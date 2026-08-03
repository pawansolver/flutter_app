import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/services/chat_service.dart';

void main() {
  test('message pagination sends JWT and cursor', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({
        'data': {
          'messages': <dynamic>[],
          'nextCursor': 'next',
          'hasMore': true,
        },
      }),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = ChatService.forTesting(
      dio: dio,
      tokenProvider: () async => 'test-token',
    );

    final page = await service.getChatMessagePage(
      12,
      5,
      cursor: 'previous',
      limit: 25,
    );

    expect(page.nextCursor, 'next');
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer test-token',
    );
    expect(adapter.requests.single.queryParameters['cursor'], 'previous');
    expect(adapter.requests.single.queryParameters['limit'], 25);
  });

  test('attachment upload uses attachment multipart field', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({
        'data': {
          'media_url': '/uploads/file.m4a',
          'media_metadata': {'duration_ms': 500},
        },
      }),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = ChatService.forTesting(
      dio: dio,
      tokenProvider: () async => 'test-token',
    );
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}chat-upload-test.m4a',
    );
    await file.writeAsBytes([1, 2, 3]);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    final attachment = await service.uploadAttachment(
      filePath: file.path,
      mimeType: 'audio/mp4',
    );

    final form = adapter.requests.single.data as FormData;
    expect(form.files.single.key, 'attachment');
    expect(form.files.single.value.contentType?.toString(), 'audio/mp4');
    expect(attachment.url, contains('/uploads/file.m4a'));
    expect(attachment.metadata.duration, const Duration(milliseconds: 500));
  });

  test('media retry reuses one idempotency key', () async {
    final adapter = _QueueAdapter([
      _jsonResponse({'message': 'temporary'}, statusCode: 500),
      _jsonResponse({
        'data': {
          'id': 10,
          'chat_id': 3,
          'sender_id': 4,
          'message_type': 'audio',
          'media_url': '/uploads/file.m4a',
          'created_at': '2026-07-30T10:00:00Z',
        },
      }),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = ChatService.forTesting(
      dio: dio,
      tokenProvider: () async => 'test-token',
    );

    final message = await service.sendMediaMessage(
      chatId: 3,
      senderId: 4,
      attachment: const MediaAttachment(
        url: '/uploads/file.m4a',
        metadata: MediaMetadata(duration: Duration(milliseconds: 500)),
      ),
      messageType: 'audio',
      idempotencyKey: 'stable-id',
    );

    expect(message.id, 10);
    expect(adapter.requests, hasLength(2));
    expect(
      adapter.requests.map(
        (request) => (request.data as Map<String, dynamic>)['idempotency_key'],
      ),
      everyElement('stable-id'),
    );
  });

  test('message actions use authenticated enterprise endpoints', () async {
    final messageJson = {
      'data': {
        'id': 10,
        'chat_id': 3,
        'sender_id': 4,
        'message': 'Updated',
        'message_type': 'text',
        'created_at': '2026-07-30T10:00:00Z',
      },
    };
    final adapter = _QueueAdapter([
      _jsonResponse(messageJson),
      _jsonResponse(messageJson, statusCode: 201),
      _jsonResponse({
        'data': {'is_pinned': true},
      }),
    ]);
    final dio = Dio()..httpClientAdapter = adapter;
    final service = ChatService.forTesting(
      dio: dio,
      tokenProvider: () async => 'test-token',
    );

    await service.editMessage(messageId: 10, userId: 4, message: 'Updated');
    await service.forwardMessage(messageId: 10, targetChatId: 8, senderId: 4);
    await service.setMessagePinned(messageId: 10, userId: 4, isPinned: true);

    expect(adapter.requests.map((request) => request.method), [
      'PUT',
      'POST',
      'PUT',
    ]);
    expect(
      (adapter.requests[0].data as Map<String, dynamic>)['message'],
      'Updated',
    );
    expect(
      (adapter.requests[1].data as Map<String, dynamic>)['targetChatId'],
      8,
    );
    expect(
      (adapter.requests[2].data as Map<String, dynamic>)['is_pinned'],
      isTrue,
    );
    expect(
      adapter.requests,
      everyElement(
        isA<RequestOptions>().having(
          (request) => request.headers['Authorization'],
          'Authorization',
          'Bearer test-token',
        ),
      ),
    );
  });
}

ResponseBody _jsonResponse(Map<String, dynamic> json, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(json),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this._responses);

  final List<ResponseBody> _responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    return _responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}
