import 'dart:async';

import 'package:flutter/material.dart';
import 'feed_service.dart';
import 'models/feed_post_model.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/custom_drawer.dart';
import '../core/notification_service.dart';
import '../core/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _service = FeedService();
  final _notificationService = NotificationService();
  Timer? _feedSyncTimer;
  Timer? _notifTimer;
  bool _isSyncingFeed = false;
  int _unreadNotifications = 0;

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMsg = '';
  String _locationName = 'Your neighbourhood';
  double? _userLat;
  double? _userLon;
  List<FeedNotice> _notices = [];
  List<FeedPost> _posts = [];

  // ── Live-geocoded location label ─────────────────────────────────
  bool _isGeocodingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFeed();
    _startFeedSync();
    _refreshUnreadCount();
    _startNotificationSync();
  }

  void _startFeedSync() {
    _feedSyncTimer?.cancel();
    _feedSyncTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _syncCommentCounts(),
    );
  }

  void _startNotificationSync() {
    _notifTimer?.cancel();
    _notifTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshUnreadCount(),
    );
  }

  Future<void> _refreshUnreadCount() async {
    final count = await _notificationService.getUnreadCount();
    if (!mounted || count == null || count == _unreadNotifications) return;
    setState(() => _unreadNotifications = count);
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _refreshUnreadCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startFeedSync();
      _syncCommentCounts();
      _startNotificationSync();
      _refreshUnreadCount();
    } else {
      _feedSyncTimer?.cancel();
      _notifTimer?.cancel();
    }
  }

  Future<void> _syncCommentCounts() async {
    if (_isLoading || _isSyncingFeed || !mounted) return;
    _isSyncingFeed = true;
    final result = await _service.getHomeFeed();
    if (!mounted) return;

    if (result.isSuccess) {
      final timeline = (result.data?['timeline'] as List?) ?? [];
      final liveCounts = <int, int>{};
      for (final item in timeline) {
        if (item is! Map) continue;
        final id = int.tryParse(item['id'].toString());
        final count = int.tryParse(item['commentsCount'].toString());
        if (id != null && count != null) liveCounts[id] = count;
      }

      var changed = false;
      for (final post in _posts) {
        final count = liveCounts[post.id];
        if (count != null && count != post.commentsCount) {
          post.commentsCount = count;
          changed = true;
        }
      }
      if (changed) setState(() {});
    }
    _isSyncingFeed = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feedSyncTimer?.cancel();
    _notifTimer?.cancel();
    super.dispose();
  }

  // ── Load Feed ────────────────────────────────────────────────────
  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final result = await _service.getHomeFeed();
    if (!mounted) return;

    if (result.isSuccess) {
      final data = result.data!;
      final notices = ((data['notices'] as List?) ?? [])
          .map((n) => FeedNotice.fromJson(n as Map<String, dynamic>))
          .toList();
      final posts = ((data['timeline'] as List?) ?? [])
          .map((p) => FeedPost.fromJson(p as Map<String, dynamic>))
          .toList();

      setState(() {
        _locationName = data['locationName'] ?? 'Your neighbourhood';
        _userLat = data['userLat'] != null
            ? double.tryParse(data['userLat'].toString())
            : null;
        _userLon = data['userLon'] != null
            ? double.tryParse(data['userLon'].toString())
            : null;
        _notices = notices;
        _posts = posts;
        _isLoading = false;
      });

      // Reverse geocode in background for human-readable name
      if (_userLat != null && _userLon != null) {
        _reverseGeocode(_userLat!, _userLon!);
      }
    } else {
      setState(() {
        _hasError = true;
        _errorMsg = result.error ?? 'Unknown error';
        _isLoading = false;
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    if (_isGeocodingLocation) return;
    setState(() => _isGeocodingLocation = true);
    final name = await _service.reverseGeocode(lat, lon);
    if (mounted) {
      setState(() {
        _locationName = name;
        _isGeocodingLocation = false;
      });
    }
  }

  // ── Open Comments ────────────────────────────────────────────────
  void _openComments(FeedPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        post: post,
        service: _service,
        onCommentCountChanged: (count) {
          if (mounted && post.commentsCount != count) {
            setState(() => post.commentsCount = count);
          }
        },
      ),
    );
  }

  // ── Open Create Post ─────────────────────────────────────────────
  void _openCreatePost() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePostSheet(
        service: _service,
        onPosted: (newPost) {
          setState(() => _posts.insert(0, newPost));
        },
      ),
    );
  }

  // ── Share Post ───────────────────────────────────────────────────
  void _sharePost(FeedPost post) {
    final text =
        '📍 ${post.authorName} on smartgali:\n"${post.content}"\n\nJoin smartgali for hyperlocal updates!';
    SharePlus.instance.share(ShareParams(text: text));
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Just now';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0EC),
      drawer: const CustomDrawer(),
      appBar: _buildAppBar(),
      body: _isLoading
          ? _buildLoader()
          : _hasError
          ? _buildError()
          : RefreshIndicator(
              color: const Color(0xFF10B981),
              onRefresh: _loadFeed,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  if (_notices.isNotEmpty) ...[
                    _NoticeCard(notice: _notices[0]),
                    const SizedBox(height: 14),
                  ],
                  _CreatePostBar(onTap: _openCreatePost),
                  const SizedBox(height: 20),
                  if (_posts.isEmpty)
                    _buildEmptyState()
                  else
                    ..._posts.map((post) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        key: ValueKey(post.id),
                        child: _PostCard(
                          post: post,
                          service: _service,
                          formatTime: _formatTime,
                          onComment: () => _openComments(post),
                          onShare: () => _sharePost(post),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Color(0xFF111827)),
      actions: [
        IconButton(
          onPressed: _openNotifications,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF111827),
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B00),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      _unreadNotifications > 99
                          ? '99+'
                          : '$_unreadNotifications',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: Color(0xFFFF8A00),
            size: 20,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _locationName,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isGeocodingLocation) ...[
            const SizedBox(width: 6),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF10B981)),
          SizedBox(height: 16),
          Text(
            'Loading your neighbourhood feed...',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load feed',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _loadFeed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_outlined,
              size: 52,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Be the first to post!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No posts in your 5km area yet.\nShare something with your neighbours!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7280), height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Notice Card ──────────────────────────────────────────────────────────────
class _NoticeCard extends StatelessWidget {
  final FeedNotice notice;
  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8EE), Color(0xFFFEEFD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Color(0xFFFF8A00),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notice.scheduledTime ?? notice.content,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Post Bar ──────────────────────────────────────────────────────────
class _CreatePostBar extends StatelessWidget {
  final VoidCallback onTap;
  const _CreatePostBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFE5E7EB),
              child: Icon(Icons.person, color: Color(0xFF9CA3AF), size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Share something with your neighbours...',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.image_outlined,
                color: Color(0xFF10B981),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Post Card (StatefulWidget — owns isolated like state) ────────────────────
// Enterprise pattern: card manages its own like/count state so only
// THIS card rebuilds on like — not the whole feed list.
class _PostCard extends StatefulWidget {
  final FeedPost post;
  final FeedService service;
  final String Function(String?) formatTime;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _PostCard({
    required this.post,
    required this.service,
    required this.formatTime,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  // ── Local like state — decoupled from parent ──────────────────────
  late bool _isLiked;
  late int _likeCount;

  // ── Guards ───────────────────────────────────────────────────────
  bool _isPending = false; // block concurrent API calls

  // ── Animation ────────────────────────────────────────────────────
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _likeCount = widget.post.likesCount;

    // Spring-like scale animation for like button
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.35,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  // ── Enterprise like handler ───────────────────────────────────────
  // Pattern: Optimistic update → API call → server-sync or rollback
  // Guard: _isPending prevents overlapping calls from rapid taps
  Future<void> _handleLike() async {
    if (_isPending) return; // ← guard: ignore tap if call in-flight

    // 1. Snapshot current state BEFORE mutation (avoids same-ref bug)
    final wasLiked = _isLiked;
    final prevCount = _likeCount;
    final optimisticCount = wasLiked ? prevCount - 1 : prevCount + 1;

    // 2. Optimistic UI — update immediately with correct values
    setState(() {
      _isLiked = !wasLiked;
      _likeCount = optimisticCount;
      _isPending = true;
    });

    // 3. Spring animation: scale up then back
    await _scaleCtrl.forward();
    _scaleCtrl.reverse();

    // 4. API call
    final result = await widget.service.toggleLike(widget.post.id);
    if (!mounted) return;

    setState(() => _isPending = false);

    if (!result.isSuccess) {
      // 5a. Rollback to snapshot on failure
      setState(() {
        _isLiked = wasLiked;
        _likeCount = prevCount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Could not update like'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // 5b. Server-sync: trust the DB-confirmed count (from post.reload())
      final serverCount = result.data?['likesCount'];
      final serverIsLiked = result.data?['isLikedByMe'] as bool?;
      setState(() {
        if (serverCount != null) {
          _likeCount = serverCount is int
              ? serverCount
              : int.tryParse(serverCount.toString()) ?? _likeCount;
        }
        if (serverIsLiked != null) _isLiked = serverIsLiked;
      });
      // Also sync parent model so refresh doesn't flicker
      widget.post.isLikedByMe = _isLiked;
      widget.post.likesCount = _likeCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _avatarColor(widget.post.authorName),
                  child: Text(
                    _initials(widget.post.authorName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        widget.formatTime(widget.post.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz, color: Color(0xFFD1D5DB)),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              widget.post.content,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 14.5,
                height: 1.55,
              ),
            ),
          ),
          // Image
          if (widget.post.mediaUrl != null &&
              widget.post.mediaUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
              child: Image.network(
                widget.post.mediaUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  height: 120,
                  color: const Color(0xFFF3F4F6),
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Color(0xFFD1D5DB),
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Action Row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // ── Like button with animation + pending guard ──
                    _LikeButton(
                      isLiked: _isLiked,
                      count: _likeCount,
                      isPending: _isPending,
                      scaleAnim: _scaleAnim,
                      onTap: _handleLike,
                    ),
                    const SizedBox(width: 4),
                    _ActionBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '${widget.post.commentsCount}',
                      color: const Color(0xFF9CA3AF),
                      onTap: widget.onComment,
                    ),
                  ],
                ),
                _ActionBtn(
                  icon: Icons.ios_share_outlined,
                  label: 'Share',
                  color: const Color(0xFF9CA3AF),
                  onTap: widget.onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Safe initial letter for avatar ──────────────────────────────
  String _initials(dynamic name) {
    final s = name?.toString() ?? '';
    return s.isNotEmpty ? s[0].toUpperCase() : 'N';
  }

  Color _avatarColor(dynamic name) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];
    final s = name?.toString() ?? '';
    final idx = s.isEmpty ? 0 : s.codeUnitAt(0) % colors.length;
    return colors[idx];
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Like Button — animated, pending-aware ─────────────────────────────────
// Uses ScaleTransition for spring effect; dims during pending API call.
class _LikeButton extends StatelessWidget {
  final bool isLiked;
  final int count;
  final bool isPending;
  final Animation<double> scaleAnim;
  final VoidCallback onTap;

  const _LikeButton({
    required this.isLiked,
    required this.count,
    required this.isPending,
    required this.scaleAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFEF4444); // red when liked
    final inactiveColor = const Color(0xFF9CA3AF); // grey when not liked
    final color = isLiked ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: isPending ? null : onTap, // block tap while pending
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            ScaleTransition(
              scale: scaleAnim,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: isPending
                    ? SizedBox(
                        key: const ValueKey('loader'),
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color.withValues(alpha: 0.5),
                        ),
                      )
                    : Icon(
                        isLiked
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        key: ValueKey(isLiked),
                        size: 19,
                        color: color,
                      ),
              ),
            ),
            const SizedBox(width: 5),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: isLiked ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text('$count'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comments Bottom Sheet ─────────────────────────────────────────────────────
class _CommentsSheet extends StatefulWidget {
  final FeedPost post;
  final FeedService service;
  final ValueChanged<int> onCommentCountChanged;

  const _CommentsSheet({
    required this.post,
    required this.service,
    required this.onCommentCountChanged,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = true;
  bool _posting = false;
  bool _refreshing = false;
  List<FeedComment> _comments = [];
  Timer? _commentsSyncTimer;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _commentsSyncTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadComments(),
    );
  }

  Future<void> _loadComments() async {
    if (_refreshing) return;
    _refreshing = true;
    final result = await widget.service.getComments(widget.post.id);
    if (!mounted) return;
    final comments = result.data;
    setState(() {
      if (comments != null) _comments = comments;
      _loading = false;
      _refreshing = false;
    });
    if (comments != null) {
      widget.post.commentsCount = comments.length;
      widget.onCommentCountChanged(comments.length);
    }
  }

  Future<void> _postComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    final result = await widget.service.addComment(
      postId: widget.post.id,
      content: text,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      _ctrl.clear();
      _focusNode.unfocus();
      final newCount = _comments.length + 1;
      widget.post.commentsCount = newCount;
      widget.onCommentCountChanged(newCount);
      setState(() {
        _comments.insert(0, result.data!);
        _posting = false;
      });
    } else {
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to post comment'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _commentsSyncTimer?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Just now';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.post.commentsCount}',
                  style: const TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          // List
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  )
                : _comments.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: Color(0xFFE5E7EB),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF10B981),
                              child: Text(
                                () {
                                  final n = c.authorName.toString();
                                  return n.isNotEmpty
                                      ? n[0].toUpperCase()
                                      : 'U';
                                }(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c.authorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTime(c.createdAt),
                                        style: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      c.content,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        color: Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: 8 + bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 8),
                _posting
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF10B981),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Color(0xFF10B981),
                        ),
                        onPressed: _postComment,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Post Bottom Sheet ──────────────────────────────────────────────────
class _CreatePostSheet extends StatefulWidget {
  final FeedService service;
  final Function(FeedPost) onPosted;

  const _CreatePostSheet({required this.service, required this.onPosted});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _ctrl = TextEditingController();
  bool _posting = false;

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);

    final result = await widget.service.createPost(content: text);
    if (!mounted) return;

    if (result.isSuccess) {
      widget.onPosted(result.data!);
      Navigator.pop(context);
    } else {
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to post'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Create Post',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: "What's happening in your neighbourhood?",
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _posting
                      ? const SizedBox.shrink()
                      : const Icon(Icons.send_rounded),
                  label: _posting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Post to neighbourhood'),
                  onPressed: _posting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
