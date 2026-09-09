import 'package:flutter/material.dart';
import '../../../widgets/custom_drawer.dart';
import '../../dashboard/main_dashboard.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';
import 'edit_business_profile_screen.dart';
import 'manage_products_screen.dart';
import 'manage_offers_screen.dart';
import 'business_leads_screen.dart';
import 'business_reviews_screen.dart';
import 'business_analytics_screen.dart';
import 'business_subscription_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final BusinessService _service = BusinessService();

  bool _isLoading = true;
  String? _error;

  BusinessProfileModel? _profile;
  List<BusinessProductModel> _products = [];
  List<BusinessOfferModel> _offers = [];
  List<BusinessLeadModel> _leads = [];
  List<BusinessReviewModel> _reviews = [];

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);
  static const Color _cardBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _service.getMyBusinessProfile();
      final products = await _service.getProducts(profile.id);
      final offers = await _service.getOffers(profile.id);
      final leads = await _service.getLeads(profile.id);
      final reviews = await _service.getReviews(profile.id);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _products = products;
        _offers = offers;
        _leads = leads;
        _reviews = reviews;
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

  void _toggleStoreStatus() async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(isOpen: !_profile!.isOpen);
    setState(() => _profile = updated);
    await _service.updateBusinessProfile(updated);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.isOpen ? 'Store is now marked OPEN to neighbours' : 'Store is now marked CLOSED',
        ),
        backgroundColor: updated.isOpen ? _brandGreen : Colors.grey.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
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
        backgroundColor: const Color(0xFFF3F4F6),
        drawer: const CustomDrawer(),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: _primaryDark),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Row(
            children: [
              const Text(
                'Business Hub',
                style: TextStyle(
                  color: _primaryDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'OWNER',
                  style: TextStyle(
                    color: _brandOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: _primaryDark),
              tooltip: 'Edit Business Profile',
              onPressed: _profile == null
                  ? null
                  : () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditBusinessProfileScreen(profile: _profile!),
                        ),
                      );
                      if (updated == true) _loadAllData();
                    },
            ),
            IconButton(
              icon: const Icon(Icons.home_outlined, color: _primaryDark),
              tooltip: 'Resident Home',
              onPressed: _handleBack,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _brandOrange),
              )
            : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    color: _brandOrange,
                    onRefresh: _loadAllData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileHeader(),
                          const SizedBox(height: 16),
                          _buildKpiMetricsGrid(),
                          const SizedBox(height: 20),
                          _buildQuickActionsGrid(),
                          const SizedBox(height: 24),
                          _buildRecentLeadsSection(),
                          const SizedBox(height: 24),
                          _buildActiveOffersSection(),
                          const SizedBox(height: 24),
                          _buildProductsSection(),
                          const SizedBox(height: 24),
                          _buildReviewsSummarySection(),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  // ── Profile Header with Open/Closed switch ──────────────────────────────────
  Widget _buildProfileHeader() {
    final p = _profile!;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business Logo / Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _brandOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _brandOrange.withValues(alpha: 0.2)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.storefront_rounded,
                    color: _brandOrange,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.businessName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _primaryDark,
                            ),
                          ),
                        ),
                        if (p.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: _brandGreen,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.categoryName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _subGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          p.hasRating
                              ? '${p.formattedRating} ${p.formattedReviewCount}'
                              : 'No ratings yet',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),
          // Store Status Toggle Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.isOpen ? _brandGreen : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.isOpen ? 'Accepting Orders & Calls' : 'Currently Closed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.isOpen ? _brandGreen : Colors.red,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    p.isOpen ? 'Open' : 'Closed',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _primaryDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: p.isOpen,
                    activeThumbColor: _brandGreen,
                    onChanged: (_) => _toggleStoreStatus(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4 KPI Metrics Cards ──────────────────────────────────────────────────
  Widget _buildKpiMetricsGrid() {
    final newLeadsCount = _leads.where((l) => l.status == 'NEW').length;
    final activeOffersCount = _offers.where((o) => o.isActive).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              title: 'Views (7d)',
              value: '--',
              icon: Icons.visibility_outlined,
              color: const Color(0xFF3B82F6),
              trend: 'No data',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: 'New Leads',
              value: newLeadsCount.toString(),
              icon: Icons.phone_in_talk_outlined,
              color: _brandOrange,
              trend: 'Action needed',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: 'Active Offers',
              value: activeOffersCount.toString(),
              icon: Icons.local_offer_outlined,
              color: _brandGreen,
              trend: 'Live locally',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: _subGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions 6-Grid ──────────────────────────────────────────────────
  Widget _buildQuickActionsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Operations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _buildActionTile(
                icon: Icons.inventory_2_outlined,
                title: 'Products',
                subtitle: '${_products.length} items',
                color: const Color(0xFF3B82F6),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManageProductsScreen(businessId: _profile!.id),
                    ),
                  );
                  _loadAllData();
                },
              ),
              _buildActionTile(
                icon: Icons.local_offer_outlined,
                title: 'Offers',
                subtitle: '${_offers.length} active',
                color: _brandOrange,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManageOffersScreen(businessId: _profile!.id),
                    ),
                  );
                  _loadAllData();
                },
              ),
              _buildActionTile(
                icon: Icons.contact_phone_outlined,
                title: 'Leads',
                subtitle: '${_leads.length} customer',
                color: _brandGreen,
                badge: _leads.where((l) => l.status == 'NEW').length,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessLeadsScreen(businessId: _profile!.id),
                    ),
                  );
                  _loadAllData();
                },
              ),
              _buildActionTile(
                icon: Icons.star_outline_rounded,
                title: 'Reviews',
                subtitle: '${_reviews.length} rated',
                color: const Color(0xFFF59E0B),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessReviewsScreen(businessId: _profile!.id),
                    ),
                  );
                  _loadAllData();
                },
              ),
              _buildActionTile(
                icon: Icons.insights_rounded,
                title: 'Analytics',
                subtitle: 'Performance',
                color: const Color(0xFF8B5CF6),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessAnalyticsScreen(businessId: _profile!.id),
                  ),
                ),
              ),
              _buildActionTile(
                icon: Icons.verified_outlined,
                title: 'Plan & Tier',
                subtitle: 'Free Local',
                color: const Color(0xFF0D9488),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BusinessSubscriptionScreen(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    int? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _subGrey),
                ),
              ],
            ),
            if (badge != null && badge > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: _brandOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Recent Leads Section ──────────────────────────────────────────────────
  Widget _buildRecentLeadsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Inbound Inquiries',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _primaryDark,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessLeadsScreen(businessId: _profile!.id),
                  ),
                ),
                child: const Text('View All', style: TextStyle(color: _brandOrange)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_leads.isEmpty)
            _buildEmptyCard('No customer leads yet. Orders and inquiries will appear here.')
          else
            ..._leads.take(2).map((lead) => _buildLeadCard(lead)),
        ],
      ),
    );
  }

  Widget _buildLeadCard(BusinessLeadModel lead) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lead.customerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _primaryDark,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lead.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lead.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: _subGrey, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lead.customerPhone,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primaryDark,
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Dialing ${lead.customerPhone}...')),
                      );
                    },
                    icon: const Icon(Icons.call, size: 14, color: _brandGreen),
                    label: const Text('Call', style: TextStyle(fontSize: 12, color: _brandGreen)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _brandGreen),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 30),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Active Offers Section ─────────────────────────────────────────────────
  Widget _buildActiveOffersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Neighbourhood Offers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _primaryDark,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageOffersScreen(businessId: _profile!.id),
                  ),
                ),
                child: const Text('Manage', style: TextStyle(color: _brandOrange)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_offers.isEmpty)
            _buildEmptyCard('No offers running. Create discount promotions to attract neighbours.')
          else
            ..._offers.take(2).map((offer) => _buildOfferCard(offer)),
        ],
      ),
    );
  }

  Widget _buildOfferCard(BusinessOfferModel offer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brandOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${offer.discountPercent}%',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _brandOrange,
                  ),
                ),
                const Text(
                  'OFF',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brandOrange),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offer.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _subGrey),
                ),
                const SizedBox(height: 4),
                Text(
                  offer.validUntil,
                  style: const TextStyle(fontSize: 11, color: _brandGreen, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Products Section ──────────────────────────────────────────────────────
  Widget _buildProductsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Product Catalog',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _primaryDark,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageProductsScreen(businessId: _profile!.id),
                  ),
                ),
                child: const Text('View All', style: TextStyle(color: _brandOrange)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_products.isEmpty)
            _buildEmptyCard('No products added yet. Add items for neighbours to browse.')
          else
            ..._products.take(2).map((product) => _buildProductItem(product)),
        ],
      ),
    );
  }

  Widget _buildProductItem(BusinessProductModel product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: _subGrey, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _primaryDark,
                      ),
                    ),
                    if (product.originalPrice != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '₹${product.originalPrice!.toStringAsFixed(0)}',
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: product.inStock
                  ? _brandGreen.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              product.inStock ? 'IN STOCK' : 'OUT OF STOCK',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: product.inStock ? _brandGreen : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reviews Summary Section ───────────────────────────────────────────────
  Widget _buildReviewsSummarySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Customer Reviews & Ratings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _primaryDark,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BusinessReviewsScreen(businessId: _profile!.id),
                  ),
                ),
                child: const Text('Manage', style: TextStyle(color: _brandOrange)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_reviews.isEmpty)
            _buildEmptyCard('No customer reviews yet. High service ratings attract more neighbours.')
          else
            _buildReviewItem(_reviews.first),
        ],
      ),
    );
  }

  Widget _buildReviewItem(BusinessReviewModel review) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _primaryDark,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    review.rating.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.comment,
            style: const TextStyle(fontSize: 13, color: _subGrey, height: 1.3),
          ),
          if (review.replyText != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.reply, size: 14, color: _brandGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Owner response: ${review.replyText!}',
                      style: const TextStyle(fontSize: 12, color: _primaryDark, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _subGrey),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Failed to load business details',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _subGrey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllData,
              style: ElevatedButton.styleFrom(backgroundColor: _brandOrange),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
