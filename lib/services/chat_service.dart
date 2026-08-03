import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/api_config.dart';
import '../models/chat_models.dart';
import 'authenticated_dio.dart';

export '../models/chat_models.dart';

typedef AccessTokenProvider = Future<String?> Function();
typedef UploadProgressCallback = void Function(int sent, int total);

class ChatServiceException implements Exception {
  const ChatServiceException(
    this.message, {
    this.statusCode,
    this.isCancelled = false,
  });

  final String message;
  final int? statusCode;
  final bool isCancelled;

  @override
  String toString() => message;
}

/// REST foundation for authenticated chat, message, and attachment operations.
class ChatService {
  factory ChatService() => _instance;

  ChatService._internal()
    : _dio = AuthenticatedDio().dio,
      _tokenProvider = _readStoredToken,
      _uuid = const Uuid();

  /// Allows focused tests and alternate authenticated clients without changing
  /// the app-wide singleton used by existing screens.
  factory ChatService.forTesting({
    required Dio dio,
    required AccessTokenProvider tokenProvider,
    Uuid uuid = const Uuid(),
  }) => ChatService._(dio, tokenProvider, uuid);

  ChatService._(this._dio, this._tokenProvider, this._uuid);

  static final ChatService _instance = ChatService._internal();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  final Dio _dio;
  final AccessTokenProvider _tokenProvider;
  final Uuid _uuid;

  static Future<String?> _readStoredToken() => _storage.read(key: 'jwt_token');

