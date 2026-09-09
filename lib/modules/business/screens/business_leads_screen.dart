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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return 'R';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _showUpdateStatusSheet(BusinessLeadModel lead) {
    const statuses = [
      {'key': 'NEW', 'label': 'New Inquiry', 'desc': 'Fresh inquiry received from resident', 'color': _brandOrange},
      {'key': 'CONTACTED', 'label': 'Contacted', 'desc': 'Phone call placed or message sent', 'color': Color(0xFF3B82F6)},
      {'key': 'CONVERTED', 'label': 'Converted', 'desc': 'Order placed or customer visit scheduled', 'color': _brandGreen},
      {'key': 'CLOSED', 'label': 'Closed', 'desc': 'Inquiry resolved or not needed', 'color': _subGrey},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Update Lead Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _primaryDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lead from ${lead.customerName}',
                            style: const TextStyle(fontSize: 12, color: _subGrey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _subGrey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              ...statuses.map((item) {
                final key = item['key'] as String;
                final label = item['label'] as String;
                final desc = item['desc'] as String;
                final color = item['color'] as Color;
                final isSelected = lead.status == key;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? _primaryDark : const Color(0xFF334155),
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(desc, style: const TextStyle(fontSize: 11, color: _subGrey)),
                    trailing: isSelected ? Icon(Icons.check_circle_rounded, color: color, size: 20) : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _service.updateLeadStatus(lead.id, key);
                      _loadLeads();
                    },
                  ),
                );
              }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLeads;

    final counts = {
      'ALL': _leads.length,
      'NEW': _leads.where((l) => l.status == 'NEW').length,
      'CONTACTED': _leads.where((l) => l.status == 'CONTACTED').length,
      'CONVERTED': _leads.where((l) => l.status == 'CONVERTED').length,
      'CLOSED': _leads.where((l) => l.status == 'CLOSED').length,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Inquiries & Leads',
              style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
            Text(
              '${_leads.length} Total Leads received from residents',
              style: const TextStyle(fontSize: 12, color: _subGrey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        iconTheme: const IconThemeData(color: _primaryDark),
      ),
      body: Column(
        children: [
          // Enterprise Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'NEW', 'CONTACTED', 'CONVERTED', 'CLOSED'].map((tab) {
                  final isSel = _activeFilter == tab;
                  final count = counts[tab] ?? 0;
                  return GestureDetector(
                    onTap: () => setState(() => _activeFilter = tab),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSel ? _brandOrange : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? _brandOrange : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tab,
                            style: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFF334155),
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSel ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isSel ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(height: 1, color: const Color(0xFFE2E8F0)),

          // Leads List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _brandOrange))
                : filtered.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(24.0),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No $_activeFilter Leads',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primaryDark),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'When residents browse your products or tap Call/Message on your profile, customer inquiries appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: _subGrey, height: 1.4),
                              ),
                            ],
                          ),
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

                          final initials = _getInitials(lead.customerName);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x050F172A),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Customer Avatar Initials
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2F6),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lead.customerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: _primaryDark,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                lead.inquiryType,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF475569),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Status Badge Pill
                                      InkWell(
                                        onTap: () => _showUpdateStatusSheet(lead),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: statusColor,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                lead.status,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(width: 3),
                                              Icon(Icons.arrow_drop_down, size: 16, color: statusColor),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Message Quote Box
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      lead.message.isNotEmpty ? lead.message : 'Resident inquired about storefront products and availability.',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Contact & Call Action Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 6),
                                          Text(
                                            lead.customerPhone.isNotEmpty ? lead.customerPhone : 'No phone provided',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (lead.customerPhone.isNotEmpty)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Dialing ${lead.customerPhone}...')),
                                            );
                                          },
                                          icon: const Icon(Icons.call, size: 14, color: Colors.white),
                                          label: const Text('Call Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _brandGreen,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            minimumSize: const Size(0, 32),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

