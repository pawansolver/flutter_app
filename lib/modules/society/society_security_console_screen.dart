import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/society_service.dart';
import '../../models/society_models.dart';
import 'society_committee_builder_screen.dart';

class SocietySecurityConsoleScreen extends StatefulWidget {
  final int societyId;
  final String userRole; // 'admin' | 'committee' | 'security' | 'staff'

  final int initialTab;

  const SocietySecurityConsoleScreen({
    super.key,
    required this.societyId,
    required this.userRole,
    this.initialTab = 0,
  });

  @override
  State<SocietySecurityConsoleScreen> createState() => _SocietySecurityConsoleScreenState();
}

class _SocietySecurityConsoleScreenState extends State<SocietySecurityConsoleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocietyService _societyService = SocietyService();

  bool _isLoading = true;

  // Data
  SocietySecurityMetricsModel _metrics = const SocietySecurityMetricsModel();
  List<SocietyVisitorModel> _visitors = [];
  List<SocietyGuardAuthorizationModel> _guards = [];
  List<SocietyGateModel> _gates = [];
  List<SocietyShiftModel> _shifts = [];
  List<SocietyCommitteeModel> _committees = [];
  List<Map<String, dynamic>> _auditLogs = [];
  Map<String, dynamic> _reports = {};
  List<SocietyMemberModel> _societyMembers = [];

  List<SocietyMemberModel> get _registeredFlatMembers {
    final seen = <String>{};
    return _societyMembers.where((m) {
      final f = (m.flatNo ?? '').trim();
      if (f.isEmpty) return false;
      final key = '$f-${m.userId}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  // Visitor Management State
  final TextEditingController _visitorSearchController = TextEditingController();
  String _visitorSearchQuery = '';
  String _visitorStatusFilter = 'all'; // 'all', 'at_gate', 'checked_in', 'expected', 'checked_out'
  String _visitorTypeFilter = 'all'; // 'all', 'guest', 'delivery', 'cab', 'service', 'vendor', 'domestic_worker'

  // Gate Command Center State
  final TextEditingController _gateSearchController = TextEditingController();
  String _gateSearchQuery = '';
  String _gateTypeFilter = 'all'; // 'all', 'main', 'pedestrian', 'service', 'emergency'
  String _gateStatusFilter = 'all'; // 'all', 'active', 'restricted', 'maintenance'
  String _securityThreatLevel = 'normal'; // 'normal', 'heightened', 'lockdown'

  bool get _isAdmin => widget.userRole.toLowerCase() == 'admin' || widget.userRole.toLowerCase() == 'owner';
  bool get _canManageCommittees => _isAdmin || widget.userRole.toLowerCase() == 'committee';

  @override
  void initState() {
    super.initState();
    // 9 tabs for Admin, or 6 tabs for Committee (including Committees), or 5 tabs
    final tabCount = _isAdmin ? 9 : (_canManageCommittees ? 6 : 5);
    final startIndex = (widget.initialTab >= 0 && widget.initialTab < tabCount) ? widget.initialTab : 0;
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: startIndex);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final socId = widget.societyId;

      final results = await Future.wait<dynamic>([
        _societyService.getSecurityDashboard(socId).catchError((_) => const SocietySecurityMetricsModel()),
        _societyService.getVisitors(socId, limit: 50).then((res) => res.data).catchError((_) => <SocietyVisitorModel>[]),
        _societyService.getGuards(socId).catchError((_) => <SocietyGuardAuthorizationModel>[]),
        _societyService.getGates(socId).catchError((_) => <SocietyGateModel>[]),
        _societyService.getShifts(socId).catchError((_) => <SocietyShiftModel>[]),
        if (_canManageCommittees)
          _societyService.getCommittees(socId).catchError((_) => <SocietyCommitteeModel>[])
        else
          Future.value(<SocietyCommitteeModel>[]),
        if (_isAdmin)
          _societyService.getSecurityReports(socId).catchError((_) => <String, dynamic>{})
        else
          Future.value(<String, dynamic>{}),
        if (_isAdmin)
          _societyService.getSecurityAuditLogs(socId).catchError((_) => <Map<String, dynamic>>[])
        else
          Future.value(<Map<String, dynamic>>[]),
        _societyService.getMembers(socId, limit: 100).then((res) => res.data).catchError((_) => <SocietyMemberModel>[]),
      ]);

      if (mounted) {
        setState(() {
          _metrics = results[0] as SocietySecurityMetricsModel;
          _visitors = results[1] as List<SocietyVisitorModel>;
          _guards = results[2] as List<SocietyGuardAuthorizationModel>;
          _gates = results[3] as List<SocietyGateModel>;
          _shifts = results[4] as List<SocietyShiftModel>;
          _committees = results[5] as List<SocietyCommitteeModel>;
          _reports = results[6] as Map<String, dynamic>;
          _auditLogs = results[7] as List<Map<String, dynamic>>;
          _societyMembers = results[8] as List<SocietyMemberModel>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _visitorSearchController.dispose();
    _gateSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Security & Visitor Console',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              _isAdmin ? 'Society Admin • Full Oversight' : 'Security Committee • Operational Console',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFFFF6B00),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor: const Color(0xFF9CA3AF),
          onTap: (index) {
            _tabController.animateTo(index);
          },
          tabs: [
            const Tab(text: 'Overview', icon: Icon(Icons.dashboard_outlined, size: 18)),
            const Tab(text: 'Visitors', icon: Icon(Icons.people_outline, size: 18)),
            const Tab(text: 'Guards', icon: Icon(Icons.security, size: 18)),
            const Tab(text: 'Gates', icon: Icon(Icons.door_front_door_outlined, size: 18)),
            const Tab(text: 'Shifts', icon: Icon(Icons.schedule, size: 18)),
            if (_canManageCommittees)
              const Tab(text: 'Committees', icon: Icon(Icons.groups_3_outlined, size: 18)),
            if (_isAdmin) ...[
              const Tab(text: 'Permissions', icon: Icon(Icons.key_outlined, size: 18)),
              const Tab(text: 'Reports', icon: Icon(Icons.analytics_outlined, size: 18)),
              const Tab(text: 'Audit Logs', icon: Icon(Icons.history, size: 18)),
            ],
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildVisitorsTab(),
                _buildGuardsTab(),
                _buildGatesTab(),
                _buildShiftsTab(),
                if (_canManageCommittees)
                  _buildCommitteesTab(),
                if (_isAdmin) ...[
                  _buildPermissionsTab(),
                  _buildReportsTab(),
                  _buildAuditLogsTab(),
                ],
              ],
            ),
    );
  }

  // ─── TAB 1: OVERVIEW ───────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Action Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.white),
                  label: const Text('Onboard Guard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  backgroundColor: const Color(0xFFFF6B00),
                  onPressed: _showOnboardGuardDialog,
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.security, size: 16, color: Color(0xFF10B981)),
                  label: Text('Guards (${_guards.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  onPressed: () => _tabController.animateTo(2),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.people_outline, size: 16, color: Color(0xFF2563EB)),
                  label: Text('Visitors (${_visitors.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  onPressed: () => _tabController.animateTo(1),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.door_front_door_outlined, size: 16, color: Color(0xFF8B5CF6)),
                  label: Text('Gates (${_gates.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  onPressed: () => _tabController.animateTo(3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricsGrid(),
          const SizedBox(height: 20),

          // Guards On Duty Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Guards On Duty (${_guards.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(2),
                child: const Text('View All', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_guards.isEmpty)
            _buildEmptyCard('No security guards onboarded yet.')
          else
            ..._guards.take(3).map(_buildGuardMiniCard),

          const SizedBox(height: 20),

          // Recent Visitors Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Gate Visitors (${_visitors.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                child: const Text('View All', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_visitors.isEmpty)
            _buildEmptyCard('No recent visitor activities logged yet.')
          else
            ..._visitors.take(5).map(_buildVisitorMiniCard),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _metricTile(
          'Guards On Duty',
          _metrics.guardsOnDuty.toString(),
          Icons.shield,
          const Color(0xFF10B981),
          onTap: () => _tabController.animateTo(2),
        ),
        _metricTile(
          'Visitors At Gate',
          _metrics.visitorsAtGate.toString(),
          Icons.doorbell_outlined,
          const Color(0xFFFF6B00),
          onTap: () => _tabController.animateTo(1),
        ),
        _metricTile(
          'Checked In Now',
          _metrics.checkedIn.toString(),
          Icons.login,
          const Color(0xFF2563EB),
          onTap: () => _tabController.animateTo(1),
        ),
        _metricTile(
          'Pending Approvals',
          _metrics.pendingApprovals.toString(),
          Icons.pending_actions,
          const Color(0xFFF59E0B),
          onTap: () => _tabController.animateTo(1),
        ),
        _metricTile(
          'Expected Visitors',
          _metrics.expectedVisitors.toString(),
          Icons.event_available,
          const Color(0xFF8B5CF6),
          onTap: () => _tabController.animateTo(1),
        ),
        _metricTile(
          'Checked Out Today',
          _metrics.checkedOutToday.toString(),
          Icons.logout,
          const Color(0xFF6B7280),
          onTap: () => _tabController.animateTo(1),
        ),
      ],
    );
  }

  Widget _metricTile(String title, String count, IconData icon, Color color, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(count, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 10, color: color.withValues(alpha: 0.7)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuardMiniCard(SocietyGuardAuthorizationModel g) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () => _showGuardDetailSheet(g),
        leading: CircleAvatar(
          backgroundColor: g.isActive ? const Color(0xFF10B981) : Colors.grey,
          backgroundImage: (g.profilePhotoUrl != null && g.profilePhotoUrl!.isNotEmpty)
              ? NetworkImage(g.profilePhotoUrl!)
              : null,
          child: (g.profilePhotoUrl == null || g.profilePhotoUrl!.isEmpty)
              ? const Icon(Icons.security, color: Colors.white, size: 20)
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                g.userName ?? 'Guard #${g.userId}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _verificationBadge(g.verificationStatus),
          ],
        ),
        subtitle: Text(
          '${g.designation} • ${g.phone ?? "No phone"}\nGate: ${g.gateName ?? "Unassigned"} • Shift: ${g.shiftName ?? "Unassigned"}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
      ),
    );
  }

  Widget _buildVisitorMiniCard(SocietyVisitorModel v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () => _tabController.animateTo(1),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF111827),
          child: Text(
            v.visitorName.isNotEmpty ? v.visitorName[0].toUpperCase() : 'V',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(v.visitorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('Flat ${v.flatNo ?? 'N/A'} • ${v.visitorType.toUpperCase()} • ${v.purpose ?? 'Visit'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        trailing: _statusChip(v.status),
      ),
    );
  }

  // ─── TAB 2: VISITORS (ENTERPRISE VISITOR MANAGEMENT CONSOLE) ──────────────
  Widget _buildVisitorsTab() {
    final filteredVisitors = _visitors.where((v) {
      if (_visitorStatusFilter != 'all' && v.status.toLowerCase() != _visitorStatusFilter) return false;
      if (_visitorTypeFilter != 'all' && v.visitorType.toLowerCase() != _visitorTypeFilter) return false;
      if (_visitorSearchQuery.isNotEmpty) {
        final q = _visitorSearchQuery.toLowerCase();
        final name = v.visitorName.toLowerCase();
        final flat = (v.flatNo ?? '').toLowerCase();
        final phone = (v.visitorPhone ?? '').toLowerCase();
        final company = (v.companyName ?? '').toLowerCase();
        final vehicle = (v.vehicleNo ?? '').toLowerCase();
        final cab = (v.cabNumber ?? '').toLowerCase();
        final driver = (v.driverName ?? '').toLowerCase();
        if (!name.contains(q) &&
            !flat.contains(q) &&
            !phone.contains(q) &&
            !company.contains(q) &&
            !vehicle.contains(q) &&
            !cab.contains(q) &&
            !driver.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    final atGateCount = _visitors.where((v) => v.status.toLowerCase() == 'at_gate').length;
    final checkedInCount = _visitors.where((v) => v.status.toLowerCase() == 'checked_in').length;
    final expectedCount = _visitors.where((v) => v.status.toLowerCase() == 'expected').length;
    final checkedOutCount = _visitors.where((v) => v.status.toLowerCase() == 'checked_out').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: filteredVisitors.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFF6B00),
              elevation: 3,
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: const Text('Log Visitor Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _showCreateVisitorModal(isGateEntry: true),
            ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            // 1. Enterprise KPI Ribbon
            _buildVisitorKpiRibbon(atGateCount, checkedInCount, expectedCount, checkedOutCount),
            const SizedBox(height: 12),

            // 2. Enterprise Search Bar
            _buildVisitorSearchBar(),
            const SizedBox(height: 10),

            // 3. Status Filters (All, At Gate, Checked In, Expected, Checked Out)
            _buildVisitorStatusChips(atGateCount, checkedInCount, expectedCount, checkedOutCount),
            const SizedBox(height: 8),

            // 4. Type Filters (Guest, Delivery, Cab, Service, Vendor)
            _buildVisitorTypeChips(),
            const SizedBox(height: 12),

            // 5. Header: Total Count & Pre-Approve Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredVisitors.length} ${_visitorStatusFilter == "all" ? "Total" : _visitorStatusFilter.replaceAll("_", " ").toUpperCase()} Records',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                ),
                TextButton.icon(
                  onPressed: () => _showCreateVisitorModal(isGateEntry: false),
                  icon: const Icon(Icons.how_to_reg_outlined, size: 16, color: Color(0xFF2563EB)),
                  label: const Text('Pre-Approve Guest', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 6. List or Enterprise Empty State
            if (filteredVisitors.isEmpty)
              _buildEnterpriseVisitorEmptyState()
            else
              ...filteredVisitors.map(_buildEnterpriseVisitorCard),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorKpiRibbon(int atGate, int checkedIn, int expected, int checkedOut) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _visitorMiniKpi('At Gate', atGate.toString(), Icons.doorbell_outlined, const Color(0xFFFF6B00), 'at_gate'),
          const SizedBox(width: 8),
          _visitorMiniKpi('Checked In', checkedIn.toString(), Icons.login, const Color(0xFF10B981), 'checked_in'),
          const SizedBox(width: 8),
          _visitorMiniKpi('Expected', expected.toString(), Icons.event_available, const Color(0xFF8B5CF6), 'expected'),
          const SizedBox(width: 8),
          _visitorMiniKpi('Checked Out', checkedOut.toString(), Icons.logout, const Color(0xFF6B7280), 'checked_out'),
        ],
      ),
    );
  }

  Widget _visitorMiniKpi(String label, String count, IconData icon, Color color, String filterKey) {
    final isSelected = _visitorStatusFilter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          _visitorStatusFilter = isSelected ? 'all' : filterKey;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: const Color(0xFF374151))),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(count, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitorSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: _visitorSearchController,
        decoration: InputDecoration(
          hintText: 'Search visitor, flat, cab, delivery, phone...',
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
          suffixIcon: _visitorSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                  onPressed: () {
                    _visitorSearchController.clear();
                    setState(() => _visitorSearchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (val) => setState(() => _visitorSearchQuery = val.trim()),
      ),
    );
  }

  Widget _buildVisitorStatusChips(int atGate, int checkedIn, int expected, int checkedOut) {
    Widget chip(String label, String key, int count, Color color) {
      final isSelected = _visitorStatusFilter == key;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          selected: isSelected,
          label: Text('$label ($count)'),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
          backgroundColor: Colors.white,
          selectedColor: color,
          checkmarkColor: Colors.white,
          side: BorderSide(color: isSelected ? color : const Color(0xFFE5E7EB)),
          onSelected: (_) => setState(() => _visitorStatusFilter = key),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', 'all', _visitors.length, const Color(0xFF111827)),
          chip('At Gate', 'at_gate', atGate, const Color(0xFFFF6B00)),
          chip('Checked In', 'checked_in', checkedIn, const Color(0xFF10B981)),
          chip('Expected', 'expected', expected, const Color(0xFF8B5CF6)),
          chip('Checked Out', 'checked_out', checkedOut, const Color(0xFF6B7280)),
        ],
      ),
    );
  }

  Widget _buildVisitorTypeChips() {
    Widget typeChip(String label, String key, IconData icon) {
      final isSelected = _visitorTypeFilter == key;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          selected: isSelected,
          avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF6B7280)),
          label: Text(label),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
          selectedColor: const Color(0xFF2563EB),
          backgroundColor: Colors.white,
          side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB)),
          onSelected: (sel) => setState(() => _visitorTypeFilter = sel ? key : 'all'),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          typeChip('All Types', 'all', Icons.apps),
          typeChip('Guest', 'guest', Icons.person),
          typeChip('Delivery', 'delivery', Icons.local_shipping),
          typeChip('Cab / Ride', 'cab', Icons.local_taxi),
          typeChip('Service', 'service', Icons.handyman),
          typeChip('Vendor', 'vendor', Icons.storefront),
          typeChip('Domestic', 'domestic_worker', Icons.home_repair_service),
        ],
      ),
    );
  }

  Widget _buildEnterpriseVisitorEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, size: 48, color: Color(0xFFFF6B00)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Visitor Activity Found',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Real-time gate check-ins, delivery drops, cab pickups, and visitor approvals will appear here with instant audit tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Log Gate Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              onPressed: () => _showCreateVisitorModal(isGateEntry: true),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.how_to_reg_outlined, size: 18),
              label: const Text('Pre-Approve Guest', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              onPressed: () => _showCreateVisitorModal(isGateEntry: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterpriseVisitorCard(SocietyVisitorModel v) {
    Color typeColor = const Color(0xFF2563EB); // Guest
    IconData typeIcon = Icons.person;
    if (v.visitorType == 'delivery') {
      typeColor = const Color(0xFFFF6B00);
      typeIcon = Icons.local_shipping;
    } else if (v.visitorType == 'cab') {
      typeColor = const Color(0xFFF59E0B);
      typeIcon = Icons.local_taxi;
    } else if (v.visitorType == 'service') {
      typeColor = const Color(0xFF8B5CF6);
      typeIcon = Icons.handyman;
    } else if (v.visitorType == 'vendor') {
      typeColor = const Color(0xFF10B981);
      typeIcon = Icons.storefront;
    } else if (v.visitorType == 'domestic_worker') {
      typeColor = const Color(0xFFEC4899);
      typeIcon = Icons.home_repair_service;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showVisitorDetailSheet(v),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Name + Type Tag + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: typeColor.withValues(alpha: 0.15),
                    child: Icon(typeIcon, color: typeColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                v.visitorName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111827)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                v.visitorType.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 3,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.home_outlined, size: 13, color: Color(0xFF6B7280)),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Text(
                                    'Flat ${v.flatNo ?? "N/A"}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (v.visitorPhone != null && v.visitorPhone!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 3),
                                  Text(
                                    v.visitorPhone!,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _statusChip(v.status),
                ],
              ),

              // Dynamic contextual metadata
              if (v.visitorType == 'delivery' && v.companyName != null && v.companyName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.delivery_dining, size: 16, color: Color(0xFFFF6B00)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Delivery: ${v.companyName}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (v.vehicleNo != null && v.vehicleNo!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          v.vehicleNo!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              if (v.visitorType == 'cab' && (v.cabNumber != null || v.driverName != null)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_taxi, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Driver: ${v.driverName ?? "Driver"}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        v.cabNumber ?? v.vehicleNo ?? '',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ),
              ],

              if (v.visitorType == 'service' && v.serviceCategory != null && v.serviceCategory!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.construction, size: 15, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Service: ${v.serviceCategory}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (v.companyName != null && v.companyName!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(v.companyName!, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                      ],
                    ],
                  ),
                ),
              ],

              // Footer: Gate / Guard attribution & Quick Action Buttons
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.door_front_door_outlined, size: 13, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 3),
                      Text(
                        v.gateId != null ? 'Gate #${v.gateId}' : 'Main Gate',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                      if (v.checkInTime != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time, size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 3),
                        Text(
                          '${v.checkInTime!.hour.toString().padLeft(2, '0')}:${v.checkInTime!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ],
                  ),

                  // Action Buttons
                  Row(
                    children: [
                      if (v.status.toLowerCase() == 'at_gate' || v.status.toLowerCase() == 'expected' || v.status.toLowerCase() == 'approved') ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.login, size: 14),
                          label: const Text('Check In'),
                          onPressed: () async {
                            await _societyService.updateVisitorStatus(v.id, widget.societyId, status: 'checked_in');
                            _loadAllData();
                          },
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFFCA5A5)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Deny'),
                          onPressed: () async {
                            await _societyService.updateVisitorStatus(v.id, widget.societyId, status: 'rejected');
                            _loadAllData();
                          },
                        ),
                      ] else if (v.status.toLowerCase() == 'checked_in') ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF374151),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.logout, size: 14),
                          label: const Text('Check Out'),
                          onPressed: () async {
                            await _societyService.updateVisitorStatus(v.id, widget.societyId, status: 'checked_out');
                            _loadAllData();
                          },
                        ),
                      ],
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 20),
                        onPressed: () => _showVisitorDetailSheet(v),
                        tooltip: 'View Details',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── VISITOR CREATION MODAL (DYNAMIC ENTERPRISE FORM) ─────────────────────
  void _showCreateVisitorModal({bool isGateEntry = true}) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final flatCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final driverNameCtrl = TextEditingController();
    final cabNumberCtrl = TextEditingController();
    final serviceCategoryCtrl = TextEditingController();
    final workerTypeCtrl = TextEditingController();
    final vehicleNoCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();

    String visitorType = 'guest';
    String vehicleType = 'none';
    String entryType = 'walk_in';
    int? selectedGateId = _gates.isNotEmpty ? _gates.first.id : null;
    int? selectedHostUserId;
    SocietyMemberModel? selectedMember;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isGateEntry ? Icons.doorbell_outlined : Icons.how_to_reg_outlined,
                            color: isGateEntry ? const Color(0xFFFF6B00) : const Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isGateEntry ? 'Log Live Gate Entry' : 'Pre-Approve Visitor',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    isGateEntry
                        ? 'Log a live walk-in, cab, delivery, or contractor entering the gate.'
                        : 'Schedule an expected guest or visitor pass ahead of time.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 16),

                  // Visitor Type Selector
                  const Text('Visitor Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: visitorType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'guest', child: Text('👤 Guest / Relative', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'delivery', child: Text('📦 Delivery Partner (Swiggy/Amazon)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'cab', child: Text('🚕 Cab / Ride (Uber/Ola)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'service', child: Text('🔧 Service Provider (Electrician/Plumber)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'vendor', child: Text('🏪 Society Vendor / Contractor', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'domestic_worker', child: Text('🧹 Domestic Worker / Staff', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'other', child: Text('📝 Other / Official', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          visitorType = val;
                          if (val == 'delivery' || val == 'cab') {
                            entryType = 'vehicle';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Basic Details
                  _modalField('Visitor Full Name *', 'Enter visitor name', nameCtrl),
                  const SizedBox(height: 12),
                  _modalField('Mobile Number', 'e.g. 9876543210', phoneCtrl, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildFlatAutocompleteSelector(
                    controller: flatCtrl,
                    selectedHostUserId: selectedHostUserId,
                    selectedMember: selectedMember,
                    onSelect: (uId, mem) {
                      selectedHostUserId = uId;
                      selectedMember = mem;
                    },
                    setModalState: setSheetState,
                    label: 'Host Flat / Unit *',
                  ),
                  const SizedBox(height: 12),

                  // Conditional Form Sections
                  if (visitorType == 'guest') ...[
                    _modalField('Purpose of Visit', 'e.g. Casual visit, Dinner', purposeCtrl),
                    const SizedBox(height: 12),
                  ],

                  if (visitorType == 'delivery') ...[
                    _modalField('Delivery Company *', 'e.g. Swiggy, Zomato, Amazon, Blinkit', companyCtrl),
                    const SizedBox(height: 12),
                    _modalField('Delivery Vehicle No (Optional)', 'e.g. MH 12 AB 1234', vehicleNoCtrl),
                    const SizedBox(height: 12),
                  ],

                  if (visitorType == 'cab') ...[
                    _modalField('Driver Name', 'e.g. Suresh Kumar', driverNameCtrl),
                    const SizedBox(height: 12),
                    _modalField('Cab / Vehicle Number *', 'e.g. DL 01 AB 9999', cabNumberCtrl),
                    const SizedBox(height: 12),
                  ],

                  if (visitorType == 'service') ...[
                    _modalField('Service Category *', 'e.g. Electrician, AC Repair, Plumbing', serviceCategoryCtrl),
                    const SizedBox(height: 12),
                    _modalField('Company / Agency Name', 'e.g. Urban Company', companyCtrl),
                    const SizedBox(height: 12),
                  ],

                  if (visitorType == 'vendor') ...[
                    _modalField('Vendor Company / Business *', 'e.g. Reliable Water Supplier', companyCtrl),
                    const SizedBox(height: 12),
                    _modalField('Purpose of Work', 'e.g. Water tank cleaning', purposeCtrl),
                    const SizedBox(height: 12),
                  ],

                  if (visitorType == 'domestic_worker') ...[
                    _modalField('Worker Type *', 'e.g. Maid, Cook, Driver', workerTypeCtrl),
                    const SizedBox(height: 12),
                  ],

                  if (visitorType == 'other') ...[
                    _modalField('Purpose *', 'e.g. Inspection, Courier drop', purposeCtrl),
                    const SizedBox(height: 12),
                    _modalField('Remarks', 'Any additional notes', remarksCtrl),
                    const SizedBox(height: 12),
                  ],

                  // Gate Selection
                  if (_gates.isNotEmpty) ...[
                    const Text('Entry Gate *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedGateId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _gates
                          .map((g) => DropdownMenuItem(
                                value: g.id,
                                child: Text(g.gateName, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) => setSheetState(() => selectedGateId = val),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isGateEntry ? const Color(0xFFFF6B00) : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Visitor Name is required')),
                                );
                                return;
                              }
                              setSheetState(() => isSubmitting = true);
                              try {
                                await _societyService.createVisitor(
                                  widget.societyId,
                                  visitorName: name,
                                  visitorPhone: phoneCtrl.text.trim(),
                                  flatNo: flatCtrl.text.trim(),
                                  userId: selectedHostUserId,
                                  purpose: purposeCtrl.text.trim(),
                                  status: isGateEntry ? 'at_gate' : 'expected',
                                  visitorType: visitorType,
                                  companyName: companyCtrl.text.trim(),
                                  driverName: driverNameCtrl.text.trim(),
                                  cabNumber: cabNumberCtrl.text.trim(),
                                  serviceCategory: serviceCategoryCtrl.text.trim(),
                                  workerType: workerTypeCtrl.text.trim(),
                                  vehicleNo: vehicleNoCtrl.text.trim().isNotEmpty
                                      ? vehicleNoCtrl.text.trim()
                                      : cabNumberCtrl.text.trim(),
                                  vehicleNumber: vehicleNoCtrl.text.trim().isNotEmpty
                                      ? vehicleNoCtrl.text.trim()
                                      : cabNumberCtrl.text.trim(),
                                  vehicleType: vehicleType,
                                  entryType: entryType,
                                  gateId: selectedGateId,
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadAllData();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isGateEntry
                                            ? 'Live gate entry logged! Resident notified.'
                                            : 'Visitor pre-approved successfully!',
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to log visitor: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              isGateEntry ? 'Submit Gate Entry' : 'Create Pre-Approved Pass',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── VISITOR DETAIL INSPECTION SHEET ───────────────────────────────────────
  void _showVisitorDetailSheet(SocietyVisitorModel v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget rowItem(String label, String value) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Visitor Pass #${v.id}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    _statusChip(v.status),
                  ],
                ),
                const SizedBox(height: 16),

                // Visitor Header Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF111827),
                        child: Text(
                          v.visitorName.isNotEmpty ? v.visitorName[0].toUpperCase() : 'V',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.visitorName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              '${v.visitorType.replaceAll("_", " ").toUpperCase()} • Flat ${v.flatNo ?? "N/A"}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Details Breakdown
                const Text('Visitor Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const Divider(height: 16),
                rowItem('Mobile Number', v.visitorPhone ?? 'N/A'),
                rowItem('Host Flat', v.flatNo ?? 'N/A'),
                rowItem('Purpose', v.purpose ?? 'Visit'),
                if (v.companyName != null && v.companyName!.isNotEmpty)
                  rowItem('Company / Delivery', v.companyName!),
                if (v.driverName != null && v.driverName!.isNotEmpty)
                  rowItem('Driver Name', v.driverName!),
                if (v.cabNumber != null && v.cabNumber!.isNotEmpty)
                  rowItem('Cab Number', v.cabNumber!),
                if (v.vehicleNo != null && v.vehicleNo!.isNotEmpty)
                  rowItem('Vehicle Number', '${v.vehicleNo} (${v.vehicleType})'),
                if (v.serviceCategory != null && v.serviceCategory!.isNotEmpty)
                  rowItem('Service Category', v.serviceCategory!),

                const SizedBox(height: 14),
                const Text('Gate & Audit Attribution', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                const Divider(height: 16),
                rowItem('Gate', v.gateId != null ? 'Gate #${v.gateId}' : 'Main Gate'),
                rowItem('Operator Guard', v.guardId != null ? 'Guard #${v.guardId}' : 'System Log'),
                rowItem('Entry Type', v.entryType),
                if (v.checkInTime != null)
                  rowItem('Check-In Time', v.checkInTime.toString().split('.')[0]),
                if (v.checkOutTime != null)
                  rowItem('Check-Out Time', v.checkOutTime.toString().split('.')[0]),

                const SizedBox(height: 20),
                // Action Buttons
                if (v.status.toLowerCase() == 'at_gate' || v.status.toLowerCase() == 'expected' || v.status.toLowerCase() == 'approved') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.block, size: 18),
                          label: const Text('Deny Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _societyService.updateVisitorStatus(v.id, widget.societyId, status: 'denied');
                            _loadAllData();
                          },
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
                          icon: const Icon(Icons.login),
                          label: const Text('Check In / Pass Gate', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _societyService.updateVisitorStatus(v.id, widget.societyId, status: 'checked_in');
                            _loadAllData();
                          },
                        ),
                      ),
                    ],
                  ),
                ] else if (v.status.toLowerCase() == 'checked_in') ...[
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
                      label: const Text('Log Check-Out', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _societyService.updateVisitorStatus(v.id, widget.societyId, status: 'checked_out');
                        _loadAllData();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── TAB 3: GUARDS ─────────────────────────────────────────────────────────
  Widget _buildGuardsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF6B00),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('Onboard Guard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showOnboardGuardDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: _guards.isEmpty
            ? _buildEmptyCard('No security guards onboarded yet.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _guards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final g = _guards[i];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showGuardDetailSheet(g),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: g.isActive ? const Color(0xFF10B981) : Colors.grey,
                              backgroundImage: (g.profilePhotoUrl != null && g.profilePhotoUrl!.isNotEmpty)
                                  ? NetworkImage(g.profilePhotoUrl!)
                                  : null,
                              child: (g.profilePhotoUrl == null || g.profilePhotoUrl!.isEmpty)
                                  ? const Icon(Icons.security, color: Colors.white, size: 24)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          g.userName ?? 'Guard #${g.userId}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      _verificationBadge(g.verificationStatus),
                                      const SizedBox(width: 6),
                                      _guardStatusBadge(g.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${g.designation} • ${g.phone ?? "No phone"}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Gate: ${g.gateName ?? "Unassigned"} • Shift: ${g.shiftName ?? "Unassigned"}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
                              onSelected: (val) async {
                                if (val == 'details') {
                                  _showGuardDetailSheet(g);
                                } else if (val == 'edit') {
                                  _showEditGuardDialog(g);
                                } else if (val == 'assign') {
                                  _showAssignGuardDialog(g);
                                } else if (val == 'verify') {
                                  await _societyService.verifyGuard(g.id, widget.societyId);
                                  _loadAllData();
                                } else if (val == 'reject') {
                                  _showRejectVerificationDialog(g);
                                } else if (val == 'activate') {
                                  await _societyService.updateGuardStatus(g.id, widget.societyId, status: 'active');
                                  _loadAllData();
                                } else if (val == 'deactivate') {
                                  await _societyService.updateGuardStatus(g.id, widget.societyId, status: 'inactive');
                                  _loadAllData();
                                } else if (val == 'delete') {
                                  _confirmDeleteGuard(g);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'details',
                                  child: Row(children: [
                                    Icon(Icons.badge_outlined, size: 18, color: Color(0xFF2563EB)),
                                    SizedBox(width: 8),
                                    Text('View Details'),
                                  ]),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit_outlined, size: 18, color: Color(0xFFFF6B00)),
                                    SizedBox(width: 8),
                                    Text('Edit Guard'),
                                  ]),
                                ),
                                const PopupMenuItem(
                                  value: 'assign',
                                  child: Row(children: [
                                    Icon(Icons.schedule, size: 18, color: Color(0xFF10B981)),
                                    SizedBox(width: 8),
                                    Text('Assign Gate & Shift'),
                                  ]),
                                ),
                                if (g.verificationStatus != 'verified')
                                  const PopupMenuItem(
                                    value: 'verify',
                                    child: Row(children: [
                                      Icon(Icons.verified_outlined, size: 18, color: Color(0xFF059669)),
                                      SizedBox(width: 8),
                                      Text('Approve Verification'),
                                    ]),
                                  ),
                                if (g.verificationStatus == 'pending' || g.verificationStatus == 'unverified')
                                  const PopupMenuItem(
                                    value: 'reject',
                                    child: Row(children: [
                                      Icon(Icons.cancel_outlined, size: 18, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('Reject Verification'),
                                    ]),
                                  ),
                                if (g.isActive)
                                  const PopupMenuItem(
                                    value: 'deactivate',
                                    child: Row(children: [
                                      Icon(Icons.block_outlined, size: 18, color: Colors.grey),
                                      SizedBox(width: 8),
                                      Text('Deactivate Guard'),
                                    ]),
                                  )
                                else
                                  const PopupMenuItem(
                                    value: 'activate',
                                    child: Row(children: [
                                      Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF10B981)),
                                      SizedBox(width: 8),
                                      Text('Activate Guard'),
                                    ]),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete Guard', style: TextStyle(color: Colors.red)),
                                  ]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ─── TAB 4: GATES (ENTERPRISE GATE COMMAND & ACCESS CENTER) ────────────────
  List<SocietyGateModel> get _filteredGates {
    return _gates.where((g) {
      if (_gateSearchQuery.isNotEmpty) {
        final q = _gateSearchQuery.toLowerCase();
        final matchName = g.gateName.toLowerCase().contains(q);
        final matchCode = (g.gateCode ?? '').toLowerCase().contains(q);
        final matchLoc = (g.location ?? '').toLowerCase().contains(q);
        if (!matchName && !matchCode && !matchLoc) return false;
      }
      if (_gateTypeFilter != 'all') {
        if (g.gateType.toLowerCase() != _gateTypeFilter.toLowerCase()) return false;
      }
      if (_gateStatusFilter != 'all') {
        if (g.status.toLowerCase() != _gateStatusFilter.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  int _getGateVisitorsCount(int gateId) {
    return _visitors.where((v) => v.gateId == gateId || (v.gate != null && v.gate!['id'] == gateId)).length;
  }

  int _getGateCheckedInCount(int gateId) {
    return _visitors.where((v) => (v.gateId == gateId || (v.gate != null && v.gate!['id'] == gateId)) && v.status.toLowerCase() == 'checked_in').length;
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  String _formatGateType(String type) {
    switch (type.toLowerCase()) {
      case 'main':
      case 'vehicular':
        return 'Vehicular Main';
      case 'pedestrian':
        return 'Pedestrian Walkway';
      case 'service':
        return 'Service & Delivery';
      case 'emergency':
        return 'Emergency Exit';
      case 'back_gate':
        return 'Secondary Gate';
      default:
        return type.toUpperCase();
    }
  }

  IconData _getGateTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'main':
      case 'vehicular':
        return Icons.directions_car_filled_rounded;
      case 'pedestrian':
        return Icons.directions_walk_rounded;
      case 'service':
        return Icons.local_shipping_rounded;
      case 'emergency':
        return Icons.emergency_rounded;
      case 'back_gate':
        return Icons.sensor_door_outlined;
      default:
        return Icons.door_front_door_outlined;
    }
  }

  LinearGradient _getGateTypeGradient(String type) {
    switch (type.toLowerCase()) {
      case 'main':
      case 'vehicular':
        return const LinearGradient(colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'pedestrian':
        return const LinearGradient(colors: [Color(0xFF065F46), Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'service':
        return const LinearGradient(colors: [Color(0xFF92400E), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'emergency':
        return const LinearGradient(colors: [Color(0xFF991B1B), Color(0xFFEF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      default:
        return const LinearGradient(colors: [Color(0xFF374151), Color(0xFF6B7280)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
  }

  Widget _buildGatesTab() {
    final filtered = _filteredGates;
    final totalGuards = _gates.fold<int>(0, (sum, g) => sum + g.activeGuards.length);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F172A),
        icon: const Icon(Icons.add_moderator_rounded, color: Colors.white, size: 20),
        label: const Text('Add Checkpoint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
        onPressed: _showAddGateDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            // Threat Protocol Banner
            _buildThreatProtocolBanner(),
            const SizedBox(height: 14),

            // Enterprise KPI Metrics Strip
            _buildGateMetricsStrip(totalGuards),
            const SizedBox(height: 16),

            // Search and Filter Bar
            _buildGateSearchAndFilterBar(),
            const SizedBox(height: 14),

            // Checkpoint Header with Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF475569)),
                    const SizedBox(width: 6),
                    Text(
                      'PERIMETER CHECKPOINTS (${filtered.length}/${_gates.length})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5),
                    ),
                  ],
                ),
                if (_gateSearchQuery.isNotEmpty || _gateTypeFilter != 'all' || _gateStatusFilter != 'all')
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _gateSearchQuery = '';
                        _gateSearchController.clear();
                        _gateTypeFilter = 'all';
                        _gateStatusFilter = 'all';
                      });
                    },
                    child: const Text(
                      'Clear Filters',
                      style: TextStyle(fontSize: 12, color: Color(0xFFFF6B00), fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Checkpoints List
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    const Text(
                      'No matching checkpoints found',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Try changing your filter settings or search query.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Filters'),
                      onPressed: () {
                        setState(() {
                          _gateSearchQuery = '';
                          _gateSearchController.clear();
                          _gateTypeFilter = 'all';
                          _gateStatusFilter = 'all';
                        });
                      },
                    ),
                  ],
                ),
              )
            else
              ...filtered.map((gate) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildEnterpriseGateCard(gate),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildThreatProtocolBanner() {
    Color bannerBg;
    Color borderColor;
    Color badgeBg;
    Color badgeFg;
    IconData icon;
    String title;
    String desc;

    if (_securityThreatLevel == 'lockdown') {
      bannerBg = const Color(0xFF7F1D1D);
      borderColor = const Color(0xFFDC2626);
      badgeBg = const Color(0xFF991B1B);
      badgeFg = const Color(0xFFFEE2E2);
      icon = Icons.lock_clock_rounded;
      title = 'DEFENSE POSTURE: LEVEL 3 (PERIMETER LOCKDOWN)';
      desc = 'Emergency Protocol Active • Automated barriers locked • Manual pass verification only.';
    } else if (_securityThreatLevel == 'heightened') {
      bannerBg = const Color(0xFF78350F);
      borderColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFF92400E);
      badgeFg = const Color(0xFFFEF3C7);
      icon = Icons.warning_rounded;
      title = 'DEFENSE POSTURE: LEVEL 2 (ELEVATED VIGILANCE)';
      desc = 'Mandatory physical ID check & vehicle boot inspection • Strict pre-approved entry.';
    } else {
      bannerBg = const Color(0xFF0F172A);
      borderColor = const Color(0xFF1E293B);
      badgeBg = const Color(0xFF064E3B);
      badgeFg = const Color(0xFFA7F3D0);
      icon = Icons.verified_user_rounded;
      title = 'DEFENSE POSTURE: LEVEL 1 (NORMAL OPERATIONS)';
      desc = 'Perimeter Secure • Automated barriers & QR FastPass active • Standard visitor screening.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: badgeFg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showSecurityProtocolSheet,
                child: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFFE2E8F0), height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildGateMetricsStrip(int totalGuards) {
    final activeCount = _gates.where((g) => g.status.toLowerCase() == 'active').length;
    final totalVisitorsToday = _visitors.length;
    final checkedInCount = _visitors.where((v) => v.status.toLowerCase() == 'checked_in').length;

    return Row(
      children: [
        Expanded(
          child: _buildGateMetricCard(
            icon: Icons.door_front_door_rounded,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFEFF6FF),
            value: '$activeCount/${_gates.length}',
            label: 'Checkpoints',
            subtext: '${_gates.isNotEmpty ? ((activeCount / _gates.length) * 100).round() : 100}% Online',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGateMetricCard(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFECFDF5),
            value: '$totalGuards',
            label: 'Guards on Duty',
            subtext: 'Station Roster',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGateMetricCard(
            icon: Icons.traffic_rounded,
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFFFFBEB),
            value: '$totalVisitorsToday',
            label: 'Pass Traffic',
            subtext: '$checkedInCount On-Premise',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGateMetricCard(
            icon: Icons.security_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFFF5F3FF),
            value: _securityThreatLevel == 'normal' ? 'L-1' : (_securityThreatLevel == 'heightened' ? 'L-2' : 'L-3'),
            label: 'Integrity',
            subtext: _securityThreatLevel.toUpperCase(),
          ),
        ),
      ],
    );
  }

  Widget _buildGateMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String value,
    required String label,
    required String subtext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtext,
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGateSearchAndFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: _gateSearchController,
            onChanged: (val) => setState(() => _gateSearchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search checkpoint name, code, landmark...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
              suffixIcon: _gateSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                      onPressed: () {
                        setState(() {
                          _gateSearchController.clear();
                          _gateSearchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Type Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildGateTypeFilterChip('all', 'All Gates', Icons.select_all_rounded),
              const SizedBox(width: 8),
              _buildGateTypeFilterChip('main', 'Vehicular', Icons.directions_car_filled_rounded),
              const SizedBox(width: 8),
              _buildGateTypeFilterChip('pedestrian', 'Pedestrian', Icons.directions_walk_rounded),
              const SizedBox(width: 8),
              _buildGateTypeFilterChip('service', 'Service & Logistics', Icons.local_shipping_rounded),
              const SizedBox(width: 8),
              _buildGateTypeFilterChip('emergency', 'Emergency', Icons.emergency_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGateTypeFilterChip(String type, String label, IconData icon) {
    final isSelected = _gateTypeFilter == type;
    return InkWell(
      onTap: () => setState(() => _gateTypeFilter = type),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFFFF6B00) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnterpriseGateCard(SocietyGateModel gate) {
    final visitorsCount = _getGateVisitorsCount(gate.id);
    final checkedInCount = _getGateCheckedInCount(gate.id);
    final isMaintenance = gate.status.toLowerCase() == 'maintenance';
    final isRestricted = gate.status.toLowerCase() == 'restricted';

    Color statusBg = const Color(0xFFECFDF5);
    Color statusBorder = const Color(0xFFA7F3D0);
    Color statusFg = const Color(0xFF065F46);
    String statusText = 'OPERATIONAL';

    if (isMaintenance) {
      statusBg = const Color(0xFFFFFBEB);
      statusBorder = const Color(0xFFFDE68A);
      statusFg = const Color(0xFF92400E);
      statusText = 'MAINTENANCE';
    } else if (isRestricted) {
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
      statusFg = const Color(0xFF991B1B);
      statusText = 'RESTRICTED';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── CARD HEADER ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gradient Gate Type Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: _getGateTypeGradient(gate.gateType),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1F000000), blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Icon(_getGateTypeIcon(gate.gateType), color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),

                // Name & Meta Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gate.gateName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (gate.gateCode != null && gate.gateCode!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                gate.gateCode!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatGateType(gate.gateType),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '🕒 ${gate.operatingHours}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Badge & Overflow Menu
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: statusFg),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            statusText,
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusFg, letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        switch (val) {
                          case 'edit':
                            _showEditGateDialog(gate);
                            break;
                          case 'assign_guard':
                            _showAssignGuardToGateDialog(gate);
                            break;
                          case 'logs':
                            _showGateVisitorLogBottomSheet(gate);
                            break;
                          case 'status':
                            _showUpdateGateStatusDialog(gate);
                            break;
                          case 'delete':
                            _confirmDeleteGate(gate);
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Details')]),
                        ),
                        const PopupMenuItem(
                          value: 'assign_guard',
                          child: Row(children: [Icon(Icons.person_add_alt_1_outlined, size: 16), SizedBox(width: 8), Text('Deploy Guard')]),
                        ),
                        const PopupMenuItem(
                          value: 'logs',
                          child: Row(children: [Icon(Icons.receipt_long_outlined, size: 16), SizedBox(width: 8), Text('View Visitor Logs')]),
                        ),
                        const PopupMenuItem(
                          value: 'status',
                          child: Row(children: [Icon(Icons.tune_rounded, size: 16), SizedBox(width: 8), Text('Change Status')]),
                        ),
                        if (_isAdmin)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Deactivate Gate', style: TextStyle(color: Colors.red))]),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── LOCATION & DESCRIPTION ──────────────────────────────────────
          if ((gate.location != null && gate.location!.isNotEmpty) || (gate.description != null && gate.description!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gate.location != null && gate.location!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF0284C7)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              gate.location!,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (gate.description != null && gate.description!.isNotEmpty) ...[
                      if (gate.location != null && gate.location!.isNotEmpty) const SizedBox(height: 4),
                      Text(
                        gate.description!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const SizedBox(height: 10),

          // ─── CHECKPOINT TELEMETRY MICRO-CHIPS ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _buildGateTelemetryChips(gate),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ─── DUTY ROSTER SECTION (ASSIGNED GUARDS) ──────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: _buildGateDutyRosterSection(gate),
          ),

          // ─── ACTION BAR FOOTER ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Live stats indicator
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 5),
                      Text(
                        '$visitorsCount passes • $checkedInCount inside',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),

                // Deploy Guard Action
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                  label: const Text('Deploy', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAssignGuardToGateDialog(gate),
                ),
                const SizedBox(width: 6),

                // Visitor Log Action
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 14),
                  label: const Text('Pass Log', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  onPressed: () => _showGateVisitorLogBottomSheet(gate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGateTelemetryChips(SocietyGateModel gate) {
    final isLocked = gate.status.toLowerCase() == 'restricted' || _securityThreatLevel == 'lockdown';
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildTelemetryBadge(
          icon: Icons.traffic_outlined,
          label: isLocked ? 'Barrier: Locked' : 'Barrier: Auto',
          color: isLocked ? const Color(0xFFDC2626) : const Color(0xFF059669),
          bgColor: isLocked ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
        ),
        _buildTelemetryBadge(
          icon: Icons.camera_alt_outlined,
          label: 'ANPR: 4K Online',
          color: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
        ),
        _buildTelemetryBadge(
          icon: Icons.qr_code_scanner_rounded,
          label: 'FastPass QR: Ready',
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFF5F3FF),
        ),
      ],
    );
  }

  Widget _buildTelemetryBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildGateDutyRosterSection(SocietyGateModel gate) {
    if (gate.activeGuards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD97706)),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unmanned Checkpoint',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                  Text(
                    'No security guard currently stationed on active shift.',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF92400E),
                side: const BorderSide(color: Color(0xFFD97706)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () => _showAssignGuardToGateDialog(gate),
              child: const Text('+ Deploy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 5),
                Text(
                  'STATIONED GUARDS (${gate.activeGuards.length} ON DUTY)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669), letterSpacing: 0.4),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showAssignGuardToGateDialog(gate),
              child: const Text(
                '+ Deploy Another',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...gate.activeGuards.map((item) {
          final userMap = item['user'] as Map<String, dynamic>?;
          final shiftMap = item['shift'] as Map<String, dynamic>?;
          final guardName = (userMap?['userName'] ?? userMap?['name'] ?? 'Authorized Guard').toString();
          final phone = (userMap?['phone'] ?? '').toString();
          final shiftName = (shiftMap?['shift_name'] ?? 'Active Shift').toString();
          final startTime = (shiftMap?['start_time'] ?? '').toString();
          final endTime = (shiftMap?['end_time'] ?? '').toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF059669),
                  child: Text(
                    guardName.isNotEmpty ? guardName[0].toUpperCase() : 'G',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              guardName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF0284C7)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$shiftName ($startTime - $endTime)',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 18, color: Color(0xFF059669)),
                    onPressed: () => _makePhoneCall(phone),
                    tooltip: 'Call Guard: $phone',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── TAB 5: SHIFTS ─────────────────────────────────────────────────────────
  Widget _buildShiftsTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF111827),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showAddShiftDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: _shifts.isEmpty
            ? _buildEmptyCard('No duty shifts defined yet.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _shifts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = _shifts[i];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF8B5CF6),
                        child: Icon(Icons.access_time, color: Colors.white),
                      ),
                      title: Text(s.shiftName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${s.startTime} → ${s.endTime} • Off: ${s.weeklyOff ?? "None"}'),
                      trailing: Text(s.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: s.status == 'active' ? const Color(0xFF10B981) : Colors.grey,
                          )),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ─── TAB 6: COMMITTEES (Admin Only) ────────────────────────────────────────
  Widget _buildCommitteesTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF6B00),
        icon: const Icon(Icons.group_add, color: Colors.white),
        label: const Text('Create Committee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _showCreateCommitteeDialog,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: _committees.isEmpty
            ? _buildEmptyCard('No delegated committees created yet.')
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _committees.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = _committees[i];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(c.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                              _statusChip(c.status),
                            ],
                          ),
                          if (c.description != null && c.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(c.description!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                          ],
                          const SizedBox(height: 8),
                          // Scope Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune_rounded, size: 13, color: Color(0xFF475569)),
                                const SizedBox(width: 5),
                                Text(
                                  'Scope: ${(c.scopeType ?? "entire_society").replaceAll("_", " ").toUpperCase()}'
                                  '${c.scopeId != null ? " • #${c.scopeId}" : ""}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: c.permissions
                                .map((p) => Chip(
                                      label: Text(p, style: const TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      backgroundColor: const Color(0xFFEFF6FF),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'MEMBERS (${c.members.length})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.person_add_alt_1, size: 14, color: Color(0xFFFF6B00)),
                                label: const Text('Invite Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00))),
                                onPressed: () => _showAddMemberDialog(c),
                              ),
                            ],
                          ),
                          if (c.members.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No members assigned yet. Tap "Invite Member" to invite residents to this committee.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                              ),
                            )
                          else
                            ...c.members.map((member) => _buildCommitteeMemberTile(c, member)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ─── TAB 7: PERMISSIONS (Admin Only) ───────────────────────────────────────
  Widget _buildPermissionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Delegated Security Permissions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select a committee below to view and update granular access granted to its members in real time.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 14),
        ..._committees.map((comm) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(comm.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${comm.permissions.length} active permissions • ${comm.memberCount} members'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditPermissionsDialog(comm),
              ),
            )),
      ],
    );
  }

  // ─── TAB 8: REPORTS (Admin Only) ───────────────────────────────────────────
  Widget _buildReportsTab() {
    final total = _reports['totalVisits'] ?? 0;
    final approved = _reports['approvedVisits'] ?? 0;
    final rejected = _reports['rejectedVisits'] ?? 0;
    final rate = _reports['rejectionRate'] ?? '0%';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Security & Visitor Analytics',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _reportRow('Total Visits Logged', total.toString()),
                const Divider(),
                _reportRow('Approved Visits', approved.toString()),
                const Divider(),
                _reportRow('Rejected Visits', rejected.toString()),
                const Divider(),
                _reportRow('Rejection Rate', rate.toString()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
        ],
      ),
    );
  }

  // ─── TAB 9: AUDIT LOGS (Admin Only) ────────────────────────────────────────
  Widget _buildAuditLogsTab() {
    return _auditLogs.isEmpty
        ? _buildEmptyCard('No security audit events recorded yet.')
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _auditLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final log = _auditLogs[i];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const Icon(Icons.history_toggle_off, color: Color(0xFFFF6B00)),
                  title: Text(log['action'] ?? 'security.event',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Target: ${log['target_entity_type']} #${log['target_entity_id']} • ${log['created_at'] ?? ""}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                ),
              );
            },
          );
  }

  // ─── DIALOGS & MODALS ──────────────────────────────────────────────────────
  // ─── GUARD CRUD: BADGES & HELPERS ──────────────────────────────────────────
  Widget _verificationBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status.toLowerCase()) {
      case 'verified':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        label = 'Verified';
        break;
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        label = 'Pending';
        break;
      case 'rejected':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFF991B1B);
        label = 'Rejected';
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        label = 'Unverified';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _guardStatusBadge(String status) {
    final isActive = status.toLowerCase() == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD1FAE5) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? const Color(0xFF065F46) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _modalField(String label, String hint, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlatAutocompleteSelector({
    required TextEditingController controller,
    required int? selectedHostUserId,
    required SocietyMemberModel? selectedMember,
    required void Function(int? userId, SocietyMemberModel? member) onSelect,
    required StateSetter setModalState,
    String label = 'Host Flat / Unit *',
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
                              Text(
                                m.memberName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF111827)),
                                overflow: TextOverflow.ellipsis,
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
                          societyId: widget.societyId,
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
                                      if (widget.societyId <= 0) return;
                                      setPickerState(() => isReloading = true);
                                      try {
                                        final res = await _societyService.getMembers(widget.societyId, limit: 100);
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
                                    '${m.role.toUpperCase()}${m.memberPhone.isNotEmpty ? ' • ${m.memberPhone}' : ''}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
                                  onTap: () {
                                    onSelected(m);
                                    Navigator.pop(ctx);
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

  Widget _datePickerField({
    required BuildContext context,
    required String label,
    required String hint,
    required TextEditingController controller,
    required StateSetter setState,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
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
              setState(() {
                controller.text = formatted;
              });
            }
          },
          child: IgnorePointer(
            child: TextField(
              controller: controller,
              readOnly: true,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFFFF6B00), size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── GUARD CRUD (READ): GUARD DETAIL BOTTOM SHEET ──────────────────────────
  void _showGuardDetailSheet(SocietyGuardAuthorizationModel guard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isVerified = guard.verificationStatus.toLowerCase() == 'verified';
          final isPending = guard.verificationStatus.toLowerCase() == 'pending' || guard.verificationStatus.toLowerCase() == 'unverified';

          Widget detailRow(String label, String value, {Widget? trailing}) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                  if (trailing != null)
                    trailing
                  else
                    Flexible(
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                      ),
                    ),
                ],
              ),
            );
          }

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Photo, Name & Badges
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: guard.isActive ? const Color(0xFF10B981) : Colors.grey,
                        backgroundImage: (guard.profilePhotoUrl != null && guard.profilePhotoUrl!.isNotEmpty)
                            ? NetworkImage(guard.profilePhotoUrl!)
                            : null,
                        child: (guard.profilePhotoUrl == null || guard.profilePhotoUrl!.isEmpty)
                            ? const Icon(Icons.security, color: Colors.white, size: 36)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guard.userName ?? 'Guard #${guard.userId}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              guard.designation,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _verificationBadge(guard.verificationStatus),
                                const SizedBox(width: 8),
                                _guardStatusBadge(guard.status),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  // Verification Actions for Admin
                  if (_isAdmin && !isVerified) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_outlined, size: 16, color: Color(0xFFB45309)),
                              SizedBox(width: 6),
                              Text('Admin Verification Required',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onPressed: () async {
                                    await _societyService.verifyGuard(guard.id, widget.societyId);
                                    Navigator.pop(ctx);
                                    _loadAllData();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Guard verified successfully!'), backgroundColor: Color(0xFF10B981)),
                                      );
                                    }
                                  },
                                ),
                              ),
                              if (isPending) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _showRejectVerificationDialog(guard);
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // SECTION: Personal Details
                  const Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        detailRow('Mobile Number', guard.phone ?? 'N/A'),
                        detailRow('Alternate Phone', guard.alternatePhone?.isNotEmpty == true ? guard.alternatePhone! : 'Not provided'),
                        detailRow('Gender', guard.gender?.toUpperCase() ?? 'N/A'),
                        detailRow('Date of Birth (DOB)', guard.dob?.isNotEmpty == true ? guard.dob! : 'Not set'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // SECTION: Identity & Document Verification
                  const Text('Identity & Document Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        detailRow('ID Document Type', guard.idType.toUpperCase()),
                        detailRow('ID Number', guard.idNumber ?? 'Not submitted'),
                        detailRow('Verification Status', guard.verificationStatus.toUpperCase(), trailing: _verificationBadge(guard.verificationStatus)),
                        detailRow('Police Verification', guard.policeVerificationStatus.toUpperCase()),
                        if (guard.verificationDate != null && guard.verificationDate!.isNotEmpty)
                          detailRow('Verification Date', guard.verificationDate!),
                        if (guard.rejectionReason != null && guard.rejectionReason!.isNotEmpty)
                          detailRow('Rejection Reason', guard.rejectionReason!, trailing: Text(guard.rejectionReason!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12))),
                        if (guard.idDocumentUrl != null && guard.idDocumentUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.file_present_outlined, size: 18),
                              label: const Text('View Uploaded Document'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF93C5FD)),
                              ),
                              onPressed: () async {
                                final uri = Uri.tryParse(guard.idDocumentUrl!);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('ID Document URL: ${guard.idDocumentUrl}')),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // SECTION: Duty & Assignment
                  const Text('Duty & Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        detailRow('Assigned Gate', guard.gateName ?? 'Unassigned'),
                        detailRow('Assigned Shift', guard.shiftName ?? 'Unassigned'),
                        detailRow('Guard Type', guard.guardType.toUpperCase()),
                        detailRow('Agency / Contractor', guard.agencyName?.isNotEmpty == true ? guard.agencyName! : 'Direct Society'),
                        if (guard.employeeId?.isNotEmpty == true) detailRow('Employee ID', guard.employeeId!),
                        if (guard.notes?.isNotEmpty == true) detailRow('Notes', guard.notes!),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons (Full CRUD)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Guard'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6B00),
                            side: const BorderSide(color: Color(0xFFFF6B00)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showEditGuardDialog(guard);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.schedule, size: 16),
                          label: const Text('Assign Duty'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAssignGuardDialog(guard);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(guard.isActive ? Icons.block : Icons.check_circle, size: 16),
                          label: Text(guard.isActive ? 'Deactivate' : 'Activate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: guard.isActive ? const Color(0xFF4B5563) : const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            final newStatus = guard.isActive ? 'inactive' : 'active';
                            await _societyService.updateGuardStatus(guard.id, widget.societyId, status: newStatus);
                            Navigator.pop(ctx);
                            _loadAllData();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete Guard'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteGuard(guard);
                          },
                        ),
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

  // ─── GUARD CRUD (UPDATE): EDIT GUARD DIALOG ────────────────────────────────
  void _showEditGuardDialog(SocietyGuardAuthorizationModel guard) {
    final nameCtrl = TextEditingController(text: guard.userName ?? '');
    final desigCtrl = TextEditingController(text: guard.designation);
    final altPhoneCtrl = TextEditingController(text: guard.alternatePhone ?? '');
    final agencyCtrl = TextEditingController(text: guard.agencyName ?? '');
    final empIdCtrl = TextEditingController(text: guard.employeeId ?? '');
    final dobCtrl = TextEditingController(text: guard.dob ?? '');
    final notesCtrl = TextEditingController(text: guard.notes ?? '');
    String gender = guard.gender ?? 'male';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setEditState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFFFF6B00)),
              const SizedBox(width: 8),
              Expanded(child: Text('Edit Guard: ${guard.userName ?? "Guard"}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _modalField('Full Name *', 'e.g. Ramesh Singh', nameCtrl),
                  const SizedBox(height: 10),
                  _modalField('Designation *', 'e.g. Senior Security Guard', desigCtrl),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: ['male', 'female', 'other'].contains(gender.toLowerCase()) ? gender.toLowerCase() : 'male',
                          decoration: InputDecoration(
                            labelText: 'Gender',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (val) => setEditState(() => gender = val ?? 'male'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datePickerField(
                          context: context,
                          label: 'DOB',
                          hint: 'Select Date',
                          controller: dobCtrl,
                          setState: setEditState,
                          initialDate: DateTime(1995, 1, 1),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _modalField('Alternate Phone', 'e.g. 9876543210', altPhoneCtrl, keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),
                  _modalField('Agency / Contractor', 'e.g. SIS Security', agencyCtrl),
                  const SizedBox(height: 10),
                  _modalField('Employee ID', 'e.g. SEC-001', empIdCtrl),
                  const SizedBox(height: 10),
                  _modalField('Notes', 'Special remarks', notesCtrl, maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
              onPressed: isSaving
                  ? null
                  : () async {
                      setEditState(() => isSaving = true);
                      try {
                        await _societyService.updateGuard(
                          guard.id,
                          widget.societyId,
                          name: nameCtrl.text.trim(),
                          designation: desigCtrl.text.trim(),
                          gender: gender,
                          dob: dobCtrl.text.trim(),
                          alternatePhone: altPhoneCtrl.text.trim(),
                          agencyName: agencyCtrl.text.trim(),
                          employeeId: empIdCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadAllData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Guard updated successfully!'), backgroundColor: Color(0xFF10B981)),
                          );
                        }
                      } catch (err) {
                        setEditState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Failed to update: $err'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── GUARD CRUD (DELETE): CONFIRM DELETE GUARD ─────────────────────────────
  void _confirmDeleteGuard(SocietyGuardAuthorizationModel guard) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Revoke & Delete Guard',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete and revoke guard "${guard.userName ?? 'Guard #${guard.userId}'}"?\n\n'
          'This will cancel all active gate and shift assignments.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _societyService.deleteGuard(guard.id, widget.societyId);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Guard deleted & revoked successfully'), backgroundColor: Colors.red),
                  );
                }
              } catch (err) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to delete guard: $err'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Delete Guard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── GUARD CRUD: REJECT VERIFICATION DIALOG ────────────────────────────────
  void _showRejectVerificationDialog(SocietyGuardAuthorizationModel guard) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Guard Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please state the reason for rejecting this guard\'s verification:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. ID document is blurred / invalid Aadhaar number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              await _societyService.rejectGuardVerification(
                guard.id,
                widget.societyId,
                reason: reasonCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadAllData();
            },
            child: const Text('Confirm Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── GUARD CRUD (CREATE): 5-STEP ENTERPRISE ONBOARDING WIZARD ──────────────
  void _showOnboardGuardDialog() {
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
    int? selectedGateId = _gates.isNotEmpty ? _gates[0].id : null;
    int? selectedShiftId = _shifts.isNotEmpty ? _shifts[0].id : null;
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

        setModalState(() => isUploadingPhoto = true);
        final bytes = await picked.readAsBytes();
        final uploadedUrl = await _societyService.uploadGuardPhotoBytes(
          widget.societyId,
          bytes,
          picked.name,
        );

        setModalState(() {
          profilePhotoUrl = uploadedUrl;
          isUploadingPhoto = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo uploaded successfully!'), backgroundColor: Color(0xFF059669)),
          );
        }
      } catch (err) {
        setModalState(() => isUploadingPhoto = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload photo: $err'), backgroundColor: Colors.red),
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

        setModalState(() => isUploadingDoc = true);

        final bytes = await file.readAsBytes();

        final uploadedUrl = await _societyService.uploadGuardIdDocumentBytes(
          widget.societyId,
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
        setModalState(() => isUploadingDoc = false);
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
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Onboard Security Guard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Register personnel with duty checkpoint & shift', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Step Progress Indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      _buildStepPill(1, 'Personal', currentStep == 0, currentStep > 0),
                      const SizedBox(width: 4),
                      _buildStepPill(2, 'Identity', currentStep == 1, currentStep > 1),
                      const SizedBox(width: 4),
                      _buildStepPill(3, 'Job', currentStep == 2, currentStep > 2),
                      const SizedBox(width: 4),
                      _buildStepPill(4, 'Shift', currentStep == 3, currentStep > 3),
                      const SizedBox(width: 4),
                      _buildStepPill(5, 'Activate', currentStep == 4, false),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── STEP 1: PERSONAL DETAILS ─────────────────────────
                if (currentStep == 0) ...[
                  const Text('Step 1 — Guard Photo & Personal Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 14),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: const Color(0xFFF1F5F9),
                            backgroundImage: profilePhotoUrl != null ? NetworkImage(profilePhotoUrl!) : null,
                            child: profilePhotoUrl == null
                                ? (isUploadingPhoto
                                    ? const CircularProgressIndicator(color: Color(0xFFFF6B00), strokeWidth: 2)
                                    : const Icon(Icons.person_add_alt_1_rounded, size: 36, color: Color(0xFF94A3B8)))
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.photo_camera_rounded, size: 16),
                              label: Text(profilePhotoUrl == null ? 'Upload Photo' : 'Change Photo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF6B00),
                                side: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: isUploadingPhoto ? null : () => pickAndUploadPhoto(setModalState),
                            ),
                            if (profilePhotoUrl != null) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => setModalState(() => profilePhotoUrl = null),
                                child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _modalField('Mobile Number *', '10-digit primary mobile', phoneCtrl, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _modalField('Full Name *', 'e.g. Ramesh Singh', nameCtrl),
                  const SizedBox(height: 12),
                  _modalField('Alternate Phone', 'Optional emergency contact', altPhoneCtrl, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Gender *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: gender,
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('Male', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'female', child: Text('Female', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'other', child: Text('Other', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                              ],
                              onChanged: (val) => setModalState(() => gender = val ?? 'male'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datePickerField(
                          context: context,
                          label: 'Date of Birth (DOB) *',
                          hint: 'Select Date',
                          controller: dobCtrl,
                          setState: setModalState,
                          initialDate: DateTime(1995, 1, 1),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── STEP 2: VERIFICATION ─────────────────────────────
                if (currentStep == 1) ...[
                  const Text('Step 2 — Identity & Verification', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ID Document Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: idType,
                        dropdownColor: Colors.white,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'aadhaar', child: Text('Aadhaar Card', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                          DropdownMenuItem(value: 'pan', child: Text('PAN Card', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                          DropdownMenuItem(value: 'voter_id', child: Text('Voter ID', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                          DropdownMenuItem(value: 'driving_license', child: Text('Driving License', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                          DropdownMenuItem(value: 'passport', child: Text('Passport', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                        ],
                        onChanged: (val) => setModalState(() => idType = val ?? 'aadhaar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _modalField('ID Number *', 'e.g. 1234 5678 9012', idNumberCtrl),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _modalField('ID Document File URL', 'Uploaded document URL', idDocUrlCtrl),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ElevatedButton.icon(
                          icon: isUploadingDoc
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.upload_file_rounded, size: 16),
                          label: const Text('Pick Doc', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: isUploadingDoc ? null : () => pickAndUploadDoc(setModalState),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Verification *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: verificationStatus,
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'unverified', child: Text('Unverified', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'pending', child: Text('Pending Approval', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'verified', child: Text('Verified', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF059669)))),
                              ],
                              onChanged: (val) => setModalState(() => verificationStatus = val ?? 'unverified'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Police Verif. *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: policeVerificationStatus,
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'not_submitted', child: Text('Not Submitted', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'pending', child: Text('Pending', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'verified', child: Text('Verified', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF059669)))),
                              ],
                              onChanged: (val) => setModalState(() => policeVerificationStatus = val ?? 'not_submitted'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _datePickerField(
                    context: context,
                    label: 'Verification Date',
                    hint: 'Select Date',
                    controller: verificationDateCtrl,
                    setState: setModalState,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                  ),
                ],

                // ── STEP 3: EMPLOYMENT ───────────────────────────────
                if (currentStep == 2) ...[
                  const Text('Step 3 — Employment Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Guard Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: guardType,
                        dropdownColor: Colors.white,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'society_guard', child: Text('Direct Society Guard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                          DropdownMenuItem(value: 'contract_guard', child: Text('Contract / Agency Guard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                          DropdownMenuItem(value: 'temporary_guard', child: Text('Temporary Guard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                        ],
                        onChanged: (val) => setModalState(() => guardType = val ?? 'society_guard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _modalField('Designation', 'Security Guard', designationCtrl)),
                      const SizedBox(width: 10),
                      Expanded(child: _modalField('Employee ID', 'EMP-001', employeeIdCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _modalField('Agency / Contractor Name', 'e.g. SIS Security / Eagle Eye', agencyCtrl),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _datePickerField(
                          context: context,
                          label: 'Joining Date',
                          hint: 'Select Date',
                          controller: joiningDateCtrl,
                          setState: setModalState,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2010),
                          lastDate: DateTime(2040),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _datePickerField(
                          context: context,
                          label: 'Contract End Date',
                          hint: 'Select Date',
                          controller: contractEndCtrl,
                          setState: setModalState,
                          initialDate: DateTime.now().add(const Duration(days: 365)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2040),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _modalField('Notes / Special Instructions', 'e.g. Trained in fire safety & CCTV', notesCtrl),
                ],

                // ── STEP 4: GATE & SHIFT ─────────────────────────────
                if (currentStep == 3) ...[
                  const Text('Step 4 — Gate & Shift Assignment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign Security Gate *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: selectedGateId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                          ),
                        ),
                        items: _gates.map((g) => DropdownMenuItem(value: g.id, child: Text(g.gateName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))))).toList(),
                        onChanged: (val) => setModalState(() => selectedGateId = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign Duty Shift *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: selectedShiftId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                          ),
                        ),
                        items: _shifts.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.shiftName} (${s.startTime} - ${s.endTime})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))))).toList(),
                        onChanged: (val) => setModalState(() => selectedShiftId = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Duty Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: dutyType,
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'permanent', child: Text('Permanent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'reliever', child: Text('Reliever', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'overtime', child: Text('Overtime', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                              ],
                              onChanged: (val) => setModalState(() => dutyType = val ?? 'permanent'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Weekly Off', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: weeklyOff,
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569)),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.8),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Sunday', child: Text('Sunday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'Monday', child: Text('Monday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'Tuesday', child: Text('Tuesday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'Wednesday', child: Text('Wednesday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'Thursday', child: Text('Thursday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'Friday', child: Text('Friday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                                DropdownMenuItem(value: 'Saturday', child: Text('Saturday', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                              ],
                              onChanged: (val) => setModalState(() => weeklyOff = val ?? 'Sunday'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _modalField('Assignment Remarks', 'Assigned to duty', remarksCtrl),
                ],

                // ── STEP 5: REVIEW & ACTIVATE ────────────────────────
                if (currentStep == 4) ...[
                  const Text('Step 5 — Summary & Activation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summaryItem('Guard Name', nameCtrl.text.trim().isEmpty ? 'N/A' : nameCtrl.text.trim()),
                        _summaryItem('Mobile Number', phoneCtrl.text.trim()),
                        _summaryItem('Designation', designationCtrl.text.trim()),
                        _summaryItem('Agency', agencyCtrl.text.trim().isEmpty ? 'Direct Society' : agencyCtrl.text.trim()),
                        _summaryItem('Verification', '${idType.toUpperCase()} ($verificationStatus)'),
                        _summaryItem('Gate', _gates.firstWhere((g) => g.id == selectedGateId, orElse: () => const SocietyGateModel(id: 0, societyId: 0, gateName: 'Main Gate 1')).gateName),
                        _summaryItem('Shift', _shifts.firstWhere((s) => s.id == selectedShiftId, orElse: () => const SocietyShiftModel(id: 0, societyId: 0, shiftName: 'Morning Shift', startTime: '07:00', endTime: '19:00')).shiftName),
                        _summaryItem('Status', employmentStatus.toUpperCase()),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Wizard Navigation Buttons
                if (currentStep < 4) ...[
                  Row(
                    children: [
                      if (currentStep > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => setModalState(() => currentStep--),
                            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (currentStep == 0 && phoneCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter mobile number')));
                              return;
                            }
                            setModalState(() => currentStep++);
                          },
                          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => setModalState(() => currentStep--),
                          child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    await _societyService.onboardGuardEnterprise(
                                      widget.societyId,
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
                                    _loadAllData();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
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
                              : const Text('Activate Guard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3)),
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

  Widget _summaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildStepPill(int number, String label, bool isCurrent, bool isCompleted) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    Color numCircleBg;
    Color numTextColor;

    if (isCurrent) {
      bgColor = const Color(0xFFFF6B00);
      borderColor = const Color(0xFFFF6B00);
      textColor = Colors.white;
      numCircleBg = Colors.white;
      numTextColor = const Color(0xFFFF6B00);
    } else if (isCompleted) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFF10B981);
      textColor = const Color(0xFF065F46);
      numCircleBg = const Color(0xFF10B981);
      numTextColor = Colors.white;
    } else {
      bgColor = Colors.white;
      borderColor = const Color(0xFFCBD5E1);
      textColor = const Color(0xFF334155);
      numCircleBg = const Color(0xFFE2E8F0);
      numTextColor = const Color(0xFF475569);
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: numCircleBg,
                shape: BoxShape.circle,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : Text(
                      '$number',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: numTextColor,
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignGuardDialog(SocietyGuardAuthorizationModel guard) {
    int? gateId = _gates.isNotEmpty ? _gates[0].id : null;
    int? shiftId = _shifts.isNotEmpty ? _shifts[0].id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Assign Duty for ${guard.userName ?? "Guard"}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: gateId,
                decoration: const InputDecoration(
                  labelText: 'Gate',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _gates.map((g) => DropdownMenuItem(value: g.id, child: Text(g.gateName, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) => setDialogState(() => gateId = val),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: shiftId,
                decoration: const InputDecoration(
                  labelText: 'Shift',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _shifts.map((s) => DropdownMenuItem(value: s.id, child: Text(s.shiftName, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) => setDialogState(() => shiftId = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (gateId == null || shiftId == null) return;
                await _societyService.assignGuardGateAndShift(
                  widget.societyId,
                  guardAuthorizationId: guard.id,
                  gateId: gateId!,
                  shiftId: shiftId!,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAllData();
              },
              child: const Text('Assign Duty'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGateDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedType = 'main';
    String operatingHours = '24/7';
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
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add_moderator_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Register Checkpoint / Gate', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          Text('Add a secured access point to society perimeter', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Checkpoint Name *',
                    hintText: 'e.g. Main Gate 1, North Service Gate',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Gate Code',
                          hintText: 'e.g. GATE-01',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedType,
                        decoration: InputDecoration(
                          labelText: 'Gate Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'main', child: Text('Vehicular Main', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'pedestrian', child: Text('Pedestrian', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'service', child: Text('Service/Vendor', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'emergency', child: Text('Emergency Exit', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'back_gate', child: Text('Secondary Gate', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) => setModalState(() => selectedType = val ?? 'main'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: operatingHours,
                  decoration: InputDecoration(
                    labelText: 'Operating Schedule',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: '24/7', child: Text('24 Hours • All Days (24/7)')),
                    DropdownMenuItem(value: '06:00 - 22:00', child: Text('Day Shift Only (06:00 AM - 10:00 PM)')),
                    DropdownMenuItem(value: '07:00 - 19:00', child: Text('Standard Shift (07:00 AM - 07:00 PM)')),
                    DropdownMenuItem(value: 'Emergency Only', child: Text('Emergency Only (Normally Locked)')),
                  ],
                  onChanged: (val) => setModalState(() => operatingHours = val ?? '24/7'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: locationCtrl,
                  decoration: InputDecoration(
                    labelText: 'Physical Landmark / Location',
                    hintText: 'e.g. North Perimeter near Tower A & Club',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Special Operating Protocol / Instructions',
                    hintText: 'e.g. Inspect all commercial delivery vans, check ID badges',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a gate name')),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);
                                try {
                                  await _societyService.createGate(
                                    widget.societyId,
                                    gateName: name,
                                    gateCode: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                                    gateType: selectedType,
                                    operatingHours: operatingHours,
                                    location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadAllData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Checkpoint "$name" created successfully!'),
                                        backgroundColor: const Color(0xFF059669),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to create gate: $e')),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Create Gate', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditGateDialog(SocietyGateModel gate) {
    final nameCtrl = TextEditingController(text: gate.gateName);
    final codeCtrl = TextEditingController(text: gate.gateCode ?? '');
    final locationCtrl = TextEditingController(text: gate.location ?? '');
    final descCtrl = TextEditingController(text: gate.description ?? '');
    String selectedType = gate.gateType;
    String operatingHours = gate.operatingHours;
    String status = gate.status;
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
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit Checkpoint (${gate.gateName})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                          const Text('Update security specifications and operational status', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Checkpoint Name *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Gate Code',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: ['main', 'pedestrian', 'service', 'emergency', 'back_gate'].contains(selectedType) ? selectedType : 'main',
                        decoration: InputDecoration(
                          labelText: 'Gate Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'main', child: Text('Vehicular Main', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'pedestrian', child: Text('Pedestrian', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'service', child: Text('Service/Vendor', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'emergency', child: Text('Emergency Exit', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'back_gate', child: Text('Secondary Gate', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) => setModalState(() => selectedType = val ?? 'main'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: ['24/7', '06:00 - 22:00', '07:00 - 19:00', 'Emergency Only'].contains(operatingHours) ? operatingHours : '24/7',
                        decoration: InputDecoration(
                          labelText: 'Operating Schedule',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: '24/7', child: Text('24 Hours (24/7)', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: '06:00 - 22:00', child: Text('06:00 - 22:00', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: '07:00 - 19:00', child: Text('07:00 - 19:00', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'Emergency Only', child: Text('Emergency Only', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) => setModalState(() => operatingHours = val ?? '24/7'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: ['active', 'maintenance', 'restricted', 'inactive'].contains(status) ? status : 'active',
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Operational', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'maintenance', child: Text('Maintenance', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'restricted', child: Text('Restricted', overflow: TextOverflow.ellipsis)),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (val) => setModalState(() => status = val ?? 'active'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: locationCtrl,
                  decoration: InputDecoration(
                    labelText: 'Physical Landmark / Location',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Special Operating Protocol / Instructions',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) return;

                                setModalState(() => isSubmitting = true);
                                try {
                                  await _societyService.updateGate(
                                    widget.societyId,
                                    gate.id,
                                    gateName: name,
                                    gateCode: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                                    gateType: selectedType,
                                    operatingHours: operatingHours,
                                    location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                                    status: status,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadAllData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Gate configuration updated!'),
                                        backgroundColor: Color(0xFF059669),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Update failed: $e')),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignGuardToGateDialog(SocietyGateModel gate) {
    if (_guards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No guards onboarded yet. Please onboard guards first in Guards tab.')),
      );
      return;
    }
    if (_shifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No shifts defined yet. Please add a shift in Shifts tab first.')),
      );
      return;
    }

    int selectedGuardId = _guards.first.id;
    int selectedShiftId = _shifts.first.id;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF059669), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Station Guard at ${gate.gateName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('${gate.gateCode ?? "GATE"} • ${gate.operatingHours}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Security Guard:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: selectedGuardId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _guards.map((g) {
                  final name = g.userName ?? g.badgeNumber ?? 'Guard #${g.id}';
                  return DropdownMenuItem<int>(
                    value: g.id,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF059669),
                          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'G', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$name (${g.phone ?? "No phone"})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedGuardId = val);
                },
              ),
              const SizedBox(height: 14),

              const Text('Select Duty Shift:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: selectedShiftId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _shifts.map((s) {
                  return DropdownMenuItem<int>(
                    value: s.id,
                    child: Text(
                      '${s.shiftName} (${s.startTime} - ${s.endTime})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedShiftId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _societyService.assignGuardGateAndShift(
                          widget.societyId,
                          guardAuthorizationId: selectedGuardId,
                          gateId: gate.id,
                          shiftId: selectedShiftId,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadAllData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Guard successfully stationed at ${gate.gateName}!'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to assign guard: $e')),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Deploy Guard'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGateVisitorLogBottomSheet(SocietyGateModel gate) {
    final gateVisitors = _visitors.where((v) {
      if (v.gateId == gate.id) return true;
      if (v.gate != null && v.gate!['id'] == gate.id) return true;
      return false;
    }).toList();

    final displayVisitors = gateVisitors.isNotEmpty ? gateVisitors : _visitors.take(15).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle & Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${gate.gateName} — Pass Stream', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                            Text(
                              gateVisitors.isNotEmpty
                                  ? '${gateVisitors.length} checkpoint records found'
                                  : 'Recent society entries (${displayVisitors.length})',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Visitors List
            Expanded(
              child: displayVisitors.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sensor_door_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('No Visitor Passes Logged', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155))),
                          SizedBox(height: 4),
                          Text('Visitors checking in through this gate will appear here in real-time.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: displayVisitors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final v = displayVisitors[i];
                        final isCheckedIn = v.status.toLowerCase() == 'checked_in';
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: CircleAvatar(
                              backgroundColor: isCheckedIn ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                              child: Icon(
                                isCheckedIn ? Icons.login_rounded : Icons.person_outline_rounded,
                                color: isCheckedIn ? const Color(0xFF059669) : const Color(0xFF475569),
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    v.visitorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _statusChip(v.status),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${v.flatNo != null ? "Flat ${v.flatNo} • " : ""}${v.vehicleNo != null ? "${v.vehicleNo} • " : ""}${v.purpose ?? "Visit"}',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showVisitorDetailSheet(v);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateGateStatusDialog(SocietyGateModel gate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Operating Status for ${gate.gateName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
              title: const Text('Operational (Active)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Normal vehicle and pedestrian clearance', style: TextStyle(fontSize: 11)),
              onTap: () async {
                Navigator.pop(ctx);
                await _societyService.updateGate(widget.societyId, gate.id, status: 'active');
                _loadAllData();
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.build_circle_rounded, color: Color(0xFFD97706)),
              title: const Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Boom barrier or sensor under repair', style: TextStyle(fontSize: 11)),
              onTap: () async {
                Navigator.pop(ctx);
                await _societyService.updateGate(widget.societyId, gate.id, status: 'maintenance');
                _loadAllData();
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626)),
              title: const Text('Restricted / Lockdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Closed to non-emergency entries', style: TextStyle(fontSize: 11)),
              onTap: () async {
                Navigator.pop(ctx);
                await _societyService.updateGate(widget.societyId, gate.id, status: 'restricted');
                _loadAllData();
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showSecurityProtocolSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF0F172A), size: 24),
                  SizedBox(width: 10),
                  Text('Set Perimeter Defense Posture', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Configure society-wide access protocol and security alertness level.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              // Level 1: Normal
              _buildProtocolOption(
                level: 'normal',
                title: 'Level 1: Normal Access Operations',
                desc: 'Automated boom barriers, FastPass QR scanning & standard visitor approval.',
                color: const Color(0xFF059669),
                icon: Icons.verified_user_rounded,
                onTap: () {
                  setState(() => _securityThreatLevel = 'normal');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Perimeter defense posture set to Level 1 (Normal)'), backgroundColor: Color(0xFF059669)),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Level 2: Heightened
              _buildProtocolOption(
                level: 'heightened',
                title: 'Level 2: Heightened Vigilance',
                desc: 'Mandatory physical photo ID inspection, vehicle boot checks & heightened guard scrutiny.',
                color: const Color(0xFFD97706),
                icon: Icons.warning_rounded,
                onTap: () {
                  setState(() => _securityThreatLevel = 'heightened');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Perimeter defense posture elevated to Level 2 (Heightened)'), backgroundColor: Color(0xFFD97706)),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Level 3: Lockdown
              _buildProtocolOption(
                level: 'lockdown',
                title: 'Level 3: Full Perimeter Lockdown',
                desc: 'Emergency protocol. All boom barriers down. Unscheduled entries suspended.',
                color: const Color(0xFFDC2626),
                icon: Icons.lock_clock_rounded,
                onTap: () {
                  setState(() => _securityThreatLevel = 'lockdown');
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('EMERGENCY: Perimeter defense set to Level 3 (Lockdown)'), backgroundColor: Color(0xFFDC2626)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolOption({
    required String level,
    required String title,
    required String desc,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = _securityThreatLevel == level;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : const Color(0xFFE2E8F0), width: isSelected ? 1.8 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGate(SocietyGateModel gate) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate Checkpoint ${gate.gateName}?'),
        content: Text(
          'Are you sure you want to deactivate ${gate.gateName} (${gate.gateCode ?? "No code"})?\n\n'
          'Stationed guards (${gate.activeGuards.length}) will need to be redeployed to another active checkpoint.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _societyService.deleteGate(widget.societyId, gate.id);
                _loadAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gate "${gate.gateName}" deactivated.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete gate: $e')),
                  );
                }
              }
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  void _showAddShiftDialog() {
    final nameCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '07:00');
    final endCtrl = TextEditingController(text: '19:00');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Duty Shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Shift Name (e.g. Night Shift)')),
            TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start Time (e.g. 19:00)')),
            TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End Time (e.g. 07:00)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await _societyService.createShift(
                widget.societyId,
                shiftName: nameCtrl.text.trim(),
                startTime: startCtrl.text.trim(),
                endTime: endCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _loadAllData();
            },
            child: const Text('Create Shift'),
          ),
        ],
      ),
    );
  }

  void _showCreateCommitteeDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SocietyCommitteeBuilderScreen(
          societyId: widget.societyId,
        ),
      ),
    );
    if (result == true) {
      _loadAllData();
    }
  }

  void _showAddMemberDialog(SocietyCommitteeModel comm, {String? initialPhone}) {
    final phoneCtrl = TextEditingController(text: initialPhone ?? '');
    final designationCtrl = TextEditingController(text: 'Security Coordinator');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Invite Member to ${comm.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'An invitation notification will be sent. Member starts in PENDING status. PBAC permissions become active only after acceptance.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'User Mobile Number *', hintText: 'e.g. 9876543210')),
            const SizedBox(height: 8),
            TextField(controller: designationCtrl, decoration: const InputDecoration(labelText: 'Designation')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), foregroundColor: Colors.white),
            onPressed: () async {
              if (phoneCtrl.text.trim().isEmpty) return;
              try {
                await _societyService.addCommitteeMember(
                  comm.id,
                  widget.societyId,
                  phone: phoneCtrl.text.trim(),
                  designation: designationCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invitation sent! Member status is PENDING until accepted.'),
                      backgroundColor: Color(0xFF059669),
                    ),
                  );
                }
                _loadAllData();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Send Invitation'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitteeMemberTile(SocietyCommitteeModel c, SocietyCommitteeMemberModel m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: m.isActive
                    ? const Color(0xFFD1FAE5)
                    : m.isPending
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFFEE2E2),
                child: Icon(
                  m.isActive
                      ? Icons.check
                      : m.isPending
                          ? Icons.hourglass_top_rounded
                          : Icons.block_rounded,
                  size: 14,
                  color: m.isActive
                      ? const Color(0xFF065F46)
                      : m.isPending
                          ? const Color(0xFF92400E)
                          : const Color(0xFF991B1B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.userName ?? (m.phone != null ? 'User (${m.phone})' : 'Member #${m.userId}'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      '${m.designation}${m.phone != null && m.phone!.isNotEmpty ? " • ${m.phone}" : ""}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _memberStatusChip(m.status),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (m.isPending) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 12),
                    label: const Text('Resend Invite', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleResendInvitation(c, m),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded, size: 12),
                    label: const Text('Cancel Invite', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleCancelInvitation(c, m),
                  ),
                ] else if (m.isActive) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.pause_circle_outline, size: 12),
                    label: const Text('Suspend', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: const BorderSide(color: Color(0xFFFCD34D)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleSuspendMember(c, m),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 12),
                    label: const Text('Revoke', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleRevokeMember(c, m),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 12),
                    label: const Text('Remove', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleRemoveMember(c, m),
                  ),
                ] else if (m.isSuspended) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.play_circle_outline, size: 12),
                    label: const Text('Reactivate', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFF6EE7B7)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleActivateMember(c, m),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 12),
                    label: const Text('Revoke', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleRevokeMember(c, m),
                  ),
                ] else if (m.isRevoked) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restore_rounded, size: 12),
                    label: const Text('Reactivate', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFF6EE7B7)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleActivateMember(c, m),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 12),
                    label: const Text('Remove', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleRemoveMember(c, m),
                  ),
                ] else if (m.isRejected || m.isExpired) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 12),
                    label: const Text('Re-invite', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B00),
                      side: const BorderSide(color: Color(0xFFFFD8B3)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _showAddMemberDialog(c, initialPhone: m.phone),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 12),
                    label: const Text('Remove', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleRemoveMember(c, m),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberStatusChip(String status) {
    Color bg = const Color(0xFFF3F4F6);
    Color fg = const Color(0xFF4B5563);
    final s = status.toLowerCase();
    if (s == 'active') {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF065F46);
    } else if (s == 'pending') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else if (s == 'suspended') {
      bg = const Color(0xFFEDE9FE);
      fg = const Color(0xFF6D28D9);
    } else if (s == 'revoked') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    } else if (s == 'rejected') {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
    } else if (s == 'expired') {
      bg = const Color(0xFFE5E7EB);
      fg = const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  Future<void> _handleResendInvitation(SocietyCommitteeModel comm, SocietyCommitteeMemberModel member) async {
    try {
      await _societyService.resendCommitteeInvitation(widget.societyId, member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation resent successfully!'), backgroundColor: Color(0xFF059669)),
      );
      _loadAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resend invitation: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleCancelInvitation(SocietyCommitteeModel comm, SocietyCommitteeMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invitation'),
        content: Text('Are you sure you want to cancel the pending invitation for ${member.userName ?? member.phone ?? "this user"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Invitation'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _societyService.cancelCommitteeInvitation(widget.societyId, member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation cancelled.'), backgroundColor: Color(0xFF059669)),
      );
      _loadAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel invitation: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSuspendMember(SocietyCommitteeModel comm, SocietyCommitteeMemberModel member) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend Committee Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suspending ${member.userName ?? "this member"} will immediately revoke all their committee PBAC permissions.'),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for suspension (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Suspend Member'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _societyService.suspendCommitteeMember(
        widget.societyId,
        comm.id,
        member.id,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member suspended. PBAC permissions revoked immediately.'), backgroundColor: Color(0xFFD97706)),
      );
      _loadAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to suspend member: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleRevokeMember(SocietyCommitteeModel comm, SocietyCommitteeMemberModel member) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Committee Membership'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to revoke ${member.userName ?? "this member"} from ${comm.name}?'),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason for revoking (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke Membership'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _societyService.revokeCommitteeMember(
        widget.societyId,
        comm.id,
        member.id,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership revoked.'), backgroundColor: Colors.red),
      );
      _loadAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to revoke member: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleActivateMember(SocietyCommitteeModel comm, SocietyCommitteeMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivate Committee Member'),
        content: Text('Reactivate ${member.userName ?? "this member"}? Their committee PBAC permissions will be restored immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _societyService.activateCommitteeMember(widget.societyId, comm.id, member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member reactivated. PBAC permissions restored immediately.'), backgroundColor: Color(0xFF059669)),
      );
      _loadAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reactivate member: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleRemoveMember(SocietyCommitteeModel comm, SocietyCommitteeMemberModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Committee'),
        content: Text('Are you sure you want to remove ${member.userName ?? "this member"} from ${comm.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _societyService.removeCommitteeMember(comm.id, member.userId, widget.societyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed from committee.'), backgroundColor: Color(0xFF059669)),
      );
      _loadAllData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove member: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEditPermissionsDialog(SocietyCommitteeModel comm) {
    final Set<String> perms = Set.from(comm.permissions);
    final allPerms = [
      'visitor.read',
      'visitor.create_gate_entry',
      'visitor.check_in',
      'visitor.check_out',
      'visitor.view_history',
      'guard.read',
      'guard.onboard',
      'guard.edit',
      'guard.activate',
      'guard.assign_gate',
      'guard.assign_shift',
      'gate.read',
      'gate.create',
      'shift.read',
      'shift.create',
      'security.dashboard.read',
      'security.reports.read',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Permissions for ${comm.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: allPerms
                  .map((p) => CheckboxListTile(
                        dense: true,
                        title: Text(p, style: const TextStyle(fontSize: 12)),
                        value: perms.contains(p),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              perms.add(p);
                            } else {
                              perms.remove(p);
                            }
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await _societyService.assignCommitteePermissions(comm.id, widget.societyId, perms.toList());
                if (ctx.mounted) Navigator.pop(ctx);
                _loadAllData();
              },
              child: const Text('Save Permissions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(msg, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade800;
    if (status == 'active' || status == 'approved' || status == 'checked_in') {
      bg = const Color(0xFFD1FAE5);
      fg = const Color(0xFF065F46);
    } else if (status == 'at_gate' || status == 'expected') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else if (status == 'denied' || status == 'inactive' || status == 'revoked') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