  Future<Options> _authOptions({String? contentType}) async {
    final token = await _tokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const ChatServiceException('Authentication is required.');
    }
    return Options(
      contentType: contentType,
      headers: {'Authorization': 'Bearer ${token.trim()}'},
    );
  }

  Future<List<ChatModel>> getMyChats(int userId) async {
    try {
      final response = await _dio.get(
        ApiConfig.myChats,
        queryParameters: {'userId': userId},
        options: await _authOptions(),
      );
      dynamic payload = response.data;
      if (payload is Map) payload = payload['data'] ?? payload;
      final values = payload is List ? payload : const <dynamic>[];
      return values
          .whereType<Map>()
          .map((value) => ChatModel.fromJson(Map<String, dynamic>.from(value)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapDioException(error, 'Failed to load chats');
    }
  }

  /// Opens a direct chat using either a backend user ID or phone number.
  ///
  /// [targetUserId] remains available for existing callers. New callers can
  /// pass a typed [recipient] to avoid ambiguous string parsing.
  Future<ChatModel> getOrCreateOneToOneChat({
    required int userId,
    int? targetUserId,
    ChatRecipient? recipient,
  }) async {
    final resolvedRecipient =
        recipient ??
        (targetUserId == null ? null : ChatRecipient.userId(targetUserId));
    if (resolvedRecipient == null) {
      throw const ChatServiceException(
        'A recipient user ID or phone number is required.',
      );
    }

    try {
      final response = await _dio.post(
        ApiConfig.createOneToOneChat,
        data: {
          'userId': userId,
          ...resolvedRecipient.toRequestJson(),
          'created_by': userId,
        },
        options: await _authOptions(),
      );
      return ChatModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error, 'Failed to open chat');
    }
  }

  Future<MessagePage> getChatMessagePage(
    int chatId,
    int userId, {
    String? cursor,
    int limit = 50,
    CancelToken? cancelToken,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError('Message page limit must be from 1 to 100.');
    }
    try {
      final response = await _dio.get(
        ApiConfig.chatMessages(chatId),
        queryParameters: {
          'userId': userId,
          'limit': limit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
        options: await _authOptions(),
        cancelToken: cancelToken,
      );
      return MessagePage.fromJson(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error, 'Failed to load messages');
    }
  }

  /// Backward-compatible first/page message loader.
  Future<List<MessageModel>> getChatMessages(
    int chatId,
    int userId, {
    String? cursor,
  }) async {
    final page = await getChatMessagePage(chatId, userId, cursor: cursor);
    return page.messages;
  }

  Future<MediaAttachment> uploadAttachment({
    required String filePath,
    String? fileName,
    String? mimeType,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final contentType = mimeType == null || mimeType.trim().isEmpty
        ? null
        : DioMediaType.parse(mimeType.trim());
    late final MultipartFile attachment;
    if (kIsWeb) {
      try {
        final webFile = XFile(filePath);
        final bytes = await webFile.readAsBytes();
        if (bytes.isEmpty) {
          throw const ChatServiceException('Attachment is empty.');
        }
        attachment = MultipartFile.fromBytes(
          bytes,
          filename: fileName ?? webFile.name,
          contentType: contentType,
        );
      } catch (error) {
        if (error is ChatServiceException) rethrow;
        throw ChatServiceException('Unable to read attachment: $error');
      }
    } else {
      final file = File(filePath);
      if (!await file.exists()) {
        throw ChatServiceException('Attachment does not exist: $filePath');
      }
      attachment = await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: contentType,
      );
    }

    try {
      final formData = FormData.fromMap({'attachment': attachment});
      final response = await _dio.post(
        ApiConfig.uploadAttachment,
        data: formData,
        options: await _authOptions(
          contentType: Headers.multipartFormDataContentType,
        ),
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      );
      return MediaAttachment.fromJson(_unwrapObject(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error, 'Failed to upload attachment');
    } on FormatException catch (error) {
      throw ChatServiceException(error.message);
    }
  }

  Future<MessageModel> sendMessage({
    required int chatId,
    required int senderId,
    required String message,
    String messageType = 'text',
    String? mediaUrl,
    MediaMetadata? mediaMetadata,
    int? replyTo,
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.sendMessage,
        data: {
          'chat_id': chatId,
          'sender_id': senderId,
          'message': message,
          'message_type': messageType,
          'media_url': mediaUrl,
          'media_metadata': mediaMetadata?.toJson(),
          'reply_to': replyTo,
          'idempotency_key': idempotencyKey,
        },
        options: await _authOptions(),
        cancelToken: cancelToken,
      );
      return MessageModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error, 'Failed to send message');
    }
  }

  /// Sends already uploaded media with one stable key across transient retries.
  ///
  /// Uploading is intentionally separate: retries never duplicate file uploads.
  Future<MessageModel> sendMediaMessage({
    required int chatId,
    required int senderId,
    required MediaAttachment attachment,
    required String messageType,
    String message = '',
    int? replyTo,
    String? idempotencyKey,
    int maxAttempts = 2,
    CancelToken? cancelToken,
  }) async {
    if (maxAttempts < 1) {
      throw ArgumentError('maxAttempts must be at least 1.');
    }
    final stableId = idempotencyKey ?? _uuid.v4();

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await sendMessage(
          chatId: chatId,
          senderId: senderId,
          message: message,
          messageType: messageType,
          mediaUrl: attachment.url,
          mediaMetadata: attachment.metadata,
          replyTo: replyTo,
          idempotencyKey: stableId,
          cancelToken: cancelToken,
        );
      } on ChatServiceException catch (error) {
        final shouldRetry =
            !error.isCancelled &&
            attempt < maxAttempts &&
            _isTransientStatus(error.statusCode);
        if (!shouldRetry) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
    }
    throw const ChatServiceException('Failed to send media message.');
  }

  Future<void> markAllRead(int chatId, int userId) async {
    try {
      await _dio.post(
        ApiConfig.markAllRead,
        data: {'chatId': chatId, 'userId': userId},
        options: await _authOptions(),
      );
    } on DioException {
      // Read receipts are best effort and must not interrupt the conversation.
    }
  }

  Future<MessageModel> editMessage({
    required int messageId,
    required int userId,
    required String message,
  }) async {
    final text = message.trim();
    if (text.isEmpty) {
      throw const ChatServiceException('Message cannot be empty.');
    }
    try {
      final response = await _dio.put(
        ApiConfig.editMessage(messageId),
        data: {'userId': userId, 'message': text},
        options: await _authOptions(),
      );
      return MessageModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error, 'Failed to edit message');
    }
  }

  Future<MessageModel> forwardMessage({
    required int messageId,
    required int targetChatId,
    required int senderId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.forwardMessage(messageId),
        data: {
          'targetChatId': targetChatId,
          'senderId': senderId,
          'created_by': senderId,
        },
        options: await _authOptions(),
      );
      return MessageModel.fromJson(_unwrapObject(response.data));
    } on DioException catch (error) {
      throw _mapDioException(error, 'Failed to forward message');
    }
  }

  Future<void> setMessagePinned({
    required int messageId,
    required int userId,
    required bool isPinned,
  }) async {
    try {
      await _dio.put(
        ApiConfig.pinMessage(messageId),
        data: {'userId': userId, 'is_pinned': isPinned},
        options: await _authOptions(),
      );
    } on DioException catch (error) {
      throw _mapDioException(error, 'Failed to update message pin');
    }
  }

  Future<List<MessageModel>> getPinnedMessages(int chatId, int userId) async {
    try {
      final response = await _dio.get(
        ApiConfig.pinnedMessages(chatId),
        queryParameters: {'userId': userId},
        options: await _authOptions(),
      );
      dynamic payload = response.data;
      if (payload is Map) payload = payload['data'] ?? payload;
      if (payload is! List) return const [];
      return payload
          .whereType<Map>()
          .map(
            (value) => MessageModel.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw _mapDioException(error, 'Failed to load pinned messages');
    }
  }

  /// Delete for me (WhatsApp "Delete for me" — hidden only for current user)
  Future<void> deleteMessageForMe(int messageId) async {
    try {
      await _dio.delete(
        ApiConfig.deleteForMe(messageId),
        options: await _authOptions(),
      );
    } on DioException catch (e) {
      throw _mapDioException(e, "Failed to delete message");
    }
  }

  /// Delete for everyone (WhatsApp "Delete for everyone" — sender only, 24h window)
  Future<void> deleteMessageForEveryone(int messageId) async {
    try {
      await _dio.delete(
        ApiConfig.deleteForEveryone(messageId),
        options: await _authOptions(),
      );
    } on DioException catch (e) {
      throw _mapDioException(e, "Failed to delete message for everyone");
    }
  }

  Future<void> reactToMessage({
    required int messageId,
    required int userId,
    required String emoji,
  }) async {
    try {
      await _dio.put(
        ApiConfig.reactToMessage(messageId),
        data: {'userId': userId, 'emoji': emoji},
        options: await _authOptions(),
      );
    } on DioException catch (error) {
      throw _mapDioException(error, 'Reaction failed');
    }
  }

  Future<void> deleteForMe(int messageId, int userId) async {
    try {
      await _dio.delete(
        ApiConfig.deleteForMe(messageId),
        data: {'userId': userId},
        options: await _authOptions(),
      );
    } on DioException catch (error) {
      throw _mapDioException(error, 'Delete failed');
    }
  }

  static Map<String, dynamic> _unwrapObject(dynamic responseData) {
    dynamic value = responseData;
    if (value is Map && value['data'] != null) value = value['data'];
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const ChatServiceException('Unexpected server response format.');
  }

  static bool _isTransientStatus(int? statusCode) =>
      statusCode == null ||
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode >= 500;

  static ChatServiceException _mapDioException(
    DioException error,
    String fallback,
  ) {
    if (CancelToken.isCancel(error)) {
      return const ChatServiceException(
        'Request cancelled.',
        isCancelled: true,
      );
    }
    final data = error.response?.data;
    String? serverMessage;
    if (data is Map) serverMessage = data['message']?.toString();
    return ChatServiceException(
      serverMessage?.trim().isNotEmpty == true ? serverMessage! : fallback,
      statusCode: error.response?.statusCode,
    );
  }
}
