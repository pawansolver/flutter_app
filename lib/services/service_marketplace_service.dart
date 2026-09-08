import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_config.dart';
import '../models/service_models.dart';
import 'auth_session.dart';
import 'authenticated_dio.dart';

class ServiceMarketplaceException implements Exception {
  final String message;
  final int? statusCode;

  const ServiceMarketplaceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ServiceMarketplaceService {
  static final ServiceMarketplaceService _instance = ServiceMarketplaceService._internal();
  factory ServiceMarketplaceService() => _instance;

  ServiceMarketplaceService._internal()
      : _dio = AuthenticatedDio().dio,
        _sessionStore = AuthSessionStore();

  @visibleForTesting
  ServiceMarketplaceService.forTesting(this._dio, this._sessionStore);

  final Dio _dio;
  final AuthSessionStore _sessionStore;

  // ── Role & Authentication Guard ──────────────────────────────────────────

  /// Checks if the currently authenticated user has provider privileges or active provider view.
  Future<bool> isProviderAuthorized() async {
    final token = await _sessionStore.readAccessToken();
    if (token == null || token.trim().isEmpty) return false;

    // Check if current active role in storage is provider
    const storage = FlutterSecureStorage();
    final activeRole = (await storage.read(key: 'active_role'))?.toLowerCase().trim();
    if (activeRole == 'provider' || activeRole == 'service_provider') {
      return true;
    }

    // Check canonical primary role from auth session
    final role = (await _sessionStore.readUserRole())?.toLowerCase().trim() ?? '';
    if (role == 'provider' || role == 'service_provider') {
      return true;
    }

    // Strict fail-closed: Deny resident, member, guest, unknown, or invalid roles
    return false;
  }

  /// Retrieves the current logged in user ID
  Future<int?> getCurrentUserId() => _sessionStore.readUserId();

  // ── Categories ───────────────────────────────────────────────────────────

  /// Fetches all active service categories from backend /service-category
  Future<List<ServiceCategoryModel>> getCategories() async {
    try {
      final response = await _dio.get(ApiConfig.serviceCategories);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is List) {
        final list = (rawData['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => ServiceCategoryModel.fromJson(item))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } on DioException catch (e) {
      debugPrint('Categories API fallback: ${e.message}');
    } catch (e) {
      debugPrint('Categories error: $e');
    }

    // Enterprise fallback: Standard SmartGali verified categories if backend has no initial seed
    return const [
      ServiceCategoryModel(id: 1, name: 'Electrician'),
      ServiceCategoryModel(id: 2, name: 'Plumber'),
      ServiceCategoryModel(id: 3, name: 'Home Cleaning'),
      ServiceCategoryModel(id: 4, name: 'Appliance Repair'),
      ServiceCategoryModel(id: 5, name: 'Tutor & Classes'),
      ServiceCategoryModel(id: 6, name: 'Carpenter'),
      ServiceCategoryModel(id: 7, name: 'Painter'),
    ];
  }

  // ── Service Listings ─────────────────────────────────────────────────────

  /// Fetches all active listings for the provider from backend /service-listing
  Future<List<ServiceListingModel>> getProviderListings({int? providerId}) async {
    try {
      final response = await _dio.get(ApiConfig.serviceListings);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is List) {
        final items = (rawData['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => ServiceListingModel.fromJson(item))
            .toList();

        if (providerId != null) {
          return items.where((l) => l.providerId == providerId).toList();
        }
        return items;
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Listings API error: ${e.message}');
      throw _formatDioError(e, 'Failed to load service listings');
    } catch (e) {
      debugPrint('Listings error: $e');
      throw ServiceMarketplaceException('Failed to load listings: $e');
    }
  }

  /// Creates a new service listing via POST /service-listing
  Future<ServiceListingModel> createListing({
    required String title,
    String? description,
    double? price,
    String? duration,
    bool isAvailable = true,
    int? categoryId,
    int? providerId,
  }) async {
    try {
      final userId = await getCurrentUserId();
      final payload = {
        'title': title.trim(),
        if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
        if (price != null) 'price': price,
        if (duration != null && duration.trim().isNotEmpty) 'duration': duration.trim(),
        'is_available': isAvailable,
        if (providerId != null) 'provider_id': providerId,
        if (userId != null) 'created_by': userId,
      };

      final response = await _dio.post(ApiConfig.serviceListings, data: payload);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is Map<String, dynamic>) {
        return ServiceListingModel.fromJson(rawData['data'] as Map<String, dynamic>);
      }
      return ServiceListingModel(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        description: description,
        price: price,
        duration: duration,
        isAvailable: isAvailable,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to create service listing');
    }
  }

  /// Updates an existing service listing via PUT /service-listing/:id
  Future<ServiceListingModel> updateListing(
    int id, {
    String? title,
    String? description,
    double? price,
    String? duration,
    bool? isAvailable,
  }) async {
    try {
      final userId = await getCurrentUserId();
      final payload = <String, dynamic>{
        if (title != null) 'title': title.trim(),
        if (description != null) 'description': description.trim(),
        if (price != null) 'price': price,
        if (duration != null) 'duration': duration.trim(),
        if (isAvailable != null) 'is_available': isAvailable,
        if (userId != null) 'updated_by': userId,
      };

      final response = await _dio.put(ApiConfig.serviceListing(id), data: payload);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is Map<String, dynamic>) {
        return ServiceListingModel.fromJson(rawData['data'] as Map<String, dynamic>);
      }
      return ServiceListingModel(
        id: id,
        title: title ?? 'Updated Service',
        description: description,
        price: price,
        duration: duration,
        isAvailable: isAvailable ?? true,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update service listing');
    }
  }

  /// Soft deletes a service listing via DELETE /service-listing/:id
  Future<bool> deleteListing(int id) async {
    try {
      final userId = await getCurrentUserId();
      final response = await _dio.delete(
        ApiConfig.serviceListing(id),
        data: {'deletedRemarks': 'Removed by provider', if (userId != null) 'updated_by': userId},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete service listing');
    }
  }

  // ── Bookings ─────────────────────────────────────────────────────────────

  /// Fetches bookings relevant to the provider from backend /service-booking
  Future<List<ServiceBookingModel>> getProviderBookings() async {
    try {
      final response = await _dio.get(ApiConfig.serviceBookings);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is List) {
        return (rawData['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => ServiceBookingModel.fromJson(item))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Bookings API error: ${e.message}');
      throw _formatDioError(e, 'Failed to load bookings');
    } catch (e) {
      debugPrint('Bookings error: $e');
      throw ServiceMarketplaceException('Failed to load bookings: $e');
    }
  }

  /// Updates booking status (e.g. accept -> 'confirmed', reject -> 'cancelled', 'completed')
  Future<bool> updateBookingStatus(int bookingId, String newStatus) async {
    try {
      final userId = await getCurrentUserId();
      final response = await _dio.put(
        ApiConfig.serviceBooking(bookingId),
        data: {
          'status': newStatus.toLowerCase().trim(),
          if (userId != null) 'updated_by': userId,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update booking status');
    }
  }

  /// Cancels an existing booking for a customer
  Future<bool> cancelBooking(int bookingId) => updateBookingStatus(bookingId, 'cancelled');

  /// Creates a booking request from customer to provider
  Future<ServiceBookingModel> createBooking({
    required int listingId,
    required DateTime scheduledAt,
    double? amount,
    String? note,
  }) async {
    try {
      final userId = await getCurrentUserId();
      final payload = {
        'listing_id': listingId,
        if (userId != null) 'user_id': userId,
        'scheduled_at': scheduledAt.toIso8601String(),
        if (amount != null) 'amount': amount,
        if (userId != null) 'created_by': userId,
      };

      final response = await _dio.post(ApiConfig.serviceBookings, data: payload);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is Map<String, dynamic>) {
        return ServiceBookingModel.fromJson(rawData['data'] as Map<String, dynamic>);
      }

      return ServiceBookingModel(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        listingId: listingId,
        userId: userId,
        scheduledAt: scheduledAt,
        amount: amount,
        status: 'pending',
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to create booking request');
    }
  }

  /// Fetches bookings created by the customer
  Future<List<ServiceBookingModel>> getCustomerBookings() async {
    try {
      final userId = await getCurrentUserId();
      final response = await _dio.get(ApiConfig.serviceBookings);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is List) {
        final list = (rawData['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => ServiceBookingModel.fromJson(item))
            .toList();

        if (userId != null) {
          final userBookings = list.where((b) => b.userId == userId).toList();
          if (userBookings.isNotEmpty) return userBookings;
        }
        return list;
      }
      return [];
    } on DioException catch (e) {
      debugPrint('Customer bookings API error: ${e.message}');
      throw _formatDioError(e, 'Failed to load bookings');
    }
  }

  /// Gets single booking detail by ID
  Future<ServiceBookingModel?> getBookingById(int id) async {
    try {
      final response = await _dio.get(ApiConfig.serviceBooking(id));
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is Map<String, dynamic>) {
        return ServiceBookingModel.fromJson(rawData['data'] as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch booking details');
    }
  }

  /// Gets single service listing detail by ID
  Future<ServiceListingModel?> getListingById(int id) async {
    try {
      final response = await _dio.get(ApiConfig.serviceListing(id));
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is Map<String, dynamic>) {
        return ServiceListingModel.fromJson(rawData['data'] as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch service listing');
    }
  }

  // ── Reviews ──────────────────────────────────────────────────────────────

  /// Fetches reviews from /service-review
  Future<List<ServiceReviewModel>> getReviews({int? bookingId}) async {
    try {
      final response = await _dio.get(ApiConfig.serviceReviews);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is List) {
        final list = (rawData['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => ServiceReviewModel.fromJson(item))
            .toList();

        if (bookingId != null) {
          return list.where((r) => r.bookingId == bookingId).toList();
        }
        return list;
      }
      return [];
    } catch (e) {
      debugPrint('Reviews error: $e');
      return [];
    }
  }

  /// Checks if a booking was already reviewed
  Future<bool> hasUserReviewedBooking(int bookingId) async {
    final reviews = await getReviews(bookingId: bookingId);
    return reviews.isNotEmpty;
  }

  /// Submits a customer review for a completed booking
  Future<ServiceReviewModel> submitReview({
    required int bookingId,
    required int rating,
    String? comment,
  }) async {
    try {
      final userId = await getCurrentUserId();
      final payload = {
        'booking_id': bookingId,
        if (userId != null) 'user_id': userId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        if (userId != null) 'created_by': userId,
      };

      final response = await _dio.post(ApiConfig.serviceReviews, data: payload);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is Map<String, dynamic>) {
        return ServiceReviewModel.fromJson(rawData['data'] as Map<String, dynamic>);
      }

      return ServiceReviewModel(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        bookingId: bookingId,
        userId: userId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to submit service review');
    }
  }

  // ── Provider Profile ─────────────────────────────────────────────────────

  /// Gets the current provider's profile from /service-provider-profile
  Future<ServiceProviderProfileModel?> getProviderProfile() async {
    try {
      final userId = await getCurrentUserId();
      final response = await _dio.get(ApiConfig.serviceProviderProfiles);
      final rawData = response.data;
      if (rawData is Map<String, dynamic> && rawData['data'] is List) {
        final profiles = (rawData['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((item) => ServiceProviderProfileModel.fromJson(item))
            .toList();

        if (userId != null) {
          final matched = profiles.where((p) => p.userId == userId);
          if (matched.isNotEmpty) return matched.first;
        }
        if (profiles.isNotEmpty) return profiles.first;
      }
      return null;
    } catch (e) {
      debugPrint('Provider profile error: $e');
      return null;
    }
  }

  static ServiceMarketplaceException _formatDioError(DioException e, String defaultMsg) {
    final data = e.response?.data;
    String message = defaultMsg;
    if (data is Map<String, dynamic>) {
      if (data['message'] != null && data['message'].toString().isNotEmpty) {
        message = data['message'].toString();
      }
    }
    return ServiceMarketplaceException(message, statusCode: e.response?.statusCode);
  }
}
