import 'package:dio/dio.dart';
import '../../../core/api_config.dart';
import '../../../services/authenticated_dio.dart';
import '../models/business_models.dart';

class BusinessService {
  static final BusinessService _instance = BusinessService._internal();
  factory BusinessService() => _instance;
  BusinessService._internal();

  final Dio _dio = AuthenticatedDio().dio;

  // In-memory cache for demo/offline resilience
  BusinessProfileModel? _cachedProfile;
  final List<BusinessProductModel> _mockProducts = [
    BusinessProductModel(
      id: 'p1',
      businessId: 1,
      name: 'Organic Desi Cow Ghee (500ml)',
      description: 'Pure Vedic bilona method cultured cow ghee directly sourced from local farm.',
      price: 650.0,
      originalPrice: 750.0,
      inStock: true,
      category: 'Dairy & Ghee',
    ),
    BusinessProductModel(
      id: 'p2',
      businessId: 1,
      name: 'Whole Wheat Farm Atta (10kg)',
      description: 'Stone ground 100% whole grain wheat flour with zero maida or preservatives.',
      price: 420.0,
      originalPrice: 480.0,
      inStock: true,
      category: 'Flour & Grains',
    ),
    BusinessProductModel(
      id: 'p3',
      businessId: 1,
      name: 'Cold Pressed Mustard Oil (1L)',
      description: 'Kachi Ghani pure yellow mustard cooking oil.',
      price: 210.0,
      originalPrice: 240.0,
      inStock: true,
      category: 'Oils & Spices',
    ),
    BusinessProductModel(
      id: 'p4',
      businessId: 1,
      name: 'Fresh Paneer / Cottage Cheese (250g)',
      description: 'Made fresh every morning from whole milk.',
      price: 110.0,
      inStock: false,
      category: 'Dairy & Ghee',
    ),
  ];

  final List<BusinessOfferModel> _mockOffers = [
    BusinessOfferModel(
      id: 1,
      businessId: 1,
      title: 'Neighbourhood Weekend Fest',
      description: 'Get flat 15% discount on all monthly grocery hampers above ₹1,500.',
      discountPercent: 15,
      promoCode: 'GALI15',
      validUntil: 'Valid till Sunday 9 PM',
      isActive: true,
    ),
    BusinessOfferModel(
      id: 2,
      businessId: 1,
      title: 'Free Society Doorstep Delivery',
      description: 'Zero delivery fee for orders within 1km radius from our storefront.',
      discountPercent: 10,
      promoCode: 'FREESHIP',
      validUntil: 'Ongoing season offer',
      isActive: true,
    ),
  ];

