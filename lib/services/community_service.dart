import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_config.dart';
import '../models/community_models.dart';
import 'authenticated_dio.dart';

typedef CommunityTokenProvider = Future<String?> Function();

class CommunityServiceException implements Exception {
  final String message;
  final int? statusCode;

  const CommunityServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal()
    : _dio = AuthenticatedDio().dio,
      _tokenProvider = _readStoredToken;
  CommunityService.forTesting(
    this._dio, {
    required this._tokenProvider,
  });

  final Dio _dio;
  final CommunityTokenProvider _tokenProvider;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static Future<String?> _readStoredToken() => _storage.read(key: 'jwt_token');

  Future<Options> _authOptions({bool optional = false}) async {
    final token = await _tokenProvider();
    if (token == null || token.trim().isEmpty) {
      if (optional) {
        return Options();
      }
      throw const CommunityServiceException('Authentication required.');
    }
    return Options(headers: {'Authorization': 'Bearer ${token.trim()}'});
  }

  /// Get communities joined by current user
  Future<List<CommunityModel>> getMyCommunities() async {
    try {
      final response = await _dio.get(
        ApiConfig.myCommunities,
        options: await _authOptions(),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityModel.fromJson(item)).toList();
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to fetch your communities');
    }
  }

  /// Get suggested/discoverable communities
  Future<List<CommunityModel>> getSuggestedCommunities({
    int? categoryId,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null && categoryId > 0) {
        queryParams['category_id'] = categoryId;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _dio.get(
        search != null && search.trim().isNotEmpty
            ? ApiConfig.communities
            : ApiConfig.suggestedCommunities,
        queryParameters: queryParams,
        options: await _authOptions(optional: true),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityModel.fromJson(item)).toList();
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to discover communities');
    }
  }

  /// Get detailed community by ID
  Future<CommunityModel> getCommunityDetails(int id) async {
    try {
      final response = await _dio.get(
        ApiConfig.community(id),
        options: await _authOptions(optional: true),
      );
      return CommunityModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load community details');
    }
  }

