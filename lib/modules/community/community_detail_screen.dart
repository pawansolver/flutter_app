import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/community_models.dart';
import '../../services/auth_service.dart';
import '../../services/community_service.dart';
import '../../services/chat_service.dart';
import '../chat/chat_window_screen.dart';
import '../feed/feed_service.dart';
import '../feed/post_composer_screen.dart';
import 'widgets/community_poll_card.dart';
import 'widgets/community_announcement_card.dart';
import 'widgets/community_gallery_view.dart';
import 'widgets/community_files_view.dart';
import 'widgets/member_action_sheet.dart';
import 'widgets/invite_members_sheet.dart';
import 'widgets/create_poll_sheet.dart';
import 'widgets/upload_media_sheet.dart';
import 'widgets/upload_document_sheet.dart';
import 'widgets/create_community_event_sheet.dart';
import 'manage_community_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final CommunityModel community;

  const CommunityDetailScreen({super.key, required this.community});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _communityService = CommunityService();
  final _authService = AuthService();

  late CommunityModel _community;
  int? _currentUserId;
  List<CommunityPostModel> _posts = [];
  List<CommunityMemberModel> _members = [];
  List<CommunityPollModel> _polls = [];
  List<CommunityAnnouncementModel> _announcements = [];
  List<CommunityDocumentModel> _documents = [];
  List<CommunityMediaModel> _gallery = [];
  List<CommunityEventModel> _events = [];
  String? _nextFeedCursor;
  bool _feedHasMore = false;
  bool _isLoadingMore = false;
  String? _error;

  bool _isLoading = true;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _community = widget.community;
    _tabController = TabController(length: 7, vsync: this);
    _loadAllCommunityData();
  }

  Future<void> _loadAllCommunityData() async {
    setState(() => _isLoading = true);
    try {
      final userId = await _authService.getUserId();
      final detailsFuture = _communityService.getCommunityDetails(
        _community.id,
      );
      final feedFuture = _communityService.getCommunityFeedPage(_community.id);
      final membersFuture = _communityService.getCommunityMembers(
        _community.id,
      );
      final pollsFuture = _communityService.getCommunityPolls(_community.id);
      final announcementsFuture = _communityService.getCommunityAnnouncements(
        _community.id,
      );
      final docsFuture = _communityService.getCommunityDocuments(_community.id);
      final galleryFuture = _communityService.getCommunityGallery(
        _community.id,
      );
      final eventsFuture = _communityService.getCommunityEvents(_community.id);

      final results = await Future.wait([
        detailsFuture,
        feedFuture,
        membersFuture,
        pollsFuture,
        announcementsFuture,
        docsFuture,
        galleryFuture,
        eventsFuture,
      ]);

      if (mounted) {
        setState(() {
          _currentUserId = userId;
          _community = results[0] as CommunityModel;
          final feed = results[1] as CommunityFeedPage;
          _posts = feed.posts;
          _nextFeedCursor = feed.nextCursor;
          _feedHasMore = feed.hasMore;
          _members = results[2] as List<CommunityMemberModel>;
          _polls = results[3] as List<CommunityPollModel>;
          _announcements = results[4] as List<CommunityAnnouncementModel>;
          _documents = results[5] as List<CommunityDocumentModel>;
          _gallery = results[6] as List<CommunityMediaModel>;
          _events = results[7] as List<CommunityEventModel>;
          _error = null;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _handleJoinToggle() async {
    setState(() => _isJoining = true);
    try {
      if (_community.isMember) {
        final success = await _communityService.leaveCommunity(_community.id);
        if (success && mounted) {
          setState(() {
            _community = _community.copyWith(
              isMember: false,
              membersCount: (_community.membersCount - 1).clamp(0, 999999),
              myRole: CommunityRole.none,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You left the community')),
          );
        }
      } else {
        final result = await _communityService.joinCommunity(_community.id);
        if (mounted) {
          setState(() {
            _community = _community.copyWith(
              isMember: result.isMember,
              joinStatus: result.status,
              membersCount: result.isMember
                  ? _community.membersCount + 1
                  : _community.membersCount,
              myRole: result.isMember
                  ? CommunityRole.member
                  : CommunityRole.none,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.isPending
                    ? 'Join request sent to Admin!'
                    : '🎉 Welcome to ${_community.name}!',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _loadMoreFeed() async {
    if (!_feedHasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _communityService.getCommunityFeedPage(
        _community.id,
        cursor: _nextFeedCursor,
      );
      if (mounted) {
        setState(() {
          _posts.addAll(page.posts);
          _nextFeedCursor = page.nextCursor;
          _feedHasMore = page.hasMore;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openMemberChat(CommunityMemberModel member) async {
    try {
      final chat = await ChatService().getOrCreateOneToOneChat(
        userId: _currentUserId ?? 0,
        targetUserId: member.userId,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatWindowScreen(
            chatId: chat.id,
            chatName: member.fullName,
            avatarUrl: member.avatarUrl,
            isOnline: chat.isOnline,
            currentUserId: _currentUserId ?? 0,
            recipientUserId: member.userId,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCommunityChat() async {
    try {
      final chatId = await _communityService.getCommunityChatId(_community.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatWindowScreen(
            chatId: chatId,
            chatName: _community.name,
            isOnline: true,
            currentUserId: _currentUserId ?? 0,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openSharedPostComposer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostComposerScreen(
          service: FeedService(),
          communityId: _community.id,
          communityName: _community.name,
          onPosted: (_) => _loadAllCommunityData(),
        ),
      ),
    );
  }

  Future<void> _openPostComments(CommunityPostModel post) async {
    final service = FeedService();
    final result = await service.getComments(post.id);
    if (!mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to load comments')),
      );
      return;
    }

    final comments = [...?result.data];
    final controller = TextEditingController();
    var posting = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.62,
            child: Column(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: comments.isEmpty
                      ? const Center(child: Text('No comments yet'))
                      : ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (_, index) {
                            final comment = comments[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                comment.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(comment.content),
                            );
                          },
                        ),
                ),
                if (!post.commentsDisabled)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText: 'Write a comment…',
                            counterText: '',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: posting
                            ? null
                            : () async {
                                final text = controller.text.trim();
                                if (text.isEmpty) return;
                                setSheetState(() => posting = true);
                                final added = await service.addComment(
                                  postId: post.id,
                                  content: text,
                                );
                                if (!sheetContext.mounted) return;
                                setSheetState(() {
                                  posting = false;
                                  if (added.data != null) {
                                    comments.add(added.data!);
                                    controller.clear();
                                  }
                                });
                                if (added.isSuccess && mounted) {
                                  setState(() {
                                    final index = _posts.indexWhere(
                                      (item) => item.id == post.id,
                                    );
                                    if (index >= 0) {
                                      _posts[index] = _posts[index].copyWith(
                                        commentsCount:
                                            _posts[index].commentsCount + 1,
                                      );
                                    }
                                  });
                                } else if (!added.isSuccess) {
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        added.error ?? 'Failed to add comment',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: posting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _showPostMenu(CommunityPostModel post) async {
    final isAuthor = post.authorId == _currentUserId;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (isAuthor)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete post'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report post'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final service = FeedService();
    final result = action == 'delete'
        ? await service.deletePost(post.id)
        : await service.reportPost(post.id, reason: 'inappropriate_content');
    if (!mounted) return;
    if (result.isSuccess) {
      if (action == 'delete') {
        setState(() => _posts.removeWhere((item) => item.id == post.id));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'delete' ? 'Post deleted' : 'Post reported'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Action failed')),
      );
    }
  }

  Future<void> _updateMemberRole(
    CommunityMemberModel member,
    CommunityRole newRole,
  ) async {
    try {
      await _communityService.updateMemberRole(
        _community.id,
        member.userId,
        newRole,
      );
      if (!mounted) return;
      final index = _members.indexWhere((item) => item.id == member.id);
      if (index >= 0) {
        setState(() {
          _members[index] = CommunityMemberModel(
            id: member.id,
            userId: member.userId,
            fullName: member.fullName,
            userName: member.userName,
            avatarUrl: member.avatarUrl,
            role: newRole,
            joinedAt: member.joinedAt,
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.fullName} is now ${newRole.displayName}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeOrBanMember(
    CommunityMemberModel member, {
    required bool ban,
  }) async {
    try {
      await _communityService.removeMember(
        _community.id,
        member.userId,
        isBanned: ban,
      );
      if (!mounted) return;
      setState(() => _members.removeWhere((item) => item.id == member.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ban
                ? '${member.fullName} has been banned'
                : '${member.fullName} removed from community',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDeleteDocument(CommunityDocumentModel doc) async {
    try {
      await _communityService.deleteDocument(_community.id, doc.id);
      if (!mounted) return;
      setState(() => _documents.removeWhere((item) => item.id == doc.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document "${doc.title}" deleted')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDeleteMedia(CommunityMediaModel media) async {
    try {
      await _communityService.deleteMedia(_community.id, media.id);
      if (!mounted) return;
      setState(() => _gallery.removeWhere((item) => item.id == media.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media removed from gallery')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDeletePoll(CommunityPollModel poll) async {
    try {
      await _communityService.deletePoll(_community.id, poll.id);
      if (!mounted) return;
      setState(() => _polls.removeWhere((p) => p.id == poll.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poll deleted successfully')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.gavel_rounded, color: Color(0xFFFF6B00)),
              SizedBox(width: 10),
              Text('Community Guidelines'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_community.rules != null && _community.rules!.isNotEmpty)
                ..._community.rules!.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: const TextStyle(fontSize: 14, height: 1.3),
                    ),
                  );
                })
              else
                const Text(
                  '1. Be respectful to all members\n2. No spam or hate speech',
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Got it',
                style: TextStyle(
                  color: Color(0xFFFF6B00),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 230,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: darkText, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              actions: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: const Icon(
                      Icons.info_outline,
                      color: darkText,
                      size: 20,
                    ),
                    onPressed: _showRulesDialog,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: IconButton(
                    icon: const Icon(
                      Icons.share_outlined,
                      color: darkText,
                      size: 20,
                    ),
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Join "${_community.name}" community on SmartGali!\nConnect with neighbors, share updates, and participate in society events.\nhttps://smartgali.com/community/${_community.id}',
                          subject: 'Join ${_community.name}',
                        ),
                      );
                    },
                  ),
                ),
                if (_community.myRole == CommunityRole.admin ||
                    _community.myRole == CommunityRole.moderator) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: darkText,
                        size: 20,
                      ),
                      tooltip: 'Community Settings',
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ManageCommunityScreen(community: _community),
                          ),
                        );
                        if (!context.mounted) return;
                        if (result == 'DELETED') {
                          Navigator.pop(context);
                        } else if (result is CommunityModel) {
                          setState(() => _community = result);
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(width: 12),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover Banner
                    _community.coverImageUrl != null &&
                            _community.coverImageUrl!.isNotEmpty
                        ? Image.network(
                            _community.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: const Color(0xFFFFF5EE),
                              child: const Icon(
                                Icons.groups_rounded,
                                color: primaryOrange,
                                size: 64,
                              ),
                            ),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF8A00), Color(0xFFFF6B00)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.group_work_rounded,
                                color: Colors.white24,
                                size: 80,
                              ),
                            ),
                          ),

                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    // Content details on banner
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _community.category ?? 'General',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _community.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 4, color: Colors.black45),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_community.membersCount} Members • ${_community.postsCount} Posts • ${_community.isPrivate ? '🔒 Private' : '🌐 Public'}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Header CTA bar (Join/Leave + Description)
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _community.description ??
                          'A neighborhood community group.',
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Join/Leave CTA
                        Expanded(
                          child: _community.isMember
                              ? OutlinedButton.icon(
                                  onPressed: _isJoining
                                      ? null
                                      : _handleJoinToggle,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF10B981),
                                    side: const BorderSide(
                                      color: Color(0xFF10B981),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Member (Joined)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed:
                                      _isJoining ||
                                          _community.joinStatus ==
                                              CommunityJoinStatus.pending
                                      ? null
                                      : _handleJoinToggle,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryOrange,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.group_add_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _community.joinStatus ==
                                            CommunityJoinStatus.pending
                                        ? 'Request Pending'
                                        : _community.isPrivate
                                        ? 'Request to Join'
                                        : 'Join Community',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        // Invite button
                        if (_community.myRole == CommunityRole.admin ||
                            _community.myRole == CommunityRole.moderator)
                          OutlinedButton.icon(
                            onPressed: () {
                              InviteMembersSheet.show(
                                context,
                                communityId: _community.id,
                                communityName: _community.name,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: darkText,
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            icon: const Icon(
                              Icons.person_add_alt_1_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Invite',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // TabBar Header (7 PRD Tabs)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: primaryOrange,
                  unselectedLabelColor: greySubtext,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  indicatorColor: primaryOrange,
                  indicatorWeight: 2.5,
                  tabs: const [
                    Tab(text: '📝 Feed'),
                    Tab(text: '🖼️ Gallery'),
                    Tab(text: '📁 Files & Docs'),
                    Tab(text: '👥 Members'),
                    Tab(text: '📊 Polls'),
                    Tab(text: '🎪 Events'),
                    Tab(text: '💬 Group Chat'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryOrange),
              )
            : _error != null
            ? Center(
                child: ElevatedButton(
                  onPressed: _loadAllCommunityData,
                  child: Text('Retry: $_error'),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildFeedTab(),
                  CommunityGalleryView(
                    mediaItems: _gallery,
                    isMember: _community.isMember,
                    canManage:
                        _community.myRole == CommunityRole.admin ||
                        _community.myRole == CommunityRole.moderator,
                    onAddMedia: () {
                      UploadMediaSheet.show(
                        context,
                        communityId: _community.id,
                        onMediaUploaded: (newMedia) {
                          setState(() => _gallery.insert(0, newMedia));
                        },
                      );
                    },
                    onDeleteMedia: _handleDeleteMedia,
                  ),
                  CommunityFilesView(
                    documents: _documents,
                    isMember: _community.isMember,
                    canManage:
                        _community.myRole == CommunityRole.admin ||
                        _community.myRole == CommunityRole.moderator,
                    onUploadDocument: () {
                      UploadDocumentSheet.show(
                        context,
                        communityId: _community.id,
                        onDocumentUploaded: (newDoc) {
                          setState(() => _documents.insert(0, newDoc));
                        },
                      );
                    },
                    onDeleteDocument: _handleDeleteDocument,
                  ),
                  _buildMembersTab(),
                  _buildPollsTab(),
                  _buildEventsTab(),
                  _buildChatTab(),
                ],
              ),
      ),
    );
  }

  // ── Tab 1: Feed ────────────────────────────────────────────────
  Widget _buildFeedTab() {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pinned Announcements
        if (_announcements.isNotEmpty) ...[
          ..._announcements.map(
            (ann) => CommunityAnnouncementCard(announcement: ann),
          ),
        ],

        // Create Post Bar
        if (_community.isMember)
          GestureDetector(
            onTap: _openSharedPostComposer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: const [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFFFF5EE),
                    child: Icon(
                      Icons.edit_outlined,
                      color: primaryOrange,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Share an update with the group...',
                      style: TextStyle(color: greySubtext, fontSize: 13),
                    ),
                  ),
                  Icon(
                    Icons.photo_camera_outlined,
                    color: greySubtext,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Posts Stream
        if (_posts.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: const [
                  Icon(Icons.forum_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    'No posts yet',
                    style: TextStyle(
                      color: darkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Be the first to share something in this community!',
                    style: TextStyle(color: greySubtext, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          ..._posts.map((post) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: primaryOrange.withValues(alpha: 0.12),
                        child: Text(
                          post.authorName.isNotEmpty
                              ? post.authorName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: primaryOrange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                post.authorName,
                                style: const TextStyle(
                                  color: darkText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (post.authorRole != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryOrange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    post.authorRole!,
                                    style: const TextStyle(
                                      color: primaryOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            DateFormat(
                              'd MMM, h:mm a',
                            ).format(post.createdAt.toLocal()),
                            style: const TextStyle(
                              color: greySubtext,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.more_horiz,
                          color: greySubtext,
                          size: 18,
                        ),
                        onPressed: () => _showPostMenu(post),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Post Text
                  Text(
                    post.content,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 10),

                  // Interactions
                  Row(
                    children: [
                      InkWell(
                        onTap: () async {
                          final result = await FeedService().toggleLike(
                            post.id,
                            isCurrentlyLiked: post.isLikedByMe,
                          );
                          if (!mounted) return;
                          if (!result.isSuccess) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.error ?? 'Failed to update like',
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            final idx = _posts.indexWhere((item) => item.id == post.id);
                            if (idx != -1) {
                              _posts[idx] = post.copyWith(
                                isLikedByMe: !post.isLikedByMe,
                                likesCount: post.isLikedByMe
                                    ? post.likesCount - 1
                                    : post.likesCount + 1,
                              );
                            }
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              post.isLikedByMe
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: post.isLikedByMe
                                  ? Colors.red
                                  : greySubtext,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${post.likesCount}',
                              style: const TextStyle(
                                color: greySubtext,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      InkWell(
                        onTap: () => _openPostComments(post),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: greySubtext,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${post.commentsCount}',
                              style: const TextStyle(
                                color: greySubtext,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () async {
                          final result = await FeedService().toggleSavePost(
                            post.id,
                            isCurrentlySaved: post.isSaved,
                          );
                          if (!mounted) return;
                          if (result.isSuccess) {
                            setState(() {
                              final idx = _posts.indexWhere((item) => item.id == post.id);
                              if (idx != -1) {
                                _posts[idx] = post.copyWith(
                                  isSaved: !post.isSaved,
                                );
                              }
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.error ?? 'Failed to update saved post',
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: greySubtext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        if (_feedHasMore)
          TextButton(
            onPressed: _isLoadingMore ? null : _loadMoreFeed,
            child: _isLoadingMore
                ? const CircularProgressIndicator()
                : const Text('Load more'),
          ),
      ],
    );
  }

  // ── Tab 4: Members ─────────────────────────────────────────────
  Widget _buildMembersTab() {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final member = _members[index];
        final isAdmin = member.role == CommunityRole.admin;
        final isMod = member.role == CommunityRole.moderator;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryOrange.withValues(alpha: 0.12),
                child: Text(
                  member.fullName.isNotEmpty
                      ? member.fullName[0].toUpperCase()
                      : 'M',
                  style: const TextStyle(
                    color: primaryOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: const TextStyle(
                        color: darkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      member.userName ?? '@resident',
                      style: const TextStyle(color: greySubtext, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      color: primaryOrange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (isMod)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Moderator',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              // 3-dots actions for admins / moderators
              if (_community.myRole == CommunityRole.admin ||
                  _community.myRole == CommunityRole.moderator) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    MemberActionSheet.show(
                      context,
                      member: member,
                      myRole: _community.myRole,
                      onUpdateRole: (newRole) =>
                          _updateMemberRole(member, newRole),
                      onRemove: () =>
                          _removeOrBanMember(member, ban: false),
                      onBan: () => _removeOrBanMember(member, ban: true),
                      onMessage: () => _openMemberChat(member),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Tab 5: Polls ───────────────────────────────────────────────
  Widget _buildPollsTab() {
    const primaryOrange = Color(0xFFFF6B00);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Create Poll Button (Available to all Community Members)
        if (_community.isMember) ...[
          OutlinedButton.icon(
            onPressed: () {
              CreatePollSheet.show(
                context,
                communityId: _community.id,
                onPollCreated: (newPoll) {
                  setState(() => _polls.insert(0, newPoll));
                },
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryOrange,
              side: const BorderSide(color: primaryOrange, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add_chart_rounded, size: 18),
            label: const Text(
              'Create New Poll',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_polls.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No active polls right now',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._polls.map((poll) {
            return CommunityPollCard(
              poll: poll,
              canDelete: _community.isMember,
              onDeletePoll: _handleDeletePoll,
              onVote: (pollId, optionId) async {
                await _communityService.votePoll(
                  _community.id,
                  pollId,
                  optionId,
                );
                // Optimistically fetch updated polls quietly without full-screen spinner
                final updatedPolls = await _communityService.getCommunityPolls(
                  _community.id,
                );
                if (mounted) {
                  setState(() => _polls = updatedPolls);
                }
              },
            );
          }),
      ],
    );
  }

  // ── Tab 6: Events ──────────────────────────────────────────────
  Widget _buildEventsTab() {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Host Event Button
        if (_community.isMember) ...[
          OutlinedButton.icon(
            onPressed: () {
              CreateCommunityEventSheet.show(
                context,
                communityId: _community.id,
                onEventCreated: (newEvent) =>
                    setState(() => _events.insert(0, newEvent)),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryOrange,
              side: const BorderSide(color: primaryOrange, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text(
              'Host Community Event',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_events.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Upcoming Events',
                    style: TextStyle(
                      color: darkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Organize match days, festival celebrations or meetings!',
                    style: TextStyle(color: greySubtext, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ..._events.map((ev) {
            final dt = ev.date;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              [
                                'SUN',
                                'MON',
                                'TUE',
                                'WED',
                                'THU',
                                'FRI',
                                'SAT',
                              ][dt.weekday % 7],
                              style: const TextStyle(
                                color: primaryOrange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${dt.day}',
                              style: const TextStyle(
                                color: primaryOrange,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ev.title,
                              style: const TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              ev.venue,
                              style: const TextStyle(
                                color: greySubtext,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (ev.description != null && ev.description!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      ev.description!,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Going: ${ev.goingCount}',
                        style: const TextStyle(
                          color: greySubtext,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final newStatus = ev.myRsvpStatus == 'going' ? 'declined' : 'going';
                            final updated = await _communityService
                                .rsvpCommunityEvent(_community.id, ev, newStatus);
                            if (mounted) {
                              setState(() {
                                final idx = _events.indexWhere((item) => item.id == ev.id);
                                if (idx != -1) {
                                  _events[idx] = updated;
                                }
                              });
                            }
                          } catch (error) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error.toString()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ev.myRsvpStatus == 'going'
                              ? const Color(0xFF10B981)
                              : primaryOrange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        icon: Icon(
                          ev.myRsvpStatus == 'going'
                              ? Icons.check_circle_outline_rounded
                              : Icons.event_available_rounded,
                          size: 16,
                        ),
                        label: Text(
                          ev.myRsvpStatus == 'going'
                              ? 'Attending'
                              : 'RSVP (Attend)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── Tab 5: Group Chat ──────────────────────────────────────────
  Widget _buildChatTab() {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5EE),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryOrange.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.forum_rounded,
                size: 40,
                color: primaryOrange,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${_community.name} Group Chat',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: darkText,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chat in real-time with all members of this community. Send voice notes, photos, and messages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: greySubtext, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _community.isMember ? _openCommunityChat : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text(
                'Enter Community Chat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
