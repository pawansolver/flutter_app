import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_config.dart';
import '../models/society_models.dart';
import 'authenticated_dio.dart';

typedef SocietyTokenProvider = Future<String?> Function();

class SocietyServiceException implements Exception {
  final String message;
  final int? statusCode;

  const SocietyServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

Map<String, dynamic> _toMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

class SocietyService {
  static final SocietyService _instance = SocietyService._internal();
  factory SocietyService() => _instance;

  SocietyService._internal()
      : _dio = AuthenticatedDio().dio,
        _tokenProvider = _readStoredToken;

  SocietyService.forTesting(
    this._dio, {
    required this._tokenProvider,
  });

  final Dio _dio;
  final SocietyTokenProvider _tokenProvider;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> _readStoredToken() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token != null && token.trim().isNotEmpty) return token.trim();
    final access = await _storage.read(key: 'accessToken');
    if (access != null && access.trim().isNotEmpty) return access.trim();
    return null;
  }

  static SocietyServiceException _formatDioError(DioException e, String defaultMsg) {
    final data = e.response?.data;
    String message = defaultMsg;
    if (data is Map) {
      final mapData = _toMap(data);
      if (mapData['message'] != null && mapData['message'].toString().isNotEmpty) {
        message = mapData['message'].toString();
      }
      if (mapData['errors'] != null) {
        final errs = mapData['errors'];
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
    return SocietyServiceException(message, statusCode: e.response?.statusCode);
  }

  Future<Options> _authOptions({bool optional = false}) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      if (optional) return Options();
      throw const SocietyServiceException('Authentication required', statusCode: 401);
    }
    return Options(headers: {
      'Authorization': 'Bearer $token',
    });
  }

  // ─── 0. Active User Society Resolver ──────────────────────────────────────
  Future<SocietyProfileModel?> getMySociety() async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(ApiConfig.society, options: opts);
      final body = _toMap(res.data);
      final data = body['data'];
      if (data is Map) {
        return SocietyProfileModel.fromJson(_toMap(data));
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<int?> resolveActiveSocietyId([int? explicitId]) async {
    if (explicitId != null && explicitId > 0) return explicitId;
    try {
      final mySoc = await getMySociety();
      if (mySoc != null && mySoc.id > 0) return mySoc.id;
    } catch (_) {}
    try {
      final socs = await getSocieties(limit: 1);
      if (socs.data.isNotEmpty) return socs.data.first.id;
    } catch (_) {}
    return null;
  }

  // ─── 1. Society Profile APIs ──────────────────────────────────────────────
  Future<SocietyPaginatedResponse<SocietyProfileModel>> getSocieties({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final opts = await _authOptions(optional: true);
      final query = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      };
      final res = await _dio.get(ApiConfig.societyProfiles, queryParameters: query, options: opts);
      final body = _toMap(res.data);
      return SocietyPaginatedResponse<SocietyProfileModel>.fromJson(
        body,
        (item) => SocietyProfileModel.fromJson(_toMap(item)),
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load societies');
    }
  }

  Future<SocietyProfileModel> getSocietyDetail(int id) async {
    try {
      final opts = await _authOptions(optional: true);
      final res = await _dio.get(ApiConfig.societyProfile(id), options: opts);
      final body = _toMap(res.data);
      final data = body['data'];
      if (data is Map) {
        return SocietyProfileModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid society detail response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch society details');
    }
  }

  Future<SocietyProfileModel> createSociety({
    required String societyName,
    String? registrationNo,
    String? address,
    double? latitude,
    double? longitude,
    int? totalFlats,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_name': societyName.trim(),
        if (registrationNo != null) 'registration_no': registrationNo.trim(),
        if (address != null) 'address': address.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (totalFlats != null) 'total_flats': totalFlats,
      };
      final res = await _dio.post(ApiConfig.societyProfiles, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyProfileModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid create society response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to create society');
    }
  }

  Future<SocietyProfileModel> updateSociety(int id, Map<String, dynamic> updateData) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.put(ApiConfig.societyProfile(id), data: updateData, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyProfileModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid update society response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update society');
    }
  }

  Future<void> deleteSociety(int id, {String? deletedRemarks}) async {
    try {
      final opts = await _authOptions();
      await _dio.delete(
        ApiConfig.societyProfile(id),
        data: {'deletedRemarks': deletedRemarks ?? 'Deleted by user'},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete society');
    }
  }

  Future<SocietyProfileModel> transferOwnership(int id, {required int targetUserId}) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.post(
        ApiConfig.transferSocietyOwnership(id),
        data: {'target_user_id': targetUserId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyProfileModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid transfer ownership response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to transfer ownership');
    }
  }

  // ─── 2. Society Member APIs ───────────────────────────────────────────────
  Future<SocietyPaginatedResponse<SocietyMemberModel>> getMembers(
    int societyId, {
    String? role,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final opts = await _authOptions();
      final query = <String, dynamic>{
        'society_id': societyId,
        'page': page,
        'limit': limit,
        if (role != null && role.isNotEmpty) 'role': role,
        if (status != null && status.isNotEmpty) 'status': status,
      };
      final res = await _dio.get(ApiConfig.societyMembers, queryParameters: query, options: opts);
      final body = _toMap(res.data);
      return SocietyPaginatedResponse<SocietyMemberModel>.fromJson(
        body,
        (item) => SocietyMemberModel.fromJson(_toMap(item)),
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load society members');
    }
  }

  Future<SocietyMemberModel> getMember(int id, int societyId) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(
        ApiConfig.societyMember(id),
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyMemberModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid member response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch member detail');
    }
  }

  Future<SocietyMemberModel> joinSociety(int societyId, {String? flatNo, String? role}) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        if (flatNo != null) 'flat_no': flatNo.trim(),
        if (role != null) 'role': role,
      };
      final res = await _dio.post(ApiConfig.societyMembers, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyMemberModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid join society response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to register society membership');
    }
  }

  Future<SocietyMemberModel> approveMember(
    int id,
    int societyId, {
    required String status,
    String? remark,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'status': status,
        if (remark != null) 'remark': remark,
      };
      final res = await _dio.put(ApiConfig.approveSocietyMember(id), data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyMemberModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid approve response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update member approval status');
    }
  }

  Future<SocietyMemberModel> updateMemberRole(int id, int societyId, {required String role}) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'role': role,
      };
      final res = await _dio.put(ApiConfig.updateSocietyMemberRole(id), data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyMemberModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid role update response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update member role');
    }
  }

  Future<void> removeMember(int id, int societyId, {String? deletedRemarks}) async {
    try {
      final opts = await _authOptions();
      await _dio.delete(
        ApiConfig.societyMember(id),
        queryParameters: {'society_id': societyId},
        data: {'deletedRemarks': deletedRemarks ?? 'Removed from society'},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to remove society member');
    }
  }

  // ─── 3. Society Announcement APIs ─────────────────────────────────────────
  Future<SocietyPaginatedResponse<SocietyAnnouncementModel>> getAnnouncements(
    int societyId, {
    String? priority,
    String? category,
    bool? isPinned,
    bool includeExpired = false,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final opts = await _authOptions();
      final query = <String, dynamic>{
        'society_id': societyId,
        'page': page,
        'limit': limit,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (category != null && category.isNotEmpty) 'category': category,
        if (isPinned != null) 'is_pinned': isPinned,
        if (includeExpired) 'include_expired': true,
      };
      final res = await _dio.get(ApiConfig.societyAnnouncements, queryParameters: query, options: opts);
      final body = _toMap(res.data);
      return SocietyPaginatedResponse<SocietyAnnouncementModel>.fromJson(
        body,
        (item) => SocietyAnnouncementModel.fromJson(_toMap(item)),
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load announcements');
    }
  }

  Future<SocietyAnnouncementModel> getAnnouncement(int id, int societyId) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(
        ApiConfig.societyAnnouncement(id),
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyAnnouncementModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid announcement response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch announcement');
    }
  }

  Future<SocietyAnnouncementModel> createAnnouncement(
    int societyId, {
    required String title,
    required String message,
    String priority = 'medium',
    String category = 'general',
    bool isPinned = false,
    DateTime? expiresAt,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'title': title.trim(),
        'message': message.trim(),
        'priority': priority,
        'category': category,
        'is_pinned': isPinned,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      };
      final res = await _dio.post(ApiConfig.societyAnnouncements, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyAnnouncementModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid create announcement response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to publish announcement');
    }
  }

  Future<SocietyAnnouncementModel> updateAnnouncement(
    int id,
    int societyId,
    Map<String, dynamic> data,
  ) async {
    try {
      final opts = await _authOptions();
      final body = {'society_id': societyId, ...data};
      final res = await _dio.put(ApiConfig.societyAnnouncement(id), data: body, options: opts);
      final resBody = _toMap(res.data);
      final respData = resBody['data'];
      if (respData is Map) {
        return SocietyAnnouncementModel.fromJson(_toMap(respData));
      }
      throw const SocietyServiceException('Invalid update announcement response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update announcement');
    }
  }

  Future<void> deleteAnnouncement(int id, int societyId, {String? deletedRemarks}) async {
    try {
      final opts = await _authOptions();
      await _dio.delete(
        ApiConfig.societyAnnouncement(id),
        queryParameters: {'society_id': societyId},
        data: {'deletedRemarks': deletedRemarks ?? 'Deleted notice'},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete announcement');
    }
  }

  // ─── 4. Society Complaint APIs ────────────────────────────────────────────
  Future<SocietyPaginatedResponse<SocietyComplaintModel>> getComplaints(
    int societyId, {
    String? status,
    String? priority,
    String? category,
    bool myOnly = false,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final opts = await _authOptions();
      final query = <String, dynamic>{
        'society_id': societyId,
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
        if (priority != null && priority.isNotEmpty) 'priority': priority,
        if (category != null && category.isNotEmpty) 'category': category,
        if (myOnly) 'my_only': true,
      };
      final res = await _dio.get(ApiConfig.societyComplaints, queryParameters: query, options: opts);
      final body = _toMap(res.data);
      return SocietyPaginatedResponse<SocietyComplaintModel>.fromJson(
        body,
        (item) => SocietyComplaintModel.fromJson(_toMap(item)),
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load complaints');
    }
  }

  Future<SocietyComplaintModel> getComplaint(int id, int societyId) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(
        ApiConfig.societyComplaint(id),
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyComplaintModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid complaint response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch complaint detail');
    }
  }

  Future<SocietyComplaintModel> createComplaint(
    int societyId, {
    required String title,
    required String description,
    String category = 'general',
    String priority = 'medium',
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'priority': priority,
      };
      final res = await _dio.post(ApiConfig.societyComplaints, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyComplaintModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid create complaint response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to submit complaint');
    }
  }

  Future<SocietyComplaintModel> updateComplaintStatus(
    int id,
    int societyId, {
    required String status,
    String? remark,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'status': status,
        if (remark != null) 'remark': remark,
      };
      final res = await _dio.put(ApiConfig.societyComplaintStatus(id), data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyComplaintModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid complaint status response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update complaint status');
    }
  }

  Future<SocietyComplaintModel> assignComplaint(
    int id,
    int societyId, {
    required int assignedTo,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'assigned_to': assignedTo,
      };
      final res = await _dio.put(ApiConfig.assignSocietyComplaint(id), data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyComplaintModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid assign complaint response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to assign complaint');
    }
  }

  // ─── 5. Society Facility APIs ─────────────────────────────────────────────
  Future<List<SocietyFacilityModel>> getFacilities(int societyId, {bool? isActive}) async {
    try {
      final opts = await _authOptions();
      final query = <String, dynamic>{
        'society_id': societyId,
        if (isActive != null) 'is_active': isActive,
      };
      final res = await _dio.get(ApiConfig.societyFacilities, queryParameters: query, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is List) {
        return data.whereType<Map>().map((e) => SocietyFacilityModel.fromJson(_toMap(e))).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load facilities');
    }
  }

  Future<SocietyFacilityModel> createFacility(
    int societyId, {
    required String name,
    String? description,
    String? operatingHours,
    String? bookingRules,
    int? maxCapacity,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (operatingHours != null) 'operating_hours': operatingHours.trim(),
        if (bookingRules != null) 'booking_rules': bookingRules.trim(),
        if (maxCapacity != null) 'max_capacity': maxCapacity,
      };
      final res = await _dio.post(ApiConfig.societyFacilities, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyFacilityModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid create facility response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to create facility');
    }
  }

  // ─── 6. Society Parking APIs ──────────────────────────────────────────────
  Future<SocietyPaginatedResponse<SocietyParkingModel>> getParkings(
    int societyId, {
    String? vehicleType,
    bool? isVisitorParking,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final opts = await _authOptions();
      final query = <String, dynamic>{
        'society_id': societyId,
        'page': page,
        'limit': limit,
        if (vehicleType != null && vehicleType.isNotEmpty) 'vehicle_type': vehicleType,
        if (isVisitorParking != null) 'is_visitor_parking': isVisitorParking,
        if (status != null && status.isNotEmpty) 'status': status,
      };
      final res = await _dio.get(ApiConfig.societyParkings, queryParameters: query, options: opts);
      final body = _toMap(res.data);
      return SocietyPaginatedResponse<SocietyParkingModel>.fromJson(
        body,
        (item) => SocietyParkingModel.fromJson(_toMap(item)),
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load parking slots');
    }
  }

  Future<SocietyParkingModel> allocateParking(
    int societyId, {
    required String parkingSlotNo,
    required String vehicleType,
    required String vehicleNo,
    String? vehicleModel,
    bool isVisitorParking = false,
    int? userId,
    String status = 'active',
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'parking_slot_no': parkingSlotNo.trim(),
        'vehicle_type': vehicleType,
        'vehicle_no': vehicleNo.trim(),
        if (vehicleModel != null) 'vehicle_model': vehicleModel.trim(),
        'is_visitor_parking': isVisitorParking,
        if (userId != null) 'user_id': userId,
        'status': status,
      };
      final res = await _dio.post(ApiConfig.societyParkings, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyParkingModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid allocate parking response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to allocate parking slot');
    }
  }

  // ─── 7. Society Poll APIs ─────────────────────────────────────────────────
  Future<SocietyPaginatedResponse<SocietyPollModel>> getPolls(
    int societyId, {
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final opts = await _authOptions();
      final query = <String, dynamic>{
        'society_id': societyId,
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
      };
      final res = await _dio.get(ApiConfig.societyPolls, queryParameters: query, options: opts);
      final body = _toMap(res.data);
      return SocietyPaginatedResponse<SocietyPollModel>.fromJson(
        body,
        (item) => SocietyPollModel.fromJson(_toMap(item)),
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load society polls');
    }
  }

  Future<SocietyPollModel> getPoll(int id, int societyId) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(
        ApiConfig.societyPoll(id),
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyPollModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid poll response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch poll detail');
    }
  }

  Future<SocietyPollModel> createPoll(
    int societyId, {
    required String question,
    required List<String> options,
    DateTime? expiresAt,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'question': question.trim(),
        'options': options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      };
      final res = await _dio.post(ApiConfig.societyPolls, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyPollModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid create poll response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to create poll');
    }
  }

  Future<SocietyPollModel> votePoll(int id, int societyId, {required int optionIndex}) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'option_index': optionIndex,
      };
      final res = await _dio.post(ApiConfig.voteSocietyPoll(id), data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyPollModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid vote response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to cast vote');
    }
  }

  Future<SocietyPollModel> updatePollStatus(int id, int societyId, {required String status}) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'status': status,
      };
      final res = await _dio.put(ApiConfig.societyPollStatus(id), data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyPollModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid poll status response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update poll status');
    }
  }

  // ─── 8. Society Visitor APIs ──────────────────────────────────────────────
  Future<SocietyPaginatedResponse<SocietyVisitorModel>> getVisitors(
    int societyId, {
    String? status,
    String? flatNo,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final opts = await _authOptions();
      final query = <String, dynamic>{
        'society_id': societyId,
        'page': page,
        'limit': limit,
        if (status != null && status.isNotEmpty) 'status': status,
        if (flatNo != null && flatNo.isNotEmpty) 'flat_no': flatNo,
      };
      final res = await _dio.get(ApiConfig.societyVisitors, queryParameters: query, options: opts);
      final body = _toMap(res.data);
      return SocietyPaginatedResponse<SocietyVisitorModel>.fromJson(
        body,
        (item) => SocietyVisitorModel.fromJson(_toMap(item)),
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load visitor passes');
    }
  }

  Future<SocietyVisitorModel> createVisitor(
    int societyId, {
    required String visitorName,
    String? visitorPhone,
    String? purpose,
    String? vehicleNo,
    String? flatNo,
    DateTime? expectedTime,
    int? userId,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'visitor_name': visitorName.trim(),
        if (visitorPhone != null) 'visitor_phone': visitorPhone.trim(),
        if (purpose != null) 'purpose': purpose.trim(),
        if (vehicleNo != null) 'vehicle_no': vehicleNo.trim(),
        if (flatNo != null) 'flat_no': flatNo.trim(),
        if (expectedTime != null) 'expected_time': expectedTime.toIso8601String(),
        if (userId != null) 'user_id': userId,
      };
      final res = await _dio.post(ApiConfig.societyVisitors, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyVisitorModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid create visitor response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to register visitor');
    }
  }

  Future<SocietyVisitorModel> updateVisitorStatus(
    int id,
    int societyId, {
    required String status,
    String? remark,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'status': status,
        if (remark != null) 'remark': remark,
      };
      final res = await _dio.put(ApiConfig.societyVisitorStatus(id), data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyVisitorModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid visitor status response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update visitor status');
    }
  }

  // ─── 9. Society Documents APIs (PRD 18.4) ─────────────────────────────────
  Future<SocietyPaginatedResponse<SocietyDocumentModel>> getDocuments(
    int societyId, {
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final opts = await _authOptions();
      final query = <String, dynamic>{
        'society_id': societyId,
        'page': page,
        'limit': limit,
        if (category != null && category.isNotEmpty) 'category': category,
      };
      final res = await _dio.get(
        ApiConfig.societyDocuments,
        queryParameters: query,
        options: opts,
      );
      final body = _toMap(res.data);
      return SocietyPaginatedResponse<SocietyDocumentModel>.fromJson(
        body,
        (item) => SocietyDocumentModel.fromJson(_toMap(item)),
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load society documents');
    }
  }

  Future<SocietyDocumentModel> createDocument(
    int societyId, {
    required String title,
    String? description,
    required String category,
    required String filePath,
    String? fileName,
  }) async {
    try {
      final opts = await _authOptions();
      final formData = FormData.fromMap({
        'society_id': societyId,
        'title': title.trim(),
        if (description != null) 'description': description.trim(),
        'category': category,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final res = await _dio.post(
        ApiConfig.societyDocuments,
        data: formData,
        options: opts,
      );
      final body = _toMap(res.data);
      final data = body['data'];
      if (data is Map) {
        return SocietyDocumentModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid document upload response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to upload society document');
    }
  }

  Future<void> deleteDocument(int id) async {
    try {
      final opts = await _authOptions();
      await _dio.delete(ApiConfig.societyDocument(id), options: opts);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete society document');
    }
  }

  // ─── 13. Society Emergency Contacts & Alerts (PRD 21.5 / 22.5) ─────────────
  Future<List<SocietyEmergencyContactModel>> getEmergencyContacts(
    int societyId, {
    String? category,
  }) async {
    try {
      final opts = await _authOptions();
      final query = <String, dynamic>{
        'society_id': societyId,
        if (category != null && category.isNotEmpty) 'category': category,
      };
      final res = await _dio.get(
        ApiConfig.societyEmergencyContacts,
        queryParameters: query,
        options: opts,
      );
      final body = _toMap(res.data);
      final rawList = body['data'] as List? ?? [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => SocietyEmergencyContactModel.fromJson(m))
          .toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load emergency contacts');
    }
  }

  Future<SocietyEmergencyContactModel> createEmergencyContact(
    int societyId, {
    required String name,
    String? designation,
    required String phone,
    String? altPhone,
    String category = 'other',
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'name': name.trim(),
        if (designation != null) 'designation': designation.trim(),
        'phone': phone.trim(),
        if (altPhone != null) 'alt_phone': altPhone.trim(),
        'category': category,
      };
      final res = await _dio.post(
        ApiConfig.societyEmergencyContacts,
        data: body,
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyEmergencyContactModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid emergency contact response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to add emergency contact');
    }
  }

  Future<void> deleteEmergencyContact(int id) async {
    try {
      final opts = await _authOptions();
      await _dio.delete(ApiConfig.societyEmergencyContact(id), options: opts);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete emergency contact');
    }
  }

  Future<void> broadcastEmergencyAlert(
    int societyId, {
    required String title,
    required String message,
    String severity = 'high',
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'title': title.trim(),
        'message': message.trim(),
        'severity': severity,
      };
      await _dio.post(
        ApiConfig.societyEmergencyAlert(societyId),
        data: body,
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to broadcast emergency alert');
    }
  }
}
