import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';

class ManageProductsScreen extends StatefulWidget {
  final int businessId;
  const ManageProductsScreen({super.key, required this.businessId});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final BusinessService _service = BusinessService();
  List<BusinessProductModel> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final list = await _service.getProducts(widget.businessId);
    if (!mounted) return;
    setState(() {
      _products = list;
      _isLoading = false;
    });
  }

  List<BusinessProductModel> get _filteredProducts {
    return _products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;
      if (_selectedFilter == 'In Stock') return p.inStock;
      if (_selectedFilter == 'Out of Stock') return !p.inStock;
      return true;
    }).toList();
  }

  static const List<String> _categoryPresets = [
    'Dairy',
    'Grocery',
    'Bakery',
    'Snacks & Namkeen',
    'Beverages',
    'Personal Care',
    'Fresh Produce',
    'Stationery',
  ];

  InputDecoration _buildSheetInputDecoration({
    required String labelText,
    required String hintText,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      prefixText: prefixText,
      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: _primaryDark),
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

  void _openAddEditSheet([BusinessProductModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.price.toStringAsFixed(0) : '');
    final origPriceCtrl = TextEditingController(
      text: existing?.originalPrice != null ? existing!.originalPrice!.toStringAsFixed(0) : '',
    );
    final catCtrl = TextEditingController(text: existing?.category ?? 'General');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    bool inStock = existing?.inStock ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                            existing == null ? 'Add New Product' : 'Edit Product',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _primaryDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Keep pricing and stock availability updated for neighbours',
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
                  controller: nameCtrl,
                  decoration: _buildSheetInputDecoration(
                    labelText: 'Product Name *',
                    hintText: 'e.g., Amul Taaza Milk (500ml), Whole Wheat Bread',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _buildSheetInputDecoration(
                          labelText: 'Selling Price *',
                          hintText: 'e.g., 32',
                          icon: Icons.currency_rupee,
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: origPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _buildSheetInputDecoration(
                          labelText: 'MRP / Original',
                          hintText: 'e.g., 35',
                          icon: Icons.money_off_csred_outlined,
                          prefixText: '₹ ',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: catCtrl,
                  decoration: _buildSheetInputDecoration(
                    labelText: 'Category',
                    hintText: 'Select preset below or type category',
                    icon: Icons.category_outlined,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categoryPresets.map((preset) {
                      final isSelected = catCtrl.text.trim().toLowerCase() == preset.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(preset),
                          backgroundColor: isSelected ? _brandOrange : const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? _brandOrange : const Color(0xFFE2E8F0),
                            ),
                          ),
                          onPressed: () {
                            setSheetState(() => catCtrl.text = preset);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: _buildSheetInputDecoration(
                    labelText: 'Product Details (Optional)',
                    hintText: 'Pack size, weight, brand, expiry notes...',
                    icon: Icons.notes_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            inStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: inStock ? _brandGreen : Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inStock ? 'In Stock (Available Now)' : 'Out of Stock',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryDark),
                              ),
                              Text(
                                inStock ? 'Visible to neighbourhood shoppers' : 'Marked unavailable for order inquiries',
                                style: const TextStyle(fontSize: 11, color: _subGrey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: inStock,
                        activeThumbColor: _brandGreen,
                        onChanged: (v) => setSheetState(() => inStock = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter name and price.')),
                        );
                        return;
                      }

                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      final origPrice = double.tryParse(origPriceCtrl.text.trim());

                      if (existing == null) {
                        final newProd = BusinessProductModel(
                          id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
                          businessId: widget.businessId,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          price: price,
                          originalPrice: origPrice,
                          category: catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
                          inStock: inStock,
                        );
                        await _service.addProduct(newProd);
                      } else {
                        final updated = BusinessProductModel(
                          id: existing.id,
                          businessId: existing.businessId,
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          price: price,
                          originalPrice: origPrice,
                          category: catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
                          inStock: inStock,
                        );
                        await _service.updateProduct(updated);
                      }

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (!mounted) return;
                      _loadProducts();
                    },
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    label: Text(
                      existing == null ? 'Publish Product to Catalog' : 'Save Product Changes',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _deleteProduct(BusinessProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to remove "${product.name}" from your catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteProduct(product.id);
      _loadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${product.name}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _service.addProduct(product);
              _loadProducts();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final inStockCount = _products.where((p) => p.inStock).length;
    final outOfStockCount = _products.length - inStockCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Product Catalog',
              style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
            Text(
              '${_products.length} Products listed in shop',
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
        onPressed: () => _openAddEditSheet(),
        backgroundColor: _brandOrange,
        elevation: 2,
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: const Text(
          'Add Product',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
        ),
      ),
      body: Column(
        children: [
          // Enterprise Search & Metric Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by product name or category...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                      borderSide: const BorderSide(color: _brandOrange, width: 1.5),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', _products.length),
                      const SizedBox(width: 8),
                      _buildFilterChip('In Stock', inStockCount),
                      const SizedBox(width: 8),
                      _buildFilterChip('Out of Stock', outOfStockCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE2E8F0)),

          // Product List
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
                                child: const Icon(Icons.inventory_2_outlined, size: 40, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Products Found',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _primaryDark),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Add your items with prices so neighbours can discover what is available in your store.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: _subGrey, height: 1.4),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: () => _openAddEditSheet(),
                                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                                label: const Text('Add First Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final hasDiscount = p.originalPrice != null && p.originalPrice! > p.price;
                          final discountPercent = hasDiscount
                              ? (((p.originalPrice! - p.price) / p.originalPrice!) * 100).round()
                              : 0;

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
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF64748B), size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p.name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: _primaryDark,
                                                ),
                                              ),
                                            ),
                                            // Stock Badge Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: p.inStock
                                                    ? _brandGreen.withValues(alpha: 0.1)
                                                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: p.inStock ? _brandGreen : const Color(0xFFEF4444),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    p.inStock ? 'In Stock' : 'Out of Stock',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: p.inStock ? _brandGreen : const Color(0xFFEF4444),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                p.category,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF475569),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (p.description.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  p.description,
                                                  style: const TextStyle(fontSize: 11, color: _subGrey),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${p.price.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: _primaryDark,
                                              ),
                                            ),
                                            if (hasDiscount) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '₹${p.originalPrice!.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: _subGrey,
                                                  decoration: TextDecoration.lineThrough,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '$discountPercent% OFF',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFFDC2626),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            // Toggle Stock Button
                                            InkWell(
                                              onTap: () async {
                                                await _service.toggleProductStock(p.id);
                                                _loadProducts();
                                              },
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  color: const Color(0xFFF8FAFC),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      p.inStock ? Icons.toggle_on : Icons.toggle_off,
                                                      size: 16,
                                                      color: p.inStock ? _brandGreen : _subGrey,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      p.inStock ? 'Mark Out of Stock' : 'Mark In Stock',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Edit Button
                                            InkWell(
                                              onTap: () => _openAddEditSheet(p),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  color: const Color(0xFFF8FAFC),
                                                ),
                                                child: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF475569)),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Delete Button
                                            InkWell(
                                              onTap: () => _deleteProduct(p),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: const Color(0xFFFEE2E2)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  color: const Color(0xFFFEF2F2),
                                                ),
                                                child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                                              ),
                                            ),
                                          ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _brandOrange : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _brandOrange : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF334155),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
