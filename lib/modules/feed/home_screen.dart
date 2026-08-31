import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/custom_drawer.dart';
import '../core/notification_service.dart';
import '../core/notifications_screen.dart';
import '../profile/user_profile_screen.dart'; // PRD Phase 8: Follow system
import 'feed_service.dart';
import 'models/feed_post_model.dart';
import 'post_composer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _service = FeedService();
  final _notificationService = NotificationService();
  int? _currentUserId; // For author vs viewer context in PostCard
  Timer? _feedSyncTimer;
  Timer? _notifTimer;
  Timer? _batchViewFlushTimer;
  final Set<int> _recordedViewPostIds = {};
  final List<Map<String, dynamic>> _pendingViews = [];
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
    _loadCurrentUser();
    _loadFeed();
    _startFeedSync();
    _refreshUnreadCount();
    _startNotificationSync();
    _startBatchViewFlush();
  }

  void _startBatchViewFlush() {
    _batchViewFlushTimer?.cancel();
    _batchViewFlushTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _flushPendingViews(),
    );
  }

  void _onPostViewed(int postId, int dwellMs) {
    if (_recordedViewPostIds.contains(postId)) return;
    _recordedViewPostIds.add(postId);
    _pendingViews.add({'postId': postId, 'dwellMs': dwellMs});
    if (_pendingViews.length >= 8) {
      _flushPendingViews();
    }
  }

  Future<void> _flushPendingViews() async {
    if (_pendingViews.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_pendingViews);
    _pendingViews.clear();
    await _service.recordBatchViews(batch);
  }

  Future<void> _loadCurrentUser() async {
    // Read userId from JWT stored in secure storage
    final storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    if (token == null) return;
    try {
      // Decode JWT payload (no verification needed - just reading our own value)
      final parts = token.split('.');
      if (parts.length != 3) return;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> map = json.decode(decoded);
      final uid = map['id'] ?? map['userId'] ?? map['sub'];
      if (uid != null && mounted) {
        setState(() => _currentUserId = int.tryParse(uid.toString()));
      }
    } catch (_) {}
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostComposerScreen(
          service: _service,
          onPosted: (newPost) {
            setState(() => _posts.insert(0, newPost));
          },
        ),
      ),
    );
  }

  // ── Share Post ───────────────────────────────────────────────────
  Future<void> _sharePost(FeedPost post) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShareOptionsBottomSheet(
        post: post,
        service: _service,
        currentUserId: _currentUserId,
        onShared: () {
          if (mounted) {
            setState(() {
              post.shareCount++;
            });
          }
        },
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Just now';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
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
                          currentUserId: _currentUserId,
                          onPostViewed: _onPostViewed,
                          onComment: () async => _openComments(post),
                          onShare: () => _sharePost(post),
                          onDeleted: () => setState(
                            () => _posts.removeWhere((p) => p.id == post.id),
                          ),
                          onHideUserPosts: (authorId) => setState(
                            () => _posts.removeWhere(
                              (p) => p.authorUserId == authorId,
                            ),
                          ),
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
  final int? currentUserId;
  final void Function(int postId, int dwellMs)? onPostViewed;
  final Future<void> Function() onComment;
  final Future<void> Function() onShare;
  final VoidCallback? onDeleted;
  final void Function(int userId)? onHideUserPosts;

  const _PostCard({
    required this.post,
    required this.service,
    required this.formatTime,
    this.currentUserId,
    this.onPostViewed,
    required this.onComment,
    required this.onShare,
    this.onDeleted,
    this.onHideUserPosts,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard>
    with SingleTickerProviderStateMixin {
  // Enterprise: all counters tracked locally with optimistic updates
  late bool _isLiked;
  late int _likeCount;
  late int _commentCount;
  late int _shareCount;
  late bool _isSaved;

  bool _likePending = false;
  bool _savePending = false;
  Timer? _dwellTimer;

  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _syncFromPost();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));

    // Enterprise MRC Standard: 1.2s dwell timer for non-author viewers
    if (widget.currentUserId != null &&
        widget.post.authorUserId != null &&
        widget.currentUserId != widget.post.authorUserId) {
      _dwellTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          widget.onPostViewed?.call(widget.post.id, 1200);
        }
      });
    }
  }

  @override
  void didUpdateWidget(_PostCard old) {
    super.didUpdateWidget(old);
    if (old.post.id != widget.post.id ||
        old.post.shareCount != widget.post.shareCount ||
        old.post.commentsCount != widget.post.commentsCount ||
        old.post.likesCount != widget.post.likesCount ||
        old.post.isSaved != widget.post.isSaved ||
        old.post.isLikedByMe != widget.post.isLikedByMe) {
      _syncFromPost();
    }
  }

  void _syncFromPost() {
    _isLiked = widget.post.isLikedByMe;
    _likeCount = widget.post.likesCount;
    _commentCount = widget.post.commentsCount;
    _shareCount = widget.post.shareCount;
    _isSaved = widget.post.isSaved;
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _scaleCtrl.dispose();
    super.dispose();
  }

  // Enterprise Like: Optimistic UI -> API -> Server-sync / Rollback
  Future<void> _handleLike() async {
    if (_likePending) return;
    final wasLiked = _isLiked;
    final prevCount = _likeCount;
    setState(() {
      _isLiked = !wasLiked;
      _likeCount = wasLiked ? prevCount - 1 : prevCount + 1;
      _likePending = true;
    });
    _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());
    final result = await widget.service.toggleLike(
      widget.post.id,
      isCurrentlyLiked: wasLiked,
    );
    if (!mounted) return;
    setState(() => _likePending = false);
    if (!result.isSuccess) {
      setState(() {
        _isLiked = wasLiked;
        _likeCount = prevCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Could not like post'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final sc = result.data?['likesCount'];
      final sl = result.data?['isLikedByMe'];
      setState(() {
        if (sc != null) {
          _likeCount = sc is int
              ? sc
              : int.tryParse(sc.toString()) ?? _likeCount;
        }
        if (sl is bool) _isLiked = sl;
      });
      widget.post.isLikedByMe = _isLiked;
      widget.post.likesCount = _likeCount;
    }
  }

  Future<void> _handleSave() async {
    if (_savePending) return;
    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !wasSaved;
      _savePending = true;
    });
    widget.post.isSaved = _isSaved;
    final result = await widget.service.toggleSavePost(
      widget.post.id,
      isCurrentlySaved: wasSaved,
    );
    if (!mounted) return;
    setState(() => _savePending = false);
    if (!result.isSuccess) {
      setState(() {
        _isSaved = wasSaved;
      });
      widget.post.isSaved = wasSaved;
      _showToast(
        result.error ?? 'Could not update saved status',
        isError: true,
      );
    } else {
      _showToast(
        _isSaved
            ? 'Post saved to your bookmarks'
            : 'Post removed from bookmarks',
      );
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red.shade600
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openContextMenu() async {
    final bool isAuthor =
        (widget.currentUserId != null &&
        widget.post.authorUserId != null &&
        widget.currentUserId == widget.post.authorUserId);

    final action = await showModalBottomSheet<_ContextMenuAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          _PostContextMenuSheet(post: widget.post, isAuthor: isAuthor),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case _ContextMenuAction.edit:
        await _handleEditPost();
        break;
      case _ContextMenuAction.pin:
        await _handleTogglePin();
        break;
      case _ContextMenuAction.toggleComments:
        await _handleToggleComments();
        break;
      case _ContextMenuAction.insights:
        _handleShowInsights();
        break;
      case _ContextMenuAction.privacy:
        await _handleShowPrivacy();
        break;
      case _ContextMenuAction.save:
        await _handleSave();
        break;
      case _ContextMenuAction.copyLink:
        _handleCopyLink();
        break;
      case _ContextMenuAction.delete:
        await _handleDeletePost();
        break;
      case _ContextMenuAction.unfollow:
        await _handleUnfollowUser();
        break;
      case _ContextMenuAction.mute:
        await _handleMuteUser();
        break;
      case _ContextMenuAction.block:
        await _handleBlockUser();
        break;
      case _ContextMenuAction.report:
        _handleReportPost();
        break;
      case _ContextMenuAction.share:
        // Enterprise: 3-dot Share routes through full _handleShare which also records to backend
        await _handleShare();
        break;
    }
  }

  // ── 1. Edit Post ──────────────────────────────────────────────────
  Future<void> _handleEditPost() async {
    final ctrl = TextEditingController(text: widget.post.content);
    final updatedText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 5,
                minLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Edit your post content...',
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

    if (updatedText != null && updatedText.isNotEmpty && mounted) {
      final oldContent = widget.post.content;
      final oldEdited = widget.post.isEdited;
      setState(() {
        widget.post.content = updatedText;
        widget.post.isEdited = true;
      });
      final res = await widget.service.editPost(
        widget.post.id,
        content: updatedText,
      );
      if (!mounted) return;
      if (res.isSuccess) {
        _showToast('Post updated successfully');
      } else {
        setState(() {
          widget.post.content = oldContent;
          widget.post.isEdited = oldEdited;
        });
        _showToast(res.error ?? 'Could not update post', isError: true);
      }
    }
  }

  // ── 2. Pin / Unpin Post ───────────────────────────────────────────
  Future<void> _handleTogglePin() async {
    final targetState = !widget.post.isPinned;
    setState(() {
      widget.post.isPinned = targetState;
    });
    final res = await widget.service.togglePinPost(widget.post.id);
    if (!mounted) return;
    if (res.isSuccess) {
      _showToast(
        widget.post.isPinned
            ? 'Post pinned to top of profile'
            : 'Post unpinned from profile',
      );
    } else {
      setState(() {
        widget.post.isPinned = !targetState;
      });
      _showToast(res.error ?? 'Failed to update pin status', isError: true);
    }
  }

  // ── 3. Turn Comments Off / On ─────────────────────────────────────
  Future<void> _handleToggleComments() async {
    final targetState = !widget.post.commentsDisabled;
    setState(() {
      widget.post.commentsDisabled = targetState;
    });
    final res = await widget.service.toggleComments(widget.post.id);
    if (!mounted) return;
    if (res.isSuccess) {
      _showToast(
        widget.post.commentsDisabled
            ? 'Comments turned off for this post'
            : 'Comments turned on for this post',
      );
    } else {
      setState(() {
        widget.post.commentsDisabled = !targetState;
      });
      _showToast(
        res.error ?? 'Failed to update comment settings',
        isError: true,
      );
    }
  }

  // ── 4. Post Insights & Analytics ──────────────────────────────────
  void _handleShowInsights() {
    final insightsFuture = widget.service.getPostInsights(widget.post.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.analytics_outlined, color: Color(0xFF6366F1), size: 24),
            SizedBox(width: 8),
            Text(
              'Post Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: FutureBuilder<FeedResult<Map<String, dynamic>>>(
          future: insightsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 160,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF6366F1),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Fetching live analytics...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data?.data ?? {};
            final reach = data['reach'] ?? 0;
            final impressions = data['impressions'] ?? 0;
            final likes = data['likesCount'] ?? widget.post.likesCount;
            final comments = data['commentsCount'] ?? widget.post.commentsCount;
            final shares = data['sharesCount'] ?? widget.post.shareCount;
            final saves = data['savesCount'] ?? 0;
            final rate = data['engagementRate'] ?? '0.0%';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InsightItem(
                  icon: Icons.people_alt_outlined,
                  color: const Color(0xFF3B82F6),
                  label: 'Unique Reach (People)',
                  value: '$reach',
                ),
                const SizedBox(height: 8),
                _InsightItem(
                  icon: Icons.remove_red_eye_outlined,
                  color: const Color(0xFF0EA5E9),
                  label: 'Total Impressions / Views',
                  value: '$impressions',
                ),
                const SizedBox(height: 8),
                _InsightItem(
                  icon: Icons.favorite,
                  color: Colors.redAccent,
                  label: 'Likes (Real DB)',
                  value: '$likes',
                ),
                const SizedBox(height: 8),
                _InsightItem(
                  icon: Icons.chat_bubble,
                  color: const Color(0xFF6366F1),
                  label: 'Comments (Real DB)',
                  value: '$comments',
                ),
                const SizedBox(height: 8),
                _InsightItem(
                  icon: Icons.reply,
                  color: const Color(0xFF10B981),
                  label: 'Shares (Real DB)',
                  value: '$shares',
                ),
                const SizedBox(height: 8),
                _InsightItem(
                  icon: Icons.bookmark,
                  color: const Color(0xFFF59E0B),
                  label: 'Saves / Bookmarks',
                  value: '$saves',
                ),
                const SizedBox(height: 8),
                _InsightItem(
                  icon: Icons.trending_up,
                  color: const Color(0xFF8B5CF6),
                  label: 'Engagement Rate',
                  value: '$rate',
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Change Audience / Privacy ──────────────────────────────────
  Future<void> _handleShowPrivacy() async {
    String current = widget.post.visibility;
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Change Post Audience',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.public, color: Color(0xFF10B981)),
                title: const Text(
                  'Public',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Anyone on or off smartgali can see this post',
                ),
                trailing: current == 'public'
                    ? const Icon(Icons.check, color: Color(0xFF10B981))
                    : null,
                onTap: () {
                  setSheetState(() => current = 'public');
                  Navigator.pop(bCtx, 'public');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.group_outlined,
                  color: Color(0xFF6366F1),
                ),
                title: const Text(
                  'Followers Only',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Only people who follow you can see this post',
                ),
                trailing: current == 'followers'
                    ? const Icon(Icons.check, color: Color(0xFF6366F1))
                    : null,
                onTap: () {
                  setSheetState(() => current = 'followers');
                  Navigator.pop(bCtx, 'followers');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF6B7280),
                ),
                title: const Text(
                  'Only Me',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Only visible to you (Private)'),
                trailing: current == 'private'
                    ? const Icon(Icons.check, color: Color(0xFF6B7280))
                    : null,
                onTap: () {
                  setSheetState(() => current = 'private');
                  Navigator.pop(bCtx, 'private');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (selected != null && selected != widget.post.visibility && mounted) {
      final oldVisibility = widget.post.visibility;
      setState(() {
        widget.post.visibility = selected;
      });
      final res = await widget.service.updateVisibility(
        widget.post.id,
        selected,
      );
      if (!mounted) return;
      if (res.isSuccess) {
        final label = selected == 'public'
            ? 'Public'
            : (selected == 'followers' ? 'Followers Only' : 'Only Me');
        _showToast('Audience changed to $label');
      } else {
        setState(() {
          widget.post.visibility = oldVisibility;
        });
        _showToast(res.error ?? 'Failed to change audience', isError: true);
      }
    }
  }

  // ── 6. Copy Link ──────────────────────────────────────────────────
  void _handleCopyLink() {
    Clipboard.setData(
      ClipboardData(text: 'https://smartgali.com/post/${widget.post.id}'),
    );
    _showToast('Post link copied to clipboard');
  }

  // ── 7. Delete Post ────────────────────────────────────────────────
  Future<void> _handleDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post?'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Enterprise: Call API FIRST, remove from feed ONLY on success
      final res = await widget.service.deletePost(widget.post.id);
      if (!mounted) return;
      if (res.isSuccess) {
        widget.onDeleted?.call(); // Remove from feed only after API confirms
        _showToast('Post deleted successfully');
      } else {
        _showToast(
          res.error ?? 'Failed to delete post. Please try again.',
          isError: true,
        );
      }
    }
  }

  // ── 8. Unfollow User ──────────────────────────────────────────────
  Future<void> _handleUnfollowUser() async {
    if (widget.post.authorUserId == null) return;
    final name = widget.post.authorUserName ?? widget.post.authorName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Unfollow @$name?'),
        content: const Text(
          "You won't see their posts in your home feed anymore.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // Enterprise: Show loading state via a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Unfollowing...'),
            ],
          ),
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final res = await widget.service.unfollowUser(widget.post.authorUserId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (res.isSuccess) {
        // Hide this user's posts from feed immediately (same as mute)
        widget.onHideUserPosts?.call(widget.post.authorUserId!);
        _showToast(
          'Unfollowed @$name. Their posts will no longer appear in your feed.',
        );
      } else {
        _showToast(
          res.error ?? 'Failed to unfollow. Please try again.',
          isError: true,
        );
      }
    }
  }

  // ── 9. Mute User ──────────────────────────────────────────────────
  Future<void> _handleMuteUser() async {
    final name = widget.post.authorUserName ?? widget.post.authorName;
    final authorId = widget.post.authorUserId;
    if (authorId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mute @$name?'),
        content: Text(
          "You won't see posts from @$name in your home feed anymore. They won't know you muted them.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Mute'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Muting user...'),
            ],
          ),
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final res = await widget.service.muteUser(authorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (res.isSuccess) {
        // Enterprise: Only hide posts from feed after API confirms mute
        widget.onHideUserPosts?.call(authorId);
        _showToast('Muted @$name. You won\'t see their posts anymore.');
      } else {
        _showToast(
          res.error ?? 'Failed to mute user. Please try again.',
          isError: true,
        );
      }
    }
  }

  // ── 10. Block User ────────────────────────────────────────────────
  Future<void> _handleBlockUser() async {
    final name = widget.post.authorUserName ?? widget.post.authorName;
    final authorId = widget.post.authorUserId;
    if (authorId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Block @$name?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("@$name will not be able to:"),
            const SizedBox(height: 8),
            const Text("• Find your profile or view your posts"),
            const Text("• Send you messages or follow you"),
            const Text("• Comment on your posts"),
            const SizedBox(height: 8),
            const Text(
              "You also won't see their content.",
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Text('Blocking user...'),
            ],
          ),
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final res = await widget.service.blockUser(authorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (res.isSuccess) {
        // Enterprise: Only hide posts from feed after API confirms block
        widget.onHideUserPosts?.call(authorId);
        _showToast('Blocked @$name. You won\'t see their content anymore.');
      } else {
        _showToast(
          res.error ?? 'Failed to block user. Please try again.',
          isError: true,
        );
      }
    }
  }

  // ── 11. Report Post ───────────────────────────────────────────────
  void _handleReportPost() {
    final reasons = [
      ('Spam or misleading', 'Fake promotions, repetitive content'),
      ('Harassment or bullying', 'Targeted abuse or personal attacks'),
      ('Hate speech or symbols', 'Content promoting discrimination'),
      ('False information or scam', 'Misinformation, fake news, fraud'),
      ('Violence or dangerous content', 'Graphic or threatening content'),
      ('Nudity or sexual content', 'Inappropriate explicit material'),
      ('Other', 'Something else not listed above'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          bool isSubmitting = false;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
                  child: Text(
                    'Report Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text(
                    'Select a reason for reporting this post. Your report is anonymous.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                  ),
                ),
                const Divider(height: 1),
                ...reasons.map(
                  ((String reason, String desc) r) => ListTile(
                    dense: true,
                    title: Text(
                      r.$1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      r.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    trailing: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6366F1),
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                    onTap: isSubmitting
                        ? null
                        : () async {
                            setSheetState(() => isSubmitting = true);
                            final res = await widget.service.reportPost(
                              widget.post.id,
                              reason: r.$1,
                            );
                            if (!mounted) return;
                            // Guard context use after async gap
                            if (bCtx.mounted) Navigator.pop(bCtx);
                            if (res.isSuccess) {
                              _showToast(
                                'Thank you for your report. Our team will review this post.',
                              );
                            } else {
                              _showToast(
                                res.error ??
                                    'Could not submit report. Please try again.',
                                isError: true,
                              );
                            }
                          },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 12. Share Post ────────────────────────────────────────────────
  // Called from BOTH the bottom action bar and the 3-dot share menu option.
  // Records to backend post_shares table and increments share count.
  Future<void> _handleShare() async {
    final text =
        '📌 ${widget.post.authorName} on SmartGali:\n"${widget.post.content}"\n\nhttps://smartgali.com/post/${widget.post.id}';
    try {
      final result = await SharePlus.instance.share(ShareParams(text: text));
      if (result.status == ShareResultStatus.success) {
        // Enterprise: Record share to backend post_shares table
        final backendRes = await widget.service.shareToFeed(widget.post.id);
        if (mounted) {
          setState(() {
            widget.post.shareCount++;
            _shareCount = widget.post.shareCount;
          });
          if (!backendRes.isSuccess) {
            // Non-critical: share succeeded but backend record failed — don't block UX
            debugPrint('[FeedService] shareToFeed failed: ${backendRes.error}');
          }
        }
      }
    } catch (e) {
      debugPrint('[_handleShare] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMedia = widget.post.hasMedia;
    final hasText = widget.post.content.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.post.authorUserId != null
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: widget.post.authorUserId!,
                              userName:
                                  widget.post.authorUserName ??
                                  widget.post.authorName,
                              fullName: widget.post.authorName,
                              avatarUrl: widget.post.authorAvatarUrl,
                            ),
                          ),
                        )
                      : null,
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor: _avatarColor(widget.post.authorName),
                    backgroundImage:
                        widget.post.authorAvatarUrl != null &&
                            widget.post.authorAvatarUrl!.isNotEmpty
                        ? NetworkImage(widget.post.authorAvatarUrl!)
                        : null,
                    child:
                        widget.post.authorAvatarUrl == null ||
                            widget.post.authorAvatarUrl!.isEmpty
                        ? Text(
                            _initials(widget.post.authorName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.post.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.post.isPinned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFC7D2FE),
                                  width: 0.5,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.push_pin,
                                    size: 10,
                                    color: Color(0xFF6366F1),
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Pinned',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            widget.formatTime(widget.post.createdAt),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          if (widget.post.isEdited) ...[
                            const SizedBox(width: 4),
                            const Text(
                              '· edited',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Icon(
                            widget.post.visibility == 'private'
                                ? Icons.lock_outline
                                : (widget.post.visibility == 'followers'
                                      ? Icons.group_outlined
                                      : Icons.public),
                            size: 11,
                            color: const Color(0xFF9CA3AF),
                          ),
                          if (widget.post.locationName != null &&
                              widget.post.locationName!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.location_on,
                              size: 11,
                              color: Color(0xFFEF4444),
                            ),
                            Text(
                              widget.post.locationName!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (widget.post.communityName != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5EE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Community · ${widget.post.communityName}',
                            style: const TextStyle(
                              color: Color(0xFFFF6B00),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF9CA3AF)),
                  onPressed: _openContextMenu,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // ── Text Content ──────────────────────────────────────────
          if (hasText)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, hasMedia ? 8 : 0),
              child: Text(
                widget.post.content,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 15,
                  height: 1.5,
                ),
                maxLines: hasMedia ? 3 : null,
                overflow: hasMedia
                    ? TextOverflow.ellipsis
                    : TextOverflow.visible,
              ),
            ),

          // ── Media Section (Facebook-style) ─────────────────────
          if (hasMedia) _MediaSection(post: widget.post),

          // ── Counts row (Facebook-style mini counts) ────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                if (_likeCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.thumb_up,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_likeCount',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
                const Spacer(),
                if (_commentCount > 0)
                  Text(
                    '$_commentCount comment${_commentCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                if (_commentCount > 0 && _shareCount > 0)
                  const Text(
                    '  ·  ',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                  ),
                if (_shareCount > 0)
                  Text(
                    '$_shareCount share${_shareCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),

          // ── Divider ────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),

          // ── Action Buttons (Facebook-style full-width row) ──────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                // Like
                Expanded(
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: TextButton.icon(
                      onPressed: _likePending ? null : _handleLike,
                      icon: Icon(
                        _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        size: 18,
                        color: _isLiked
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF6B7280),
                      ),
                      label: Text(
                        'Like',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isLiked
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                ),
                // Comment
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.post.commentsDisabled
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Comments are turned off for this post',
                                ),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        : () async {
                            await widget.onComment();
                          },
                    icon: Icon(
                      widget.post.commentsDisabled
                          ? Icons.comments_disabled_outlined
                          : Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: widget.post.commentsDisabled
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                    ),
                    label: Text(
                      widget.post.commentsDisabled ? 'Off' : 'Comment',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.post.commentsDisabled
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                // Save
                Expanded(
                  child: TextButton.icon(
                    onPressed: _savePending ? null : _handleSave,
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                      color: _isSaved
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6B7280),
                    ),
                    label: Text(
                      _isSaved ? 'Saved' : 'Save',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isSaved
                            ? const Color(0xFF10B981)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
                // Share
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      await widget.onShare();
                      if (mounted) {
                        setState(() {
                          _shareCount = widget.post.shareCount;
                        });
                      }
                    },
                    icon: const Icon(
                      Icons.reply_rounded,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                    label: const Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
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

// ── Facebook-style Media Section ─────────────────────────────────────────────
class _MediaSection extends StatelessWidget {
  final FeedPost post;
  const _MediaSection({required this.post});

  @override
  Widget build(BuildContext context) {
    final allMedia = <String>[];

    // Collect all media URLs
    if (post.mediaUrls.isNotEmpty) {
      for (final m in post.mediaUrls) {
        if (m.url.isNotEmpty) allMedia.add(m.url);
      }
    }
    if (allMedia.isEmpty && post.effectiveMediaUrl != null) {
      allMedia.add(post.effectiveMediaUrl!);
    }

    if (allMedia.isEmpty) return const SizedBox.shrink();

    // === 1 image/video → full width ===
    if (allMedia.length == 1) {
      return _MediaTile(
        url: allMedia[0],
        isVideo: post.isVideo || FeedPost.isVideoUrl(allMedia[0]),
        height: 280,
        width: double.infinity,
      );
    }

    // === 2 images → side by side ===
    if (allMedia.length == 2) {
      return Row(
        children: [
          Expanded(
            child: _MediaTile(
              url: allMedia[0],
              height: 200,
              isVideo: FeedPost.isVideoUrl(allMedia[0]),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _MediaTile(
              url: allMedia[1],
              height: 200,
              isVideo: FeedPost.isVideoUrl(allMedia[1]),
            ),
          ),
        ],
      );
    }

    // === 3 images → 1 left big + 2 right stacked ===
    if (allMedia.length == 3) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _MediaTile(
              url: allMedia[0],
              height: 200,
              isVideo: FeedPost.isVideoUrl(allMedia[0]),
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _MediaTile(
                  url: allMedia[1],
                  height: 99,
                  isVideo: FeedPost.isVideoUrl(allMedia[1]),
                ),
                const SizedBox(height: 2),
                _MediaTile(
                  url: allMedia[2],
                  height: 99,
                  isVideo: FeedPost.isVideoUrl(allMedia[2]),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // === 4+ images → 2x2 grid with "+N more" overlay on last cell ===
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MediaTile(
                url: allMedia[0],
                height: 150,
                isVideo: FeedPost.isVideoUrl(allMedia[0]),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: _MediaTile(
                url: allMedia[1],
                height: 150,
                isVideo: FeedPost.isVideoUrl(allMedia[1]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: _MediaTile(
                url: allMedia[2],
                height: 150,
                isVideo: FeedPost.isVideoUrl(allMedia[2]),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Stack(
                children: [
                  _MediaTile(
                    url: allMedia[3],
                    height: 150,
                    isVideo: FeedPost.isVideoUrl(allMedia[3]),
                  ),
                  if (allMedia.length > 4)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: Text(
                            '+${allMedia.length - 4}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// In-feed inline video player widget with rich play/pause and progress controls
class _FeedVideoPlayer extends StatefulWidget {
  final String url;
  const _FeedVideoPlayer({required this.url});

  @override
  State<_FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<_FeedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isMuted = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _hasError = false;
    _initialized = false;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _initialized = true;
              });
              _controller.setLooping(true);
              _controller.addListener(_videoListener);
            }
          })
          .catchError((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
              });
            }
          });
  }

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant _FeedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _hideControlsTimer?.cancel();
      _controller.removeListener(_videoListener);
      _controller.dispose();
      _initPlayer();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _togglePlay() {
    if (!_initialized) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
      _hideControlsTimer?.cancel();
      setState(() {
        _showControls = true;
      });
    } else {
      if (_controller.value.position >= _controller.value.duration &&
          _controller.value.duration > Duration.zero) {
        _controller.seekTo(Duration.zero);
      }
      _controller.play();
      setState(() {
        _showControls = true;
      });
      _startHideTimer();
    }
  }

  void _onTapVideo() {
    if (!_initialized) return;
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls && _controller.value.isPlaying) {
      _startHideTimer();
    }
  }

  void _toggleMute() {
    if (!_initialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
    if (_showControls && _controller.value.isPlaying) {
      _startHideTimer();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF1E293B),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 8),
              const Text(
                'Unable to load video',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _initPlayer,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Color(0xFF818CF8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF6366F1),
          ),
        ),
      );
    }

    final value = _controller.value;
    final isPlaying = value.isPlaying;
    final isBuffering = value.isBuffering;
    final position = value.position;
    final duration = value.duration;
    final isEnded = duration > Duration.zero && position >= duration;

    return GestureDetector(
      onTap: _onTapVideo,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            // Video surface
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio > 0
                    ? value.aspectRatio
                    : (16 / 9),
                child: VideoPlayer(_controller),
              ),
            ),

            // Buffering spinner
            if (isBuffering)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),

            // Controls overlay (animated fade)
            AnimatedOpacity(
              opacity: _showControls || !isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showControls && isPlaying,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: isPlaying ? 0.1 : 0.4),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Center Play / Pause button
                      Center(
                        child: GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              isEnded
                                  ? Icons.replay_rounded
                                  : (isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded),
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),

                      // Bottom controls bar
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 6,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Mini Play/Pause button
                            GestureDetector(
                              onTap: _togglePlay,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Time display
                            Text(
                              '${_formatDuration(position)} / ${_formatDuration(duration)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Progress scrubber
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  height: 20,
                                  child: VideoProgressIndicator(
                                    _controller,
                                    allowScrubbing: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    colors: const VideoProgressColors(
                                      playedColor: Color(0xFF6366F1),
                                      bufferedColor: Colors.white38,
                                      backgroundColor: Colors.white24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Mute / Unmute Button
                            GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isMuted
                                      ? Icons.volume_off_rounded
                                      : Icons.volume_up_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single media tile — image with loading, error, or in-feed video player
class _MediaTile extends StatelessWidget {
  final String url;
  final double height;
  final double width;
  final bool isVideo;

  const _MediaTile({
    required this.url,
    required this.height,
    this.width = double.infinity,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIsVideo = isVideo || FeedPost.isVideoUrl(url);

    return SizedBox(
      height: height,
      width: width,
      child: effectiveIsVideo
          ? _FeedVideoPlayer(url: url)
          : Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: const Color(0xFFF3F4F6),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFFF3F4F6),
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFFD1D5DB),
                    size: 40,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Bottom sheet offering in-app Contact/Chat sharing and Basic system share
class _ShareOptionsBottomSheet extends StatefulWidget {
  final FeedPost post;
  final FeedService service;
  final int? currentUserId;
  final VoidCallback onShared;

  const _ShareOptionsBottomSheet({
    required this.post,
    required this.service,
    this.currentUserId,
    required this.onShared,
  });

  @override
  State<_ShareOptionsBottomSheet> createState() =>
      _ShareOptionsBottomSheetState();
}

class _ShareOptionsBottomSheetState extends State<_ShareOptionsBottomSheet> {
  final _chatService = ChatService();
  final _authService = AuthService();
  List<ChatModel> _chats = [];
  bool _isLoadingChats = true;
  String _searchQuery = '';
  final Set<int> _sentChatIds = {};
  final Set<int> _sendingChatIds = {};
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    _userId = widget.currentUserId ?? await _authService.getUserId();
    if (_userId == null) {
      if (mounted) setState(() => _isLoadingChats = false);
      return;
    }
    try {
      final chats = await _chatService.getMyChats(_userId!);
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoadingChats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingChats = false);
    }
  }

  String _getShareText() {
    final author = widget.post.authorName;
    final snippet = widget.post.content.trim();
    if (snippet.isEmpty) {
      return '📌 Post by $author on SmartGali\nhttps://smartgali.com/post/${widget.post.id}';
    }
    return '📌 $author on SmartGali:\n"$snippet"\n\nhttps://smartgali.com/post/${widget.post.id}';
  }

  Future<void> _sendToChat(ChatModel chat) async {
    if (_userId == null ||
        _sentChatIds.contains(chat.id) ||
        _sendingChatIds.contains(chat.id)) {
      return;
    }
    setState(() {
      _sendingChatIds.add(chat.id);
    });
    try {
      await _chatService.sendMessage(
        chatId: chat.id,
        senderId: _userId!,
        message: _getShareText(),
      );
      await widget.service.shareToFeed(widget.post.id);
      widget.onShared();
      if (mounted) {
        setState(() {
          _sendingChatIds.remove(chat.id);
          _sentChatIds.add(chat.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Shared to ${chat.name ?? chat.otherUserName ?? "chat"}!',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendingChatIds.remove(chat.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not send to chat. Please try again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _basicShare() async {
    final text = _getShareText();
    Navigator.pop(context);
    try {
      final result = await SharePlus.instance.share(ShareParams(text: text));
      if (result.status == ShareResultStatus.success) {
        await widget.service.shareToFeed(widget.post.id);
        widget.onShared();
      }
    } catch (_) {}
  }

  void _copyLink() {
    final text = _getShareText();
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post link copied to clipboard!'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _chats.where((c) {
      final title = (c.name ?? c.otherUserName ?? '').toLowerCase();
      return title.contains(_searchQuery.toLowerCase().trim());
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Share Post',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFF6B7280),
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Post snippet preview
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF10B981),
                    backgroundImage: widget.post.authorAvatarUrl != null
                        ? NetworkImage(widget.post.authorAvatarUrl!)
                        : null,
                    child: widget.post.authorAvatarUrl == null
                        ? Text(
                            widget.post.authorName.isNotEmpty
                                ? widget.post.authorName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.post.content.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.post.content.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4B5563),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section 1: In-App Contacts / Chats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: const [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
                SizedBox(width: 6),
                Text(
                  'Send in Direct Chat',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),

          // Search Box (if chats exist)
          if (_chats.length > 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 12,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ),

          // Chats List
          Flexible(
            child: _isLoadingChats
                ? const SizedBox(
                    height: 80,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  )
                : _chats.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'No recent chats found',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredChats.length,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemBuilder: (ctx, idx) {
                      final chat = filteredChats[idx];
                      final name =
                          chat.name ?? chat.otherUserName ?? 'Chat #${chat.id}';
                      final isSent = _sentChatIds.contains(chat.id);
                      final isSending = _sendingChatIds.contains(chat.id);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF6366F1),
                              backgroundImage: chat.avatarUrl != null
                                  ? NetworkImage(chat.avatarUrl!)
                                  : null,
                              child: chat.avatarUrl == null
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (chat.lastMessage != null &&
                                      chat.lastMessage!.isNotEmpty)
                                    Text(
                                      chat.lastMessage!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: (isSent || isSending)
                                    ? null
                                    : () => _sendToChat(chat),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSent
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: isSending
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isSent ? 'Sent ✓' : 'Send',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Section 2: Basic Share & Copy Link Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                // Share via Other Apps (Basic Share)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _basicShare,
                    icon: const Icon(
                      Icons.share_outlined,
                      size: 18,
                      color: Color(0xFF1F2937),
                    ),
                    label: const Text(
                      'Share via...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Copy Link
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Copy Link',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ContextMenuAction {
  edit,
  pin,
  toggleComments,
  insights,
  privacy,
  save,
  copyLink,
  delete,
  unfollow,
  mute,
  block,
  report,
  share,
}

/// Enterprise-Level 3-Dot Context Menu (Author vs Viewer / Multi-Device)
class _PostContextMenuSheet extends StatelessWidget {
  final FeedPost post;
  final bool isAuthor;

  const _PostContextMenuSheet({required this.post, required this.isAuthor});

  String get _privacyLabel {
    if (post.visibility == 'private') return 'Only Me (Private)';
    if (post.visibility == 'followers') return 'Followers Only';
    return 'Public';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (isAuthor) ...[
                // ── AUTHOR ACTIONS (Apna Post) ──
                _ContextMenuTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Post',
                  subtitle: 'Change post text content',
                  onTap: () => Navigator.pop(context, _ContextMenuAction.edit),
                ),
                _ContextMenuTile(
                  icon: post.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  title: post.isPinned ? 'Unpin from Top' : 'Pin to Profile',
                  subtitle: post.isPinned
                      ? 'Remove from top of profile'
                      : 'Keep at the top of your profile',
                  onTap: () => Navigator.pop(context, _ContextMenuAction.pin),
                ),
                _ContextMenuTile(
                  icon: post.commentsDisabled
                      ? Icons.chat_bubble_outline
                      : Icons.comments_disabled_outlined,
                  title: post.commentsDisabled
                      ? 'Turn On Comments'
                      : 'Turn Off Comments',
                  subtitle: post.commentsDisabled
                      ? 'Allow users to comment'
                      : 'Disable new comments on this post',
                  onTap: () =>
                      Navigator.pop(context, _ContextMenuAction.toggleComments),
                ),
                _ContextMenuTile(
                  icon: Icons.analytics_outlined,
                  title: 'View Insights & Analytics',
                  subtitle: 'See total reach, likes, comments, and shares',
                  onTap: () =>
                      Navigator.pop(context, _ContextMenuAction.insights),
                ),
                _ContextMenuTile(
                  icon: Icons.lock_outline,
                  title: 'Audience / Privacy',
                  subtitle: 'Currently: $_privacyLabel',
                  onTap: () =>
                      Navigator.pop(context, _ContextMenuAction.privacy),
                ),
                _ContextMenuTile(
                  icon: post.isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  title: post.isSaved ? 'Remove from Saved' : 'Save Post',
                  subtitle: 'Bookmark for your personal collection',
                  onTap: () => Navigator.pop(context, _ContextMenuAction.save),
                ),
                _ContextMenuTile(
                  icon: Icons.link_rounded,
                  title: 'Copy Post Link',
                  onTap: () =>
                      Navigator.pop(context, _ContextMenuAction.copyLink),
                ),
                const Divider(height: 1),
                _ContextMenuTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Delete Post',
                  subtitle: 'Delete permanently with confirmation',
                  isDestructive: true,
                  onTap: () =>
                      Navigator.pop(context, _ContextMenuAction.delete),
                ),
              ] else ...[
                // ── VIEWER ACTIONS (Doosre Ka Post) ──
                _ContextMenuTile(
                  icon: post.isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  title: post.isSaved ? 'Remove from Saved' : 'Save Post',
                  subtitle: post.isSaved
                      ? 'Remove from your bookmarks'
                      : 'Save to your private bookmarks',
                  onTap: () => Navigator.pop(context, _ContextMenuAction.save),
                ),
                if (post.authorUserId != null)
                  _ContextMenuTile(
                    icon: Icons.person_remove_outlined,
                    title:
                        'Unfollow @${post.authorUserName ?? post.authorName}',
                    subtitle: "Stop seeing posts from this user in your feed",
                    onTap: () =>
                        Navigator.pop(context, _ContextMenuAction.unfollow),
                  ),
                _ContextMenuTile(
                  icon: Icons.volume_off_outlined,
                  title: 'Mute @${post.authorUserName ?? post.authorName}',
                  subtitle:
                      "Hide future posts from this user without unfollowing",
                  onTap: () => Navigator.pop(context, _ContextMenuAction.mute),
                ),
                _ContextMenuTile(
                  icon: Icons.block_outlined,
                  title: 'Block @${post.authorUserName ?? post.authorName}',
                  subtitle: "Prevent all interactions and hide content",
                  isDestructive: true,
                  onTap: () => Navigator.pop(context, _ContextMenuAction.block),
                ),
                _ContextMenuTile(
                  icon: Icons.share_outlined,
                  title: 'Share Post',
                  subtitle: 'Share via apps or message',
                  onTap: () => Navigator.pop(context, _ContextMenuAction.share),
                ),
                _ContextMenuTile(
                  icon: Icons.link_rounded,
                  title: 'Copy Post Link',
                  onTap: () =>
                      Navigator.pop(context, _ContextMenuAction.copyLink),
                ),
                const Divider(height: 1),
                _ContextMenuTile(
                  icon: Icons.flag_outlined,
                  title: 'Report Post',
                  subtitle: "Report spam, abuse, harassment or misinformation",
                  isDestructive: true,
                  onTap: () =>
                      Navigator.pop(context, _ContextMenuAction.report),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ContextMenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : const Color(0xFF1F2937);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
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
}

class _InsightItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _InsightItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4B5563),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
