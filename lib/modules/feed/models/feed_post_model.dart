import '../../../core/api_config.dart';

/// Enterprise model — maps 1:1 with the backend feed timeline item
class FeedPost {
  final int id;
  final String content;
  final String? mediaUrl;
  int likesCount;
  int commentsCount;
  bool isLikedByMe;
  final String createdAt;
  final String authorName;
  final String? authorAvatarUrl;

  FeedPost({
    required this.id,
    required this.content,
    this.mediaUrl,
    required this.likesCount,
    required this.commentsCount,
    required this.isLikedByMe,
    required this.createdAt,
    required this.authorName,
    this.authorAvatarUrl,
  });

  static String _safeString(dynamic val, String fallback) {
    if (val == null) return fallback;
    final s = val.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static int _safeInt(dynamic val, int fallback) {
    if (val == null) return fallback;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? fallback;
  }

  static bool _safeBool(dynamic val, bool fallback) {
    if (val == null) return fallback;
    if (val is bool) return val;
    return val.toString().toLowerCase() == 'true';
  }

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    // On Flutter Web, json['user'] is a JS object — must cast explicitly
    final userMap = json['user'] is Map ? (json['user'] as Map) : null;
    final fullName = userMap != null
        ? _safeString(userMap['fullName'], 'smartgali User')
        : 'smartgali User';
    final avatarUrl = userMap != null
        ? ApiConfig.normalizeMediaUrl(userMap['avatarUrl']?.toString())
        : null;

    return FeedPost(
      id: _safeInt(json['id'], 0),
      content: _safeString(json['content'], ''),
      mediaUrl: ApiConfig.normalizeMediaUrl(json['mediaUrl']?.toString()),
      likesCount: _safeInt(json['likesCount'], 0),
      commentsCount: _safeInt(json['commentsCount'], 0),
      isLikedByMe: _safeBool(json['isLikedByMe'], false),
      createdAt: _safeString(json['createdAt'], ''),
      authorName: fullName,
      authorAvatarUrl: avatarUrl,
    );
  }
}

/// Enterprise model for a notice banner
class FeedNotice {
  final int id;
  final String title;
  final String content;
  final String? scheduledTime;

  const FeedNotice({
    required this.id,
    required this.title,
    required this.content,
    this.scheduledTime,
  });

  static String _safeString(dynamic val, String fallback) {
    if (val == null) return fallback;
    final s = val.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static int _safeInt(dynamic val, int fallback) {
    if (val == null) return fallback;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? fallback;
  }

  factory FeedNotice.fromJson(Map<String, dynamic> json) {
    return FeedNotice(
      id: _safeInt(json['id'], 0),
      title: _safeString(json['title'], 'Notice'),
      content: _safeString(json['content'], ''),
      scheduledTime: json['scheduledTime']?.toString(),
    );
  }
}

/// Enterprise model for a single comment
class FeedComment {
  final int id;
  final String content;
  final String authorName;
  final String createdAt;

  const FeedComment({
    required this.id,
    required this.content,
    required this.authorName,
    required this.createdAt,
  });

  static String _safeString(dynamic val, String fallback) {
    if (val == null) return fallback;
    final s = val.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static int _safeInt(dynamic val, int fallback) {
    if (val == null) return fallback;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? fallback;
  }

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    // On Flutter Web, json['user'] is a JS object — must cast explicitly
    final userMap = json['user'] is Map ? (json['user'] as Map) : null;
    final fullName = userMap != null
        ? _safeString(userMap['fullName'], 'User')
        : _safeString(json['authorName'], 'User');

    return FeedComment(
      id: _safeInt(json['id'], 0),
      content: _safeString(json['content'], ''),
      authorName: fullName,
      createdAt: _safeString(json['createdAt'], ''),
    );
  }
}
