import '../core/api_config.dart';

int _safeInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String? _safeString(dynamic value) {
  if (value == null) return null;
  return value is String ? value : value.toString();
}

/// A recipient accepted by the one-to-one chat API.
///
/// Numeric IDs and phone numbers are deliberately represented separately so a
/// caller never has to guess which backend field a value belongs in.
class ChatRecipient {
  const ChatRecipient._({this.userId, this.phoneNumber});

  factory ChatRecipient.userId(int userId) {
    if (userId <= 0) {
      throw const FormatException('Recipient user ID must be positive.');
    }
    return ChatRecipient._(userId: userId);
  }

  factory ChatRecipient.phone(String phoneNumber) {
    return ChatRecipient._(phoneNumber: normalizePhone(phoneNumber));
  }

  factory ChatRecipient.parse(String value, {bool preferUserId = false}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Recipient cannot be empty.');
    }

    final id = int.tryParse(trimmed);
    if (preferUserId && id != null) return ChatRecipient.userId(id);

    final looksLikePhone =
        trimmed.startsWith('+') ||
        trimmed.contains(RegExp(r'[\s()-]')) ||
        RegExp(r'^\d{7,15}$').hasMatch(trimmed);
    if (looksLikePhone) return ChatRecipient.phone(trimmed);
    if (id != null) return ChatRecipient.userId(id);

    throw const FormatException(
      'Recipient must be a user ID or a valid phone number.',
    );
  }

  final int? userId;
  final String? phoneNumber;

  static String normalizePhone(String value) {
    final trimmed = value.trim();
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      throw const FormatException('Phone number must contain 7 to 15 digits.');
    }
    return '${hasPlus ? '+' : ''}$digits';
  }

  Map<String, dynamic> toRequestJson() {
    if (userId != null) return {'targetUserId': userId};
    return {'phoneNumber': phoneNumber};
  }
}

class ChatModel {
  const ChatModel({
    required this.id,
    required this.chatType,
    this.name,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
    required this.isOnline,
    this.otherUserName,
    this.otherUserId,
    this.otherUserPhone,
  });

  final int id;
  final String chatType;
  final String? name;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isOnline;
  final String? otherUserName;
  final int? otherUserId;
  final String? otherUserPhone;

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    String? lastMessage;
    final lastMessageJson = json['last_message'];
    if (lastMessageJson is Map) {
      final type = _safeString(lastMessageJson['message_type']) ?? 'text';
      lastMessage = switch (type) {
        'image' => '📷 Photo',
        'video' => '🎥 Video',
        'audio' => '🎵 Audio',
        'document' => '📄 Document',
        _ => _safeString(lastMessageJson['message']),
      };
    } else {
      lastMessage = _safeString(lastMessageJson);
    }

    final otherUser = json['other_user'];
    final otherUserMap = otherUser is Map
        ? Map<String, dynamic>.from(otherUser)
        : const <String, dynamic>{};
    final profile = otherUserMap['profile'];
    final profileMap = profile is Map
        ? Map<String, dynamic>.from(profile)
        : const <String, dynamic>{};

    return ChatModel(
      id: _safeInt(json['id']),
      chatType: _safeString(json['chat_type']) ?? 'one_to_one',
      name: _safeString(json['name']),
      avatarUrl: ApiConfig.normalizeMediaUrl(
        _safeString(json['avatar_url']) ??
            _safeString(profileMap['avatarUrl']) ??
            _safeString(profileMap['avatar_url']),
      ),
      lastMessage: lastMessage,
      lastMessageAt: DateTime.tryParse(
        _safeString(json['last_message_at']) ?? '',
      ),
      unreadCount: _safeInt(json['unread_count']),
      isOnline:
          profileMap['is_online'] == true || otherUserMap['is_online'] == true,
      otherUserName:
          _safeString(profileMap['fullName']) ??
          _safeString(profileMap['full_name']) ??
          _safeString(otherUserMap['userName']) ??
          _safeString(otherUserMap['user_name']) ??
          _safeString(json['other_user_name']),
      otherUserId: _nullableInt(
        otherUserMap['userId'] ??
            otherUserMap['user_id'] ??
            otherUserMap['id'] ??
            json['other_user_id'],
      ),
      otherUserPhone: _safeString(
        otherUserMap['phoneNumber'] ??
            otherUserMap['phone_number'] ??
            otherUserMap['phone'] ??
            profileMap['phoneNumber'] ??
            json['other_user_phone'],
      ),
    );
  }

  String get displayName {
    if (chatType == 'one_to_one') return otherUserName ?? 'Unknown User';
    return name ?? 'Group Chat';
  }

  String get avatarInitial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  String get formattedTime {
    if (lastMessageAt == null) return '';
    final difference = DateTime.now().difference(lastMessageAt!);
    if (difference.inDays == 0) {
      final hour = lastMessageAt!.hour.toString().padLeft(2, '0');
      final minute = lastMessageAt!.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (difference.inDays == 1) return 'Yesterday';
    return '${lastMessageAt!.day}/${lastMessageAt!.month}';
  }
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  final result = _safeInt(value);
  return result == 0 ? null : result;
}

