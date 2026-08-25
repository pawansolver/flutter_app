import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  /// Toggle to easily switch between Localhost backend and Live Production Server.
  /// When true (or in debug mode), the app connects to the local backend on port 5000.
  static const bool useLocalhost = true;

  /// Live Production API URL
  static const String _productionUrl = 'https://api.smartgali.com/api/v1';

  /// Local Machine Wi-Fi IP (for physical Android/iOS device testing over Wi-Fi)
  static const String localLanIp = '10.19.176.105';
  static const int localPort = 5000;

  static const String _configuredUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Local dev URLs automatically resolved based on runtime platform:
  /// - Web (Chrome/Edge): http://127.0.0.1:5000/api/v1
  /// - Android Emulator: http://10.0.2.2:5000/api/v1 (10.0.2.2 routes to host localhost)
  /// - iOS Simulator / macOS / Windows Desktop: http://localhost:5000/api/v1
  static String get _localDevUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$localPort/api/v1'; // Chrome / Web browser
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:$localPort/api/v1'; // Android Emulator
    } else if (Platform.isIOS) {
      return 'http://localhost:$localPort/api/v1'; // iOS Simulator
    } else {
      return 'http://localhost:$localPort/api/v1'; // Desktop (Windows/Mac/Linux)
    }
  }

  static bool get _hasCustomUrl => _configuredUrl.trim().isNotEmpty;

  /// Base URL resolution (priority order):
  ///  1. --dart-define=API_BASE_URL  → explicit override (always wins)
  ///  2. useLocalhost = true / Debug → Localhost dev URLs (10.0.2.2 / 127.0.0.1 / localhost)
  ///  3. Release Mode                → Live Production URL
  static String get baseUrl {
    String selected;
    if (_hasCustomUrl) {
      selected = _configuredUrl.trim();
    } else if (useLocalhost || !kReleaseMode) {
      selected = _localDevUrl;
    } else {
      // Live Production API Server
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

    if (kReleaseMode && parsed.scheme == 'http') {
      return parsed.replace(scheme: 'https').toString();
    }

    // Rewrite localhost URLs to baseUrl because physical phones cannot access localhost.
    // This happens if the backend misconfigures its BASE_URL env var.
    if (parsed.host == 'localhost' || parsed.host == '127.0.0.1') {
      final apiUri = Uri.parse(baseUrl);
      return parsed.replace(scheme: apiUri.scheme, host: apiUri.host, port: apiUri.port).toString();
    }

    return parsed.toString();
  }

  // Highly accurate endpoints connected to your existing userProfile backend folder
  static String get sendOtp => "$baseUrl/user-profile/send-otp";
  static String get verifyOtp => "$baseUrl/user-profile/verify-otp";
  static String get resendOtp => "$baseUrl/user-profile/resend-otp";

  // ── Password authentication endpoints ─────────────────────────
  static String get authSignup => "$baseUrl/auth/signup";
  static String get authVerifyEmailOtp => "$baseUrl/auth/verify-email-otp";
  static String get authCreatePassword => "$baseUrl/auth/create-password";
  static String get authSignin => "$baseUrl/auth/signin";
  static String get authForgotPassword => "$baseUrl/auth/forgot-password";
  static String get authVerifyResetOtp => "$baseUrl/auth/verify-reset-otp";
  static String get authResetPassword => "$baseUrl/auth/reset-password";
  static String get authRefreshToken => "$baseUrl/auth/refresh-token";
  static String get authLogout => "$baseUrl/auth/logout";
  static String get authProfile => "$baseUrl/auth/profile";
  static String get authAccount => "$baseUrl/auth/account";

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
  static String deleteNotification(int id) => "$baseUrl/notification/$id";
  static String get bulkDeleteNotifications =>
      "$baseUrl/notification/bulk-delete";

  // ── Follow module endpoints (Phase 8) ────────────────────────
  /// POST body: { userId: TARGET_USER_ID }
  static String get followUser => "$baseUrl/users/follow";
  static String unfollow(int targetUserId) =>
      "$baseUrl/users/unfollow/$targetUserId";
  static String get myFollowers => "$baseUrl/users/followers";
  static String get myFollowing => "$baseUrl/users/following";
  static String get allUsers => "$baseUrl/user";

  // ── Device module endpoints ─────────────────────────────────
  static String get registerDevice => "$baseUrl/device/register";
  static String get deactivateDevice => "$baseUrl/device/deactivate";
  static String updateDevice(String deviceId) => "$baseUrl/device/$deviceId";

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

  // ── Community module endpoints (PRD Section 18.3) ────────────
  static String get communities => "$baseUrl/communities";
  static String community(int id) => "$baseUrl/communities/$id";
  static String get myCommunities => "$baseUrl/communities/my";
  static String get suggestedCommunities => "$baseUrl/communities/suggested";
  static String get communityCategories => "$baseUrl/communities/categories";
  static String joinCommunity(int id) => "$baseUrl/communities/$id/join";
  static String leaveCommunity(int id) => "$baseUrl/communities/$id/leave";
  static String communityMembers(int id) => "$baseUrl/communities/$id/members";
  static String communityFeed(int id) => "$baseUrl/communities/$id/feed";
  static String communityPolls(int id) => "$baseUrl/communities/$id/polls";
  static String voteCommunityPoll(int pollId) => "$baseUrl/communities/polls/$pollId/vote";

  // ── Socket.IO base URL (no /api/v1 path) ────────────────────
  static String get socketUrl {
    final apiUri = Uri.parse(baseUrl);
    return apiUri
        .replace(path: '', query: null, fragment: null)
        .toString()
        .replaceFirst(RegExp(r'/+$'), '');
  }
}
