import 'package:flutter/material.dart';
import '../../../core/api_config.dart';
import '../../../services/authenticated_dio.dart';
import '../../../services/event_service.dart';

class InviteFriendsSheet extends StatefulWidget {
  final int eventId;
  final String eventTitle;

  const InviteFriendsSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<InviteFriendsSheet> {
  final _eventService = EventService();
  final _dio = AuthenticatedDio().dio;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _allUsers = [];
  final Set<int> _selectedUserIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First try to fetch followed users
      List<Map<String, dynamic>> users = [];
      try {
        final res = await _dio.get(ApiConfig.myFollowing);
        final body = res.data;
        final list = (body['data'] is List ? body['data'] : (body['following'] ?? [])) as List;
        users = list.whereType<Map<String, dynamic>>().map((item) {
          final u = item['user'] is Map<String, dynamic> ? item['user'] as Map<String, dynamic> : item;
          return {
            'userId': u['userId'] ?? u['id'],
            'userName': u['userName'] ?? u['name'] ?? 'User #${u['userId'] ?? u['id']}',
            'profileImage': u['profile_image'] ?? u['avatarUrl'],
          };
        }).toList();
      } catch (_) {}

      // If following list is empty or fails, fallback to general user discovery
      if (users.isEmpty) {
        try {
          final res = await _dio.get(ApiConfig.allUsers, queryParameters: {'limit': 50});
          final body = res.data;
          final list = (body['data'] is List ? body['data'] : (body['users'] ?? [])) as List;
          users = list.whereType<Map<String, dynamic>>().map((u) {
            return {
              'userId': u['userId'] ?? u['id'],
              'userName': u['userName'] ?? u['name'] ?? 'User #${u['userId'] ?? u['id']}',
              'profileImage': u['profile_image'] ?? u['avatarUrl'],
            };
          }).toList();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) return _allUsers;
    final q = _searchQuery.trim().toLowerCase();
    return _allUsers.where((u) {
      final name = (u['userName'] ?? '').toString().toLowerCase();
      return name.contains(q);
    }).toList();
  }

  Future<void> _sendInvitations() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final res = await _eventService.sendInvitations(
        widget.eventId,
        _selectedUserIds.toList(),
      );

      if (mounted) {
        setState(() => _isSending = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${res.length} invitation(s) sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invite Friends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      widget.eventTitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 8),

          // Selection indicator bar
          if (_selectedUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${_selectedUserIds.length} friend(s) selected',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF18D38), fontSize: 13),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedUserIds.clear()),
                    child: const Text('Clear all', style: TextStyle(fontSize: 12, color: Color(0xFFF18D38))),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Users list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF18D38)))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _filteredUsers.isEmpty
                        ? const Center(
                            child: Text('No users found', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.separated(
                            itemCount: _filteredUsers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final u = _filteredUsers[index];
                              final userId = u['userId'] as int?;
                              if (userId == null) return const SizedBox.shrink();
                              final isSelected = _selectedUserIds.contains(userId);
                              final name = (u['userName'] ?? 'User').toString();

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: const Color(0xFFF18D38),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedUserIds.add(userId);
                                    } else {
                                      _selectedUserIds.remove(userId);
                                    }
                                  });
                                },
                                secondary: CircleAvatar(
                                  backgroundColor: const Color(0xFFFFF4EC),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                    style: const TextStyle(color: Color(0xFFF18D38), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              );
                            },
                          ),
          ),

          // Bottom Send Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _selectedUserIds.isEmpty || _isSending ? null : _sendInvitations,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF18D38),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: Text(
                    _isSending ? 'Sending...' : 'Send Invitations (${_selectedUserIds.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
