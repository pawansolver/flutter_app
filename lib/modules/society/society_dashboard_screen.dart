import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';
import 'society_operations_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.initialSocietyId != null) {
        final soc = await _societyService.getSocietyDetail(widget.initialSocietyId!);
        _activeSociety = soc;
      } else {
        _activeSociety = await _societyService.getMySociety();
        if (_activeSociety == null) {
          final societiesRes = await _societyService.getSocieties(limit: 10);
          if (societiesRes.data.isNotEmpty) {
            _activeSociety = societiesRes.data.first;
          }
        }
      }

      if (_activeSociety != null) {
        final annRes = await _societyService.getAnnouncements(
          _activeSociety!.id,
          limit: 3,
        );
        _announcements = annRes.data;

        // Resolve user's role in society
        final currentUserId = await AuthSessionStore().readUserId();
        if (currentUserId != null) {
          if (_activeSociety!.userId == currentUserId || _activeSociety!.createdBy == currentUserId) {
            _userRole = 'admin';
          } else {
            try {
              final membersRes = await _societyService.getMembers(_activeSociety!.id, limit: 100);
              final myMember = membersRes.data.firstWhere(
                (m) => m.userId == currentUserId,
                orElse: () => const SocietyMemberModel(
                  id: 0,
                  societyId: 0,
                  userId: 0,
                  role: 'resident',
                  status: 'active',
                ),
              );
              if (myMember.id > 0) {
                _userRole = myMember.role.toLowerCase();
              }
            } catch (_) {}
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

  final List<Map<String, dynamic>> _quickActions = [
    {'title': 'Complaints', 'icon': Icons.report_problem_outlined, 'tab': -1, 'route': 'complaints'},
    {'title': 'Announcements', 'icon': Icons.campaign_outlined, 'tab': -1, 'route': 'announcements'},
    {'title': 'Visitors', 'icon': Icons.people_outline, 'tab': 1, 'route': 'ops'},
    {'title': 'Parking', 'icon': Icons.local_parking, 'tab': -1, 'route': 'parking'},
    {'title': 'Documents', 'icon': Icons.description_outlined, 'tab': -1, 'route': 'documents'},
    {'title': 'Polls', 'icon': Icons.poll_outlined, 'tab': 2, 'route': 'ops'},
    {'title': 'Events', 'icon': Icons.event_outlined, 'tab': -1, 'route': 'events'},
    {'title': 'Emergency', 'icon': Icons.emergency_outlined, 'tab': -1, 'route': 'emergency'},
    {'title': 'Members', 'icon': Icons.groups_outlined, 'tab': -1, 'route': 'members'},
  ];

  void _onQuickActionTap(Map<String, dynamic> action) {
    final route = action['route'] as String;
    final tab = action['tab'] as int;
    final societyId = _activeSociety?.id;

    switch (route) {
      case 'complaints':
        final isMgmt = _userRole.toLowerCase() == 'admin' ||
            _userRole.toLowerCase() == 'committee' ||
            _userRole.toLowerCase() == 'owner';
        if (isMgmt) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SocietyOperationsScreen(initialTab: 0, societyId: societyId),
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ResidentComplaintsScreen(societyId: societyId),
          ));
        }
        break;
      case 'ops':
        if (tab >= 0) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => SocietyOperationsScreen(initialTab: tab, societyId: societyId),
          ));
        }
        break;
      case 'announcements':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AnnouncementsScreen(societyId: societyId, userRole: _userRole),
        ));
        break;
      case 'parking':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ParkingScreen(societyId: societyId),
        ));
        break;
      case 'documents':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DocumentsScreen(societyId: societyId, userRole: _userRole),
        ));
        break;
      case 'events':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => EventsScreen(societyId: societyId, societyName: _activeSociety?.societyName),
        ));
        break;
      case 'emergency':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SocietyEmergencyContactsScreen(societyId: societyId ?? 0, userRole: _userRole),
        ));
        break;
      case 'members':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SocietyMembersScreen(societyId: societyId ?? 0, userRole: _userRole),
        ));
        break;
    }
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
                _activeSociety?.societyName ?? 'My Society Dashboard',
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (_activeSociety != null)
                Text(
                  'Role: ${_userRole.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _userRole == 'admin' ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                  ),
                ),
            ],
          ),
          actions: [
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
            : RefreshIndicator(
                color: const Color(0xFFFF6B00),
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null)
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
                          return InkWell(
                            onTap: () => _onQuickActionTap(action),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(action['icon'], color: const Color(0xFFFF6B00), size: 28),
                                  const SizedBox(height: 8),
                                  Text(
                                    action['title'],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF111827),
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
}
