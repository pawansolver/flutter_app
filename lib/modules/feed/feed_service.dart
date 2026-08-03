import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_config.dart';
import 'models/feed_post_model.dart';

/// Uses the shared, release-safe API configuration.
String get _base => ApiConfig.baseUrl;

/// Result wrapper — separates success data from error message
class FeedResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  const FeedResult.success(this.data) : error = null;
  const FeedResult.failure(this.error) : data = null;
}

/// Enterprise service — all feed API calls in ONE place
class FeedService {
  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;
  FeedService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final _storage = const FlutterSecureStorage();

  // ── Private helper: get auth header ─────────────────────────────
  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  // ── 1. GET Home Feed ─────────────────────────────────────────────
  Future<FeedResult<Map<String, dynamic>>> getHomeFeed({int page = 1}) async {
    try {
      final resp = await _dio.get(
        '$_base/feed',
        queryParameters: {'page': page, 'limit': 10},
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

  // ── 2. POST Create Post ──────────────────────────────────────────
  Future<FeedResult<FeedPost>> createPost({
    required String content,
    String? mediaUrl,
  }) async {
    try {
      final resp = await _dio.post(
        '$_base/feed/post',
        data: {'content': content, 'mediaUrl': mediaUrl},
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

  // ── 3. POST Toggle Like ──────────────────────────────────────────
  Future<FeedResult<Map<String, dynamic>>> toggleLike(int postId) async {
    try {
      final resp = await _dio.post(
        '$_base/feed/post/$postId/like',
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return FeedResult.success(resp.data['data'] as Map<String, dynamic>);
      }
      return FeedResult.failure(
        resp.data['message'] ?? 'Failed to toggle like',
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['message'] ?? 'Network error';
      return FeedResult.failure(msg);
    }
  }

  // ── 4. GET Comments for a post ───────────────────────────────────
  Future<FeedResult<List<FeedComment>>> getComments(int postId) async {
    try {
      final resp = await _dio.get(
        '$_base/post-comment/by-post/$postId',
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

  // ── 5. POST Add Comment ──────────────────────────────────────────
  Future<FeedResult<FeedComment>> addComment({
    required int postId,
    required String content,
  }) async {
    try {
      final resp = await _dio.post(
        '$_base/post-comment',
        data: {'post_id': postId, 'content': content},
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

  // ── 6. Reverse geocode lat/lng → neighbourhood name ───────────────
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
}
