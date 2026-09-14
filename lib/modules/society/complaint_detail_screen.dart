import 'package:flutter/material.dart';
import '../../models/society_models.dart';
import '../../services/society_service.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final SocietyComplaintModel complaint;
  final String userRole; // 'admin' | 'committee' | 'resident'

  const ComplaintDetailScreen({
    super.key,
    required this.complaint,
    required this.userRole,
  });

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final _societyService = SocietyService();
  late SocietyComplaintModel _complaint;
  bool _isLoading = false;

  bool get _canManage =>
      widget.userRole.toLowerCase() == 'admin' ||
      widget.userRole.toLowerCase() == 'committee';

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
    _refreshComplaint();
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
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showUpdateStatusDialog() async {
    String selectedStatus = _complaint.status;
    final remarkController = TextEditingController();
    final statuses = ['open', 'in_progress', 'resolved', 'closed'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Update Complaint Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: statuses.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.replaceAll('_', ' ').toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedStatus = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarkController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Resolution Note',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Status'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        final updated = await _societyService.updateComplaintStatus(
          _complaint.id,
          _complaint.societyId,
          status: selectedStatus,
          remark: remarkController.text.trim().isEmpty ? null : remarkController.text.trim(),
        );
        if (mounted) {
          setState(() {
            _complaint = updated;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Status updated successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshComplaint,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshComplaint,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & Priority header
                    Row(
                      children: [
                        _buildStatusBadge(_complaint.status),
                        const SizedBox(width: 8),
                        _buildPriorityBadge(_complaint.priority),
                        const Spacer(),
                        Text(
                          _complaint.createdAt != null
                              ? '${_complaint.createdAt!.toLocal()}'.split(' ')[0]
                              : '',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      _complaint.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Category
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Category: ${_complaint.category.toUpperCase()}',
                        style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _complaint.description,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Metadata Card
                    Card(
                      elevation: 0,
                      color: Colors.grey.shade50,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildInfoRow('Raised By', _complaint.raisedByName),
                            const Divider(height: 16),
                            _buildInfoRow('Assigned To', _complaint.assigneeName.isNotEmpty ? _complaint.assigneeName : 'Unassigned'),
                            if (_complaint.resolvedAt != null) ...[
                              const Divider(height: 16),
                              _buildInfoRow('Resolved Date', '${_complaint.resolvedAt!.toLocal()}'.split(' ')[0]),
                            ],
                            if (_complaint.closedAt != null) ...[
                              const Divider(height: 16),
                              _buildInfoRow('Closed Date', '${_complaint.closedAt!.toLocal()}'.split(' ')[0]),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Admin update button
                    if (_canManage)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _showUpdateStatusDialog,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Update Status / Add Note'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.orange.shade50;
    Color fg = Colors.orange.shade800;

    switch (status.toLowerCase()) {
      case 'open':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
      case 'in_progress':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'resolved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'closed':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;

    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      case 'medium':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'low':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
