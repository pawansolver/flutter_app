import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/community_models.dart';
import '../../services/community_service.dart';
import '../dashboard/main_dashboard.dart';
import 'community_detail_screen.dart';
import 'community_invitations_screen.dart';
import 'create_community_screen.dart';
import 'widgets/community_card.dart';

class CommunityGroupsScreen extends StatefulWidget {
  const CommunityGroupsScreen({super.key});

  @override
  State<CommunityGroupsScreen> createState() => _CommunityGroupsScreenState();
}

class _CommunityGroupsScreenState extends State<CommunityGroupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _communityService = CommunityService();
  final _searchController = TextEditingController();

  List<CommunityCategoryModel> _categories = [];
  int _selectedCategoryId = 0; // 0 = local "All" sentinel
  Timer? _searchDebounce;

  List<CommunityModel> _myCommunities = [];
  List<CommunityModel> _suggestedCommunities = [];
  final Set<int> _joiningCommunityIds = {};

  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
        (route) => false,
      );
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final catsFuture = _communityService.getCategories();
      final myFuture = _communityService.getMyCommunities();
      final suggestedFuture = _communityService.getSuggestedCommunities(
        categoryId: _selectedCategoryId > 0 ? _selectedCategoryId : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      final results = await Future.wait([
        catsFuture,
        myFuture,
        suggestedFuture,
      ]);

      if (mounted) {
        setState(() {
          _categories = results[0] as List<CommunityCategoryModel>;
          _myCommunities = results[1] as List<CommunityModel>;
          _suggestedCommunities = results[2] as List<CommunityModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _filterBySearchOrCategory() async {
    try {
      final suggested = await _communityService.getSuggestedCommunities(
        categoryId: _selectedCategoryId > 0 ? _selectedCategoryId : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (mounted) {
        setState(() => _suggestedCommunities = suggested);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _handleJoinToggle(CommunityModel community) async {
    if (_joiningCommunityIds.contains(community.id)) return;
    setState(() => _joiningCommunityIds.add(community.id));
    try {
      final isCurrentlyMember = community.isMember;
      if (isCurrentlyMember) {
        final success = await _communityService.leaveCommunity(community.id);
        if (success && mounted) {
          setState(() {
            _myCommunities.removeWhere((c) => c.id == community.id);
            final idx = _suggestedCommunities.indexWhere(
              (c) => c.id == community.id,
            );
            if (idx != -1) {
              _suggestedCommunities[idx] = community.copyWith(
                isMember: false,
                joinStatus: CommunityJoinStatus.none,
                membersCount: (community.membersCount - 1).clamp(0, 999999),
              );
            }
          });
        }
      } else {
        final result = await _communityService.joinCommunity(community.id);
        if (!mounted) return;
        final joined = result.isMember;
        final updated = community.copyWith(
          isMember: joined,
          joinStatus: result.status,
          membersCount: joined
              ? community.membersCount + 1
              : community.membersCount,
          myRole: joined ? CommunityRole.member : CommunityRole.none,
        );
        setState(() {
          if (joined && !_myCommunities.any((c) => c.id == community.id)) {
            _myCommunities.add(updated);
          }
          final idx = _suggestedCommunities.indexWhere(
            (c) => c.id == community.id,
          );
          if (idx != -1) {
            _suggestedCommunities[idx] = updated;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isPending
                  ? 'Join request sent to Admin!'
                  : '🎉 Joined ${community.name}!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _joiningCommunityIds.remove(community.id));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: darkText),
            onPressed: _handleBack,
          ),
          title: const Text(
            'Communities & Groups',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Community invitations',
              icon: const Icon(Icons.mail_outline_rounded, color: darkText),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CommunityInvitationsScreen(),
                  ),
                );
                if (mounted) await _loadInitialData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: darkText),
              onPressed: _loadInitialData,
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(108),
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search communities, sports, clubs...',
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _filterBySearchOrCategory();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 11,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 350),
                          _filterBySearchOrCategory,
                        );
                      },
                    ),
                  ),
                ),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  labelColor: primaryOrange,
                  unselectedLabelColor: greySubtext,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  indicatorColor: primaryOrange,
                  indicatorWeight: 2.5,
                  tabs: [
                    Tab(text: 'My Groups (${_myCommunities.length})'),
                    const Tab(text: 'Discover New'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            // Category Chips (only active in Discover Tab or global)
            if (_categories.isNotEmpty)
              Container(
                height: 48,
                color: Colors.white,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategoryId == cat.id;

                    // Determine if icon is a URL (points to a server) or an emoji
                    final icon = cat.icon;
                    final bool isUrlIcon =
                        icon != null &&
                        (icon.startsWith('http') || icon.startsWith('/'));
                    final bool isEmojiIcon =
                        icon != null && !isUrlIcon && icon.isNotEmpty;

                    return ChoiceChip(
                      avatar: isUrlIcon
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                icon,
                                width: 18,
                                height: 18,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.category_rounded,
                                  size: 14,
                                  color: primaryOrange,
                                ),
                              ),
                            )
                          : null,
                      label: Text(
                        isEmojiIcon ? '$icon ${cat.name}' : cat.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : darkText,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: primaryOrange,
                      backgroundColor: const Color(0xFFF3F4F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      showCheckmark: false,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategoryId = cat.id);
                          _filterBySearchOrCategory();
                        }
                      },
                    );
                  },
                ),
              ),

            // Body content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryOrange),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: darkText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadInitialData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryOrange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [_buildMyGroupsList(), _buildDiscoverList()],
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: primaryOrange,
          elevation: 2,
          onPressed: () async {
            final newCommunity = await Navigator.push<CommunityModel>(
              context,
              MaterialPageRoute(builder: (_) => const CreateCommunityScreen()),
            );
            if (newCommunity != null) {
              setState(() {
                _myCommunities.insert(0, newCommunity);
                _suggestedCommunities.insert(0, newCommunity);
              });
            }
          },
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Create Community',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildMyGroupsList() {
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    if (_myCommunities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF5EE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  size: 40,
                  color: Color(0xFFFF6B00),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Groups Joined Yet',
                style: TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Explore neighborhood clubs in the Discover tab or create your own group!',
                textAlign: TextAlign.center,
                style: TextStyle(color: greySubtext, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Discover Nearby Groups'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: const Color(0xFFFF6B00),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _myCommunities.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _myCommunities[index];
          return CommunityCard(
            community: item,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommunityDetailScreen(community: item),
                ),
              ).then((_) => _loadInitialData());
            },
            onJoinToggle: () => _handleJoinToggle(item),
            isJoining: _joiningCommunityIds.contains(item.id),
          );
        },
      ),
    );
  }

  Widget _buildDiscoverList() {
    const darkText = Color(0xFF111827);
    const greySubtext = Color(0xFF6B7280);

    if (_suggestedCommunities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No Communities Found',
                style: TextStyle(
                  color: darkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Try searching with a different keyword or category.',
                style: TextStyle(color: greySubtext, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: const Color(0xFFFF6B00),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _suggestedCommunities.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _suggestedCommunities[index];
          return CommunityCard(
            community: item,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommunityDetailScreen(community: item),
                ),
              ).then((_) => _loadInitialData());
            },
            onJoinToggle: () => _handleJoinToggle(item),
            isJoining: _joiningCommunityIds.contains(item.id),
          );
        },
      ),
    );
  }
}
