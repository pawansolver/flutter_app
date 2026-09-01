import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api_config.dart';
import 'auth_session.dart';
import 'authenticated_dio.dart';

// ─── Local notification plugin (singleton) ────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'smartgali_channel',
  'Smartgali Notifications',
  description: 'Notifications for Smartgali App',
  importance: Importance.high,
  playSound: true,
);

// ─── Background handler ────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log('Handling a background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AuthSessionStore _store = AuthSessionStore();

  Future<void> initialize() async {
    try {
      // 1. Request permissions
      final NotificationSettings settings =
          await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      log('FCM permission: ${settings.authorizationStatus}');

      // 2. Setup flutter_local_notifications
      await _setupLocalNotifications();

      // 3. Register FCM background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // 4. Foreground handler — show popup via local notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Foreground FCM received: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // 5. Print token for testing
      await getFcmToken();

      // 6. Token refresh
      _messaging.onTokenRefresh.listen(_onTokenRefresh);
    } catch (e) {
      log('FCM Initialization error: $e');
    }
  }

  // ── Setup flutter_local_notifications ──────────────────────────────────────
  Future<void> _setupLocalNotifications() async {
    // Create the Android channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);
  }

  // ── Show a local popup notification ────────────────────────────────────────
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  // ── FCM Token ───────────────────────────────────────────────────────────────
  Future<String?> getFcmToken() async {
    try {
      final String? token = await _messaging.getToken();
      if (token != null) {
        print('====================================');
        print('FCM TOKEN FOR TESTING:');
        print(token);
        print('====================================');
      }
      return token;
    } catch (e) {
      log('Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final token = await _store.readAccessToken();
    if (token == null || token.isEmpty) return;

    final deviceId = await _getDeviceId();
    if (deviceId == null) return;

    try {
      final dio = AuthenticatedDio().dio;
      await dio.put(
        ApiConfig.updateDevice(deviceId),
        data: {'pushToken': newToken},
      );
      log('FCM token refreshed and updated on backend.');
    } catch (e) {
      log('Failed to update refreshed token: $e');
    }
  }

  // ── Device Registration ─────────────────────────────────────────────────────
  Future<void> registerDevice() async {
    final token = await _store.readAccessToken();
    if (token == null || token.isEmpty) return;

    final fcmToken = await getFcmToken();
    if (fcmToken == null) return;

    final deviceId = await _getDeviceId();
    final platform = kIsWeb
        ? 'web'
        : Platform.isIOS
            ? 'ios'
            : 'android';
    final appVersion = await _getAppVersion();
    final deviceModel = await _getDeviceModel();

    if (deviceId == null) return;

    try {
      final dio = AuthenticatedDio().dio;
      await dio.post(
        ApiConfig.registerDevice,
        data: {
          'deviceId': deviceId,
          'platform': platform,
          'pushToken': fcmToken,
          'appVersion': appVersion,
          'deviceModel': deviceModel,
        },
      );
      log('Device registered with backend successfully');
    } catch (e) {
      log('Failed to register device with backend: $e');
    }
  }

  Future<void> deactivateDevice() async {
    final token = await _store.readAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      final dio = AuthenticatedDio().dio;
      await dio.post(ApiConfig.deactivateDevice, data: {});
      log('Device successfully deactivated.');
    } catch (e) {
      log('Failed to deactivate device: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Future<String?> _getDeviceId() async {
    if (kIsWeb) return 'web-client';
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      log('Failed to get device ID: $e');
    }
    return null;
  }

  Future<String> _getDeviceModel() async {
    if (kIsWeb) return 'Web Browser';
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.model;
      }
    } catch (e) {
      log('Failed to get device model: $e');
    }
    return 'Unknown';
  }

  Future<String> _getAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      log('Failed to get app version: $e');
    }
    return '1.0.0';
  }
}

