import 'package:flutter/material.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';
import '../../services/auth_session.dart';
import 'complaint_detail_screen.dart';

class ResidentComplaintsScreen extends StatefulWidget {
  final int? societyId;
  final bool autoOpenCreate;

  const ResidentComplaintsScreen({
    super.key,
    this.societyId,
    this.autoOpenCreate = false,
  });

  @override
  State<ResidentComplaintsScreen> createState() => _ResidentComplaintsScreenState();
}

class _ResidentComplaintsScreenState extends State<ResidentComplaintsScreen> {
  final _societyService = SocietyService();
  int? _resolvedSocietyId;
  String _societyName = 'Society';
  String? _registeredFlatNo;

  bool _isLoading = true;
  String? _errorMessage;
  List<SocietyComplaintModel> _complaints = [];
  String _activeFilter = 'all'; // 'all', 'open', 'in_progress', 'resolved', 'closed'

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _resolvedSocietyId = await _societyService.resolveActiveSocietyId(widget.societyId);
      if (_resolvedSocietyId != null) {
        try {
          final soc = await _societyService.getSocietyDetail(_resolvedSocietyId!);
          _societyName = soc.name;
        } catch (_) {}

        try {
          final userId = await AuthSessionStore().readUserId();
          if (userId != null) {
            final membersRes = await _societyService.getMembers(_resolvedSocietyId!, limit: 100);
            final me = membersRes.data.firstWhere(
              (m) => m.userId == userId,
              orElse: () => const SocietyMemberModel(
                id: 0,
                societyId: 0,
                userId: 0,
                role: 'member',
                status: 'active',
              ),
            );
            if (me.id > 0 && me.flatNo != null && me.flatNo!.trim().isNotEmpty) {
              _registeredFlatNo = me.flatNo!.trim();
            }
          }
        } catch (_) {}
      }

      await _loadComplaints();

