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
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Contact ${widget.businessName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _primaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Send an inquiry directly to the shopkeeper. They will receive this in their leads dashboard.',
              style: TextStyle(fontSize: 12, color: _subGrey, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Inquiry Type Dropdown
            DropdownButtonFormField<String>(
              value: _inquiryType,
              decoration: InputDecoration(
                labelText: 'Inquiry Subject',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            const SizedBox(height: 12),

            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Your Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Contact Phone Number *',
                hintText: '+91 98765 43210',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _messageCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Inquiry Message *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitInquiry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Send Inquiry to Shop',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
