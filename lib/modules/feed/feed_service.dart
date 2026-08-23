import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_config.dart';
import '../../services/authenticated_dio.dart';
import 'models/feed_post_model.dart';

/// Uses the shared, release-safe API configuration.
String get _base => ApiConfig.baseUrl;

/// Result wrapper - separates success data from error message
class FeedResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  const FeedResult.success(this.data) : error = null;
  const FeedResult.failure(this.error) : data = null;
}

/// Enterprise service - all feed API calls in ONE place
class FeedService {
  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;
  FeedService._internal();

  final Dio _dio = AuthenticatedDio().dio;
  final _storage = const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // 1. GET Home Feed
  Future<FeedResult<Map<String, dynamic>>> getHomeFeed({
    int limit = 10,
    String? cursor,
  }) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit};
      if (cursor != null) queryParams['cursor'] = cursor;
      final resp = await _dio.get(
        '$_base/feed/home',
        queryParameters: queryParams,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return FeedResult.success(resp.data['data'] as Map<String, dynamic>);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to load feed');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // 2. POST Create Post
  Future<FeedResult<FeedPost>> createPost({
    required String content,
    List<int>? mediaIds,
    String? type,
    String? visibility,
  }) async {
    try {
      final resp = await _dio.post(
        '$_base/post',
        data: {
          'content': content,
          if (mediaIds != null && mediaIds.isNotEmpty) 'mediaIds': mediaIds,
          if (type != null) 'type': type,
          if (visibility != null) 'visibility': visibility,
        },
        options: await _authOptions(),
      );
      if (resp.statusCode == 201 && resp.data['success'] == true) {
        return FeedResult.success(FeedPost.fromJson(resp.data['data']));
      }
      return FeedResult.failure(
        resp.data['message'] ?? 'Failed to create post',
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // 3. POST Like
  Future<FeedResult<Map<String, dynamic>>> likePost(int postId) async {
    try {
      final resp = await _dio.post(
        '$_base/post/$postId/like',
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) &&
          resp.data['success'] == true) {
        return FeedResult.success(
          resp.data['data'] as Map<String, dynamic>? ?? {},
        );
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to like post');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // 4. DELETE Unlike
  Future<FeedResult<Map<String, dynamic>>> unlikePost(int postId) async {
    try {
      final resp = await _dio.delete(
        '$_base/post/$postId/like',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return FeedResult.success(
          resp.data['data'] as Map<String, dynamic>? ?? {},
        );
      }
      return FeedResult.failure(
        resp.data['message'] ?? 'Failed to unlike post',
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // 5. Toggle Like
  Future<FeedResult<Map<String, dynamic>>> toggleLike(
    int postId, {
    bool isCurrentlyLiked = false,
  }) async {
    if (isCurrentlyLiked) {
      return unlikePost(postId);
    } else {
      return likePost(postId);
    }
  }

  // 6. GET Comments
  Future<FeedResult<List<FeedComment>>> getComments(int postId) async {
    try {
      final resp = await _dio.get(
        '$_base/post/$postId/comments',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        final list = (resp.data['data'] as List?) ?? [];
        return FeedResult.success(
          list.map((e) => FeedComment.fromJson(e)).toList(),
        );
      }
      return FeedResult.failure(
        resp.data['message'] ?? 'Failed to load comments',
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? e.message ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // 7. POST Add Comment
  Future<FeedResult<FeedComment>> addComment({
    required int postId,
    required String content,
  }) async {
    try {
      final resp = await _dio.post(
        '$_base/post/$postId/comment',
        data: {'content': content},
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) &&
          resp.data['success'] == true) {
        return FeedResult.success(FeedComment.fromJson(resp.data['data']));
      }
      return FeedResult.failure(
        resp.data['message'] ?? 'Failed to add comment',
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // 8. POST Save Post
  Future<FeedResult<bool>> savePost(int postId) async {
    try {
      final resp = await _dio.post(
        '$_base/saved-post',
        data: {'post_id': postId},
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to save post');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // 8b. DELETE Unsave Post
  Future<FeedResult<bool>> unsavePost(int postId) async {
    try {
      final resp = await _dio.delete(
        '$_base/saved-post/$postId',
        data: {'post_id': postId},
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to remove from saved');
    } on DioException catch (e) {
      try {
        final resp2 = await _dio.delete(
          '$_base/saved-post',
          data: {'post_id': postId},
          options: await _authOptions(),
        );
        if (resp2.statusCode == 200 && resp2.data['success'] == true) {
          return const FeedResult.success(true);
        }
      } catch (_) {}
      final msg = e.response?.data?['message'] ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // 8c. Toggle Save Post
  Future<FeedResult<bool>> toggleSavePost(int postId, {required bool isCurrentlySaved}) async {
    if (isCurrentlySaved) {
      return unsavePost(postId);
    } else {
      return savePost(postId);
    }
  }

  // 9. POST Share to Feed
  Future<FeedResult<bool>> shareToFeed(int postId) async {
    try {
      final resp = await _dio.post(
        '$_base/post-share',
        data: {'post_id': postId},
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to share post');
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // 10. Reverse geocode lat/lng to neighbourhood name
  Future<String> reverseGeocode(double lat, double lon) async {
    try {
      final resp = await Dio().get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {'lat': lat, 'lon': lon, 'format': 'json'},
        options: Options(headers: {'User-Agent': 'smartgali/1.0'}),
      );
      final addr = resp.data['address'];
      if (addr == null) return 'Your neighbourhood';
      final parts = <String>[];
      if (addr['neighbourhood'] != null) {
        parts.add(addr['neighbourhood'].toString());
      } else if (addr['suburb'] != null) {
        parts.add(addr['suburb'].toString());
      }
      if (addr['city'] != null) {
        parts.add(addr['city'].toString());
      } else if (addr['town'] != null) {
        parts.add(addr['town'].toString());
      }
      return parts.isNotEmpty ? parts.join(', ') : 'Your neighbourhood';
    } catch (_) {
      return 'Your neighbourhood';
    }
  }

  // 11. DELETE Post (author only)
  Future<FeedResult<bool>> deletePost(int postId) async {
    try {
      final resp = await _dio.delete(
        '$_base/post/$postId',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to delete post');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 12. Report Post
  Future<FeedResult<bool>> reportPost(int postId, {required String reason, String? details}) async {
    try {
      final resp = await _dio.post(
        '$_base/post/$postId/report',
        data: {'reason': reason, if (details != null) 'details': details},
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to report');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 13. Unfollow User
  Future<FeedResult<bool>> unfollowUser(int targetUserId) async {
    try {
      final resp = await _dio.delete(
        '$_base/users/unfollow/$targetUserId',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to unfollow');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 14. PUT Edit Post
  Future<FeedResult<Map<String, dynamic>>> editPost(int postId, {required String content, String? visibility}) async {
    try {
      final resp = await _dio.put(
        '$_base/post/$postId',
        data: {
          'content': content,
          if (visibility != null) 'visibility': visibility,
        },
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return FeedResult.success(resp.data['data'] as Map<String, dynamic>? ?? {});
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to update post');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 15. PATCH Update Post Visibility
  Future<FeedResult<bool>> updateVisibility(int postId, String visibility) async {
    try {
      final resp = await _dio.patch(
        '$_base/post/$postId/visibility',
        data: {'visibility': visibility},
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to update audience');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 16. POST Pin Post
  Future<FeedResult<bool>> togglePinPost(int postId) async {
    try {
      final resp = await _dio.post(
        '$_base/post/$postId/pin',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to toggle pin');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 17. POST Toggle Comments
  Future<FeedResult<bool>> toggleComments(int postId) async {
    try {
      final resp = await _dio.post(
        '$_base/post/$postId/toggle-comments',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to toggle comments');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 18. PUT / POST Block User
  Future<FeedResult<bool>> blockUser(int targetUserId) async {
    try {
      final resp = await _dio.put(
        '$_base/user/$targetUserId/block',
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to block user');
    } on DioException catch (e) {
      try {
        final resp2 = await _dio.post(
          '$_base/users/block',
          data: {'targetUserId': targetUserId, 'userId': targetUserId},
          options: await _authOptions(),
        );
        if ((resp2.statusCode == 200 || resp2.statusCode == 201) && resp2.data['success'] == true) {
          return const FeedResult.success(true);
        }
      } catch (_) {}
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 19. PUT / POST Mute User
  Future<FeedResult<bool>> muteUser(int targetUserId) async {
    try {
      final resp = await _dio.put(
        '$_base/user/$targetUserId/mute',
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to mute user');
    } on DioException catch (e) {
      try {
        final resp2 = await _dio.post(
          '$_base/users/mute',
          data: {'targetUserId': targetUserId, 'userId': targetUserId},
          options: await _authOptions(),
        );
        if ((resp2.statusCode == 200 || resp2.statusCode == 201) && resp2.data['success'] == true) {
          return const FeedResult.success(true);
        }
      } catch (_) {}
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 20. GET Post Insights (Live DB Metrics)
  Future<FeedResult<Map<String, dynamic>>> getPostInsights(int postId) async {
    try {
      final resp = await _dio.get(
        '$_base/post/$postId/insights',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return FeedResult.success(resp.data['data'] as Map<String, dynamic>? ?? {});
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to load insights');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

  // 21. POST Record Batch Views (Enterprise Viewport Dwell-Time Ingestion)
  Future<FeedResult<bool>> recordBatchViews(List<Map<String, dynamic>> views) async {
    if (views.isEmpty) return const FeedResult.success(true);
    try {
      final resp = await _dio.post(
        '$_base/post/batch-views',
        data: {'views': views},
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const FeedResult.success(true);
      }
      return FeedResult.failure(resp.data['message'] ?? 'Failed to record batch views');
    } on DioException catch (e) {
      return FeedResult.failure(e.response?.data?['message'] ?? 'Network error');
    }
  }

}