      if (widget.autoOpenCreate && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCreateComplaintSheet();
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

  Future<void> _loadComplaints() async {
    if (_resolvedSocietyId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No active society found.';
        });
      }
      return;
    }

    try {
      // Backend automatically scopes complaints to caller user for non-admin residents
      final res = await _societyService.getComplaints(
        _resolvedSocietyId!,
        myOnly: true,
        limit: 100,
      );

      if (mounted) {
        setState(() {
          _complaints = res.data;
          _isLoading = false;
          _errorMessage = null;
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

  List<SocietyComplaintModel> get _filteredComplaints {
    if (_activeFilter == 'all') return _complaints;
    if (_activeFilter == 'open') {
      return _complaints.where((c) => c.status.toLowerCase() == 'open').toList();
    }
    if (_activeFilter == 'in_progress') {
      return _complaints.where((c) =>
          c.status.toLowerCase() == 'in_progress' ||
          c.status.toLowerCase() == 'assigned').toList();
    }
    if (_activeFilter == 'resolved') {
      return _complaints.where((c) => c.status.toLowerCase() == 'resolved').toList();
    }
    if (_activeFilter == 'closed') {
      return _complaints.where((c) => c.status.toLowerCase() == 'closed').toList();
    }
    return _complaints;
  }

  int get _countTotal => _complaints.length;
  int get _countActive => _complaints.where((c) =>
      c.status.toLowerCase() == 'open' ||
      c.status.toLowerCase() == 'assigned' ||
      c.status.toLowerCase() == 'in_progress').length;
  int get _countResolved => _complaints.where((c) =>
      c.status.toLowerCase() == 'resolved').length;
  int get _countClosed => _complaints.where((c) =>
      c.status.toLowerCase() == 'closed').length;

  void _showCreateComplaintSheet() {
    if (_resolvedSocietyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active society selected')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateComplaintModal(
        societyId: _resolvedSocietyId!,
        registeredFlatNo: _registeredFlatNo,
        onSuccess: (newComplaint) {
          _loadComplaints();
          _showTicketGeneratedDialog(newComplaint);
        },
      ),
    );
  }

  void _showTicketGeneratedDialog(SocietyComplaintModel complaint) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Complaint Submitted!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your complaint has been successfully registered with society management.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'TICKET NUMBER',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      complaint.ticketNumber,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'STATUS: OPEN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComplaintDetailScreen(
                          complaint: complaint,
                          userRole: 'resident',
                        ),
                      ),
                    ).then((_) => _loadComplaints());
                  },
                  child: const Text(
                    'Track Complaint Details',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredComplaints;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Complaints',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            Text(
              _societyName,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadComplaints,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF111827),
        elevation: 3,
        onPressed: _showCreateComplaintSheet,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Raise Complaint',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF111827)),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF374151), fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initData,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111827)),
                          child: const Text('Try Again', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF111827),
                  onRefresh: _loadComplaints,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Summary Stat Strip
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              _buildSummaryCard(
                                'Total',
                                '$_countTotal',
                                Icons.folder_open_outlined,
                                const Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 8),
                              _buildSummaryCard(
                                'In Progress',
                                '$_countActive',
                                Icons.pending_actions_outlined,
                                const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 8),
                              _buildSummaryCard(
                                'Resolved',
                                '$_countResolved',
                                Icons.task_alt_outlined,
                                const Color(0xFF10B981),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Filter Bar
                      SliverToBoxAdapter(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              _buildFilterChip('All ($_countTotal)', 'all'),
                              const SizedBox(width: 8),
                              _buildFilterChip('Open', 'open'),
                              const SizedBox(width: 8),
                              _buildFilterChip('In Progress', 'in_progress'),
                              const SizedBox(width: 8),
                              _buildFilterChip('Resolved ($_countResolved)', 'resolved'),
                              const SizedBox(width: 8),
                              _buildFilterChip('Closed ($_countClosed)', 'closed'),
                            ],
                          ),
                        ),
                      ),

                      // Complaints List
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
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
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.assignment_turned_in_outlined,
                                      size: 48,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _activeFilter == 'all'
                                        ? 'No complaints registered yet'
                                        : 'No complaints in "${_activeFilter.replaceAll('_', ' ').toUpperCase()}"',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Need help with plumbing, electrical, lift, or maintenance? Log a ticket and society management will assist you.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.4),
                                  ),
                                  const SizedBox(height: 20),
                                  OutlinedButton.icon(
                                    onPressed: _showCreateComplaintSheet,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Raise Complaint Now'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF111827),
                                      side: const BorderSide(color: Color(0xFF111827)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final c = filtered[index];
                                return _buildComplaintCard(c);
                              },
                              childCount: filtered.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _activeFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildComplaintCard(SocietyComplaintModel c) {
    final statusColor = _getStatusColor(c.status);
    final priorityColor = _getPriorityColor(c.priority);
    final categoryIcon = _getCategoryIcon(c.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.isResolved
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFFE5E7EB),
          width: c.isResolved ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ComplaintDetailScreen(
                  complaint: c,
                  userRole: 'resident',
                ),
              ),
            ).then((_) => _loadComplaints());
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Ticket Number & Status / Priority Badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        c.ticketNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF111827),
                          letterSpacing: 0.5,
                        ),
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
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                    // Priority chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Status pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        c.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Category & Sub-Category Badges (Wrap ensures zero overflow)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(categoryIcon, size: 12, color: const Color(0xFF4B5563)),
                          const SizedBox(width: 4),
                          Text(
                            c.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (c.subCategory != null && c.subCategory!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        child: Text(
                          c.subCategory!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Complaint Title
                Text(
                  c.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Description preview
                Text(
                  c.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
                if (c.hasStructuredLocation) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.locationDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B5563),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // Bottom strip: Assignment & Date
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      c.hasAssignee ? Icons.person_outline : Icons.schedule,
                      size: 14,
                      color: c.hasAssignee ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.hasAssignee
                            ? 'Assigned: ${c.assigneeDisplay}'
                            : 'Awaiting Staff Assignment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.hasAssignee ? const Color(0xFF1D4ED8) : const Color(0xFF6B7280),
                          fontWeight: c.hasAssignee ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (c.createdAt != null)
                      Text(
                        '${c.createdAt!.day.toString().padLeft(2, '0')}/${c.createdAt!.month.toString().padLeft(2, '0')}/${c.createdAt!.year}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                  ],
                ),

                // Action Callout for Resolved items
                if (c.isResolved) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.touch_app, size: 16, color: Color(0xFF047857)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Resolved by society • Tap to Accept or Reopen',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 16, color: Color(0xFF047857)),
                      ],
                    ),
                  ),
                ],
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
        return const Color(0xFF2563EB); // Blue
      case 'assigned':
      case 'in_progress':
        return const Color(0xFFF59E0B); // Amber
      case 'resolved':
        return const Color(0xFF10B981); // Emerald
      case 'closed':
        return const Color(0xFF6B7280); // Grey
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
      case 'high':
        return const Color(0xFFEF4444); // Red
      case 'medium':
        return const Color(0xFFF59E0B); // Amber
      case 'low':
        return const Color(0xFF10B981); // Green
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
}

