import 'package:flutter/material.dart';
import '../../../widgets/custom_drawer.dart';
import '../../dashboard/main_dashboard.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';
import 'business_detail_screen.dart';

class BusinessListingsScreen extends StatefulWidget {
  final int? initialCategoryId;
  final String? initialSearch;

  const BusinessListingsScreen({
    super.key,
    this.initialCategoryId,
    this.initialSearch,
  });

  @override
  State<BusinessListingsScreen> createState() => _BusinessListingsScreenState();
}

class _BusinessListingsScreenState extends State<BusinessListingsScreen> {
  final BusinessService _service = BusinessService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  String? _error;

  List<BusinessProfileModel> _allBusinesses = [];
  List<BusinessProfileModel> _filteredBusinesses = [];
  List<BusinessCategoryModel> _categories = [];

  int? _selectedCategoryId;
  String _selectedRadius = 'Within 2 km';
  final List<String> _radiusOptions = ['Within 500m', 'Within 1 km', 'Within 2 km', 'Within 5 km'];

  bool _verifiedOnly = false;
  bool _openNowOnly = false;

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);
  static const Color _bgGrey = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    if (widget.initialSearch != null) {
      _searchCtrl.text = widget.initialSearch!;
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await _service.getCategories();
      final businesses = await _service.getBusinesses(
        categoryId: _selectedCategoryId,
        search: _searchCtrl.text.trim().isNotEmpty ? _searchCtrl.text.trim() : null,
      );

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _allBusinesses = businesses;
        _applyLocalFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyLocalFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();

    _filteredBusinesses = _allBusinesses.where((b) {
      // Category filter
      if (_selectedCategoryId != null && _selectedCategoryId! > 0) {
        if (b.categoryId != null && b.categoryId != _selectedCategoryId) {
          return false;
        }
      }

      // Verified filter
      if (_verifiedOnly && !b.isVerified) {
        return false;
      }

      // Open now filter
      if (_openNowOnly && !b.isOpen) {
        return false;
      }

      // Search query
      if (query.isNotEmpty) {
        final matchesName = b.businessName.toLowerCase().contains(query);
        final matchesCat = b.categoryName.toLowerCase().contains(query);
        final matchesDesc = b.description?.toLowerCase().contains(query) ?? false;
        final matchesAddress = b.address?.toLowerCase().contains(query) ?? false;
        if (!matchesName && !matchesCat && !matchesDesc && !matchesAddress) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _onCategorySelected(int? categoryId) {
    setState(() {
      if (_selectedCategoryId == categoryId) {
        _selectedCategoryId = null; // toggle off
      } else {
        _selectedCategoryId = categoryId;
      }
      _applyLocalFilters();
    });
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainDashboard()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: _bgGrey,
        drawer: const CustomDrawer(),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: _primaryDark),
                  onPressed: _handleBack,
                )
              : Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: _primaryDark),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
          title: const Text(
            'Local Shops & Businesses',
            style: TextStyle(
              color: _primaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
          ),
        ),
        body: RefreshIndicator(
          color: _brandOrange,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildRadiusSelector(),
                const SizedBox(height: 12),
                _buildCategoriesBar(),
                const SizedBox(height: 12),
                _buildFilterToggleChips(),
                const SizedBox(height: 16),
                _buildResultsHeader(),
                const SizedBox(height: 12),
                _buildListingsContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(_applyLocalFilters),
          decoration: InputDecoration(
            hintText: 'Search kirana, bakery, pharmacy, dairy...',
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(_applyLocalFilters);
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Radius Selector (GAP 4) ─────────────────────────────────────────────────
  Widget _buildRadiusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _radiusOptions.map((radius) {
              final isSelected = _selectedRadius == radius;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(radius),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedRadius = radius);
                  },
                  selectedColor: _brandOrange,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : _primaryDark,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? _brandOrange : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Radius preference selected (Actual GPS distance filtering is backend-dependent)',
            style: TextStyle(fontSize: 11, color: _subGrey, fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  // ── Categories Horizontal Bar ──────────────────────────────────────────────
  Widget _buildCategoriesBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // "All" chip
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All Categories'),
              selected: _selectedCategoryId == null,
              onSelected: (_) => _onCategorySelected(null),
              selectedColor: _primaryDark,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedCategoryId == null ? Colors.white : _primaryDark,
                fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: _selectedCategoryId == null ? _primaryDark : const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
          ..._categories.map((cat) {
            final isSelected = _selectedCategoryId == cat.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(cat.name),
                selected: isSelected,
                onSelected: (_) => _onCategorySelected(cat.id),
                selectedColor: _brandOrange,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : _primaryDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? _brandOrange : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Quick Filter Toggles ───────────────────────────────────────────────────
  Widget _buildFilterToggleChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          FilterChip(
            avatar: Icon(
              Icons.verified,
              size: 16,
              color: _verifiedOnly ? Colors.white : _brandGreen,
            ),
            label: const Text('Verified Only'),
            selected: _verifiedOnly,
            onSelected: (val) {
              setState(() {
                _verifiedOnly = val;
                _applyLocalFilters();
              });
            },
            selectedColor: _brandGreen,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _verifiedOnly ? Colors.white : _primaryDark,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _openNowOnly ? Colors.white : _brandGreen,
              ),
            ),
            label: const Text('Open Now'),
            selected: _openNowOnly,
            onSelected: (val) {
              setState(() {
                _openNowOnly = val;
                _applyLocalFilters();
              });
            },
            selectedColor: _brandGreen,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _openNowOnly ? Colors.white : _primaryDark,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Results Header ─────────────────────────────────────────────────────────
  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Shops in Neighbourhood (${_filteredBusinesses.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _primaryDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _selectedRadius,
            style: const TextStyle(fontSize: 12, color: _subGrey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Listings Content (List / Loading / Error / Empty) ───────────────────────
  Widget _buildListingsContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: _brandOrange),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                'Could not load businesses',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark),
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _subGrey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredBusinesses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.storefront_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No matching shops found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try adjusting your search keywords or category filters.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _subGrey),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchCtrl.clear();
                    _selectedCategoryId = null;
                    _verifiedOnly = false;
                    _openNowOnly = false;
                    _applyLocalFilters();
                  });
                },
                child: const Text('Reset All Filters', style: TextStyle(color: _brandOrange)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredBusinesses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final business = _filteredBusinesses[index];
        return _buildBusinessCard(business);
      },
    );
  }

  // ── Individual Business Card ───────────────────────────────────────────────
  Widget _buildBusinessCard(BusinessProfileModel b) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessDetailScreen(business: b),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shop Logo / Icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: b.logoUrl != null && b.logoUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            b.logoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.storefront_rounded, color: _brandOrange),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.storefront_rounded, color: _brandOrange, size: 26),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              b.businessName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _primaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (b.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: _brandGreen, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.categoryName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _subGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Rating & Reviews Summary
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 3),
                          Text(
                            b.hasRating
                                ? '${b.formattedRating} ${b.formattedReviewCount}'
                                : 'No ratings yet',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Open / Closed Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: b.isOpen
                        ? _brandGreen.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    b.isOpen ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: b.isOpen ? _brandGreen : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            if (b.address != null && b.address!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: _subGrey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      b.address!,
                      style: const TextStyle(fontSize: 12, color: _subGrey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  b.displayOperatingHours,
                  style: const TextStyle(fontSize: 11, color: _subGrey),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BusinessDetailScreen(business: b),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'View Storefront',
                        style: TextStyle(
                          color: _brandOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _brandOrange),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
