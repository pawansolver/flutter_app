import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_config.dart';
import '../../services/authenticated_dio.dart';

// ── Model: A safe user returned by follow endpoints ─────────────────────────
class FollowUserModel {
  final int userId;
  final String userName;
  final String? fullName;
  final String? avatarUrl;

  const FollowUserModel({
    required this.userId,
    required this.userName,
    this.fullName,
    this.avatarUrl,
  });

  factory FollowUserModel.fromJson(Map<String, dynamic> json) {
    // Backend getAllUsers returns nested 'profile' object
    // UserProfile model uses: avatarUrl, fullName (camelCase in Sequelize)
    final profile = json['profile'] as Map<String, dynamic>?;

    final rawAvatar = profile?['avatarUrl'] ??   // ✅ correct field name
        profile?['profile_image'] ??             // fallback
        json['avatarUrl'] ??
        json['avatar_url'];

    final rawFullName = profile?['fullName'] ??  // ✅ correct field name
        profile?['full_name'] ??                 // fallback
        json['fullName'] ??
        json['full_name'];

    return FollowUserModel(
      userId: (json['userId'] ?? json['user_id'] ?? 0) is int
          ? json['userId'] ?? json['user_id'] ?? 0
          : int.tryParse(json['userId']?.toString() ?? '0') ?? 0,
      userName: json['userName'] ?? json['username'] ?? '',
      fullName: (rawFullName as String?)?.isNotEmpty == true ? rawFullName : null,
      avatarUrl: (rawAvatar as String?)?.isNotEmpty == true
          ? ApiConfig.normalizeMediaUrl(rawAvatar)
          : null,
    );
  }

  String get displayName => fullName?.isNotEmpty == true ? fullName! : userName;
}

// ── Model: Paginated list response ──────────────────────────────────────────
class FollowListResult {
  final List<FollowUserModel> users;
  final int total;
  final int page;
  final int totalPages;

  const FollowListResult({
    required this.users,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

// ── Result wrapper ────────────────────────────────────────────────────────────
class FollowResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  const FollowResult.success(this.data) : error = null;
  const FollowResult.failure(this.error) : data = null;
}

// ── Service ───────────────────────────────────────────────────────────────────
class FollowService {
  static final FollowService _instance = FollowService._internal();
  factory FollowService() => _instance;
  FollowService._internal();

  final Dio _dio = AuthenticatedDio().dio;
  final _storage = const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── 1. Follow a user ──────────────────────────────────────────
  Future<FollowResult<String>> followUser(int targetUserId) async {
    try {
      final resp = await _dio.post(
        ApiConfig.followUser,
        data: {'userId': targetUserId},
        options: await _authOptions(),
      );
      if (resp.statusCode == 201 && resp.data['success'] == true) {
        final msg = resp.data['data']?['message'] ?? 'Followed successfully.';
        return FollowResult.success(msg);
      }
      return FollowResult.failure(resp.data['message'] ?? 'Follow failed.');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return FollowResult.success('Already following this user.');
      }
      final msg = e.response?.data?['message'] ?? e.message ?? 'Network error';
      return FollowResult.failure(msg);
    }
  }

  // ── 2. Unfollow a user ────────────────────────────────────────
  Future<FollowResult<bool>> unfollowUser(int targetUserId) async {
    try {
      final resp = await _dio.delete(
        ApiConfig.unfollow(targetUserId),
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FollowResult.success(true);
      }
      return FollowResult.failure(resp.data['message'] ?? 'Unfollow failed.');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Network error';
      return FollowResult.failure(msg);
    }
  }

  // ── 3. Get my followers ───────────────────────────────────────
  Future<FollowResult<FollowListResult>> getFollowers({int page = 1, int limit = 20}) async {
    try {
      final resp = await _dio.get(
        ApiConfig.myFollowers,
        queryParameters: {'page': page, 'limit': limit},
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        final data = resp.data['data'] as Map<String, dynamic>;
        final rawList = (data['followers'] as List?) ?? [];
        return FollowResult.success(FollowListResult(
          users: rawList.map((e) => FollowUserModel.fromJson(e)).toList(),
          total: data['total'] ?? 0,
          page: data['page'] ?? page,
          totalPages: data['totalPages'] ?? 1,
        ));
      }
      return FollowResult.failure(resp.data['message'] ?? 'Failed to load followers.');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Network error';
      return FollowResult.failure(msg);
    }
  }

  // ── 4. Get users I follow ─────────────────────────────────────
  Future<FollowResult<FollowListResult>> getFollowing({int page = 1, int limit = 20}) async {
    try {
      final resp = await _dio.get(
        ApiConfig.myFollowing,
        queryParameters: {'page': page, 'limit': limit},
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        final data = resp.data['data'] as Map<String, dynamic>;
        final rawList = (data['following'] as List?) ?? [];
        return FollowResult.success(FollowListResult(
          users: rawList.map((e) => FollowUserModel.fromJson(e)).toList(),
          total: data['total'] ?? 0,
          page: data['page'] ?? page,
          totalPages: data['totalPages'] ?? 1,
        ));
      }
      return FollowResult.failure(resp.data['message'] ?? 'Failed to load following.');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Network error';
      return FollowResult.failure(msg);
    }
  }

  // ── 5. Get suggested users (Quick fix for discover users) ────────
  Future<FollowResult<List<FollowUserModel>>> getSuggestedUsers() async {
    try {
      final resp = await _dio.get(
        ApiConfig.allUsers,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        // Backend returns: { success: true, message: '...', data: [ {user1}, {user2} ] }
        // 'data' can be a List directly OR a Map with 'users' key — handle both
        final rawData = resp.data['data'];
        List rawList;
        if (rawData is List) {
          rawList = rawData;
        } else if (rawData is Map && rawData['users'] != null) {
          rawList = rawData['users'] as List;
        } else {
          rawList = [];
        }
        debugPrint('Got users: ${rawList.length}');
        return FollowResult.success(
          rawList.map((e) => FollowUserModel.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
      }
      debugPrint('getSuggestedUsers failed with status: ${resp.statusCode}, data: ${resp.data}');
      return FollowResult.failure('Failed to load users.');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Network error';
      debugPrint('getSuggestedUsers DioException: $msg, URL: ${e.requestOptions.uri}');
      return FollowResult.failure(msg);
    } catch (e) {
      debugPrint('getSuggestedUsers exception: $e');
      return FollowResult.failure(e.toString());
    }
  }
}
