import 'package:flutter/material.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';
import 'service_detail_screen.dart';

class ServiceListingsScreen extends StatefulWidget {
  const ServiceListingsScreen({super.key, this.initialCategoryId});

  final int? initialCategoryId;

  @override
  State<ServiceListingsScreen> createState() => _ServiceListingsScreenState();
}

class _ServiceListingsScreenState extends State<ServiceListingsScreen> {
  final _service = ServiceMarketplaceService();

  bool _loading = true;
  String? _errorMessage;

  List<ServiceCategoryModel> _categories = [];
  int? _selectedCategoryId;

  List<ServiceListingModel> _allListings = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _activeFilter = 'All'; // 'All', 'Available', 'Top Rated'

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.getCategories(),
        _service.getProviderListings().catchError((_) => <ServiceListingModel>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<ServiceCategoryModel>;
        _allListings = results[1] as List<ServiceListingModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  List<ServiceListingModel> _getFilteredListings() {
    List<ServiceListingModel> list = _allListings;

    // Filter by Category
    if (_selectedCategoryId != null) {
      list = list.where((item) => item.categoryId == _selectedCategoryId).toList();
    }

    // Filter by Status / Rating Filter
    if (_activeFilter == 'Available') {
      list = list.where((item) => item.isAvailable).toList();
    } else if (_activeFilter == 'Top Rated') {
      list = list.where((item) => item.rating >= 4.5).toList();
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((item) {
        final title = item.title.toLowerCase();
        final cat = (item.categoryName ?? '').toLowerCase();
        final desc = (item.description ?? '').toLowerCase();
        final prov = (item.providerName ?? '').toLowerCase();
        return title.contains(q) || cat.contains(q) || desc.contains(q) || prov.contains(q);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'All Services',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF), size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: 'Search service name or provider...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),

                // Filter Chips Row: All, Available, Top Rated
                Row(
                  children: [
                    _buildFilterPill('All'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Available'),
                    const SizedBox(width: 8),
                    _buildFilterPill('Top Rated'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Category Chips Row
          if (_categories.isNotEmpty) ...[
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All Categories'),
                      selected: _selectedCategoryId == null,
                      selectedColor: const Color(0xFF111827),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: _selectedCategoryId == null ? Colors.white : const Color(0xFF374151),
                        fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: const Color(0xFFF3F4F6),
                      onSelected: (_) => setState(() => _selectedCategoryId = null),
                    ),
                    const SizedBox(width: 8),
                    ..._categories.map((cat) {
                      final isSelected = _selectedCategoryId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          selectedColor: const Color(0xFF111827),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : const Color(0xFF374151),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: const Color(0xFFF3F4F6),
                          onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ],

          // List Body
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String filter) {
    final isSelected = _activeFilter == filter;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filter),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2B7BB9) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          filter,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF111827)));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text('Failed to load listings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(_errorMessage!, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchData,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111827)),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _getFilteredListings();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 44, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              const Text(
                'No service listings found',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 4),
              const Text(
                'No services match your active filters or keyword search.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategoryId = null;
                    _activeFilter = 'All';
                  });
                },
                child: const Text('Clear All Filters', style: TextStyle(color: Color(0xFF2B7BB9), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _fetchData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildListingCard(item);
        },
      ),
    );
  }

  Widget _buildListingCard(ServiceListingModel item) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServiceDetailScreen(listing: item)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.handyman, size: 22, color: Color(0xFF111827)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.categoryName ?? 'General Service',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2B7BB9), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (item.isProviderVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(item.providerName ?? 'Local Pro', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                const Spacer(),
                const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 2),
                Text('${item.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF3F4F6)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.price != null ? '₹${item.price!.toStringAsFixed(0)}' : 'Quote on request',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const Text(
                  'View Details →',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2B7BB9)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
