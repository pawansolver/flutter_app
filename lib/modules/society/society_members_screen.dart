import 'package:flutter/material.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';

class SocietyMembersScreen extends StatefulWidget {
  final int societyId;
  final String userRole; // 'admin' | 'committee' | 'resident'
  final int initialTab;

  const SocietyMembersScreen({
    super.key,
    required this.societyId,
    required this.userRole,
    this.initialTab = 0,
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
    final tabCount = _canManage ? 2 : 1;
    final initialIdx = (widget.initialTab == 1 && _canManage) ? 1 : 0;
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: initialIdx);
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
    String selectedRole = member.role.toLowerCase() == 'security' ? 'staff' : member.role;
    if (!['admin', 'committee', 'staff', 'member'].contains(selectedRole)) {
      selectedRole = 'member';
    }
    String selectedPortfolio = member.remark ?? '🛡️ Security & Gate Head (Guard In-Charge)';
    final customPortfolioCtrl = TextEditingController(text: member.remark ?? '');

    final portfolioPresets = [
      '🛡️ Security & Gate Head (Guard In-Charge)',
      '🌳 Garden & Amenities Head',
      '🔧 Maintenance & Complaints Head',
      '📢 Cultural & Events Head',
      '📋 General Committee Member',
      '✏️ Custom Portfolio...',
    ];

    bool isCustom = !portfolioPresets.any((p) => p.contains(member.remark ?? '___xyz___')) &&
        (member.remark != null && member.remark!.isNotEmpty);
    if (isCustom) {
      selectedPortfolio = '✏️ Custom Portfolio...';
    } else {
      final match = portfolioPresets.firstWhere(
        (p) => p.contains(member.remark ?? ''),
        orElse: () => portfolioPresets[0],
      );
      selectedPortfolio = match;
    }

    final updated = await showDialog<Map<String, String?>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Assign Role & Duties: ${member.userName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Role:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                RadioListTile<String>(
                  title: const Text('Committee Member', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Manage society, guards, complaints, or amenities'),
                  value: 'committee',
                  groupValue: selectedRole,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                if (selectedRole == 'committee') ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Assigned Portfolio / Head Area:',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF059669))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedPortfolio,
                              items: portfolioPresets.map((p) {
                                return DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedPortfolio = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        if (selectedPortfolio == '✏️ Custom Portfolio...') ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: customPortfolioCtrl,
                            decoration: InputDecoration(
                              hintText: 'e.g. Parking & Traffic In-Charge',
                              labelText: 'Custom Portfolio Name',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                RadioListTile<String>(
                  title: const Text('Security Guard (Gate Staff)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Visitor Check-in/out and gate control duties'),
                  value: 'staff',
                  groupValue: selectedRole,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Resident (Flat Member)'),
                  subtitle: const Text('Normal flat resident with visitor approvals'),
                  value: 'member',
                  groupValue: selectedRole,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Society Admin'),
                  subtitle: const Text('Full society management access'),
                  value: 'admin',
                  groupValue: selectedRole,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedRole = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                String? finalRemark;
                if (selectedRole == 'committee') {
                  if (selectedPortfolio == '✏️ Custom Portfolio...') {
                    finalRemark = customPortfolioCtrl.text.trim();
                  } else {
                    // Extract clean name without emoji
                    finalRemark = selectedPortfolio.replaceAll(RegExp(r'^[^\w]+'), '').trim();
                  }
                }
                Navigator.pop(ctx, {
                  'role': selectedRole,
                  'remark': finalRemark,
                });
              },
              child: const Text('Save & Assign'),
            ),
          ],
        ),
      ),
    );

    if (updated != null) {
      try {
        await _societyService.updateMemberRole(
          member.id,
          widget.societyId,
          role: updated['role']!,
          remark: updated['remark'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Updated role to ${updated['role']!.toUpperCase()}'
                '${updated['remark'] != null && updated['remark']!.isNotEmpty ? ' (${updated['remark']})' : ''}',
              ),
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

  String _selectedRoleFilter = 'all';

  List<SocietyMemberModel> get _filteredActiveMembers {
    var list = _activeMembers;
    if (_selectedRoleFilter == 'committee') {
      list = list.where((m) => m.isCommittee).toList();
    } else if (_selectedRoleFilter == 'guard') {
      list = list.where((m) => m.isStaff || m.isSecurity).toList();
    } else if (_selectedRoleFilter == 'resident') {
      list = list.where((m) => !m.isAdmin && !m.isCommittee && !m.isStaff && !m.isSecurity).toList();
    }

    if (_searchQuery.trim().isEmpty) return list;
    final q = _searchQuery.trim().toLowerCase();
    return list.where((m) {
      final name = m.userName.toLowerCase();
      final flat = (m.flatNo ?? '').toLowerCase();
      final role = m.role.toLowerCase();
      final portfolio = m.portfolio.toLowerCase();
      return name.contains(q) || flat.contains(q) || role.contains(q) || portfolio.contains(q);
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

    final committeeCount = _activeMembers.where((m) => m.isCommittee).length;
    final guardCount = _activeMembers.where((m) => m.isStaff || m.isSecurity).length;
    final residentCount = _activeMembers.where((m) => !m.isAdmin && !m.isCommittee && !m.isStaff && !m.isSecurity).length;

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members by name, flat, portfolio...',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('All (${_activeMembers.length})', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('🛡️ Committee ($committeeCount)', 'committee'),
                const SizedBox(width: 8),
                _buildFilterChip('👮 Guards ($guardCount)', 'guard'),
                const SizedBox(width: 8),
                _buildFilterChip('🏠 Residents ($residentCount)', 'resident'),
              ],
            ),
          ),
          const SizedBox(height: 4),
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
                          backgroundColor: m.isCommittee
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : m.isStaff || m.isSecurity
                                  ? const Color(0xFFFF6B00).withValues(alpha: 0.15)
                                  : m.isAdmin
                                      ? Colors.indigo.withValues(alpha: 0.15)
                                      : Colors.grey.shade200,
                          child: Icon(
                            m.isCommittee
                                ? Icons.verified_user_outlined
                                : m.isStaff || m.isSecurity
                                    ? Icons.security
                                    : m.isAdmin
                                        ? Icons.admin_panel_settings
                                        : Icons.person_outline,
                            color: m.isCommittee
                                ? const Color(0xFF059669)
                                : m.isStaff || m.isSecurity
                                    ? const Color(0xFFFF6B00)
                                    : m.isAdmin
                                        ? Colors.indigo
                                        : Colors.grey.shade700,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.userName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              fit: FlexFit.loose,
                              child: _buildRoleBadge(m),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          [
                            if (m.flatNo != null && m.flatNo!.isNotEmpty) 'Flat: ${m.flatNo}',
                            if (m.portfolio.isNotEmpty) 'Duties: ${m.portfolio}',
                            if (m.userPhone.isNotEmpty) 'Phone: ${m.userPhone}',
                          ].join(' • '),
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                                        Text('Assign Role / Duties'),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedRoleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedRoleFilter = value);
      },
      selectedColor: const Color(0xFF10B981).withValues(alpha: 0.2),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? const Color(0xFF059669) : Colors.black87,
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

  Widget _buildRoleBadge(SocietyMemberModel m) {
    Color color = Colors.blueGrey;
    String label = m.role.toUpperCase();

    if (m.isAdmin) {
      color = Colors.indigo;
      label = 'ADMIN';
    } else if (m.isCommittee) {
      color = const Color(0xFF059669);
      if (m.portfolio.isNotEmpty) {
        label = 'COMMITTEE • ${m.portfolio.toUpperCase()}';
      } else {
        label = 'COMMITTEE';
      }
    } else if (m.isStaff || m.isSecurity) {
      color = const Color(0xFFFF6B00);
      label = 'SECURITY GUARD';
    } else if (m.role == 'member') {
      color = Colors.blueGrey;
      label = 'RESIDENT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