class MediaMetadata {
  const MediaMetadata({
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.duration,
    this.waveform,
    this.extra = const {},
  });

  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final Duration? duration;
  final List<double>? waveform;
  final Map<String, dynamic> extra;

  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    final knownKeys = {
      'file_name',
      'fileName',
      'mime_type',
      'mimeType',
      'size',
      'size_bytes',
      'file_size',
      'original_name',
      'width',
      'height',
      'duration',
      'duration_ms',
      'waveform',
    };
    final waveformJson = json['waveform'];
    return MediaMetadata(
      fileName: _safeString(
        json['file_name'] ?? json['fileName'] ?? json['original_name'],
      ),
      mimeType: _safeString(json['mime_type'] ?? json['mimeType']),
      sizeBytes: _nullableInt(
        json['size_bytes'] ?? json['size'] ?? json['file_size'],
      ),
      width: _nullableInt(json['width']),
      height: _nullableInt(json['height']),
      duration: _parseDuration(json),
      waveform: waveformJson is List
          ? waveformJson
                .whereType<num>()
                .map((value) => value.toDouble())
                .toList(growable: false)
          : null,
      extra: Map<String, dynamic>.from(json)
        ..removeWhere((key, _) => knownKeys.contains(key)),
    );
  }

  Map<String, dynamic> toJson() => {
    if (fileName != null) 'file_name': fileName,
    if (mimeType != null) 'mime_type': mimeType,
    if (sizeBytes != null) 'size_bytes': sizeBytes,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (duration != null) 'duration_ms': duration!.inMilliseconds,
    if (waveform != null) 'waveform': waveform,
    ...extra,
  };

  static Duration? _parseDuration(Map<String, dynamic> json) {
    final milliseconds = _nullableInt(json['duration_ms']);
    if (milliseconds != null) return Duration(milliseconds: milliseconds);

    final raw = json['duration'];
    if (raw is num) {
      return Duration(milliseconds: (raw * 1000).round());
    }
    final seconds = double.tryParse(raw?.toString() ?? '');
    return seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
  }
}

class MediaAttachment {
  const MediaAttachment({required this.url, required this.metadata, this.type});

