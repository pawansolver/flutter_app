import '../../../core/api_config.dart';

class FeedPost {
  final int id;
  final String content;
  final String? mediaUrl;
  final List<FeedMedia> mediaUrls;  // multi-image support
  int likesCount;
  int commentsCount;
  bool isLikedByMe;
  final String createdAt;
  bool isSaved;
  int shareCount;
  final String postType;
  final String authorName;
  final String? authorAvatarUrl;
  final int? authorUserId;
  final String? authorUserName;

  FeedPost({
    required this.id,
    required this.content,
    this.mediaUrl,
    this.mediaUrls = const [],
    required this.likesCount,
    required this.commentsCount,
    required this.isLikedByMe,
    required this.createdAt,
    this.isSaved = false,
    this.shareCount = 0,
    this.postType = 'text',
    required this.authorName,
    this.authorAvatarUrl,
    this.authorUserId,
    this.authorUserName,
  });

  // Returns true if this post has any media
  bool get hasMedia => effectiveMediaUrl != null;

  // Returns the primary media URL (first image/video)
  String? get effectiveMediaUrl {
    if (mediaUrl != null && mediaUrl!.isNotEmpty) return mediaUrl;
    if (mediaUrls.isNotEmpty) return mediaUrls.first.url;
    return null;
  }

  // Returns true if this is a video post
  bool get isVideo => postType == 'video';

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
    final authorMap = json['author'] is Map ? (json['author'] as Map) : null;

    final fullName = _safeString(
      authorMap?['fullName'] ?? authorMap?['userName'],
      'SmartGali User',
    );

    final avatarUrl = ApiConfig.normalizeMediaUrl(
      authorMap?['avatarUrl']?.toString(),
    );

    final authorUserId = authorMap?['userId'] != null
        ? _safeInt(authorMap!['userId'], 0)
        : null;

    final authorUserName = authorMap?['userName']?.toString();

    // Parse mediaUrls array (multi-image)
    final mediaUrlsList = <FeedMedia>[];
    if (json['mediaUrls'] is List) {
      for (final m in (json['mediaUrls'] as List)) {
        if (m is Map) {
          final url = ApiConfig.normalizeMediaUrl(m['url']?.toString());
          if (url != null && url.isNotEmpty) {
            mediaUrlsList.add(FeedMedia(
              id: _safeInt(m['id'], 0),
              url: url,
              type: _safeString(m['type'], 'image'),
            ));
          }
        }
      }
    }

    return FeedPost(
      id: _safeInt(json['id'], 0),
      content: _safeString(json['content'], ''),
      mediaUrl: ApiConfig.normalizeMediaUrl(json['mediaUrl']?.toString()),
      mediaUrls: mediaUrlsList,
      likesCount: _safeInt(json['likeCount'] ?? json['likesCount'], 0),
      commentsCount: _safeInt(json['commentCount'] ?? json['commentsCount'], 0),
      isLikedByMe: _safeBool(json['isLikedByMe'], false),
      createdAt: _safeString(json['createdAt'], ''),
      isSaved: _safeBool(json['isSaved'], false),
      shareCount: _safeInt(json['shareCount'], 0),
      postType: _safeString(json['postType'], 'text'),
      authorName: fullName,
      authorAvatarUrl: avatarUrl,
      authorUserId: authorUserId,
      authorUserName: authorUserName,
    );
  }
}

/// A single media item in a post (image or video)
class FeedMedia {
  final int id;
  final String url;
  final String type; // 'image' | 'video'

  const FeedMedia({required this.id, required this.url, required this.type});
}

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
    final authorMap = json['author'] is Map ? (json['author'] as Map) : null;
    final fullName = authorMap != null
        ? _safeString(authorMap['fullName'] ?? authorMap['userName'], 'User')
        : _safeString(json['authorName'], 'User');

    return FeedComment(
      id: _safeInt(json['id'], 0),
      content: _safeString(json['content'], ''),
      authorName: fullName,
      createdAt: _safeString(json['createdAt'], ''),
    );
  }
}
