import 'package:flutter/material.dart';
import '../../services/society_service.dart';
import 'society_operations_screen.dart';
import 'society_security_console_screen.dart';
import 'resident_complaints_screen.dart';
import 'announcements_screen.dart';
import 'parking_screen.dart';
import 'documents_screen.dart';
import 'society_members_screen.dart';
import '../events/events_screen.dart';

/// Generic Dynamic Enterprise Committee Workspace Screen
///
/// Driven entirely by the user's active committee PBAC permissions:
/// - Resolves all active committee memberships and PBAC permissions (union)
/// - Committee switcher if user belongs to multiple active committees
/// - Displays ONLY modules where the user has authorized permissions
/// - Actions inside each module card appear ONLY if the specific action permission is granted
/// - Gate-scope enforcement indicator
class SocietyCommitteeWorkspaceScreen extends StatefulWidget {
  final int societyId;
  final int? committeeId;
  final String? committeeName;
  final String? userRole;

  const SocietyCommitteeWorkspaceScreen({
    super.key,
    required this.societyId,
    this.committeeId,
    this.committeeName,
    this.userRole,
  });

  @override
  State<SocietyCommitteeWorkspaceScreen> createState() =>
      _SocietyCommitteeWorkspaceScreenState();
}

class _SocietyCommitteeWorkspaceScreenState
    extends State<SocietyCommitteeWorkspaceScreen> {
  final _societyService = SocietyService();
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _myCommittees = [];
  Set<String> _effectivePermissions = {};
  int? _activeCommitteeId;
  String _activeCommitteeName = 'Committee Workspace';
  String _activeDesignation = 'Committee Member';
  String _activeCommitteeType = 'custom';
  String _scopeType = 'entire_society';
  int? _scopeId;

  @override
  void initState() {
    super.initState();
    _activeCommitteeId = widget.committeeId;
    _loadWorkspaceData();
  }

  Future<void> _loadWorkspaceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final memberships =
          await _societyService.getMyCommitteeMemberships(widget.societyId);
      if (!mounted) return;

      if (memberships.isEmpty) {
        setState(() {
          _myCommittees = [];
          _effectivePermissions = {};
          _isLoading = false;
        });
        return;
      }

      // Determine active committee
      Map<String, dynamic> activeMembership = memberships.first;
      if (_activeCommitteeId != null) {
        final match = memberships.firstWhere(
          (m) =>
              (m['committee_id'] ?? m['committeeId'] ?? m['committee']?['id']) ==
              _activeCommitteeId,
          orElse: () => memberships.first,
        );
        activeMembership = match;
      }

      final committee = (activeMembership['committee'] as Map<String, dynamic>?) ?? {};
      _activeCommitteeId = int.tryParse((committee['id'] ?? activeMembership['committee_id'])?.toString() ?? '');
      _activeCommitteeName = (committee['name'] ?? widget.committeeName ?? 'Society Committee').toString();
      _activeDesignation = (activeMembership['designation'] ?? 'Member').toString();
      _activeCommitteeType = (committee['committee_type'] ?? 'custom').toString();
      _scopeType = (committee['scope_type'] ?? 'entire_society').toString();
      _scopeId = int.tryParse(committee['scope_id']?.toString() ?? '');

      // PBAC Union: Collect all effective permissions across ALL active committees for this society
      final Set<String> perms = {};
      for (final m in memberships) {
        final c = m['committee'] as Map<String, dynamic>? ?? {};
        final rawPerms = c['permissions'] as List? ?? [];
        for (final p in rawPerms) {
          if (p is Map && p['permission_code'] != null) {
            perms.add(p['permission_code'].toString());
          } else if (p is String) {
            perms.add(p);
          }
        }
        final memberPerms = m['memberPermissions'] as List? ?? [];
        for (final p in memberPerms) {
          if (p is Map && p['permission_code'] != null) {
            perms.add(p['permission_code'].toString());
          } else if (p is String) {
            perms.add(p);
          }
        }
      }

      setState(() {
        _myCommittees = memberships;
        _effectivePermissions = perms;
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

  void _switchActiveCommittee(int committeeId) {
    setState(() {
      _activeCommitteeId = committeeId;
    });
    _loadWorkspaceData();
  }

  // ── PBAC Granular Permission Checkers ─────────────────────────────────────
  bool _has(String perm) => _effectivePermissions.contains(perm);

  // Visitors
  bool get _canViewVisitors =>
      _has('visitor.read') ||
      _has('visitor.create_gate_entry') ||
      _has('visitor.check_in') ||
      _has('visitor.reports.read') ||
      _has('society.visitor.manage');

  bool get _canCreateGateEntry =>
      _has('visitor.create_gate_entry') || _has('visitor.check_in');

  // Guards
  bool get _canViewGuards =>
      _has('guard.read') ||
      _has('guard.onboard') ||
      _has('guard.assign_gate') ||
      _has('guard.assign_shift');

  bool get _canOnboardGuard => _has('guard.onboard');

  // Gates
  bool get _canViewGates => _has('gate.read') || _has('gate.create');
  bool get _canCreateGate => _has('gate.create');

  // Shifts
  bool get _canManageShifts =>
      _has('shift.read') || _has('shift.create') || _has('shift.assign');
  bool get _canCreateShift => _has('shift.create');

  // Security / SOS
  bool get _canViewSecurity =>
      _has('security.dashboard.read') ||
      _has('security.reports.read') ||
      _has('security.audit.read');

  // Complaints & Maintenance
  bool get _canViewComplaints =>
      _has('society.complaint.create') || _has('society.complaint.resolve');
  bool get _canResolveComplaints => _has('society.complaint.resolve');

  // Notices & Announcements
  bool get _canViewNotices => _has('society.notice.publish');

  // Events & Gatherings
  bool get _canViewEvents =>
      _has('event.view') ||
      _has('event.create') ||
      _has('event.rsvp') ||
      _has('event.view_participants');
  bool get _canCreateEvent => _has('event.create');

  // Parking Management
  bool get _canViewParking => _has('society.parking.manage');

  // Society Documents
  bool get _canViewDocuments =>
      _has('society.view') || _has('society.update');

  // Society Members
  bool get _canViewMembers => _has('society.manage_members');

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _activeCommitteeName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Workspace',
            onPressed: _loadWorkspaceData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _myCommittees.isEmpty
                  ? _buildNoMembershipView()
                  : _buildWorkspaceContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
              onPressed: _loadWorkspaceData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMembershipView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_3_outlined, size: 64, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            const Text(
              'No Active Committee Memberships',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'You do not have any active appointments in society committees. If you received an invitation, please accept it from your Dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspaceContent() {
    final modules = <Widget>[];

    // 1. Visitors Module
    if (_canViewVisitors) {
      modules.add(_buildModuleCard(
        title: 'Visitor Management',
        description: 'Real-time visitor gate entries, check-in/out logs & passes',
        icon: Icons.people_outline,
        color: const Color(0xFF2563EB),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietyOperationsScreen(
                societyId: widget.societyId,
                initialTab: 1,
                userRole: 'committee',
              ),
            ),
          );
        },
        actionButton: _canCreateGateEntry
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SocietyOperationsScreen(
                        societyId: widget.societyId,
                        initialTab: 1,
                        userRole: 'committee',
                        autoOpenGateEntry: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: const Text('Log Gate Entry', style: TextStyle(fontSize: 12)),
              )
            : null,
      ));
    }

    // 2. Guards Module
    if (_canViewGuards) {
      modules.add(_buildModuleCard(
        title: 'Security Guards',
        description: 'Guard duty rosters, active check-ins, gate & shift assignments',
        icon: Icons.security_rounded,
        color: const Color(0xFF059669),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietySecurityConsoleScreen(
                societyId: widget.societyId,
                userRole: 'committee',
                initialTab: 2,
              ),
            ),
          );
        },
        actionButton: _canOnboardGuard
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  side: const BorderSide(color: Color(0xFF059669)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SocietySecurityConsoleScreen(
                        societyId: widget.societyId,
                        userRole: 'committee',
                        initialTab: 2,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_moderator_outlined, size: 16),
                label: const Text('Onboard Guard', style: TextStyle(fontSize: 12)),
              )
            : null,
      ));
    }

    // 3. Gates Module
    if (_canViewGates) {
      modules.add(_buildModuleCard(
        title: 'Gates & Access Points',
        description: 'Gate pass tracking, boom barrier status & checkpoints',
        icon: Icons.door_sliding_outlined,
        color: const Color(0xFFD97706),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietySecurityConsoleScreen(
                societyId: widget.societyId,
                userRole: 'committee',
                initialTab: 3,
              ),
            ),
          );
        },
        actionButton: _canCreateGate
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFD97706)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SocietySecurityConsoleScreen(
                        societyId: widget.societyId,
                        userRole: 'committee',
                        initialTab: 3,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Manage Gate', style: TextStyle(fontSize: 12)),
              )
            : null,
      ));
    }

    // 4. Shifts Module
    if (_canManageShifts) {
      modules.add(_buildModuleCard(
        title: 'Duty Shifts & Roster',
        description: 'Shift scheduling, rotation plans & security guard timings',
        icon: Icons.schedule_rounded,
        color: const Color(0xFF7C3AED),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietySecurityConsoleScreen(
                societyId: widget.societyId,
                userRole: 'committee',
                initialTab: 4,
              ),
            ),
          );
        },
        actionButton: _canCreateShift
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SocietySecurityConsoleScreen(
                        societyId: widget.societyId,
                        userRole: 'committee',
                        initialTab: 4,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Manage Shifts', style: TextStyle(fontSize: 12)),
              )
            : null,
      ));
    }

    // 5. Security & SOS Monitoring
    if (_canViewSecurity) {
      modules.add(_buildModuleCard(
        title: 'Security & SOS Monitoring',
        description: 'Live security dashboard, emergency dispatches & incident logs',
        icon: Icons.shield_outlined,
        color: const Color(0xFFDC2626),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietySecurityConsoleScreen(
                societyId: widget.societyId,
                userRole: 'committee',
                initialTab: 0,
              ),
            ),
          );
        },
      ));
    }

    // 6. Complaints & Maintenance
    if (_canViewComplaints) {
      modules.add(_buildModuleCard(
        title: 'Complaints & Maintenance',
        description: 'Resident complaints, maintenance requests & resolution tracking',
        icon: Icons.report_problem_outlined,
        color: const Color(0xFFE11D48),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResidentComplaintsScreen(societyId: widget.societyId),
            ),
          );
        },
        actionButton: _canResolveComplaints
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  side: const BorderSide(color: Color(0xFFE11D48)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResidentComplaintsScreen(societyId: widget.societyId),
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Resolve Complaints', style: TextStyle(fontSize: 12)),
              )
            : null,
      ));
    }

    // 7. Announcements & Notices
    if (_canViewNotices) {
      modules.add(_buildModuleCard(
        title: 'Announcements & Notices',
        description: 'Broadcast notices, circulars & official society communications',
        icon: Icons.campaign_outlined,
        color: const Color(0xFFD97706),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnnouncementsScreen(
                societyId: widget.societyId,
                userRole: 'committee',
              ),
            ),
          );
        },
      ));
    }

    // 8. Events & Gatherings
    if (_canViewEvents) {
      modules.add(_buildModuleCard(
        title: 'Events & Gatherings',
        description: 'Society festivals, cultural celebrations & participant RSVPs',
        icon: Icons.event_outlined,
        color: const Color(0xFF9333EA),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventsScreen(
                societyId: widget.societyId,
                societyName: _activeCommitteeName,
              ),
            ),
          );
        },
        actionButton: _canCreateEvent
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9333EA),
                  side: const BorderSide(color: Color(0xFF9333EA)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventsScreen(
                        societyId: widget.societyId,
                        societyName: _activeCommitteeName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Event', style: TextStyle(fontSize: 12)),
              )
            : null,
      ));
    }

    // 9. Parking Management
    if (_canViewParking) {
      modules.add(_buildModuleCard(
        title: 'Parking Management',
        description: 'Vehicle registry, parking slot allocations & visitor parking passes',
        icon: Icons.local_parking,
        color: const Color(0xFFEA580C),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParkingScreen(societyId: widget.societyId),
            ),
          );
        },
      ));
    }

    // 10. Society Documents
    if (_canViewDocuments) {
      modules.add(_buildModuleCard(
        title: 'Society Documents',
        description: 'Society bylaws, meeting minutes & operational records',
        icon: Icons.description_outlined,
        color: const Color(0xFF0891B2),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentsScreen(
                societyId: widget.societyId,
                userRole: 'committee',
              ),
            ),
          );
        },
      ));
    }

    // 11. Society Members
    if (_canViewMembers) {
      modules.add(_buildModuleCard(
        title: 'Members Directory',
        description: 'Resident directory, flat mappings & member roles',
        icon: Icons.groups_outlined,
        color: const Color(0xFF475569),
        badgeText: 'PBAC Authorized',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietyMembersScreen(
                societyId: widget.societyId,
                userRole: 'committee',
              ),
            ),
          );
        },
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Committee Multi-Membership Switcher (if user belongs to more than 1)
          if (_myCommittees.length > 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.switch_account_outlined, size: 18, color: Color(0xFFFF6B00)),
                  const SizedBox(width: 8),
                  const Text('Active Committee:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _activeCommitteeId,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        items: _myCommittees.map((m) {
                          final comm = m['committee'] as Map<String, dynamic>? ?? {};
                          final cId = int.tryParse((comm['id'] ?? m['committee_id'])?.toString() ?? '') ?? 0;
                          final name = comm['name']?.toString() ?? 'Committee #$cId';
                          final desig = m['designation']?.toString() ?? 'Member';
                          return DropdownMenuItem<int>(
                            value: cId,
                            child: Text('$name ($desig)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) _switchActiveCommittee(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Banner Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, size: 12, color: Color(0xFF34D399)),
                          SizedBox(width: 4),
                          Text(
                            'ACTIVE COMMITTEE DELEGATION',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_effectivePermissions.length} Active Grants',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _activeCommitteeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Role: $_activeDesignation  •  Category: ${_activeCommitteeType.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      _scopeType == 'gate' ? Icons.door_front_door : Icons.my_location_rounded,
                      size: 14,
                      color: _scopeType == 'gate' ? const Color(0xFFFBBF24) : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _scopeType == 'entire_society'
                          ? 'Operational Scope: Entire Society'
                          : 'Operational Scope: Gate-Scoped (Gate #${_scopeId ?? "1"})',
                      style: TextStyle(
                        color: _scopeType == 'gate' ? const Color(0xFFFDE68A) : Colors.white70,
                        fontSize: 12,
                        fontWeight: _scopeType == 'gate' ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Operational Modules Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Authorized Modules',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                '${modules.length} Modules Active',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (modules.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No operational permissions assigned yet.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your committee membership is active, but permissions for operational modules have not been granted. Contact your society administrator.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...modules,
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String badgeText,
    required VoidCallback onTap,
    Widget? actionButton,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),
              if (actionButton != null) ...[
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: actionButton,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
