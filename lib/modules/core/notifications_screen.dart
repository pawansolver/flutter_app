import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../chat/chat_window_screen.dart';
import '../community/community_detail_screen.dart';
import 'notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final NotificationService _service = NotificationService();

  // ── State ──────────────────────────────────────────────────────────────
  final List<AppNotification> _all = [];
  bool _isLoading = true;
  bool _isMarkingAll = false;
  bool _isClearingRead = false;
  String? _error;
  int _unreadCount = 0;

  // ── Tabs ───────────────────────────────────────────────────────────────
  late final TabController _tabController;
  final _tabs = NotificationCategory.values;

  // ── Polling ────────────────────────────────────────────────────────────
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 15);

  // ── Constants ──────────────────────────────────────────────────────────
  static const _orange = Color(0xFFFF6B00);
  static const _green = Color(0xFF10B981);
  static const _dark = Color(0xFF111827);
  static const _grey = Color(0xFF6B7280);
  static const _bgColor = Color(0xFFE1EAE4);
  static const _divider = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addObserver(this);
    _loadNotifications();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
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

  // ── Filtered list for the current tab ─────────────────────────────────
  List<AppNotification> get _filtered {
    final category = _tabs[_tabController.index];
    if (category == NotificationCategory.unread) {
      return _all.where((n) => !n.isRead).toList();
    }
    final filters = category.typeFilters;
    if (filters == null) return _all;
    return _all.where((n) => filters.contains(n.type)).toList();
  }

  // ── Data fetching ──────────────────────────────────────────────────────
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _service.getMyNotifications(limit: 50);
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() {
        _all
          ..clear()
          ..addAll(result.data!.items);
        _unreadCount = result.data!.unreadCount;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.error ?? 'Failed to load notifications';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshSilently() async {
    final result = await _service.getMyNotifications(limit: 50);
    if (!mounted || !result.isSuccess || result.data == null) return;
    setState(() {
      _all
        ..clear()
        ..addAll(result.data!.items);
      _unreadCount = result.data!.unreadCount;
      _error = null;
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────

  /// Tap: mark single notification as read (optimistic update).
  Future<void> _onTapNotification(AppNotification notif) async {
    // Deep-link routing based on payload data
    await _handleDeepLink(notif);

    if (notif.isRead) return;
    final index = _all.indexWhere((n) => n.id == notif.id);
    if (index == -1) return;

    setState(() {
      _all[index] = notif.copyWith(isRead: true);
      if (_unreadCount > 0) _unreadCount -= 1;
    });

    final result = await _service.markRead(notif.id);
    if (!mounted) return;
    if (!result.isSuccess) {
      // Roll back optimistic update on failure.
      setState(() {
        _all[index] = notif.copyWith(isRead: false);
        _unreadCount += 1;
      });
      _showSnack('Could not mark as read. Try again.');
    }
  }

  /// Swipe-to-dismiss / button: delete single notification (optimistic).
  Future<void> _deleteNotification(AppNotification notif) async {
    final index = _all.indexWhere((n) => n.id == notif.id);
    if (index == -1) return;

    // Optimistic remove
    setState(() {
      _all.removeAt(index);
      if (!notif.isRead && _unreadCount > 0) _unreadCount -= 1;
    });

    final result = await _service.deleteNotification(notif.id);
    if (!mounted) return;
    if (!result.isSuccess) {
      // Restore on failure
      setState(() {
        _all.insert(index, notif);
        if (!notif.isRead) _unreadCount += 1;
      });
      _showSnack(result.error ?? 'Could not delete notification.');
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
    } else {
      setState(() => _isMarkingAll = false);
      _showSnack(result.error ?? 'Failed to update notifications');
    }
  }

  /// Bulk delete all READ notifications → "Clear read" action.
  Future<void> _clearReadNotifications() async {
    final readIds = _all.where((n) => n.isRead).map((n) => n.id).toList();
    if (readIds.isEmpty) {
      _showSnack('No read notifications to clear.');
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Read Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete ${readIds.length} read notification${readIds.length > 1 ? 's' : ''}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.redAccent),
            ),
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

  // ── Deep Link Routing ──────────────────────────────────────────────────

  /// Inspects `notification.data` and navigates to the relevant screen.
  /// Enterprise pattern: all notification types have a `target` key.
  Future<void> _handleDeepLink(AppNotification notif) async {
    final target = notif.deepLinkTarget;
    if (target == null) return;

    final data = notif.data ?? {};

    switch (target) {
      case 'post':
        final postId = data['postId'];
        if (postId != null) {
          _showSnack('Opening post #$postId…', isSuccess: true);
          // Navigator.push(context, MaterialPageRoute(
          //   builder: (_) => PostDetailScreen(postId: postId),
          // ));
        }
        break;
      case 'profile':
        final userId = data['userId'];
        if (userId != null) {
          _showSnack('Opening profile…', isSuccess: true);
          // Navigator.push(context, MaterialPageRoute(
          //   builder: (_) => UserProfileScreen(userId: userId),
          // ));
        }
        break;
      case 'chat':
        final chatId = int.tryParse(data['chatId']?.toString() ?? '');
        if (chatId != null && chatId > 0) {
          final userId = await AuthService().getUserId();
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatWindowScreen(
                chatId: chatId,
                chatName: data['chatName']?.toString() ?? 'Chat',
                currentUserId: userId ?? 0,
                isOnline: false,
              ),
            ),
          );
        }
        break;
      case 'community':
        final communityId = int.tryParse(data['communityId']?.toString() ?? '');
        if (communityId != null && communityId > 0) {
          try {
            final community = await CommunityService().getCommunityDetails(
              communityId,
            );
            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommunityDetailScreen(community: community),
              ),
            );
          } catch (error) {
            _showSnack(error.toString());
          }
        }
        break;
      default:
        break;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

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

  ({IconData icon, Color color}) _visualsFor(String type) {
    switch (type) {
      case 'alert':
        return (icon: Icons.warning_amber_rounded, color: _orange);
      case 'reminder':
        return (icon: Icons.event_note_outlined, color: Colors.blueGrey);
      case 'message':
        return (
          icon: Icons.chat_bubble_outline,
          color: const Color(0xFF3B82F6),
        );
      case 'system':
        return (icon: Icons.settings_suggest_outlined, color: Colors.grey);
      case 'like':
        return (icon: Icons.favorite_border_rounded, color: Colors.pinkAccent);
      case 'comment':
        return (icon: Icons.comment_outlined, color: const Color(0xFF8B5CF6));
      case 'follow':
        return (icon: Icons.person_add_outlined, color: _green);
      default:
        return (icon: Icons.notifications_none_rounded, color: _green);
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final readCount = _all.where((n) => n.isRead).length;
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(readCount),
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
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        // Mark all read
        if (_isMarkingAll || _isClearingRead)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
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
        // 3-dot overflow menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: _dark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'clear_read') _clearReadNotifications();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'clear_read',
              enabled: readCount > 0,
              child: Row(
                children: [
                  Icon(
                    Icons.delete_sweep_outlined,
                    size: 20,
                    color: readCount > 0 ? Colors.redAccent : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Clear read ($readCount)',
                    style: TextStyle(
                      color: readCount > 0 ? Colors.redAccent : Colors.grey,
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
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _orange,
        unselectedLabelColor: _grey,
        indicatorColor: _orange,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: _tabs.map((t) {
          // Badge for Unread tab
          if (t == NotificationCategory.unread && _unreadCount > 0) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.label),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.circular(8),
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
              ),
            );
          }
          return Tab(text: t.label);
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final visible = _filtered;

    if (visible.isEmpty) {
      return RefreshIndicator(
        color: _green,
        onRefresh: _refreshSilently,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 100),
            const Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'You\'re all caught up',
                style: TextStyle(
                  color: _dark,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _tabs[_tabController.index] == NotificationCategory.unread
                    ? 'No unread notifications'
                    : 'No notifications in this category',
                style: const TextStyle(color: _grey, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _refreshSilently,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length,
        separatorBuilder: (_, idx) => const Divider(height: 1, color: _divider),
        itemBuilder: (context, index) => _buildNotificationTile(visible[index]),
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification notif) {
    final visuals = _visualsFor(notif.type);
    return Dismissible(
      key: ValueKey('notif_${notif.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withValues(alpha: 0.9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        // Light confirmation via snack with undo — no full dialog for swipe
        return true;
      },
      onDismissed: (_) => _deleteNotification(notif),
      child: InkWell(
        onTap: () => _onTapNotification(notif),
        child: Container(
          color: notif.isRead ? Colors.white : _orange.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: visuals.color.withValues(alpha: 0.15),
                child: Icon(visuals.icon, color: visuals.color, size: 20),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notif.title.isNotEmpty)
                      Text(
                        notif.title,
                        style: TextStyle(
                          color: _dark,
                          fontSize: 14,
                          fontWeight: notif.isRead
                              ? FontWeight.w600
                              : FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    if (notif.message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        notif.message,
                        style: TextStyle(
                          color: const Color(0xFF374151),
                          fontSize: 13,
                          fontWeight: notif.isRead
                              ? FontWeight.normal
                              : FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          _formatTime(notif.createdAt),
                          style: TextStyle(
                            color: notif.isRead ? Colors.grey : _orange,
                            fontSize: 11,
                            fontWeight: notif.isRead
                                ? FontWeight.normal
                                : FontWeight.w500,
                          ),
                        ),
                        // Deep-link indicator
                        if (notif.deepLinkTarget != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Tap to open',
                              style: TextStyle(
                                color: _green,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notif.data?['invitationId'] != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _respondToCommunityInvitation(
                              notif,
                              'decline',
                            ),
                            child: const Text('Decline'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _respondToCommunityInvitation(
                              notif,
                              'accept',
                            ),
                            child: const Text('Accept'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Unread dot
              if (!notif.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 6, left: 8),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
