import 'package:flutter/material.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';
import 'society_committee_builder_screen.dart';
import 'society_committee_workspace_screen.dart';

/// Generic Governance & Committee Management Screen
///
/// Decouples Committee Management from Security Console into a generic,
/// society-wide governance workspace for all committee categories:
/// Security, Maintenance, Events, Operations, Garden, Finance, and Custom.
class SocietyCommitteeManagementScreen extends StatefulWidget {
  final int societyId;
  final String userRole;

  const SocietyCommitteeManagementScreen({
    super.key,
    required this.societyId,
    this.userRole = 'admin',
  });

  @override
  State<SocietyCommitteeManagementScreen> createState() =>
      _SocietyCommitteeManagementScreenState();
}

class _SocietyCommitteeManagementScreenState
    extends State<SocietyCommitteeManagementScreen> {
  final _societyService = SocietyService();
  bool _isLoading = true;
  String? _error;

  List<SocietyCommitteeModel> _committees = [];
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadCommittees();
  }

  Future<void> _loadCommittees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _societyService.getCommittees(widget.societyId);
      if (mounted) {
        setState(() {
          _committees = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<SocietyCommitteeModel> get _filteredCommittees {
    if (_filterCategory == 'all') return _committees;
    return _committees
        .where((c) => c.committeeType.toLowerCase() == _filterCategory.toLowerCase())
        .toList();
  }

  bool get _isAdmin =>
      widget.userRole.toLowerCase() == 'admin' ||
      widget.userRole.toLowerCase() == 'owner';

  void _openBuilder([SocietyCommitteeModel? comm]) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SocietyCommitteeBuilderScreen(
          societyId: widget.societyId,
          existingCommittee: comm,
        ),
      ),
    );
    if (result == true) {
      _loadCommittees();
    }
  }

  void _showAddMemberDialog(SocietyCommitteeModel comm) {
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final desigCtrl = TextEditingController(text: 'Member');
    bool isInviting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Invite Member to ${comm.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Member starts in PENDING status. An authoritative invitation notification is emitted. PBAC permissions activate only upon member acceptance.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'User Mobile Number *',
                    hintText: 'e.g. 9876543210',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address (Optional)',
                    hintText: 'e.g. user@example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: desigCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Designation / Portfolio',
                    hintText: 'e.g. Lead, Coordinator, Treasurer',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isInviting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
              ),
              onPressed: isInviting
                  ? null
                  : () async {
                      if (phoneCtrl.text.trim().isEmpty && emailCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a phone number or email.')),
                        );
                        return;
                      }
                      setDialogState(() => isInviting = true);
                      try {
                        await _societyService.addCommitteeMember(
                          comm.id,
                          widget.societyId,
                          phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                          email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                          designation: desigCtrl.text.trim().isNotEmpty ? desigCtrl.text.trim() : 'Member',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Invitation sent successfully!'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                        }
                        _loadCommittees();
                      } catch (e) {
                        setDialogState(() => isInviting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
              child: isInviting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Invitation'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMembersSheet(SocietyCommitteeModel comm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${comm.name} — Members',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (_isAdmin)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAddMemberDialog(comm);
                          },
                          icon: const Icon(Icons.person_add_alt_1, size: 14),
                          label: const Text('Invite', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: comm.members.isEmpty
                        ? const Center(
                            child: Text(
                              'No members in this committee yet.\nTap "Invite" to send invitations.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: comm.members.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final m = comm.members[index];
                              final status = m.status.toLowerCase();
                              Color statusColor = const Color(0xFF64748B);
                              if (status == 'active') statusColor = const Color(0xFF059669);
                              if (status == 'pending') statusColor = const Color(0xFFD97706);
                              if (status == 'suspended') statusColor = Colors.orange;
                              if (status == 'revoked' || status == 'rejected') statusColor = Colors.red;

                              final name = m.userName ?? 'User #${m.userId}';
                              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: statusColor.withOpacity(0.15),
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                        color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                subtitle: Text(
                                  '${m.designation} • ${m.phone ?? m.email ?? ''}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: statusColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    m.status.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteCommittee(SocietyCommitteeModel comm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive ${comm.name}?'),
        content: const Text(
          'Archiving will deactivate all committee memberships and immediately revoke PBAC permissions for all members.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _societyService.deleteCommittee(comm.id, widget.societyId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Committee archived successfully.'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                }
                _loadCommittees();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Committees & Governance',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadCommittees,
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.white,
              onPressed: () => _openBuilder(),
              icon: const Icon(Icons.add),
              label: const Text('New Committee'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadCommittees, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildCategoryFilter(),
                    Expanded(
                      child: _filteredCommittees.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.groups_3_outlined, size: 54, color: Color(0xFFCBD5E1)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No committees found',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _filterCategory == 'all'
                                        ? 'Tap "New Committee" below to create one.'
                                        : 'No committees match the "$_filterCategory" category.',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _filteredCommittees.length,
                              itemBuilder: (context, index) {
                                final comm = _filteredCommittees[index];
                                return _buildCommitteeCard(comm);
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      {'key': 'all', 'label': 'All Committees'},
      {'key': 'security', 'label': 'Security'},
      {'key': 'maintenance', 'label': 'Maintenance'},
      {'key': 'events', 'label': 'Events'},
      {'key': 'operations', 'label': 'Operations'},
      {'key': 'garden', 'label': 'Garden'},
      {'key': 'finance', 'label': 'Finance'},
      {'key': 'custom', 'label': 'Custom'},
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final key = cat['key']!;
          final isSelected = _filterCategory == key;

          return ChoiceChip(
            label: Text(cat['label']!, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            selected: isSelected,
            selectedColor: const Color(0xFFFFF7ED),
            backgroundColor: const Color(0xFFF1F5F9),
            labelStyle: TextStyle(color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF475569)),
            side: BorderSide(color: isSelected ? const Color(0xFFFF6B00) : Colors.transparent),
            onSelected: (selected) {
              if (selected) setState(() => _filterCategory = key);
            },
          );
        },
      ),
    );
  }

  Widget _buildCommitteeCard(SocietyCommitteeModel comm) {
    Color typeColor = const Color(0xFF2563EB);
    IconData typeIcon = Icons.groups_3_rounded;

    final typeLower = comm.committeeType.toLowerCase();
    if (typeLower == 'security') {
      typeColor = const Color(0xFFDC2626);
      typeIcon = Icons.security_rounded;
    } else if (typeLower == 'maintenance') {
      typeColor = const Color(0xFFD97706);
      typeIcon = Icons.build_rounded;
    } else if (typeLower == 'events') {
      typeColor = const Color(0xFF7C3AED);
      typeIcon = Icons.event_rounded;
    } else if (typeLower == 'operations') {
      typeColor = const Color(0xFF0284C7);
      typeIcon = Icons.settings_suggest_rounded;
    } else if (typeLower == 'garden') {
      typeColor = const Color(0xFF059669);
      typeIcon = Icons.eco_rounded;
    } else if (typeLower == 'finance') {
      typeColor = const Color(0xFF0D9488);
      typeIcon = Icons.account_balance_rounded;
    }

    final activeMembersCount = comm.members.where((m) => m.status.toLowerCase() == 'active').length;
    final pendingCount = comm.members.where((m) => m.status.toLowerCase() == 'pending').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: typeColor.withOpacity(0.12),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comm.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              comm.committeeType.toUpperCase(),
                              style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            comm.scopeType == 'gate'
                                ? '• Gate #${comm.scopeId ?? '1'} Scoped'
                                : '• Entire Society',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                  onSelected: (val) {
                    if (val == 'workspace') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SocietyCommitteeWorkspaceScreen(
                            societyId: widget.societyId,
                            committeeId: comm.id,
                            committeeName: comm.name,
                          ),
                        ),
                      );
                    } else if (val == 'edit') {
                      _openBuilder(comm);
                    } else if (val == 'members') {
                      _showMembersSheet(comm);
                    } else if (val == 'archive') {
                      _confirmDeleteCommittee(comm);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'workspace',
                      child: Row(
                        children: [
                          Icon(Icons.dashboard_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Open Workspace'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'members',
                      child: Row(
                        children: [
                          Icon(Icons.people_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Manage Members'),
                        ],
                      ),
                    ),
                    if (_isAdmin) ...[
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Committee'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Archive', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (comm.description?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(
                comm.description!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Grants', '${comm.permissions.length} perms', Icons.shield_outlined),
                  _buildStatItem('Active Members', '$activeMembersCount active', Icons.person_outline),
                  _buildStatItem('Pending Invites', '$pendingCount pending', Icons.mail_outline),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => _showMembersSheet(comm),
                    icon: const Icon(Icons.people_alt_outlined, size: 16),
                    label: const Text('Members', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SocietyCommitteeWorkspaceScreen(
                            societyId: widget.societyId,
                            committeeId: comm.id,
                            committeeName: comm.name,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Workspace', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String val, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            Text(val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
      ],
    );
  }
}
