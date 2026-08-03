import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/chat_models.dart';

void main() {
  group('ChatRecipient', () {
    test('parses and normalizes phone numbers', () {
      final recipient = ChatRecipient.parse('+91 (98765) 43210');

      expect(recipient.userId, isNull);
      expect(recipient.phoneNumber, '+919876543210');
      expect(recipient.toRequestJson(), {'phoneNumber': '+919876543210'});
    });

    test('supports explicit numeric user IDs', () {
      final recipient = ChatRecipient.parse('42', preferUserId: true);

      expect(recipient.userId, 42);
      expect(recipient.toRequestJson(), {'targetUserId': 42});
    });

    test('rejects phone numbers outside dialable length limits', () {
      expect(
        () => ChatRecipient.phone('12345'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ChatRecipient.phone('1234567890123456'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('MessagePage retains cursor metadata and typed media metadata', () {
    final page = MessagePage.fromJson({
      'success': true,
      'data': {
        'messages': [
          {
            'id': '7',
            'chat_id': 3,
            'sender_id': 9,
            'message_type': 'audio',
            'media_url': '/uploads/voice.m4a',
            'media_metadata': {
              'duration_ms': 1250,
              'mime_type': 'audio/mp4',
              'size_bytes': 100,
            },
            'created_at': '2026-07-30T10:00:00Z',
          },
        ],
        'nextCursor': 'cursor-2',
        'hasMore': true,
      },
    });

    expect(page.nextCursor, 'cursor-2');
    expect(page.hasMore, isTrue);
    expect(page.messages.single.id, 7);
    expect(
      page.messages.single.mediaMetadata?.duration,
      const Duration(milliseconds: 1250),
    );
    expect(page.messages.single.mediaUrl, contains('/uploads/voice.m4a'));
  });

  test('optimistic messages reconcile only with the same stable key', () {
    final optimistic = MessageModel(
      id: -1,
      chatId: 4,
      senderId: 8,
      message: '',
      messageType: 'audio',
      isForwarded: false,
      isEdited: false,
      createdAt: DateTime(2026),
      idempotencyKey: 'stable-key',
    );
    final confirmed = MessageModel(
      id: 99,
      chatId: 4,
      senderId: 8,
      message: '',
      messageType: 'audio',
      isForwarded: false,
      isEdited: false,
      createdAt: DateTime(2026),
      idempotencyKey: 'stable-key',
    );

    expect(optimistic.canReconcileWith(confirmed), isTrue);
  });

  test('optimistic messages do not reconcile across stable keys', () {
    final first = MessageModel(
      id: -1,
      chatId: 4,
      senderId: 8,
      message: 'hello',
      messageType: 'text',
      isForwarded: false,
      isEdited: false,
      createdAt: DateTime(2026),
      idempotencyKey: 'first-key',
    );
    final second = MessageModel(
      id: 99,
      chatId: 4,
      senderId: 8,
      message: 'hello',
      messageType: 'text',
      isForwarded: false,
      isEdited: false,
      createdAt: DateTime(2026),
      idempotencyKey: 'second-key',
    );

    expect(first.canReconcileWith(second), isFalse);
  });

  test('chat and attachment models accept backend legacy aliases', () {
    final chat = ChatModel.fromJson({
      'id': 4,
      'chat_type': 'one_to_one',
      'other_user': {'userId': 8, 'phone': '+919876543210'},
    });
    final attachment = MediaAttachment.fromJson({
      'media_url': '/uploads/file.pdf',
      'media_metadata': {
        'original_name': 'notice.pdf',
        'file_size': 1200,
        'mime_type': 'application/pdf',
      },
    });

    expect(chat.otherUserPhone, '+919876543210');
    expect(attachment.metadata.fileName, 'notice.pdf');
    expect(attachment.metadata.sizeBytes, 1200);
  });

  test('message model parses pinned and replied message payloads', () {
    final message = MessageModel.fromJson({
      'id': 12,
      'chat_id': 3,
      'sender_id': 4,
      'message': 'Reply',
      'message_type': 'text',
      'reply_to': 11,
      'is_pinned': true,
      'repliedMessage': {
        'id': 11,
        'chat_id': 3,
        'sender_id': 8,
        'message': 'Original',
        'message_type': 'text',
      },
      'created_at': '2026-07-30T10:00:00Z',
    });

    expect(message.isPinned, isTrue);
    expect(message.replyTo, 11);
    expect(message.replyToMessage?.message, 'Original');
  });
}
