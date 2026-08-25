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
    return CommunityCategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'General',
      icon: json['icon']?.toString(),
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
  final CommunityRole myRole;
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
    this.myRole = CommunityRole.none,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.rules,
    this.hasUnread = false,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    final rawRole = json['my_role'] ?? json['role'] ?? json['membership_role'];
    final rawIsMember = json['is_member'] ?? json['isJoined'] ?? (rawRole != null && rawRole != 'none');

    List<String>? parsedRules;
    if (json['rules'] is List) {
      parsedRules = (json['rules'] as List).map((e) => e.toString()).toList();
    } else if (json['rules'] is String && (json['rules'] as String).isNotEmpty) {
      parsedRules = (json['rules'] as String).split('\n').where((r) => r.trim().isNotEmpty).toList();
    }

    return CommunityModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Community',
      description: json['description']?.toString(),
      category: json['category_name']?.toString() ?? json['category']?.toString() ?? 'General',
      categoryId: json['category_id'] is int ? json['category_id'] : int.tryParse(json['category_id']?.toString() ?? ''),
      iconUrl: json['icon_url']?.toString() ?? json['icon']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString() ?? json['cover_image']?.toString() ?? json['banner']?.toString(),
      isPrivate: json['is_private'] == true || json['is_private'] == 1 || json['privacy'] == 'private',
      membersCount: json['members_count'] is int ? json['members_count'] : int.tryParse(json['members_count']?.toString() ?? json['members']?.toString() ?? '0') ?? 0,
      postsCount: json['posts_count'] is int ? json['posts_count'] : int.tryParse(json['posts_count']?.toString() ?? '0') ?? 0,
      isMember: rawIsMember == true || rawIsMember == 1,
      myRole: CommunityRole.fromString(rawRole?.toString()),
      createdBy: json['created_by'] is int ? json['created_by'] : int.tryParse(json['created_by']?.toString() ?? ''),
      createdByName: json['created_by_name']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
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
    CommunityRole? myRole,
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
      myRole: myRole ?? this.myRole,
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
    return CommunityMemberModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? json['userId']?.toString() ?? '0') ?? 0,
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? 'Resident',
      userName: json['user_name']?.toString() ?? json['username']?.toString(),
      avatarUrl: json['avatar_url']?.toString() ?? json['avatar']?.toString() ?? json['profile_image']?.toString(),
      role: CommunityRole.fromString(json['role']?.toString()),
      joinedAt: json['joined_at'] != null ? DateTime.tryParse(json['joined_at'].toString()) : null,
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
    required this.createdAt,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    List<String> media = [];
    if (json['media_urls'] is List) {
      media = (json['media_urls'] as List).map((e) => e.toString()).toList();
    } else if (json['media'] is List) {
      media = (json['media'] as List).map((e) => e['media_url']?.toString() ?? e['url']?.toString() ?? '').where((u) => u.isNotEmpty).toList();
    }

    return CommunityPostModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      communityId: json['community_id'] is int ? json['community_id'] : int.tryParse(json['community_id']?.toString() ?? '0') ?? 0,
      authorId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      authorName: json['author_name']?.toString() ?? json['full_name']?.toString() ?? 'Member',
      authorAvatar: json['author_avatar']?.toString() ?? json['avatar_url']?.toString(),
      authorRole: json['author_role']?.toString(),
      content: json['content']?.toString() ?? '',
      mediaUrls: media,
      likesCount: json['likes_count'] is int ? json['likes_count'] : int.tryParse(json['likes_count']?.toString() ?? '0') ?? 0,
      commentsCount: json['comments_count'] is int ? json['comments_count'] : int.tryParse(json['comments_count']?.toString() ?? '0') ?? 0,
      isLikedByMe: json['is_liked'] == true || json['isLiked'] == true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
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
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      text: json['text']?.toString() ?? json['option_text']?.toString() ?? '',
      votesCount: json['votes_count'] is int ? json['votes_count'] : int.tryParse(json['votes_count']?.toString() ?? json['votes']?.toString() ?? '0') ?? 0,
      isVotedByMe: json['is_voted'] == true || json['isVoted'] == true,
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

    final totalVotes = json['total_votes'] is int 
        ? json['total_votes'] 
        : int.tryParse(json['total_votes']?.toString() ?? '0') ?? 
          parsedOptions.fold<int>(0, (sum, opt) => sum + opt.votesCount);

    final hasVoted = json['has_voted'] == true || parsedOptions.any((opt) => opt.isVotedByMe);

    return CommunityPollModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      communityId: json['community_id'] is int ? json['community_id'] : int.tryParse(json['community_id']?.toString() ?? '0') ?? 0,
      question: json['question']?.toString() ?? json['title']?.toString() ?? '',
      createdByName: json['created_by_name']?.toString() ?? 'Admin',
      createdByAvatar: json['created_by_avatar']?.toString(),
      options: parsedOptions,
      totalVotes: totalVotes,
      hasVoted: hasVoted,
      endsAt: json['ends_at'] != null ? DateTime.tryParse(json['ends_at'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
