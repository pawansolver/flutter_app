import 'package:flutter/material.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';
import '../../services/auth_session.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final SocietyComplaintModel complaint;
  final String userRole; // Defaults to resident view in Phase 1

  const ComplaintDetailScreen({
    super.key,
    required this.complaint,
    this.userRole = 'resident',
  });

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final _societyService = SocietyService();
  late SocietyComplaintModel _complaint;
  bool _isLoading = false;
  bool _isActionInProgress = false;
  int? _currentUserId;

  bool get _isManagementUser =>
      widget.userRole.toLowerCase() == 'admin' ||
      widget.userRole.toLowerCase() == 'committee' ||
      widget.userRole.toLowerCase() == 'owner';

  // Worker can manage their own assigned complaint regardless of role
  bool get _isAssignedWorker =>
      _currentUserId != null && _complaint.assignedTo == _currentUserId;

  List<SocietyComplaintHistoryItemModel> _history = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
    _loadCurrentUser();
    _refreshComplaint();
    _loadHistory();
  }

  Future<void> _loadCurrentUser() async {
    final userId = await AuthSessionStore().readUserId();
    if (mounted) setState(() => _currentUserId = userId);
  }

  Future<void> _refreshComplaint() async {
    setState(() => _isLoading = true);
    try {
      final updated = await _societyService.getComplaint(_complaint.id, _complaint.societyId);
      if (mounted) {
        setState(() {
          _complaint = updated;
          _isLoading = false;
        });
        _loadHistory();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);
    try {
      final items = await _societyService.getComplaintHistory(_complaint.id, _complaint.societyId);
      if (mounted) {
        setState(() {
          _history = items;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // Worker Action: Accept Task
  Future<void> _handleAcceptTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.task_alt, color: Color(0xFF0284C7), size: 24),
            SizedBox(width: 8),
            Text('Accept Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Accept this complaint task? You will be responsible for resolving it.',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept Task'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _isActionInProgress = true);
      try {
        final updated = await _societyService.updateComplaintStatus(
          _complaint.id, _complaint.societyId, status: 'accepted', remark: 'Task accepted by assigned worker',
        );
        if (mounted) {
          setState(() { _complaint = updated; _isActionInProgress = false; });
          _loadHistory();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task accepted. Please start work when ready.'), backgroundColor: Color(0xFF0284C7)));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isActionInProgress = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFEF4444)));
        }
      }
    }
  }

  // Management Action: Start Work
  Future<void> _handleStartWork() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.play_circle_outline, color: Color(0xFF0284C7), size: 24),
            SizedBox(width: 8),
            Text('Start Work', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Mark this complaint as IN PROGRESS to indicate that maintenance work has begun?',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Work'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isActionInProgress = true);
      try {
        final updated = await _societyService.updateComplaintStatus(
          _complaint.id,
          _complaint.societyId,
          status: 'in_progress',
          remark: 'Work started by management/staff',
        );
        if (mounted) {
          setState(() {
            _complaint = updated;
            _isActionInProgress = false;
          });
          _loadHistory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complaint status updated to IN PROGRESS.'),
              backgroundColor: Color(0xFF0284C7),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isActionInProgress = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  // Management Action: Mark Resolved
  Future<void> _handleMarkResolved() async {
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 8),
            Text('Resolve Complaint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Provide resolution notes describing the actions taken to fix the issue. The resident will be notified.',
                style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: noteController,
                maxLines: 3,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter resolution notes';
                  }
                  if (val.trim().length < 5) {
                    return 'Please provide more details (min 5 characters)';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Resolution Note *',
                  hintText: 'e.g., Replaced leaking valve and pressure tested.',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirm Resolution'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isActionInProgress = true);
      try {
        final updated = await _societyService.updateComplaintStatus(
          _complaint.id,
          _complaint.societyId,
          status: 'resolved',
          remark: noteController.text.trim(),
        );
        if (mounted) {
          setState(() {
            _complaint = updated;
            _isActionInProgress = false;
          });
          _loadHistory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complaint successfully marked as RESOLVED.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isActionInProgress = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  // Management Action: Open Assign Staff Modal
  Future<void> _showAssignStaffModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignStaffBottomSheet(
        societyId: _complaint.societyId,
        complaintId: _complaint.id,
        complaintCategory: _complaint.category,
        creatorUserId: _complaint.userId,
        currentAssigneeId: _complaint.assignedTo,
        onAssigned: (updated) {
          setState(() {
            _complaint = updated;
          });
          _refreshComplaint();
        },
      ),
    );
  }

  // Resident Action: Accept & Close
  Future<void> _handleAcceptAndClose() async {
    final remarkController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 8),
            Text('Accept & Close', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you satisfied with the resolution of this complaint? This will mark the ticket as CLOSED.',
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarkController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Optional Feedback Note',
                hintText: 'e.g., Fixed properly, thanks!',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Close'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isActionInProgress = true);
      try {
        final feedback = remarkController.text.trim().isEmpty ? null : remarkController.text.trim();
        final updated = await _societyService.closeComplaint(
          _complaint.id,
          _complaint.societyId,
          remark: feedback,
        );
        if (mounted) {
          setState(() {
            _complaint = updated;
            _isActionInProgress = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complaint successfully closed. Thank you!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isActionInProgress = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  // Resident Action: Reopen Complaint
  Future<void> _handleReopenComplaint() async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.replay, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('Reopen Complaint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please explain why you are reopening this complaint so the society team can address it properly.',
                style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for Reopening *',
                  hintText: 'e.g., The leak started again after technician left',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a reason';
                  }
                  if (val.trim().length < 5) {
                    return 'Please provide a clear reason (min 5 chars)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Reopen Ticket'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isActionInProgress = true);
      try {
        final reason = reasonController.text.trim();
        final updated = await _societyService.reopenComplaint(
          _complaint.id,
          _complaint.societyId,
          reason: reason,
        );
        if (mounted) {
          setState(() {
            _complaint = updated;
            _isActionInProgress = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complaint reopened. Society team has been notified.'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isActionInProgress = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          _complaint.ticketNumber,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF111827)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _refreshComplaint,
          ),
        ],
      ),
      body: _isLoading && !_isActionInProgress
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF111827)))
          : RefreshIndicator(
              color: const Color(0xFF111827),
              onRefresh: _refreshComplaint,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Reopened Warning Banner (if reopened)
                    if (_complaint.isReopened) ...[
                      _buildReopenedBanner(),
                      const SizedBox(height: 16),
                    ],

                    // 2. Ticket Hero Card
                    _buildTicketHeroCard(),
                    const SizedBox(height: 16),

                    // 3. Resident Information Card
                    _buildResidentInfoCard(),
                    const SizedBox(height: 16),

                    // 4. Location Details Card
                    if (_complaint.hasStructuredLocation) ...[
                      _buildLocationCard(),
                      const SizedBox(height: 16),
                    ],

                    // 5. Worker Action Card (if current user is assigned worker)
                    if (_isAssignedWorker && !_isManagementUser) ...[
                      _buildWorkerActionsCard(),
                      const SizedBox(height: 16),
                    ],

                    // 6. Management Action Card
                    if (_isManagementUser) ...[
                      _buildManagementActionsCard(),
                      const SizedBox(height: 16),
                    ],

                    // 7. Resident Action Banner (If Resolved & resident view)
                    if (_complaint.isResolved && !_isManagementUser && !_isAssignedWorker) ...[
                      _buildResidentResolutionActionCard(),
                      const SizedBox(height: 16),
                    ],

                    // 8. Closed State Banner
                    if (_complaint.isClosed) ...[
                      _buildClosedCard(),
                      const SizedBox(height: 16),
                    ],

                    // 9. Status Tracker / Stepper
                    _buildStatusTrackerCard(),
                    const SizedBox(height: 16),

                    // 10. Complaint Details Section
                    _buildComplaintDetailsCard(),
                    const SizedBox(height: 16),

                    // 11. Assignment Information Section
                    _buildAssignmentCard(),
                    const SizedBox(height: 16),

                    // 12. Resolution Information Section
                    if (_complaint.hasResolution || _complaint.isResolved || _complaint.isClosed) ...[
                      _buildResolutionCard(),
                      const SizedBox(height: 16),
                    ],

                    // 13. History Timeline Section
                    _buildHistoryTimelineCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ─── Ticket Hero Card ──────────────────────────────────────────────────────
  Widget _buildTicketHeroCard() {
    final statusColor = _getStatusColor(_complaint.status);
    final priorityColor = _getPriorityColor(_complaint.priority);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _complaint.ticketNumber,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _complaint.status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _complaint.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Category Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getCategoryIcon(_complaint.category), size: 13, color: const Color(0xFF4B5563)),
                    const SizedBox(width: 4),
                    Text(
                      _complaint.category.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                    ),
                  ],
                ),
              ),
              // Sub-category Chip
              if (_complaint.subCategory != null && _complaint.subCategory!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    _complaint.subCategory!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                  ),
                ),
              // Priority Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PRIORITY: ${_complaint.priority.toUpperCase()}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: priorityColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Structured Location Details Card ──────────────────────────────────────
  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF111827)),
              SizedBox(width: 8),
              Text(
                'Location & Premises',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_complaint.locationType != null && _complaint.locationType!.isNotEmpty) ...[
            _buildDetailRow('Location Type', _complaint.locationTypeDisplay),
            const SizedBox(height: 8),
          ],
          if (_complaint.flatNo != null && _complaint.flatNo!.isNotEmpty) ...[
            _buildDetailRow('Flat / Unit', _complaint.flatNo!),
            const SizedBox(height: 8),
          ],
          if (_complaint.exactLocation != null && _complaint.exactLocation!.isNotEmpty) ...[
            _buildDetailRow('Exact Location / Detail', _complaint.exactLocation!),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF111827)),
          ),
        ),
      ],
    );
  }

  // ─── Resident Resolution Action Card ───────────────────────────────────────
  Widget _buildResidentResolutionActionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5), // light emerald
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.verified, color: Color(0xFF047857), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Issue Marked as Resolved',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Society management has completed work on your complaint. Please verify if the problem is completely fixed.',
            style: TextStyle(color: Color(0xFF047857), fontSize: 13, height: 1.4),
          ),
          if (_complaint.remark != null && _complaint.remark!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resolution Note:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF065F46)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _complaint.remark!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isActionInProgress ? null : _handleAcceptAndClose,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text(
                    'Accept & Close',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isActionInProgress ? null : _handleReopenComplaint,
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text(
                    'Reopen Issue',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Closed State Banner ───────────────────────────────────────────────────
  Widget _buildClosedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF6B7280), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complaint Closed',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                ),
                Text(
                  _complaint.closedAt != null
                      ? 'Closed on ${_formatDate(_complaint.closedAt)}'
                      : 'This issue is archived.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _isActionInProgress ? null : _handleReopenComplaint,
            child: const Text('Reopen', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Status Lifecycle Tracker / Stepper ────────────────────────────────────
  Widget _buildStatusTrackerCard() {
    final status = _complaint.status.toLowerCase();

    final isStep1Done = true; // Submitted is always done
    final isStep2Done = status == 'assigned' || status == 'in_progress' || status == 'resolved' || status == 'closed';
    final isStep3Done = status == 'resolved' || status == 'closed';
    final isStep4Done = status == 'closed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complaint Progress',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 18),
          _buildTrackerStep(
            title: 'Submitted',
            subtitle: _complaint.createdAt != null ? _formatDateTime(_complaint.createdAt) : 'Ticket logged',
            isCompleted: isStep1Done,
            isCurrent: status == 'open',
            isLast: false,
          ),
          _buildTrackerStep(
            title: 'Assigned / In Progress',
            subtitle: _complaint.hasAssignee
                ? 'Assigned to ${_complaint.assigneeDisplay}'
                : (status == 'open' ? 'Awaiting staff assignment' : 'Under review'),
            isCompleted: isStep2Done,
            isCurrent: status == 'assigned' || status == 'in_progress',
            isLast: false,
          ),
          _buildTrackerStep(
            title: 'Resolved',
            subtitle: _complaint.resolvedAt != null
                ? 'Resolved on ${_formatDateTime(_complaint.resolvedAt)}'
                : (status == 'resolved' ? 'Work completed by team' : 'Pending resolution'),
            isCompleted: isStep3Done,
            isCurrent: status == 'resolved',
            isLast: false,
          ),
          _buildTrackerStep(
            title: 'Closed',
            subtitle: _complaint.closedAt != null
                ? 'Closed on ${_formatDateTime(_complaint.closedAt)}'
                : (status == 'closed' ? 'Ticket closed' : 'Resident sign-off'),
            isCompleted: isStep4Done,
            isCurrent: status == 'closed',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerStep({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    Color iconColor;
    IconData iconData;
    if (isCompleted) {
      iconColor = const Color(0xFF10B981);
      iconData = Icons.check_circle;
    } else if (isCurrent) {
      iconColor = const Color(0xFF3B82F6);
      iconData = Icons.radio_button_checked;
    } else {
      iconColor = const Color(0xFFD1D5DB);
      iconData = Icons.radio_button_unchecked;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(iconData, color: iconColor, size: 20),
            if (!isLast)
              Container(
                width: 2,
                height: 34,
                color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent || isCompleted ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent || isCompleted ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Complaint Details Section ─────────────────────────────────────────────
  Widget _buildComplaintDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Complaint Description',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 10),
          Text(
            _complaint.description,
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.5),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reported By', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              Text(_complaint.raisedByName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          if (_complaint.createdAt != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reported At', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                Text(_formatDateTime(_complaint.createdAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Assignment Information Section ────────────────────────────────────────
  Widget _buildAssignmentCard() {
    final hasStaff = _complaint.hasAssignee;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    hasStaff ? Icons.engineering_outlined : Icons.person_search_outlined,
                    color: hasStaff ? const Color(0xFF2563EB) : const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Staff Assignment',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ],
              ),
              if (_isManagementUser && !_complaint.isClosed)
                TextButton.icon(
                  onPressed: _isActionInProgress ? null : _showAssignStaffModal,
                  icon: const Icon(Icons.edit, size: 15, color: Color(0xFF2563EB)),
                  label: Text(
                    hasStaff ? 'Change' : 'Assign Staff',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasStaff) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    radius: 20,
                    child: Text(
                      _complaint.assigneeDisplay.isNotEmpty ? _complaint.assigneeDisplay[0].toUpperCase() : 'S',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _complaint.assigneeDisplay,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Assigned Technician / Staff',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                        if (_complaint.assigneePhone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Phone: ${_complaint.assigneePhone}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFF6B7280), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Society management has not assigned a technician yet. You will be notified once someone is assigned.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
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

  // ─── Resolution Information Section ────────────────────────────────────────
  Widget _buildResolutionCard() {
    final isResolvedOrClosed = _complaint.isResolved || _complaint.isClosed;
    final hasRemark = _complaint.remark != null && _complaint.remark!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isResolvedOrClosed ? Icons.task_alt : Icons.hourglass_empty,
                color: isResolvedOrClosed ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Resolution Details',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isResolvedOrClosed) ...[
            if (hasRemark) ...[
              const Text(
                'Staff / Management Remark:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  _complaint.remark!,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937), height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_complaint.resolvedAt != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Resolved Date', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  Text(_formatDateTime(_complaint.resolvedAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            if (_complaint.closedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Closed Date', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                  Text(_formatDateTime(_complaint.closedAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.pending_actions, color: Color(0xFF9CA3AF), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Resolution pending. Once work is completed by the team, the resolution details will be displayed here.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
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

  // ─── Reopened Complaint Warning Banner ────────────────────────────────────
  Widget _buildReopenedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF87171), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REOPENED COMPLAINT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'The resident was not satisfied with the previous resolution and reopened this complaint for further action.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), height: 1.3),
                ),
                if (_complaint.remark != null && _complaint.remark!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Reopen Reason: "${_complaint.remark}"',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: Color(0xFF7F1D1D)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Resident Information Card (Section B) ─────────────────────────────────
  Widget _buildResidentInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.person_outline, size: 18, color: Color(0xFF111827)),
              SizedBox(width: 8),
              Text(
                'Resident Information',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDetailRow('Resident Name', _complaint.raisedByName),
          const SizedBox(height: 8),
          _buildDetailRow('Flat / Unit', _complaint.residentFlatDisplay),
          if (_complaint.residentPhone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Contact Phone', _complaint.residentPhone),
          ],
          if (_complaint.residentEmail.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Email Address', _complaint.residentEmail),
          ],
          if (_complaint.createdAt != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Reported On', _formatDateTime(_complaint.createdAt)),
          ],
        ],
      ),
    );
  }

  // ─── Worker Task Actions Card (Assigned Worker Only) ──────────────────────
  Widget _buildWorkerActionsCard() {
    final status = _complaint.status.toLowerCase();

    // Determine what action is available based on state machine
    String? actionLabel;
    String? actionSubtitle;
    Color actionColor = const Color(0xFF0284C7);
    IconData actionIcon = Icons.task_alt;
    VoidCallback? onAction;

    if (status == 'assigned') {
      actionLabel = 'Accept Task';
      actionSubtitle = 'Acknowledge that you have received and will handle this complaint.';
      actionColor = const Color(0xFF0284C7);
      actionIcon = Icons.task_alt;
      onAction = _handleAcceptTask;
    } else if (status == 'accepted') {
      actionLabel = 'Start Work';
      actionSubtitle = 'Indicate that you have begun working on resolving this complaint.';
      actionColor = const Color(0xFF7C3AED);
      actionIcon = Icons.play_circle_outline;
      onAction = _handleStartWork;
    } else if (status == 'in_progress') {
      actionLabel = 'Mark Resolved';
      actionSubtitle = 'Submit your resolution notes. The resident will be notified to review.';
      actionColor = const Color(0xFF10B981);
      actionIcon = Icons.check_circle_outline;
      onAction = _handleMarkResolved;
    }

    final isWaiting = status == 'resolved' || status == 'closed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWaiting
              ? [const Color(0xFFD1FAE5), const Color(0xFFF0FDF4)]
              : [actionColor.withValues(alpha: 0.08), actionColor.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWaiting ? const Color(0xFF10B981).withValues(alpha: 0.3) : actionColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isWaiting ? const Color(0xFF10B981) : actionColor).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isWaiting ? Icons.hourglass_top_rounded : actionIcon,
                  color: isWaiting ? const Color(0xFF10B981) : actionColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWaiting ? 'Awaiting Resident Closure' : 'Your Task Action',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isWaiting ? const Color(0xFF065F46) : actionColor,
                      ),
                    ),
                    Text(
                      isWaiting
                          ? 'You have resolved this complaint. Waiting for the resident to close the ticket.'
                          : (actionSubtitle ?? ''),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isWaiting && onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isActionInProgress ? null : onAction,
                icon: _isActionInProgress
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(actionIcon, size: 18),
                label: Text(actionLabel ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actionColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Management Actions Card (Section J) ──────────────────────────────────
  Widget _buildManagementActionsCard() {
    final status = _complaint.status.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF0369A1), size: 22),
              SizedBox(width: 8),
              Text(
                'Management Controls',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Authorized Admin / Committee actions for this resident ticket:',
            style: TextStyle(color: Color(0xFF0284C7), fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (status == 'open') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isActionInProgress ? null : _showAssignStaffModal,
                    icon: const Icon(Icons.person_add_alt_1, size: 18),
                    label: const Text('Assign Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isActionInProgress ? null : _handleStartWork,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Start Work', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ] else if (status == 'assigned') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isActionInProgress ? null : _handleStartWork,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Start Work', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isActionInProgress ? null : _handleMarkResolved,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ] else if (status == 'in_progress') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isActionInProgress ? null : _handleMarkResolved,
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: const Text('Mark Resolved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4B5563),
                      side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isActionInProgress ? null : _showAssignStaffModal,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Reassign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ] else if (status == 'resolved') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF0284C7)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complaint is RESOLVED. Waiting for resident review to Close or Reopen.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0369A1), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (status == 'closed') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complaint is CLOSED. No further management action required.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w500),
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

  // ─── History / Activity Timeline Section (Section I) ──────────────────────
  Widget _buildHistoryTimelineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.history, size: 18, color: Color(0xFF111827)),
                  SizedBox(width: 8),
                  Text(
                    'Activity & Audit History',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                  ),
                ],
              ),
              if (_isLoadingHistory)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF6B7280)),
                  tooltip: 'Refresh History',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _loadHistory,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_history.isEmpty && !_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No activity history recorded yet.',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
            )
          else
            Column(
              children: List.generate(_history.length, (index) {
                final item = _history[index];
                final isLast = index == _history.length - 1;
                return _buildHistoryItem(item, isLast);
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(SocietyComplaintHistoryItemModel item, bool isLast) {
    Color iconColor = const Color(0xFF3B82F6);
    IconData iconData = Icons.radio_button_checked;

    final act = item.action.toLowerCase();
    if (act.contains('created')) {
      iconColor = const Color(0xFF10B981);
      iconData = Icons.add_circle_outline;
    } else if (act.contains('assigned')) {
      iconColor = const Color(0xFF8B5CF6);
      iconData = Icons.person_add_outlined;
    } else if (act.contains('progress')) {
      iconColor = const Color(0xFF0284C7);
      iconData = Icons.play_circle_outline;
    } else if (act.contains('resolved')) {
      iconColor = const Color(0xFF10B981);
      iconData = Icons.check_circle_outline;
    } else if (act.contains('reopened')) {
      iconColor = const Color(0xFFEF4444);
      iconData = Icons.replay;
    } else if (act.contains('closed')) {
      iconColor = const Color(0xFF6B7280);
      iconData = Icons.lock_outline;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(iconData, color: iconColor, size: 18),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                color: const Color(0xFFE5E7EB),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.actionTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF111827)),
                    ),
                    Text(
                      _formatDateTime(item.createdAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'By ${item.actorName}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                if (item.remark.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '"${item.remark}"',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF374151)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} $hour:$minute $period';
  }
}

// ─── Assign Staff Bottom Sheet (Enterprise Worker Matching) ─────────────────
class _AssignStaffBottomSheet extends StatefulWidget {
  final int societyId;
  final int complaintId;
  final String? complaintCategory;
  final int? creatorUserId;
  final int? currentAssigneeId;
  final ValueChanged<SocietyComplaintModel> onAssigned;

  const _AssignStaffBottomSheet({
    required this.societyId,
    required this.complaintId,
    this.complaintCategory,
    this.creatorUserId,
    this.currentAssigneeId,
    required this.onAssigned,
  });

  @override
  State<_AssignStaffBottomSheet> createState() => _AssignStaffBottomSheetState();
}

class _AssignStaffBottomSheetState extends State<_AssignStaffBottomSheet> {
  final _societyService = SocietyService();
  bool _isLoading = true;
  String? _error;

  List<EligibleWorkerModel> _recommendedWorkers = [];
  List<EligibleWorkerModel> _marketplaceWorkers = [];
  List<EligibleWorkerModel> _otherWorkers = [];
  List<SocietyMemberModel> _managementMembers = [];

  int? _selectedUserId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.currentAssigneeId;
    _fetchAssignees();
  }

  Future<void> _fetchAssignees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Fetch eligible workers (skill-matched + other authorized workers + marketplace providers)
      final workersMap = await _societyService.getEligibleWorkers(
        widget.societyId,
        category: widget.complaintCategory,
      ).catchError((_) => {'recommended': <EligibleWorkerModel>[], 'others': <EligibleWorkerModel>[], 'marketplace': <EligibleWorkerModel>[]});

      // 2. Fetch society members for management fallback (admin/committee)
      final membersRes = await _societyService.getMembers(
        widget.societyId,
        status: 'active',
        limit: 50,
      ).catchError((_) => const SocietyPaginatedResponse<SocietyMemberModel>(data: [], page: 1, limit: 50, total: 0, totalPages: 1));

      final rec = workersMap['recommended'] ?? [];
      final oth = workersMap['others'] ?? [];
      final mkt = workersMap['marketplace'] ?? [];

      // Management members who aren't creator and aren't already listed as workers
      final workerUserIds = {...rec.map((w) => w.userId), ...oth.map((w) => w.userId), ...mkt.map((w) => w.userId)};
      final mgmt = membersRes.data.where((m) {
        final role = m.role.toLowerCase();
        final isMgmt = role == 'admin' || role == 'committee';
        final isNotCreator = widget.creatorUserId == null || m.userId != widget.creatorUserId;
        final notInWorkers = !workerUserIds.contains(m.userId);
        return isMgmt && isNotCreator && notInWorkers;
      }).toList();

      if (mounted) {
        setState(() {
          _recommendedWorkers = rec.where((w) => widget.creatorUserId == null || w.userId != widget.creatorUserId).toList();
          _otherWorkers = oth.where((w) => widget.creatorUserId == null || w.userId != widget.creatorUserId).toList();
          _marketplaceWorkers = mkt.where((w) => widget.creatorUserId == null || w.userId != widget.creatorUserId).toList();
          _managementMembers = mgmt;
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

  Future<void> _handleConfirm() async {
    if (_selectedUserId == null) return;
    setState(() => _isSaving = true);
    try {
      final updated = await _societyService.assignComplaint(
        widget.complaintId,
        widget.societyId,
        assignedTo: _selectedUserId!,
        reason: 'Assigned via Mobile App',
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onAssigned(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Worker / Staff successfully assigned to complaint.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  // Quick dialog to authorize a new worker (e.g. plumber) by phone
  Future<void> _showAuthorizeWorkerDialog() async {
    final phoneCtrl = TextEditingController();
    final desigCtrl = TextEditingController(
      text: (widget.complaintCategory != null && widget.complaintCategory!.isNotEmpty)
          ? '${widget.complaintCategory![0].toUpperCase()}${widget.complaintCategory!.substring(1)} Specialist'
          : 'Plumber',
    );
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.person_add_alt_1, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Authorize Worker', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the registered mobile number of the worker (e.g., Plumber, Electrician) to authorize them for this society.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
                if (_marketplaceWorkers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Quick Select from Marketplace Partners:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _marketplaceWorkers.map((m) => ActionChip(
                      avatar: const Icon(Icons.handyman, size: 13, color: Color(0xFFFF6B00)),
                      label: Text(m.displayName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      backgroundColor: const Color(0xFFFFF7ED),
                      side: const BorderSide(color: Color(0xFFFFEDD5)),
                      onPressed: () {
                        setDlgState(() {
                          if (m.phone != null) phoneCtrl.text = m.phone!;
                          desigCtrl.text = m.designation;
                        });
                      },
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Worker Mobile Number *',
                    hintText: 'e.g. 9876543210',
                    prefixIcon: const Icon(Icons.phone, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desigCtrl,
                  decoration: InputDecoration(
                    labelText: 'Designation / Trade *',
                    hintText: 'e.g. Plumber, Electrician',
                    prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isSubmitting ? null : () async {
                final phone = phoneCtrl.text.trim();
                final desig = desigCtrl.text.trim();
                if (phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter mobile number'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }
                if (desig.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter designation'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                setDlgState(() => isSubmitting = true);
                try {
                  final newWorker = await _societyService.authorizeWorker(
                    widget.societyId,
                    phone: phone,
                    designation: desig,
                  );
                  if (mounted) {
                    Navigator.pop(dlgCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Worker "$desig" authorized successfully!'), backgroundColor: const Color(0xFF10B981)),
                    );
                    final newUserId = newWorker['user_id'] is int ? newWorker['user_id'] as int : int.tryParse(newWorker['user_id'].toString());
                    if (newUserId != null) {
                      _selectedUserId = newUserId;
                    }
                    _fetchAssignees();
                  }
                } catch (err) {
                  setDlgState(() => isSubmitting = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(err.toString()), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Authorize & Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _recommendedWorkers.length + _otherWorkers.length + _marketplaceWorkers.length + _managementMembers.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Worker to Complaint',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Complaint #${widget.complaintId}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                            if (widget.complaintCategory != null && widget.complaintCategory!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.complaintCategory!,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB), width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _showAuthorizeWorkerDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Worker', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(height: 20, color: Color(0xFFE5E7EB)),

            // Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF111827)))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 36),
                                const SizedBox(height: 8),
                                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 13)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _fetchAssignees,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111827), foregroundColor: Colors.white),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : totalCount == 0
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.engineering_outlined, size: 48, color: Color(0xFF9CA3AF)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No authorized workers found for this society.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Tap "+ Add Worker" above to authorize a plumber, electrician, or technician by mobile number.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                                      onPressed: _showAuthorizeWorkerDialog,
                                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                                      label: const Text('Authorize Plumber / Worker Now'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                // Section 1: Recommended Workers (Skill Matched)
                                if (_recommendedWorkers.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.stars, color: Color(0xFF059669), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'RECOMMENDED WORKERS (SKILL-MATCHED)',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669), letterSpacing: 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._recommendedWorkers.map((w) => _buildWorkerTile(
                                        userId: w.userId,
                                        title: w.displayName,
                                        designation: w.designation,
                                        skills: w.skills,
                                        phone: w.phone,
                                        isRecommended: true,
                                        badgeColor: const Color(0xFF059669),
                                        badgeText: 'RECOMMENDED',
                                      )),
                                  const SizedBox(height: 10),
                                ],

                                // Section 2: Verified Marketplace Partners (e.g. Anni)
                                if (_marketplaceWorkers.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.verified, color: Color(0xFFFF6B00), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'VERIFIED MARKETPLACE PARTNERS',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00), letterSpacing: 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._marketplaceWorkers.map((w) => _buildWorkerTile(
                                        userId: w.userId,
                                        title: w.displayName,
                                        designation: w.designation,
                                        skills: w.skills,
                                        phone: w.phone,
                                        isRecommended: false,
                                        badgeColor: const Color(0xFFFF6B00),
                                        badgeText: 'MARKETPLACE',
                                        isMarketplace: true,
                                        hourlyRate: w.hourlyRate,
                                      )),
                                  const SizedBox(height: 10),
                                ],

                                // Section 3: Other Authorized Workers
                                if (_otherWorkers.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.engineering, color: Color(0xFF2563EB), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'OTHER AUTHORIZED WORKERS',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB), letterSpacing: 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._otherWorkers.map((w) => _buildWorkerTile(
                                        userId: w.userId,
                                        title: w.displayName,
                                        designation: w.designation,
                                        skills: w.skills,
                                        phone: w.phone,
                                        isRecommended: false,
                                        badgeColor: const Color(0xFF2563EB),
                                        badgeText: w.designation,
                                      )),
                                  const SizedBox(height: 10),
                                ],

                                // Section 4: Society Management (Admin / Committee Fallback)
                                if (_managementMembers.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.shield_outlined, color: Color(0xFF6B7280), size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'SOCIETY MANAGEMENT (FALLBACK)',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ..._managementMembers.map((m) => _buildWorkerTile(
                                        userId: m.userId,
                                        title: m.memberName,
                                        designation: m.role.toUpperCase(),
                                        skills: m.flatNo != null ? 'Unit: ${m.flatNo}' : null,
                                        phone: null,
                                        isRecommended: false,
                                        badgeColor: const Color(0xFF6B7280),
                                        badgeText: m.role.toUpperCase(),
                                      )),
                                ],
                              ],
                            ),
            ),

            // Footer Action
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_selectedUserId == null || _isSaving) ? null : _handleConfirm,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Confirm Assignment',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerTile({
    required int userId,
    required String title,
    required String designation,
    String? skills,
    String? phone,
    required bool isRecommended,
    required Color badgeColor,
    required String badgeText,
    bool isMarketplace = false,
    double? hourlyRate,
  }) {
    final isSelected = userId == _selectedUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? const Color(0xFF2563EB)
              : (isMarketplace
                  ? const Color(0xFFFFF7ED)
                  : (isRecommended ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6))),
          child: Icon(
            isMarketplace
                ? Icons.handyman
                : (isRecommended ? Icons.build_circle : Icons.person),
            color: isSelected
                ? Colors.white
                : (isMarketplace
                    ? const Color(0xFFFF6B00)
                    : (isRecommended ? const Color(0xFF059669) : const Color(0xFF4B5563))),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: const Color(0xFF111827),
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                designation,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
              ),
              if (skills != null && skills.isNotEmpty && skills != designation)
                Text(
                  'Skills: $skills',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Row(
                children: [
                  if (phone != null && phone.isNotEmpty)
                    Text(
                      '📞 $phone',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  if (hourlyRate != null && hourlyRate > 0) ...[
                    if (phone != null && phone.isNotEmpty)
                      const Text(' • ', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
                    Text(
                      '₹${hourlyRate.toStringAsFixed(0)}/hr',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        trailing: Icon(
          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFD1D5DB),
        ),
        onTap: () {
          setState(() {
            _selectedUserId = userId;
          });
        },
      ),
    );
  }
}

