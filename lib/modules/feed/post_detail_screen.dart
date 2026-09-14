import 'package:flutter/material.dart';
import '../../core/api_config.dart';
import 'feed_service.dart';
import 'models/feed_post_model.dart';

class PostDetailScreen extends StatefulWidget {
  final int postId;
  final FeedPost? initialPost;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FeedService _service = FeedService();
  final TextEditingController _commentCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  FeedPost? _post;
  List<FeedComment> _comments = [];
  bool _isLoadingPost = true;
  bool _isLoadingComments = true;
  bool _isPostingComment = false;
  String? _error;

  static const Color _orange = Color(0xFFFF6B00);
  static const Color _dark = Color(0xFF111827);
  static const Color _grey = Color(0xFF6B7280);
  static const Color _divider = Color(0xFFE5E7EB);
  static const Color _bg = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    if (_post != null) {
      _isLoadingPost = false;
    }
    _fetchPostAndComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPostAndComments() async {
    setState(() {
      _error = null;
      if (_post == null) _isLoadingPost = true;
      _isLoadingComments = true;
    });

    final postFuture = _service.getPostById(widget.postId);
    final commentsFuture = _service.getComments(widget.postId);

    final results = await Future.wait([postFuture, commentsFuture]);
    if (!mounted) return;

    final postResult = results[0] as FeedResult<FeedPost>;
    final commentsResult = results[1] as FeedResult<List<FeedComment>>;

    setState(() {
      if (postResult.isSuccess && postResult.data != null) {
        _post = postResult.data;
        _isLoadingPost = false;
      } else if (_post == null) {
        _error = postResult.error ?? 'Failed to load post';
        _isLoadingPost = false;
      }

      if (commentsResult.isSuccess && commentsResult.data != null) {
        _comments = commentsResult.data!;
      }
      _isLoadingComments = false;
    });
  }

  Future<void> _handleToggleLike() async {
    final currentPost = _post;
    if (currentPost == null) return;

    final wasLiked = currentPost.isLikedByMe;
    final currentLikes = currentPost.likesCount;

    setState(() {
      currentPost.isLikedByMe = !wasLiked;
      currentPost.likesCount = wasLiked ? (currentLikes > 0 ? currentLikes - 1 : 0) : currentLikes + 1;
    });

    final result = await _service.toggleLike(currentPost.id, isCurrentlyLiked: wasLiked);
    if (!result.isSuccess && mounted) {
      setState(() {
        currentPost.isLikedByMe = wasLiked;
        currentPost.likesCount = currentLikes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to update like')),
      );
    }
  }

  Future<void> _handleSubmitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _post == null || _isPostingComment) return;

    setState(() => _isPostingComment = true);

    final result = await _service.addComment(
      postId: _post!.id,
      content: text,
    );

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      _commentCtrl.clear();
      setState(() {
        _comments.insert(0, result.data!);
        _post!.commentsCount += 1;
        _isPostingComment = false;
      });
      // Scroll to top of comments
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      setState(() => _isPostingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to post comment')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Post',
          style: TextStyle(color: _dark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _divider, height: 1.0),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _post != null ? _buildCommentInputBar() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoadingPost && _post == null) {
      return const Center(
        child: CircularProgressIndicator(color: _orange),
      );
    }

    if (_error != null && _post == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: _dark, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _fetchPostAndComments,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: _orange),
              ),
            ],
          ),
        ),
      );
    }

    final post = _post!;

    return RefreshIndicator(
      color: _orange,
      onRefresh: _fetchPostAndComments,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // ── Post Card View ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFF3F4F6),
                      backgroundImage: (post.authorAvatarUrl != null && post.authorAvatarUrl!.isNotEmpty)
                          ? NetworkImage(ApiConfig.normalizeMediaUrl(post.authorAvatarUrl) ?? post.authorAvatarUrl!)
                          : null,
                      child: (post.authorAvatarUrl == null || post.authorAvatarUrl!.isEmpty)
                          ? Text(
                              post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: _dark, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(
                              color: _dark,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (post.createdAt.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              post.createdAt,
                              style: const TextStyle(color: _grey, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (post.communityName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          post.communityName!,
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Post text
                if (post.content.isNotEmpty)
                  Text(
                    post.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1F2937),
                      height: 1.45,
                    ),
                  ),

                // Post media
                if (post.hasMedia && post.effectiveMediaUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      ApiConfig.normalizeMediaUrl(post.effectiveMediaUrl) ?? post.effectiveMediaUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(height: 1, color: _divider),
                const SizedBox(height: 10),

                // Engagement buttons
                Row(
                  children: [
                    InkWell(
                      onTap: _handleToggleLike,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                              color: post.isLikedByMe ? const Color(0xFFF43F5E) : _grey,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${post.likesCount}',
                              style: TextStyle(
                                color: post.isLikedByMe ? const Color(0xFFF43F5E) : _dark,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: _grey, size: 19),
                        const SizedBox(width: 6),
                        Text(
                          '${post.commentsCount}',
                          style: const TextStyle(
                            color: _dark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Comments Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Text(
              'Comments (${_comments.length})',
              style: const TextStyle(
                color: _dark,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // ── Comments List ───────────────────────────────────────────
          if (_isLoadingComments)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: _orange, strokeWidth: 2),
                ),
              ),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No comments yet. Be the first to comment!',
                  style: TextStyle(color: _grey.withValues(alpha: 0.8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: _divider, indent: 64),
              itemBuilder: (context, index) {
                final c = _comments[index];
                return Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFF3F4F6),
                        child: Text(
                          c.authorName.isNotEmpty ? c.authorName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  c.authorName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _dark,
                                  ),
                                ),
                                if (c.createdAt.isNotEmpty)
                                  Text(
                                    c.createdAt,
                                    style: const TextStyle(fontSize: 11, color: _grey),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c.content,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF374151),
                                height: 1.35,
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

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCommentInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _divider)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _commentCtrl,
                  style: const TextStyle(fontSize: 14, color: _dark),
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: _grey, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSubmitComment(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isPostingComment ? null : _handleSubmitComment,
              icon: _isPostingComment
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _orange),
                    )
                  : const Icon(Icons.send_rounded, color: _orange),
            ),
          ],
        ),
      ),
    );
  }
}
