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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
                    Text(
                      existing == null ? 'Add New Product' : 'Edit Product',
                      style: const TextStyle(
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
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    hintText: 'e.g., Organic Honey (500g)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Selling Price (₹) *',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: origPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'MRP / Original (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: catCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g., Dairy, Bakery, Beverages',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Short Description',
                    hintText: 'Unit size, package details, freshness...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Stock Availability',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _primaryDark),
                    ),
                    Switch(
                      value: inStock,
                      activeThumbColor: _brandGreen,
                      onChanged: (v) => setSheetState(() => inStock = v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      existing == null ? 'Add Product to Catalog' : 'Save Changes',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Product Catalog',
          style: TextStyle(color: _primaryDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: _primaryDark),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditSheet(),
        backgroundColor: _brandOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products or categories...',
                    prefixIcon: const Icon(Icons.search, color: _subGrey),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['All', 'In Stock', 'Out of Stock'].map((filter) {
                    final isSel = _selectedFilter == filter;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? _brandOrange : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSel ? _brandOrange : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            color: isSel ? Colors.white : _primaryDark,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Product List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _brandOrange))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 54, color: _subGrey),
                            const SizedBox(height: 12),
                            const Text(
                              'No products found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryDark),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap "Add Product" to create your first listing',
                              style: TextStyle(fontSize: 13, color: _subGrey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.shopping_bag_outlined, color: _subGrey, size: 28),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: _primaryDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          p.category,
                                          style: const TextStyle(fontSize: 12, color: _subGrey),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${p.price.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: _primaryDark,
                                              ),
                                            ),
                                            if (p.originalPrice != null) ...[
                                              const SizedBox(width: 6),
                                              Text(
                                                '₹${p.originalPrice!.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: _subGrey,
                                                  decoration: TextDecoration.lineThrough,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          p.inStock ? Icons.check_circle : Icons.pause_circle_outline,
                                          color: p.inStock ? _brandGreen : Colors.red,
                                          size: 22,
                                        ),
                                        tooltip: p.inStock ? 'Mark Out of Stock' : 'Mark In Stock',
                                        onPressed: () async {
                                          await _service.toggleProductStock(p.id);
                                          _loadProducts();
                                        },
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: _subGrey),
                                            onPressed: () => _openAddEditSheet(p),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () => _deleteProduct(p),
                                          ),
                                        ],
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
