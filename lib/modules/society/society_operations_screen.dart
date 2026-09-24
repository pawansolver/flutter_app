import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'society_security_console_screen.dart';
import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';
import 'complaint_detail_screen.dart';
import '../../services/society_service.dart';
import '../../services/auth_session.dart';
import '../../models/society_models.dart';
import 'select_society_screen.dart';

class SocietyOperationsScreen extends StatefulWidget {
  final int initialTab;
  final int? societyId;
  final String? userRole;
  final bool autoOpenGateEntry;
  final String? initialVisitorFilter;

  const SocietyOperationsScreen({
    super.key,
    this.initialTab = 0,
    this.societyId,
    this.userRole,
    this.autoOpenGateEntry = false,
    this.initialVisitorFilter,
  });

  @override
  State<SocietyOperationsScreen> createState() => _SocietyOperationsScreenState();
}

class _SocietyOperationsScreenState extends State<SocietyOperationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocietyService _societyService = SocietyService();

  int? _resolvedSocietyId;
  String? _societyName;
  String _userRole = 'resident';
  int? _currentUserId;
  String? _myFlatNo;
  SocietyGuardDutyModel? _guardDuty;
  List<SocietyGateModel> _availableGates = [];
  List<SocietyShiftModel> _availableShifts = [];
  List<SocietyMemberModel> _societyMembers = [];

  List<SocietyMemberModel> get _registeredFlatMembers {
    final list = <SocietyMemberModel>[];
    final seen = <String>{};
    for (final m in _societyMembers) {
      final f = m.flatNo?.trim();
      if (f != null && f.isNotEmpty && (m.isActive || m.isPending)) {
        final key = '${f.toLowerCase()}#${m.userId}';
        if (!seen.contains(key)) {
          seen.add(key);
          list.add(m);
        }
      }
    }
    return list;
  }

  // Complaints State
  bool _isLoadingComplaints = true;
  List<SocietyComplaintModel> _complaints = [];
  String _complaintFilter = 'all';
  SocietyComplaintSummaryModel? _complaintSummary;
  final TextEditingController _complaintSearchController = TextEditingController();
  String _complaintSearchQuery = '';

  // Advanced Filters
  String? _complaintCategoryFilter;
  String? _complaintPriorityFilter;
  String? _complaintLocationTypeFilter;
  String _complaintAssignedFilter = 'all'; // 'all', 'assigned', 'unassigned'

  bool get _isManagementUser =>
      _userRole.toLowerCase() == 'admin' ||
      _userRole.toLowerCase() == 'committee' ||
      _userRole.toLowerCase() == 'owner';

  int get _activeFiltersCount {
    int count = 0;
    if (_complaintCategoryFilter != null) count++;
    if (_complaintPriorityFilter != null) count++;
    if (_complaintLocationTypeFilter != null) count++;
    if (_complaintAssignedFilter != 'all') count++;
    return count;
  }

  // Visitors State
  bool _isLoadingVisitors = true;
  List<SocietyVisitorModel> _visitors = [];
  String _visitorFilter = 'all';
  final TextEditingController _visitorSearchController = TextEditingController();
  String _visitorSearchQuery = '';

  int get _visitorCountAll => _visitors.length;
  int get _visitorCountAtGate => _visitors.where((v) => v.isAtGate || v.isApproved).length;
  int get _visitorCountApproved => _visitors.where((v) => v.isApproved).length;
  int get _visitorCountExpected => _visitors.where((v) => v.isExpected).length;
  int get _visitorCountCheckedIn => _visitors.where((v) => v.isCheckedIn).length;
  int get _visitorCountCheckedOut => _visitors.where((v) => v.isCheckedOut).length;

  List<SocietyVisitorModel> get _filteredVisitors {
    var list = _visitors;
    if (_visitorFilter == 'at_gate') {
      list = list.where((v) => v.isAtGate || v.isApproved).toList();
    } else if (_visitorFilter != 'all') {
      list = list.where((v) => v.status.toLowerCase() == _visitorFilter).toList();
    }
    if (_visitorSearchQuery.trim().isNotEmpty) {
      final q = _visitorSearchQuery.trim().toLowerCase();
      list = list.where((v) {
        final name = v.visitorName.toLowerCase();
        final phone = (v.visitorPhone ?? '').toLowerCase();
        final flat = (v.flatNo ?? '').toLowerCase();
        final vehicle = (v.vehicleNo ?? '').toLowerCase();
        final comp = (v.companyName ?? '').toLowerCase();
        final purpose = (v.purpose ?? '').toLowerCase();
        final driver = (v.driverName ?? '').toLowerCase();
        final passCode = 'pass-${v.id}'.toLowerCase();
        final passId = v.id.toString();
        return name.contains(q) ||
            phone.contains(q) ||
            flat.contains(q) ||
            vehicle.contains(q) ||
            comp.contains(q) ||
            purpose.contains(q) ||
            driver.contains(q) ||
            passCode.contains(q) ||
            passId == q;
      }).toList();
    }
    return list;
  }

  // Polls State
  bool _isLoadingPolls = true;
  List<SocietyPollModel> _polls = [];

  @override
  void initState() {
    super.initState();
    if (widget.userRole != null && widget.userRole!.isNotEmpty) {
      _userRole = widget.userRole!.toLowerCase();
    }
    if (widget.initialVisitorFilter != null && widget.initialVisitorFilter!.isNotEmpty) {
      _visitorFilter = widget.initialVisitorFilter!;
    }
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _initSocietyAndData();
  }

  Future<void> _initSocietyAndData() async {
    _resolvedSocietyId = await _societyService.resolveActiveSocietyId(widget.societyId);

    if (_resolvedSocietyId != null) {
      try {
        _currentUserId = await AuthSessionStore().readUserId();
        final membersRes = await _societyService.getMembers(_resolvedSocietyId!, limit: 100);
        final allMembers = List<SocietyMemberModel>.from(membersRes.data);
        if (membersRes.totalPages > 1) {
          for (int p = 2; p <= membersRes.totalPages && p <= 5; p++) {
            try {
              final nextRes = await _societyService.getMembers(_resolvedSocietyId!, page: p, limit: 100);
              allMembers.addAll(nextRes.data);
            } catch (_) {}
          }
        }
        _societyMembers = allMembers;

        if (widget.userRole != null && widget.userRole!.isNotEmpty) {
          _userRole = widget.userRole!.toLowerCase();
        } else if (_currentUserId != null) {
          final soc = await _societyService.getSocietyDetail(_resolvedSocietyId!);
          _societyName = soc.societyName;
          if (soc.userId == _currentUserId || soc.createdBy == _currentUserId) {
            _userRole = 'admin';
          } else {
            final me = _societyMembers.firstWhere(
              (m) => m.userId == _currentUserId,
              orElse: () => const SocietyMemberModel(
                id: 0,
                societyId: 0,
                userId: 0,
                role: 'resident',
                status: 'active',
              ),
            );
            if (me.id > 0 && me.role.isNotEmpty) {
              _userRole = me.role.toLowerCase();
              _myFlatNo = me.flatNo;
            }
          }
        }
      } catch (e) {
        debugPrint('SocietyOperations: Failed to load members: $e');
      }

      try {
        _availableGates = await _societyService.getGates(_resolvedSocietyId!);
        _availableShifts = await _societyService.getShifts(_resolvedSocietyId!);
        if (_userRole == 'staff' || _userRole == 'security') {
          _guardDuty = await _societyService.getMyGuardDuty(_resolvedSocietyId!);
        }
      } catch (_) {}
      _loadComplaints();
      _loadVisitors();
      _loadPolls();

      if (widget.autoOpenGateEntry && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showVisitorModal(isGateEntry: true);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingComplaints = false;
          _isLoadingVisitors = false;
          _isLoadingPolls = false;
        });
      }
    }
  }

  Future<void> _loadComplaints() async {
    if (_resolvedSocietyId == null) return;
    setState(() => _isLoadingComplaints = true);
    try {
      final query = _complaintSearchQuery.trim();
      final assignedParam = (_complaintAssignedFilter == 'assigned')
          ? 'assigned'
          : (_complaintAssignedFilter == 'unassigned')
              ? 'unassigned'
              : null;

      final complaintsFuture = _societyService.getComplaints(
        _resolvedSocietyId!,
        status: _complaintFilter == 'all' ? null : _complaintFilter,
        category: _complaintCategoryFilter,
        priority: _complaintPriorityFilter,
        locationType: _complaintLocationTypeFilter,
        assigned: assignedParam,
        search: query.isEmpty ? null : query,
        limit: 50,
      );

      final summaryFuture = _societyService.getComplaintSummary(_resolvedSocietyId!);

      final results = await Future.wait([complaintsFuture, summaryFuture]);
      final complaintsRes = results[0] as SocietyPaginatedResponse<SocietyComplaintModel>;
      final summaryRes = results[1] as SocietyComplaintSummaryModel;

      if (mounted) {
        setState(() {
          _complaints = complaintsRes.data;
          _complaintSummary = summaryRes;
          _isLoadingComplaints = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingComplaints = false);
    }
  }

  Future<void> _loadVisitors() async {
    if (_resolvedSocietyId == null) return;
    setState(() => _isLoadingVisitors = true);
    try {
      final res = await _societyService.getVisitors(
        _resolvedSocietyId!,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _visitors = res.data;
          _isLoadingVisitors = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVisitors = false);
    }
  }

  Future<void> _loadPolls() async {
    if (_resolvedSocietyId == null) return;
    setState(() => _isLoadingPolls = true);
    try {
      final res = await _societyService.getPolls(_resolvedSocietyId!, limit: 50);
      if (mounted) {
        setState(() {
          _polls = res.data;
          _isLoadingPolls = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPolls = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _complaintSearchController.dispose();
    _visitorSearchController.dispose();
    super.dispose();
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
            children: [
              Text(
                _societyName ?? 'Society Operations',
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _resolvedSocietyId != null ? 'Society #$_resolvedSocietyId • Operations Desk' : 'Operations Desk',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
          actions: [
            if (_isManagementUser && _resolvedSocietyId != null)
              IconButton(
                icon: const Icon(Icons.shield_outlined, color: Color(0xFF111827)),
                tooltip: 'Security & Committees Console',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SocietySecurityConsoleScreen(
                      societyId: _resolvedSocietyId!,
                      userRole: _userRole,
                    ),
                  )).then((_) => _initSocietyAndData());
                },
              ),
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF111827)),
              tooltip: 'Switch Society',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectSocietyScreen()),
                ).then((_) => _initSocietyAndData());
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFFF6B00),
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            indicatorColor: const Color(0xFFFF6B00),
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Complaints'),
              Tab(text: 'Visitors'),
              Tab(text: 'Polls'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildComplaintsTab(),
            _buildVisitorsTab(),
            _buildPollsTab(),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: COMPLAINTS ────────────────────────────────────────────────────
  Widget _buildComplaintsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF6B00),
        elevation: 0,
        onPressed: _showNewComplaintModal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 1. Summary Metric Cards for Admin/Committee (Section 3)
          if (_isManagementUser) ...[
            _buildSummaryMetricsCarousel(),
            const SizedBox(height: 6),
          ],

          // 2. Search & Filter Bar (Section 4 & 5)
          _buildComplaintSearchBar(),

          // 3. Status Filter Chips (Section 5)
          _buildComplaintStatusChips(),

          // 4. Complaints List / Cards (Section 6)
          Expanded(
            child: _isLoadingComplaints
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : RefreshIndicator(
                    color: const Color(0xFFFF6B00),
                    onRefresh: _loadComplaints,
                    child: _complaints.isEmpty
                        ? _buildEmptyComplaintsState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _complaints.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final c = _complaints[index];
                              return _buildComplaintCard(c);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Summary Metric Cards Carousel (Real Backend Data) ─────────────────────
  Widget _buildSummaryMetricsCarousel() {
    final s = _complaintSummary;
    final totalCount = s?.total ?? _complaints.length;
    final openCount = s?.open ?? 0;
    final assignedCount = s?.assigned ?? 0;
    final inProgressCount = s?.inProgress ?? 0;
    final resolvedCount = s?.resolved ?? 0;
    final closedCount = s?.closed ?? 0;

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildSummaryMetricCard('Total', totalCount, 'all', const Color(0xFF111827), Icons.format_list_bulleted),
            const SizedBox(width: 8),
            _buildSummaryMetricCard('Open', openCount, 'open', const Color(0xFF2563EB), Icons.pending_actions),
            const SizedBox(width: 8),
            _buildSummaryMetricCard('Assigned', assignedCount, 'assigned', const Color(0xFF8B5CF6), Icons.person_pin_circle_outlined),
            const SizedBox(width: 8),
            _buildSummaryMetricCard('In Progress', inProgressCount, 'in_progress', const Color(0xFF0284C7), Icons.play_circle_outline),
            const SizedBox(width: 8),
            _buildSummaryMetricCard('Resolved', resolvedCount, 'resolved', const Color(0xFF10B981), Icons.task_alt),
            const SizedBox(width: 8),
            _buildSummaryMetricCard('Closed', closedCount, 'closed', const Color(0xFF64748B), Icons.lock_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetricCard(String label, int count, String statusFilter, Color color, IconData icon) {
    final isSelected = _complaintFilter == statusFilter;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _complaintFilter = statusFilter;
        });
        _loadComplaints();
      },
      child: Container(
        width: 106,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E7EB),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 16, color: color),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? color : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search Bar with Filter Trigger ────────────────────────────────────────
  Widget _buildComplaintSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: TextField(
                controller: _complaintSearchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: 'Search #ticket, flat, title, resident...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF6B7280)),
                  suffixIcon: _complaintSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Color(0xFF6B7280)),
                          onPressed: () {
                            _complaintSearchController.clear();
                            setState(() {
                              _complaintSearchQuery = '';
                            });
                            _loadComplaints();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (val) {
                  setState(() {
                    _complaintSearchQuery = val;
                  });
                  _loadComplaints();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter Button
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _showComplaintFilterModal,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: _activeFiltersCount > 0 ? const Color(0xFF111827) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _activeFiltersCount > 0 ? const Color(0xFF111827) : const Color(0xFFD1D5DB),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune,
                    size: 20,
                    color: _activeFiltersCount > 0 ? Colors.white : const Color(0xFF4B5563),
                  ),
                  if (_activeFiltersCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B00),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          '$_activeFiltersCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status Filter Chips Row ───────────────────────────────────────────────
  Widget _buildComplaintStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _filterChip('All', 'all', _complaintFilter, (val) {
            setState(() => _complaintFilter = val);
            _loadComplaints();
          }),
          const SizedBox(width: 8),
          _filterChip('Open', 'open', _complaintFilter, (val) {
            setState(() => _complaintFilter = val);
            _loadComplaints();
          }),
          const SizedBox(width: 8),
          _filterChip('Assigned', 'assigned', _complaintFilter, (val) {
            setState(() => _complaintFilter = val);
            _loadComplaints();
          }),
          const SizedBox(width: 8),
          _filterChip('In Progress', 'in_progress', _complaintFilter, (val) {
            setState(() => _complaintFilter = val);
            _loadComplaints();
          }),
          const SizedBox(width: 8),
          _filterChip('Resolved', 'resolved', _complaintFilter, (val) {
            setState(() => _complaintFilter = val);
            _loadComplaints();
          }),
          const SizedBox(width: 8),
          _filterChip('Closed', 'closed', _complaintFilter, (val) {
            setState(() => _complaintFilter = val);
            _loadComplaints();
          }),
          if (_activeFiltersCount > 0) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.close, size: 14, color: Color(0xFFDC2626)),
              label: Text('Reset Filters ($_activeFiltersCount)', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
              backgroundColor: const Color(0xFFFEE2E2),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              onPressed: () {
                setState(() {
                  _complaintCategoryFilter = null;
                  _complaintPriorityFilter = null;
                  _complaintLocationTypeFilter = null;
                  _complaintAssignedFilter = 'all';
                });
                _loadComplaints();
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyComplaintsState() {
    final isFiltered = _complaintFilter != 'all' || _complaintSearchQuery.isNotEmpty || _activeFiltersCount > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered ? Icons.search_off : Icons.inbox_outlined,
              size: 48,
              color: const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered ? 'No matching complaints found' : 'No complaints reported in society',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Try modifying your search query, status, or applied filters.'
                  : 'Residents can raise complaints whenever an issue arises.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFF111827)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  setState(() {
                    _complaintFilter = 'all';
                    _complaintSearchQuery = '';
                    _complaintSearchController.clear();
                    _complaintCategoryFilter = null;
                    _complaintPriorityFilter = null;
                    _complaintLocationTypeFilter = null;
                    _complaintAssignedFilter = 'all';
                  });
                  _loadComplaints();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Rich Complaint Card (Section 6) ───────────────────────────────────────
  Widget _buildComplaintCard(SocietyComplaintModel c) {
    final statusColor = _getStatusColor(c.status);
    final priorityColor = _getPriorityColor(c.priority);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(
              complaint: c,
              userRole: _userRole,
            ),
          ),
        ).then((_) => _loadComplaints());
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Ticket # + Badges (Status, Priority, Reopened)
            Row(
              children: [
                Text(
                  c.ticketNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF111827),
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                if (c.isReopened) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: const Text(
                      'REOPENED',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
                // Priority Chip
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    c.priority.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor),
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    c.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Complaint Title
            Text(
              c.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),

            // Row 3: Description Snippet
            Text(
              c.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 10),

            // Row 4: Resident & Location Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF4B5563)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      c.raisedByName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Color(0xFFD1D5DB))),
                  const SizedBox(width: 8),
                  const Icon(Icons.home_outlined, size: 14, color: Color(0xFF4B5563)),
                  const SizedBox(width: 4),
                  Text(
                    c.residentFlatDisplay,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                  if (c.locationTypeDisplay.isNotEmpty && c.locationType != 'my_flat') ...[
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Color(0xFFD1D5DB))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        c.locationTypeDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Row 5: Metadata & Assignment Footer
            Row(
              children: [
                // Category Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getCategoryIcon(c.category), size: 12, color: const Color(0xFF4B5563)),
                      const SizedBox(width: 4),
                      Text(
                        c.category.toUpperCase(),
                        style: const TextStyle(color: Color(0xFF4B5563), fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Assignee Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.hasAssignee ? const Color(0xFFEFF6FF) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: c.hasAssignee ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c.hasAssignee ? Icons.engineering : Icons.person_search_outlined,
                        size: 12,
                        color: c.hasAssignee ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        c.hasAssignee ? c.assigneeDisplay : 'Unassigned',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: c.hasAssignee ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Date
                const Icon(Icons.schedule, size: 12, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text(
                  c.createdAt != null
                      ? '${c.createdAt!.day.toString().padLeft(2, '0')}/${c.createdAt!.month.toString().padLeft(2, '0')}/${c.createdAt!.year}'
                      : '',
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter Bottom Sheet Modal (Section 5) ─────────────────────────────────
  void _showComplaintFilterModal() {
    String? tempCategory = _complaintCategoryFilter;
    String? tempPriority = _complaintPriorityFilter;
    String? tempLocation = _complaintLocationTypeFilter;
    String tempAssigned = _complaintAssignedFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setFilterState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filter Complaints',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    TextButton(
                      onPressed: () {
                        setFilterState(() {
                          tempCategory = null;
                          tempPriority = null;
                          tempLocation = null;
                          tempAssigned = 'all';
                        });
                      },
                      child: const Text('Reset', style: TextStyle(color: Color(0xFFDC2626))),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Assignment Filter
                const Text('Staff Assignment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: tempAssigned == 'all',
                      onSelected: (_) => setFilterState(() => tempAssigned = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('Assigned'),
                      selected: tempAssigned == 'assigned',
                      onSelected: (_) => setFilterState(() => tempAssigned = 'assigned'),
                    ),
                    ChoiceChip(
                      label: const Text('Unassigned'),
                      selected: tempAssigned == 'unassigned',
                      onSelected: (_) => setFilterState(() => tempAssigned = 'unassigned'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Priority Filter
                const Text('Priority Level', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: tempPriority == null,
                      onSelected: (_) => setFilterState(() => tempPriority = null),
                    ),
                    ChoiceChip(
                      label: const Text('Urgent'),
                      selected: tempPriority == 'urgent',
                      onSelected: (_) => setFilterState(() => tempPriority = 'urgent'),
                    ),
                    ChoiceChip(
                      label: const Text('High'),
                      selected: tempPriority == 'high',
                      onSelected: (_) => setFilterState(() => tempPriority = 'high'),
                    ),
                    ChoiceChip(
                      label: const Text('Medium'),
                      selected: tempPriority == 'medium',
                      onSelected: (_) => setFilterState(() => tempPriority = 'medium'),
                    ),
                    ChoiceChip(
                      label: const Text('Low'),
                      selected: tempPriority == 'low',
                      onSelected: (_) => setFilterState(() => tempPriority = 'low'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category Filter
                const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: tempCategory == null,
                      onSelected: (_) => setFilterState(() => tempCategory = null),
                    ),
                    ChoiceChip(
                      label: const Text('Plumbing'),
                      selected: tempCategory == 'plumbing',
                      onSelected: (_) => setFilterState(() => tempCategory = 'plumbing'),
                    ),
                    ChoiceChip(
                      label: const Text('Electrical'),
                      selected: tempCategory == 'electrical',
                      onSelected: (_) => setFilterState(() => tempCategory = 'electrical'),
                    ),
                    ChoiceChip(
                      label: const Text('Lift'),
                      selected: tempCategory == 'lift',
                      onSelected: (_) => setFilterState(() => tempCategory = 'lift'),
                    ),
                    ChoiceChip(
                      label: const Text('Security'),
                      selected: tempCategory == 'security',
                      onSelected: (_) => setFilterState(() => tempCategory = 'security'),
                    ),
                    ChoiceChip(
                      label: const Text('Maintenance'),
                      selected: tempCategory == 'maintenance',
                      onSelected: (_) => setFilterState(() => tempCategory = 'maintenance'),
                    ),
                    ChoiceChip(
                      label: const Text('General'),
                      selected: tempCategory == 'general',
                      onSelected: (_) => setFilterState(() => tempCategory = 'general'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Location Type Filter
                const Text('Location Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: tempLocation == null,
                      onSelected: (_) => setFilterState(() => tempLocation = null),
                    ),
                    ChoiceChip(
                      label: const Text('My Flat'),
                      selected: tempLocation == 'my_flat',
                      onSelected: (_) => setFilterState(() => tempLocation = 'my_flat'),
                    ),
                    ChoiceChip(
                      label: const Text('Other Flat'),
                      selected: tempLocation == 'other_flat',
                      onSelected: (_) => setFilterState(() => tempLocation = 'other_flat'),
                    ),
                    ChoiceChip(
                      label: const Text('Common Area'),
                      selected: tempLocation == 'common_area',
                      onSelected: (_) => setFilterState(() => tempLocation = 'common_area'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Apply Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _complaintCategoryFilter = tempCategory;
                        _complaintPriorityFilter = tempPriority;
                        _complaintLocationTypeFilter = tempLocation;
                        _complaintAssignedFilter = tempAssigned;
                      });
                      _loadComplaints();
                    },
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFF2563EB);
      case 'assigned':
      case 'in_progress':
        return const Color(0xFFF59E0B);
      case 'resolved':
        return const Color(0xFF10B981);
      case 'closed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electrical':
        return Icons.bolt;
      case 'plumbing':
        return Icons.plumbing;
      case 'lift':
        return Icons.elevator;
      case 'security':
        return Icons.shield;
      case 'maintenance':
        return Icons.build;
      case 'general':
      default:
        return Icons.assignment;
    }
  }

  void _showNewComplaintModal() {
    if (_resolvedSocietyId == null) return;
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');
    final descController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Log New Complaint',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              _modalField('Complaint Title', 'e.g., Street light not working', titleController),
              const SizedBox(height: 14),
              _modalField('Category', 'Electrical, Plumbing, Security...', categoryController),
              const SizedBox(height: 14),
              _modalField('Description', 'Describe the issue in detail...', descController, maxLines: 3),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final title = titleController.text.trim();
                          final desc = descController.text.trim();
                          final cat = categoryController.text.trim().toLowerCase();
                          if (title.isEmpty || desc.isEmpty) return;

                          setModalState(() => isSubmitting = true);
                          try {
                            try {
                              await _societyService.createComplaint(
                                _resolvedSocietyId!,
                                title: title,
                                description: desc,
                                category: cat.isEmpty ? 'general' : cat,
                                priority: 'medium',
                              );
                            } on SocietyServiceException catch (e) {
                              if (e.statusCode == 403) {
                                // Auto-join society and retry
                                await _societyService.joinSociety(_resolvedSocietyId!);
                                await _societyService.createComplaint(
                                  _resolvedSocietyId!,
                                  title: title,
                                  description: desc,
                                  category: cat.isEmpty ? 'general' : cat,
                                  priority: 'medium',
                                );
                              } else {
                                rethrow;
                              }
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadComplaints();
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Complaint submitted successfully!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (err) {
                            setModalState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(err.toString()),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Ticket',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TAB 2: VISITORS & GATE DESK ──────────────────────────────────────────
  Widget _buildVisitorsTab() {
    final isStaffOrCommittee = _userRole == 'admin' ||
        _userRole == 'committee' ||
        _userRole == 'security' ||
        _userRole == 'staff';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: isStaffOrCommittee
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF059669),
              elevation: 3,
              onPressed: () => _showVisitorModal(isGateEntry: true),
              icon: const Icon(Icons.add_moderator, color: Colors.white),
              label: const Text('Log Gate Entry',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            )
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF111827),
              elevation: 0,
              onPressed: () => _showVisitorModal(isGateEntry: false),
              icon: const Icon(Icons.person_add_outlined, color: Colors.white),
              label: const Text('Pre-Approve Guest',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
      body: Column(
        children: [
          if (isStaffOrCommittee)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gatekeeper & Security Desk',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827))),
                        Text(
                          _userRole == 'committee'
                              ? 'Security Committee • Restricted Access'
                              : _userRole == 'staff' || _userRole == 'security'
                                  ? 'Guard • ${_guardDuty?.gate?.gateName ?? "Main Gate 1"} • Shift: ${_guardDuty?.shift?.shiftName ?? "Morning"}'
                                  : 'Society Admin • Full Access',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  if (_userRole == 'admin' || _userRole == 'committee') ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF111827),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.tune, size: 14),
                      label: const Text('Console', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => SocietySecurityConsoleScreen(
                            societyId: _resolvedSocietyId!,
                            userRole: _userRole,
                          ),
                        ));
                      },
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 14),
                      label: const Text('Add Guard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _showOnboardGuardModal,
                    ),
                  ],
                ],
              ),
            )
          else
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.apartment, color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _myFlatNo != null ? 'Resident Gate Desk • Flat $_myFlatNo' : 'Resident Passes & Visitors',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827)),
                        ),
                        const Text(
                          'Instant gate clearance, pre-authorize guests & track deliveries',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (!isStaffOrCommittee) ...[
            _buildUrgentGateAlertBanner(),
            _buildQuickCategoryPresets(),
          ],
          _buildVisitorSearchBar(),
          _buildVisitorStatusChips(),
          Expanded(
            child: _isLoadingVisitors
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : RefreshIndicator(
                    color: const Color(0xFFFF6B00),
                    onRefresh: _loadVisitors,
                    child: _filteredVisitors.isEmpty
                        ? _buildEmptyVisitorsState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: _filteredVisitors.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final v = _filteredVisitors[index];
                              return _buildVisitorCard(v);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Enterprise Urgent Gate Alert Banner (MyGate / NoBrokerHood Standard) ──
  Widget _buildUrgentGateAlertBanner() {
    final pendingAtGateVisitors = _visitors.where((v) {
      final isResidentForThisFlat = _myFlatNo != null &&
          v.flatNo != null &&
          _myFlatNo!.trim().toLowerCase() == v.flatNo!.trim().toLowerCase();
      final isVisitorCreator = v.userId != null && v.userId == _currentUserId;
      return v.isAtGate && !v.isApproved && (isResidentForThisFlat || isVisitorCreator);
    }).toList();

    if (pendingAtGateVisitors.isEmpty) return const SizedBox.shrink();

    final v = pendingAtGateVisitors.first;
    final catTag = v.companyName?.isNotEmpty == true
        ? v.companyName!.toUpperCase()
        : v.visitorType.toUpperCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'ACTION REQUIRED • VISITOR AT GATE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (pendingAtGateVisitors.length > 1)
                Text(
                  '+${pendingAtGateVisitors.length - 1} more waiting',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                child: const Icon(Icons.meeting_room_rounded, color: Color(0xFFFF6B00), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.visitorName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$catTag • Flat ${v.flatNo ?? _myFlatNo ?? ""}${v.vehicleNo != null ? " • ${v.vehicleNo}" : ""}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _promptDenyVisitor(v),
                  child: const Text('Deny Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Approve Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => _handleVisitorApprove(v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Quick Category Presets (1-Tap Pre-Approval) ──────────────────────────
  Widget _buildQuickCategoryPresets() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _quickPresetChip(
            icon: Icons.delivery_dining_outlined,
            label: 'Delivery',
            color: const Color(0xFFFF6B00),
            onTap: () => _showVisitorModal(isGateEntry: false, initialCategory: 'delivery', defaultCompany: 'Swiggy'),
          ),
          const SizedBox(width: 8),
          _quickPresetChip(
            icon: Icons.local_taxi_outlined,
            label: 'Cab / Ride',
            color: const Color(0xFFF59E0B),
            onTap: () => _showVisitorModal(isGateEntry: false, initialCategory: 'cab'),
          ),
          const SizedBox(width: 8),
          _quickPresetChip(
            icon: Icons.person_add_outlined,
            label: 'Guest',
            color: const Color(0xFF8B5CF6),
            onTap: () => _showVisitorModal(isGateEntry: false, initialCategory: 'guest'),
          ),
          const SizedBox(width: 8),
          _quickPresetChip(
            icon: Icons.home_repair_service_outlined,
            label: 'Service',
            color: const Color(0xFF2563EB),
            onTap: () => _showVisitorModal(isGateEntry: false, initialCategory: 'service'),
          ),
        ],
      ),
    );
  }

  Widget _quickPresetChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickBrandChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Smart Enterprise Timeline & Duration Badge ───────────────────────────
  Widget _buildSmartTimingBar(SocietyVisitorModel v) {
    final atGate = v.isAtGate;
    final isApproved = v.isApproved;
    final isCheckedIn = v.isCheckedIn;
    final isCheckedOut = v.isCheckedOut;
    final isExpected = v.isExpected;
    final isDenied = v.isDenied;

    if (isCheckedOut) {
      final inTime = v.checkInTime ?? v.createdAt;
      final outTime = v.checkOutTime;
      String durationStr = '';
      if (inTime != null && outTime != null) {
        final diff = outTime.difference(inTime);
        if (diff.inMinutes < 60) {
          durationStr = '${diff.inMinutes.abs()}m duration';
        } else {
          final hours = diff.inHours.abs();
          final mins = diff.inMinutes.abs() % 60;
          durationStr = '${hours}h ${mins}m duration';
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.login, size: 13, color: Color(0xFF059669)),
            const SizedBox(width: 4),
            Text(
              inTime != null ? 'In: ${DateFormat('hh:mm a').format(inTime)}' : 'In: --:--',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
            const SizedBox(width: 8),
            const Text('•', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
            const SizedBox(width: 8),
            const Icon(Icons.logout, size: 13, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Text(
              outTime != null ? 'Out: ${DateFormat('hh:mm a').format(outTime)}' : 'Out: --:--',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
            if (durationStr.isNotEmpty) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  durationStr,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (isCheckedIn) {
      final inTime = v.checkInTime ?? v.createdAt;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF16A34A)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                inTime != null
                    ? 'Inside Campus • Entered: ${DateFormat('hh:mm a').format(inTime)}'
                    : 'Inside Campus',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (atGate || isApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isApproved ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Icon(
              isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
              size: 14,
              color: isApproved ? const Color(0xFF059669) : const Color(0xFFD97706),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isApproved
                    ? 'Approved by Resident • Clear to enter'
                    : 'Waiting at Gate • Arrived: ${v.createdAt != null ? DateFormat('hh:mm a').format(v.createdAt!) : "Just now"}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isApproved ? const Color(0xFF065F46) : const Color(0xFFB45309),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (isExpected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Text(
              'PASS-#${v.id} • Pre-Approved',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
            ),
            const Spacer(),
            InkWell(
              onTap: () => _sharePassOnWhatsApp(v),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share, size: 11, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Share Pass',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isDenied) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFDC2626)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Entry Denied${v.rejectionReason != null ? ": ${v.rejectionReason}" : ""}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _sharePassOnWhatsApp(SocietyVisitorModel v) {
    final societyName = _societyName ?? 'Palm Grove';
    final passCode = 'PASS-${v.id}';
    final flatText = v.flatNo != null && v.flatNo!.isNotEmpty
        ? 'Flat ${v.flatNo}'
        : (_myFlatNo != null ? 'Flat $_myFlatNo' : 'Society Gate');
    final shareMsg = '''
🏢 *$societyName - Digital Gate Pass*

Hello ${v.visitorName},
You have been pre-approved for entry at *$flatText*.

🔢 *Pass Code:* $passCode
👤 *Visitor Type:* ${v.visitorType.toUpperCase()}
📍 *Purpose:* ${v.purpose ?? 'Visit'}

_Please show this Pass Code at the Security Gate for instant entry._
''';
    final url = 'https://wa.me/?text=${Uri.encodeComponent(shareMsg)}';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _showPassCreatedDialog(SocietyVisitorModel v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gate Pass Generated!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            const SizedBox(height: 4),
            Text(
              'Valid for ${v.visitorName} (${v.visitorType.toUpperCase()})',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  const Text('ENTRY PASS CODE', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                  const SizedBox(height: 4),
                  Text(
                    'PASS-${v.id}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF111827), letterSpacing: 2),
                  ),
                  const SizedBox(height: 4),
                  Text('Flat ${v.flatNo ?? _myFlatNo ?? ""}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share Pass via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _sharePassOnWhatsApp(v);
                },
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: Color(0xFF6B7280))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationFlatField(StateSetter setModalState, TextEditingController flatController, int? selectedHostUserId, SocietyMemberModel? selectedMember, Function(int?, SocietyMemberModel?) onSelect, {required bool isGateEntry, required String label}) {
    if (!isGateEntry && _myFlatNo != null && _myFlatNo!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.apartment, color: Color(0xFF16A34A), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Destination Flat (Locked to your unit)', style: TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                  Text('Flat $_myFlatNo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534))),
                ],
              ),
            ),
            const Icon(Icons.lock_outline, size: 16, color: Color(0xFF16A34A)),
          ],
        ),
      );
    }
    return _buildFlatAutocompleteSelector(
      controller: flatController,
      selectedHostUserId: selectedHostUserId,
      selectedMember: selectedMember,
      onSelect: onSelect,
      setModalState: setModalState,
      label: label,
    );
  }

  // ─── Visitor Search Bar ───────────────────────────────────────────────────
  Widget _buildVisitorSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: TextField(
                controller: _visitorSearchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
                decoration: InputDecoration(
                  hintText: 'Search visitor, phone, flat, company...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF6B7280)),
                  suffixIcon: _visitorSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Color(0xFF6B7280)),
                          onPressed: () {
                            _visitorSearchController.clear();
                            setState(() => _visitorSearchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: (val) {
                  setState(() => _visitorSearchQuery = val);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _loadVisitors,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: const Icon(Icons.refresh, size: 20, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Visitor Dynamic Status Chips with Live Counters ──────────────────────
  Widget _buildVisitorStatusChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _visitorFilterChip('All', _visitorCountAll, 'all', const Color(0xFF111827)),
          const SizedBox(width: 8),
          _visitorFilterChip('At Gate', _visitorCountAtGate, 'at_gate', const Color(0xFFFF6B00)),
          const SizedBox(width: 8),
          _visitorFilterChip('Approved', _visitorCountApproved, 'approved', const Color(0xFF059669)),
          const SizedBox(width: 8),
          _visitorFilterChip('Checked In', _visitorCountCheckedIn, 'checked_in', const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _visitorFilterChip('Expected', _visitorCountExpected, 'expected', const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          _visitorFilterChip('Checked Out', _visitorCountCheckedOut, 'checked_out', const Color(0xFF6B7280)),
        ],
      ),
    );
  }

  Widget _visitorFilterChip(String label, int count, String value, Color accentColor) {
    final isSelected = _visitorFilter == value;
    return InkWell(
      onTap: () {
        setState(() => _visitorFilter = value);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF374151),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Enterprise Empty Visitors State ──────────────────────────────────────
  Widget _buildEmptyVisitorsState() {
    final hasSearch = _visitorSearchQuery.trim().isNotEmpty;
    final isAtGateFilter = _visitorFilter == 'at_gate';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : isAtGateFilter
                        ? Icons.meeting_room_outlined
                        : Icons.badge_outlined,
                size: 48,
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'No matching visitors'
                  : isAtGateFilter
                      ? 'No visitors waiting at gate'
                      : 'No visitor records found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? 'No entries match "$_visitorSearchQuery". Try another search keyword.'
                  : 'New gate entries and expected guests will appear here with live actions.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                  onPressed: _loadVisitors,
                ),
                if (_userRole == 'admin' || _userRole == 'security' || _userRole == 'staff') ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_moderator, size: 16),
                    label: const Text('Log Gate Entry'),
                    onPressed: () => _showVisitorModal(isGateEntry: true),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Enterprise Visitor Card ──────────────────────────────────────────────
  Widget _buildVisitorCard(SocietyVisitorModel v) {
    final atGate = v.isAtGate;
    final isApproved = v.isApproved;
    final isCheckedIn = v.isCheckedIn;
    final isCheckedOut = v.isCheckedOut;
    final isExpected = v.isExpected;
    final isDenied = v.isDenied;

    final isStaffOrSecurity = _userRole == 'security' || _userRole == 'staff';
    final isResidentForThisFlat = _myFlatNo != null &&
        v.flatNo != null &&
        _myFlatNo!.trim().toLowerCase() == v.flatNo!.trim().toLowerCase();
    final isVisitorCreator = v.userId != null && v.userId == _currentUserId;
    final isResident = (_userRole == 'resident' && isVisitorCreator) || isResidentForThisFlat;
    final isAdminOrCommittee = _userRole == 'admin' || _userRole == 'committee';

    final statusColor = atGate
        ? const Color(0xFFFF6B00)
        : isCheckedIn
            ? const Color(0xFF10B981)
            : isApproved
                ? const Color(0xFF059669)
                : isExpected
                    ? const Color(0xFF3B82F6)
                    : isDenied
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF6B7280);

    final statusLabel = atGate
        ? 'AT GATE'
        : isCheckedIn
            ? 'INSIDE'
            : isApproved
                ? 'APPROVED'
                : isExpected
                    ? 'EXPECTED'
                    : isDenied
                        ? 'DENIED'
                        : isCheckedOut
                            ? 'CHECKED OUT'
                            : v.status.replaceAll('_', ' ').toUpperCase();

    // Category styling
    IconData typeIcon = Icons.person_outline;
    Color typeBgColor = const Color(0xFF8B5CF6);
    String typeTag = 'GUEST';

    final vType = v.visitorType.toLowerCase();
    final purpose = (v.purpose ?? '').toLowerCase();

    if (vType == 'delivery' || purpose.contains('delivery') || (v.companyName != null && v.companyName!.isNotEmpty)) {
      typeIcon = Icons.local_shipping_outlined;
      typeBgColor = const Color(0xFFFF6B00);
      typeTag = v.companyName?.isNotEmpty == true ? v.companyName!.toUpperCase() : 'DELIVERY';
    } else if (vType == 'cab' || purpose.contains('cab') || (v.cabNumber != null && v.cabNumber!.isNotEmpty)) {
      typeIcon = Icons.local_taxi_outlined;
      typeBgColor = const Color(0xFFF59E0B);
      typeTag = 'CAB';
    } else if (vType == 'service' || purpose.contains('service') || purpose.contains('repair') || purpose.contains('work')) {
      typeIcon = Icons.home_repair_service_outlined;
      typeBgColor = const Color(0xFF2563EB);
      typeTag = v.serviceCategory?.isNotEmpty == true ? v.serviceCategory!.toUpperCase() : 'SERVICE';
    } else {
      typeIcon = Icons.person_outline;
      typeBgColor = const Color(0xFF8B5CF6);
      typeTag = 'GUEST';
    }

    return InkWell(
      onTap: () => _showVisitorDetailSheet(v),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: atGate ? const Color(0xFFFF6B00) : const Color(0xFFE2E8F0),
            width: atGate ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Avatar, Visitor Full Name (Never truncated!), Category & Phone subtitle, Status Badge, 3-dots menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: typeBgColor.withValues(alpha: 0.12),
                  child: Icon(typeIcon, color: typeBgColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.visitorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeBgColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeTag,
                              style: TextStyle(
                                color: typeBgColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (v.visitorPhone != null && v.visitorPhone!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              v.visitorPhone!,
                              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (atGate) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF9CA3AF)),
                  onSelected: (action) {
                    if (action == 'details') {
                      _showVisitorDetailSheet(v);
                    } else if (action == 'share') {
                      _sharePassOnWhatsApp(v);
                    } else if (action == 'call' && v.visitorPhone != null && v.visitorPhone!.isNotEmpty) {
                      launchUrl(Uri.parse('tel:${v.visitorPhone}'));
                    } else if (action == 'deny') {
                      _promptDenyVisitor(v);
                    } else if (action == 'delete') {
                      _promptDeleteVisitor(v);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.badge_outlined, size: 18, color: Color(0xFF374151)),
                          SizedBox(width: 8),
                          Text('View Pass Details', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    if (isExpected)
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 18, color: Color(0xFF25D366)),
                            SizedBox(width: 8),
                            Text('Share on WhatsApp', style: TextStyle(fontSize: 13, color: Color(0xFF15803D))),
                          ],
                        ),
                      ),
                    if (v.visitorPhone != null && v.visitorPhone!.isNotEmpty)
                      const PopupMenuItem(
                        value: 'call',
                        child: Row(
                          children: [
                            Icon(Icons.call_outlined, size: 18, color: Color(0xFF059669)),
                            SizedBox(width: 8),
                            Text('Call Visitor', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    if (atGate || isExpected)
                      const PopupMenuItem(
                        value: 'deny',
                        child: Row(
                          children: [
                            Icon(Icons.block, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Deny Entry', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    if (isAdminOrCommittee || isStaffOrSecurity)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Delete Pass', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Row 2: Destination Flat & Purpose Badges
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (v.flatNo != null && v.flatNo!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.apartment, size: 13, color: Color(0xFF2563EB)),
                        const SizedBox(width: 4),
                        Text(
                          'Flat ${v.flatNo}',
                          style: const TextStyle(
                            color: Color(0xFF1E40AF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (v.purpose != null && v.purpose!.isNotEmpty)
                  _infoBadge(Icons.assignment_outlined, v.purpose!),
                if (v.gateName.isNotEmpty)
                  _infoBadge(Icons.door_sliding_outlined, v.gateName),
                if (v.vehicleNo != null && v.vehicleNo!.isNotEmpty)
                  _infoBadge(Icons.directions_car_outlined, v.vehicleNo!),
              ],
            ),

            // Row 3: Enterprise Smart Timeline & Duration Bar
            const SizedBox(height: 10),
            _buildSmartTimingBar(v),

            // Row 4: Action Buttons (Strictly Role Based!)
            if (!isStaffOrSecurity && atGate && !isApproved && (isResident || isResidentForThisFlat)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _promptDenyVisitor(v),
                      child: const Text('Deny Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Approve Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () => _handleVisitorApprove(v),
                    ),
                  ),
                ],
              ),
            ]
            else if (isStaffOrSecurity || isAdminOrCommittee) ...[
              if (atGate || isApproved) ...[
                if (!isApproved && atGate && v.flatNo != null && v.flatNo!.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      SocietyMemberModel? host;
                      for (final m in _societyMembers) {
                        if ((m.flatNo ?? '').trim().toLowerCase() == v.flatNo!.trim().toLowerCase() &&
                            m.phone.isNotEmpty) {
                          host = m;
                          break;
                        }
                      }
                      if (host == null || host.phone.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final hostMember = host;
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        child: InkWell(
                          onTap: () => launchUrl(Uri.parse('tel:${hostMember.phone}')),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.phone_in_talk, size: 14, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Call Host: ${hostMember.name.isNotEmpty ? hostMember.name : "Flat ${v.flatNo ?? ''}"} (${hostMember.phone})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF2563EB)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _promptDenyVisitor(v),
                        child: const Text('Deny Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isApproved ? const Color(0xFF10B981) : const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.login, size: 16),
                        label: Text(
                          isApproved ? 'Allow Entry (Check In)' : 'Check In (Admit)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _handleVisitorCheckIn(v),
                      ),
                    ),
                  ],
                ),
              ] else if (isCheckedIn) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4B5563),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Check Out (Exit Gate)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => _handleVisitorCheckOut(v),
                  ),
                ),
              ] else if (isExpected) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6B00),
                          side: const BorderSide(color: Color(0xFFFF6B00)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _handleVisitorAtGate(v),
                        child: const Text('Mark At Gate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.login, size: 16),
                        label: const Text('Check In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _handleVisitorCheckIn(v),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ─── Visitor Full Detail & Audit Sheet ────────────────────────────────────
  void _showVisitorDetailSheet(SocietyVisitorModel v) {
    final atGate = v.isAtGate;
    final isApproved = v.isApproved;
    final isCheckedIn = v.isCheckedIn;
    final isExpected = v.isExpected;

    final isStaffOrSecurity = _userRole == 'security' || _userRole == 'staff';
    final isResidentForThisFlat = _myFlatNo != null &&
        v.flatNo != null &&
        _myFlatNo!.trim().toLowerCase() == v.flatNo!.trim().toLowerCase();
    final isVisitorCreator = v.userId != null && v.userId == _currentUserId;
    final isResident = (_userRole == 'resident' && isVisitorCreator) || isResidentForThisFlat;
    final isAdminOrCommittee = _userRole == 'admin' || _userRole == 'committee';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'PASS #VIS-${v.id}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        v.visitorType.toUpperCase(),
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Large Visitor Name & Phone Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFFF6B00).withValues(alpha: 0.15),
                      child: Text(
                        v.visitorName.isNotEmpty ? v.visitorName[0].toUpperCase() : 'V',
                        style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.visitorName,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v.visitorPhone ?? 'Phone not provided',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (v.visitorPhone != null && v.visitorPhone!.isNotEmpty)
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                        icon: const Icon(Icons.call, color: Colors.white, size: 20),
                        tooltip: 'Call Visitor',
                        onPressed: () => launchUrl(Uri.parse('tel:${v.visitorPhone}')),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Details Grid (Log info that guard added)
              const Text('Logged Entry Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              const SizedBox(height: 10),
              _summaryRow('Current Status', v.status.replaceAll('_', ' ').toUpperCase()),
              if (v.flatNo != null && v.flatNo!.isNotEmpty) ...[
                _summaryRow('Destination Flat', 'Flat ${v.flatNo}'),
                Builder(
                  builder: (context) {
                    SocietyMemberModel? host;
                    for (final m in _societyMembers) {
                      if ((m.flatNo ?? '').trim().toLowerCase() == v.flatNo!.trim().toLowerCase() &&
                          m.phone.isNotEmpty) {
                        host = m;
                        break;
                      }
                    }
                    if (host != null && host.phone.isNotEmpty) {
                      final hostMember = host;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Color(0xFF2563EB), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Host: ${hostMember.name.isNotEmpty ? hostMember.name : "Resident"} (Flat ${v.flatNo})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E40AF)),
                                  ),
                                  Text(
                                    hostMember.phone,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.all(6),
                              ),
                              icon: const Icon(Icons.call, color: Colors.white, size: 16),
                              onPressed: () => launchUrl(Uri.parse('tel:${hostMember.phone}')),
                              tooltip: 'Call Host Resident',
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
              if (v.purpose != null && v.purpose!.isNotEmpty)
                _summaryRow('Visit Purpose', v.purpose!),
              if (v.companyName != null && v.companyName!.isNotEmpty)
                _summaryRow('Company / Brand', v.companyName!),
              if (v.vehicleNo != null && v.vehicleNo!.isNotEmpty)
                _summaryRow('Vehicle Registration', v.vehicleNo!),
              if (v.vehicleType != 'none')
                _summaryRow('Vehicle Type', v.vehicleType.replaceAll('_', ' ').toUpperCase()),
              if (v.driverName != null && v.driverName!.isNotEmpty)
                _summaryRow('Driver Name', v.driverName!),
              if (v.gateName.isNotEmpty)
                _summaryRow('Entry Gate', v.gateName),
              if (v.checkInTime != null)
                _summaryRow('Check-in Timestamp', DateFormat('dd MMM yyyy, hh:mm a').format(v.checkInTime!)),
              if (v.checkOutTime != null)
                _summaryRow('Check-out Timestamp', DateFormat('dd MMM yyyy, hh:mm a').format(v.checkOutTime!)),
              if (v.expectedTime != null)
                _summaryRow('Expected Arrival', DateFormat('dd MMM yyyy, hh:mm a').format(v.expectedTime!)),

              // Action Toolbar at bottom of Sheet
              const SizedBox(height: 20),
              // Resident Actions: Only for Resident of this flat (Never for Guard)
              if (!isStaffOrSecurity && atGate && !isApproved && (isResident || isResidentForThisFlat)) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _promptDenyVisitor(v);
                        },
                        child: const Text('Deny Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Approve Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleVisitorApprove(v);
                        },
                      ),
                    ),
                  ],
                ),
              ]
              // Guard / Security Actions: Guard manages admittance at gate (Never approves on behalf of resident)
              else if (isStaffOrSecurity || isAdminOrCommittee) ...[
                if (atGate || isApproved) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _promptDenyVisitor(v);
                          },
                          child: const Text('Deny Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isApproved ? const Color(0xFF10B981) : const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.login),
                          label: Text(
                            isApproved ? 'Allow Entry (Check In)' : 'Check In (Admit)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleVisitorCheckIn(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ] else if (isCheckedIn) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF374151),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Check Out (Exit Gate)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleVisitorCheckOut(v);
                      },
                    ),
                  ),
                ] else if (isExpected) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6B00),
                            side: const BorderSide(color: Color(0xFFFF6B00)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleVisitorAtGate(v);
                          },
                          child: const Text('Mark At Gate', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.login),
                          label: const Text('Check In', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleVisitorCheckIn(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Visitor CRUD Handlers ────────────────────────────────────────────────
  Future<void> _handleVisitorCheckIn(SocietyVisitorModel v) async {
    final messenger = ScaffoldMessenger.of(context);

    // If resident approval is pending, ask confirmation from security
    if (!v.isApproved && v.isAtGate) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 8),
              Text('Approval Pending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Resident of Flat ${v.flatNo ?? ""} has not approved this visitor yet.\n\nDo you want to confirm gate entry under security clearance?',
            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Wait for Approval', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Allow Gate Entry'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await _societyService.updateVisitorStatus(
        v.id,
        _resolvedSocietyId!,
        status: 'checked_in',
        remark: 'Checked in by ${_userRole == "staff" || _userRole == "security" ? "Gate Security" : "Management"}',
      );
      _loadVisitors();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${v.visitorName} checked in at gate successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to check in: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleVisitorCheckOut(SocietyVisitorModel v) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _societyService.updateVisitorStatus(
        v.id,
        _resolvedSocietyId!,
        status: 'checked_out',
        remark: 'Checked out at exit gate',
      );
      _loadVisitors();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${v.visitorName} checked out successfully!'),
            backgroundColor: const Color(0xFF4B5563),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to check out: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleVisitorApprove(SocietyVisitorModel v) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _societyService.updateVisitorStatus(
        v.id,
        _resolvedSocietyId!,
        status: 'approved',
        remark: 'Approved by resident of Flat ${v.flatNo ?? ""}',
      );
      _loadVisitors();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Entry approved for ${v.visitorName}! Gate security notified.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Approval failed: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleVisitorAtGate(SocietyVisitorModel v) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _societyService.updateVisitorStatus(
        v.id,
        _resolvedSocietyId!,
        status: 'at_gate',
        remark: 'Marked at gate by security',
      );
      _loadVisitors();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${v.visitorName} marked at gate! Resident notified.'),
            backgroundColor: const Color(0xFFFF6B00),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Action failed: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _promptDenyVisitor(SocietyVisitorModel v) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Deny Gate Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to deny entry for ${v.visitorName}?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for Denial (Optional)',
                hintText: 'e.g. Resident refused, wrong flat, unverified',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _societyService.updateVisitorStatus(
                  v.id,
                  _resolvedSocietyId!,
                  status: 'denied',
                  reason: reasonController.text.trim().isNotEmpty
                      ? reasonController.text.trim()
                      : 'Denied by gate security',
                );
                _loadVisitors();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Entry denied for ${v.visitorName}'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Action failed: ${e.toString()}'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Confirm Deny', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _promptDeleteVisitor(SocietyVisitorModel v) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Delete Visitor Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete visitor record #${v.id} (${v.visitorName})? This action cannot be undone.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _societyService.deleteVisitor(v.id, _resolvedSocietyId!);
                _loadVisitors();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Visitor record #${v.id} deleted successfully.'),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to delete: ${e.toString()}'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Dynamic Conditional Visitor Modal (PRD Section 5 & 14) ────────────────
  void _showVisitorModal({
    bool isGateEntry = false,
    String initialCategory = 'guest',
    String? defaultCompany,
  }) {
    if (_resolvedSocietyId == null) return;

    // Common fields
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final flatController = TextEditingController(text: isGateEntry ? '' : (_myFlatNo ?? ''));
    String defaultPurpose = 'Personal Visit';
    if (isGateEntry) {
      defaultPurpose = 'Delivery';
    } else {
      if (initialCategory == 'delivery') defaultPurpose = 'Delivery';
      else if (initialCategory == 'cab') defaultPurpose = 'Cab Pick/Drop';
      else if (initialCategory == 'service') defaultPurpose = 'Maintenance Service';
    }
    final purposeController = TextEditingController(text: defaultPurpose);

    int? selectedHostUserId;
    SocietyMemberModel? selectedMember;

    if (!isGateEntry && _myFlatNo != null) {
      final matches = _registeredFlatMembers.where((m) => (m.flatNo ?? '').trim().toLowerCase() == _myFlatNo!.trim().toLowerCase());
      if (matches.isNotEmpty) {
        selectedMember = matches.first;
        selectedHostUserId = selectedMember.userId;
      }
    }

    // Dynamic fields
    final companyController = TextEditingController(text: defaultCompany ?? '');
    final driverNameController = TextEditingController();
    final cabNumberController = TextEditingController();
    final serviceCategoryController = TextEditingController();
    final workerTypeController = TextEditingController();
    final vehicleNoController = TextEditingController();
    final remarksController = TextEditingController();

    String visitorType = isGateEntry ? 'delivery' : initialCategory;
    String vehicleType = 'none';
    String entryType = isGateEntry ? 'walk_in' : 'expected';
    int? selectedGateId = _availableGates.isNotEmpty ? _availableGates[0].id : null;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isGateEntry ? 'Log Gate Entry (At Gate)' : 'Pre-Approve Visitor',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                if (isGateEntry) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Visitor will be logged with status "At Gate". Resident will receive instant notification.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF059669)),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1-Tap Delivery & Cab Quick Select:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _quickBrandChip('🛵 Swiggy', () {
                          setModalState(() {
                            visitorType = 'delivery';
                            companyController.text = 'Swiggy';
                            if (nameController.text.trim().isEmpty) nameController.text = 'Swiggy Delivery Partner';
                            purposeController.text = 'Food Delivery';
                            vehicleType = '2_wheeler';
                          });
                        }),
                        const SizedBox(width: 6),
                        _quickBrandChip('🍕 Zomato', () {
                          setModalState(() {
                            visitorType = 'delivery';
                            companyController.text = 'Zomato';
                            if (nameController.text.trim().isEmpty) nameController.text = 'Zomato Delivery Partner';
                            purposeController.text = 'Food Delivery';
                            vehicleType = '2_wheeler';
                          });
                        }),
                        const SizedBox(width: 6),
                        _quickBrandChip('⚡ Blinkit', () {
                          setModalState(() {
                            visitorType = 'delivery';
                            companyController.text = 'Blinkit';
                            if (nameController.text.trim().isEmpty) nameController.text = 'Blinkit Delivery Partner';
                            purposeController.text = 'Grocery Delivery';
                            vehicleType = '2_wheeler';
                          });
                        }),
                        const SizedBox(width: 6),
                        _quickBrandChip('📦 Amazon', () {
                          setModalState(() {
                            visitorType = 'delivery';
                            companyController.text = 'Amazon';
                            if (nameController.text.trim().isEmpty) nameController.text = 'Amazon Delivery Partner';
                            purposeController.text = 'Parcel Delivery';
                            vehicleType = '2_wheeler';
                          });
                        }),
                        const SizedBox(width: 6),
                        _quickBrandChip('🛍️ Zepto', () {
                          setModalState(() {
                            visitorType = 'delivery';
                            companyController.text = 'Zepto';
                            if (nameController.text.trim().isEmpty) nameController.text = 'Zepto Delivery Partner';
                            purposeController.text = 'Grocery Delivery';
                            vehicleType = '2_wheeler';
                          });
                        }),
                        const SizedBox(width: 6),
                        _quickBrandChip('🛒 Flipkart', () {
                          setModalState(() {
                            visitorType = 'delivery';
                            companyController.text = 'Flipkart';
                            if (nameController.text.trim().isEmpty) nameController.text = 'Flipkart Delivery Partner';
                            purposeController.text = 'Parcel Delivery';
                            vehicleType = '2_wheeler';
                          });
                        }),
                        const SizedBox(width: 6),
                        _quickBrandChip('🚕 Cab / Ride', () {
                          setModalState(() {
                            visitorType = 'cab';
                            purposeController.text = 'Cab Pick/Drop';
                            vehicleType = '4_wheeler';
                          });
                        }),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Common Field 1: Visitor Type Dropdown
                DropdownButtonFormField<String>(
                  value: visitorType,
                  decoration: InputDecoration(
                    labelText: 'Visitor Category *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'guest', child: Text('Guest / Personal Visitor')),
                    DropdownMenuItem(value: 'delivery', child: Text('Delivery (Food / Parcel / Groceries)')),
                    DropdownMenuItem(value: 'cab', child: Text('Cab / Ride (Uber / Ola / Rapido)')),
                    DropdownMenuItem(value: 'service', child: Text('Service Provider (Technician / Repair)')),
                    DropdownMenuItem(value: 'vendor', child: Text('Vendor / Supplier')),
                    DropdownMenuItem(value: 'domestic_worker', child: Text('Domestic Worker / Help')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        visitorType = val;
                        if (val == 'delivery') {
                          purposeController.text = 'Delivery';
                        } else if (val == 'cab') {
                          purposeController.text = 'Cab Pick/Drop';
                        } else if (val == 'service') {
                          purposeController.text = 'Maintenance Service';
                        } else if (val == 'domestic_worker') {
                          purposeController.text = 'Daily Help Work';
                        } else {
                          purposeController.text = 'Personal Visit';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Common Field 2: Visitor Name
                _modalField('Visitor Full Name *', 'e.g. Ramesh Kumar', nameController),
                const SizedBox(height: 12),

                // Common Field 3: Visitor Phone
                _modalField('Visitor Mobile Number', 'e.g. 9876543210', phoneController),
                const SizedBox(height: 12),

                // ── Dynamic Conditional Fields with Smart Flat Selector ─────────
                // GUEST: Show Host Resident * & Purpose
                if (visitorType == 'guest') ...[
                  _buildDestinationFlatField(setModalState, flatController, selectedHostUserId, selectedMember, (uId, mem) { selectedHostUserId = uId; selectedMember = mem; }, isGateEntry: isGateEntry, label: 'Host Resident / Flat No. *'),
                  const SizedBox(height: 12),
                  _modalField('Purpose of Visit', 'e.g. Family gathering, dinner', purposeController),
                  const SizedBox(height: 12),
                ],

                // DELIVERY: Show Delivery Partner / Company, Destination Flat, Vehicle Type, Vehicle Number
                if (visitorType == 'delivery') ...[
                  _modalField('Delivery Partner / Company *', 'e.g. Swiggy, Zomato, Amazon, Blinkit', companyController),
                  const SizedBox(height: 12),
                  _buildDestinationFlatField(setModalState, flatController, selectedHostUserId, selectedMember, (uId, mem) { selectedHostUserId = uId; selectedMember = mem; }, isGateEntry: isGateEntry, label: 'Destination Flat No. *'),
                  const SizedBox(height: 12),
                  _modalField('Vehicle Number (Optional)', 'e.g. MH-12-AB-1234', vehicleNoController),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: vehicleType,
                    decoration: InputDecoration(
                      labelText: 'Vehicle Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None / Walk-in')),
                      DropdownMenuItem(value: '2_wheeler', child: Text('2-Wheeler (Bike / Scooter)')),
                      DropdownMenuItem(value: '4_wheeler', child: Text('4-Wheeler (Car / Van)')),
                      DropdownMenuItem(value: 'commercial', child: Text('Commercial Vehicle')),
                    ],
                    onChanged: (v) => setModalState(() => vehicleType = v ?? 'none'),
                  ),
                  const SizedBox(height: 12),
                ],

                // CAB / RIDE: Show Driver Name, Cab Number, Vehicle Type, Host Resident
                if (visitorType == 'cab') ...[
                  _modalField('Driver Name', 'e.g. Suresh Driver', driverNameController),
                  const SizedBox(height: 12),
                  _modalField('Cab / Vehicle Number *', 'e.g. MH-02-EE-9999', cabNumberController),
                  const SizedBox(height: 12),
                  _buildDestinationFlatField(setModalState, flatController, selectedHostUserId, selectedMember, (uId, mem) { selectedHostUserId = uId; selectedMember = mem; }, isGateEntry: isGateEntry, label: 'Host Resident / Pick Flat *'),
                  const SizedBox(height: 12),
                ],

                // SERVICE PROVIDER: Show Service Category, Company / Person Name, Host Flat, Vehicle Number
                if (visitorType == 'service') ...[
                  _modalField('Service Category *', 'e.g. Electrician, AC Repair, Plumbing', serviceCategoryController),
                  const SizedBox(height: 12),
                  _modalField('Company / Technician Name', 'e.g. Urban Company / Raj Repair', companyController),
                  const SizedBox(height: 12),
                  _buildDestinationFlatField(setModalState, flatController, selectedHostUserId, selectedMember, (uId, mem) { selectedHostUserId = uId; selectedMember = mem; }, isGateEntry: isGateEntry, label: 'Host Flat No. *'),
                  const SizedBox(height: 12),
                  _modalField('Vehicle Number (Optional)', 'e.g. MH-12-CD-5678', vehicleNoController),
                  const SizedBox(height: 12),
                ],

                // VENDOR: Show Company Name, Purpose, Host Flat
                if (visitorType == 'vendor') ...[
                  _modalField('Company / Vendor Name *', 'e.g. Reliable Water Suppliers', companyController),
                  const SizedBox(height: 12),
                  _modalField('Purpose of Delivery / Work', 'e.g. Society Water Tank Supply', purposeController),
                  const SizedBox(height: 12),
                  _buildFlatAutocompleteSelector(
                    controller: flatController,
                    selectedHostUserId: selectedHostUserId,
                    selectedMember: selectedMember,
                    onSelect: (uId, mem) {
                      selectedHostUserId = uId;
                      selectedMember = mem;
                    },
                    setModalState: setModalState,
                    label: 'Host Department / Flat (Optional)',
                  ),
                  const SizedBox(height: 12),
                ],

                // DOMESTIC WORKER: Show Host Flat / Resident, Worker Type
                if (visitorType == 'domestic_worker') ...[
                  _buildDestinationFlatField(setModalState, flatController, selectedHostUserId, selectedMember, (uId, mem) { selectedHostUserId = uId; selectedMember = mem; }, isGateEntry: isGateEntry, label: 'Host Resident / Flat No. *'),
                  const SizedBox(height: 12),
                  _modalField('Worker Type *', 'e.g. Housekeeper / Cook / Driver', workerTypeController),
                  const SizedBox(height: 12),
                ],

                // OTHER: Purpose, Host Resident, Remarks
                if (visitorType == 'other') ...[
                  _buildDestinationFlatField(setModalState, flatController, selectedHostUserId, selectedMember, (uId, mem) { selectedHostUserId = uId; selectedMember = mem; }, isGateEntry: isGateEntry, label: 'Host Resident / Flat'),
                  const SizedBox(height: 12),
                  _modalField('Purpose *', 'e.g. Courier drop, Inspection', purposeController),
                  const SizedBox(height: 12),
                  _modalField('Remarks', 'Any additional notes', remarksController),
                  const SizedBox(height: 12),
                ],

                // Common Gate Selection (if gates available)
                if (_availableGates.isNotEmpty && isGateEntry) ...[
                  DropdownButtonFormField<int>(
                    value: selectedGateId,
                    decoration: InputDecoration(
                      labelText: 'Gate *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _availableGates.map((g) => DropdownMenuItem(value: g.id, child: Text(g.gateName))).toList(),
                    onChanged: (val) => setModalState(() => selectedGateId = val),
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGateEntry ? const Color(0xFF059669) : const Color(0xFF111827),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final name = nameController.text.trim();
                            if (name.isEmpty) return;

                            setModalState(() => isSubmitting = true);
                            try {
                              final newVisitor = await _societyService.createVisitor(
                                _resolvedSocietyId!,
                                visitorName: name,
                                visitorPhone: phoneController.text.trim(),
                                flatNo: flatController.text.trim(),
                                userId: selectedHostUserId,
                                purpose: purposeController.text.trim(),
                                status: isGateEntry ? 'at_gate' : 'expected',
                                visitorType: visitorType,
                                companyName: companyController.text.trim(),
                                driverName: driverNameController.text.trim(),
                                cabNumber: cabNumberController.text.trim(),
                                serviceCategory: serviceCategoryController.text.trim(),
                                workerType: workerTypeController.text.trim(),
                                vehicleNo: vehicleNoController.text.trim().isNotEmpty
                                    ? vehicleNoController.text.trim()
                                    : cabNumberController.text.trim(),
                                vehicleNumber: vehicleNoController.text.trim().isNotEmpty
                                    ? vehicleNoController.text.trim()
                                    : cabNumberController.text.trim(),
                                vehicleType: vehicleType,
                                entryType: entryType,
                                gateId: selectedGateId,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              setState(() {
                                _visitorFilter = 'all';
                                _visitorSearchQuery = '';
                                _visitorSearchController.clear();
                              });
                              _loadVisitors();
                              if (!isGateEntry && mounted) {
                                _showPassCreatedDialog(newVisitor);
                              }
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isGateEntry
                                          ? 'Gate entry logged! Resident notified.'
                                          : 'Visitor pre-approved successfully!',
                                    ),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            } catch (err) {
                              setModalState(() => isSubmitting = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(err.toString()), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            isGateEntry ? 'Log Gate Entry' : 'Pre-Approve Visitor',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 5-Step Enterprise Guard Onboarding Wizard (PRD Section 1 & 13) ─────────
  void _showOnboardGuardModal() {
    if (_resolvedSocietyId == null) return;
    int currentStep = 0;

    // STEP 1 — PERSONAL
    String? profilePhotoUrl;
    bool isUploadingPhoto = false;
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final altPhoneCtrl = TextEditingController();
    String gender = 'male';
    final dobCtrl = TextEditingController();

    // STEP 2 — VERIFICATION
    String idType = 'aadhaar';
    final idNumberCtrl = TextEditingController();
    final idDocUrlCtrl = TextEditingController();
    bool isUploadingDoc = false;
    String verificationStatus = 'unverified';
    String policeVerificationStatus = 'not_submitted';
    final verificationDateCtrl = TextEditingController();

    // STEP 3 — EMPLOYMENT
    String guardType = 'society_guard';
    final designationCtrl = TextEditingController(text: 'Security Guard');
    final employeeIdCtrl = TextEditingController();
    final agencyCtrl = TextEditingController();
    final joiningDateCtrl = TextEditingController(text: DateTime.now().toIso8601String().split('T')[0]);
    final contractEndCtrl = TextEditingController();
    String employmentStatus = 'active';
    final notesCtrl = TextEditingController();

    // STEP 4 — GATE & SHIFT
    int? selectedGateId = _availableGates.isNotEmpty ? _availableGates[0].id : null;
    int? selectedShiftId = _availableShifts.isNotEmpty ? _availableShifts[0].id : null;
    String dutyType = 'permanent';
    String weeklyOff = 'Sunday';
    final remarksCtrl = TextEditingController(text: 'Assigned to duty');

    bool isSubmitting = false;

    Future<void> pickAndUploadPhoto(StateSetter setModalState) async {
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (picked == null) return;

        setModalState(() {
          isUploadingPhoto = true;
        });

        final bytes = await picked.readAsBytes();
        final uploadedUrl = await _societyService.uploadGuardPhotoBytes(
          _resolvedSocietyId!,
          bytes,
          picked.name,
        );

        setModalState(() {
          profilePhotoUrl = uploadedUrl;
          isUploadingPhoto = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guard profile photo uploaded successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } catch (err) {
        setModalState(() {
          isUploadingPhoto = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload photo: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    Future<void> pickAndUploadDoc(StateSetter setModalState) async {
      try {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
        );
        final file = files.firstOrNull;
        if (file == null) return;

        setModalState(() {
          isUploadingDoc = true;
        });

        final bytes = await file.readAsBytes();

        final uploadedUrl = await _societyService.uploadGuardIdDocumentBytes(
          _resolvedSocietyId!,
          bytes,
          file.name,
          idType: idType,
          idNumber: idNumberCtrl.text.trim(),
        );

        setModalState(() {
          idDocUrlCtrl.text = uploadedUrl;
          isUploadingDoc = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guard ID document uploaded successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } catch (err) {
        setModalState(() {
          isUploadingDoc = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload ID document: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: const Color(0xFFFF6B00).withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.shield_outlined, color: Color(0xFFFF6B00), size: 20),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Onboard Security Guard',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),

                // 5-Step Wizard Indicator
                Row(
                  children: [
                    _stepIndicator(0, '1. Personal', currentStep),
                    _stepDivider(),
                    _stepIndicator(1, '2. Verify', currentStep),
                    _stepDivider(),
                    _stepIndicator(2, '3. Employ', currentStep),
                    _stepDivider(),
                    _stepIndicator(3, '4. Duty', currentStep),
                    _stepDivider(),
                    _stepIndicator(4, '5. Review', currentStep),
                  ],
                ),
                const Divider(height: 24),

                // ── STEP 1: PERSONAL DETAILS ──────────────────────────
                if (currentStep == 0) ...[
                  const Text('Step 1 — Personal Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),

                  // Profile Photo Controls: [Add Photo], [Change Photo], [Remove Photo]
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFE5E7EB),
                              backgroundImage: profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty
                                  ? NetworkImage(profilePhotoUrl!)
                                  : null,
                              child: isUploadingPhoto
                                  ? const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFF6B00)),
                                    )
                                  : (profilePhotoUrl == null || profilePhotoUrl!.isEmpty
                                      ? const Icon(Icons.person, size: 40, color: Color(0xFF9CA3AF))
                                      : null),
                            ),
                            if (!isUploadingPhoto && (profilePhotoUrl == null || profilePhotoUrl!.isEmpty))
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () => pickAndUploadPhoto(setModalState),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: Color(0xFFFF6B00), shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (profilePhotoUrl == null) ...[
                              TextButton.icon(
                                icon: isUploadingPhoto
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.add_a_photo, size: 16, color: Color(0xFFFF6B00)),
                                label: Text(
                                  isUploadingPhoto ? 'Uploading...' : 'Add Photo',
                                  style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold),
                                ),
                                onPressed: isUploadingPhoto ? null : () => pickAndUploadPhoto(setModalState),
                              ),
                            ] else ...[
                              TextButton.icon(
                                icon: isUploadingPhoto
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.edit, size: 16),
                                label: Text(isUploadingPhoto ? 'Uploading...' : 'Change Photo'),
                                onPressed: isUploadingPhoto ? null : () => pickAndUploadPhoto(setModalState),
                              ),
                              const SizedBox(width: 6),
                              TextButton.icon(
                                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                                onPressed: isUploadingPhoto ? null : () => setModalState(() => profilePhotoUrl = null),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _modalField('Full Name', 'e.g. Ramesh Kumar', nameCtrl),
                  const SizedBox(height: 10),
                  _modalField('Mobile Number (Required) *', 'e.g. 9876543210', phoneCtrl),
                  const SizedBox(height: 10),
                  _modalField('Alternate Mobile', 'e.g. 9123456789', altPhoneCtrl),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: gender,
                          decoration: InputDecoration(labelText: 'Gender', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (val) => setModalState(() => gender = val ?? 'male'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datePickerField(
                          context,
                          'Date of Birth (DOB) *',
                          'Select Date',
                          dobCtrl,
                          initialDate: DateTime(1995, 1, 1),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                          onChanged: () => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── STEP 2: VERIFICATION ──────────────────────────────
                if (currentStep == 1) ...[
                  const Text('Step 2 — Identity & Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: idType,
                    decoration: InputDecoration(
                      labelText: 'ID Type *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'aadhaar', child: Text('Aadhaar Card')),
                      DropdownMenuItem(value: 'voter_id', child: Text('Voter ID Card')),
                      DropdownMenuItem(value: 'driving_license', child: Text('Driving License')),
                      DropdownMenuItem(value: 'pan', child: Text('PAN Card')),
                      DropdownMenuItem(value: 'passport', child: Text('Passport')),
                      DropdownMenuItem(value: 'other', child: Text('Other Govt Photo ID')),
                    ],
                    onChanged: (val) => setModalState(() => idType = val ?? 'aadhaar'),
                  ),
                  const SizedBox(height: 10),
                  _modalField('ID Number *', 'e.g. 1234 5678 9012', idNumberCtrl),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _modalField('ID Document File URL / Ref', 'Uploaded file URL or reference', idDocUrlCtrl),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: isUploadingDoc
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.upload_file, size: 18),
                          label: Text(isUploadingDoc ? 'Uploading...' : 'Upload Doc'),
                          onPressed: isUploadingDoc ? null : () => pickAndUploadDoc(setModalState),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          isDense: true,
                          value: verificationStatus,
                          decoration: InputDecoration(
                            labelText: 'Verification Status',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'unverified', child: Text('Unverified', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'pending', child: Text('Pending Review', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'verified', child: Text('Verified', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'rejected', child: Text('Rejected', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) => setModalState(() => verificationStatus = val ?? 'unverified'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          isDense: true,
                          value: policeVerificationStatus,
                          decoration: InputDecoration(
                            labelText: 'Police Verif.',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'not_submitted', child: Text('Not Submitted', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'pending', child: Text('Pending', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'in_progress', child: Text('In Progress', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'verified', child: Text('Verified', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) => setModalState(() => policeVerificationStatus = val ?? 'not_submitted'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _datePickerField(
                    context,
                    'Verification Date',
                    'Select Verification Date',
                    verificationDateCtrl,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                    onChanged: () => setModalState(() {}),
                  ),
                ],

                // ── STEP 3: EMPLOYMENT ────────────────────────────────
                if (currentStep == 2) ...[
                  const Text('Step 3 — Employment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: guardType,
                    decoration: InputDecoration(
                      labelText: 'Guard Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'society_guard', child: Text('Direct Society Guard')),
                      DropdownMenuItem(value: 'contract_guard', child: Text('Contract / Agency Guard')),
                      DropdownMenuItem(value: 'temporary_guard', child: Text('Temporary / Reliever Guard')),
                    ],
                    onChanged: (val) => setModalState(() => guardType = val ?? 'society_guard'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _modalField('Designation', 'Security Guard', designationCtrl)),
                      const SizedBox(width: 10),
                      Expanded(child: _modalField('Employee ID', 'EMP-009', employeeIdCtrl)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _modalField('Agency / Contractor Name', 'e.g. SIS Security / Eagle Eye', agencyCtrl),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _datePickerField(
                          context,
                          'Joining Date',
                          'Select Date',
                          joiningDateCtrl,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2010),
                          lastDate: DateTime(2040),
                          onChanged: () => setModalState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datePickerField(
                          context,
                          'Contract End Date',
                          'Select Date',
                          contractEndCtrl,
                          initialDate: DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2040),
                          onChanged: () => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _modalField('Notes / Special Instructions', 'e.g. Trained in fire safety', notesCtrl),
                ],

                // ── STEP 4: GATE & SHIFT ──────────────────────────────
                if (currentStep == 3) ...[
                  const Text('Step 4 — Gate & Shift Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  if (_availableGates.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: selectedGateId,
                      decoration: InputDecoration(
                        labelText: 'Assigned Gate *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _availableGates.map((g) => DropdownMenuItem(value: g.id, child: Text(g.gateName))).toList(),
                      onChanged: (val) => setModalState(() => selectedGateId = val),
                    ),
                  const SizedBox(height: 10),
                  if (_availableShifts.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: selectedShiftId,
                      decoration: InputDecoration(
                        labelText: 'Assigned Shift *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _availableShifts.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.shiftName} (${s.startTime} - ${s.endTime})'))).toList(),
                      onChanged: (val) => setModalState(() => selectedShiftId = val),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: dutyType,
                          decoration: InputDecoration(labelText: 'Duty Type', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          items: const [
                            DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                            DropdownMenuItem(value: 'rotational', child: Text('Rotational')),
                            DropdownMenuItem(value: 'reliever', child: Text('Reliever')),
                          ],
                          onChanged: (v) => setModalState(() => dutyType = v ?? 'permanent'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: weeklyOff,
                          decoration: InputDecoration(labelText: 'Weekly Off', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                          items: const [
                            DropdownMenuItem(value: 'Sunday', child: Text('Sunday')),
                            DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                            DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday')),
                            DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday')),
                            DropdownMenuItem(value: 'Thursday', child: Text('Thursday')),
                            DropdownMenuItem(value: 'Friday', child: Text('Friday')),
                            DropdownMenuItem(value: 'Saturday', child: Text('Saturday')),
                          ],
                          onChanged: (v) => setModalState(() => weeklyOff = v ?? 'Sunday'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _modalField('Assignment Remarks', 'e.g. Main entrance surveillance', remarksCtrl),
                ],

                // ── STEP 5: REVIEW & ACTIVATE ─────────────────────────
                if (currentStep == 4) ...[
                  const Text('Step 5 — Review & Activate Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summaryRow('Guard Name', nameCtrl.text.trim().isEmpty ? 'N/A' : nameCtrl.text.trim()),
                        _summaryRow('Mobile Number', phoneCtrl.text.trim()),
                        _summaryRow('Designation', designationCtrl.text.trim()),
                        _summaryRow('Agency', agencyCtrl.text.trim().isEmpty ? 'Direct Society' : agencyCtrl.text.trim()),
                        _summaryRow('Verification', '${idType.toUpperCase()} ($verificationStatus)'),
                        _summaryRow('Gate', _availableGates.firstWhere((g) => g.id == selectedGateId, orElse: () => const SocietyGateModel(id: 0, societyId: 0, gateName: 'Main Gate 1')).gateName),
                        _summaryRow('Shift', _availableShifts.firstWhere((s) => s.id == selectedShiftId, orElse: () => const SocietyShiftModel(id: 0, societyId: 0, shiftName: 'Morning Shift', startTime: '07:00', endTime: '19:00')).shiftName),
                        _summaryRow('Status', employmentStatus.toUpperCase()),
                        _summaryRow('Permissions', 'Gate Entry, Visitor Check-in/out'),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Wizard Navigation Actions
                if (currentStep < 4) ...[
                  Row(
                    children: [
                      if (currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setModalState(() => currentStep--),
                            child: const Text('Back'),
                          ),
                        ),
                      if (currentStep > 0) const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            if (currentStep == 0 && phoneCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Guard mobile number is required')),
                              );
                              return;
                            }
                            setModalState(() => currentStep++);
                          },
                          child: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Step 5 Buttons: Save Draft, Back, Activate Guard, Cancel
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setModalState(() => currentStep--),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      setModalState(() => isSubmitting = true);
                                      try {
                                        await _societyService.onboardGuardEnterprise(
                                          _resolvedSocietyId!,
                                          phone: phoneCtrl.text.trim(),
                                          name: nameCtrl.text.trim(),
                                          designation: designationCtrl.text.trim(),
                                          guardType: guardType,
                                          gateId: selectedGateId,
                                          shiftId: selectedShiftId,
                                          idType: idType,
                                          idNumber: idNumberCtrl.text.trim(),
                                          profilePhotoUrl: profilePhotoUrl,
                                          idDocumentUrl: idDocUrlCtrl.text.trim(),
                                          alternatePhone: altPhoneCtrl.text.trim(),
                                          gender: gender,
                                          dob: dobCtrl.text.trim(),
                                          agencyName: agencyCtrl.text.trim(),
                                          notes: notesCtrl.text.trim(),
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        _loadVisitors();
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            const SnackBar(content: Text('Guard saved as draft!'), backgroundColor: Color(0xFF10B981)),
                                          );
                                        }
                                      } catch (err) {
                                        setModalState(() => isSubmitting = false);
                                        if (ctx.mounted) {
                                          ScaffoldMessenger.of(ctx).showSnackBar(
                                            SnackBar(content: Text(err.toString()), backgroundColor: Colors.redAccent),
                                          );
                                        }
                                      }
                                    },
                              child: const Text('Save Draft'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    await _societyService.onboardGuardEnterprise(
                                      _resolvedSocietyId!,
                                      phone: phoneCtrl.text.trim(),
                                      name: nameCtrl.text.trim(),
                                      designation: designationCtrl.text.trim(),
                                      guardType: guardType,
                                      gateId: selectedGateId,
                                      shiftId: selectedShiftId,
                                      idType: idType,
                                      idNumber: idNumberCtrl.text.trim(),
                                      profilePhotoUrl: profilePhotoUrl,
                                      idDocumentUrl: idDocUrlCtrl.text.trim(),
                                      alternatePhone: altPhoneCtrl.text.trim(),
                                      gender: gender,
                                      dob: dobCtrl.text.trim(),
                                      agencyName: agencyCtrl.text.trim(),
                                      notes: notesCtrl.text.trim(),
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    _loadVisitors();
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Guard activated successfully!'), backgroundColor: Color(0xFF10B981)),
                                      );
                                    }
                                  } catch (err) {
                                    setModalState(() => isSubmitting = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(content: Text(err.toString()), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Activate Guard', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepIndicator(int step, String label, int activeStep) {
    final isDone = activeStep >= step;
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
          color: isDone ? const Color(0xFFFF6B00) : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }

  Widget _stepDivider() {
    return Container(width: 8, height: 1, color: const Color(0xFFE5E7EB));
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  // ─── TAB 3: POLLS ────────────────────────────────────────────────────────
  Widget _buildPollsTab() {
    if (_isLoadingPolls) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
    }

    return RefreshIndicator(
      color: const Color(0xFFFF6B00),
      onRefresh: _loadPolls,
      child: _polls.isEmpty
          ? const Center(
              child: Text('No active polls right now',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _polls.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final poll = _polls[index];
                final bool hasVoted = poll.hasVoted;
                final bool isActive = poll.isActive && !poll.isExpired;

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
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive ? 'Active Poll' : 'Closed Poll',
                              style: TextStyle(
                                color: isActive ? const Color(0xFF10B981) : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (hasVoted) ...[
                            const SizedBox(width: 8),
                            const Text('• You voted',
                                style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        poll.question,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...poll.options.map((opt) {
                        final pct = opt.percentage / 100.0;
                        final isSelected = poll.userVotedOption == opt.index;

                        if (hasVoted || !isActive) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      opt.text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      '${opt.percentage}% (${opt.count})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? const Color(0xFFFF6B00) : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isSelected ? const Color(0xFFFF6B00) : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(opt.text, style: const TextStyle(fontSize: 14, color: Color(0xFF111827))),
                              trailing: const Icon(Icons.touch_app_outlined, size: 18, color: Color(0xFFFF6B00)),
                              onTap: () async {
                                try {
                                  await _societyService.votePoll(
                                    poll.id,
                                    _resolvedSocietyId!,
                                    optionIndex: opt.index,
                                  );
                                  _loadPolls();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        }
                      }),
                      const SizedBox(height: 4),
                      Text(
                        '${poll.totalVotes} total votes cast',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _filterChip(String label, String value, String selectedValue, ValueChanged<String> onSelected) {
    final isSelected = selectedValue == value;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF111827),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFlatAutocompleteSelector({
    required TextEditingController controller,
    required int? selectedHostUserId,
    required SocietyMemberModel? selectedMember,
    required void Function(int? userId, SocietyMemberModel? member) onSelect,
    required StateSetter setModalState,
    String label = 'Destination Flat No. *',
    String hint = 'Type flat (e.g. 402) or resident name...',
  }) {
    final query = controller.text.trim().toLowerCase();
    final hasQuery = query.isNotEmpty && selectedMember == null;
    final matches = hasQuery
        ? _registeredFlatMembers.where((m) {
            final f = (m.flatNo ?? '').toLowerCase();
            final n = m.memberName.toLowerCase();
            final p = m.memberPhone.toLowerCase();
            return f.contains(query) || n.contains(query) || p.contains(query);
          }).take(5).toList()
        : <SocietyMemberModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selectedMember != null ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
              width: selectedMember != null ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Icon(
                  Icons.apartment_rounded,
                  size: 20,
                  color: selectedMember != null ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      if (selectedMember != null && val != selectedMember.flatNo) {
                        onSelect(null, null);
                      }
                    });
                  },
                ),
              ),
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                  onPressed: () {
                    setModalState(() {
                      controller.clear();
                      onSelect(null, null);
                    });
                  },
                ),
              IconButton(
                icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20, color: Color(0xFF2563EB)),
                tooltip: 'Browse All Society Flats',
                onPressed: () {
                  _showFlatsPickerBottomSheet(
                    onSelected: (m) {
                      setModalState(() {
                        controller.text = m.flatNo ?? '';
                        onSelect(m.userId, m);
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),

        // 1. If selected, show verified badge
        if (selectedMember != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, size: 16, color: Color(0xFF059669)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Linked to: ${selectedMember.memberName} (${selectedMember.flatNo ?? ""}) • Push notification active',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],

        // 2. Dropdown suggestions if typing
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1D5DB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: matches.length,
              separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (ctx, i) {
                final m = matches[i];
                return InkWell(
                  onTap: () {
                    setModalState(() {
                      controller.text = m.flatNo ?? '';
                      onSelect(m.userId, m);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.apartment, size: 12, color: Color(0xFF2563EB)),
                              const SizedBox(width: 4),
                              Text(
                                m.flatNo ?? '',
                                style: const TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    m.memberName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF111827)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (m.isPending) ...[
                                    const SizedBox(width: 4),
                                    const Text('(Pending)', style: TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                                  ],
                                ],
                              ),
                              if (m.memberPhone.isNotEmpty)
                                Text(
                                  m.memberPhone,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _showFlatsPickerBottomSheet({required Function(SocietyMemberModel member) onSelected}) {
    final searchCtrl = TextEditingController();
    String query = '';
    bool isReloading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setPickerState) {
          final allFlats = _registeredFlatMembers;
          final filtered = query.isEmpty
              ? allFlats
              : allFlats.where((m) {
                  final f = (m.flatNo ?? '').toLowerCase();
                  final n = m.memberName.toLowerCase();
                  final p = m.memberPhone.toLowerCase();
                  return f.contains(query) || n.contains(query) || p.contains(query);
                }).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Select Society Flat / Resident',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${allFlats.length} flats',
                            style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: searchCtrl,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search by flat number (e.g. 402) or resident name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setPickerState(() {
                                searchCtrl.clear();
                                query = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  onChanged: (val) {
                    setPickerState(() => query = val.trim().toLowerCase());
                  },
                ),
                const SizedBox(height: 12),

                // Custom Flat quick-select when typing
                if (query.isNotEmpty) ...[
                  InkWell(
                    onTap: () {
                      final customFlat = searchCtrl.text.trim();
                      Navigator.pop(ctx);
                      onSelected(
                        SocietyMemberModel(
                          id: 0,
                          societyId: _resolvedSocietyId ?? 0,
                          userId: 0,
                          flatNo: customFlat,
                          role: 'resident',
                          status: 'active',
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_home_work_rounded, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Use Flat: "${searchCtrl.text.trim()}"',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E40AF)),
                                ),
                                const Text(
                                  'Select this flat directly (unlisted/custom flat)',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                ],

                Expanded(
                  child: isReloading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.apartment_outlined, size: 48, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text(
                                    allFlats.isEmpty
                                        ? 'No registered flats loaded in society.'
                                        : 'No matching flat or resident found for "$query".',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                                    label: const Text('Reload Society Flats', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    onPressed: () async {
                                      if (_resolvedSocietyId == null) return;
                                      setPickerState(() => isReloading = true);
                                      try {
                                        final res = await _societyService.getMembers(_resolvedSocietyId!, limit: 100);
                                        setState(() {
                                          _societyMembers = res.data;
                                        });
                                      } catch (e) {
                                        debugPrint('Error reloading members: $e');
                                      } finally {
                                        setPickerState(() => isReloading = false);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (c, i) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              itemBuilder: (context, i) {
                                final m = filtered[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  leading: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      m.flatNo ?? '',
                                      style: const TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m.memberName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (m.isPending) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                          ),
                                          child: const Text(
                                            'Pending Approval',
                                            style: TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ] else if (m.isAdmin) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF2FF),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFC7D2FE)),
                                          ),
                                          child: const Text(
                                            'Admin',
                                            style: TextStyle(color: Color(0xFF4338CA), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    m.memberPhone.isNotEmpty ? '${m.memberPhone} • ${m.role.toUpperCase()}' : m.role.toUpperCase(),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onSelected(m);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _modalField(String label, String hint, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF111827))),
          ),
        ),
      ],
    );
  }

  Widget _datePickerField(
    BuildContext context,
    String label,
    String hint,
    TextEditingController controller, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    VoidCallback? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            DateTime defaultInitial = initialDate ?? now;
            if (controller.text.trim().isNotEmpty) {
              final parsed = DateTime.tryParse(controller.text.trim());
              if (parsed != null) defaultInitial = parsed;
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: defaultInitial,
              firstDate: firstDate ?? DateTime(1940),
              lastDate: lastDate ?? DateTime(2050),
              builder: (ctx, child) {
                return Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFFFF6B00),
                      onPrimary: Colors.white,
                      onSurface: Color(0xFF111827),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              final formatted = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              controller.text = formatted;
              if (onChanged != null) onChanged();
            }
          },
          child: IgnorePointer(
            child: TextField(
              controller: controller,
              readOnly: true,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                suffixIcon: const Icon(Icons.calendar_month_outlined, color: Color(0xFFFF6B00), size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF6B00))),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
