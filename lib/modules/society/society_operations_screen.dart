import 'package:flutter/material.dart';
import '../dashboard/main_dashboard.dart';
import 'complaint_detail_screen.dart';
import '../../services/society_service.dart';
import '../../services/auth_session.dart';
import '../../models/society_models.dart';

class SocietyOperationsScreen extends StatefulWidget {
  final int initialTab;
  final int? societyId;

  const SocietyOperationsScreen({
    super.key,
    this.initialTab = 0,
    this.societyId,
  });

  @override
  State<SocietyOperationsScreen> createState() => _SocietyOperationsScreenState();
}

class _SocietyOperationsScreenState extends State<SocietyOperationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SocietyService _societyService = SocietyService();

  int? _resolvedSocietyId;
  String _userRole = 'resident';
  int? _currentUserId;
  String? _myFlatNo;

  // Complaints State
  bool _isLoadingComplaints = true;
  List<SocietyComplaintModel> _complaints = [];
  String _complaintFilter = 'all';

  // Visitors State
  bool _isLoadingVisitors = true;
  List<SocietyVisitorModel> _visitors = [];
  String _visitorFilter = 'all';

  // Polls State
  bool _isLoadingPolls = true;
  List<SocietyPollModel> _polls = [];

  @override
  void initState() {
    super.initState();
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
        if (_currentUserId != null) {
          final soc = await _societyService.getSocietyDetail(_resolvedSocietyId!);
          if (soc.userId == _currentUserId || soc.createdBy == _currentUserId) {
            _userRole = 'admin';
          } else {
            final membersRes = await _societyService.getMembers(_resolvedSocietyId!, limit: 100);
            final me = membersRes.data.firstWhere(
              (m) => m.userId == _currentUserId,
              orElse: () => const SocietyMemberModel(
                id: 0,
                societyId: 0,
                userId: 0,
                role: 'resident',
                status: 'active',
              ),
            );
            if (me.id > 0) {
              _userRole = me.role.toLowerCase();
              _myFlatNo = me.flatNo;
            }
          }
        }
      } catch (_) {}

      _loadComplaints();
      _loadVisitors();
      _loadPolls();
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
      final res = await _societyService.getComplaints(
        _resolvedSocietyId!,
        status: _complaintFilter == 'all' ? null : _complaintFilter,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _complaints = res.data;
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
        status: _visitorFilter == 'all' ? null : _visitorFilter,
        limit: 50,
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
          title: const Text(
            'Society Operations',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                _filterChip('In Progress', 'in_progress', _complaintFilter, (val) {
                  setState(() => _complaintFilter = val);
                  _loadComplaints();
                }),
                const SizedBox(width: 8),
                _filterChip('Resolved', 'resolved', _complaintFilter, (val) {
                  setState(() => _complaintFilter = val);
                  _loadComplaints();
                }),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingComplaints
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : RefreshIndicator(
                    color: const Color(0xFFFF6B00),
                    onRefresh: _loadComplaints,
                    child: _complaints.isEmpty
                        ? const Center(
                            child: Text('No complaints found',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            itemCount: _complaints.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final c = _complaints[index];
                              final isOpen = c.isOpen;
                              final isResolved = c.isResolved;
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFF111827),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isResolved
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                                  : isOpen
                                                      ? const Color(0xFFFF6B00).withValues(alpha: 0.1)
                                                      : Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              c.status.toUpperCase(),
                                              style: TextStyle(
                                                color: isResolved
                                                    ? const Color(0xFF10B981)
                                                    : isOpen
                                                        ? const Color(0xFFFF6B00)
                                                        : Colors.blue,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        c.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              c.category.toUpperCase(),
                                              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const Spacer(),
                                          const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            c.createdAt != null
                                                ? '${c.createdAt!.day}/${c.createdAt!.month}/${c.createdAt!.year}'
                                                : '',
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
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

  // ─── TAB 2: VISITORS ─────────────────────────────────────────────────────
  Widget _buildVisitorsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFE1EAE4),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        onPressed: _showPreApproveGuestModal,
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: const Text('Pre-Approve Guest',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _filterChip('All', 'all', _visitorFilter, (val) {
                  setState(() => _visitorFilter = val);
                  _loadVisitors();
                }),
                const SizedBox(width: 8),
                _filterChip('At Gate', 'at_gate', _visitorFilter, (val) {
                  setState(() => _visitorFilter = val);
                  _loadVisitors();
                }),
                const SizedBox(width: 8),
                _filterChip('Expected', 'expected', _visitorFilter, (val) {
                  setState(() => _visitorFilter = val);
                  _loadVisitors();
                }),
                const SizedBox(width: 8),
                _filterChip('Checked In', 'checked_in', _visitorFilter, (val) {
                  setState(() => _visitorFilter = val);
                  _loadVisitors();
                }),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingVisitors
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)))
                : RefreshIndicator(
                    color: const Color(0xFFFF6B00),
                    onRefresh: _loadVisitors,
                    child: _visitors.isEmpty
                        ? const Center(
                            child: Text('No visitor records found',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: _visitors.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final v = _visitors[index];
                              final atGate = v.isAtGate;
                              final isApproved = v.isApproved;
                              final isCheckedIn = v.isCheckedIn;

                              final statusColor = atGate
                                  ? const Color(0xFFFF6B00)
                                  : isApproved || isCheckedIn
                                      ? const Color(0xFF10B981)
                                      : Colors.grey;

                              final canManageVisitor = _userRole == 'admin' ||
                                  _userRole == 'security' ||
                                  _userRole == 'committee' ||
                                  (v.userId != null && v.userId == _currentUserId) ||
                                  (_myFlatNo != null && v.flatNo != null && _myFlatNo!.toLowerCase() == v.flatNo!.toLowerCase());

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: atGate ? const Color(0xFFFF6B00) : const Color(0xFFE5E7EB)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: statusColor.withValues(alpha: 0.15),
                                          child: Icon(
                                            v.purpose?.toLowerCase().contains('delivery') == true
                                                ? Icons.local_shipping_outlined
                                                : Icons.person_outline,
                                            color: statusColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(v.visitorName,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                      color: Color(0xFF111827))),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  if (v.flatNo != null) ...[
                                                    Text('Flat ${v.flatNo}',
                                                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  Text(v.purpose ?? 'Visit',
                                                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(v.status.replaceAll('_', ' ').toUpperCase(),
                                              style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    if (atGate && canManageVisitor) ...[
                                      const SizedBox(height: 14),
                                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.redAccent,
                                                side: BorderSide(color: Colors.red.shade200),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () async {
                                                await _societyService.updateVisitorStatus(
                                                  v.id,
                                                  _resolvedSocietyId!,
                                                  status: 'denied',
                                                );
                                                _loadVisitors();
                                              },
                                              child: const Text('Deny Entry'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 2,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF10B981),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () async {
                                                await _societyService.updateVisitorStatus(
                                                  v.id,
                                                  _resolvedSocietyId!,
                                                  status: 'approved',
                                                );
                                                _loadVisitors();
                                              },
                                              child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showPreApproveGuestModal() {
    if (_resolvedSocietyId == null) return;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final flatController = TextEditingController();
    final purposeController = TextEditingController(text: 'Guest');
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
                  const Text('Pre-Approve Visitor',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              _modalField('Visitor Name', 'e.g., John Doe', nameController),
              const SizedBox(height: 14),
              _modalField('Visitor Phone', 'e.g., 9876543210', phoneController),
              const SizedBox(height: 14),
              _modalField('Flat Number', 'e.g., A-401', flatController),
              const SizedBox(height: 14),
              _modalField('Purpose', 'Guest, Delivery, Service...', purposeController),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
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
                            try {
                              await _societyService.createVisitor(
                                _resolvedSocietyId!,
                                visitorName: name,
                                visitorPhone: phoneController.text.trim(),
                                flatNo: flatController.text.trim(),
                                purpose: purposeController.text.trim(),
                              );
                            } on SocietyServiceException catch (e) {
                              if (e.statusCode == 403) {
                                // Auto-join society and retry
                                await _societyService.joinSociety(_resolvedSocietyId!);
                                await _societyService.createVisitor(
                                  _resolvedSocietyId!,
                                  visitorName: name,
                                  visitorPhone: phoneController.text.trim(),
                                  flatNo: flatController.text.trim(),
                                  purpose: purposeController.text.trim(),
                                );
                              } else {
                                rethrow;
                              }
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadVisitors();
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Gate pass generated successfully!'),
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
                      : const Text('Generate Gate Pass',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
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
}
