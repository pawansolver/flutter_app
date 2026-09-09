import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';

class ManageOffersScreen extends StatefulWidget {
  final int businessId;
  const ManageOffersScreen({super.key, required this.businessId});

  @override
  State<ManageOffersScreen> createState() => _ManageOffersScreenState();
}

class _ManageOffersScreenState extends State<ManageOffersScreen> {
  final BusinessService _service = BusinessService();
  List<BusinessOfferModel> _offers = [];
  bool _isLoading = true;

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);
    final list = await _service.getOffers(widget.businessId);
    if (!mounted) return;
    setState(() {
      _offers = list;
      _isLoading = false;
    });
  }

  InputDecoration _buildSheetInputDecoration({
    required String labelText,
    required String hintText,
    required IconData icon,
    String? suffixText,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      prefixText: prefixText,
      suffixText: suffixText,
      suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: _primaryDark),
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

  void _openCreateOfferSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final discountCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final validCtrl = TextEditingController(text: 'Valid till Sunday');

    const discountPresets = ['5', '10', '15', '20', '25', '50'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Promotional Offer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _primaryDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Publish discounts and festive deals to neighbours',
                            style: TextStyle(fontSize: 12, color: _subGrey),
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
                const SizedBox(height: 18),
                TextField(
                  controller: titleCtrl,
                  decoration: _buildSheetInputDecoration(
                    labelText: 'Offer Headline *',
                    hintText: 'e.g., Weekend Kirana Bonanza, Morning Milk Combo',
                    icon: Icons.local_offer_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _buildSheetInputDecoration(
                          labelText: 'Discount % *',
                          hintText: 'e.g., 15',
                          icon: Icons.percent,
                          suffixText: '%',
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: _buildSheetInputDecoration(
                          labelText: 'Coupon Code (Optional)',
                          hintText: 'e.g., GALI15',
                          icon: Icons.confirmation_number_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: discountPresets.map((pct) {
                      final isSelected = discountCtrl.text.trim() == pct;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text('$pct% OFF'),
                          backgroundColor: isSelected ? _brandOrange : const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? _brandOrange : const Color(0xFFE2E8F0),
                            ),
                          ),
                          onPressed: () {
                            setSheetState(() => discountCtrl.text = pct);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: validCtrl,
                  decoration: _buildSheetInputDecoration(
                    labelText: 'Offer Validity *',
                    hintText: 'e.g., Valid till Sunday, Valid this festive week',
                    icon: Icons.event_available_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: _buildSheetInputDecoration(
                    labelText: 'Offer Terms & Conditions',
                    hintText: 'e.g., Applicable on all items above ₹500 for local residents',
                    icon: Icons.notes_outlined,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty || discountCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter offer title and discount percentage.')),
                        );
                        return;
                      }

                      final discountVal = int.tryParse(discountCtrl.text.trim()) ?? 0;

                      final newOffer = BusinessOfferModel(
                        id: DateTime.now().millisecondsSinceEpoch,
                        businessId: widget.businessId,
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        discountPercent: discountVal,
                        promoCode: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                        validUntil: validCtrl.text.trim().isEmpty ? 'Limited period' : validCtrl.text.trim(),
                        isActive: true,
                      );

                      await _service.createOffer(newOffer);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (!mounted) return;
                      _loadOffers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Offer published to neighbourhood feed!'),
                          backgroundColor: _brandGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
                    label: const Text(
                      'Publish Offer to Neighbourhood',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandOrange,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _deleteOffer(int offerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Offer?'),
        content: const Text('Are you sure you want to remove this promotional offer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteOffer(offerId);
      _loadOffers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer removed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Promotional Offers',
              style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
            Text(
              '${_offers.length} Active Deals for neighbours',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateOfferSheet,
        backgroundColor: _brandOrange,
        elevation: 2,
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: const Text('Create Offer', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _brandOrange))
          : _offers.isEmpty
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
                          child: const Icon(Icons.local_offer_outlined, size: 40, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Active Offers',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primaryDark),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Discounts and festive deals published here will appear on your storefront and in neighbourhood feeds.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: _subGrey, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _openCreateOfferSheet,
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text('Create First Offer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandOrange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _offers.length,
                  itemBuilder: (context, index) {
                    final offer = _offers[index];
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
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _brandOrange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${offer.discountPercent}% OFF',
                                    style: const TextStyle(
                                      color: _brandOrange,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                if (offer.promoCode != null && offer.promoCode!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.confirmation_number_outlined, size: 12, color: Color(0xFF475569)),
                                        const SizedBox(width: 4),
                                        Text(
                                          offer.promoCode!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF334155),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _brandGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _brandGreen,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Active',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _brandGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 18),
                                  tooltip: 'Remove Offer',
                                  onPressed: () => _deleteOffer(offer.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              offer.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _primaryDark,
                              ),
                            ),
                            if (offer.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                offer.description,
                                style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.3),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 5),
                                  Text(
                                    offer.validUntil,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
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
}
