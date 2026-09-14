import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/service_marketplace_service.dart';
import '../../services/society_service.dart';
import '../chat/chat_window_screen.dart';
import '../community/community_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/event_invitations_screen.dart';
import '../events/events_screen.dart';
import '../feed/home_screen.dart' as feed_home;
import '../feed/post_detail_screen.dart';
import '../profile/user_profile_screen.dart';
import '../services/screens/booking_detail_screen.dart';
import '../services/screens/my_service_bookings_screen.dart';
import '../services/screens/provider_booking_detail_screen.dart';
import '../services/screens/provider_bookings_screen.dart';
import '../services/screens/provider_reviews_screen.dart';
import '../society/announcements_screen.dart';
import '../society/complaint_detail_screen.dart';
import '../society/parking_screen.dart';
import '../society/society_dashboard_screen.dart';
import '../society/society_emergency_contacts_screen.dart';
import '../society/society_operations_screen.dart';
import 'notification_service.dart';
import 'widgets/notification_card.dart';

/// Top filter for the notification center: strictly "All" and "Unread" as per PRD.
enum _NotificationTab { all, unread }

/// SmartGali Notification Center Screen
/// Implements PRD-compliant notifications list with date grouping (Today, Yesterday, Earlier),
/// All/Unread filters, live unread badge, shimmer loading, empty state, pull-to-refresh,
/// pagination, and safe deep-link navigation into existing screens.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final NotificationService _service = NotificationService();
  final ScrollController _scrollController = ScrollController();

  // ── State ──────────────────────────────────────────────────────────────
  final List<AppNotification> _all = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isMarkingAll = false;
  bool _isClearingRead = false;
  bool _isDeletingAll = false;
  String? _error;
  int _unreadCount = 0;

  // Multi-Selection Mode
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  bool get _hasMore => _currentPage < _totalPages;

  // ── Tabs ───────────────────────────────────────────────────────────────
  late final TabController _tabController;
  final List<_NotificationTab> _tabs = [_NotificationTab.all, _NotificationTab.unread];

  // ── Polling ────────────────────────────────────────────────────────────
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 20);

  // ── Design Tokens ──────────────────────────────────────────────────────
  static const _orange = Color(0xFFFF6B00);
  static const _green = Color(0xFF10B981);
  static const _dark = Color(0xFF111827);
  static const _grey = Color(0xFF6B7280);
  static const _bgColor = Color(0xFFF3F4F6);
  static const _divider = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _loadNotifications();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSilently();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refreshSilently());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading && !_isLoadingMore) {
        _loadMoreNotifications();
      }
    }
  }

  // ── Filtered list for active tab ──────────────────────────────────────
  List<AppNotification> get _filtered {
    final currentTab = _tabs[_tabController.index];
    if (currentTab == _NotificationTab.unread) {
      return _all.where((n) => !n.isRead).toList();
    }
    return _all;
  }

  // ── Date Grouping ─────────────────────────────────────────────────────
  Map<String, List<AppNotification>> _groupNotifications(List<AppNotification> items) {
    final Map<String, List<AppNotification>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final item in items) {
      if (item.createdAt == null) {
        groups['Earlier']!.add(item);
        continue;
      }

      final itemDate = DateTime(
        item.createdAt!.year,
        item.createdAt!.month,
        item.createdAt!.day,
      );

      if (itemDate.isAtSameMomentAs(today)) {
        groups['Today']!.add(item);
      } else if (itemDate.isAtSameMomentAs(yesterday)) {
        groups['Yesterday']!.add(item);
      } else {
        groups['Earlier']!.add(item);
      }
    }

    return groups;
  }

  // ── Data fetching ──────────────────────────────────────────────────────
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
    });

    final result = await _service.getMyNotifications(page: 1, limit: 25);
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        _all
          ..clear()
          ..addAll(result.data!.items);
        _unreadCount = result.data!.unreadCount;
        _currentPage = result.data!.page;
        _totalPages = result.data!.totalPages;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.error ?? 'Failed to load notifications';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final result = await _service.getMyNotifications(page: nextPage, limit: 25);
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        // Prevent duplicates
        final existingIds = _all.map((e) => e.id).toSet();
        for (final item in result.data!.items) {
          if (!existingIds.contains(item.id)) {
            _all.add(item);
          }
        }
        _currentPage = result.data!.page;
        _totalPages = result.data!.totalPages;
        _unreadCount = result.data!.unreadCount;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refreshSilently() async {
    final result = await _service.getMyNotifications(page: 1, limit: 25);
    if (!mounted || !result.isSuccess || result.data == null) return;
    setState(() {
      _all
        ..clear()
        ..addAll(result.data!.items);
      _unreadCount = result.data!.unreadCount;
      _currentPage = result.data!.page;
      _totalPages = result.data!.totalPages;
      _error = null;
    });
  }

  // ── Multi-Selection Mode Actions ───────────────────────────────────────────

  void _enterSelectionMode(int initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      _selectedIds.add(initialId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    final visible = _filtered;
    setState(() {
      if (_selectedIds.length == visible.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(visible.map((n) => n.id));
      }
    });
  }

  Future<void> _deleteSelectedNotifications() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Selected',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Delete $count selected notification${count > 1 ? 's' : ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final idsToDelete = _selectedIds.toList();
    setState(() {
      for (final id in idsToDelete) {
        final notif = _all.firstWhere((n) => n.id == id, orElse: () => _all.first);
        if (!notif.isRead && _unreadCount > 0) _unreadCount -= 1;
      }
      _all.removeWhere((n) => _selectedIds.contains(n.id));
      _exitSelectionMode();
    });

    final result = await _service.bulkDeleteNotifications(
      idsToDelete,
      deletedRemarks: 'User deleted selected notifications',
    );
    if (!mounted) return;

    if (result.isSuccess) {
      _showSnack('Deleted $count notifications.', isSuccess: true);
    } else {
      _loadNotifications();
      _showSnack(result.error ?? 'Failed to delete selected notifications.');
    }
  }

  Future<void> _markSelectedAsRead() async {
    if (_selectedIds.isEmpty) return;

    final unreadSelected = _all.where((n) => _selectedIds.contains(n.id) && !n.isRead).toList();
    if (unreadSelected.isEmpty) {
      _exitSelectionMode();
      _showSnack('Selected notifications are already read.');
      return;
    }

    setState(() {
      for (var i = 0; i < _all.length; i++) {
        if (_selectedIds.contains(_all[i].id) && !_all[i].isRead) {
          _all[i] = _all[i].copyWith(isRead: true);
        }
      }
      _unreadCount = (_unreadCount - unreadSelected.length).clamp(0, 999999);
      _exitSelectionMode();
    });

    for (final notif in unreadSelected) {
      unawaited(_service.markRead(notif.id));
    }

    _showSnack('Marked ${unreadSelected.length} notification(s) as read.', isSuccess: true);
  }

  // ── Notification Actions ───────────────────────────────────────────────

  /// Tap: mark single notification as read (optimistic update) and navigate.
  Future<void> _onTapNotification(AppNotification notif) async {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedIds.contains(notif.id)) {
          _selectedIds.remove(notif.id);
        } else {
          _selectedIds.add(notif.id);
        }
      });
      return;
    }

    if (!notif.isRead) {
      final index = _all.indexWhere((n) => n.id == notif.id);
      if (index != -1) {
        setState(() {
          _all[index] = notif.copyWith(isRead: true);
          if (_unreadCount > 0) _unreadCount -= 1;
        });
      }

      // Background sync mark as read
      unawaited(_service.markRead(notif.id).then((res) {
        if (!res.isSuccess && mounted && index != -1) {
          setState(() {
            _all[index] = notif.copyWith(isRead: false);
            _unreadCount += 1;
          });
        }
      }));
    }

    // Deep navigation
    await _handleDeepLink(notif);
  }

  /// Toggle read/unread status on a single notification
  Future<void> _toggleReadStatus(AppNotification notif) async {
    final index = _all.indexWhere((n) => n.id == notif.id);
    if (index == -1) return;

    final newRead = !notif.isRead;
    setState(() {
      _all[index] = notif.copyWith(isRead: newRead);
      if (newRead) {
        if (_unreadCount > 0) _unreadCount -= 1;
      } else {
        _unreadCount += 1;
      }
    });

    final result = newRead
        ? await _service.markRead(notif.id)
        : await _service.markUnread(notif.id);

    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() {
        _all[index] = notif;
        if (newRead) {
          _unreadCount += 1;
        } else {
          if (_unreadCount > 0) _unreadCount -= 1;
        }
      });
      _showSnack(result.error ?? 'Failed to update notification');
    } else {
      _showSnack(
        newRead ? 'Marked as read.' : 'Marked as unread.',
        isSuccess: true,
      );
    }
  }

  /// Delete single notification with immediate optimistic UI and Undo snackbar.
  Future<void> _deleteNotification(AppNotification notif) async {
    final index = _all.indexWhere((n) => n.id == notif.id);
    if (index == -1) return;

    setState(() {
      _all.removeAt(index);
      if (!notif.isRead && _unreadCount > 0) _unreadCount -= 1;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted.'),
        backgroundColor: _dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Undo',
          textColor: _orange,
          onPressed: () {
            setState(() {
              _all.insert(index, notif);
              if (!notif.isRead) _unreadCount += 1;
            });
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    final result = await _service.deleteNotification(
      notif.id,
      deletedRemarks: 'User deleted notification',
    );
    if (!mounted) return;
    if (!result.isSuccess) {
      if (!_all.any((n) => n.id == notif.id)) {
        setState(() {
          _all.insert(index, notif);
          if (!notif.isRead) _unreadCount += 1;
        });
        _showSnack(result.error ?? 'Could not delete notification.');
      }
    }
  }

  /// Mark all as read for the entire feed.
  Future<void> _markAllRead() async {
    if (_isMarkingAll || _unreadCount == 0) return;
    setState(() => _isMarkingAll = true);

    final result = await _service.markAllRead();
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        for (var i = 0; i < _all.length; i++) {
          if (!_all[i].isRead) {
            _all[i] = _all[i].copyWith(isRead: true);
          }
        }
        _unreadCount = 0;
        _isMarkingAll = false;
      });
      _showSnack('All notifications marked as read.', isSuccess: true);
    } else {
      setState(() => _isMarkingAll = false);
      _showSnack(result.error ?? 'Failed to mark all as read.');
    }
  }

  /// Delete all notifications in feed with confirmation.
  Future<void> _deleteAllNotifications() async {
    if (_all.isEmpty || _isDeletingAll) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete All Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Delete all ${_all.length} notification${_all.length > 1 ? 's' : ''}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAll = true);
    final allIds = _all.map((n) => n.id).toList();
    final result = await _service.bulkDeleteNotifications(
      allIds,
      deletedRemarks: 'User deleted all notifications',
    );
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _all.clear();
        _unreadCount = 0;
        _isDeletingAll = false;
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      _showSnack('All notifications deleted.', isSuccess: true);
    } else {
      setState(() => _isDeletingAll = false);
      _showSnack(result.error ?? 'Failed to delete notifications.');
    }
  }

  /// Bulk delete all READ notifications → "Clear read" action.
  Future<void> _clearReadNotifications() async {
    final readIds = _all.where((n) => n.isRead).map((n) => n.id).toList();
    if (readIds.isEmpty) {
      _showSnack('No read notifications to clear.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Read Notifications',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Delete ${readIds.length} read notification${readIds.length > 1 ? 's' : ''}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isClearingRead = true);
    final result = await _service.bulkDeleteNotifications(
      readIds,
      deletedRemarks: 'User cleared read notifications',
    );
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _all.removeWhere((n) => n.isRead);
        _isClearingRead = false;
      });
      _showSnack(
        'Cleared ${result.data} notification${(result.data ?? 0) > 1 ? 's' : ''}.',
        isSuccess: true,
      );
    } else {
      setState(() => _isClearingRead = false);
      _showSnack(result.error ?? 'Failed to clear notifications.');
    }
  }

  Future<void> _respondToCommunityInvitation(
    AppNotification notification,
    String action,
  ) async {
    final communityId = int.tryParse(
      notification.data?['communityId']?.toString() ?? '',
    );
    final invitationId = int.tryParse(
      notification.data?['invitationId']?.toString() ?? '',
    );
    if (communityId == null || invitationId == null) {
      _showSnack('This invitation is missing required details.');
      return;
    }
    try {
      await CommunityService().respondToInvitation(
        communityId,
        invitationId,
        action,
      );
      if (!mounted) return;
      await _service.markRead(notification.id);
      if (!mounted) return;
      setState(() {
        _all.removeWhere((item) => item.id == notification.id);
        if (!notification.isRead && _unreadCount > 0) _unreadCount -= 1;
      });
      _showSnack(
        action == 'accept' ? 'Invitation accepted.' : 'Invitation declined.',
        isSuccess: true,
      );
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  // ── Deep Link Navigation Dispatcher ────────────────────────────────────

  Future<void> _handleDeepLink(AppNotification notif) async {
    final target = notif.deepLinkTarget;
    final data = notif.data ?? {};

    try {
      switch (target) {
        // 1. Chat Message
        case 'chat':
          final chatId = int.tryParse(data['chatId']?.toString() ?? '');
          if (chatId != null && chatId > 0) {
            final userId = await AuthService().getUserId();
            if (!mounted) return;
            final chatName = (data['chatName']?.toString().isNotEmpty == true)
                ? data['chatName'].toString()
                : (notif.title.isNotEmpty ? notif.title : 'Chat');
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatWindowScreen(
                  chatId: chatId,
                  chatName: chatName,
                  currentUserId: userId ?? 0,
                  isOnline: false,
                ),
              ),
            );
            return;
          }
          break;

        // 2. Community Update / Announcement / Join Request
        case 'community':
          final communityId = int.tryParse(data['communityId']?.toString() ?? '');
          if (communityId != null && communityId > 0) {
            try {
              final community = await CommunityService().getCommunityDetails(communityId);
              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommunityDetailScreen(community: community),
                ),
              );
              return;
            } catch (_) {
              if (!mounted) return;
              _showSnack('Unable to load community details.');
              return;
            }
          }
          break;

        // 3. Event Reminder / New Event / Event Invitation
        case 'event':
        case 'event_invitation':
          final t = notif.type.toLowerCase();
          if (t.contains('invitation') || target == 'event_invitation' || data['invitationId'] != null) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EventInvitationsScreen(),
              ),
            );
            return;
          }
          final eventId = int.tryParse(data['eventId']?.toString() ?? '');
          if (eventId != null && eventId > 0) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(eventId: eventId),
              ),
            );
            return;
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EventsScreen(),
              ),
            );
            return;
          }

        // 4. Follow Request / Profile
        case 'profile':
          final userId = int.tryParse(
            (data['userId'] ?? data['targetUserId'] ?? data['senderId'])?.toString() ?? '',
          );
          if (userId != null && userId > 0) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  userId: userId,
                  userName: data['userName']?.toString() ?? 'User',
                  fullName: data['fullName']?.toString(),
                  avatarUrl: data['avatarUrl']?.toString(),
                ),
              ),
            );
            return;
          }
          break;

        // 5. Service Bookings (Provider & Customer)
        case 'booking':
          final bookingId = int.tryParse(data['bookingId']?.toString() ?? '');
          final isProvider = data['isProvider'] == true ||
              notif.type.toLowerCase().contains('request') ||
              notif.type.toLowerCase().contains('provider') ||
              notif.title.toLowerCase().contains('request');

          if (bookingId != null && bookingId > 0) {
            try {
              final booking = await ServiceMarketplaceService().getBookingById(bookingId);
              if (!mounted) return;

              if (booking != null) {
                if (isProvider) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProviderBookingDetailScreen(booking: booking),
                    ),
                  );
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingDetailScreen(booking: booking),
                    ),
                  );
                }
                return;
              }
            } catch (_) {
              // Fallback to bookings screen
            }
          }

          if (!mounted) return;
          if (isProvider) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProviderBookingsScreen()),
            );
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyServiceBookingsScreen()),
            );
          }
          return;

        // 6. Service Reviews
        case 'review':
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ProviderReviewsScreen(),
            ),
          );
          return;

        // 7. Society Complaints
        case 'society_complaint':
          final societyId = int.tryParse(data['societyId']?.toString() ?? '');
          final complaintId = int.tryParse(data['complaintId']?.toString() ?? '');
          if (complaintId != null && complaintId > 0) {
            try {
              final complaint = await SocietyService().getComplaint(complaintId, societyId ?? 0);
              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComplaintDetailScreen(
                    complaint: complaint,
                    userRole: 'resident',
                  ),
                ),
              );
              return;
            } catch (_) {
              // Fallback to operations complaints tab
            }
          }
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietyOperationsScreen(
                initialTab: 0,
                societyId: societyId,
              ),
            ),
          );
          return;

        // 8. Society Visitors
        case 'society_visitor':
          final societyId = int.tryParse(data['societyId']?.toString() ?? '');
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietyOperationsScreen(
                initialTab: 1,
                societyId: societyId,
              ),
            ),
          );
          return;

        // 9. Society Polls
        case 'society_poll':
          final societyId = int.tryParse(data['societyId']?.toString() ?? '');
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietyOperationsScreen(
                initialTab: 2,
                societyId: societyId,
              ),
            ),
          );
          return;

        // 10. Society Announcements
        case 'society_announcement':
          final societyId = int.tryParse(data['societyId']?.toString() ?? '');
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnnouncementsScreen(societyId: societyId),
            ),
          );
          return;

        // 11. Society Parking
        case 'society_parking':
          final societyId = int.tryParse(data['societyId']?.toString() ?? '');
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParkingScreen(societyId: societyId),
            ),
          );
          return;

        // 12. Society Emergency
        case 'society_emergency':
          final societyId = int.tryParse(data['societyId']?.toString() ?? '');
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietyEmergencyContactsScreen(
                societyId: societyId ?? 0,
                userRole: 'resident',
              ),
            ),
          );
          return;

        // 13. General Society Dashboard
        case 'society':
          final societyId = int.tryParse(data['societyId']?.toString() ?? '');
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietyDashboardScreen(
                initialSocietyId: societyId,
              ),
            ),
          );
          return;

        // 14. Posts (Like / Comment)
        case 'post':
          final postId = int.tryParse(data['postId']?.toString() ?? '');
          if (postId != null && postId > 0) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(postId: postId),
              ),
            );
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const feed_home.HomeScreen(),
            ),
          );
          return;

        default:
          break;
      }
    } catch (e) {
      if (mounted) {
        _showSnack('This content could not be opened.');
      }
      return;
    }

    // Informational fallback when no direct screen navigation is matched
    if (notif.message.isNotEmpty && mounted) {
      _showSnack('${notif.title}: ${notif.message}', isSuccess: true);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? _green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── UI Builders ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final readCount = _all.where((n) => n.isRead).length;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: _dark),
                onPressed: _exitSelectionMode,
              ),
              title: Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(
                  color: _dark,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: _selectedIds.length == _filtered.length ? 'Deselect all' : 'Select all',
                  icon: Icon(
                    _selectedIds.length == _filtered.length
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    color: _dark,
                  ),
                  onPressed: _toggleSelectAll,
                ),
                if (_selectedIds.isNotEmpty) ...[
                  IconButton(
                    tooltip: 'Mark as read',
                    icon: const Icon(Icons.mark_email_read_outlined, color: _dark),
                    onPressed: _markSelectedAsRead,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: _deleteSelectedNotifications,
                  ),
                ],
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(color: _divider, height: 1.0),
              ),
            )
          : _buildAppBar(readCount),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(int readCount) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _dark),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              color: _dark,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_isMarkingAll || _isClearingRead || _isDeletingAll)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _orange),
              ),
            ),
          )
        else if (_unreadCount > 0)
          TextButton(
            onPressed: _markAllRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: _orange,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: _dark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            if (value == 'select_mode') {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.clear();
              });
            } else if (value == 'clear_read') {
              _clearReadNotifications();
            } else if (value == 'delete_all') {
              _deleteAllNotifications();
            }
          },
          itemBuilder: (_) => [
            if (_filtered.isNotEmpty)
              const PopupMenuItem(
                value: 'select_mode',
                child: Row(
                  children: [
                    Icon(Icons.checklist_rounded, size: 20, color: _dark),
                    SizedBox(width: 10),
                    Text(
                      'Select notifications',
                      style: TextStyle(color: _dark),
                    ),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'clear_read',
              enabled: readCount > 0,
              child: Row(
                children: [
                  Icon(
                    Icons.cleaning_services_outlined,
                    size: 20,
                    color: readCount > 0 ? _orange : _grey,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Clear read ($readCount)',
                    style: TextStyle(
                      color: readCount > 0 ? _dark : _grey,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete_all',
              enabled: _all.isNotEmpty,
              child: Row(
                children: [
                  Icon(
                    Icons.delete_forever_outlined,
                    size: 20,
                    color: _all.isNotEmpty ? Colors.redAccent : _grey,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Delete all (${_all.length})',
                    style: TextStyle(
                      color: _all.isNotEmpty ? Colors.redAccent : _grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: _divider, height: 1.0),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: _dark,
          unselectedLabelColor: _grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          dividerHeight: 0,
          tabs: [
            const Tab(text: 'All'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Unread'),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildSkeletonList();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    final visible = _filtered;
    if (visible.isEmpty) {
      return _buildEmptyState();
    }

    final grouped = _groupNotifications(visible);

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadNotifications,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ..._buildDateSection('Today', grouped['Today']!),
          ..._buildDateSection('Yesterday', grouped['Yesterday']!),
          ..._buildDateSection('Earlier', grouped['Earlier']!),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildDateSection(String title, List<AppNotification> items) {
    if (items.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4B5563),
            letterSpacing: 0.5,
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: _divider),
          itemBuilder: (context, index) {
            final notif = items[index];
            return NotificationCard(
              notification: notif,
              isSelectionMode: _isSelectionMode,
              isSelected: _selectedIds.contains(notif.id),
              onSelectChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.add(notif.id);
                  } else {
                    _selectedIds.remove(notif.id);
                  }
                });
              },
              onTap: () => _onTapNotification(notif),
              onLongPress: () {
                if (!_isSelectionMode) {
                  _enterSelectionMode(notif.id);
                }
              },
              onToggleRead: () => _toggleReadStatus(notif),
              onDelete: () => _deleteNotification(notif),
              onAcceptInvitation: notif.data?['invitationId'] != null
                  ? () => _respondToCommunityInvitation(notif, 'accept')
                  : null,
              onDeclineInvitation: notif.data?['invitationId'] != null
                  ? () => _respondToCommunityInvitation(notif, 'decline')
                  : null,
            );
          },
        ),
      ),
    ];
  }

  Widget _buildEmptyState() {
    final isUnreadTab = _tabs[_tabController.index] == _NotificationTab.unread;

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadNotifications,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _divider),
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 38,
                color: _grey,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              "You're all caught up",
              style: TextStyle(
                color: _dark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                isUnreadTab
                    ? 'No unread notifications right now.'
                    : 'New activity and updates will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _grey, fontSize: 13, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _divider),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 36,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Couldn't load notifications",
              style: TextStyle(
                color: _dark,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
