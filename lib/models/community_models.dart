import '../core/api_config.dart';

enum CommunityJoinStatus {
  none,
  pending,
  member,
  banned;

  static CommunityJoinStatus fromJson(Map<String, dynamic> json) {
    if (json['isMember'] == true || json['is_member'] == true) {
      return CommunityJoinStatus.member;
    }
    if (json['hasPendingRequest'] == true ||
        json['has_pending_request'] == true ||
        json['isPending'] == true) {
      return CommunityJoinStatus.pending;
    }
    final status = (json['joinStatus'] ?? json['join_status'] ?? json['status'])
        ?.toString()
        .toLowerCase();
    if (status == 'active' || status == 'member') {
      return CommunityJoinStatus.member;
    }
    if (status == 'pending') return CommunityJoinStatus.pending;
    if (status == 'banned') return CommunityJoinStatus.banned;
    return CommunityJoinStatus.none;
  }
}

/// Role of a user inside a community
enum CommunityRole {
  admin,
  moderator,
  member,
  none;

  static CommunityRole fromString(String? role) {
    switch (role?.toLowerCase().trim()) {
      case 'admin':
      case 'creator':
        return CommunityRole.admin;
      case 'moderator':
      case 'mod':
        return CommunityRole.moderator;
      case 'member':
        return CommunityRole.member;
      default:
        return CommunityRole.none;
    }
  }

  String get displayName {
    switch (this) {
      case CommunityRole.admin:
        return 'Admin';
      case CommunityRole.moderator:
        return 'Moderator';
      case CommunityRole.member:
        return 'Member';
      case CommunityRole.none:
        return '';
    }
  }
}

/// Category of a community (e.g. Sports, Books, Society, Tech)
class CommunityCategoryModel {
  final int id;
  final String name;
  final String? icon;
  final String? slug;
  final String? description;

  const CommunityCategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.slug,
    this.description,
  });

  factory CommunityCategoryModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['communityCategoryId'] ?? json['id'];
    final rawName =
        json['communityCategoryName'] ?? json['categoryName'] ?? json['name'];
    final rawIcon = json['communityCategoryIcon'] ?? json['icon'];

    return CommunityCategoryModel(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0,
      name: rawName?.toString() ?? 'General',
      icon: rawIcon?.toString(),
      slug: json['slug']?.toString(),
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'slug': slug,
    'description': description,
  };
}

/// Full model for a Community (Group)
class CommunityModel {
  final int id;
  final String name;
  final String? description;
  final String? category;
  final int? categoryId;
  final String? iconUrl;
  final String? coverImageUrl;
  final bool isPrivate;
  final int membersCount;
  final int postsCount;
  final bool isMember;
  final CommunityJoinStatus joinStatus;
  final CommunityRole myRole;
  final int? chatId;
  final int? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final List<String>? rules;
  final bool hasUnread;

