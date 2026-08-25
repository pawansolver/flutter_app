import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_config.dart';
import '../models/community_models.dart';
import 'authenticated_dio.dart';

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
  CommunityService._internal() : _dio = AuthenticatedDio().dio;

  final Dio _dio;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null || token.trim().isEmpty) {
      throw const CommunityServiceException('Authentication required.');
    }
    return Options(
      headers: {'Authorization': 'Bearer ${token.trim()}'},
    );
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
      // Return dummy fallbacks if server offline during local dev
      if (kDebugMode && _isConnectionError(e)) {
        return _mockMyCommunities();
      }
      throw _mapDioException(e, 'Failed to fetch your communities');
    } catch (_) {
      return _mockMyCommunities();
    }
  }

  /// Get suggested/discoverable communities
  Future<List<CommunityModel>> getSuggestedCommunities({
    int? categoryId,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (categoryId != null && categoryId > 0) queryParams['categoryId'] = categoryId;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final response = await _dio.get(
        ApiConfig.suggestedCommunities,
        queryParameters: queryParams,
        options: await _authOptions(),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityModel.fromJson(item)).toList();
    } on DioException catch (e) {
      if (kDebugMode && _isConnectionError(e)) {
        return _mockSuggestedCommunities(categoryId: categoryId, search: search);
      }
      throw _mapDioException(e, 'Failed to discover communities');
    } catch (_) {
      return _mockSuggestedCommunities(categoryId: categoryId, search: search);
    }
  }

  /// Get detailed community by ID
  Future<CommunityModel> getCommunityDetails(int id) async {
    try {
      final response = await _dio.get(
        ApiConfig.community(id),
        options: await _authOptions(),
      );
      return CommunityModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      if (kDebugMode && _isConnectionError(e)) {
        final mock = _mockSuggestedCommunities().firstWhere(
          (c) => c.id == id,
          orElse: () => _mockMyCommunities().firstWhere((c) => c.id == id),
        );
        return mock;
      }
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
        'name': name.trim(),
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
      if (kDebugMode && _isConnectionError(e)) {
        // Return local representation
        return CommunityModel(
          id: DateTime.now().millisecondsSinceEpoch % 10000,
          name: name,
          description: description,
          category: 'General',
          categoryId: categoryId,
          isPrivate: isPrivate,
          membersCount: 1,
          postsCount: 0,
          isMember: true,
          myRole: CommunityRole.admin,
          createdAt: DateTime.now(),
        );
      }
      throw _mapDioException(e, 'Failed to create community');
    }
  }

  /// Join a community
  Future<bool> joinCommunity(int communityId) async {
    try {
      final response = await _dio.post(
        ApiConfig.joinCommunity(communityId),
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      if (kDebugMode && _isConnectionError(e)) return true;
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
      if (kDebugMode && _isConnectionError(e)) return true;
      throw _mapDioException(e, 'Failed to leave community');
    }
  }

  /// Get members list
  Future<List<CommunityMemberModel>> getCommunityMembers(int communityId) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityMembers(communityId),
        options: await _authOptions(),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityMemberModel.fromJson(item)).toList();
    } on DioException catch (e) {
      if (kDebugMode && _isConnectionError(e)) {
        return _mockMembers();
      }
      throw _mapDioException(e, 'Failed to load community members');
    } catch (_) {
      return _mockMembers();
    }
  }

  /// Get Community Scoped Feed Posts
  Future<List<CommunityPostModel>> getCommunityFeed(int communityId, {String? cursor, int limit = 20}) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityFeed(communityId),
        queryParameters: {
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
        },
        options: await _authOptions(),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityPostModel.fromJson(item)).toList();
    } on DioException catch (e) {
      if (kDebugMode && _isConnectionError(e)) {
        return _mockPosts(communityId);
      }
      throw _mapDioException(e, 'Failed to load community feed');
    } catch (_) {
      return _mockPosts(communityId);
    }
  }

  /// Create a post inside community
  Future<CommunityPostModel> createCommunityPost(
    int communityId, {
    required String content,
    List<String> mediaUrls = const [],
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.communityFeed(communityId),
        data: {
          'content': content,
          'media_urls': mediaUrls,
        },
        options: await _authOptions(),
      );
      return CommunityPostModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (e) {
      if (kDebugMode && _isConnectionError(e)) {
        return CommunityPostModel(
          id: DateTime.now().millisecondsSinceEpoch % 10000,
          communityId: communityId,
          authorId: 1,
          authorName: 'You',
          content: content,
          mediaUrls: mediaUrls,
          createdAt: DateTime.now(),
        );
      }
      throw _mapDioException(e, 'Failed to publish post to community');
    }
  }

  /// Get community polls
  Future<List<CommunityPollModel>> getCommunityPolls(int communityId) async {
    try {
      final response = await _dio.get(
        ApiConfig.communityPolls(communityId),
        options: await _authOptions(),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityPollModel.fromJson(item)).toList();
    } on DioException catch (e) {
      if (kDebugMode && _isConnectionError(e)) {
        return _mockPolls(communityId);
      }
      throw _mapDioException(e, 'Failed to load polls');
    } catch (_) {
      return _mockPolls(communityId);
    }
  }

  /// Vote on a poll option
  Future<bool> votePoll(int pollId, int optionId) async {
    try {
      final response = await _dio.post(
        ApiConfig.voteCommunityPoll(pollId),
        data: {'option_id': optionId},
        options: await _authOptions(),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      if (kDebugMode && _isConnectionError(e)) return true;
      throw _mapDioException(e, 'Failed to register vote');
    }
  }

  /// Get list of categories
  Future<List<CommunityCategoryModel>> getCategories() async {
    try {
      final response = await _dio.get(
        ApiConfig.communityCategories,
        options: await _authOptions(),
      );
      final list = _unwrapList(response.data);
      return list.map((item) => CommunityCategoryModel.fromJson(item)).toList();
    } catch (_) {
      return _defaultCategories();
    }
  }

  // ── Helper Unwrappers ──────────────────────────────────────────

  List<Map<String, dynamic>> _unwrapList(dynamic responseData) {
    dynamic payload = responseData;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    if (payload is List) {
      return payload.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Map<String, dynamic> _unwrapObject(dynamic responseData) {
    dynamic payload = responseData;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw const CommunityServiceException('Unexpected server response format.');
  }

  bool _isConnectionError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.response?.statusCode == 404 ||
        e.response?.statusCode == 500;
  }

  CommunityServiceException _mapDioException(DioException error, String fallback) {
    final data = error.response?.data;
    String? msg;
    if (data is Map && data['message'] != null) {
      msg = data['message'].toString();
    }
    return CommunityServiceException(msg ?? fallback, statusCode: error.response?.statusCode);
  }

  // ── Smart Mock / Fallback Data ─────────────────────────────────

  List<CommunityCategoryModel> _defaultCategories() {
    return const [
      CommunityCategoryModel(id: 1, name: 'All', icon: '🌟', slug: 'all'),
      CommunityCategoryModel(id: 2, name: 'Sports & Games', icon: '🏏', slug: 'sports'),
      CommunityCategoryModel(id: 3, name: 'Society & RWA', icon: '🏢', slug: 'society'),
      CommunityCategoryModel(id: 4, name: 'Fitness & Gym', icon: '💪', slug: 'fitness'),
      CommunityCategoryModel(id: 5, name: 'Buy & Sell', icon: '🛍️', slug: 'market'),
      CommunityCategoryModel(id: 6, name: 'Food & Cooking', icon: '🍲', slug: 'food'),
      CommunityCategoryModel(id: 7, name: 'Moms & Parenting', icon: '👶', slug: 'parenting'),
      CommunityCategoryModel(id: 8, name: 'Tech & Gadgets', icon: '💻', slug: 'tech'),
      CommunityCategoryModel(id: 9, name: 'Books & Learning', icon: '📚', slug: 'books'),
    ];
  }

  List<CommunityModel> _mockMyCommunities() {
    return [
      CommunityModel(
        id: 101,
        name: 'Sunday Cricket League Sector 62',
        description: 'Neighborhood cricket enthusiasts meeting every Sunday 7 AM at Mini Stadium.',
        category: 'Sports & Games',
        categoryId: 2,
        isPrivate: false,
        membersCount: 48,
        postsCount: 132,
        isMember: true,
        myRole: CommunityRole.admin,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        rules: ['Be punctual for morning matches', 'Bring your own kit if available', 'Respect umpire decisions'],
        hasUnread: true,
      ),
      CommunityModel(
        id: 102,
        name: 'Greenwood RWA Residents',
        description: 'Official resident community for tower announcements, maintenance, and parking discussions.',
        category: 'Society & RWA',
        categoryId: 3,
        isPrivate: true,
        membersCount: 184,
        postsCount: 340,
        isMember: true,
        myRole: CommunityRole.member,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        rules: ['Only verified flat owners & tenants', 'No promotional ads without admin approval'],
        hasUnread: false,
      ),
    ];
  }

  List<CommunityModel> _mockSuggestedCommunities({int? categoryId, String? search}) {
    final all = [
      ..._mockMyCommunities(),
      CommunityModel(
        id: 103,
        name: 'Indirapuram Organic Terrace Gardening',
        description: 'Share seeds, gardening tips, compost techniques, and plant care for terrace gardens.',
        category: 'Food & Cooking',
        categoryId: 6,
        isPrivate: false,
        membersCount: 230,
        postsCount: 512,
        isMember: false,
        myRole: CommunityRole.none,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        rules: ['Only organic techniques', 'Free seed exchange encouraged'],
      ),
      CommunityModel(
        id: 104,
        name: 'Noida Runners & Cycling Club',
        description: 'Morning runners, cycling routes, 10k marathon prep, and weekend group rides.',
        category: 'Fitness & Gym',
        categoryId: 4,
        isPrivate: false,
        membersCount: 410,
        postsCount: 680,
        isMember: false,
        myRole: CommunityRole.none,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        rules: ['Safety helmet mandatory for cycling', 'Track times on Strava'],
      ),
      CommunityModel(
        id: 105,
        name: 'Sector 62 Used Goods & Buy-Sell',
        description: 'Hyper-local marketplace for selling furniture, electronics, cycles, and books among neighbors.',
        category: 'Buy & Sell',
        categoryId: 5,
        isPrivate: false,
        membersCount: 590,
        postsCount: 1240,
        isMember: false,
        myRole: CommunityRole.none,
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
        rules: ['Genuine photos only', 'Mention fixed or negotiable price clearly'],
      ),
      CommunityModel(
        id: 106,
        name: 'Patna Tech & Developers Meetup',
        description: 'Flutter, Node.js, AI, and startup founders discussions and weekend hackathons.',
        category: 'Tech & Gadgets',
        categoryId: 8,
        isPrivate: false,
        membersCount: 165,
        postsCount: 290,
        isMember: false,
        myRole: CommunityRole.none,
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        rules: ['No spam or job broker links', 'Share real tech questions & projects'],
      ),
    ];

    if (search != null && search.isNotEmpty) {
      return all.where((c) => c.name.toLowerCase().contains(search.toLowerCase()) || (c.description?.toLowerCase().contains(search.toLowerCase()) ?? false)).toList();
    }
    if (categoryId != null && categoryId > 1) {
      return all.where((c) => c.categoryId == categoryId).toList();
    }
    return all;
  }

  List<CommunityMemberModel> _mockMembers() {
    return [
      CommunityMemberModel(
        id: 1,
        userId: 1,
        fullName: 'Rahul Sharma',
        userName: '@rahul_cricket',
        role: CommunityRole.admin,
        joinedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      CommunityMemberModel(
        id: 2,
        userId: 2,
        fullName: 'Vikram Patel',
        userName: '@vikram_p',
        role: CommunityRole.moderator,
        joinedAt: DateTime.now().subtract(const Duration(days: 28)),
      ),
      CommunityMemberModel(
        id: 3,
        userId: 3,
        fullName: 'Priya Verma',
        userName: '@priya_v',
        role: CommunityRole.member,
        joinedAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
      CommunityMemberModel(
        id: 4,
        userId: 4,
        fullName: 'Amit Kumar',
        userName: '@amit_k',
        role: CommunityRole.member,
        joinedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      CommunityMemberModel(
        id: 5,
        userId: 5,
        fullName: 'Sneha Gupta',
        userName: '@sneha_g',
        role: CommunityRole.member,
        joinedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }

  List<CommunityPostModel> _mockPosts(int communityId) {
    return [
      CommunityPostModel(
        id: 201,
        communityId: communityId,
        authorId: 1,
        authorName: 'Rahul Sharma',
        authorRole: 'Admin',
        content: '🏏 Match Alert! This Sunday we are having a friendly tournament at Sector 62 Ground at 7:00 AM sharp. Please confirm your availability in comments!',
        likesCount: 14,
        commentsCount: 9,
        isLikedByMe: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      CommunityPostModel(
        id: 202,
        communityId: communityId,
        authorId: 2,
        authorName: 'Vikram Patel',
        authorRole: 'Moderator',
        content: 'New leather balls and scorebook arrived today! Sponsored by Sharma Sweets. See everyone on field! 🏆',
        likesCount: 8,
        commentsCount: 3,
        isLikedByMe: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 18)),
      ),
    ];
  }

  List<CommunityPollModel> _mockPolls(int communityId) {
    return [
      CommunityPollModel(
        id: 301,
        communityId: communityId,
        question: 'Which day is better for the next 20-Over Tournament?',
        createdByName: 'Rahul Sharma',
        options: const [
          PollOptionModel(id: 1, text: 'Saturday Morning (6:30 AM)', votesCount: 18, isVotedByMe: false),
          PollOptionModel(id: 2, text: 'Sunday Morning (7:00 AM)', votesCount: 32, isVotedByMe: true),
          PollOptionModel(id: 3, text: 'Sunday Afternoon (4:00 PM)', votesCount: 5, isVotedByMe: false),
        ],
        totalVotes: 55,
        hasVoted: true,
        endsAt: DateTime.now().add(const Duration(days: 3)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}
