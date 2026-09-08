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

  void _openCreateOfferSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '15');
    final codeCtrl = TextEditingController();
    final validCtrl = TextEditingController(text: 'Valid till Sunday 9 PM');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                  const Text(
                    'Create Promotional Offer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _primaryDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Offer Title *',
                  hintText: 'e.g., Weekend Grocery Bonanza',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Discount % *',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Promo Code (Optional)',
                        hintText: 'e.g., GALI20',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: validCtrl,
                decoration: const InputDecoration(
                  labelText: 'Validity Text *',
                  hintText: 'e.g., Valid till this Sunday',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Offer Description / Terms',
                  hintText: 'e.g., Applicable on all items above ₹1,000 for verified society residents.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || discountCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill title and discount.')),
                      );
                      return;
                    }

                    final newOffer = BusinessOfferModel(
                      id: DateTime.now().millisecondsSinceEpoch,
                      businessId: widget.businessId,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      discountPercent: int.tryParse(discountCtrl.text.trim()) ?? 15,
                      promoCode: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                      validUntil: validCtrl.text.trim(),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Publish Offer Locally',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteOffer(int offerId) async {
    await _service.deleteOffer(offerId);
    _loadOffers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offer removed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Promotional Offers',
          style: TextStyle(color: _primaryDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _primaryDark),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateOfferSheet,
        backgroundColor: _brandOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Create Offer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _brandOrange))
          : _offers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_offer_outlined, size: 56, color: _subGrey),
                      const SizedBox(height: 12),
                      const Text(
                        'No offers currently active',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryDark),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "Create Offer" to publish discounts to your neighbourhood.',
                        style: TextStyle(fontSize: 13, color: _subGrey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _offers.length,
                  itemBuilder: (context, index) {
                    final offer = _offers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _brandOrange.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${offer.discountPercent}% OFF',
                                    style: const TextStyle(
                                      color: _brandOrange,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (offer.promoCode != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'CODE: ${offer.promoCode}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _primaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => _deleteOffer(offer.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              offer.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _primaryDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              offer.description,
                              style: const TextStyle(fontSize: 13, color: _subGrey),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: _brandGreen),
                                const SizedBox(width: 4),
                                Text(
                                  offer.validUntil,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _brandGreen,
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
}