  final String url;
  final MediaMetadata metadata;
  final String? type;

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    final nested = json['attachment'];
    final source = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(json);
    final rawUrl = _safeString(
      source['url'] ?? source['media_url'] ?? source['path'],
    );
    final url = ApiConfig.normalizeMediaUrl(rawUrl);
    if (url == null) {
      throw const FormatException(
        'Upload response did not contain a media URL.',
      );
    }
    final metadataJson = source['media_metadata'] ?? source['metadata'];
    return MediaAttachment(
      url: url,
      type: _safeString(source['message_type'] ?? source['type']),
      metadata: metadataJson is Map
          ? MediaMetadata.fromJson(Map<String, dynamic>.from(metadataJson))
          : MediaMetadata.fromJson(source),
    );
  }
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.message,
    required this.messageType,
    this.mediaUrl,
    this.mediaMetadata,
    this.replyTo,
    this.replyToMessage,
    required this.isForwarded,
    required this.isEdited,
    this.isPinned = false,
    this.isDelivered = false,
    this.isRead = false,
    required this.createdAt,
    this.reactions,
    this.idempotencyKey,
  });

  final int id;
  final int chatId;
  final int senderId;
  final String? message;
  final String messageType;
  final String? mediaUrl;
  final MediaMetadata? mediaMetadata;
  final int? replyTo;
  final MessageModel? replyToMessage; // nested quoted message for reply preview
  final bool isForwarded;
  final bool isEdited;
  final bool isPinned;
  final bool isDelivered;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? reactions;
  final String? idempotencyKey;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final metadata = json['media_metadata'] ?? json['mediaMetadata'];
    final reactionsJson = json['reactionsSummary'] ?? json['reactions'];
    final replyJson =
        json['repliedMessage'] ??
        json['replyToMessage'] ??
        json['reply_to_message'];
    return MessageModel(
      id: _safeInt(json['id']),
      chatId: _safeInt(json['chat_id'] ?? json['chatId']),
      senderId: _safeInt(json['sender_id'] ?? json['senderId']),
      message: _safeString(json['message']),
      messageType:
          _safeString(json['message_type'] ?? json['messageType']) ?? 'text',
      mediaUrl: ApiConfig.normalizeMediaUrl(
        _safeString(json['media_url'] ?? json['mediaUrl']),
      ),
      mediaMetadata: metadata is Map
          ? MediaMetadata.fromJson(Map<String, dynamic>.from(metadata))
          : null,
      replyTo: _nullableInt(json['reply_to'] ?? json['replyTo']),
      replyToMessage: replyJson is Map
          ? MessageModel.fromJson(Map<String, dynamic>.from(replyJson))
          : null,
      isForwarded: json['is_forwarded'] == true || json['isForwarded'] == true,
      isEdited: json['is_edited'] == true || json['isEdited'] == true,
      isPinned: json['is_pinned'] == true || json['isPinned'] == true,
      isDelivered:
          json['is_delivered'] == true ||
          json['isDelivered'] == true ||
          json['delivered_at'] != null ||
          json['deliveredAt'] != null ||
          json['receiptStatus'] == 'delivered' ||
          json['receiptStatus'] == 'read',
      isRead:
          json['is_read'] == true ||
          json['isRead'] == true ||
          json['read_at'] != null ||
          json['readAt'] != null ||
          json['receiptStatus'] == 'read',
      createdAt:
          DateTime.tryParse(
            _safeString(json['created_at'] ?? json['createdAt']) ?? '',
          ) ??
          DateTime.now(),
      reactions: reactionsJson is Map
          ? Map<String, dynamic>.from(reactionsJson)
          : null,
      idempotencyKey: _safeString(
        json['idempotency_key'] ?? json['idempotencyKey'],
      ),
    );
  }

  String get formattedTime {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  MessageModel copyWith({
    String? message,
    bool clearMessage = false,
    String? messageType,
    bool? isEdited,
    bool? isPinned,
    bool? isDelivered,
    bool? isRead,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      message: clearMessage ? null : (message ?? this.message),
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl,
      mediaMetadata: mediaMetadata,
      replyTo: replyTo,
      replyToMessage: replyToMessage,
      isForwarded: isForwarded,
      isEdited: isEdited ?? this.isEdited,
      isPinned: isPinned ?? this.isPinned,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      reactions: reactions,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Matches an optimistic message to its REST or socket confirmation.
  bool canReconcileWith(MessageModel other) {
    if (id > 0 && other.id > 0) return id == other.id;
    if (chatId != other.chatId || senderId != other.senderId) return false;
    final thisKey = idempotencyKey;
    final otherKey = other.idempotencyKey;
    return thisKey != null && thisKey == otherKey;
  }
}

class MessagePage {
  const MessagePage({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  final List<MessageModel> messages;
  final String? nextCursor;
  final bool hasMore;

  factory MessagePage.fromJson(dynamic json) {
    dynamic value = json;
    if (value is Map && value['data'] != null) value = value['data'];

    if (value is List) {
      return MessagePage(messages: _parseMessages(value), hasMore: false);
    }
    if (value is! Map) {
      return const MessagePage(messages: [], hasMore: false);
    }

    final messages = value['messages'];
    return MessagePage(
      messages: messages is List ? _parseMessages(messages) : const [],
      nextCursor: _safeString(value['nextCursor'] ?? value['next_cursor']),
      hasMore: value['hasMore'] == true || value['has_more'] == true,
    );
  }

  static List<MessageModel> _parseMessages(List<dynamic> values) => values
      .whereType<Map>()
      .map((value) => MessageModel.fromJson(Map<String, dynamic>.from(value)))
      .toList(growable: false);
}