  /// Create a new Community
  Future<CommunityModel> createCommunity({
    required String name,
    required String description,
    int? categoryId,
    bool isPrivate = false,
    String? coverFilePath,
    String? iconFilePath,
    List<String>? rules,
  }) async {
    try {
      final map = <String, dynamic>{
        'communityName': name.trim(),
        'name': name.trim(),
        'communityDescription': description.trim(),
        'description': description.trim(),
        'is_private': isPrivate,
        if (categoryId != null) 'category_id': categoryId,
        if (rules != null && rules.isNotEmpty) 'rules': rules,
      };

      if (coverFilePath != null && coverFilePath.isNotEmpty && !kIsWeb) {
        map['cover_image'] = await MultipartFile.fromFile(
          coverFilePath,
          filename: 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      if (iconFilePath != null && iconFilePath.isNotEmpty && !kIsWeb) {
        map['icon'] = await MultipartFile.fromFile(
          iconFilePath,
          filename: 'icon_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      final formData = FormData.fromMap(map);
      final response = await _dio.post(
        ApiConfig.communities,
        data: formData,
        options: await _authOptions(),
      );
      return CommunityModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to create community');
    }
  }

  /// Join a community
  Future<CommunityJoinResult> joinCommunity(
    int communityId, {
    String? note,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.joinCommunity(communityId),
        data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
        options: await _authOptions(),
      );
      final data = _unwrapObject(response.data);
      return CommunityJoinResult(
        status: data['isPending'] == true
            ? CommunityJoinStatus.pending
            : CommunityJoinStatus.member,
      );
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to join community');
    }
  }

  /// Leave a community
  Future<bool> leaveCommunity(int communityId) async {
    try {
      final response = await _dio.post(
        ApiConfig.leaveCommunity(communityId),
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to leave community');
    }
  }

  /// Get members list
  Future<List<CommunityMemberModel>> getCommunityMembers(
    int communityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityMembers(communityId),
        options: await _authOptions(optional: true),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityMemberModel.fromJson(item)).toList();
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load community members');
    }
  }

  /// Get Community Scoped Feed Posts
  Future<CommunityFeedPage> getCommunityFeedPage(
    int communityId, {
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityFeed(communityId),
        queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
        options: await _authOptions(optional: true),
      );
      final data = _unwrapObject(response.data);
      final rawPosts = data['posts'] ?? data['timeline'];
      final posts = rawPosts is List
          ? rawPosts
                .whereType<Map>()
                .map(
                  (item) => CommunityPostModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : <CommunityPostModel>[];
      return CommunityFeedPage(
        posts: posts,
        nextCursor: data['nextCursor']?.toString(),
        hasMore: data['hasMore'] == true,
      );
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load community feed');
    }
  }

  Future<List<CommunityPostModel>> getCommunityFeed(
    int communityId, {
    String? cursor,
    int limit = 20,
  }) async => (await getCommunityFeedPage(
    communityId,
    cursor: cursor,
    limit: limit,
  )).posts;

  /// Create a post inside community
  Future<CommunityPostModel> createCommunityPost(
    int communityId, {
    required String content,
    List<int> mediaIds = const [],
    String type = 'text',
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.communityFeed(communityId),
        data: {'content': content, 'mediaIds': mediaIds, 'type': type},
        options: await _authOptions(),
      );
      return CommunityPostModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to publish post');
    }
  }

  /// Get Community Polls
  Future<List<CommunityPollModel>> getCommunityPolls(int communityId) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityPolls(communityId),
        options: await _authOptions(optional: true),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityPollModel.fromJson(item)).toList();
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load polls');
    }
  }

  /// Create a new Poll in Community
  Future<CommunityPollModel> createPoll(
    int communityId, {
    required String question,
    required List<String> options,
    int durationDays = 3,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.communityPolls(communityId),
        data: {
          'question': question,
          'options': options,
          'expiresAt': DateTime.now()
              .add(Duration(days: durationDays))
              .toIso8601String(),
        },
        options: await _authOptions(),
      );
      return CommunityPollModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to create poll');
    }
  }

  /// Vote on a poll option (Atomic Row-Locking backend)
  Future<bool> votePoll(int communityId, int pollId, int optionId) async {
    try {
      final response = await _dio.post(
        ApiConfig.voteCommunityPoll(communityId, pollId),
        data: {'optionId': optionId},
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to register vote');
    }
  }

  /// Delete a community poll (by Creator / Admin)
  Future<bool> deletePoll(int communityId, int pollId) async {
    try {
      final response = await _dio.delete(
        ApiConfig.communityPoll(communityId, pollId),
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to delete poll');
    }
  }

  /// Get list of categories from backend
  Future<List<CommunityCategoryModel>> getCategories() async {
    try {
      final response = await _dio.get(
        ApiConfig.communityCategories,
        options: await _authOptions(optional: true),
      );
      final list = _unwrapList(response.data);
      if (list.isNotEmpty) {
        final parsed = list
            .map((item) => CommunityCategoryModel.fromJson(item))
            .toList();
        // Add "All" option if not present
        if (!parsed.any((c) => c.name.toLowerCase() == 'all')) {
          return [
            const CommunityCategoryModel(
              id: 0,
              name: 'All',
              icon: '🌟',
              slug: 'all',
            ),
            ...parsed,
          ];
        }
        return parsed;
      }
      return const [
        CommunityCategoryModel(id: 0, name: 'All', icon: '🌟', slug: 'all'),
      ];
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load community categories');
    }
  }

  // ── Advanced PRD Sub-Feature APIs ──────────────────────────────

  /// Get pending join requests for a private community (Admin/Mod only)
  Future<List<CommunityJoinRequestModel>> getPendingJoinRequests(
    int communityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityJoinRequests(communityId),
        options: await _authOptions(),
      );
      final list = _unwrapList(response.data);
      return list
          .map((item) => CommunityJoinRequestModel.fromJson(item))
          .toList();
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load join requests');
    }
  }

  /// Approve a pending join request
  Future<bool> approveJoinRequest(int communityId, int requestId) async {
    try {
      final response = await _dio.post(
        ApiConfig.approveJoinRequest(communityId, requestId),
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to approve join request');
    }
  }

  /// Reject a pending join request
  Future<bool> rejectJoinRequest(int communityId, int requestId) async {
    try {
      final response = await _dio.post(
        ApiConfig.rejectJoinRequest(communityId, requestId),
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to reject join request');
    }
  }

  /// Update a member's role (Admin -> Moderator / Member)
  Future<bool> updateMemberRole(
    int communityId,
    int memberId,
    CommunityRole role,
  ) async {
    try {
      final response = await _dio.put(
        ApiConfig.communityMemberRole(communityId, memberId),
        data: {'role': role.name},
        options: await _authOptions(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to update member role');
    }
  }

  /// Remove or Ban a member from the community
  Future<bool> removeMember(
    int communityId,
    int memberId, {
    bool isBanned = false,
  }) async {
    try {
      if (isBanned) {
        final response = await _dio.post(
          ApiConfig.banCommunityMember(communityId, memberId),
          options: await _authOptions(),
        );
        return response.statusCode == 200;
      } else {
        final response = await _dio.delete(
          ApiConfig.communityMember(communityId, memberId),
          options: await _authOptions(),
        );
        return response.statusCode == 200 || response.statusCode == 204;
      }
    } on DioException catch (e) {
      throw _mapDioException(
        e,
        isBanned ? 'Failed to ban member' : 'Failed to remove member',
      );
    }
  }

  /// Ban a member from community (Admin only)
  Future<bool> banMember(int communityId, int memberId) async {
    try {
      final response = await _dio.post(
        ApiConfig.banCommunityMember(communityId, memberId),
        options: await _authOptions(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to ban member');
    }
  }

  Future<bool> unbanMember(int communityId, int userId) async {
    try {
      final response = await _dio.post(
        ApiConfig.unbanCommunityMember(communityId, userId),
        options: await _authOptions(),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to unban member');
    }
  }

  /// Get pinned announcements
  Future<List<CommunityAnnouncementModel>> getCommunityAnnouncements(
    int communityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityAnnouncements(communityId),
        options: await _authOptions(optional: true),
      );
      final list = _unwrapList(response.data);
      return list
          .map((item) => CommunityAnnouncementModel.fromJson(item))
          .toList();
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load announcements');
    }
  }

  /// Create a new official announcement (Admin only)
  Future<CommunityAnnouncementModel> createAnnouncement(
    int communityId,
    String title,
    String message,
  ) async {
    try {
      final response = await _dio.post(
        ApiConfig.communityAnnouncements(communityId),
        data: {'title': title, 'message': message},
        options: await _authOptions(),
      );
      return CommunityAnnouncementModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to publish announcement');
    }
  }

  /// Delete an announcement (Admin / Moderator only)
  Future<bool> deleteAnnouncement(int communityId, int announcementId) async {
    try {
      final response = await _dio.delete(
        ApiConfig.communityAnnouncement(communityId, announcementId),
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to delete announcement');
    }
  }

  /// Get Community Documents (PDFs, bylaws, guidelines)
  Future<List<CommunityDocumentModel>> getCommunityDocuments(
    int communityId,
  ) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityDocuments(communityId),
        options: await _authOptions(optional: true),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityDocumentModel.fromJson(item)).toList();
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load documents');
    }
  }

  /// Upload a Community Document - bytes-based (works on ALL platforms incl. Web)
  /// Enterprise fix: MultipartFile.fromFile(path) fails on Flutter Web.
  /// Use MultipartFile.fromBytes() which is platform-agnostic.
  Future<CommunityDocumentModel> uploadDocumentBytes(
    int communityId, {
    required String title,
    required List<int> fileBytes,
    required String fileName,
    String fileType = 'pdf',
    String fileSize = '0 MB',
  }) async {
    try {
      final form = FormData.fromMap({
        'title': title,
        'fileType': fileType,
        'fileSize': fileSize,
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });
      final response = await _dio.post(
        ApiConfig.communityDocuments(communityId),
        data: form,
        options: await _authOptions(),
      );
      return CommunityDocumentModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to upload document');
    }
  }

  /// [Deprecated] Use uploadDocumentBytes for web compatibility.
  @Deprecated('Use uploadDocumentBytes instead - supports all platforms including web')
  Future<CommunityDocumentModel> uploadDocument(
    int communityId, {
    required String title,
    required String filePath,
    String fileType = 'pdf',
    String fileSize = '1.2 MB',
  }) async {
    try {
      final form = FormData.fromMap({
        'title': title,
        'fileType': fileType,
        'fileSize': fileSize,
        'file': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        ApiConfig.communityDocuments(communityId),
        data: form,
        options: await _authOptions(),
      );
      return CommunityDocumentModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to upload document');
    }
  }

  /// Get Community Photo/Video Gallery
  Future<List<CommunityMediaModel>> getCommunityGallery(int communityId) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityGallery(communityId),
        options: await _authOptions(optional: true),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityMediaModel.fromJson(item)).toList();
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load gallery');
    }
  }

  /// Upload Community Gallery Media - bytes-based (works on ALL platforms incl. Web)
  /// Enterprise fix: XFile.path on Flutter Web returns a blob URL, not a real path.
  /// MultipartFile.fromFile() throws "MultipartFile is only supported where dart:io
  /// is available." on web. Use fromBytes() instead.
  Future<CommunityMediaModel> uploadMediaBytes(
    int communityId, {
    required List<int> fileBytes,
    required String fileName,
    String? caption,
    String mediaType = 'image',
  }) async {
    try {
      final form = FormData.fromMap({
        'mediaType': mediaType,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        'media': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });
      final response = await _dio.post(
        ApiConfig.communityGallery(communityId),
        data: form,
        options: await _authOptions(),
      );
      return CommunityMediaModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to upload media');
    }
  }

  /// [Deprecated] Use uploadMediaBytes for web compatibility.
  @Deprecated('Use uploadMediaBytes instead - supports all platforms including web')
  Future<CommunityMediaModel> uploadMedia(
    int communityId, {
    required String filePath,
    String? caption,
    String mediaType = 'image',
  }) async {
    try {
      final form = FormData.fromMap({
        'mediaType': mediaType,
        if (caption != null) 'caption': caption,
        'media': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post(
        ApiConfig.communityGallery(communityId),
        data: form,
        options: await _authOptions(),
      );
      return CommunityMediaModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to upload media');
    }
  }

  /// Delete a Community Document (by Admin / Moderator / Owner)
  Future<bool> deleteDocument(int communityId, int documentId) async {
    try {
      final response = await _dio.delete(
        ApiConfig.communityDocument(communityId, documentId),
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to delete document');
    }
  }

  /// Delete a Community Gallery Media (by Admin / Moderator / Owner)
  Future<bool> deleteMedia(int communityId, int mediaId) async {
    try {
      final response = await _dio.delete(
        ApiConfig.communityGalleryMedia(communityId, mediaId),
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to delete media');
    }
  }

  /// Update Community Settings / Info
  Future<CommunityModel> updateCommunity(
    int communityId,
    Map<String, dynamic> data,
  ) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      final coverPath = payload.remove('coverFilePath')?.toString();
      dynamic requestData = payload;
      if (coverPath != null && coverPath.isNotEmpty && !kIsWeb) {
        payload['cover_image'] = await MultipartFile.fromFile(coverPath);
        requestData = FormData.fromMap(payload);
      }
      final response = await _dio.put(
        ApiConfig.community(communityId),
        data: requestData,
        options: await _authOptions(),
      );
      return CommunityModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to update community');
    }
  }

  /// Delete Community (Creator/Admin only)
  Future<bool> deleteCommunity(int communityId) async {
    try {
      final response = await _dio.delete(
        ApiConfig.community(communityId),
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to delete community');
    }
  }

  /// Get Community Events
  Future<List<CommunityEventModel>> getCommunityEvents(int communityId) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityEvents(communityId),
        options: await _authOptions(optional: true),
      );
      return _unwrapList(
        response.data,
      ).map(CommunityEventModel.fromJson).toList();
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load events');
    }
  }

  /// Create Community Event
  Future<CommunityEventModel> createCommunityEvent(
    int communityId, {
    required String title,
    String? description,
    String? venue,
    required DateTime date,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.communityEvents(communityId),
        data: {
          'title': title,
          'description': description,
          'venue': venue,
          'date': date.toUtc().toIso8601String(),
        },
        options: await _authOptions(),
      );
      return CommunityEventModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to create event');
    }
  }

  Future<CommunityEventModel> rsvpCommunityEvent(
    int communityId,
    CommunityEventModel event,
    String status,
  ) async {
    try {
      final response = await _dio.put(
        ApiConfig.communityEventRsvp(communityId, event.id),
        data: {'status': status},
        options: await _authOptions(),
      );
      final data = _unwrapObject(response.data);
      return event.copyWith(
        myRsvpStatus: data['status']?.toString(),
        goingCount: _asInt(data['goingCount']),
        interestedCount: _asInt(data['interestedCount']),
      );
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to update RSVP');
    }
  }

  Future<CommunityPage<CommunityInviteableUser>> getInviteableUsers(
    int communityId, {
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityInviteableUsers(communityId),
        queryParameters: {
          'page': page,
          'limit': limit,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
        options: await _authOptions(),
      );
      final data = _unwrapObject(response.data);
      final users = data['users'] is List
          ? (data['users'] as List)
                .whereType<Map>()
                .map(
                  (value) => CommunityInviteableUser.fromJson(
                    Map<String, dynamic>.from(value),
                  ),
                )
                .toList()
          : <CommunityInviteableUser>[];
      return CommunityPage(
        items: users,
        total: _asInt(data['total']),
        page: _asInt(data['page'], fallback: page),
        totalPages: _asInt(data['totalPages'], fallback: 1),
      );
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to search inviteable users');
    }
  }

  Future<int> sendInvitations(int communityId, List<int> userIds) async {
    try {
      final response = await _dio.post(
        ApiConfig.communityInvitations(communityId),
        data: {'userIds': userIds},
        options: await _authOptions(),
      );
      return _asInt(_unwrapObject(response.data)['count']);
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to send invitations');
    }
  }

  Future<CommunityPage<CommunityInvitationModel>> getMyInvitations({
    int page = 1,
    int limit = 20,
    String status = 'pending',
  }) async {
    try {
      final response = await _dio.get(
        ApiConfig.myCommunityInvitations,
        queryParameters: {'page': page, 'limit': limit, 'status': status},
        options: await _authOptions(),
      );
      final data = _unwrapObject(response.data);
      final invitations = data['invitations'] is List
          ? (data['invitations'] as List)
                .whereType<Map>()
                .map(
                  (value) => CommunityInvitationModel.fromJson(
                    Map<String, dynamic>.from(value),
                  ),
                )
                .toList()
          : <CommunityInvitationModel>[];
      return CommunityPage(
        items: invitations,
        total: _asInt(data['total']),
        page: _asInt(data['page'], fallback: page),
        totalPages: _asInt(data['totalPages'], fallback: 1),
      );
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to load community invitations');
    }
  }

  Future<CommunityInvitationModel> respondToInvitation(
    int communityId,
    int invitationId,
    String action,
  ) async {
    if (action != 'accept' && action != 'decline') {
      throw ArgumentError.value(action, 'action', 'Must be accept or decline');
    }
    try {
      final response = await _dio.post(
        ApiConfig.respondCommunityInvitation(communityId, invitationId),
        data: {'action': action},
        options: await _authOptions(),
      );
      return CommunityInvitationModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to respond to invitation');
    }
  }

  Future<int> getCommunityChatId(int communityId) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityChat(communityId),
        options: await _authOptions(),
      );
      final id = _asInt(_unwrapObject(response.data)['id']);
      if (id <= 0) {
        throw const CommunityServiceException(
          'Community chat response did not contain a valid chat ID.',
        );
      }
      return id;
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to open community chat');
    }
  }

  // ── Helper Unwrappers ──────────────────────────────────────────

  List<Map<String, dynamic>> _unwrapList(dynamic responseData) {
    dynamic payload = responseData;
    // Handle { success, message, data: ... } wrapper
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    // Handle double-wrapped { data: { data: [...] } }
    if (payload is Map && payload['data'] != null && payload['data'] is List) {
      payload = payload['data'];
    }
    // Handle common list wrapper keys from backend
    if (payload is Map) {
      if (payload['communities'] is List) {
        payload = payload['communities'];
      } else if (payload['members'] is List) {
        payload = payload['members'];
      } else if (payload['requests'] is List) {
        payload = payload['requests'];
      } else if (payload['categories'] is List) {
        payload = payload['categories'];
      } else if (payload['rows'] is List) {
        payload = payload['rows'];
      } else if (payload['items'] is List) {
        payload = payload['items'];
      } else if (payload['polls'] is List) {
        payload = payload['polls'];
      } else if (payload['documents'] is List) {
        payload = payload['documents'];
      } else if (payload['gallery'] is List) {
        payload = payload['gallery'];
      } else if (payload['announcements'] is List) {
        payload = payload['announcements'];
      } else if (payload['results'] is List) {
        payload = payload['results'];
      }
    }
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    throw const CommunityServiceException(
      'Unexpected server list response format.',
    );
  }

  Map<String, dynamic> _unwrapObject(dynamic responseData) {
    dynamic payload = responseData;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw const CommunityServiceException('Unexpected server response format.');
  }

  CommunityServiceException _mapDioException(
    DioException error,
    String fallback,
  ) {
    final data = error.response?.data;
    String? msg;
    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    }
    return CommunityServiceException(
      msg ?? fallback,
      statusCode: error.response?.statusCode,
    );
  }


  int _asInt(dynamic value, {int fallback = 0}) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;

  /// Browse all public communities (search + category filter + pagination)
  /// Maps to: GET /communities?search=...&category_id=...&cursor=...&limit=...
  Future<({List<CommunityModel> communities, String? nextCursor, bool hasMore})>
      getAllCommunities({
    String? search,
    int? categoryId,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final options = await _authOptions(optional: true);
      final query = <String, dynamic>{
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (categoryId != null) 'category_id': categoryId,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      };

      final response = await _dio.get(
        '${ApiConfig.baseUrl}/communities',
        queryParameters: query,
        options: options,
      );

      final body = response.data;
      final data = body['data'] is Map ? body['data'] : body;
      final rawList = (data['communities'] ?? data['items'] ?? body['communities'] ?? []) as List<dynamic>;

      final communities = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => CommunityModel.fromJson(item))
          .toList();

      final nextCursor = data['nextCursor']?.toString() ?? data['cursor']?.toString();
      final hasMore = data['hasMore'] == true || data['has_more'] == true;

      return (communities: communities, nextCursor: nextCursor, hasMore: hasMore);
    } on DioException catch (e) {
      throw _mapDioException(e, 'Failed to browse communities.');
    }
  }
}
