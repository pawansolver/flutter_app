import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';
import 'community_detail_screen.dart';

class CommunityGroupsScreen extends StatefulWidget {
  const CommunityGroupsScreen({Key? key}) : super(key: key);

  @override
  State<CommunityGroupsScreen> createState() => _CommunityGroupsScreenState();
}

class _CommunityGroupsScreenState extends State<CommunityGroupsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  final List<Map<String, dynamic>> _myGroups = [
    {
      'title': 'Sunday Cricket Club',
      'members': 42,
      'hasUnread': true,
      'description': 'A group for local cricket enthusiasts. We play every Sunday morning.',
    },
    {
      'title': 'Weekend Book Reading',
      'members': 15,
      'hasUnread': false,
      'description': 'Join us to discuss our favorite books over coffee.',
    },
  ];

  final List<Map<String, dynamic>> _discoverGroups = [
    {
      'title': 'Organic Gardening',
      'members': 120,
      'description': 'Tips, seeds exchange, and discussions about organic terrace gardening.',
    },
    {
      'title': 'Patna Runners Club',
      'members': 340,
      'description': 'Morning runs, marathon prep, and fitness goals.',
    },
    {
      'title': 'Tech Enthusiasts',
      'members': 56,
      'description': 'Discuss the latest in tech, gadgets, and programming.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE1EAE4),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
            onPressed: _handleBack,
          ),
          title: const Text(
            'Interest Groups',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFFF6B00),
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            indicatorColor: const Color(0xFFFF6B00),
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'My Groups'),
              Tab(text: 'Discover New'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMyGroupsTab(),
            _buildDiscoverTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFFFF6B00),
          elevation: 0,
          onPressed: () {
            // Action for creating a new group
          },
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Create Group',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _myGroups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = _myGroups[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommunityDetailScreen(group: group),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Center(
                    child: Icon(Icons.groups_outlined, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          if (group['hasUnread'])
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B00),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group['members']} active members',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _discoverGroups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = _discoverGroups[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Center(
                      child: Icon(Icons.explore_outlined, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group['members']} members',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                group['description'],
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B00),
                    side: const BorderSide(color: Color(0xFFFF6B00)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Joined ${group['title']}'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  },
                  child: const Text('Join Group', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