  const CommunityModel({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.categoryId,
    this.iconUrl,
    this.coverImageUrl,
    this.isPrivate = false,
    this.membersCount = 0,
    this.postsCount = 0,
    this.isMember = false,
    this.joinStatus = CommunityJoinStatus.none,
    this.myRole = CommunityRole.none,
    this.chatId,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.rules,
    this.hasUnread = false,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    final rawRole =
        json['myRole'] ??
        json['my_role'] ??
        json['role'] ??
        json['membership_role'];
    final rawIsMember =
        json['isMember'] ??
        json['is_member'] ??
        json['isJoined'] ??
        (rawRole != null && rawRole != 'none');

    List<String>? parsedRules;
    if (json['rules'] is List) {
      parsedRules = (json['rules'] as List).map((e) => e.toString()).toList();
    } else if (json['rules'] is String &&
        (json['rules'] as String).isNotEmpty) {
      parsedRules = (json['rules'] as String)
          .split('\n')
          .where((r) => r.trim().isNotEmpty)
          .toList();
    }

    final rawId = json['communityId'] ?? json['id'];
    final rawName = json['communityName'] ?? json['name'] ?? json['title'];
    final rawDesc = json['communityDescription'] ?? json['description'];
    final rawCover =
        json['cover_image'] ??
        json['cover_image_url'] ??
        json['coverImageUrl'] ??
        json['banner'];
    final rawIcon = json['icon'] ?? json['icon_url'] ?? json['iconUrl'];
    final rawCatId = json['category_id'] ?? json['categoryId'];
    final rawMembers =
        json['members_count'] ?? json['membersCount'] ?? json['members'];
    final rawPosts = json['posts_count'] ?? json['postsCount'];

    String catName = 'General';
    if (json['category'] is Map) {
      catName =
          json['category']['categoryName']?.toString() ??
          json['category']['communityCategoryName']?.toString() ??
          'General';
    } else if (json['category_name'] != null) {
      catName = json['category_name'].toString();
    } else if (json['category'] != null) {
      catName = json['category'].toString();
    }

    String? creatorName;
    if (json['creator'] is Map) {
      creatorName = json['creator']['userName']?.toString();
    } else {
      creatorName = json['created_by_name']?.toString();
    }

    return CommunityModel(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0,
      name: rawName?.toString() ?? 'Community',
      description: rawDesc?.toString(),
      category: catName,
      categoryId: rawCatId is int
          ? rawCatId
          : int.tryParse(rawCatId?.toString() ?? ''),
      iconUrl: ApiConfig.normalizeMediaUrl(rawIcon?.toString()),
      coverImageUrl: ApiConfig.normalizeMediaUrl(rawCover?.toString()),
      isPrivate:
          json['is_private'] == true ||
          json['is_private'] == 1 ||
          json['isPrivate'] == true ||
          json['privacy'] == 'private',
      membersCount: rawMembers is int
          ? rawMembers
          : int.tryParse(rawMembers?.toString() ?? '0') ?? 0,
      postsCount: rawPosts is int
          ? rawPosts
          : int.tryParse(rawPosts?.toString() ?? '0') ?? 0,
      isMember: rawIsMember == true || rawIsMember == 1,
      joinStatus: CommunityJoinStatus.fromJson(json),
      myRole: CommunityRole.fromString(rawRole?.toString()),
      chatId: _asInt(json['chatId'] ?? json['chat_id']),
      createdBy: json['created_by'] is int
          ? json['created_by']
          : int.tryParse(json['created_by']?.toString() ?? ''),
      createdByName: creatorName,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      rules: parsedRules,
      hasUnread: json['has_unread'] == true || json['hasUnread'] == true,
    );
  }

  CommunityModel copyWith({
    int? id,
    String? name,
    String? description,
    String? category,
    int? categoryId,
    String? iconUrl,
    String? coverImageUrl,
    bool? isPrivate,
    int? membersCount,
    int? postsCount,
    bool? isMember,
    CommunityJoinStatus? joinStatus,
    CommunityRole? myRole,
    int? chatId,
    int? createdBy,
    String? createdByName,
    DateTime? createdAt,
    List<String>? rules,
    bool? hasUnread,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      iconUrl: iconUrl ?? this.iconUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      membersCount: membersCount ?? this.membersCount,
      postsCount: postsCount ?? this.postsCount,
      isMember: isMember ?? this.isMember,
      joinStatus: joinStatus ?? this.joinStatus,
      myRole: myRole ?? this.myRole,
      chatId: chatId ?? this.chatId,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      rules: rules ?? this.rules,
      hasUnread: hasUnread ?? this.hasUnread,
    );
  }
}

/// Community Member Model
class CommunityMemberModel {
  final int id;
  final int userId;
  final String fullName;
  final String? userName;
  final String? avatarUrl;
  final CommunityRole role;
  final DateTime? joinedAt;

  const CommunityMemberModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.userName,
    this.avatarUrl,
    this.role = CommunityRole.member,
    this.joinedAt,
  });

  factory CommunityMemberModel.fromJson(Map<String, dynamic> json) {
    final userObj = json['user'] is Map ? json['user'] : null;
    final profileObj = userObj != null && userObj['profile'] is Map
        ? userObj['profile']
        : null;

    final rawId = json['communityMemberId'] ?? json['id'];
    final rawUserId = json['user_id'] ?? json['userId'] ?? userObj?['userId'];
    final rawFullName =
        profileObj?['fullName'] ??
        userObj?['userName'] ??
        json['full_name'] ??
        json['name'] ??
        'Resident';
    final rawUserName =
        userObj?['userName'] ?? json['user_name'] ?? json['username'];
    final rawAvatar =
        profileObj?['avatarUrl'] ??
        json['avatar_url'] ??
        json['avatar'] ??
        json['profile_image'];

    return CommunityMemberModel(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0,
      userId: rawUserId is int
          ? rawUserId
          : int.tryParse(rawUserId?.toString() ?? '0') ?? 0,
      fullName: rawFullName.toString(),
      userName: rawUserName?.toString(),
      avatarUrl: ApiConfig.normalizeMediaUrl(rawAvatar?.toString()),
      role: CommunityRole.fromString(json['role']?.toString()),
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString())
          : null,
    );
  }
}