  final List<BusinessLeadModel> _mockLeads = [
    BusinessLeadModel(
      id: 'lead-1',
      businessId: 1,
      customerName: 'Anil Sharma (Flat B-504)',
      customerPhone: '+91 98112 34567',
      inquiryType: 'Monthly Ration Order',
      message: 'Can you deliver the 10kg Atta and 2L mustard oil today by 6 PM to Palm Heights?',
      status: 'NEW',
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    BusinessLeadModel(
      id: 'lead-2',
      businessId: 1,
      customerName: 'Priya Mehra (Tower A)',
      customerPhone: '+91 97123 45678',
      inquiryType: 'Stock Inquiry',
      message: 'When will fresh Desi Cow Ghee batch arrive? Need 2 jars.',
      status: 'CONTACTED',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    BusinessLeadModel(
      id: 'lead-3',
      businessId: 1,
      customerName: 'Vikram Joshi',
      customerPhone: '+91 99234 56789',
      inquiryType: 'Bulk Society Purchase',
      message: 'Needed pricing quotation for Diwali society gift hampers.',
      status: 'CONVERTED',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<BusinessReviewModel> _mockReviews = [
    BusinessReviewModel(
      id: 1,
      businessId: 1,
      userName: 'Dr. Rajesh Gupta',
      rating: 5.0,
      comment: 'Excellent quality grocery. The desi cow ghee is top notch and delivery to society is within 30 minutes!',
      replyText: 'Thank you Dr. Gupta for your continuous trust! Always happy to serve our neighbourhood.',
      repliedAt: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    BusinessReviewModel(
      id: 2,
      businessId: 1,
      userName: 'Sneha Verma',
      rating: 4.5,
      comment: 'Very polite shopkeeper and fresh dairy products. Would recommend to all neighbours in Sector 4.',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  // ── Profile Methods ──────────────────────────────────────────────────────────
  Future<BusinessProfileModel> getMyBusinessProfile() async {
    try {
      final response = await _dio.get('${ApiConfig.baseUrl}/business-profile/me');
      if (response.statusCode == 200 && response.data != null) {
        final profileData = response.data['data'] ?? response.data;
        _cachedProfile = BusinessProfileModel.fromJson(profileData);
        return _cachedProfile!;
      }
    } catch (_) {
      // Fallback if backend route not seeded yet
    }

    if (_cachedProfile != null) return _cachedProfile!;

    // Curated initial profile
    _cachedProfile = BusinessProfileModel(
      id: 1,
      businessName: 'Verma Supermart & Daily Fresh',
      categoryName: 'Grocery & Daily Essentials',
      description:
          'Your trusted neighbourhood supermarket serving fresh farm dairy, whole grain flours, organic spices, and daily household supplies with free 30-min doorstep delivery to society towers.',
      address: 'Shop #4, Commercial Complex, Main Gali Road, Near Gate 2',
      phone: '+91 98765 12340',
      email: 'verma.supermart@smartgali.local',
      website: 'https://smartgali.in/shops/verma-supermart',
      operatingHours: '7:30 AM - 10:30 PM (All 7 Days)',
      isVerified: true,
      rating: 4.8,
      reviewCount: 48,
      isOpen: true,
    );
    return _cachedProfile!;
  }

  Future<void> updateBusinessProfile(BusinessProfileModel updated) async {
    _cachedProfile = updated;
    try {
      await _dio.put(
        '${ApiConfig.baseUrl}/business-profile/${updated.id}',
        data: {
          'name': updated.businessName,
          'description': updated.description,
          'address': updated.address,
          'contactNumber': updated.phone,
          'operatingHours': updated.operatingHours,
          'isOpen': updated.isOpen,
        },
      );
    } catch (_) {
      // Resilient local update
    }
  }

  // ── Products ───────────────────────────────────────────────────────────────
  Future<List<BusinessProductModel>> getProducts(int businessId) async {
    return List.from(_mockProducts);
  }

  Future<void> addProduct(BusinessProductModel product) async {
    _mockProducts.insert(0, product);
  }

  Future<void> updateProduct(BusinessProductModel product) async {
    final idx = _mockProducts.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      _mockProducts[idx] = product;
    }
  }

  Future<void> deleteProduct(String productId) async {
    _mockProducts.removeWhere((p) => p.id == productId);
  }

  Future<void> toggleProductStock(String productId) async {
    final idx = _mockProducts.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final p = _mockProducts[idx];
      _mockProducts[idx] = BusinessProductModel(
        id: p.id,
        businessId: p.businessId,
        name: p.name,
        description: p.description,
        price: p.price,
        originalPrice: p.originalPrice,
        imageUrl: p.imageUrl,
        inStock: !p.inStock,
        category: p.category,
      );
    }
  }

  // ── Offers ─────────────────────────────────────────────────────────────────
  Future<List<BusinessOfferModel>> getOffers(int businessId) async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/business-offer/business/$businessId');
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data['data'] ?? res.data;
        if (list.isNotEmpty) {
          return list.map((e) => BusinessOfferModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}
    return List.from(_mockOffers);
  }

  Future<void> createOffer(BusinessOfferModel offer) async {
    _mockOffers.insert(0, offer);
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/business-offer',
        data: offer.toJson(),
      );
    } catch (_) {}
  }

  Future<void> deleteOffer(int offerId) async {
    _mockOffers.removeWhere((o) => o.id == offerId);
    try {
      await _dio.delete('${ApiConfig.baseUrl}/business-offer/$offerId');
    } catch (_) {}
  }

  // ── Leads ──────────────────────────────────────────────────────────────────
  Future<List<BusinessLeadModel>> getLeads(int businessId) async {
    return List.from(_mockLeads);
  }

  Future<void> updateLeadStatus(String leadId, String newStatus) async {
    final idx = _mockLeads.indexWhere((l) => l.id == leadId);
    if (idx != -1) {
      final l = _mockLeads[idx];
      _mockLeads[idx] = BusinessLeadModel(
        id: l.id,
        businessId: l.businessId,
        customerName: l.customerName,
        customerPhone: l.customerPhone,
        inquiryType: l.inquiryType,
        message: l.message,
        status: newStatus.toUpperCase(),
        createdAt: l.createdAt,
      );
    }
  }

  // ── Reviews ────────────────────────────────────────────────────────────────
  Future<List<BusinessReviewModel>> getReviews(int businessId) async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/business-review/business/$businessId');
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data['data'] ?? res.data;
        if (list.isNotEmpty) {
          return list.map((e) => BusinessReviewModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}
    return List.from(_mockReviews);
  }

  Future<void> replyToReview(int reviewId, String replyText) async {
    final idx = _mockReviews.indexWhere((r) => r.id == reviewId);
    if (idx != -1) {
      final r = _mockReviews[idx];
      _mockReviews[idx] = BusinessReviewModel(
        id: r.id,
        businessId: r.businessId,
        userName: r.userName,
        userAvatar: r.userAvatar,
        rating: r.rating,
        comment: r.comment,
        replyText: replyText,
        repliedAt: DateTime.now(),
        createdAt: r.createdAt,
      );
    }
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/business-review/$reviewId/reply',
        data: {'reply': replyText},
      );
    } catch (_) {}
  }
}
