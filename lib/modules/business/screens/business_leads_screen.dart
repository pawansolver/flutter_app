import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';

class BusinessLeadsScreen extends StatefulWidget {
  final int businessId;
  const BusinessLeadsScreen({super.key, required this.businessId});

  @override
  State<BusinessLeadsScreen> createState() => _BusinessLeadsScreenState();
}

class _BusinessLeadsScreenState extends State<BusinessLeadsScreen> {
  final BusinessService _service = BusinessService();
  List<BusinessLeadModel> _leads = [];
  bool _isLoading = true;
  String _activeFilter = 'ALL';

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    setState(() => _isLoading = true);
    final list = await _service.getLeads(widget.businessId);
    if (!mounted) return;
    setState(() {
      _leads = list;
      _isLoading = false;
    });
  }

  List<BusinessLeadModel> get _filteredLeads {
    if (_activeFilter == 'ALL') return _leads;
    return _leads.where((l) => l.status == _activeFilter).toList();
  }

  void _showUpdateStatusSheet(BusinessLeadModel lead) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update Lead Status: ${lead.customerName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              ...['NEW', 'CONTACTED', 'CONVERTED', 'CLOSED'].map((status) {
                final isSelected = lead.status == status;
                return ListTile(
                  title: Text(
                    status,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? _brandOrange : _primaryDark,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: _brandOrange) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _service.updateLeadStatus(lead.id, status);
                    _loadLeads();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLeads;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Customer Inquiries & Leads',
          style: TextStyle(color: _primaryDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _primaryDark),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'NEW', 'CONTACTED', 'CONVERTED', 'CLOSED'].map((tab) {
                  final isSel = _activeFilter == tab;
                  return GestureDetector(
                    onTap: () => setState(() => _activeFilter = tab),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? _brandOrange : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel ? _brandOrange : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          color: isSel ? Colors.white : _primaryDark,
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Leads List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _brandOrange))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox_outlined, size: 54, color: _subGrey),
                            const SizedBox(height: 12),
                            Text(
                              'No $_activeFilter leads found',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryDark),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final lead = filtered[index];
                          Color statusColor;
                          switch (lead.status) {
                            case 'NEW':
                              statusColor = _brandOrange;
                              break;
                            case 'CONTACTED':
                              statusColor = const Color(0xFF3B82F6);
                              break;
                            case 'CONVERTED':
                              statusColor = _brandGreen;
                              break;
                            default:
                              statusColor = _subGrey;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        lead.customerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: _primaryDark,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _showUpdateStatusSheet(lead),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                lead.status,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(Icons.arrow_drop_down, size: 16, color: statusColor),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      lead.inquiryType,
                                      style: const TextStyle(fontSize: 11, color: _subGrey, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    lead.message,
                                    style: const TextStyle(fontSize: 13, color: _primaryDark, height: 1.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        lead.customerPhone,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Dialing ${lead.customerPhone}...')),
                                          );
                                        },
                                        icon: const Icon(Icons.call, size: 14),
                                        label: const Text('Call Customer'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _brandGreen,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(0, 34),
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
          ),
        ],
      ),
    );
  }
}
