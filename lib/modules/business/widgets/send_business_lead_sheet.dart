import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';

class SendBusinessLeadSheet extends StatefulWidget {
  final int businessId;
  final String businessName;
  final BusinessProductModel? product;

  const SendBusinessLeadSheet({
    super.key,
    required this.businessId,
    required this.businessName,
    this.product,
  });

  @override
  State<SendBusinessLeadSheet> createState() => _SendBusinessLeadSheetState();
}

class _SendBusinessLeadSheetState extends State<SendBusinessLeadSheet> {
  final BusinessService _service = BusinessService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _messageCtrl;
  String _inquiryType = 'Product Availability';
  bool _isSubmitting = false;

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: 'Neighbour Resident');
    _phoneCtrl = TextEditingController();

    if (widget.product != null) {
      _inquiryType = 'Product Inquiry';
      _messageCtrl = TextEditingController(
        text: 'Hi, I would like to inquire about "${widget.product!.name}". Is it available for delivery today?',
      );
    } else {
      _messageCtrl = TextEditingController(
        text: 'Hi, I would like to inquire about placing an order with your store.',
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitInquiry() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final msg = _messageCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your contact phone number.')),
      );
      return;
    }
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your inquiry message.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final lead = BusinessLeadModel(
        id: 'lead_${DateTime.now().millisecondsSinceEpoch}',
        businessId: widget.businessId,
        customerName: name,
        customerPhone: phone,
        inquiryType: _inquiryType,
        message: msg,
        status: 'NEW',
        createdAt: DateTime.now(),
      );

      await _service.submitLead(lead);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inquiry sent! The shopkeeper will contact you shortly.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send inquiry: $e')),
      );
    }
  }

  InputDecoration _buildSheetInputDecoration({
    required String labelText,
    String? hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _brandOrange, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                      Text(
                        'Contact ${widget.businessName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _primaryDark,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Send inquiry directly to shopkeeper leads desk',
                        style: TextStyle(fontSize: 12, color: _subGrey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: _subGrey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Inquiry Type Dropdown
            DropdownButtonFormField<String>(
              initialValue: _inquiryType,
              decoration: _buildSheetInputDecoration(
                labelText: 'Inquiry Subject',
                icon: Icons.topic_outlined,
              ),
              items: const [
                DropdownMenuItem(value: 'Product Availability', child: Text('Product Availability')),
                DropdownMenuItem(value: 'Product Inquiry', child: Text('Product Inquiry')),
                DropdownMenuItem(value: 'Home Delivery Request', child: Text('Home Delivery Request')),
                DropdownMenuItem(value: 'Bulk Purchase / Hamper', child: Text('Bulk Purchase / Hamper')),
                DropdownMenuItem(value: 'Pricing / Quotation', child: Text('Pricing / Quotation')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _inquiryType = val);
              },
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _nameCtrl,
              decoration: _buildSheetInputDecoration(
                labelText: 'Your Name *',
                hintText: 'Resident Name',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _buildSheetInputDecoration(
                labelText: 'Contact Phone Number *',
                hintText: '+91 98765 43210',
                icon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _messageCtrl,
              maxLines: 3,
              decoration: _buildSheetInputDecoration(
                labelText: 'Inquiry Message *',
                hintText: 'Describe what you need or ask your question...',
                icon: Icons.message_outlined,
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitInquiry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'Sending...' : 'Send Inquiry to Shop',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
