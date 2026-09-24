import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../dashboard/main_dashboard.dart';
import '../provider/provider_dashboard_screen.dart';
import 'society_operations_screen.dart';
import 'society_security_console_screen.dart';
import 'announcements_screen.dart';
import 'documents_screen.dart';
import 'parking_screen.dart';
import 'society_profile_screen.dart';
import 'society_members_screen.dart';
import 'society_emergency_contacts_screen.dart';
import 'resident_complaints_screen.dart';
import '../events/events_screen.dart';
import '../events/event_detail_screen.dart';
import '../../services/society_service.dart';
import '../../services/event_service.dart';
import '../../services/auth_session.dart';
import '../../models/society_models.dart';
import '../../models/event_model.dart';
import 'select_society_screen.dart';
import 'society_committee_workspace_screen.dart';
import 'society_committee_management_screen.dart';
import 'committee_invitation_screen.dart';

class SocietyDashboardScreen extends StatefulWidget {
  final int? initialSocietyId;
  const SocietyDashboardScreen({super.key, this.initialSocietyId});

  @override
  State<SocietyDashboardScreen> createState() => _SocietyDashboardScreenState();
}

class _SocietyDashboardScreenState extends State<SocietyDashboardScreen> {
  final SocietyService _societyService = SocietyService();

