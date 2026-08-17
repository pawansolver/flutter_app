import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api_config.dart';
import 'auth_session.dart';
import 'authenticated_dio.dart';

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
      // Request permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      log('User granted notification permission: ${settings.authorizationStatus}');

      // Background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Foreground handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Foreground Notification: ${message.notification?.title}');
      });

      // Token refresh listener
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

    } catch (e) {
      log('FCM Initialization error: $e');
    }
  }

  Future<String?> getFcmToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        final maskedToken = token.length > 10 ? '${token.substring(0, 10)}...' : token;
        log('FCM token received: $maskedToken');
      }
      return token;
    } catch (e) {
      log('Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> _onTokenRefresh(String newToken) async {
    final token = await _store.readAccessToken();
    if (token == null || token.isEmpty) return; // Not logged in

    final deviceId = await _getDeviceId();
    if (deviceId == null) return;

    try {
      final dio = AuthenticatedDio().dio;
      await dio.put(
        ApiConfig.updateDevice(deviceId),
        data: {
          'pushToken': newToken,
        },
      );
      log('FCM token refreshed and updated on backend.');
    } catch (e) {
      log('Failed to update refreshed token: $e');
    }
  }

  Future<void> registerDevice() async {
    final token = await _store.readAccessToken();
    if (token == null || token.isEmpty) return; // Not logged in

    final fcmToken = await getFcmToken();
    if (fcmToken == null) return;

    final deviceId = await _getDeviceId();
    final platform = Platform.isIOS ? 'ios' : 'android';
    final appVersion = await _getAppVersion();
    final deviceModel = await _getDeviceModel();

    if (deviceId == null) return;

    try {
      final dio = AuthenticatedDio().dio;
      await dio.post(
        ApiConfig.registerDevice,
        data: {
          "deviceId": deviceId,
          "platform": platform,
          "pushToken": fcmToken,
          "appVersion": appVersion,
          "deviceModel": deviceModel,
        },
      );
      log('Device successfully registered with backend.');
    } catch (e) {
      log('Failed to register device: $e');
    }
  }

  Future<void> deactivateDevice() async {
    final token = await _store.readAccessToken();
    if (token == null || token.isEmpty) return; // Not logged in

    try {
      final dio = AuthenticatedDio().dio;
      await dio.post(ApiConfig.deactivateDevice, data: {});
      log('Device successfully deactivated.');
    } catch (e) {
      log('Failed to deactivate device: $e');
    }
  }

  Future<String?> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Unique ID on Android
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
