import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api_config.dart';
import '../../services/authenticated_dio.dart';

/// Generic result wrapper — separates success payload from error message.
class NotificationResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  const NotificationResult.success(this.data) : error = null;
  const NotificationResult.failure(this.error) : data = null;
}

/// Notification category tabs used in the UI filter bar.
enum NotificationCategory { all, unread, society, social }

extension NotificationCategoryExt on NotificationCategory {
  String get label {
    switch (this) {
      case NotificationCategory.all:
        return 'All';
      case NotificationCategory.unread:
        return 'Unread';
      case NotificationCategory.society:
        return 'Society';
      case NotificationCategory.social:
        return 'Social';
    }
  }

  /// Backend `type` values that belong to this tab.
  /// Null means "no filtering" (show all).
  List<String>? get typeFilters {
    switch (this) {
      case NotificationCategory.all:
        return null;
      case NotificationCategory.unread:
        return null; // handled via unreadOnly query param
      case NotificationCategory.society:
        return ['alert', 'system', 'reminder'];
      case NotificationCategory.social:
        return ['message', 'comment', 'like', 'follow', 'info'];
    }
  }
}

/// A single notification as returned by the backend `/notification/me` feed.
class AppNotification {
  final int id;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    required this.isRead,
    this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final raw = json['createdAt']?.toString();
    if (raw != null && raw.isNotEmpty) {
      parsedDate = DateTime.tryParse(raw)?.toLocal();
    }
    return AppNotification(
      id: int.tryParse(json['id'].toString()) ?? 0,
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      type: (json['type'] ?? 'info').toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      isRead: json['isRead'] == true,
      createdAt: parsedDate,
    );
  }

  /// Returns the deep-link target type from the notification data payload.
  String? get deepLinkTarget => data?['target']?.toString();
}

/// Paginated feed payload for the notifications screen.
class NotificationFeed {
  final List<AppNotification> items;
  final int unreadCount;
  final int page;
  final int totalPages;

  const NotificationFeed({
    required this.items,
    required this.unreadCount,
    required this.page,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  factory NotificationFeed.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final pagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : const <String, dynamic>{};
    return NotificationFeed(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (e) => AppNotification.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : <AppNotification>[],
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '0') ?? 0,
      page: int.tryParse(pagination['page']?.toString() ?? '1') ?? 1,
      totalPages:
          int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1,
    );
  }
}

/// API client for the real-time notification feature. Singleton so the home
/// bell poller and the notifications screen share one Dio instance.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final Dio _dio = AuthenticatedDio().dio;
  final _storage = const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(
      headers: token == null || token.trim().isEmpty
          ? const <String, String>{}
          : {'Authorization': 'Bearer $token'},
    );
  }

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? fallback;
  }

  // ── READ ─────────────────────────────────────────────────────────────────

  Future<NotificationResult<NotificationFeed>> getMyNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    try {
      final resp = await _dio.get(
        ApiConfig.myNotifications,
        queryParameters: {
          'page': page,
          'limit': limit,
          if (unreadOnly) 'unreadOnly': true,
        },
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return NotificationResult.success(
          NotificationFeed.fromJson(
            Map<String, dynamic>.from(resp.data['data']),
          ),
        );
      }
      return NotificationResult.failure(
        resp.data['message']?.toString() ?? 'Failed to load notifications',
      );
    } on DioException catch (e) {
      return NotificationResult.failure(
        _extractError(e, 'Failed to load notifications'),
      );
    } catch (_) {
      return const NotificationResult.failure('Something went wrong');
    }
  }

  /// Lightweight unread count for the bell badge poller. Returns null on error
  /// so the caller can keep the last known value instead of resetting to 0.
  Future<int?> getUnreadCount() async {
    try {
      final resp = await _dio.get(
        ApiConfig.notificationsUnreadCount,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return int.tryParse(
              resp.data['data']?['unreadCount']?.toString() ?? '0',
            ) ??
            0;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── UPDATE ───────────────────────────────────────────────────────────────

  Future<NotificationResult<bool>> markRead(int id) async {
    try {
      final resp = await _dio.patch(
        ApiConfig.markNotificationRead(id),
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const NotificationResult.success(true);
      }
      return NotificationResult.failure(
        resp.data['message']?.toString() ?? 'Failed to mark as read',
      );
    } on DioException catch (e) {
      return NotificationResult.failure(
        _extractError(e, 'Failed to mark as read'),
      );
    } catch (_) {
      return const NotificationResult.failure('Something went wrong');
    }
  }

  Future<NotificationResult<int>> markAllRead() async {
    try {
      final resp = await _dio.patch(
        ApiConfig.markAllNotificationsRead,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return NotificationResult.success(
          int.tryParse(resp.data['data']?['updated']?.toString() ?? '0') ?? 0,
        );
      }
      return NotificationResult.failure(
        resp.data['message']?.toString() ?? 'Failed to update notifications',
      );
    } on DioException catch (e) {
      return NotificationResult.failure(
        _extractError(e, 'Failed to update notifications'),
      );
    } catch (_) {
      return const NotificationResult.failure('Something went wrong');
    }
  }

  // ── DELETE ───────────────────────────────────────────────────────────────

  /// Soft-delete a single notification (swipe-to-dismiss / long-press delete).
  Future<NotificationResult<bool>> deleteNotification(int id) async {
    try {
      final resp = await _dio.delete(
        ApiConfig.deleteNotification(id),
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const NotificationResult.success(true);
      }
      return NotificationResult.failure(
        resp.data['message']?.toString() ?? 'Failed to delete notification',
      );
    } on DioException catch (e) {
      return NotificationResult.failure(
        _extractError(e, 'Failed to delete notification'),
      );
    } catch (_) {
      return const NotificationResult.failure('Something went wrong');
    }
  }

  /// Bulk soft-delete — used for "Clear all read" action.
  Future<NotificationResult<int>> bulkDeleteNotifications(
    List<int> ids, {
    String? deletedRemarks,
  }) async {
    try {
      final resp = await _dio.post(
        ApiConfig.bulkDeleteNotifications,
        data: {
          'ids': ids,
          if (deletedRemarks != null) 'deletedRemarks': deletedRemarks,
        },
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return NotificationResult.success(
          int.tryParse(
                resp.data['data']?['count']?.toString() ?? '${ids.length}',
              ) ??
              ids.length,
        );
      }
      return NotificationResult.failure(
        resp.data['message']?.toString() ?? 'Failed to clear notifications',
      );
    } on DioException catch (e) {
      return NotificationResult.failure(
        _extractError(e, 'Failed to clear notifications'),
      );
    } catch (_) {
      return const NotificationResult.failure('Something went wrong');
    }
  }
}