  bool _isLoading = true;
  String? _errorMessage;
  SocietyProfileModel? _activeSociety;
  List<SocietyAnnouncementModel> _announcements = [];
  List<EventModel> _societyEvents = [];
  String _userRole = 'resident';
  String _systemRole = 'resident';
  bool _isNotMember = false;
  bool _isJoining = false;
  bool _isPendingApproval = false;
  String? _myFlatNo;
  String? _myPortfolio;
  int _pendingJoinRequestsCount = 0;
  List<Map<String, dynamic>> _myActiveCommittees = [];
  List<Map<String, dynamic>> _myPendingInvitations = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isNotMember = false;
    });

    try {
      // 1. Resolve user's stored/active role
      final authStore = AuthSessionStore();
      final storedRole = await authStore.readUserRole();
      final activeRole = await const FlutterSecureStorage().read(key: 'active_role');
      final resolvedRole = (activeRole ?? storedRole ?? 'resident').toLowerCase().trim();
      _systemRole = resolvedRole;
      _userRole = resolvedRole;

      // 2. Resolve active society
      if (widget.initialSocietyId != null) {
        final soc = await _societyService.getSocietyDetail(widget.initialSocietyId!);
        _activeSociety = soc;
      } else {
        _activeSociety = await _societyService.getMySociety();
      }

      if (_activeSociety != null) {
        // Resolve user's role in this society
        final currentUserId = await authStore.readUserId();
        if (currentUserId != null) {
          if (_activeSociety!.userId == currentUserId || _activeSociety!.createdBy == currentUserId) {
            _userRole = 'admin';
            _isNotMember = false;
            _isPendingApproval = false;
          } else {
            try {
              final membersRes = await _societyService.getMembers(_activeSociety!.id, limit: 100);
              final myMember = membersRes.data.firstWhere(
                (m) => m.userId == currentUserId,
                orElse: () => const SocietyMemberModel(
                  id: 0,
                  societyId: 0,
                  userId: 0,
                  role: '',
                  status: 'inactive',
                ),
              );
              _myFlatNo = myMember.flatNo;
              _myPortfolio = myMember.portfolio;
              if (myMember.id > 0 && myMember.status.toLowerCase() == 'active') {
                _userRole = myMember.role.toLowerCase();
                _isNotMember = false;
                _isPendingApproval = false;
              } else if (myMember.id > 0 && myMember.status.toLowerCase() == 'pending') {
                _isNotMember = true;
                _isPendingApproval = true;
                _userRole = myMember.role.isNotEmpty ? myMember.role.toLowerCase() : resolvedRole;
              } else {
                _isNotMember = true;
                _isPendingApproval = false;
                _userRole = resolvedRole;
              }
            } catch (_) {
              _isNotMember = true;
              _isPendingApproval = false;
              _userRole = resolvedRole;
            }
          }
        }

        // Try loading announcements if member or admin
        if (!_isNotMember) {
          try {
            final annRes = await _societyService.getAnnouncements(
              _activeSociety!.id,
              limit: 3,
            );
            _announcements = annRes.data;
          } on SocietyServiceException catch (e) {
            if (e.statusCode == 403) {
              _isNotMember = true;
            } else {
              _errorMessage = e.toString();
            }
          } catch (_) {
            _isNotMember = true;
          }
        }

        // Load upcoming society events
        try {
          final eventsRes = await EventService().getUpcomingEvents(
            societyId: _activeSociety!.id,
            limit: 3,
          );
          _societyEvents = eventsRes.events;
        } catch (_) {}

        // Load pending member requests if admin or committee
        if (_userRole.toLowerCase() == 'admin' || _userRole.toLowerCase() == 'committee') {
          try {
            final pendingRes = await _societyService.getMembers(
              _activeSociety!.id,
              status: 'pending',
              limit: 50,
            );
            _pendingJoinRequestsCount = pendingRes.data.length;
          } catch (_) {
            _pendingJoinRequestsCount = 0;
          }
        } else {
          _pendingJoinRequestsCount = 0;
        }

        // Load active committee memberships & pending invitations
        if (!_isNotMember && _activeSociety != null) {
          try {
            final comms = await _societyService.getMyCommitteeMemberships(_activeSociety!.id);
            final invites = await _societyService.getMyCommitteeInvitations(_activeSociety!.id);
            _myActiveCommittees = comms;
            _myPendingInvitations = invites;
          } catch (_) {
            _myActiveCommittees = [];
            _myPendingInvitations = [];
          }
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleJoinSociety() async {
    if (_activeSociety == null) return;
    setState(() => _isJoining = true);
    try {
      await _societyService.joinSociety(_activeSociety!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined society!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
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

  bool get _isManagementUser =>
      _userRole.toLowerCase() == 'admin' ||
      _userRole.toLowerCase() == 'committee' ||
      _userRole.toLowerCase() == 'owner';

  bool get _isGuardUser =>
      _userRole.toLowerCase() == 'staff' ||
      _userRole.toLowerCase() == 'security';

  List<Map<String, dynamic>> get _quickActions {
    final role = _userRole.toLowerCase().trim();
    final isMgmt = role == 'admin' || role == 'committee' || role == 'owner';
    final isGuard = role == 'staff' || role == 'security';

    if (isMgmt) {
      return [
        {
          'title': 'Admin Console',
          'icon': Icons.admin_panel_settings,
          'tab': 0,
          'route': 'security_console',
          'badge': 'Full Desk',
          'color': const Color(0xFFDC2626),
        },
        {
          'title': 'Committees',
          'icon': Icons.groups_3_outlined,
          'tab': 0,
          'route': 'committee_management',
          'badge': 'Governance',
          'color': const Color(0xFF059669),
        },
        {
          'title': 'Guards',
          'icon': Icons.security,
          'tab': 2,
          'route': 'security_console',
          'badge': 'Onboard',
          'color': const Color(0xFFFF6B00),
        },
        {
          'title': 'Gates & Shifts',
          'icon': Icons.door_front_door_outlined,
          'tab': 3,
          'route': 'security_console',
          'color': const Color(0xFF2563EB),
        },
        {
          'title': 'Complaints',
          'icon': Icons.report_problem_outlined,
          'tab': 0,
          'route': 'complaints',
          'color': const Color(0xFFE11D48),
        },
        {
          'title': 'Visitors',
          'icon': Icons.people_outline,
          'tab': 1,
          'route': 'ops',
          'color': const Color(0xFF0284C7),
        },
        {
          'title': 'Announcements',
          'icon': Icons.campaign_outlined,
          'tab': -1,
          'route': 'announcements',
          'color': const Color(0xFFD97706),
        },
        {
          'title': 'Members',
          'icon': Icons.groups_outlined,
          'tab': -1,
          'route': 'members',
          'color': const Color(0xFF7C3AED),
        },
        {
          'title': 'Reports & Logs',
          'icon': Icons.analytics_outlined,
          'tab': 7,
          'route': 'security_console',
          'color': const Color(0xFF475569),
        },
        {
          'title': 'Parking',
          'icon': Icons.local_parking,
          'tab': -1,
          'route': 'parking',
          'color': const Color(0xFFEA580C),
        },
        {
          'title': 'Documents',
          'icon': Icons.description_outlined,
          'tab': -1,
          'route': 'documents',
          'color': const Color(0xFF0891B2),
        },
        {
          'title': 'Polls',
          'icon': Icons.poll_outlined,
          'tab': 2,
          'route': 'ops',
          'color': const Color(0xFF6366F1),
        },
      ];
    } else if (isGuard) {
      return [
        {
          'title': 'Log Gate Entry',
          'icon': Icons.add_moderator,
          'tab': 1,
          'route': 'gate_entry',
          'badge': 'Fast Entry',
          'color': const Color(0xFF059669),
        },
        {
          'title': 'Gatekeeper Desk',
          'icon': Icons.door_front_door,
          'tab': 1,
          'route': 'ops',
          'badge': 'Live Gate',
          'color': const Color(0xFFFF6B00),
        },
        {
          'title': 'Visitors at Gate',
          'icon': Icons.people_outline,
          'tab': 1,
          'route': 'gate_at_gate',
          'badge': 'At Gate',
          'color': const Color(0xFF2563EB),
        },
        {
          'title': 'My Duty & Shift',
          'icon': Icons.badge_outlined,
          'tab': 1,
          'route': 'duty_shift',
          'badge': 'On Duty',
          'color': const Color(0xFF7C3AED),
        },
        {
          'title': 'Emergency',
          'icon': Icons.emergency_outlined,
          'tab': -1,
          'route': 'emergency',
          'color': const Color(0xFFDC2626),
        },
        {
          'title': 'Complaints',
          'icon': Icons.report_problem_outlined,
          'tab': -1,
          'route': 'complaints',
          'color': const Color(0xFFE11D48),
        },
        {
          'title': 'Announcements',
          'icon': Icons.campaign_outlined,
          'tab': -1,
          'route': 'announcements',
          'color': const Color(0xFFD97706),
        },
        {
          'title': 'Members Directory',
          'icon': Icons.groups_outlined,
          'tab': -1,
          'route': 'members',
          'color': const Color(0xFF475569),
        },
        {
          'title': 'Parking',
          'icon': Icons.local_parking,
          'tab': -1,
          'route': 'parking',
          'color': const Color(0xFFEA580C),
        },
      ];
    } else {
      final list = <Map<String, dynamic>>[];
      if (_myActiveCommittees.isNotEmpty) {
        list.add({
          'title': 'Committee Desk',
          'icon': Icons.groups_3_rounded,
          'tab': 0,
          'route': 'committee_workspace',
          'badge': 'Active',
          'color': const Color(0xFF059669),
        });
      }
      if (_myPendingInvitations.isNotEmpty) {
        list.add({
          'title': 'Invitations',
          'icon': Icons.mark_email_unread_outlined,
          'tab': 0,
          'route': 'committee_invitation',
          'badge': '${_myPendingInvitations.length}',
          'color': const Color(0xFFD97706),
        });
      }
      list.addAll([
        {'title': 'Complaints', 'icon': Icons.report_problem_outlined, 'tab': -1, 'route': 'complaints', 'color': const Color(0xFFFF6B00)},
        {'title': 'Announcements', 'icon': Icons.campaign_outlined, 'tab': -1, 'route': 'announcements', 'color': const Color(0xFFFF6B00)},
        {'title': 'Visitors', 'icon': Icons.people_outline, 'tab': 1, 'route': 'ops', 'color': const Color(0xFFFF6B00)},
        {'title': 'Parking', 'icon': Icons.local_parking, 'tab': -1, 'route': 'parking', 'color': const Color(0xFFFF6B00)},
        {'title': 'Documents', 'icon': Icons.description_outlined, 'tab': -1, 'route': 'documents', 'color': const Color(0xFFFF6B00)},
        {'title': 'Polls', 'icon': Icons.poll_outlined, 'tab': 2, 'route': 'ops', 'color': const Color(0xFFFF6B00)},
        {'title': 'Events', 'icon': Icons.event_outlined, 'tab': -1, 'route': 'events', 'color': const Color(0xFFFF6B00)},
        {'title': 'Emergency', 'icon': Icons.emergency_outlined, 'tab': -1, 'route': 'emergency', 'color': const Color(0xFFFF6B00)},
        {'title': 'Members', 'icon': Icons.groups_outlined, 'tab': -1, 'route': 'members', 'color': const Color(0xFFFF6B00)},
      ]);
      return list;
    }
  }

  void _onQuickActionTap(Map<String, dynamic> action) {
    final route = action['route'] as String;
    final tab = action['tab'] as int;
    final societyId = _activeSociety?.id;

    switch (route) {
      case 'committee_management':
        if (societyId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietyCommitteeManagementScreen(
                societyId: societyId,
                userRole: _userRole,
              ),
            ),
          ).then((_) => _loadDashboardData());
        }
        break;
      case 'committee_workspace':
        if (societyId != null) {
          final commId = _myActiveCommittees.isNotEmpty
              ? int.tryParse((_myActiveCommittees.first['committee_id'] ?? _myActiveCommittees.first['committee']?['id'])?.toString() ?? '')
              : null;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SocietyCommitteeWorkspaceScreen(
                societyId: societyId,
                committeeId: commId,
              ),
            ),
          ).then((_) => _loadDashboardData());
        }
        break;
      case 'committee_invitation':
        if (societyId != null && _myPendingInvitations.isNotEmpty) {
          final invId = int.tryParse(_myPendingInvitations.first['id']?.toString() ?? '') ?? 0;
          if (invId > 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommitteeInvitationScreen(
                  invitationId: invId,
                  societyId: societyId,
                ),
              ),
            ).then((_) => _loadDashboardData());
          }
        }
        break;
      case 'security_console':
        if (societyId != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SocietySecurityConsoleScreen(
              societyId: societyId,
              userRole: _userRole,
              initialTab: tab >= 0 ? tab : 0,
            ),
          )).then((_) => _loadDashboardData());
        }
        break;
      case 'gate_entry':
        if (societyId != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SocietyOperationsScreen(
              initialTab: 1,
              societyId: societyId,
              userRole: _userRole,
              autoOpenGateEntry: true,
            ),
          )).then((_) => _loadDashboardData());
        }
        break;
      case 'gate_at_gate':
        if (societyId != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SocietyOperationsScreen(
              initialTab: 1,
              societyId: societyId,
              userRole: _userRole,
              initialVisitorFilter: 'at_gate',
            ),
          )).then((_) => _loadDashboardData());
        }
        break;
      case 'duty_shift':
        _showGuardDutyDetailSheet();
        break;
      case 'complaints':
        final isStaffOrSecurity = _userRole.toLowerCase() == 'staff' ||
            _userRole.toLowerCase() == 'security';
        final isMgmt = _userRole.toLowerCase() == 'admin' ||
            _userRole.toLowerCase() == 'committee' ||
            _userRole.toLowerCase() == 'owner' ||
            isStaffOrSecurity;
        if (isMgmt) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SocietyOperationsScreen(
              initialTab: 0,
              societyId: societyId,
              userRole: _userRole,
            ),
          )).then((_) => _loadDashboardData());
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ResidentComplaintsScreen(societyId: societyId),
          )).then((_) => _loadDashboardData());
        }
        break;
      case 'ops':
        if (tab >= 0) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SocietyOperationsScreen(
              initialTab: tab,
              societyId: societyId,
              userRole: _userRole,
            ),
          )).then((_) => _loadDashboardData());
        }
        break;
      case 'announcements':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AnnouncementsScreen(societyId: societyId, userRole: _userRole),
        )).then((_) => _loadDashboardData());
        break;
      case 'parking':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ParkingScreen(societyId: societyId),
        )).then((_) => _loadDashboardData());
        break;
      case 'documents':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DocumentsScreen(societyId: societyId, userRole: _userRole),
        )).then((_) => _loadDashboardData());
        break;
      case 'events':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => EventsScreen(societyId: societyId, societyName: _activeSociety?.societyName),
        )).then((_) => _loadDashboardData());
        break;
      case 'emergency':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SocietyEmergencyContactsScreen(societyId: societyId ?? 0, userRole: _userRole),
        )).then((_) => _loadDashboardData());
        break;
      case 'members':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SocietyMembersScreen(societyId: societyId ?? 0, userRole: _userRole),
        )).then((_) => _loadDashboardData());
        break;
    }
  }

  void _showQuickRoleSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Switch Society Role View',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Text(
                  'Select a role to preview and test specific interfaces:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 12),
                _buildRoleOptionTile('Admin', 'Full oversight: manage committees, onboard guards, gates & reports', Icons.admin_panel_settings, const Color(0xFFDC2626), 'admin'),
                _buildRoleOptionTile('Committee', 'Security committee: delegate tasks, view guards & committees', Icons.groups_3_outlined, const Color(0xFF059669), 'committee'),
                _buildRoleOptionTile('Staff / Guard', 'Gatekeeper desk: visitor entry, guard shifts & gate security', Icons.security, const Color(0xFFFF6B00), 'staff'),
                _buildRoleOptionTile('Resident', 'Resident view: complaints, pre-approvals, announcements, polls', Icons.home_outlined, const Color(0xFF2563EB), 'resident'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleOptionTile(String title, String subtitle, IconData icon, Color color, String roleKey) {
    final isSelected = _userRole.toLowerCase() == roleKey || (_userRole == 'security' && roleKey == 'staff');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF111827), fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      trailing: isSelected ? Icon(Icons.check_circle, color: color, size: 20) : null,
      onTap: () async {
        Navigator.pop(context);
        setState(() {
          _userRole = roleKey;
        });
        await const FlutterSecureStorage().write(key: 'active_role', value: roleKey);
      },
    );
  }

  Widget _buildAdminManagementBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Color(0xFFFF6B00), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userRole.toLowerCase() == 'committee' ? 'Security Committee Desk' : 'Society Management Console',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      'Manage delegated committees, security guards, gates & shifts',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.group_add_outlined, size: 15),
                  label: const Text('Add Committee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (_activeSociety != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SocietySecurityConsoleScreen(
                          societyId: _activeSociety!.id,
                          userRole: _userRole,
                          initialTab: 5,
                        ),
                      )).then((_) => _loadDashboardData());
                    }
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                  label: const Text('Add Guard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (_activeSociety != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SocietySecurityConsoleScreen(
                          societyId: _activeSociety!.id,
                          userRole: _userRole,
                          initialTab: 2,
                        ),
                      )).then((_) => _loadDashboardData());
                    }
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune, size: 15),
                  label: const Text('Full Console', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (_activeSociety != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SocietySecurityConsoleScreen(
                          societyId: _activeSociety!.id,
                          userRole: _userRole,
                          initialTab: 0,
                        ),
                      )).then((_) => _loadDashboardData());
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingJoinRequestsBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_add_alt_1, color: Color(0xFFD97706), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_pendingJoinRequestsCount Pending Member Join Request${_pendingJoinRequestsCount > 1 ? "s" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Review and approve or reject resident memberships',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () {
              if (_activeSociety != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SocietyMembersScreen(
                    societyId: _activeSociety!.id,
                    userRole: _userRole,
                    initialTab: 1, // Open Pending Tab directly!
                  ),
                )).then((_) => _loadDashboardData());
              }
            },
            child: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardDutyBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guard & Gate Operations Desk',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Log visitors at gate, verify check-ins & manage gate entries',
                      style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_moderator, size: 18),
                  label: const Text('Log Gate Entry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (_activeSociety != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SocietyOperationsScreen(
                          initialTab: 1,
                          societyId: _activeSociety!.id,
                          userRole: _userRole,
                          autoOpenGateEntry: true,
                        ),
                      )).then((_) => _loadDashboardData());
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.door_front_door_outlined, size: 18),
                  label: const Text('Gate Desk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF064E3B),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (_activeSociety != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SocietyOperationsScreen(
                          initialTab: 1,
                          societyId: _activeSociety!.id,
                          userRole: _userRole,
                        ),
                      )).then((_) => _loadDashboardData());
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommitteeInvitationBanner() {
    final invite = _myPendingInvitations.first;
    final int inviteId = (invite['id'] as num?)?.toInt() ?? 0;
    final String committeeName = (invite['committee_name'] ?? invite['committeeName'] ?? 'Society Committee').toString();
    final String designation = (invite['designation'] ?? 'Member').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Committee Invitation Received',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'You are invited to join $committeeName ($designation)',
                      style: const TextStyle(color: Color(0xFFE0E7FF), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.touch_app, size: 16),
                  label: const Text('Review & Respond', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4338CA),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (_activeSociety != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommitteeInvitationScreen(
                            societyId: _activeSociety!.id,
                            invitationId: inviteId,
                            committeeName: committeeName,
                          ),
                        ),
                      ).then((_) => _loadDashboardData());
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResidentCommitteeBanner() {
    final committee = _myActiveCommittees.first;
    final int committeeId = (committee['id'] as num?)?.toInt() ?? 0;
    final String commName = (committee['name'] ?? 'Society Committee').toString();
    final String scope = (committee['scope_type'] ?? committee['scopeType'] ?? 'entire_society').toString().replaceAll('_', ' ').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_ind_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Committee Member Desk',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Active on: $commName • Scope: $scope',
                      style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.dashboard_customize_outlined, size: 16),
                  label: const Text('Open Committee Workspace', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F766E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (_activeSociety != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SocietyCommitteeWorkspaceScreen(
                            societyId: _activeSociety!.id,
                            committeeId: committeeId,
                            committeeName: commName,
                            userRole: _userRole,
                          ),
                        ),
                      ).then((_) => _loadDashboardData());
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGuardDutyDetailSheet() {
    final societyId = _activeSociety?.id;
    if (societyId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: FutureBuilder<SocietyGuardDutyModel>(
          future: _societyService.getMyGuardDuty(societyId),
          builder: (context, snapshot) {
            final duty = snapshot.data;
            final gateName = duty?.gate?.gateName ?? 'Main Security Gate';
            final gateType = duty?.gate?.gateType ?? 'Pedestrian & Vehicle Gate';
            final shiftName = duty?.shift?.shiftName ?? 'Standard Shift';
            final startTime = duty?.shift?.startTime ?? '08:00 AM';
            final endTime = duty?.shift?.endTime ?? '04:00 PM';
            final isActive = duty?.isActive ?? true;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.badge, color: Color(0xFF7C3AED), size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Guard Duty & Shift Roster',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                              ),
                              Text(
                                'Active Gate & Shift Assignment',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
                    )
                  else ...[
                    // Card 1: Active Duty Status Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4ADE80),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isActive ? 'ON DUTY • ACTIVE' : 'DUTY ROSTER',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            gateName,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            gateType,
                            style: const TextStyle(color: Color(0xFFDDD6FE), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Card 2: Shift Timings & Details
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF7C3AED), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shiftName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Timing: $startTime - $endTime',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Card 3: Security Help Desk / Supervisor Contact
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.support_agent_rounded, color: Color(0xFF16A34A), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Security Control Room',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                                ),
                                Text(
                                  'Emergency & Guard Escalation Desk',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.call, size: 14),
                            label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => SocietyEmergencyContactsScreen(
                                  societyId: societyId,
                                  userRole: _userRole,
                                ),
                              ));
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Standard Gate Protocol SOP
                    const Text('Gate Security Protocols', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    _sopItem(Icons.check_circle_outline, 'Verify visitor identity & vehicle registration before admit.'),
                    const SizedBox(height: 6),
                    _sopItem(Icons.check_circle_outline, 'Wait for host resident approval or confirm digital pass code.'),
                    const SizedBox(height: 6),
                    _sopItem(Icons.check_circle_outline, 'Mark visitor check-out at exit to record departure time.'),
                    const SizedBox(height: 20),

                    // Direct Action: Open Gatekeeper Desk
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.door_front_door_outlined, size: 18),
                        label: const Text('Open Gatekeeper Desk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => SocietyOperationsScreen(
                              initialTab: 1,
                              societyId: societyId,
                              userRole: _userRole,
                            ),
                          )).then((_) => _loadDashboardData());
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sopItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF059669)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ),
      ],
    );
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _activeSociety?.societyName ?? 'Society Dashboard',
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              InkWell(
                onTap: _showQuickRoleSwitcher,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Role: ${_userRole.replaceAll('_', ' ').toUpperCase()}'
                          '${_myPortfolio != null && _myPortfolio!.isNotEmpty ? ' • ${_myPortfolio!.toUpperCase()}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _userRole == 'admin'
                                ? const Color(0xFFDC2626)
                                : _userRole == 'committee'
                                    ? const Color(0xFF059669)
                                    : (_userRole == 'staff' || _userRole == 'security'
                                        ? const Color(0xFFFF6B00)
                                        : const Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 14,
                        color: _userRole == 'admin'
                            ? const Color(0xFFDC2626)
                            : _userRole == 'committee'
                                ? const Color(0xFF059669)
                                : (_userRole == 'staff' || _userRole == 'security'
                                    ? const Color(0xFFFF6B00)
                                    : const Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (_activeSociety != null && _isManagementUser)
              IconButton(
                icon: const Icon(Icons.shield_outlined, color: Color(0xFF111827)),
                tooltip: 'Security & Committees Console',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SocietySecurityConsoleScreen(
                        societyId: _activeSociety!.id,
                        userRole: _userRole,
                        initialTab: 0,
                      ),
                    ),
                  ).then((_) => _loadDashboardData());
                },
              ),
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF111827)),
              tooltip: 'Switch / Select Society',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectSocietyScreen()),
                ).then((_) => _loadDashboardData());
              },
            ),
            if (_activeSociety != null)
              IconButton(
                icon: const Icon(Icons.info_outline, color: Color(0xFF111827)),
                tooltip: 'Society Profile',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SocietyProfileScreen(
                        societyId: _activeSociety!.id,
                        userRole: _userRole,
                      ),
                    ),
                  ).then((_) => _loadDashboardData());
                },
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: const Color(0xFFE5E7EB),
              height: 1.0,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
            : (_activeSociety == null)
                ? (_systemRole == 'provider' || _systemRole == 'service provider'
                    ? _buildNoSocietyProviderView()
                    : _buildNoSocietyResidentView())
                : RefreshIndicator(
                    color: const Color(0xFFFF6B00),
                    onRefresh: _loadDashboardData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isPendingApproval)
                            _buildPendingApprovalBanner()
                          else if (_isNotMember)
                            _buildNotMemberBanner()
                          else if (_errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_myPendingInvitations.isNotEmpty)
                            _buildCommitteeInvitationBanner(),
                          if (_isManagementUser && _pendingJoinRequestsCount > 0)
                            _buildPendingJoinRequestsBanner(),
                          if (_isManagementUser)
                            _buildAdminManagementBanner()
                          else if (_myActiveCommittees.isNotEmpty)
                            _buildResidentCommitteeBanner()
                          else if (_isGuardUser)
                            _buildGuardDutyBanner(),
                          const Text(
                            'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _quickActions.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, index) {
                          final action = _quickActions[index];
                          final color = (action['color'] as Color?) ?? const Color(0xFFFF6B00);
                          final badge = action['badge'] as String?;
                          return InkWell(
                            onTap: () => _onQuickActionTap(action),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                children: [
                                  if (badge != null)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          badge,
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(action['icon'], color: color, size: 28),
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Text(
                                            action['title'],
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Official Announcements',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_announcements.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Text(
                            'No announcements published yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                          ),
                        )
                      else
                        ..._announcements.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: item.isUrgent ? const Color(0xFFFFF7F0) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: item.isUrgent
                                    ? const Color(0xFFFF6B00)
                                    : const Color(0xFFE5E7EB),
                                width: item.isUrgent ? 4 : 1,
                              ),
                              top: const BorderSide(color: Color(0xFFE5E7EB)),
                              right: const BorderSide(color: Color(0xFFE5E7EB)),
                              bottom: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.campaign,
                                      color: Color(0xFFFF6B00), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.category.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (item.isUrgent) ...[
                                    const Spacer(),
                                    const Icon(Icons.warning_amber_rounded,
                                        size: 14, color: Color(0xFFFF6B00)),
                                    const SizedBox(width: 4),
                                    const Text('Urgent',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFFF6B00))),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.createdAt != null
                                    ? '${item.createdAt!.day}/${item.createdAt!.month}/${item.createdAt!.year}'
                                    : 'Recent',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        )),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnnouncementsScreen(
                              societyId: _activeSociety?.id,
                              userRole: _userRole,
                            ),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'View all announcements',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF6B00),
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios,
                                  size: 11, color: Color(0xFFFF6B00)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Society Events Preview Section ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Society Events',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventsScreen(
                                  societyId: _activeSociety?.id,
                                  societyName: _activeSociety?.societyName,
                                ),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'View all',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF6B00),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFFFF6B00)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_societyEvents.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: const Text(
                            'No upcoming society events scheduled.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                          ),
                        )
                      else
                        ..._societyEvents.map((ev) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.event, color: Color(0xFF2563EB)),
                            ),
                            title: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              [
                                if (ev.startAt != null)
                                  '${ev.startAt!.day}/${ev.startAt!.month}/${ev.startAt!.year}',
                                if (ev.locationName != null && ev.locationName!.isNotEmpty)
                                  ev.locationName!,
                              ].join(' • '),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailScreen(eventId: ev.id),
                                ),
                              );
                            },
                          ),
                        )),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111827),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF111827), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResidentComplaintsScreen(
                                  societyId: _activeSociety?.id,
                                  autoOpenCreate: true,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            '+ Raise a Complaint',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNoSocietyProviderView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.handyman_rounded,
                size: 64,
                color: Color(0xFFFF6B00),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Logged in as Service Provider',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This screen is for residential society operations. To manage your services, accept customer bookings, and track your daily earnings, open the Provider Center.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.handyman_outlined, size: 20),
                label: const Text(
                  'Go to Provider Center',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _handleBack,
              child: const Text(
                'Back to Main Dashboard',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSocietyResidentView() {
    const Color brandGreen = Color(0xFF10B981);
    const Color primaryText = Color(0xFF111827);
    const Color subText = Color(0xFF6B7280);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.apartment_rounded,
                size: 64,
                color: brandGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Society Linked Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose your housing society to connect with your society admin, register flat details, access visitor gate approvals, complaints, and official announcements.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: subText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 20),
                label: const Text(
                  'Search & Select Society',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SelectSocietyScreen()),
                  ).then((_) => _loadDashboardData());
                },
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _handleBack,
              child: const Text(
                'Back to Home',
                style: TextStyle(color: subText, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApprovalBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Membership Approval Pending',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                        fontSize: 15,
                      ),
                    ),
                    if (_myFlatNo != null && _myFlatNo!.isNotEmpty)
                      Text(
                        'Unit: $_myFlatNo',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Your join request has been submitted to the society management committee. You will have full access to notices, complaints, and visitor logs once approved.',
            style: TextStyle(color: Color(0xFF92400E), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Change Society'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF92400E),
                  side: const BorderSide(color: Color(0xFFD97706)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SelectSocietyScreen()),
                  ).then((_) => _loadDashboardData());
                },
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh Status'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF92400E),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _loadDashboardData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotMemberBanner() {
    final isProvider = _systemRole == 'provider' || _systemRole == 'service provider';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isProvider ? 'Service Provider (Guest View)' : 'Not an Active Member',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isProvider
                ? 'You are logged in as a Service Provider. This society is shown in guest view mode.'
                : 'You are viewing this society as a guest. Join to access official announcements and full features.',
            style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (isProvider)
                ElevatedButton.icon(
                  icon: const Icon(Icons.handyman, size: 16),
                  label: const Text('Open Provider Center'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
                    );
                  },
                )
              else
                ElevatedButton.icon(
                  icon: _isJoining
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.group_add, size: 16),
                  label: const Text('Join Society'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isJoining ? null : _handleJoinSociety,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
