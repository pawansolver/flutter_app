import 'package:dio/dio.dart';
import '../../../core/api_config.dart';
import '../../../services/authenticated_dio.dart';
import '../models/business_models.dart';

class BusinessService {
  static final BusinessService _instance = BusinessService._internal();
  factory BusinessService() => _instance;
  BusinessService._internal();

  final Dio _dio = AuthenticatedDio().dio;

  // In-memory cache for state persistence during current session
  BusinessProfileModel? _cachedProfile;
  final List<BusinessProductModel> _sessionProducts = [];
  final List<BusinessOfferModel> _sessionOffers = [];
  final List<BusinessLeadModel> _sessionLeads = [];
  final List<BusinessReviewModel> _sessionReviews = [];

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

    // Honest initial profile with no fake ratings or invented hours
    _cachedProfile = BusinessProfileModel(
      id: 1,
      businessName: 'My Local Business',
      categoryName: 'General Store',
      description: 'Add your business description here to reach neighbours.',
      address: null,
      phone: null,
      email: null,
      website: null,
      operatingHours: null,
      isVerified: false,
      rating: null,
      reviewCount: null,
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

  // ── Public Directory & Discovery Methods ──────────────────────────────────────
  Future<List<BusinessProfileModel>> getBusinesses({
    int? categoryId,
    String? search,
    bool? isVerified,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null && categoryId > 0) queryParams['category_id'] = categoryId;
      if (isVerified == true) queryParams['is_verified'] = 'true';

      final response = await _dio.get(
        '${ApiConfig.baseUrl}/business-profile',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final List rawList = response.data is List
            ? response.data
            : (response.data['data'] is List ? response.data['data'] : []);

        List<BusinessProfileModel> results = rawList
            .map((item) => BusinessProfileModel.fromJson(item as Map<String, dynamic>))
            .toList();

        if (search != null && search.trim().isNotEmpty) {
          final query = search.trim().toLowerCase();
          results = results.where((b) {
            final nameMatch = b.businessName.toLowerCase().contains(query);
            final catMatch = b.categoryName.toLowerCase().contains(query);
            final descMatch = b.description?.toLowerCase().contains(query) ?? false;
            return nameMatch || catMatch || descMatch;
          }).toList();
        }

        return results;
      }
    } catch (_) {
      // Handle network or endpoint issue safely
    }

    // If backend profile list is empty or offline, check cached profile
    if (_cachedProfile != null) {
      if (search != null && search.trim().isNotEmpty) {
        if (_cachedProfile!.businessName.toLowerCase().contains(search.toLowerCase())) {
          return [_cachedProfile!];
        }
        return [];
      }
      return [_cachedProfile!];
    }

    return [];
  }

  Future<BusinessProfileModel?> getBusinessById(int id) async {
    try {
      final response = await _dio.get('${ApiConfig.baseUrl}/business-profile/$id');
      if (response.statusCode == 200 && response.data != null) {
        final profileData = response.data['data'] ?? response.data;
        return BusinessProfileModel.fromJson(profileData);
      }
    } catch (_) {}

    if (_cachedProfile != null && _cachedProfile!.id == id) {
      return _cachedProfile;
    }
    return null;
  }

  Future<List<BusinessCategoryModel>> getCategories() async {
    try {
      final response = await _dio.get('${ApiConfig.baseUrl}/business-category');
      if (response.statusCode == 200 && response.data != null) {
        final List list = response.data is List
            ? response.data
            : (response.data['data'] is List ? response.data['data'] : []);
        if (list.isNotEmpty) {
          return list.map((e) => BusinessCategoryModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}

    // Standard taxonomy categories for SmartGali
    return [
      BusinessCategoryModel(id: 1, name: 'Grocery & Kirana', icon: 'storefront'),
      BusinessCategoryModel(id: 2, name: 'Dairy & Milk', icon: 'water_drop'),
      BusinessCategoryModel(id: 3, name: 'Bakery & Sweets', icon: 'bakery_dining'),
      BusinessCategoryModel(id: 4, name: 'Pharmacy & Medical', icon: 'local_pharmacy'),
      BusinessCategoryModel(id: 5, name: 'Fruits & Vegetables', icon: 'eco'),
      BusinessCategoryModel(id: 6, name: 'Electronics & Electrical', icon: 'electrical_services'),
      BusinessCategoryModel(id: 7, name: 'Hardware & Sanitary', icon: 'handyman'),
      BusinessCategoryModel(id: 8, name: 'Stationery & Books', icon: 'menu_book'),
    ];
  }

  // ── Products ───────────────────────────────────────────────────────────────
  Future<List<BusinessProductModel>> getProducts(int businessId) async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/business-product/business/$businessId');
      if (res.statusCode == 200 && res.data != null) {
        final List list = res.data['data'] ?? res.data;
        if (list.isNotEmpty) {
          return list.map((e) => BusinessProductModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}
    return _sessionProducts.where((p) => p.businessId == businessId).toList();
  }

  Future<void> addProduct(BusinessProductModel product) async {
    _sessionProducts.insert(0, product);
  }

  Future<void> updateProduct(BusinessProductModel product) async {
    final idx = _sessionProducts.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      _sessionProducts[idx] = product;
    }
  }

  Future<void> deleteProduct(String productId) async {
    _sessionProducts.removeWhere((p) => p.id == productId);
  }

  Future<void> toggleProductStock(String productId) async {
    final idx = _sessionProducts.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final p = _sessionProducts[idx];
      _sessionProducts[idx] = BusinessProductModel(
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
    return _sessionOffers.where((o) => o.businessId == businessId).toList();
  }

  Future<void> createOffer(BusinessOfferModel offer) async {
    _sessionOffers.insert(0, offer);
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/business-offer',
        data: offer.toJson(),
      );
    } catch (_) {}
  }

  Future<void> deleteOffer(int offerId) async {
    _sessionOffers.removeWhere((o) => o.id == offerId);
    try {
      await _dio.delete('${ApiConfig.baseUrl}/business-offer/$offerId');
    } catch (_) {}
  }

  // ── Leads ──────────────────────────────────────────────────────────────────
  Future<List<BusinessLeadModel>> getLeads(int businessId) async {
    return _sessionLeads.where((l) => l.businessId == businessId).toList();
  }

  Future<void> submitLead(BusinessLeadModel lead) async {
    _sessionLeads.insert(0, lead);
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/business-lead',
        data: lead.toJson(),
      );
    } catch (_) {}
  }

  Future<void> updateLeadStatus(String leadId, String newStatus) async {
    final idx = _sessionLeads.indexWhere((l) => l.id == leadId);
    if (idx != -1) {
      final l = _sessionLeads[idx];
      _sessionLeads[idx] = BusinessLeadModel(
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
    return _sessionReviews.where((r) => r.businessId == businessId).toList();
  }

  Future<void> createReview({
    required int businessId,
    required double rating,
    required String comment,
    String? userName,
  }) async {
    final review = BusinessReviewModel(
      id: DateTime.now().millisecondsSinceEpoch,
      businessId: businessId,
      userName: userName ?? 'Neighbourhood Resident',
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );
    _sessionReviews.insert(0, review);

    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/business-review',
        data: {
          'business_id': businessId,
          'rating': rating,
          'comment': comment,
        },
      );
    } catch (_) {}
  }

  Future<void> replyToReview(int reviewId, String replyText) async {
    final idx = _sessionReviews.indexWhere((r) => r.id == reviewId);
    if (idx != -1) {
      final r = _sessionReviews[idx];
      _sessionReviews[idx] = BusinessReviewModel(
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
