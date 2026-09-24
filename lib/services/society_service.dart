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
      final safeLimit = limit < 1 ? 20 : (limit > 100 ? 100 : limit);
      final query = <String, dynamic>{
        'society_id': societyId,
        'page': page,
        'limit': safeLimit,
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

  Future<List<SocietyMemberModel>> getSocietyMembers(int societyId, {int limit = 100}) async {
    final res = await getMembers(societyId, limit: limit);
    return res.data;
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

  Future<SocietyMemberModel> updateMemberRole(int id, int societyId, {required String role, String? remark}) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'role': role,
        if (remark != null) 'remark': remark,
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
    String? status,
    String? audience,
    String? search,
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
        if (status != null && status.isNotEmpty) 'status': status,
        if (audience != null && audience.isNotEmpty) 'audience': audience,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
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
    String? summary,
    required String message,
    String? actionText,
    String audience = 'entire_society',
    String priority = 'medium',
    String category = 'general',
    bool isPinned = false,
    String status = 'published',
    DateTime? publishAt,
    DateTime? expiresAt,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'title': title.trim(),
        if (summary != null && summary.trim().isNotEmpty) 'summary': summary.trim(),
        'message': message.trim(),
        if (actionText != null && actionText.trim().isNotEmpty) 'action_text': actionText.trim(),
        'audience': audience,
        'priority': priority,
        'category': category,
        'is_pinned': isPinned,
        'status': status,
        if (publishAt != null) 'publish_at': publishAt.toIso8601String(),
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
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

  Future<SocietyAnnouncementModel> archiveAnnouncement(int id, int societyId) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.put(
        ApiConfig.societyAnnouncementArchive(id),
        data: {'society_id': societyId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyAnnouncementModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid archive announcement response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to archive announcement');
    }
  }

  Future<AnnouncementAttachmentModel> uploadAnnouncementAttachment(
    int societyId, {
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final MultipartFile filePart;
      if (fileBytes != null && fileBytes.isNotEmpty) {
        filePart = MultipartFile.fromBytes(
          fileBytes,
          filename: fileName ?? 'attachment_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      } else if (filePath != null && filePath.isNotEmpty) {
        filePart = await MultipartFile.fromFile(filePath, filename: fileName);
      } else {
        throw const SocietyServiceException('No file content or path provided for upload');
      }

      final formData = FormData.fromMap({
        'society_id': societyId.toString(),
        'file': filePart,
      });

      final res = await _dio.post(
        ApiConfig.societyAnnouncementUpload,
        queryParameters: {'society_id': societyId},
        data: formData,
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return AnnouncementAttachmentModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid upload announcement attachment response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to upload notice attachment');
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

  Future<int> bulkDeleteAnnouncements(
    List<int> ids,
    int societyId, {
    String? deletedRemarks,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.post(
        ApiConfig.societyAnnouncementBulkDelete,
        data: {
          'ids': ids,
          'society_id': societyId,
          if (deletedRemarks != null) 'deletedRemarks': deletedRemarks,
        },
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = _toMap(resBody['data']);
      return (data['count'] as num?)?.toInt() ?? ids.length;
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to bulk delete announcements');
    }
  }

  // ─── 4. Society Complaint APIs ────────────────────────────────────────────
  Future<SocietyPaginatedResponse<SocietyComplaintModel>> getComplaints(
    int societyId, {
    String? status,
    String? priority,
    String? category,
    String? locationType,
    String? assigned,
    String? search,
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
        if (status != null && status.isNotEmpty && status != 'all') 'status': status,
        if (priority != null && priority.isNotEmpty && priority != 'all') 'priority': priority,
        if (category != null && category.isNotEmpty && category != 'all') 'category': category,
        if (locationType != null && locationType.isNotEmpty && locationType != 'all') 'location_type': locationType,
        if (assigned != null && assigned.isNotEmpty && assigned != 'all') 'assigned': assigned,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
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

  Future<SocietyComplaintSummaryModel> getComplaintSummary(int societyId) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(
        '${ApiConfig.societyComplaints}/summary',
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyComplaintSummaryModel.fromJson(_toMap(data));
      }
      return const SocietyComplaintSummaryModel();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch complaint summary');
    }
  }

  Future<List<SocietyComplaintHistoryItemModel>> getComplaintHistory(int id, int societyId) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(
        '${ApiConfig.societyComplaint(id)}/history',
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      // New format: { audit: [...], assignments: [...] }
      // Old format: data is directly a list
      List<dynamic> auditItems = [];
      if (data is Map) {
        final audit = data['audit'];
        if (audit is List) auditItems = audit;
      } else if (data is List) {
        auditItems = data;
      }
      return auditItems
          .map((item) => SocietyComplaintHistoryItemModel.fromJson(_toMap(item)))
          .toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch complaint history');
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
    String? subCategory,
    String? locationType,
    String? flatNo,
    String? exactLocation,
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
        if (subCategory != null && subCategory.trim().isNotEmpty)
          'sub_category': subCategory.trim(),
        if (locationType != null && locationType.trim().isNotEmpty)
          'location_type': locationType.trim(),
        if (flatNo != null && flatNo.trim().isNotEmpty)
          'flat_no': flatNo.trim(),
        if (exactLocation != null && exactLocation.trim().isNotEmpty)
          'exact_location': exactLocation.trim(),
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

  Future<SocietyComplaintModel> closeComplaint(
    int id,
    int societyId, {
    String? remark,
  }) {
    return updateComplaintStatus(
      id,
      societyId,
      status: 'closed',
      remark: remark ?? 'Closed by resident',
    );
  }

  Future<SocietyComplaintModel> reopenComplaint(
    int id,
    int societyId, {
    required String reason,
  }) {
    return updateComplaintStatus(
      id,
      societyId,
      status: 'open',
      remark: reason.trim(),
    );
  }

  Future<SocietyComplaintModel> assignComplaint(
    int id,
    int societyId, {
    required int assignedTo,
    String? reason,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'assigned_to': assignedTo,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
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

  /// Get complaints assigned to the current user (worker task list)
  Future<List<SocietyComplaintModel>> getMyWorkerTasks(int societyId) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(
        ApiConfig.societyComplaints,
        queryParameters: {'society_id': societyId, 'limit': 50},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      final items = data is List ? data : (data is Map ? (data['data'] as List? ?? []) : []);
      return items
          .whereType<Map>()
          .map((e) => SocietyComplaintModel.fromJson(_toMap(e)))
          .toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch worker tasks');
    }
  }

  /// Worker: Accept assigned task
  Future<SocietyComplaintModel> acceptWorkerTask(int id, int societyId) {
    return updateComplaintStatus(
      id, societyId,
      status: 'accepted',
      remark: 'Task accepted by assigned worker',
    );
  }

  /// Worker: Start work on accepted task
  Future<SocietyComplaintModel> startWorkerTask(int id, int societyId) {
    return updateComplaintStatus(
      id, societyId,
      status: 'in_progress',
      remark: 'Work started by assigned worker',
    );
  }

  /// Fetch eligible workers for complaint assignment (categorized into recommended & others)
  Future<Map<String, List<EligibleWorkerModel>>> getEligibleWorkers(int societyId, {String? category}) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(
        ApiConfig.societyWorkerEligible(societyId, category: category),
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'] is Map ? resBody['data'] as Map : {};
      final recList = data['recommended'] is List ? (data['recommended'] as List) : [];
      final othList = data['others'] is List ? (data['others'] as List) : [];
      final mktList = data['marketplace'] is List ? (data['marketplace'] as List) : [];

      final recommended = recList
          .whereType<Map>()
          .map((e) => EligibleWorkerModel.fromJson(_toMap(e), isRecommended: true))
          .toList();

      final others = othList
          .whereType<Map>()
          .map((e) => EligibleWorkerModel.fromJson(_toMap(e), isRecommended: false))
          .toList();

      final marketplace = mktList
          .whereType<Map>()
          .map((e) => EligibleWorkerModel.fromJson(_toMap(e), isMarketplaceProvider: true))
          .toList();

      return {
        'recommended': recommended,
        'others': others,
        'marketplace': marketplace,
      };
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch eligible workers');
    }
  }

  /// Authorize a new worker for this society (by phone number, designation & skills)
  Future<Map<String, dynamic>> authorizeWorker(
    int societyId, {
    required String phone,
    required String designation,
    List<int>? skillCategoryIds,
    String? notes,
  }) async {
    try {
      final opts = await _authOptions();
      final body = {
        'society_id': societyId,
        'phone': phone,
        'designation': designation,
        'authorization_status': 'active',
        if (skillCategoryIds != null && skillCategoryIds.isNotEmpty)
          'skill_category_ids': skillCategoryIds,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };
      final res = await _dio.post(ApiConfig.societyWorkers, data: body, options: opts);
      final resBody = _toMap(res.data);
      if (resBody['success'] == true) {
        return _toMap(resBody['data']);
      }
      throw SocietyServiceException(resBody['message']?.toString() ?? 'Failed to authorize worker');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to authorize worker');
    }
  }

  /// Get all authorized workers for a society
  Future<List<EligibleWorkerModel>> getAuthorizedWorkers(int societyId) async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(
        ApiConfig.societyWorkers,
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'] is List ? (resBody['data'] as List) : [];
      return data
          .whereType<Map>()
          .map((e) => EligibleWorkerModel.fromJson(_toMap(e)))
          .toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to fetch authorized workers');
    }
  }

  // --- Complaint Master APIs ---
  Future<List<Map<String, dynamic>>> getComplaintCategories() async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(ApiConfig.complaintCategories, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is List) {
        return data.whereType<Map>().map((e) => _toMap(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getComplaintSubCategories({int? categoryId}) async {
    try {
      final opts = await _authOptions();
      final query = categoryId != null ? {'category_id': categoryId} : null;
      final res = await _dio.get(
        ApiConfig.complaintSubCategories,
        queryParameters: query,
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is List) {
        return data.whereType<Map>().map((e) => _toMap(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getComplaintLocationTypes() async {
    try {
      final opts = await _authOptions();
      final res = await _dio.get(ApiConfig.complaintLocationTypes, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is List) {
        return data.whereType<Map>().map((e) => _toMap(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // --- 5. Society Facility APIs
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

  Future<SocietyMemberModel> onboardGuard(
    int societyId, {
    required String phone,
    String? name,
    String? gateNo,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'phone': phone.trim(),
        'role': 'staff',
        if (gateNo != null && gateNo.trim().isNotEmpty) 'flat_no': gateNo.trim(),
        if (name != null && name.trim().isNotEmpty) 'trade': name.trim(),
      };
      final res = await _dio.post(ApiConfig.societyMembers, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyMemberModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid guard onboard response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to onboard guard');
    }
  }

  Future<SocietyVisitorModel> createVisitor(
    int societyId, {
    required String visitorName,
    String? visitorPhone,
    String? purpose,
    String? vehicleNo,
    String? flatNo,
    String? status,
    DateTime? expectedTime,
    int? userId,
    String? visitorType,
    String? companyName,
    String? vehicleType,
    String? entryType,
    int? gateId,
    int? guardId,
    String? idType,
    String? idNumber,
    String? driverName,
    String? cabNumber,
    String? serviceCategory,
    String? workerType,
    String? vehicleNumber,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'visitor_name': visitorName.trim(),
        if (visitorPhone != null && visitorPhone.trim().isNotEmpty) 'visitor_phone': visitorPhone.trim(),
        if (purpose != null && purpose.trim().isNotEmpty) 'purpose': purpose.trim(),
        if (vehicleNo != null && vehicleNo.trim().isNotEmpty) 'vehicle_no': vehicleNo.trim(),
        if (flatNo != null && flatNo.trim().isNotEmpty) 'flat_no': flatNo.trim(),
        if (status != null) 'status': status,
        if (expectedTime != null) 'expected_time': expectedTime.toIso8601String(),
        if (userId != null) 'user_id': userId,
        if (visitorType != null) 'visitor_type': visitorType,
        if (companyName != null && companyName.trim().isNotEmpty) 'company_name': companyName.trim(),
        if (vehicleType != null) 'vehicle_type': vehicleType,
        if (entryType != null) 'entry_type': entryType,
        if (gateId != null) 'gate_id': gateId,
        if (guardId != null) 'guard_id': guardId,
        if (idType != null) 'id_type': idType,
        if (idNumber != null && idNumber.trim().isNotEmpty) 'id_number': idNumber.trim(),
        if (driverName != null && driverName.trim().isNotEmpty) 'driver_name': driverName.trim(),
        if (cabNumber != null && cabNumber.trim().isNotEmpty) 'cab_number': cabNumber.trim(),
        if (serviceCategory != null && serviceCategory.trim().isNotEmpty) 'service_category': serviceCategory.trim(),
        if (workerType != null && workerType.trim().isNotEmpty) 'worker_type': workerType.trim(),
        if (vehicleNumber != null && vehicleNumber.trim().isNotEmpty) 'vehicle_number': vehicleNumber.trim(),
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
    String? reason,
  }) async {
    try {
      final opts = await _authOptions();
      final body = <String, dynamic>{
        'society_id': societyId,
        'status': status,
        if (remark != null) 'remark': remark,
        if (reason != null) 'reason': reason,
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

  Future<void> deleteVisitor(int id, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;
      await _dio.delete(
        ApiConfig.societyVisitor(id),
        queryParameters: {'society_id': societyId},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete visitor pass');
    }
  }

  // ─── Enterprise Security: Committees, Gates, Shifts, Guards ─────────────────



  Future<SocietyCommitteeModel> createCommittee(
    int societyId, {
    required String name,
    String? description,
    String committeeType = 'custom',
    String? scopeType,
    int? scopeId,
    List<int>? scopeGateIds,
    List<String>? selectedModules,
    List<String>? permissions,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        'name': name.trim(),
        if (description != null) 'description': description.trim(),
        'committee_type': committeeType,
        if (scopeType != null) 'scope_type': scopeType,
        if (scopeId != null) 'scope_id': scopeId,
        if (scopeGateIds != null) 'scope_gate_ids': scopeGateIds,
        if (selectedModules != null) 'modules': selectedModules,
        if (permissions != null) 'permissions': permissions,
      };
      final res = await _dio.post(ApiConfig.societyCommittees, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyCommitteeModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid create committee response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to create committee');
    }
  }

  Future<SocietyCommitteeModel> updateCommittee(
    int committeeId,
    int societyId, {
    String? name,
    String? description,
    String? committeeType,
    String? scopeType,
    int? scopeId,
    List<int>? scopeGateIds,
    List<String>? selectedModules,
    List<String>? permissions,
    String? status,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (committeeType != null) 'committee_type': committeeType,
        if (scopeType != null) 'scope_type': scopeType,
        if (scopeId != null) 'scope_id': scopeId,
        if (scopeGateIds != null) 'scope_gate_ids': scopeGateIds,
        if (selectedModules != null) 'modules': selectedModules,
        if (permissions != null) 'permissions': permissions,
        if (status != null) 'status': status,
      };
      final res = await _dio.put(ApiConfig.societyCommittee(committeeId), data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyCommitteeModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid update committee response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update committee');
    }
  }

  Future<void> deleteCommittee(int committeeId, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.delete(ApiConfig.societyCommittee(committeeId), options: opts);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete committee');
    }
  }

  Future<List<SocietyCommitteeModel>> getCommittees(
    int societyId, {
    String? status,
    String? committeeType,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societyCommittees,
        queryParameters: {
          'society_id': societyId,
          if (status != null) 'status': status,
          if (committeeType != null) 'committee_type': committeeType,
        },
        options: opts,
      );
      final resBody = _toMap(res.data);
      final rawList = resBody['data'] as List? ?? [];
      return rawList
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => SocietyCommitteeModel.fromJson(_toMap(item)))
          .toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load committees');
    }
  }

  Future<Map<String, dynamic>> getCommitteePermissionCatalog(int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(ApiConfig.societyCommitteeCatalog, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return _toMap(data);
      }
      return <String, dynamic>{};
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load committee permission catalog');
    }
  }

  Future<void> addCommitteeMember(
    int committeeId,
    int societyId, {
    int? userId,
    String? phone,
    String? email,
    String designation = 'Member',
    List<String>? permissions,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        if (userId != null) 'user_id': userId,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'designation': designation,
        if (permissions != null) 'permissions': permissions,
      };
      await _dio.post(ApiConfig.societyCommitteeMembers(committeeId), data: body, options: opts);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to add committee member');
    }
  }

  Future<void> removeCommitteeMember(int committeeId, int userId, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.delete(
        ApiConfig.societyCommitteeMember(committeeId, userId),
        queryParameters: {'society_id': societyId},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to remove committee member');
    }
  }

  Future<void> assignCommitteePermissions(
    int committeeId,
    int societyId,
    List<String> permissions, {
    int? memberId,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        'permissions': permissions,
        if (memberId != null) 'memberId': memberId,
      };
      await _dio.post(ApiConfig.societyCommitteePermissions(committeeId), data: body, options: opts);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to assign committee permissions');
    }
  }

  Future<List<Map<String, dynamic>>> searchUsersForCommittee(int societyId, String query) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.searchCommitteeUsers,
        queryParameters: {'society_id': societyId, 'q': query},
        options: opts,
      );
      final body = _toMap(res.data);
      final rawList = body['data'] as List? ?? [];
      return rawList.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to search users');
    }
  }

  // ── Committee Invitations & Lifecycle ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyCommitteeInvitations(int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societyCommitteeInvitations,
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final body = _toMap(res.data);
      final rawList = body['data'] as List? ?? [];
      return rawList.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load committee invitations');
    }
  }

  Future<List<Map<String, dynamic>>> getMyCommitteeMemberships(int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societyMyCommitteeMemberships,
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final body = _toMap(res.data);
      final rawList = body['data'] as List? ?? [];
      return rawList.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load committee memberships');
    }
  }

  Future<Map<String, dynamic>> getCommitteeInvitation(int invitationId, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societyCommitteeInvitation(invitationId),
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final body = _toMap(res.data);
      final data = body['data'];
      if (data is Map) return _toMap(data);
      throw const SocietyServiceException('Invalid invitation response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load invitation details');
    }
  }

  Future<void> acceptCommitteeInvitation(int invitationId, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.post(
        ApiConfig.acceptCommitteeInvitation(invitationId),
        data: {'society_id': societyId},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to accept committee invitation');
    }
  }

  Future<void> rejectCommitteeInvitation(int invitationId, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.post(
        ApiConfig.rejectCommitteeInvitation(invitationId),
        data: {'society_id': societyId},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to decline committee invitation');
    }
  }

  Future<void> resendCommitteeInvitation(int invitationId, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.post(
        ApiConfig.resendCommitteeInvitation(invitationId),
        data: {'society_id': societyId},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to resend committee invitation');
    }
  }

  Future<void> cancelCommitteeInvitation(int invitationId, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.post(
        ApiConfig.cancelCommitteeInvitation(invitationId),
        data: {'society_id': societyId},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to cancel committee invitation');
    }
  }

  Future<void> suspendCommitteeMember(int societyId, int committeeId, int memberId, {String? reason}) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.put(
        ApiConfig.suspendCommitteeMember(committeeId, memberId),
        data: {
          'society_id': societyId,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to suspend committee member');
    }
  }

  Future<void> revokeCommitteeMember(int societyId, int committeeId, int memberId, {String? reason}) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.put(
        ApiConfig.revokeCommitteeMember(committeeId, memberId),
        data: {
          'society_id': societyId,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        },
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to revoke committee member');
    }
  }

  Future<void> activateCommitteeMember(int societyId, int committeeId, int memberId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.put(
        ApiConfig.activateCommitteeMember(committeeId, memberId),
        data: {'society_id': societyId},
        options: opts,
      );
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to activate committee member');
    }
  }

  // Gates
  Future<List<SocietyGateModel>> getGates(int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societyGates,
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final body = _toMap(res.data);
      final rawList = body['data'] as List? ?? [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => SocietyGateModel.fromJson(m))
          .toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load gates');
    }
  }

  Future<SocietyGateModel> createGate(
    int societyId, {
    required String gateName,
    String? gateCode,
    String gateType = 'main',
    String operatingHours = '24/7',
    String? location,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        'gate_name': gateName.trim(),
        if (gateCode != null) 'gate_code': gateCode.trim(),
        'gate_type': gateType,
        'operating_hours': operatingHours,
        if (location != null) 'location': location.trim(),
      };
      final res = await _dio.post(ApiConfig.societyGates, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyGateModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid create gate response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to create gate');
    }
  }

  Future<SocietyGateModel> updateGate(
    int societyId,
    int gateId, {
    String? gateName,
    String? gateCode,
    String? gateType,
    String? operatingHours,
    String? location,
    String? description,
    String? status,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        if (gateName != null) 'gate_name': gateName.trim(),
        if (gateCode != null) 'gate_code': gateCode.trim(),
        if (gateType != null) 'gate_type': gateType,
        if (operatingHours != null) 'operating_hours': operatingHours,
        if (location != null) 'location': location.trim(),
        if (description != null) 'description': description.trim(),
        if (status != null) 'status': status,
      };
      final res = await _dio.put('${ApiConfig.societyGates}/$gateId', data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyGateModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid update gate response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update gate');
    }
  }

  Future<void> deleteGate(int societyId, int gateId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.delete('${ApiConfig.societyGates}/$gateId', queryParameters: {'society_id': societyId}, options: opts);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete gate');
    }
  }

  // Shifts
  Future<List<SocietyShiftModel>> getShifts(int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societyShifts,
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final body = _toMap(res.data);
      final rawList = body['data'] as List? ?? [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => SocietyShiftModel.fromJson(m))
          .toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load shifts');
    }
  }

  Future<SocietyShiftModel> createShift(
    int societyId, {
    required String shiftName,
    String startTime = '07:00',
    String endTime = '19:00',
    String? weeklyOff,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        'shift_name': shiftName.trim(),
        'start_time': startTime,
        'end_time': endTime,
        if (weeklyOff != null) 'weekly_off': weeklyOff,
      };
      final res = await _dio.post(ApiConfig.societyShifts, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyShiftModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid create shift response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to create shift');
    }
  }

  // Guards
  Future<List<SocietyGuardAuthorizationModel>> getGuards(int societyId, {String? status}) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societyGuards,
        queryParameters: {
          'society_id': societyId,
          if (status != null) 'status': status,
        },
        options: opts,
      );
      final body = _toMap(res.data);
      final rawList = body['data'] as List? ?? [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => SocietyGuardAuthorizationModel.fromJson(m))
          .toList();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load guards');
    }
  }

  Future<SocietyGuardAuthorizationModel> onboardGuardEnterprise(
    int societyId, {
    required String phone,
    String? name,
    String designation = 'Security Guard',
    String guardType = 'society_guard',
    int? gateId,
    int? shiftId,
    String? idType,
    String? idNumber,
    String? idDocumentUrl,
    String? profilePhotoUrl,
    String? badgeNumber,
    String? alternatePhone,
    String? gender,
    String? dob,
    String? agencyName,
    String? notes,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        'phone': phone.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'designation': designation,
        'guard_type': guardType,
        if (gateId != null) 'gate_id': gateId,
        if (shiftId != null) 'shift_id': shiftId,
        if (idType != null) 'id_type': idType,
        if (idNumber != null && idNumber.trim().isNotEmpty) 'id_number': idNumber.trim(),
        if (idDocumentUrl != null && idDocumentUrl.trim().isNotEmpty) 'id_document_url': idDocumentUrl.trim(),
        if (profilePhotoUrl != null && profilePhotoUrl.trim().isNotEmpty) 'profile_photo_url': profilePhotoUrl.trim(),
        if (badgeNumber != null && badgeNumber.trim().isNotEmpty) 'badge_number': badgeNumber.trim(),
        if (alternatePhone != null && alternatePhone.trim().isNotEmpty) 'alternate_phone': alternatePhone.trim(),
        if (gender != null && gender.trim().isNotEmpty) 'gender': gender.trim(),
        if (dob != null && dob.trim().isNotEmpty) 'dob': dob.trim(),
        if (agencyName != null && agencyName.trim().isNotEmpty) 'agency_name': agencyName.trim(),
        if (notes != null) 'notes': notes.trim(),
      };
      final res = await _dio.post(ApiConfig.societyGuards, data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyGuardAuthorizationModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid guard onboard response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to onboard guard');
    }
  }

  Future<SocietyGuardAuthorizationModel> uploadGuardPhoto(
    int guardId,
    int societyId, {
    String? photoUrl,
    String? filePath,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      dynamic bodyData;
      if (filePath != null && filePath.isNotEmpty) {
        bodyData = FormData.fromMap({
          'photo': await MultipartFile.fromFile(filePath),
          'society_id': societyId,
        });
      } else {
        bodyData = {
          'society_id': societyId,
          'photo_url': photoUrl,
        };
      }

      final res = await _dio.post(ApiConfig.societyGuardPhoto(guardId), data: bodyData, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyGuardAuthorizationModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid upload photo response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to upload guard photo');
    }
  }

  Future<SocietyGuardAuthorizationModel> uploadGuardIdDocument(
    int guardId,
    int societyId, {
    String? documentUrl,
    String? filePath,
    String? idType,
    String? idNumber,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      dynamic bodyData;
      if (filePath != null && filePath.isNotEmpty) {
        bodyData = FormData.fromMap({
          'id_document': await MultipartFile.fromFile(filePath),
          'society_id': societyId,
          if (idType != null) 'id_type': idType,
          if (idNumber != null) 'id_number': idNumber,
        });
      } else {
        bodyData = {
          'society_id': societyId,
          if (documentUrl != null) 'document_url': documentUrl,
          if (idType != null) 'id_type': idType,
          if (idNumber != null) 'id_number': idNumber,
        };
      }

      final res = await _dio.post(ApiConfig.societyGuardIdDocument(guardId), data: bodyData, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyGuardAuthorizationModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid upload document response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to upload ID document');
    }
  }

  Future<String> uploadGuardPhotoBytes(
    int societyId,
    List<int> bytes,
    String filename, {
    int? guardId,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final formData = FormData.fromMap({
        'photo': MultipartFile.fromBytes(bytes, filename: filename),
        'society_id': societyId,
      });

      final url = guardId != null
          ? '${ApiConfig.societyGuardPhoto(guardId)}?society_id=$societyId'
          : '${ApiConfig.societyGuardUploadPhoto}?society_id=$societyId';

      final res = await _dio.post(url, data: formData, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return (data['photo_url'] ?? data['profile_photo_url'] ?? '').toString();
      }
      return '';
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to upload guard photo');
    }
  }

  Future<String> uploadGuardIdDocumentBytes(
    int societyId,
    List<int> bytes,
    String filename, {
    int? guardId,
    String? idType,
    String? idNumber,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final formData = FormData.fromMap({
        'id_document': MultipartFile.fromBytes(bytes, filename: filename),
        'society_id': societyId,
        if (idType != null) 'id_type': idType,
        if (idNumber != null) 'id_number': idNumber,
      });

      final url = guardId != null
          ? '${ApiConfig.societyGuardIdDocument(guardId)}?society_id=$societyId'
          : '${ApiConfig.societyGuardUploadIdDocument}?society_id=$societyId';

      final res = await _dio.post(url, data: formData, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return (data['document_url'] ?? data['id_document_url'] ?? '').toString();
      }
      return '';
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to upload ID document');
    }
  }

  Future<SocietyGuardAuthorizationModel> verifyGuard(int guardId, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.put(
        ApiConfig.societyGuardVerify(guardId),
        data: {'society_id': societyId},
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyGuardAuthorizationModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid verify guard response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to verify guard');
    }
  }

  Future<SocietyGuardAuthorizationModel> rejectGuardVerification(
    int guardId,
    int societyId, {
    String? reason,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.put(
        ApiConfig.societyGuardReject(guardId),
        data: {
          'society_id': societyId,
          if (reason != null) 'reason': reason,
        },
        options: opts,
      );
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyGuardAuthorizationModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid reject guard response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to reject guard verification');
    }
  }

  Future<void> updateGuardStatus(int id, int societyId, {required String status, String? notes}) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        'status': status,
        if (notes != null) 'notes': notes,
      };
      await _dio.put(ApiConfig.societyGuardStatus(id), data: body, options: opts);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update guard status');
    }
  }

  Future<SocietyGuardAuthorizationModel> updateGuard(
    int guardId,
    int societyId, {
    String? name,
    String? designation,
    String? guardType,
    String? employeeId,
    String? badgeNumber,
    String? agencyName,
    String? idType,
    String? idNumber,
    String? gender,
    String? dob,
    String? alternatePhone,
    String? status,
    String? notes,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        if (name != null) 'name': name,
        if (designation != null) 'designation': designation,
        if (guardType != null) 'guard_type': guardType,
        if (employeeId != null) 'employee_id': employeeId,
        if (badgeNumber != null) 'badge_number': badgeNumber,
        if (agencyName != null) 'agency_name': agencyName,
        if (idType != null) 'id_type': idType,
        if (idNumber != null) 'id_number': idNumber,
        if (gender != null) 'gender': gender,
        if (dob != null) 'dob': dob,
        if (alternatePhone != null) 'alternate_phone': alternatePhone,
        if (status != null) 'status': status,
        if (notes != null) 'notes': notes,
      };

      final res = await _dio.put(ApiConfig.societyGuard(guardId), data: body, options: opts);
      final resBody = _toMap(res.data);
      final data = resBody['data'];
      if (data is Map) {
        return SocietyGuardAuthorizationModel.fromJson(_toMap(data));
      }
      throw const SocietyServiceException('Invalid update guard response');
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to update guard');
    }
  }

  Future<void> deleteGuard(int guardId, int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      await _dio.delete(ApiConfig.societyGuard(guardId), options: opts);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to delete guard');
    }
  }

  Future<void> assignGuardGateAndShift(
    int societyId, {
    required int guardAuthorizationId,
    required int gateId,
    required int shiftId,
    String? remarks,
  }) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final body = <String, dynamic>{
        'society_id': societyId,
        'guard_authorization_id': guardAuthorizationId,
        'gate_id': gateId,
        'shift_id': shiftId,
        if (remarks != null) 'remarks': remarks,
      };
      await _dio.post(ApiConfig.societyGuardAssign, data: body, options: opts);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to assign guard duty');
    }
  }

  Future<SocietyGuardDutyModel> getMyGuardDuty(int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societyGuardDuty,
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final body = _toMap(res.data);
      final data = body['data'];
      if (data is Map) {
        return SocietyGuardDutyModel.fromJson(_toMap(data));
      }
      return const SocietyGuardDutyModel();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to get guard duty');
    }
  }

  // Security Overview & Reports
  Future<SocietySecurityMetricsModel> getSecurityDashboard(int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societySecurityDashboard,
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final body = _toMap(res.data);
      final data = body['data'];
      if (data is Map) {
        final metrics = data['metrics'];
        if (metrics is Map) {
          return SocietySecurityMetricsModel.fromJson(_toMap(metrics));
        }
      }
      return const SocietySecurityMetricsModel();
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load security dashboard');
    }
  }

  Future<Map<String, dynamic>> getSecurityReports(int societyId) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societySecurityReports,
        queryParameters: {'society_id': societyId},
        options: opts,
      );
      final body = _toMap(res.data);
      return _toMap(body['data']);
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load security reports');
    }
  }

  Future<List<Map<String, dynamic>>> getSecurityAuditLogs(int societyId, {int page = 1, int limit = 30}) async {
    try {
      final opts = await _authOptions();
      final headers = Map<String, dynamic>.from(opts.headers ?? {});
      headers['x-society-id'] = societyId.toString();
      opts.headers = headers;

      final res = await _dio.get(
        ApiConfig.societySecurityAuditLogs,
        queryParameters: {'society_id': societyId, 'page': page, 'limit': limit},
        options: opts,
      );
      final body = _toMap(res.data);
      final data = body['data'];
      if (data is Map) {
        final rawList = data['data'] as List? ?? [];
        return rawList.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } on DioException catch (e) {
      throw _formatDioError(e, 'Failed to load security audit logs');
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
