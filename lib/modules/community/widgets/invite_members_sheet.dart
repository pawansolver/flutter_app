import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/community_models.dart';
import '../../../services/community_service.dart';

class InviteMembersSheet extends StatefulWidget {
  final int communityId;
  final String communityName;

  const InviteMembersSheet({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  static void show(
    BuildContext context, {
    required int communityId,
    required String communityName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => InviteMembersSheet(
        communityId: communityId,
        communityName: communityName,
      ),
    );
  }

  @override
  State<InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _InviteMembersSheetState extends State<InviteMembersSheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedUserIds = {};
  final CommunityService _service = CommunityService();
  List<CommunityInviteableUser> _users = [];
  Timer? _debounce;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _service.getInviteableUsers(
        widget.communityId,
        search: _searchController.text,
      );
      if (mounted) setState(() => _users = page.items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _shareLink() {
    final link = 'https://smartgali.com/community/${widget.communityId}';
    SharePlus.instance.share(
      ShareParams(
        text:
            'Hey neighbor! Join the "${widget.communityName}" community on SmartGali: $link',
        subject: 'Join ${widget.communityName}',
      ),
    );
  }

  void _copyLink() {
    final link = 'https://smartgali.com/community/${widget.communityId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Community invite link copied to clipboard!'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendInvites() async {
    setState(() => _isSending = true);
    try {
      final count = await _service.sendInvitations(
        widget.communityId,
        _selectedUserIds.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$count invitation(s) sent')));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF6B00);
    const darkText = Color(0xFF111827);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_add_rounded,
                  color: primaryOrange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite Neighbors',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: darkText,
                      ),
                    ),
                    Text(
                      widget.communityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Share Link Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Colors.grey, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'smartgali.com/c/${widget.communityId}',
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: primaryOrange,
                  ),
                  tooltip: 'Copy Link',
                  onPressed: _copyLink,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.share_rounded,
                    size: 18,
                    color: primaryOrange,
                  ),
                  tooltip: 'Share Link',
                  onPressed: _shareLink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Search Neighbors
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search neighbors by name or flat...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Colors.grey,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryOrange),
              ),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _loadUsers);
            },
          ),
          const SizedBox(height: 12),

          // Neighbors List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: TextButton(
                      onPressed: _loadUsers,
                      child: Text('Retry: $_error'),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isSelected = _selectedUserIds.contains(user.userId);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedUserIds.remove(user.userId);
                            } else {
                              _selectedUserIds.add(user.userId);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: user.avatarUrl == null
                                    ? null
                                    : NetworkImage(user.avatarUrl!),
                                child: user.avatarUrl == null
                                    ? Text(user.fullName.substring(0, 1))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: darkText,
                                      ),
                                    ),
                                    Text(
                                      '@${user.userName}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Checkbox(
                                value: isSelected,
                                activeColor: primaryOrange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedUserIds.add(user.userId);
                                    } else {
                                      _selectedUserIds.remove(user.userId);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // Send Invites Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedUserIds.isEmpty || _isSending
                  ? null
                  : _sendInvites,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _selectedUserIds.isEmpty
                    ? 'Select neighbors to invite'
                    : 'Send Invites (${_selectedUserIds.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
