import 'dart:async';
import 'dart:io' as dart_io;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_config.dart';
import '../models/event_model.dart';
import 'authenticated_dio.dart';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

typedef EventTokenProvider = Future<String?> Function();

class EventServiceException implements Exception {
  final String message;
  final int? statusCode;

  const EventServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class EventService {
  static final EventService _instance = EventService._internal();
  factory EventService() => _instance;
  EventService._internal()
      : _dio = AuthenticatedDio().dio,
        _tokenProvider = _readStoredToken;

  EventService.forTesting(
    this._dio, {
    required this._tokenProvider,
  });

  final Dio _dio;
  final EventTokenProvider _tokenProvider;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  
  static Future<String?> _readStoredToken() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null && token.trim().isNotEmpty) return token.trim();
    final access = await _storage.read(key: 'accessToken');
    if (access != null && access.trim().isNotEmpty) return access.trim();
    return null;
  }

  static EventServiceException _formatDioError(DioException e, String defaultMsg) {
    final data = e.response?.data;
    String message = defaultMsg;
    if (data is Map<String, dynamic>) {
      if (data['message'] != null && data['message'].toString().isNotEmpty) {
        message = data['message'].toString();
      }
      if (data['errors'] != null) {
        final errs = data['errors'];
        if (errs is List && errs.isNotEmpty) {
          message = '$message: ${errs.join(', ')}';
        } else if (errs is String && errs.isNotEmpty) {
          message = '$message: $errs';
        }
      }
    } else if (e.response?.statusMessage != null && e.response!.statusMessage!.isNotEmpty) {
      message = '$defaultMsg: ${e.response!.statusMessage}';
    } else if (e.message != null && e.message!.isNotEmpty) {
      message = '$defaultMsg (${e.message})';
    }
    return EventServiceException(message, statusCode: e.response?.statusCode);
  }

  Future<Options> _authOptions({bool optional = false}) async {
    final token = await _tokenProvider();
    if (token == null || token.trim().isEmpty) {
      if (optional) {
        return Options();
      }
      throw const EventServiceException('Please log in to continue.');
    }
    return Options(headers: {'Authorization': 'Bearer ${token.trim()}'});
  }

  /// Fetch Upcoming Events with filters and keyset pagination
  Future<({List<EventModel> events, String? nextCursor, bool hasMore})> getUpcomingEvents({
    int? categoryId,
    String? eventType,
    int? communityId,
    String? search,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final options = await _authOptions(optional: true);
      final query = <String, dynamic>{
        'limit': limit,
        if (categoryId != null) 'category_id': categoryId,
        if (eventType != null && eventType.isNotEmpty) 'event_type': eventType,
        if (communityId != null) 'community_id': communityId,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };

      final response = await _dio.get(
        ApiConfig.upcomingEvents,
        queryParameters: query,
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : <String, dynamic>{};
      final rawEvents = (data['events'] ?? body['events'] ?? []) as List<dynamic>;

      final events = rawEvents
          .whereType<Map<String, dynamic>>()
          .map((item) => EventModel.fromJson(item))
          .toList();

      final nextCursor = data['nextCursor']?.toString();
      final hasMore = data['hasMore'] == true;

      return (events: events, nextCursor: nextCursor, hasMore: hasMore);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load upcoming events.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Fetch Nearby Events by coordinates & radius
  Future<({List<EventModel> events, String? nextCursor, bool hasMore})> getNearbyEvents({
    required double lat,
    required double lng,
    double radiusKm = 50,
    int? categoryId,
    String? eventType,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final options = await _authOptions(optional: true);
      final query = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'radiusKm': radiusKm,
        'limit': limit,
        if (categoryId != null) 'category_id': categoryId,
        if (eventType != null && eventType.isNotEmpty) 'event_type': eventType,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };

      final response = await _dio.get(
        ApiConfig.nearbyEvents,
        queryParameters: query,
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : <String, dynamic>{};
      final rawEvents = (data['events'] ?? body['events'] ?? []) as List<dynamic>;

      final events = rawEvents
          .whereType<Map<String, dynamic>>()
          .map((item) => EventModel.fromJson(item))
          .toList();

      final nextCursor = data['nextCursor']?.toString();
      final hasMore = data['hasMore'] == true;

      return (events: events, nextCursor: nextCursor, hasMore: hasMore);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load nearby events.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Fetch My RSVPs
  Future<({List<EventModel> events, String? nextCursor, bool hasMore})> getMyRsvps({
    String? status,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final options = await _authOptions();
      final query = <String, dynamic>{
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };

      final response = await _dio.get(
        ApiConfig.myEventRsvps,
        queryParameters: query,
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : <String, dynamic>{};
      final rawList = (data['rsvps'] ?? body['rsvps'] ?? []) as List<dynamic>;

      final events = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final eventJson = item['event'] is Map<String, dynamic> ? item['event'] as Map<String, dynamic> : item;
            final ev = EventModel.fromJson(eventJson);
            return ev.copyWith(myRsvpStatus: item['status']?.toString());
          })
          .toList();

      final nextCursor = data['nextCursor']?.toString();
      final hasMore = data['hasMore'] == true;

      return (events: events, nextCursor: nextCursor, hasMore: hasMore);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load RSVPs.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Fetch Event Details by ID
  Future<EventModel> getEventDetails(int id) async {
    try {
      final options = await _authOptions(optional: true);
      final response = await _dio.get(
        ApiConfig.eventDetails(id),
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : body;
      return EventModel.fromJson(data);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load event details.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Fetch Event Categories
  Future<List<EventCategoryModel>> getEventCategories() async {
    try {
      final options = await _authOptions(optional: true);
      final response = await _dio.get(
        ApiConfig.eventCategories,
        options: options,
      );

      final body = response.data;
      final rawList = (body['data'] ?? body) as List<dynamic>;

      return rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => EventCategoryModel.fromJson(item))
          .toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load event categories.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Create Event (with optional cover image upload)
  Future<EventModel> createEvent({
    required String title,
    String? description,
    int? categoryId,
    int? communityId,
    String eventType = 'offline',
    String visibility = 'public',
    required DateTime startAt,
    DateTime? endAt,
    String? location,
    String? locationName,
    String? address,
    double? latitude,
    double? longitude,
    int? maxParticipants,
    dart_io.File? coverImageFile,
  }) async {
    try {
      final options = await _authOptions();

      dynamic requestData;
      // MultipartFile.fromFile is NOT available on Flutter Web.
      // On web, always use JSON body. On native, use multipart when a file is provided.
      if (coverImageFile != null && !kIsWeb) {
        final formData = FormData();
        formData.fields.addAll([
          MapEntry('title', title),
          if (description != null && description.isNotEmpty) MapEntry('description', description),
          if (categoryId != null) MapEntry('category_id', categoryId.toString()),
          if (communityId != null) MapEntry('community_id', communityId.toString()),
          MapEntry('event_type', eventType),
          MapEntry('visibility', visibility),
          MapEntry('start_at', startAt.toUtc().toIso8601String()),
          if (endAt != null) MapEntry('end_at', endAt.toUtc().toIso8601String()),
          if (location != null && location.isNotEmpty) MapEntry('location', location),
          if (locationName != null && locationName.isNotEmpty) MapEntry('location_name', locationName),
          if (address != null && address.isNotEmpty) MapEntry('address', address),
          if (latitude != null) MapEntry('latitude', latitude.toString()),
          if (longitude != null) MapEntry('longitude', longitude.toString()),
          if (maxParticipants != null) MapEntry('max_participants', maxParticipants.toString()),
        ]);

        final pathSegments = coverImageFile.path.split(RegExp(r'[/\\]'));
        final fileName = pathSegments.isNotEmpty && pathSegments.last.trim().isNotEmpty
            ? pathSegments.last.trim()
            : 'cover_image.jpg';
        formData.files.add(
          MapEntry(
            'cover_image',
            await MultipartFile.fromFile(coverImageFile.path, filename: fileName),
          ),
        );
        requestData = formData;
      } else {
        requestData = {
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          if (categoryId != null) 'category_id': categoryId,
          if (communityId != null) 'community_id': communityId,
          'event_type': eventType,
          'visibility': visibility,
          'start_at': startAt.toUtc().toIso8601String(),
          if (endAt != null) 'end_at': endAt.toUtc().toIso8601String(),
          if (location != null && location.isNotEmpty) 'location': location,
          if (locationName != null && locationName.isNotEmpty) 'location_name': locationName,
          if (address != null && address.isNotEmpty) 'address': address,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (maxParticipants != null) 'max_participants': maxParticipants,
        };
      }

      final response = await _dio.post(
        ApiConfig.events,
        data: requestData,
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : body;
      return EventModel.fromJson(data);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to create event.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Set RSVP for an Event
  Future<({int goingCount, int interestedCount, int declinedCount, String status})> setEventRsvp(
    int eventId,
    String status,
  ) async {
    try {
      final options = await _authOptions();
      final response = await _dio.put(
        ApiConfig.eventRsvp(eventId),
        data: {'status': status},
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : body;

      return (
        goingCount: _asInt(data['going_count']) ?? 0,
        interestedCount: _asInt(data['interested_count']) ?? 0,
        declinedCount: _asInt(data['declined_count']) ?? 0,
        status: data['status']?.toString() ?? status,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update RSVP.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Cancel RSVP
  Future<({int goingCount, int interestedCount, int declinedCount})> cancelEventRsvp(int eventId) async {
    try {
      final options = await _authOptions();
      final response = await _dio.delete(
        ApiConfig.eventRsvp(eventId),
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : body;

      return (
        goingCount: _asInt(data['going_count']) ?? 0,
        interestedCount: _asInt(data['interested_count']) ?? 0,
        declinedCount: _asInt(data['declined_count']) ?? 0,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to cancel RSVP.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Update Event (Host / Admin) — partial update
  Future<EventModel> updateEvent(
    int id, {
    String? title,
    String? description,
    int? categoryId,
    String? eventType,
    String? visibility,
    DateTime? startAt,
    DateTime? endAt,
    String? location,
    String? locationName,
    String? address,
    double? latitude,
    double? longitude,
    int? maxParticipants,
    dart_io.File? coverImageFile,
  }) async {
    try {
      final options = await _authOptions();
      dynamic requestData;

      if (coverImageFile != null && !kIsWeb) {
        final formData = FormData();
        if (title != null && title.isNotEmpty) formData.fields.add(MapEntry('title', title));
        if (description != null) formData.fields.add(MapEntry('description', description));
        if (categoryId != null) formData.fields.add(MapEntry('category_id', categoryId.toString()));
        if (eventType != null) formData.fields.add(MapEntry('event_type', eventType));
        if (visibility != null) formData.fields.add(MapEntry('visibility', visibility));
        if (startAt != null) formData.fields.add(MapEntry('start_at', startAt.toUtc().toIso8601String()));
        if (endAt != null) formData.fields.add(MapEntry('end_at', endAt.toUtc().toIso8601String()));
        if (location != null) formData.fields.add(MapEntry('location', location));
        if (locationName != null) formData.fields.add(MapEntry('location_name', locationName));
        if (address != null) formData.fields.add(MapEntry('address', address));
        if (maxParticipants != null) formData.fields.add(MapEntry('max_participants', maxParticipants.toString()));

        final parts = coverImageFile.path.split(RegExp(r'[/\\]'));
        final fileName = parts.isNotEmpty && parts.last.trim().isNotEmpty ? parts.last.trim() : 'cover_image.jpg';
        formData.files.add(MapEntry(
          'cover_image',
          await MultipartFile.fromFile(coverImageFile.path, filename: fileName),
        ));
        requestData = formData;
      } else {
        requestData = {
          if (title != null && title.isNotEmpty) 'title': title,
          if (description != null) 'description': description,
          if (categoryId != null) 'category_id': categoryId,
          if (eventType != null) 'event_type': eventType,
          if (visibility != null) 'visibility': visibility,
          if (startAt != null) 'start_at': startAt.toUtc().toIso8601String(),
          if (endAt != null) 'end_at': endAt.toUtc().toIso8601String(),
          if (location != null) 'location': location,
          if (locationName != null) 'location_name': locationName,
          if (address != null) 'address': address,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (maxParticipants != null) 'max_participants': maxParticipants,
        };
      }

      final response = await _dio.put(
        ApiConfig.eventDetails(id),
        data: requestData,
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : body;
      return EventModel.fromJson(data);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update event.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Cancel Event (Host / Admin)
  Future<EventModel> cancelEvent(int id, {String? reason}) async {
    try {
      final options = await _authOptions();
      final response = await _dio.put(
        ApiConfig.cancelEvent(id),
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : body;
      return EventModel.fromJson(data);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to cancel event.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Delete Event (Host / Admin)
  Future<void> deleteEvent(int id, {String? reason}) async {
    try {
      final options = await _authOptions();
      await _dio.delete(
        ApiConfig.eventDetails(id),
        data: {if (reason != null && reason.isNotEmpty) 'deletedRemarks': reason},
        options: options,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete event.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }

  /// Fetch Event Participants
  Future<({List<EventParticipantModel> participants, String? nextCursor, bool hasMore})> getEventParticipants(
    int eventId, {
    String? status,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final options = await _authOptions(optional: true);
      final query = <String, dynamic>{
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };

      final response = await _dio.get(
        ApiConfig.eventParticipants(eventId),
        queryParameters: query,
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map<String, dynamic> ? body['data'] : <String, dynamic>{};
      final rawList = (data['participants'] ?? body['participants'] ?? []) as List<dynamic>;

      final participants = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => EventParticipantModel.fromJson(item))
          .toList();

      final nextCursor = data['nextCursor']?.toString();
      final hasMore = data['hasMore'] == true;

      return (participants: participants, nextCursor: nextCursor, hasMore: hasMore);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load participants.');
    } catch (e) {
      throw EventServiceException(e.toString());
    }
  }
}