// ─── Bottom Sheet for Raising a New Complaint ──────────────────────────────
class _CreateComplaintModal extends StatefulWidget {
  final int societyId;
  final String? registeredFlatNo;
  final Function(SocietyComplaintModel newComplaint) onSuccess;

  const _CreateComplaintModal({
    required this.societyId,
    this.registeredFlatNo,
    required this.onSuccess,
  });

  @override
  State<_CreateComplaintModal> createState() => _CreateComplaintModalState();
}

class _CreateComplaintModalState extends State<_CreateComplaintModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late final TextEditingController _flatController;
  final _exactLocationController = TextEditingController();
  final _societyService = SocietyService();

  String _selectedCategory = 'general';
  String? _selectedSubCategory;
  String _selectedLocationType = 'my_flat';
  String _selectedPriority = 'medium';
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _categories = [
    {'id': 'general', 'name': 'General', 'icon': Icons.assignment_outlined},
    {'id': 'plumbing', 'name': 'Plumbing', 'icon': Icons.plumbing_outlined},
    {'id': 'electrical', 'name': 'Electrical', 'icon': Icons.bolt_outlined},
    {'id': 'lift', 'name': 'Lift', 'icon': Icons.elevator_outlined},
    {'id': 'security', 'name': 'Security', 'icon': Icons.shield_outlined},
    {'id': 'maintenance', 'name': 'Maintenance', 'icon': Icons.build_outlined},
  ];

  Map<String, List<String>> _subCategoriesByCategory = {
    'plumbing': [
      'Water Leakage',
      'Pipe Blockage',
      'Tap / Faucet',
      'Drainage / Overflow',
      'Low Water Pressure',
      'Other Plumbing Issue',
    ],
    'electrical': [
      'Power Outage / MCB',
      'Light / Bulb',
      'Switch / Socket',
      'Wiring / Sparking',
      'Fan / Appliance',
      'Other Electrical Issue',
    ],
    'maintenance': [
      'Civil Work / Wall Cracks',
      'Cleaning / Housekeeping',
      'Painting / Plaster',
      'Door / Window Repair',
      'Pest Control',
      'Other Maintenance',
    ],
    'lift': [
      'Lift Stopped / Stuck',
      'Door Not Closing',
      'Noise / Jerk During Movement',
      'Display / Button Fault',
      'Other Lift Issue',
    ],
    'security': [
      'Visitor / Gate Issue',
      'Boom Barrier Fault',
      'CCTV / Camera Offline',
      'Guard Unavailability',
      'Other Security Issue',
    ],
    'general': [
      'Noise Disturbance',
      'Garbage Disposal',
      'Common Facility Issue',
      'Other General Issue',
    ],
  };

  List<Map<String, dynamic>> _locationTypes = [
    {'id': 'my_flat', 'name': 'My Flat', 'icon': Icons.home_outlined},
    {'id': 'common_area', 'name': 'Common Area', 'icon': Icons.apartment_outlined},
    {'id': 'parking', 'name': 'Parking', 'icon': Icons.local_parking_outlined},
    {'id': 'lift', 'name': 'Lift', 'icon': Icons.elevator_outlined},
    {'id': 'garden', 'name': 'Garden', 'icon': Icons.park_outlined},
    {'id': 'clubhouse', 'name': 'Clubhouse', 'icon': Icons.sports_tennis_outlined},
    {'id': 'other', 'name': 'Other', 'icon': Icons.place_outlined},
  ];

  final List<String> _priorities = const ['low', 'medium', 'high', 'urgent'];

  IconData _iconForCategorySlug(String slug) {
    switch (slug.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing_outlined;
      case 'electrical':
        return Icons.bolt_outlined;
      case 'lift':
        return Icons.elevator_outlined;
      case 'security':
        return Icons.shield_outlined;
      case 'maintenance':
        return Icons.build_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  IconData _iconForLocationCode(String code) {
    switch (code.toLowerCase()) {
      case 'my_flat':
        return Icons.home_outlined;
      case 'common_area':
        return Icons.apartment_outlined;
      case 'parking':
        return Icons.local_parking_outlined;
      case 'lift':
        return Icons.elevator_outlined;
      case 'garden':
        return Icons.park_outlined;
      case 'clubhouse':
        return Icons.sports_tennis_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  Future<void> _loadDynamicMasters() async {
    try {
      final results = await Future.wait([
        _societyService.getComplaintCategories(),
        _societyService.getComplaintSubCategories(),
        _societyService.getComplaintLocationTypes(),
      ]);

      final catsData = results[0];
      final subsData = results[1];
      final locsData = results[2];

      if (mounted) {
        setState(() {
          if (catsData.isNotEmpty) {
            _categories = catsData.map((c) {
              final slug = (c['slug'] ?? c['name'] ?? '').toString().toLowerCase();
              return {
                'id': slug,
                'name': (c['name'] ?? '').toString(),
                'icon': _iconForCategorySlug(slug),
              };
            }).toList();

            final Map<String, List<String>> newSubs = {};
            final Map<int, String> categoryIdToSlug = {};
            for (final c in catsData) {
              final id = c['id'] is int ? c['id'] as int : int.tryParse(c['id'].toString()) ?? 0;
              final slug = (c['slug'] ?? c['name'] ?? '').toString().toLowerCase();
              categoryIdToSlug[id] = slug;
              newSubs[slug] = [];
            }

            for (final s in subsData) {
              final catId = s['category_id'] is int ? s['category_id'] as int : int.tryParse(s['category_id'].toString()) ?? 0;
              final catSlug = categoryIdToSlug[catId];
              final subName = (s['name'] ?? '').toString();
              if (catSlug != null && subName.isNotEmpty) {
                newSubs[catSlug]?.add(subName);
              }
            }

            if (newSubs.isNotEmpty) {
              _subCategoriesByCategory = newSubs;
            }

            if (!_categories.any((c) => c['id'] == _selectedCategory) && _categories.isNotEmpty) {
              _selectedCategory = _categories.first['id'] as String;
            }
          }

          if (locsData.isNotEmpty) {
            _locationTypes = locsData.map((l) {
              final code = (l['code'] ?? l['name'] ?? '').toString().toLowerCase().replaceAll(' ', '_');
              return {
                'id': code,
                'name': (l['name'] ?? '').toString(),
                'icon': _iconForLocationCode(code),
              };
            }).toList();

            if (!_locationTypes.any((l) => l['id'] == _selectedLocationType) && _locationTypes.isNotEmpty) {
              _selectedLocationType = _locationTypes.first['id'] as String;
            }
          }
        });
      }
    } catch (_) {
      // Fallback defaults preserved
    }
  }

  @override
  void initState() {
    super.initState();
    _flatController = TextEditingController(text: widget.registeredFlatNo ?? '');
    _loadDynamicMasters();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _flatController.dispose();
    _exactLocationController.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final flatNo = _selectedLocationType == 'my_flat' ? _flatController.text.trim() : null;
    final exactLoc = _exactLocationController.text.trim();

    try {
      SocietyComplaintModel created;
      try {
        created = await _societyService.createComplaint(
          widget.societyId,
          title: title,
          description: description,
          category: _selectedCategory,
          subCategory: _selectedSubCategory,
          locationType: _selectedLocationType,
          flatNo: (flatNo != null && flatNo.isNotEmpty) ? flatNo : null,
          exactLocation: exactLoc.isNotEmpty ? exactLoc : null,
          priority: _selectedPriority,
        );
      } on SocietyServiceException catch (e) {
        if (e.statusCode == 403) {
          // Auto-join society and retry
          await _societyService.joinSociety(widget.societyId);
          created = await _societyService.createComplaint(
            widget.societyId,
            title: title,
            description: description,
            category: _selectedCategory,
            subCategory: _selectedSubCategory,
            locationType: _selectedLocationType,
            flatNo: (flatNo != null && flatNo.isNotEmpty) ? flatNo : null,
            exactLocation: exactLoc.isNotEmpty ? exactLoc : null,
            priority: _selectedPriority,
          );
        } else {
          rethrow;
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess(created);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxModalHeight = MediaQuery.of(context).size.height * 0.90;
    final availableSubCategories = _subCategoriesByCategory[_selectedCategory] ?? [];

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: maxModalHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: bottomInset + 16,
          left: 20,
          right: 20,
          top: 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag indicator
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Raise Complaint',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Report an issue to society maintenance team',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ──────────────────────────────────────────
                // A. CATEGORY
                // ──────────────────────────────────────────
                const Text(
                  'A. Category *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat['id'];
                    return ChoiceChip(
                      avatar: Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFF4B5563),
                      ),
                      label: Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF111827),
                      backgroundColor: const Color(0xFFF3F4F6),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedCategory = cat['id'] as String;
                            _selectedSubCategory = null; // reset sub-category on change
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ──────────────────────────────────────────
                // B. SUB-CATEGORY (Dynamic based on Category)
                // ──────────────────────────────────────────
                Row(
                  children: [
                    const Text(
                      'B. Sub-category',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${_selectedCategory.toUpperCase()})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (availableSubCategories.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSubCategories.map((subCat) {
                      final isSelected = _selectedSubCategory == subCat;
                      return ChoiceChip(
                        label: Text(
                          subCat,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : const Color(0xFF374151),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF3F4F6),
                        onSelected: (val) {
                          setState(() {
                            _selectedSubCategory = val ? subCat : null;
                          });
                        },
                      );
                    }).toList(),
                  )
                else
                  const Text(
                    'No sub-categories available for this category.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                const SizedBox(height: 18),

                // ──────────────────────────────────────────
                // C. COMPLAINT TITLE
                // ──────────────────────────────────────────
                const Text(
                  'C. Complaint Title *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  maxLength: 150,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                      null, // Clean UI without counter clutter
                  decoration: InputDecoration(
                    hintText: 'e.g., Water leakage in bathroom',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a complaint title';
                    }
                    if (val.trim().length < 3) {
                      return 'Title must be at least 3 characters';
                    }
                    if (val.trim().length > 150) {
                      return 'Title cannot exceed 150 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ──────────────────────────────────────────
                // D. STRUCTURED LOCATION
                // ──────────────────────────────────────────
                const Text(
                  'D. Location & Premises *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select the premise area where maintenance is required',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),

                // Location Type Choice Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _locationTypes.map((loc) {
                    final isSelected = _selectedLocationType == loc['id'];
                    return ChoiceChip(
                      avatar: Icon(
                        loc['icon'] as IconData,
                        size: 15,
                        color: isSelected ? Colors.white : const Color(0xFF4B5563),
                      ),
                      label: Text(
                        loc['name'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF111827),
                      backgroundColor: const Color(0xFFF3F4F6),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedLocationType = loc['id'] as String;
                            if (_selectedLocationType == 'my_flat' &&
                                _flatController.text.trim().isEmpty &&
                                widget.registeredFlatNo?.isNotEmpty == true) {
                              _flatController.text = widget.registeredFlatNo!;
                            }
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),

                // If My Flat is selected, show Flat/Unit field
                if (_selectedLocationType == 'my_flat') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Flat / Unit Number *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF4B5563)),
                      ),
                      if (widget.registeredFlatNo != null && widget.registeredFlatNo!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check, size: 10, color: Color(0xFF059669)),
                              SizedBox(width: 3),
                              Text(
                                'Registered Unit',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _flatController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Flat 402, Tower B',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (_selectedLocationType == 'my_flat' && (val == null || val.trim().isEmpty)) {
                        return 'Please provide your flat/unit number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Exact Location / Landmark (Optional)
                const Text(
                  'Exact Location / Landmark (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _exactLocationController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Master bathroom, basement parking slot #14, near lift lobby',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ──────────────────────────────────────────
                // E. PRIORITY
                // ──────────────────────────────────────────
                const Text(
                  'E. Priority',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _priorities.map((p) {
                    final isSelected = _selectedPriority == p;
                    Color chipColor;
                    if (p == 'urgent') {
                      chipColor = const Color(0xFFEF4444);
                    } else if (p == 'high') {
                      chipColor = const Color(0xFFF97316);
                    } else if (p == 'medium') {
                      chipColor = const Color(0xFFF59E0B);
                    } else {
                      chipColor = const Color(0xFF10B981);
                    }

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedPriority = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected ? chipColor : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? chipColor : const Color(0xFFE5E7EB),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              p.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ──────────────────────────────────────────
                // F. DESCRIPTION
                // ──────────────────────────────────────────
                const Text(
                  'F. Description & Details *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe the problem, symptoms, and any useful details...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    contentPadding: const EdgeInsets.all(14),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please describe the issue';
                    }
                    if (val.trim().length < 8) {
                      return 'Please provide more detail (at least 8 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ──────────────────────────────────────────
                // I. SUBMIT COMPLAINT
                // ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _submitComplaint,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit Complaint',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
}
