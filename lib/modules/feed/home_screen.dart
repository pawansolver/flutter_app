import 'post_composer_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'feed_service.dart';
import 'models/feed_post_model.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/custom_drawer.dart';
import '../core/notification_service.dart';
import '../core/notifications_screen.dart';
import '../profile/user_profile_screen.dart'; // PRD Phase 8: Follow system

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
import 'package:video_player/video_player.dart';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _service = FeedService();
  final _notificationService = NotificationService();
  int? _currentUserId; // For author vs viewer context in PostCard
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
    _loadCurrentUser();
    _loadFeed();
    _startFeedSync();
    _refreshUnreadCount();
    _startNotificationSync();
  }

  Future<void> _loadCurrentUser() async {
    // Read userId from JWT stored in secure storage
    final storage = const FlutterSecureStorage();
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
      if (uid != null && mounted) setState(() => _currentUserId = int.tryParse(uid.toString()));
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
void _sharePost(FeedPost post) async {
    final text = '📌 ${post.authorName} on smartgali:\n"${post.content}"\n\nJoin smartgali for hyperlocal updates!';
    await SharePlus.instance.share(ShareParams(text: text));
    await _service.shareToFeed(post.id);
    setState(() {
      post.shareCount++;
    });
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
                          currentUserId: _currentUserId,
                          onComment: () async => _openComments(post),
                          onShare: () => _sharePost(post),
                          onDeleted: () => setState(() => _posts.removeWhere((p) => p.id == post.id)),
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
  final Future<void> Function() onComment;
  final VoidCallback onShare;
  final VoidCallback? onDeleted;

  const _PostCard({
    required this.post,
    required this.service,
    required this.formatTime,
    this.currentUserId,
    required this.onComment,
    required this.onShare,
    this.onDeleted,
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
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.3)
        .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_PostCard old) {
    super.didUpdateWidget(old);
    if (old.post.id != widget.post.id) _syncFromPost();
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
    _scaleCtrl.dispose();
    super.dispose();
  }

  // Enterprise Like: Optimistic UI -> API -> Server-sync / Rollback
  Future<void> _handleLike() async {
    if (_likePending) return;
    final wasLiked = _isLiked;
    final prevCount = _likeCount;
    setState(() { _isLiked = !wasLiked; _likeCount = wasLiked ? prevCount - 1 : prevCount + 1; _likePending = true; });
    _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());
    final result = await widget.service.toggleLike(widget.post.id, isCurrentlyLiked: wasLiked);
    if (!mounted) return;
    setState(() => _likePending = false);
    if (!result.isSuccess) {
      setState(() { _isLiked = wasLiked; _likeCount = prevCount; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Could not like post'),
        backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating,
      ));
    } else {
      final sc = result.data?['likesCount'];
      final sl = result.data?['isLikedByMe'];
      setState(() {
        if (sc != null) _likeCount = sc is int ? sc : int.tryParse(sc.toString()) ?? _likeCount;
        if (sl is bool) _isLiked = sl;
      });
      widget.post.isLikedByMe = _isLiked;
      widget.post.likesCount = _likeCount;
    }
  }

  // Enterprise Save: Optimistic toggle
  Future<void> _handleSave() async {
    if (_savePending) return;
    final wasSaved = _isSaved;
    setState(() { _isSaved = !wasSaved; _savePending = true; });
    widget.post.isSaved = _isSaved;
    final result = await widget.service.savePost(widget.post.id);
    if (!mounted) return;
    setState(() => _savePending = false);
    if (!result.isSuccess) {
      setState(() { _isSaved = wasSaved; });
      widget.post.isSaved = wasSaved;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Could not save post'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // Called by comment sheet when a comment is added
  void _onCommentAdded() {
    setState(() { _commentCount++; widget.post.commentsCount = _commentCount; });
  }

  // Called after share action
  void _onShared() {
    setState(() { _shareCount++; widget.post.shareCount = _shareCount; });
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
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: widget.post.authorUserId!, userName: widget.post.authorUserName ?? widget.post.authorName, fullName: widget.post.authorName, avatarUrl: widget.post.authorAvatarUrl)))
                      : null,
                  child: CircleAvatar(
                    radius: 21,
                    backgroundColor: _avatarColor(widget.post.authorName),
                    backgroundImage: widget.post.authorAvatarUrl != null && widget.post.authorAvatarUrl!.isNotEmpty
                        ? NetworkImage(widget.post.authorAvatarUrl!) : null,
                    child: widget.post.authorAvatarUrl == null || widget.post.authorAvatarUrl!.isEmpty
                        ? Text(_initials(widget.post.authorName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.post.authorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: Color(0xFF111827))),
                      Row(children: [
                        Text(widget.formatTime(widget.post.createdAt), style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF))),
                        const SizedBox(width: 4),
                        const Icon(Icons.public, size: 11, color: Color(0xFF9CA3AF)),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Color(0xFF9CA3AF)),
                  onPressed: () {},
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
                style: const TextStyle(color: Color(0xFF1F2937), fontSize: 15, height: 1.5),
                maxLines: hasMedia ? 3 : null,
                overflow: hasMedia ? TextOverflow.ellipsis : TextOverflow.visible,
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
                    decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                    child: const Icon(Icons.thumb_up, size: 9, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Text('$_likeCount', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                ],
                const Spacer(),
                if (_commentCount > 0)
                  Text('$_commentCount comment${_commentCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                if (_commentCount > 0 && _shareCount > 0)
                  const Text('  ·  ', style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
                if (_shareCount > 0)
                  Text('$_shareCount share${_shareCount == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280))),
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
                        color: _isLiked ? const Color(0xFF6366F1) : const Color(0xFF6B7280),
                      ),
                      label: Text(
                        'Like',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isLiked ? const Color(0xFF6366F1) : const Color(0xFF6B7280),
                        ),
                      ),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                    ),
                  ),
                ),
                // Comment
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      await widget.onComment();
                      // count is updated via _onCommentAdded from comment sheet callback
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF6B7280)),
                    label: const Text('Comment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                  ),
                ),
                // Save
                Expanded(
                  child: TextButton.icon(
                    onPressed: _savePending ? null : _handleSave,
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                      color: _isSaved ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                    ),
                    label: Text(
                      _isSaved ? 'Saved' : 'Save',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isSaved ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                      ),
                    ),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                  ),
                ),
                // Share
                Expanded(
                  child: TextButton.icon(
                    onPressed: () { widget.onShare(); _onShared(); },
                    icon: const Icon(Icons.reply_rounded, size: 18, color: Color(0xFF6B7280)),
                    label: const Text('Share', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
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

    // === 1 image → full width ===
    if (allMedia.length == 1) {
      return _MediaTile(
        url: allMedia[0],
        isVideo: post.isVideo,
        height: 280,
        width: double.infinity,
      );
    }

    // === 2 images → side by side ===
    if (allMedia.length == 2) {
      return Row(
        children: [
          Expanded(child: _MediaTile(url: allMedia[0], height: 200)),
          const SizedBox(width: 2),
          Expanded(child: _MediaTile(url: allMedia[1], height: 200)),
        ],
      );
    }

    // === 3 images → 1 left big + 2 right stacked ===
    if (allMedia.length == 3) {
      return Row(
        children: [
          Expanded(flex: 2, child: _MediaTile(url: allMedia[0], height: 200)),
          const SizedBox(width: 2),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _MediaTile(url: allMedia[1], height: 99),
                const SizedBox(height: 2),
                _MediaTile(url: allMedia[2], height: 99),
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
            Expanded(child: _MediaTile(url: allMedia[0], height: 150)),
            const SizedBox(width: 2),
            Expanded(child: _MediaTile(url: allMedia[1], height: 150)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(child: _MediaTile(url: allMedia[2], height: 150)),
            const SizedBox(width: 2),
            Expanded(
              child: Stack(
                children: [
                  _MediaTile(url: allMedia[3], height: 150),
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

/// Single media tile — image with loading, error, video overlay
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
    return SizedBox(
      height: height,
      width: width,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFFF3F4F6),
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF3F4F6),
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: Color(0xFFD1D5DB), size: 40),
              ),
            ),
          ),
          if (isVideo)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 52),
              ),
            ),
        ],
      ),
    );
  }
}