/// Community-Scoped Feed Post Model
class CommunityPostModel {
  final int id;
  final int communityId;
  final int authorId;
  final String authorName;
  final String? authorAvatar;
  final String? authorRole;
  final String content;
  final List<String> mediaUrls;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final bool isSaved;
  final bool commentsDisabled;
  final DateTime createdAt;

  const CommunityPostModel({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorRole,
    required this.content,
    this.mediaUrls = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLikedByMe = false,
    this.isSaved = false,
    this.commentsDisabled = false,
    required this.createdAt,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    List<String> media = [];
    final rawMedia = json['mediaUrls'] ?? json['media_urls'] ?? json['media'];
    if (rawMedia is List) {
      media = rawMedia
          .map((item) {
            final raw = item is Map ? item['url'] ?? item['media_url'] : item;
            return ApiConfig.normalizeMediaUrl(raw?.toString());
          })
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList();
    } else {
      final primary = ApiConfig.normalizeMediaUrl(
        (json['mediaUrl'] ?? json['media_url'])?.toString(),
      );
      if (primary != null) media = [primary];
    }

    final authorObj = json['author'] is Map ? json['author'] : null;
    final profileObj = authorObj != null && authorObj['profile'] is Map
        ? authorObj['profile']
        : null;

    final authorName =
        profileObj?['fullName'] ??
        authorObj?['fullName'] ??
        authorObj?['userName'] ??
        json['author_name'] ??
        json['full_name'] ??
        'Member';
    final authorAvatar =
        profileObj?['avatarUrl'] ??
        authorObj?['avatarUrl'] ??
        authorObj?['avatar'] ??
        json['author_avatar'] ??
        json['avatar_url'];

    return CommunityPostModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      communityId:
          _asInt(json['communityId'] ?? json['community_id']) ?? 0,
      authorId:
          _asInt(
            authorObj?['userId'] ??
                json['user_id'] ??
                json['author_id'] ??
                json['authorId'],
          ) ??
          0,
      authorName: authorName.toString(),
      authorAvatar: ApiConfig.normalizeMediaUrl(authorAvatar?.toString()),
      authorRole: json['author_role']?.toString(),
      content: json['content']?.toString() ?? '',
      mediaUrls: media,
      likesCount:
          _asInt(
            json['likeCount'] ?? json['likes_count'] ?? json['likesCount'],
          ) ??
          0,
      commentsCount:
          _asInt(
            json['commentCount'] ??
                json['comments_count'] ??
                json['commentsCount'],
          ) ??
          0,
      isLikedByMe:
          json['isLikedByMe'] == true ||
          json['is_liked'] == true ||
          json['isLiked'] == true,
      isSaved: json['isSaved'] == true || json['is_saved'] == true,
      commentsDisabled:
          json['commentsDisabled'] == true ||
          json['comments_disabled'] == true,
      createdAt:
          _asDate(json['createdAt'] ?? json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  CommunityPostModel copyWith({
    int? id,
    int? communityId,
    int? authorId,
    String? authorName,
    String? authorAvatar,
    String? authorRole,
    String? content,
    List<String>? mediaUrls,
    int? likesCount,
    int? commentsCount,
    bool? isLikedByMe,
    bool? isSaved,
    bool? commentsDisabled,
    DateTime? createdAt,
  }) {
    return CommunityPostModel(
      id: id ?? this.id,
      communityId: communityId ?? this.communityId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      authorRole: authorRole ?? this.authorRole,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSaved: isSaved ?? this.isSaved,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Community Poll Option
class PollOptionModel {
  final int id;
  final String text;
  final int votesCount;
  final bool isVotedByMe;

  const PollOptionModel({
    required this.id,
    required this.text,
    this.votesCount = 0,
    this.isVotedByMe = false,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    return PollOptionModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      text: json['text']?.toString() ?? json['option_text']?.toString() ?? '',
      votesCount: json['votesCount'] is int
          ? json['votesCount']
          : (json['votes_count'] is int
                ? json['votes_count']
                : int.tryParse(
                        json['votesCount']?.toString() ??
                            json['votes_count']?.toString() ??
                            json['votes']?.toString() ??
                            '0',
                      ) ??
                      0),
      isVotedByMe:
          json['isVotedByMe'] == true ||
          json['is_voted'] == true ||
          json['isVoted'] == true,
    );
  }
}

/// Community Poll Model
class CommunityPollModel {
  final int id;
  final int communityId;
  final String question;
  final String createdByName;
  final String? createdByAvatar;
  final List<PollOptionModel> options;
  final int totalVotes;
  final bool hasVoted;
  final DateTime? endsAt;
  final DateTime createdAt;

  const CommunityPollModel({
    required this.id,
    required this.communityId,
    required this.question,
    required this.createdByName,
    this.createdByAvatar,
    required this.options,
    this.totalVotes = 0,
    this.hasVoted = false,
    this.endsAt,
    required this.createdAt,
  });

  factory CommunityPollModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] is List ? (json['options'] as List) : [];
    final parsedOptions = rawOptions
        .whereType<Map>()
        .map((opt) => PollOptionModel.fromJson(Map<String, dynamic>.from(opt)))
        .toList();

    final rawVotes = json['total_votes'] ?? json['totalVotes'];
    final totalVotes = rawVotes is int
        ? rawVotes
        : int.tryParse(rawVotes?.toString() ?? '0') ??
              parsedOptions.fold<int>(0, (sum, opt) => sum + opt.votesCount);

    final hasVoted =
        json['hasVoted'] == true ||
        json['has_voted'] == true ||
        parsedOptions.any((opt) => opt.isVotedByMe);

    String authorName = 'Admin';
    if (json['creator'] is Map) {
      authorName = json['creator']['userName']?.toString() ?? 'Admin';
    } else if (json['created_by_name'] != null) {
      authorName = json['created_by_name'].toString();
    }

    return CommunityPollModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      communityId: json['community_id'] is int
          ? json['community_id']
          : int.tryParse(json['community_id']?.toString() ?? '0') ?? 0,
      question: json['question']?.toString() ?? json['title']?.toString() ?? '',
      createdByName: authorName,
      createdByAvatar: ApiConfig.normalizeMediaUrl(
        json['created_by_avatar']?.toString(),
      ),
      options: parsedOptions,
      totalVotes: totalVotes,
      hasVoted: hasVoted,
      endsAt: _asDate(
        json['expires_at'] ?? json['expiresAt'] ?? json['ends_at'],
      ),
      createdAt:
          _asDate(json['created_at'] ?? json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Official Community Pinned Announcement Model
class CommunityAnnouncementModel {
  final int id;
  final int communityId;
  final String title;
  final String message;
  final bool isPinned;
  final String createdByName;
  final String? createdByRole;
  final DateTime createdAt;

  const CommunityAnnouncementModel({
    required this.id,
    required this.communityId,
    required this.title,
    required this.message,
    this.isPinned = true,
    required this.createdByName,
    this.createdByRole,
    required this.createdAt,
  });

  factory CommunityAnnouncementModel.fromJson(Map<String, dynamic> json) {
    String authorName = 'Community Admin';
    if (json['author'] is Map) {
      authorName = json['author']['userName']?.toString() ?? 'Community Admin';
    } else if (json['created_by_name'] != null) {
      authorName = json['created_by_name'].toString();
    }

    return CommunityAnnouncementModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      communityId: json['community_id'] is int
          ? json['community_id']
          : int.tryParse(json['community_id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString() ?? 'Official Notice',
      message: json['message']?.toString() ?? json['content']?.toString() ?? '',
      isPinned:
          json['is_pinned'] == true ||
          json['is_pinned'] == 1 ||
          json['isPinned'] == true,
      createdByName: authorName,
      createdByRole: json['created_by_role']?.toString() ?? 'Admin',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Pending Community Join Request Model
class CommunityJoinRequestModel {
  final int id;
  final int communityId;
  final int userId;
  final String fullName;
  final String? userName;
  final String? avatarUrl;
  final String? note;
  final DateTime requestedAt;

  const CommunityJoinRequestModel({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.fullName,
    this.userName,
    this.avatarUrl,
    this.note,
    required this.requestedAt,
  });

  factory CommunityJoinRequestModel.fromJson(Map<String, dynamic> json) {
    final applicantObj = json['applicant'] is Map ? json['applicant'] : null;
    final profileObj = applicantObj != null && applicantObj['profile'] is Map
        ? applicantObj['profile']
        : null;

    final rawFullName =
        profileObj?['fullName'] ??
        applicantObj?['userName'] ??
        json['full_name'] ??
        json['name'] ??
        'Resident';
    final rawUserName =
        applicantObj?['userName'] ?? json['user_name'] ?? json['username'];
    final rawAvatar =
        profileObj?['avatarUrl'] ?? json['avatar_url'] ?? json['avatar'];

    return CommunityJoinRequestModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      communityId: json['community_id'] is int
          ? json['community_id']
          : int.tryParse(json['community_id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(
                  json['user_id']?.toString() ??
                      applicantObj?['userId']?.toString() ??
                      '0',
                ) ??
                0,
      fullName: rawFullName.toString(),
      userName: rawUserName?.toString(),
      avatarUrl: ApiConfig.normalizeMediaUrl(rawAvatar?.toString()),
      note: json['note']?.toString() ?? json['message']?.toString(),
      requestedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Community Files & Documents Model
class CommunityDocumentModel {
  final int id;
  final int communityId;
  final String title;
  final String? fileUrl;
  final String fileType; // pdf, doc, xls, image
  final String? fileSize;
  final String uploadedByName;
  final DateTime uploadedAt;

  const CommunityDocumentModel({
    required this.id,
    required this.communityId,
    required this.title,
    this.fileUrl,
    this.fileType = 'pdf',
    this.fileSize,
    required this.uploadedByName,
    required this.uploadedAt,
  });

  factory CommunityDocumentModel.fromJson(Map<String, dynamic> json) {
    String uploaderName = 'Admin';
    if (json['uploader'] is Map) {
      uploaderName = json['uploader']['userName']?.toString() ?? 'Admin';
    } else if (json['uploaded_by_name'] != null) {
      uploaderName = json['uploaded_by_name'].toString();
    }

    return CommunityDocumentModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      communityId: json['community_id'] is int
          ? json['community_id']
          : int.tryParse(json['community_id']?.toString() ?? '0') ?? 0,
      title:
          json['title']?.toString() ?? json['name']?.toString() ?? 'Document',
      fileUrl: ApiConfig.normalizeMediaUrl(
        json['file_url']?.toString() ??
            json['url']?.toString() ??
            json['fileUrl']?.toString(),
      ),
      fileType:
          json['file_type']?.toString() ??
          json['fileType']?.toString() ??
          json['type']?.toString() ??
          'pdf',
      fileSize: json['file_size']?.toString() ?? json['fileSize']?.toString(),
      uploadedByName: uploaderName,
      uploadedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Community Media Gallery Model
class CommunityMediaModel {
  final int id;
  final int communityId;
  final String mediaUrl;
  final String mediaType; // image, video
  final String? caption;
  final String uploadedByName;
  final DateTime createdAt;

  const CommunityMediaModel({
    required this.id,
    required this.communityId,
    required this.mediaUrl,
    this.mediaType = 'image',
    this.caption,
    required this.uploadedByName,
    required this.createdAt,
  });

  factory CommunityMediaModel.fromJson(Map<String, dynamic> json) {
    String uploaderName = 'Member';
    if (json['uploader'] is Map) {
      uploaderName = json['uploader']['userName']?.toString() ?? 'Member';
    } else if (json['uploaded_by_name'] != null) {
      uploaderName = json['uploaded_by_name'].toString();
    }

    return CommunityMediaModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      communityId: json['community_id'] is int
          ? json['community_id']
          : int.tryParse(json['community_id']?.toString() ?? '0') ?? 0,
      mediaUrl:
          ApiConfig.normalizeMediaUrl(
            json['media_url']?.toString() ??
                json['url']?.toString() ??
                json['mediaUrl']?.toString(),
          ) ??
          '',
      mediaType:
          json['media_type']?.toString() ??
          json['mediaType']?.toString() ??
          json['type']?.toString() ??
          'image',
      caption: json['caption']?.toString() ?? json['title']?.toString(),
      uploadedByName: uploaderName,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _asDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

class CommunityPage<T> {
  const CommunityPage({
    required this.items,
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
  });

  final List<T> items;
  final int total;
  final int page;
  final int totalPages;
  bool get hasMore => page < totalPages;
}

class CommunityFeedPage {
  const CommunityFeedPage({
    required this.posts,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<CommunityPostModel> posts;
  final String? nextCursor;
  final bool hasMore;
}

class CommunityJoinResult {
  const CommunityJoinResult({required this.status});
  final CommunityJoinStatus status;
  bool get isMember => status == CommunityJoinStatus.member;
  bool get isPending => status == CommunityJoinStatus.pending;
}

class CommunityInviteableUser {
  const CommunityInviteableUser({
    required this.userId,
    required this.userName,
    required this.fullName,
    this.avatarUrl,
  });

  final int userId;
  final String userName;
  final String fullName;
  final String? avatarUrl;

  factory CommunityInviteableUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map ? json['profile'] as Map : null;
    return CommunityInviteableUser(
      userId: _asInt(json['userId'] ?? json['id']) ?? 0,
      userName: json['userName']?.toString() ?? '',
      fullName:
          profile?['fullName']?.toString() ??
          json['fullName']?.toString() ??
          json['userName']?.toString() ??
          'Resident',
      avatarUrl: ApiConfig.normalizeMediaUrl(
        profile?['avatarUrl']?.toString() ?? json['avatarUrl']?.toString(),
      ),
    );
  }
}

class CommunityInvitationModel {
  const CommunityInvitationModel({
    required this.id,
    required this.communityId,
    required this.invitedUserId,
    required this.status,
    this.invitedBy,
    this.createdAt,
    this.respondedAt,
    this.community,
    this.inviterName,
  });

  final int id;
  final int communityId;
  final int invitedUserId;
  final int? invitedBy;
  final String status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final CommunityModel? community;
  final String? inviterName;

  factory CommunityInvitationModel.fromJson(Map<String, dynamic> json) {
    final communityJson = json['community'] is Map
        ? Map<String, dynamic>.from(json['community'] as Map)
        : null;
    final inviterJson = json['inviter'] is Map
        ? Map<String, dynamic>.from(json['inviter'] as Map)
        : null;
    return CommunityInvitationModel(
        id: _asInt(json['id']) ?? 0,
        communityId: _asInt(json['community_id'] ?? json['communityId']) ?? 0,
        invitedUserId:
            _asInt(json['invited_user_id'] ?? json['invitedUserId']) ?? 0,
        invitedBy: _asInt(json['invited_by'] ?? json['invitedBy']),
        status: json['status']?.toString() ?? 'pending',
        createdAt: _asDate(json['created_at'] ?? json['createdAt']),
        respondedAt: _asDate(json['responded_at'] ?? json['respondedAt']),
        community: communityJson == null
            ? null
            : CommunityModel.fromJson(communityJson),
        inviterName: inviterJson?['userName']?.toString(),
      );
  }
}

class CommunityEventModel {
  const CommunityEventModel({
    required this.id,
    required this.title,
    required this.date,
    required this.venue,
    this.description,
    this.coverImage,
    this.goingCount = 0,
    this.interestedCount = 0,
    this.myRsvpStatus,
  });

  final int id;
  final String title;
  final String? description;
  final String venue;
  final DateTime date;
  final String? coverImage;
  final int goingCount;
  final int interestedCount;
  final String? myRsvpStatus;

  factory CommunityEventModel.fromJson(Map<String, dynamic> json) =>
      CommunityEventModel(
        id: _asInt(json['id']) ?? 0,
        title: json['title']?.toString() ?? 'Community Event',
        description: json['description']?.toString(),
        venue: (json['venue'] ?? json['location'])?.toString() ?? '',
        date:
            _asDate(json['date'] ?? json['start_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        coverImage: ApiConfig.normalizeMediaUrl(
          (json['coverImage'] ?? json['cover_image'])?.toString(),
        ),
        goingCount: _asInt(json['goingCount']) ?? 0,
        interestedCount: _asInt(json['interestedCount']) ?? 0,
        myRsvpStatus: json['myRsvpStatus']?.toString(),
      );

  CommunityEventModel copyWith({
    int? goingCount,
    int? interestedCount,
    String? myRsvpStatus,
  }) => CommunityEventModel(
    id: id,
    title: title,
    description: description,
    venue: venue,
    date: date,
    coverImage: coverImage,
    goingCount: goingCount ?? this.goingCount,
    interestedCount: interestedCount ?? this.interestedCount,
    myRsvpStatus: myRsvpStatus ?? this.myRsvpStatus,
  );
}
