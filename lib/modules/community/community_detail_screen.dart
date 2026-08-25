import 'package:flutter/material.dart';
import '../../models/community_models.dart';
import '../../services/community_service.dart';
import '../chat/chat_window_screen.dart';
import 'widgets/community_poll_card.dart';

class CommunityDetailScreen extends StatefulWidget {
  final CommunityModel community;

  const CommunityDetailScreen({
    super.key,
    required this.community,
  });

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _communityService = CommunityService();
  final _postTextController = TextEditingController();

  late CommunityModel _community;
  List<CommunityPostModel> _posts = [];
  List<CommunityMemberModel> _members = [];
  List<CommunityPollModel> _polls = [];

  bool _isLoading = true;
  bool _isJoining = false;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _community = widget.community;
    _tabController = TabController(length: 5, vsync: this);
    _loadAllCommunityData();
  }

  Future<void> _loadAllCommunityData() async {
    setState(() => _isLoading = true);
    try {
      final detailsFuture = _communityService.getCommunityDetails(_community.id);
      final feedFuture = _communityService.getCommunityFeed(_community.id);
      final membersFuture = _communityService.getCommunityMembers(_community.id);
      final pollsFuture = _communityService.getCommunityPolls(_community.id);

      final results = await Future.wait([
        detailsFuture,
        feedFuture,
        membersFuture,
        pollsFuture,
      ]);

      if (mounted) {
        setState(() {
          _community = results[0] as CommunityModel;
          _posts = results[1] as List<CommunityPostModel>;
          _members = results[2] as List<CommunityMemberModel>;
          _polls = results[3] as List<CommunityPollModel>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
        final success = await _communityService.joinCommunity(_community.id);
        if (success && mounted) {
          setState(() {
            _community = _community.copyWith(
              isMember: true,
              membersCount: _community.membersCount + 1,
              myRole: CommunityRole.member,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _community.isPrivate
                    ? 'Join request sent to Admin!'
                    : '🎉 Welcome to ${_community.name}!',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _handleCreatePost() async {
    final text = _postTextController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      final newPost = await _communityService.createCommunityPost(
        _community.id,
        content: text,
      );
      if (mounted) {
        setState(() {
          _posts.insert(0, newPost);
          _postTextController.clear();
          _community = _community.copyWith(postsCount: _community.postsCount + 1);
        });
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published to community!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showCreatePostBottomSheet() {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Post in ${_community.name}',
                    style: const TextStyle(
                      color: darkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _postTextController,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Share updates, questions, or ideas with group members...',
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: primaryOrange),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.poll_outlined, color: primaryOrange),
                    onPressed: () {},
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isPosting ? null : _handleCreatePost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Post', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                const Text('1. Be respectful to all members\n2. No spam or hate speech'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postTextController.dispose();
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
                backgroundColor: Colors.white.withOpacity(0.9),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: darkText, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              actions: [
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: IconButton(
                    icon: const Icon(Icons.info_outline, color: darkText, size: 20),
                    onPressed: _showRulesDialog,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined, color: darkText, size: 20),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 12),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover Banner
                    _community.coverImageUrl != null && _community.coverImageUrl!.isNotEmpty
                        ? Image.network(
                            _community.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFFFF5EE),
                              child: const Icon(Icons.groups_rounded, color: primaryOrange, size: 64),
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
                              child: Icon(Icons.group_work_rounded, color: Colors.white24, size: 80),
                            ),
                          ),

                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.65),
                            Colors.transparent,
                            Colors.black.withOpacity(0.75),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _community.category ?? 'General',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _community.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_community.membersCount} Members • ${_community.postsCount} Posts • ${_community.isPrivate ? '🔒 Private' : '🌐 Public'}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _community.description ?? 'A neighborhood community group.',
                      style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Join/Leave CTA
                        Expanded(
                          child: _community.isMember
                              ? OutlinedButton.icon(
                                  onPressed: _isJoining ? null : _handleJoinToggle,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF10B981),
                                    side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.check_circle, size: 16),
                                  label: const Text('Member (Joined)', style: TextStyle(fontWeight: FontWeight.bold)),
                                )
                              : ElevatedButton.icon(
                                  onPressed: _isJoining ? null : _handleJoinToggle,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryOrange,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  icon: const Icon(Icons.group_add_rounded, size: 18),
                                  label: Text(
                                    _community.isPrivate ? 'Request to Join' : 'Join Community',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        // Invite button
                        OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: darkText,
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                          label: const Text('Invite', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // TabBar Header (5 PRD Tabs)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: primaryOrange,
                  unselectedLabelColor: greySubtext,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  indicatorColor: primaryOrange,
                  indicatorWeight: 2.5,
                  tabs: const [
                    Tab(text: '📝 Feed'),
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
            ? const Center(child: CircularProgressIndicator(color: primaryOrange))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildFeedTab(),
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
        // Create Post Bar
        if (_community.isMember)
          GestureDetector(
            onTap: _showCreatePostBottomSheet,
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
                    child: Icon(Icons.edit_outlined, color: primaryOrange, size: 18),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Share an update with the group...',
                      style: TextStyle(color: greySubtext, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.photo_camera_outlined, color: greySubtext, size: 20),
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
                  Text('No posts yet', style: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Be the first to share something in this community!', style: TextStyle(color: greySubtext, fontSize: 13)),
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
                    color: Colors.black.withOpacity(0.02),
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
                        backgroundColor: primaryOrange.withOpacity(0.12),
                        child: Text(
                          post.authorName.isNotEmpty ? post.authorName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: primaryOrange, fontWeight: FontWeight.bold),
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
                                style: const TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (post.authorRole != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    post.authorRole!,
                                    style: const TextStyle(color: primaryOrange, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Text('3 hrs ago', style: TextStyle(color: greySubtext, fontSize: 11)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.more_horiz, color: greySubtext, size: 18),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Post Text
                  Text(
                    post.content,
                    style: const TextStyle(color: darkText, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  const SizedBox(height: 10),

                  // Interactions
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            final idx = _posts.indexOf(post);
                            _posts[idx] = post.copyWith(
                              isLikedByMe: !post.isLikedByMe,
                              likesCount: post.isLikedByMe ? post.likesCount - 1 : post.likesCount + 1,
                            );
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                              color: post.isLikedByMe ? Colors.red : greySubtext,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text('${post.likesCount}', style: const TextStyle(color: greySubtext, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: greySubtext, size: 18),
                          const SizedBox(width: 6),
                          Text('${post.commentsCount}', style: const TextStyle(color: greySubtext, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
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

  // ── Tab 2: Members ─────────────────────────────────────────────
  Widget _buildMembersTab() {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                backgroundColor: primaryOrange.withOpacity(0.12),
                child: Text(
                  member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'M',
                  style: const TextStyle(color: primaryOrange, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.fullName,
                      style: const TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(color: primaryOrange, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                )
              else if (isMod)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Moderator',
                    style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 3: Polls ───────────────────────────────────────────────
  Widget _buildPollsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_polls.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('No active polls right now', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._polls.map((poll) {
            return CommunityPollCard(
              poll: poll,
              onVote: (pollId, optionId) async {
                await _communityService.votePoll(pollId, optionId);
                _loadAllCommunityData();
              },
            );
          }),
      ],
    );
  }

  // ── Tab 4: Events ──────────────────────────────────────────────
  Widget _buildEventsTab() {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: const [
                        Text('SUN', style: TextStyle(color: primaryOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('30', style: TextStyle(color: primaryOrange, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Sunday Morning Cricket Tournament', style: TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('7:00 AM • Mini Stadium Sector 62', style: TextStyle(color: greySubtext, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Bring your kits! 20-over match between Team Alpha and Team Bravo. Refreshments sponsored.',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('24 Attending', style: TextStyle(color: greySubtext, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('RSVP Confirmed! You are attending this event.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('RSVP (Attend)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                border: Border.all(color: primaryOrange.withOpacity(0.2), width: 2),
              ),
              child: const Icon(Icons.forum_rounded, size: 40, color: primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              '${_community.name} Group Chat',
              textAlign: TextAlign.center,
              style: const TextStyle(color: darkText, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Chat in real-time with all members of this community. Send voice notes, photos, and messages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: greySubtext, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatWindowScreen(
                      chatId: _community.id,
                      chatName: _community.name,
                      isOnline: true,
                      currentUserId: 1,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Enter Community Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
