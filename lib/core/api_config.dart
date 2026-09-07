import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  /// Toggle to easily switch between Localhost backend and Live Production Server.
  /// When true (or in debug mode), the app connects to the local backend on port 5000.
  static const bool useLocalhost = true;

  /// Live Production API URL
  static const String _productionUrl = 'https://api.smartgali.com/api/v1';

  /// Set this to true if testing on a REAL PHYSICAL PHONE connected via Wi-Fi.
  /// Set to false if testing on Android Emulator / Web / Desktop.
  static const bool usePhysicalPhoneLan = false;

  /// Local Machine Wi-Fi IP (current IP: 192.168.31.15)
  static const String localLanIp = '192.168.31.15';
  static const int localPort = 5000;

  static const String _configuredUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Local dev URLs automatically resolved based on runtime platform:
  /// - Web (Chrome/Edge): http://127.0.0.1:5000/api/v1
  /// - Android Emulator: http://10.0.2.2:5000/api/v1
  /// - Real Android Phone (Wi-Fi): http://192.168.31.15:5000/api/v1
  /// - iOS Simulator / macOS / Windows Desktop: http://localhost:5000/api/v1
  static String get _localDevUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$localPort/api/v1'; // Chrome / Web browser
    } else if (Platform.isAndroid) {
      if (usePhysicalPhoneLan) {
        return 'http://$localLanIp:$localPort/api/v1'; // Physical Android device over Wi-Fi
      }
      return 'http://10.0.2.2:$localPort/api/v1'; // Android Emulator
    } else if (Platform.isIOS) {
      if (usePhysicalPhoneLan) {
        return 'http://$localLanIp:$localPort/api/v1'; // Physical iOS device over Wi-Fi
      }
      return 'http://localhost:$localPort/api/v1'; // iOS Simulator
    } else {
      return 'http://localhost:$localPort/api/v1'; // Desktop (Windows/Mac/Linux)
    }
  }

  static bool get _hasCustomUrl => _configuredUrl.trim().isNotEmpty;

  /// Base URL resolution (priority order):
  ///  1. --dart-define=API_BASE_URL  → explicit override (always wins)
  ///  2. useLocalhost = true         → Local dev URLs (10.0.2.2 / 127.0.0.1 / localhost)
  ///  3. Default                     → Live Production URL (https://api.smartgali.com/api/v1)
  static String get baseUrl {
    String selected;
    if (_hasCustomUrl) {
      selected = _configuredUrl.trim();
    } else if (useLocalhost) {
      selected = _localDevUrl;
    } else {
      // Live Production API Server
      selected = _productionUrl;
    }
    return selected.replaceFirst(RegExp(r'/+$'), '');
  }

  /// Converts relative and backend-local media URLs into a URL reachable from
  /// the current Flutter platform.
  ///
  /// Handles:
  ///  - Relative paths (no scheme)   → prepend baseUrl
  ///  - localhost / 127.0.0.1 URLs   → rewrite to current baseUrl host
  ///  - Private LAN IPs (192.168.x, 10.x, 172.x) → rewrite to current baseUrl host
  ///  - Release mode HTTP            → upgrade to HTTPS
  static String? normalizeMediaUrl(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final parsed = Uri.tryParse(raw);
    if (parsed == null) return raw;

    // Relative path → prepend baseUrl origin
    if (!parsed.hasScheme) {
      final apiUri = Uri.parse(baseUrl);
      final path = raw.startsWith('/') ? raw : '/$raw';
      return apiUri.replace(path: path, query: null, fragment: null).toString();
    }

    // Release mode: always use HTTPS
    if (kReleaseMode && parsed.scheme == 'http') {
      return parsed.replace(scheme: 'https').toString();
    }

    // Rewrite any local/LAN addresses to the current Flutter baseUrl host.
    // This covers:
    //   - localhost / 127.0.0.1   (dev machine loopback)
    //   - 192.168.x.x             (home/office Wi-Fi LAN)
    //   - 10.x.x.x                (corporate LAN / Android emulator host)
    //   - 172.16–31.x.x           (Docker / VPN subnets)
    if (_isLocalAddress(parsed.host)) {
      final apiUri = Uri.parse(baseUrl);
      return parsed
          .replace(
            scheme: apiUri.scheme,
            host: apiUri.host,
            port: apiUri.hasPort ? apiUri.port : null,
          )
          .toString();
    }

    return parsed.toString();
  }

  /// Returns true if the given [host] is a loopback or private-network address.
  static bool _isLocalAddress(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') return true;
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return false;
    if (a == 10) return true;                          // 10.0.0.0/8
    if (a == 192 && b == 168) return true;             // 192.168.0.0/16
    if (a == 172 && b >= 16 && b <= 31) return true;   // 172.16.0.0/12
    return false;
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
  static String get myCommunityInvitations =>
      "$baseUrl/communities/invitations";
  static String get communityCategories => "$baseUrl/community-category";
  static String joinCommunity(int id) => "$baseUrl/communities/$id/join";
  static String leaveCommunity(int id) => "$baseUrl/communities/$id/leave";
  static String communityMembers(int id) => "$baseUrl/communities/$id/members";
  static String communityMemberRole(int communityId, int userId) =>
      "$baseUrl/communities/$communityId/members/$userId/role";
  static String communityMember(int communityId, int userId) =>
      "$baseUrl/communities/$communityId/members/$userId";
  static String banCommunityMember(int communityId, int userId) =>
      "${communityMember(communityId, userId)}/ban";
  static String unbanCommunityMember(int communityId, int userId) =>
      "${communityMember(communityId, userId)}/unban";
  static String communityInviteableUsers(int id) =>
      "$baseUrl/communities/$id/inviteable-users";
  static String communityInvitations(int id) =>
      "$baseUrl/communities/$id/invitations";
  static String respondCommunityInvitation(int communityId, int invitationId) =>
      "${communityInvitations(communityId)}/$invitationId/respond";
  static String communityFeed(int id) => "$baseUrl/communities/$id/feed";
  static String communityPolls(int id) => "$baseUrl/communities/$id/polls";
  static String communityPoll(int communityId, int pollId) =>
      "${communityPolls(communityId)}/$pollId";
  static String voteCommunityPoll(int communityId, int pollId) =>
      "$baseUrl/communities/$communityId/polls/$pollId/vote";
  static String communityAnnouncements(int id) =>
      "$baseUrl/communities/$id/announcements";
  static String communityAnnouncement(int communityId, int announcementId) =>
      "${communityAnnouncements(communityId)}/$announcementId";
  static String communityDocuments(int id) =>
      "$baseUrl/communities/$id/documents";
  static String communityDocument(int communityId, int documentId) =>
      "${communityDocuments(communityId)}/$documentId";
  static String communityGallery(int id) => "$baseUrl/communities/$id/gallery";
  static String communityGalleryMedia(int communityId, int mediaId) =>
      "${communityGallery(communityId)}/$mediaId";
  static String communityEvents(int id) => "$baseUrl/communities/$id/events";
  static String communityEventRsvp(int communityId, int eventId) =>
      "$baseUrl/communities/$communityId/events/$eventId/rsvp";
  static String communityChat(int id) => "$baseUrl/communities/$id/chat";
  static String communityJoinRequests(int id) =>
      "$baseUrl/communities/$id/join-requests";
  static String approveJoinRequest(int id, int reqId) =>
      "$baseUrl/communities/$id/join-requests/$reqId/approve";
  static String rejectJoinRequest(int id, int reqId) =>
      "$baseUrl/communities/$id/join-requests/$reqId/reject";

  // ── Global Events module endpoints (PRD Section 7.4) ─────────
  static String get events => "$baseUrl/event";
  static String get eventCategories => "$baseUrl/event/categories";
  static String get upcomingEvents => "$baseUrl/event/upcoming";
  static String get nearbyEvents => "$baseUrl/event/nearby";
  static String get myEventRsvps => "$baseUrl/event/my-rsvps";
  static String eventDetails(int id) => "$baseUrl/event/$id";
  static String eventRsvp(int id) => "$baseUrl/event/$id/rsvp";
  static String eventParticipants(int id) => "$baseUrl/event/$id/participants";
  static String cancelEvent(int id) => "$baseUrl/event/$id/cancel";

  // ── Society module endpoints (Enterprise Hardened) ────────────
  // Society Profile
  static String get societyProfiles => "$baseUrl/society-profile";
  static String societyProfile(int id) => "$baseUrl/society-profile/$id";
  static String transferSocietyOwnership(int id) =>
      "$baseUrl/society-profile/$id/transfer-ownership";

  // Society Members
  static String get societyMembers => "$baseUrl/society-member";
  static String societyMember(int id) => "$baseUrl/society-member/$id";
  static String updateSocietyMemberRole(int id) =>
      "$baseUrl/society-member/$id/role";
  static String approveSocietyMember(int id) =>
      "$baseUrl/society-member/$id/approve";

  // Society Announcements
  static String get societyAnnouncements => "$baseUrl/society-announcement";
  static String societyAnnouncement(int id) =>
      "$baseUrl/society-announcement/$id";

  // Society Complaints
  static String get societyComplaints => "$baseUrl/society-complaint";
  static String societyComplaint(int id) => "$baseUrl/society-complaint/$id";
  static String societyComplaintStatus(int id) =>
      "$baseUrl/society-complaint/$id/status";
  static String assignSocietyComplaint(int id) =>
      "$baseUrl/society-complaint/$id/assign";

  // Society Facilities
  static String get societyFacilities => "$baseUrl/society-facility";
  static String societyFacility(int id) => "$baseUrl/society-facility/$id";

  // Society Parking
  static String get societyParkings => "$baseUrl/society-parking";
  static String societyParking(int id) => "$baseUrl/society-parking/$id";

  // Society Polls
  static String get societyPolls => "$baseUrl/society-poll";
  static String societyPoll(int id) => "$baseUrl/society-poll/$id";
  static String voteSocietyPoll(int id) => "$baseUrl/society-poll/$id/vote";
  static String societyPollStatus(int id) => "$baseUrl/society-poll/$id/status";

  // Society Visitors
  static String get societyVisitors => "$baseUrl/society-visitor";
  static String societyVisitor(int id) => "$baseUrl/society-visitor/$id";
  static String societyVisitorStatus(int id) =>
      "$baseUrl/society-visitor/$id/status";

  // ── Services Module Endpoints (PRD Sections 7.3 & 18.8) ────
  static String get serviceCategories => "$baseUrl/service-category";
  static String serviceCategory(int id) => "$baseUrl/service-category/$id";
  static String get serviceListings => "$baseUrl/service-listing";
  static String serviceListing(int id) => "$baseUrl/service-listing/$id";
  static String get serviceBookings => "$baseUrl/service-booking";
  static String serviceBooking(int id) => "$baseUrl/service-booking/$id";
  static String get serviceReviews => "$baseUrl/service-review";
  static String serviceReview(int id) => "$baseUrl/service-review/$id";
  static String get serviceProviderProfiles => "$baseUrl/service-provider-profile";
  static String serviceProviderProfile(int id) =>
      "$baseUrl/service-provider-profile/$id";

  // ── Socket.IO base URL (no /api/v1 path) ────────────────────
  static String get socketUrl {
    final apiUri = Uri.parse(baseUrl);
    return apiUri
        .replace(path: '', query: null, fragment: null)
        .toString()
        .replaceFirst(RegExp(r'/+$'), '');
  }
}

