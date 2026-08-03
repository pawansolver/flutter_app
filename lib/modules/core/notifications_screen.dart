import 'dart:async';

import 'package:flutter/material.dart';

import 'notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  final NotificationService _service = NotificationService();

  final List<AppNotification> _notifications = [];
  bool _isLoading = true;
  bool _isMarkingAll = false;
  String? _error;
  int _unreadCount = 0;

  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotifications();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await _service.getMyNotifications();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() {
        _notifications
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

  /// Background refresh used by the poller and pull-to-refresh; never flips the
  /// screen into the full-screen loading/error state.
  Future<void> _refreshSilently() async {
    final result = await _service.getMyNotifications();
    if (!mounted || !result.isSuccess || result.data == null) return;
    setState(() {
      _notifications
        ..clear()
        ..addAll(result.data!.items);
      _unreadCount = result.data!.unreadCount;
      _error = null;
    });
  }

  Future<void> _onTapNotification(AppNotification notif) async {
    if (notif.isRead) return;
    final index = _notifications.indexWhere((n) => n.id == notif.id);
    if (index == -1) return;

    setState(() {
      _notifications[index] = notif.copyWith(isRead: true);
      if (_unreadCount > 0) _unreadCount -= 1;
    });

    final result = await _service.markRead(notif.id);
    if (!mounted) return;
    if (!result.isSuccess) {
      // Roll back the optimistic update on failure.
      setState(() {
        _notifications[index] = notif.copyWith(isRead: false);
        _unreadCount += 1;
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_isMarkingAll || _unreadCount == 0) return;
    setState(() => _isMarkingAll = true);

    final result = await _service.markAllRead();
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        for (var i = 0; i < _notifications.length; i++) {
          if (!_notifications[i].isRead) {
            _notifications[i] = _notifications[i].copyWith(isRead: true);
          }
        }
        _unreadCount = 0;
        _isMarkingAll = false;
      });
    } else {
      setState(() => _isMarkingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to update notifications')),
      );
    }
  }

  ({IconData icon, Color color}) _visualsFor(String type) {
    switch (type) {
      case 'alert':
        return (icon: Icons.warning_amber_rounded, color: const Color(0xFFFF6B00));
      case 'reminder':
        return (icon: Icons.event_note_outlined, color: Colors.blueGrey);
      case 'message':
        return (icon: Icons.chat_bubble_outline, color: const Color(0xFF3B82F6));
      case 'system':
        return (icon: Icons.settings_suggest_outlined, color: Colors.grey);
      default:
        return (icon: Icons.notifications_none_rounded, color: const Color(0xFF10B981));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00),
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
          if (_isMarkingAll)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _unreadCount > 0 ? _markAllRead : null,
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: _unreadCount > 0 ? const Color(0xFFFF6B00) : Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
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
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF10B981),
        onRefresh: _refreshSilently,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey),
            SizedBox(height: 16),
            Center(
              child: Text(
                'You\'re all caught up',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 6),
            Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF10B981),
      onRefresh: _refreshSilently,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          final visuals = _visualsFor(notif.type);
          return InkWell(
            onTap: () => _onTapNotification(notif),
            child: Container(
              color: notif.isRead
                  ? Colors.white
                  : const Color(0xFFFF6B00).withValues(alpha: 0.05),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: visuals.color.withValues(alpha: 0.15),
                    child: Icon(visuals.icon, color: visuals.color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notif.title.isNotEmpty)
                          Text(
                            notif.title,
                            style: TextStyle(
                              color: const Color(0xFF111827),
                              fontSize: 15,
                              fontWeight:
                                  notif.isRead ? FontWeight.w600 : FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        if (notif.message.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            notif.message,
                            style: TextStyle(
                              color: const Color(0xFF374151),
                              fontSize: 14,
                              fontWeight:
                                  notif.isRead ? FontWeight.normal : FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          _formatTime(notif.createdAt),
                          style: TextStyle(
                            color: notif.isRead
                                ? Colors.grey
                                : const Color(0xFFFF6B00),
                            fontSize: 12,
                            fontWeight:
                                notif.isRead ? FontWeight.normal : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notif.isRead)
                    Container(
                      margin: const EdgeInsets.only(top: 6, left: 8),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF6B00),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
