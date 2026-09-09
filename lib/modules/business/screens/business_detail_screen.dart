import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../chat/chat_window_screen.dart';
import '../models/business_models.dart';
import '../services/business_service.dart';
import '../widgets/send_business_lead_sheet.dart';
import '../widgets/write_business_review_sheet.dart';

class BusinessDetailScreen extends StatefulWidget {
  final BusinessProfileModel business;

  const BusinessDetailScreen({super.key, required this.business});

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen>
    with SingleTickerProviderStateMixin {
  final BusinessService _businessService = BusinessService();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  late BusinessProfileModel _business;

  bool _isLoading = true;
  bool _openingChat = false;
  List<BusinessProductModel> _products = [];
  List<BusinessOfferModel> _offers = [];
  List<BusinessReviewModel> _reviews = [];

  static const Color _brandOrange = Color(0xFFFF6B00);
  static const Color _brandGreen = Color(0xFF10B981);
  static const Color _primaryDark = Color(0xFF111827);
  static const Color _subGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _business = widget.business;
    _tabController = TabController(length: 4, vsync: this);
    _loadStorefrontData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStorefrontData() async {
    setState(() => _isLoading = true);
    try {
      final freshProfile = await _businessService.getBusinessById(_business.id);
      final products = await _businessService.getProducts(_business.id);
      final offers = await _businessService.getOffers(_business.id);
      final reviews = await _businessService.getReviews(_business.id);

      if (!mounted) return;
      setState(() {
        if (freshProfile != null) _business = freshProfile;
        _products = products;
        _offers = offers;
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  Future<void> _handleCall() async {
    final phone = _business.phone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact unavailable for this shop.')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not dial $phone')),
      );
    }
  }

  Future<void> _handleWhatsApp() async {
    final rawPhone = _business.phone?.replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone == null || rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact unavailable for this shop.')),
      );
      return;
    }
    final uri = Uri.parse('https://wa.me/$rawPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }

  Future<void> _handleChat() async {
    final ownerUserId = _business.userId;
    if (ownerUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Direct chat is unavailable as no user account is linked to this business storefront.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _openingChat = true);
    try {
      final currentUserId = await _authService.getUserId();
      if (currentUserId == null) {
        throw Exception('Please sign in to message this business.');
      }

      final chat = await _chatService.getOrCreateOneToOneChat(
        userId: currentUserId,
        targetUserId: ownerUserId,
      );

      if (!mounted) return;
      setState(() => _openingChat = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatWindowScreen(
            chatId: chat.id,
            chatName: _business.businessName,
            currentUserId: currentUserId,
            isOnline: false,
            recipientUserId: ownerUserId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingChat = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openInquirySheet([BusinessProductModel? product]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendBusinessLeadSheet(
        businessId: _business.id,
        businessName: _business.businessName,
        product: product,
      ),
    );
  }

  void _openWriteReviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WriteBusinessReviewSheet(
        businessId: _business.id,
        businessName: _business.businessName,
        onReviewSubmitted: _loadStorefrontData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFF0F172A),
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeroHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBusinessInfo(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: _brandOrange,
                  unselectedLabelColor: _subGrey,
                  indicatorColor: _brandOrange,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return _brandOrange.withValues(alpha: 0.1);
                    }
                    return null;
                  }),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    Tab(text: 'Products (${_products.length})'),
                    Tab(text: 'Offers (${_offers.length})'),
                    Tab(text: 'Reviews (${_reviews.length})'),
                    const Tab(text: 'About'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _brandOrange))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildProductsTab(),
                  _buildOffersTab(),
                  _buildReviewsTab(),
                  _buildAboutTab(),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomContactBar(),
    );
  }

  // ── Hero Header ────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_business.bannerUrl != null && _business.bannerUrl!.isNotEmpty)
          Image.network(
            _business.bannerUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFE5E7EB)),
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.storefront_rounded, size: 72, color: Colors.white24),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  // ── Business Info Details ──────────────────────────────────────────────────
  Widget _buildBusinessInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Logo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: _business.logoUrl != null && _business.logoUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        _business.logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.store, color: _brandOrange),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.storefront_rounded, color: _brandOrange, size: 30),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _business.businessName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _primaryDark,
                          ),
                        ),
                      ),
                      if (_business.isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: _brandGreen, size: 18),
                      ] else ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Text(
                            'Not verified',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _subGrey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _business.categoryName,
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
                        _business.hasRating
                            ? '${_business.formattedRating} ${_business.formattedReviewCount}'
                            : 'Rating: -- (No reviews yet)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _primaryDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.near_me_outlined, color: _subGrey, size: 14),
                      const SizedBox(width: 3),
                      const Text(
                        '--',
                        style: TextStyle(
                          fontSize: 12,
                          color: _subGrey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Open/Closed & Operating Hours Badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _business.isOpen
                    ? _brandGreen.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
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
                      color: _business.isOpen ? _brandGreen : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _business.isOpen ? 'Open Now' : 'Closed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _business.isOpen ? _brandGreen : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _business.displayOperatingHours,
                style: const TextStyle(fontSize: 12, color: _subGrey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (_business.address != null && _business.address!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: _subGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _business.address!,
                  style: const TextStyle(fontSize: 12, color: _subGrey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Quick Action Buttons Row ────────────────────────────────────────────────
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _handleCall,
            icon: const Icon(Icons.call_outlined, size: 16, color: _primaryDark),
            label: const Text('Call', style: TextStyle(color: _primaryDark, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openingChat ? null : _handleChat,
            icon: _openingChat
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text('Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _handleWhatsApp,
            icon: const Icon(Icons.message_outlined, size: 16, color: _brandGreen),
            label: const Text('WhatsApp', style: TextStyle(color: _brandGreen, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Reusable Empty Tab State ──────────────────────────────────────────────
  Widget _buildEmptyTabState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isScrollable = true,
  }) {
    final content = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 28, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _subGrey,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );

    if (isScrollable) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: content,
    );
  }

  // ── Products Tab ───────────────────────────────────────────────────────────
  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.inventory_2_outlined,
        title: 'No products listed yet',
        subtitle: 'This shop has not uploaded a digital product catalog yet. You can chat or call directly to inquire.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = _products[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, color: Colors.grey),
                        ),
                      )
                    : const Icon(Icons.local_offer_outlined, color: _subGrey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _primaryDark,
                      ),
                    ),
                    if (product.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _subGrey),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _primaryDark,
                          ),
                        ),
                        if (product.originalPrice != null && product.originalPrice! > product.price) ...[
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
                        const Spacer(),
                        if (!product.inStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Out of stock',
                              style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: _brandOrange, size: 20),
                tooltip: 'Inquire About Product',
                onPressed: () => _openInquirySheet(product),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Offers Tab ─────────────────────────────────────────────────────────────
  Widget _buildOffersTab() {
    if (_offers.isEmpty) {
      return _buildEmptyTabState(
        icon: Icons.local_offer_outlined,
        title: 'No active offers',
        subtitle: 'This business does not have running promotions right now. Check back soon for festive and weekend deals.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _offers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final offer = _offers[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      ),
                    ),
                  ),
                  Text(
                    offer.validUntil,
                    style: const TextStyle(fontSize: 12, color: _subGrey),
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
              if (offer.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  offer.description,
                  style: const TextStyle(fontSize: 13, color: _subGrey, height: 1.4),
                ),
              ],
              if (offer.promoCode != null && offer.promoCode!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Code: ${offer.promoCode}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: _primaryDark,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: offer.promoCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied code "${offer.promoCode}" to clipboard!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 14, color: _brandOrange),
                            SizedBox(width: 4),
                            Text(
                              'COPY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _brandOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Reviews Tab ────────────────────────────────────────────────────────────
  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Write Review Action Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Visited this store?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _primaryDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Help your neighbours by sharing your experience.',
                        style: TextStyle(fontSize: 12, color: _subGrey),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _openWriteReviewSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF7ED),
                    foregroundColor: _brandOrange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Write Review', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_reviews.isEmpty)
            _buildEmptyTabState(
              icon: Icons.rate_review_outlined,
              title: 'No reviews yet',
              subtitle: 'Be the first neighbour to rate and review this shop!',
              isScrollable: false,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final r = _reviews[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            r.userName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _primaryDark,
                            ),
                          ),
                          Row(
                            children: List.generate(5, (starIdx) {
                              return Icon(
                                starIdx < r.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 14,
                                color: const Color(0xFFF59E0B),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r.comment,
                        style: const TextStyle(fontSize: 13, color: _primaryDark, height: 1.4),
                      ),
                      if (r.replyText != null && r.replyText!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Store Owner Response:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _brandOrange,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.replyText!,
                                style: const TextStyle(fontSize: 12, color: _subGrey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── About Tab ──────────────────────────────────────────────────────────────
  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About Business',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryDark),
                ),
                const SizedBox(height: 8),
                Text(
                  _business.description != null && _business.description!.isNotEmpty
                      ? _business.description!
                      : 'No detailed description provided by this business.',
                  style: const TextStyle(fontSize: 13, color: _subGrey, height: 1.5),
                ),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),
                _buildInfoRow(
                  icon: Icons.access_time_rounded,
                  label: 'Operating Hours',
                  value: _business.displayOperatingHours,
                ),
                if (_business.address != null && _business.address!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: _business.address!,
                  ),
                ],
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.near_me_outlined,
                  label: 'Distance',
                  value: '--',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Contact',
                  value: (_business.phone != null && _business.phone!.trim().isNotEmpty)
                      ? _business.phone!
                      : 'Contact unavailable',
                ),
                if (_business.email != null && _business.email!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _business.email!,
                  ),
                ],
                if (_business.website != null && _business.website!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.language_outlined,
                    label: 'Website',
                    value: _business.website!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _subGrey),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: _subGrey)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bottom Fixed Contact Bar ───────────────────────────────────────────────
  Widget _buildBottomContactBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openInquirySheet(),
                icon: const Icon(Icons.send_rounded, size: 16, color: _brandOrange),
                label: const Text(
                  'Send Inquiry',
                  style: TextStyle(color: _brandOrange, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: _brandOrange),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openingChat ? null : _handleChat,
                icon: _openingChat
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text(
                  'Chat with Shop',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
