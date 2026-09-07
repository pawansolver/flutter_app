import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../models/service_models.dart';
import '../../../services/service_marketplace_service.dart';
import 'my_service_bookings_screen.dart';
import 'service_detail_screen.dart';
import 'service_listings_screen.dart';

class ServicesMarketplaceScreen extends StatefulWidget {
  const ServicesMarketplaceScreen({super.key});

  @override
  State<ServicesMarketplaceScreen> createState() => _ServicesMarketplaceScreenState();
}

class _ServicesMarketplaceScreenState extends State<ServicesMarketplaceScreen> {
  final _service = ServiceMarketplaceService();

  bool _loading = true;
  String? _errorMessage;

  String _detectedLocation = 'Locating neighborhood...';

  List<ServiceCategoryModel> _categories = [];
  int? _selectedCategoryId; // null = All

  List<ServiceListingModel> _listings = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initLocationAndData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocationAndData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    _determinePosition();

    try {
      final results = await Future.wait([
        _service.getCategories(),
        _service.getProviderListings().catchError((_) => <ServiceListingModel>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<ServiceCategoryModel>;
        _listings = results[1] as List<ServiceListingModel>;
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

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        if (mounted) {
          setState(() {
            _detectedLocation = 'Neighborhood • Within 2 km';
          });
        }
      } else {
        if (mounted) setState(() => _detectedLocation = 'Neighborhood Area');
      }
    } catch (_) {
      if (mounted) setState(() => _detectedLocation = 'Local Community Area');
    }
  }

  List<ServiceListingModel> _getFilteredListings() {
    List<ServiceListingModel> list = _listings;

    // Filter by selected category
    if (_selectedCategoryId != null) {
      list = list.where((item) => item.categoryId == _selectedCategoryId).toList();
    }

    // Filter by search query
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

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('electric')) return Icons.bolt;
    if (name.contains('plumb')) return Icons.plumbing;
    if (name.contains('clean')) return Icons.cleaning_services;
    if (name.contains('appliance') || name.contains('ac')) return Icons.kitchen;
    if (name.contains('tutor') || name.contains('class') || name.contains('edu')) return Icons.school;
    if (name.contains('car') || name.contains('auto')) return Icons.directions_car;
    if (name.contains('carpent')) return Icons.carpenter;
    if (name.contains('paint')) return Icons.format_paint;
    return Icons.handyman_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(),
      body: _loading ? _buildLoadingShimmer() : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Services',
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, size: 12, color: Color(0xFFF59E0B)),
              const SizedBox(width: 3),
              Text(
                _detectedLocation,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFF111827)),
          tooltip: 'My Bookings',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyServiceBookingsScreen()),
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: const Color(0xFFE5E7EB), height: 1.0),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF111827)),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text(
                'Unable to load services marketplace',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _initLocationAndData,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final filteredList = _getFilteredListings();

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _initLocationAndData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero / Search Area ──
            _buildHeroArea(),
            const SizedBox(height: 16),

            // ── Category Section ──
            _buildCategoriesSection(),
            const SizedBox(height: 24),

            // ── Quick Bookings Banner ──
            _buildMyBookingsBanner(),
            const SizedBox(height: 24),

            // ── Nearby Services Section ──
            _buildNearbyServicesSection(filteredList),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Hero Area with Search Field ──────────────────────────────────────────
  Widget _buildHeroArea() {
    final exampleTags = ['Plumber', 'Electrician', 'Tutor', 'Home Cleaning', 'AC Repair'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find Services Near You',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Discover trusted local service providers in your neighborhood',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF), size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              hintText: 'Search services or providers',
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF111827), width: 1.5),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),

          // Search Example Pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: exampleTags.map((tag) {
              return InkWell(
                onTap: () {
                  _searchController.text = tag;
                  setState(() => _searchQuery = tag);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Categories Horizontal Carousel ───────────────────────────────────────
  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Categories',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length + 1, // +1 for "All"
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedCategoryId == null;
                return _buildCategoryChip(
                  title: 'All Services',
                  icon: Icons.grid_view_rounded,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedCategoryId = null),
                );
              }

              final cat = _categories[index - 1];
              final isSelected = _selectedCategoryId == cat.id;
              return _buildCategoryChip(
                title: cat.name,
                icon: _getCategoryIcon(cat.name),
                isSelected: isSelected,
                onTap: () => setState(() => _selectedCategoryId = cat.id),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.white : const Color(0xFF374151),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick My Bookings Access Banner ──────────────────────────────────────
  Widget _buildMyBookingsBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyServiceBookingsScreen()),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, size: 20, color: Color(0xFF2B7BB9)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Track Your Service Bookings',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'View active requests, scheduled dates, and rate completed work.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF2B7BB9)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Nearby Services Section ──────────────────────────────────────────────
  Widget _buildNearbyServicesSection(List<ServiceListingModel> list) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Services Near You',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Available providers in your local perimeter',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceListingsScreen(
                        initialCategoryId: _selectedCategoryId,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B7BB9),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (list.isEmpty)
          _buildEmptyNearbyState()
        else
          ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = list[index];
              return _buildServiceCard(item);
            },
          ),
      ],
    );
  }

  Widget _buildServiceCard(ServiceListingModel item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Generic Category Icon Box
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(item.categoryName ?? ''),
                  size: 24,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.categoryName ?? 'General Service',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2B7BB9),
                            ),
                          ),
                        ),
                        if (item.duration != null && item.duration!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${item.duration}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Verified Badge
              if (item.isProviderVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.verified, size: 11, color: Color(0xFF10B981)),
                      SizedBox(width: 3),
                      Text(
                        'Verified',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Provider name and distance
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                item.providerName ?? 'Local Pro',
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 2),
              Text(
                item.distance ?? 'Within 1.5 km',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const Spacer(),
              const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 3),
              Text(
                '${item.rating}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              if (item.reviewsCount > 0)
                Text(
                  ' (${item.reviewsCount})',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
            ],
          ),

          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.3),
            ),
          ],

          const Divider(height: 20, color: Color(0xFFF3F4F6)),

          // Bottom Pricing and View Service CTA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  Text(
                    item.price != null ? '₹${item.price!.toStringAsFixed(0)}' : 'Quote on request',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailScreen(listing: item),
                    ),
                  );
                },
                child: const Text(
                  'View Service',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyNearbyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 44, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          const Text(
            'No nearby services found',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 6),
          const Text(
            'No service listings match your selected category or query. Try resetting filters.',
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
              });
            },
            child: const Text('Reset Filters', style: TextStyle(color: Color(0xFF2B7BB9), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
