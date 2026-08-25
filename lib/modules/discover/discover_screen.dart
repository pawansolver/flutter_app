import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';
import '../../widgets/custom_drawer.dart';
import '../community/community_groups_screen.dart';
import '../profile/follow_service.dart';
import '../profile/user_profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _followService = FollowService();
  bool _loading = true;
  String? _error;
  List<FollowUserModel> _users = [];
  String _activeRadius = 'Within 500m';
  final List<String> _radiusOptions = ['Within 500m', '1 km', '2 km', '5 km'];

  final List<Map<String, dynamic>> _trendingItems = [
    {
      'type': 'Business',
      'title': 'Verma Grocery Mart',
      'subtitle': 'Special discount on monthly supplies. Delivery available.',
      'tag': 'Featured Local',
    },
    {
      'type': 'Event',
      'title': 'Community Yoga Session',
      'subtitle': 'Join us at Central Park every Sunday morning at 6 AM.',
      'tag': 'Trending Event',
    },
    {
      'type': 'Post',
      'title': 'Lost Golden Retriever',
      'subtitle': 'Please help find Max. Last seen near Block B gate.',
      'tag': 'Urgent Alert',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _followService.getSuggestedUsers();
    if (!mounted) return;
    setState(() {
      if (result.isSuccess) {
        _users = result.data ?? [];
      } else {
        _error = result.error ?? 'Unknown error occurred.';
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    void handleBack() {
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

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE1EAE4),
        drawer: const CustomDrawer(),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
                  onPressed: handleBack,
                )
              : Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFF111827)),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  ),
                ),

        title: const Text(
          'Discover Nearby',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE5E7EB),
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search people, businesses, events...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF6B00)),
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
            
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _radiusOptions.map((radius) {
                    final isActive = _activeRadius == radius;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeRadius = radius;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFFFF6B00) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? const Color(0xFFFF6B00) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          radius,
                          style: TextStyle(
                            color: isActive ? Colors.white : const Color(0xFF111827),
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            
            // Communities & Groups Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CommunityGroupsScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8A00), Color(0xFFFF6B00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.groups_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Explore Communities',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Join neighborhood clubs, sports & groups',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'People on SmartGali',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
              )
            else if (_users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No users found in your area yet.'),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: _users.map((person) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: person.userId,
                              userName: person.userName,
                              fullName: person.fullName,
                              avatarUrl: person.avatarUrl,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                              backgroundImage: person.avatarUrl != null && person.avatarUrl!.isNotEmpty
                                  ? NetworkImage(person.avatarUrl!)
                                  : null,
                              child: person.avatarUrl == null || person.avatarUrl!.isEmpty
                                  ? Text(
                                      person.displayName.isNotEmpty ? person.displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              person.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${person.userName}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: Text(
                'Trending & Highlights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              itemCount: _trendingItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = _trendingItems[index];
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item['tag'],
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            item['type'],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['subtitle'],
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 14,
                          height: 1.4,
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
      ),
      ),
    );
  }
}
