import 'package:flutter/material.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';

class SocietyMembersScreen extends StatefulWidget {
  final int societyId;
  final String userRole; // 'admin' | 'committee' | 'resident'

  const SocietyMembersScreen({
    super.key,
    required this.societyId,
    required this.userRole,
  });

  @override
  State<SocietyMembersScreen> createState() => _SocietyMembersScreenState();
}

class _SocietyMembersScreenState extends State<SocietyMembersScreen> with SingleTickerProviderStateMixin {
  final _societyService = SocietyService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  List<SocietyMemberModel> _activeMembers = [];
  List<SocietyMemberModel> _pendingMembers = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin';
  bool get _canManage => _isAdmin || widget.userRole.toLowerCase() == 'committee';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _canManage ? 2 : 1, vsync: this);
    _loadMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final activeRes = await _societyService.getMembers(
        widget.societyId,
        status: 'active',
        limit: 100,
      );

      List<SocietyMemberModel> pendingList = [];
      if (_canManage) {
        try {
          final pendingRes = await _societyService.getMembers(
            widget.societyId,
            status: 'pending',
            limit: 100,
          );
          pendingList = pendingRes.data;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _activeMembers = activeRes.data;
          _pendingMembers = pendingList;
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

  Future<void> _approveMember(SocietyMemberModel member) async {
    try {
      await _societyService.approveMember(member.id, widget.societyId, status: 'active');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.userName} approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMembers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _changeMemberRole(SocietyMemberModel member) async {
    String selectedRole = member.role;
    final roles = ['resident', 'committee', 'security'];

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('Change Role: ${member.userName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles.map((r) {
              return RadioListTile<String>(
                title: Text(r.toUpperCase()),
                value: r,
                groupValue: selectedRole,
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedRole = val);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selectedRole),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (updated != null && updated != member.role) {
      try {
        await _societyService.updateMemberRole(member.id, widget.societyId, role: updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Updated role to ${updated.toUpperCase()}'),
              backgroundColor: Colors.green,
            ),
          );
          _loadMembers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _removeMember(SocietyMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Are you sure you want to remove ${member.userName} from this society?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _societyService.removeMember(member.id, widget.societyId, deletedRemarks: 'Removed by Admin');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member removed successfully'), backgroundColor: Colors.green),
          );
          _loadMembers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  List<SocietyMemberModel> get _filteredActiveMembers {
    if (_searchQuery.trim().isEmpty) return _activeMembers;
    final q = _searchQuery.trim().toLowerCase();
    return _activeMembers.where((m) {
      final name = m.userName.toLowerCase();
      final flat = (m.flatNo ?? '').toLowerCase();
      final role = m.role.toLowerCase();
      return name.contains(q) || flat.contains(q) || role.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Society Members'),
        bottom: _canManage
            ? TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'Active (${_activeMembers.length})'),
                  Tab(text: 'Pending (${_pendingMembers.length})'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadMembers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _canManage
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildActiveMembersList(),
                        _buildPendingMembersList(),
                      ],
                    )
                  : _buildActiveMembersList(),
    );
  }

  Widget _buildActiveMembersList() {
    final list = _filteredActiveMembers;

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members by name, flat, role...',
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
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No members found', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = list[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(m.userName.isNotEmpty ? m.userName[0].toUpperCase() : 'U'),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.userName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildRoleBadge(m.role),
                          ],
                        ),
                        subtitle: Text(
                          [
                            if (m.flatNo != null && m.flatNo!.isNotEmpty) 'Flat: ${m.flatNo}',
                            if (m.userEmail.isNotEmpty) m.userEmail,
                          ].join(' • '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: _isAdmin && m.role.toLowerCase() != 'admin'
                            ? PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'role') {
                                    _changeMemberRole(m);
                                  } else if (action == 'remove') {
                                    _removeMember(m);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'role',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('Change Role'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Remove Member', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingMembersList() {
    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: _pendingMembers.isEmpty
          ? const Center(child: Text('No pending membership requests', style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _pendingMembers.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final m = _pendingMembers[index];
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Text(m.userName.isNotEmpty ? m.userName[0].toUpperCase() : 'U'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (m.flatNo != null && m.flatNo!.isNotEmpty)
                                Text('Applied for Flat: ${m.flatNo}', style: const TextStyle(fontSize: 12)),
                              if (m.userPhone.isNotEmpty)
                                Text('Phone: ${m.userPhone}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              tooltip: 'Reject',
                              onPressed: () => _removeMember(m),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              tooltip: 'Approve',
                              onPressed: () => _approveMember(m),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color = Colors.blueGrey;
    if (role.toLowerCase() == 'admin' || role.toLowerCase() == 'owner') {
      color = Colors.indigo;
    } else if (role.toLowerCase() == 'committee') {
      color = Colors.teal;
    } else if (role.toLowerCase() == 'security') {
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
