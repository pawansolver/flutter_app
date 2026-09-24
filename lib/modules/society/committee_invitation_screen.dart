import 'package:flutter/material.dart';
import '../../services/society_service.dart';
import '../../services/auth_service.dart';
import 'society_committee_workspace_screen.dart';

class CommitteeInvitationScreen extends StatefulWidget {
  final int invitationId;
  final int societyId;
  final String? committeeName;

  const CommitteeInvitationScreen({
    super.key,
    required this.invitationId,
    required this.societyId,
    this.committeeName,
  });

  @override
  State<CommitteeInvitationScreen> createState() => _CommitteeInvitationScreenState();
}

class _CommitteeInvitationScreenState extends State<CommitteeInvitationScreen> {
  final _societyService = SocietyService();
  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _error;
  Map<String, dynamic>? _invitation;

  @override
  void initState() {
    super.initState();
    _loadInvitation();
  }

  Future<void> _loadInvitation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _societyService.getCommitteeInvitation(
        widget.invitationId,
        widget.societyId,
      );
      if (!mounted) return;
      setState(() {
        _invitation = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvitation() async {
    setState(() => _isActionLoading = true);
    try {
      await _societyService.acceptCommitteeInvitation(
        widget.invitationId,
        widget.societyId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation accepted! You are now an active committee member.'),
          backgroundColor: Color(0xFF059669),
        ),
      );

      final committeeId = int.tryParse(
            _invitation?['committee_id']?.toString() ??
                _invitation?['committeeId']?.toString() ??
                '',
          ) ??
          0;

      // Navigate to Committee Workspace replacing invitation screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SocietyCommitteeWorkspaceScreen(
            societyId: widget.societyId,
            committeeId: committeeId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _rejectInvitation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Decline Invitation?'),
        content: const Text(
          'Are you sure you want to decline this committee appointment? You can only join later if the administrator re-invites you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await _societyService.rejectCommitteeInvitation(
        widget.invitationId,
        widget.societyId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation declined.'),
          backgroundColor: Colors.grey,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F172A);
    const accentColor = Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Committee Appointment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
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
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInvitation,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildInvitationContent(accentColor),
    );
  }

  Widget _buildInvitationContent(Color accentColor) {
    final inv = _invitation!;
    final committee = inv['committee'] as Map<String, dynamic>? ?? {};
    final committeeName = (committee['name'] ?? 'Society Committee').toString();
    final description = (committee['description'] ?? '').toString();
    final societyName = (inv['societyName'] ?? 'Residential Society').toString();
    final designation = (inv['designation'] ?? 'Member').toString();
    final status = (inv['status'] ?? 'pending').toString().toLowerCase();
    final scopeType = (committee['scope_type'] ?? 'entire_society').toString();
    final inviter = inv['inviter'] as Map<String, dynamic>?;
    final inviterName = inviter?['userName']?.toString() ?? 'Society Administrator';

    // Parse permissions
    final rawPerms = committee['permissions'] as List? ?? [];
    final permissions = rawPerms
        .map((p) => p is Map ? (p['permission_code'] ?? '').toString() : p.toString())
        .where((p) => p.isNotEmpty)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        societyName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                      ),
                      child: const Icon(Icons.groups_3_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 12, width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            committeeName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Designation: $designation',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Operational Scope Card
          _buildInfoSection(
            title: 'Committee Operational Scope',
            icon: Icons.my_location_rounded,
            content: Row(
              children: [
                Icon(
                  scopeType == 'entire_society' ? Icons.domain_rounded : Icons.door_sliding_outlined,
                  size: 20,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Text(
                  scopeType == 'entire_society'
                      ? 'Entire Society (Full Perimeter)'
                      : (scopeType == 'gate' || scopeType == 'specific_gates')
                          ? 'Gate-Scoped (Designated Gate Only)'
                          : 'Area-Scoped (${scopeType.toUpperCase()})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Delegated PBAC Permissions
          _buildInfoSection(
            title: 'Delegated PBAC Permissions (${permissions.length})',
            icon: Icons.shield_outlined,
            content: permissions.isEmpty
                ? const Text('Standard informational committee access', style: TextStyle(color: Colors.grey))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: permissions.map((p) => _buildPermissionChip(p)).toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // Metadata Details
          _buildInfoSection(
            title: 'Invitation Details',
            icon: Icons.info_outline,
            content: Column(
              children: [
                _buildMetaRow('Invited By:', inviterName),
                const SizedBox(height: 8),
                _buildMetaRow('Status:', status.toUpperCase()),
                if (inv['expires_at'] != null) ...[
                  const SizedBox(height: 8),
                  _buildMetaRow(
                    'Expires:',
                    DateTime.tryParse(inv['expires_at'].toString())?.toLocal().toString().split('.')[0] ??
                        inv['expires_at'].toString(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          if (status == 'pending') ...[
            if (_isActionLoading)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _rejectInvitation,
                      child: const Text('Decline', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _acceptInvitation,
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('Accept Appointment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
          ] else if (status == 'active') ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final committeeId = int.tryParse(
                      _invitation?['committee_id']?.toString() ??
                          _invitation?['committeeId']?.toString() ??
                          '',
                    ) ??
                    0;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SocietyCommitteeWorkspaceScreen(
                      societyId: widget.societyId,
                      committeeId: committeeId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Open Committee Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This invitation is currently $status and cannot be accepted.',
                      style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'active':
        bg = Colors.green.shade900.withOpacity(0.5);
        fg = Colors.greenAccent;
        break;
      case 'pending':
        bg = Colors.amber.shade900.withOpacity(0.5);
        fg = Colors.amberAccent;
        break;
      case 'rejected':
      case 'revoked':
        bg = Colors.red.shade900.withOpacity(0.5);
        fg = Colors.redAccent;
        break;
      case 'suspended':
        bg = Colors.orange.shade900.withOpacity(0.5);
        fg = Colors.orangeAccent;
        break;
      default:
        bg = Colors.grey.shade800;
        fg = Colors.white70;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildPermissionChip(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            code,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
