import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  /// LOCAL TESTING MODE — real phone bhi local server se connect hoga
  /// Phone aur computer same WiFi pe hone chahiye!
  /// Production ke liye wapas Render URL karo:
  /// 'https://smartgaliapi-77oa.onrender.com/api/v1'
  static const String _productionUrl = 'http://192.168.31.15:5000/api/v1';

  static const String _configuredUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Local dev URLs — ONLY used when running on emulator/simulator via `flutter run`.
  /// These IPs do NOT work on real physical devices.
  static String get _emulatorUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000/api/v1'; // Chrome / Web browser
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api/v1'; // Android Emulator only
    } else {
      return 'http://localhost:5000/api/v1'; // iOS Simulator only
    }
  }

  static bool get _hasCustomUrl => _configuredUrl.trim().isNotEmpty;

  /// Returns true only when running inside an emulator/simulator via `flutter run`.
  /// Real physical devices always return false — so they use the Render URL.
  static bool get _isEmulator {
    // Only possible in debug/profile mode. Release builds never use emulator URLs.
    if (kReleaseMode) return false;
    // Check dart-define flag set by launch configs for emulator/simulator sessions.
    const runEnv = String.fromEnvironment('RUN_ENV', defaultValue: '');
    return runEnv == 'emulator';
  }

  /// Base URL resolution (priority order):\
  ///  1. --dart-define=API_BASE_URL  → explicit override (always wins)
  ///  2. Emulator/Simulator session  → localhost URL (only via flutter run with RUN_ENV=emulator)
  ///  3. Everything else             → Local machine IP (192.168.31.15:5000)
  static String get baseUrl {
    String selected;
    if (_hasCustomUrl) {
      selected = _configuredUrl.trim();
    } else if (_isEmulator) {
      selected = _emulatorUrl;
    } else {
      // Real phone → Local machine IP (same WiFi pe hona chahiye)
      selected = _productionUrl;
    }
    return selected.replaceFirst(RegExp(r'/+$'), '');
  }

  /// Converts relative and backend-local media URLs into a URL reachable from
  /// the current Flutter platform.
  static String? normalizeMediaUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final parsed = Uri.tryParse(raw);
    if (parsed == null) return raw;

    if (!parsed.hasScheme) {
      final apiUri = Uri.parse(baseUrl);
      final path = raw.startsWith('/') ? raw : '/$raw';
      return apiUri.replace(path: path, query: null, fragment: null).toString();
    }

    if (kReleaseMode && parsed.scheme != 'https') return null;

    // Only rewrite localhost URLs when actually running on emulator/simulator.
    if (_isEmulator &&
        (parsed.host == 'localhost' || parsed.host == '127.0.0.1')) {
      final apiUri = Uri.parse(baseUrl);
      return parsed.replace(host: apiUri.host, port: apiUri.port).toString();
    }

    return parsed.toString();
  }

  // Highly accurate endpoints connected to your existing userProfile backend folder
  static String get sendOtp => "$baseUrl/user-profile/send-otp";
  static String get verifyOtp => "$baseUrl/user-profile/verify-otp";
  static String get resendOtp => "$baseUrl/user-profile/resend-otp";

  // ── Profile module endpoints ─────────────────────────────────
  static String get me => "$baseUrl/profile/me";
  static String get avatar => "$baseUrl/profile/me/avatar";
  static String get addresses => "$baseUrl/profile/addresses";
  static String address(int id) => "$addresses/$id";
  static String defaultAddress(int id) => "$addresses/$id/default";
  static String get society => "$baseUrl/profile/society";
  static String get supportTickets => "$baseUrl/profile/support-tickets";
  static String get dataExportRequests =>
      "$baseUrl/profile/data-export-requests";
  static String get notificationPreferences =>
      "$baseUrl/profile/notification-preferences";
  static String get privacySettings => "$baseUrl/profile/privacy-settings";
  static String get changePassword => "$baseUrl/profile/change-password";

  // ── Notification module endpoints (real-time) ────────────────
  static String get myNotifications => "$baseUrl/notification/me";
  static String get notificationsUnreadCount =>
      "$baseUrl/notification/me/unread-count";
  static String get markAllNotificationsRead =>
      "$baseUrl/notification/me/read-all";
  static String markNotificationRead(int id) =>
      "$baseUrl/notification/$id/read";

  // ── Chat module endpoints ────────────────────────────────────
  static String get myChats => "$baseUrl/chat/my-chats";
  static String get createOneToOneChat => "$baseUrl/chat/one-to-one";
  static String get createGroupChat => "$baseUrl/chat/group";
  static String get uploadAttachment => "$baseUrl/chat/upload-attachment";
  static String chatMute(int chatId) => "$baseUrl/chat/$chatId/mute";
  static String chatPin(int chatId) => "$baseUrl/chat/$chatId/pin";

  // ── Message module endpoints ─────────────────────────────────
  static String get sendMessage => "$baseUrl/message/send";
  static String get markAllRead => "$baseUrl/message/mark-all-read";
  static String chatMessages(int chatId) => "$baseUrl/message/chat/$chatId";
  static String searchMessages(int chatId) =>
      "$baseUrl/message/chat/$chatId/search";
  static String chatMedia(int chatId) => "$baseUrl/message/chat/$chatId/media";
  static String pinnedMessages(int chatId) =>
      "$baseUrl/message/chat/$chatId/pinned";
  static String markMessageRead(int messageId) =>
      "$baseUrl/message/$messageId/read";
  static String messageReceipts(int messageId) =>
      "$baseUrl/message/$messageId/receipts";
  static String reactToMessage(int messageId) =>
      "$baseUrl/message/$messageId/react";
  static String editMessage(int messageId) =>
      "$baseUrl/message/$messageId/edit";
  static String deleteForMe(int messageId) =>
      "$baseUrl/message/$messageId/delete-for-me";
  static String deleteForEveryone(int messageId) =>
      "$baseUrl/message/$messageId/delete-for-everyone";
  static String forwardMessage(int messageId) =>
      "$baseUrl/message/$messageId/forward";
  static String pinMessage(int messageId) => "$baseUrl/message/$messageId/pin";

  // ── Socket.IO base URL (no /api/v1 path) ────────────────────
  static String get socketUrl {
    final apiUri = Uri.parse(baseUrl);
    return apiUri
        .replace(path: '', query: null, fragment: null)
        .toString()
        .replaceFirst(RegExp(r'/+$'), '');
  }
}
