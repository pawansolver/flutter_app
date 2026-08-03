import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_config.dart';

typedef MessageCallback = void Function(Map<String, dynamic> message);
typedef MessageEventCallback = void Function(Map<String, dynamic> event);
typedef TypingCallback = void Function(int chatId, int userId, bool isTyping);
typedef PresenceCallback = void Function(int userId, bool isOnline);

/// SocketService — Singleton managing the Socket.IO connection
/// Handles: online presence, typing indicators, real-time messages
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  int? _currentUserId;

  // Registered listeners
  final List<MessageCallback> _messageListeners = [];
  final List<MessageEventCallback> _messageEditedListeners = [];
  final List<MessageEventCallback> _messageDeletedListeners = [];
  final List<MessageEventCallback> _messagePinnedListeners = [];
  final List<TypingCallback> _typingListeners = [];
  final List<PresenceCallback> _presenceListeners = [];
  final Set<int> _joinedChatIds = {};

  bool get isConnected => _isConnected;

  /// Initialize and connect socket (call once after login)
  Future<void> connect(int userId) async {
    if (_socket != null) return;
    _currentUserId = userId;

    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token ?? ''})
          .setExtraHeaders({'Authorization': 'Bearer ${token ?? ''}'})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      // Announce presence
      _socket!.emit('user:online', {'userId': userId});
      for (final chatId in _joinedChatIds) {
        _socket!.emit('user:join:chat', {'chatId': chatId});
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      // Silently handle — app works in degraded mode without socket
    });

    // ── Real-time message received ───────────────────────────────
    _socket!.on('chat:message', (data) {
      if (data is Map) {
        final event = Map<String, dynamic>.from(data);
        for (final cb in _messageListeners) {
          cb(event);
        }
      }
    });

    _socket!.on('message:edited', (data) {
      _dispatchMessageEvent(data, _messageEditedListeners);
    });
    _socket!.on('message:deleted', (data) {
      _dispatchMessageEvent(data, _messageDeletedListeners);
    });
    _socket!.on('message:pinned', (data) {
      _dispatchMessageEvent(data, _messagePinnedListeners);
    });

    // ── Typing indicator ─────────────────────────────────────────
    _socket!.on('chat:typing', (data) {
      if (data is Map<String, dynamic>) {
        final chatId = int.tryParse(data['chatId'].toString()) ?? 0;
        final userId = int.tryParse(data['userId'].toString()) ?? 0;
        final isTyping = data['isTyping'] == true;
        for (final cb in _typingListeners) {
          cb(chatId, userId, isTyping);
        }
      }
    });

    // ── Presence events ──────────────────────────────────────────
    _socket!.on('presence:online', (data) {
      if (data is Map<String, dynamic>) {
        final uid = int.tryParse(data['userId'].toString()) ?? 0;
        for (final cb in _presenceListeners) {
          cb(uid, true);
        }
      }
    });

    _socket!.on('presence:offline', (data) {
      if (data is Map<String, dynamic>) {
        final uid = int.tryParse(data['userId'].toString()) ?? 0;
        for (final cb in _presenceListeners) {
          cb(uid, false);
        }
      }
    });

    _socket!.connect();
  }

  /// Join a chat room to receive its messages
  void joinChat(int chatId) {
    _joinedChatIds.add(chatId);
    if (_isConnected) {
      _socket?.emit('user:join:chat', {'chatId': chatId});
    }
  }

  /// Leave a chat room
  void leaveChat(int chatId) {
    _joinedChatIds.remove(chatId);
    if (_isConnected) {
      _socket?.emit('user:leave:chat', {'chatId': chatId});
    }
  }

  /// Emit typing status
  void emitTyping(int chatId, bool isTyping) {
    _socket?.emit('chat:typing', {'chatId': chatId, 'isTyping': isTyping});
  }

  // ── Listener management ────────────────────────────────────────

  void addMessageListener(MessageCallback cb) {
    if (!_messageListeners.contains(cb)) _messageListeners.add(cb);
  }

  void removeMessageListener(MessageCallback cb) {
    _messageListeners.remove(cb);
  }

  void addMessageEditedListener(MessageEventCallback cb) {
    if (!_messageEditedListeners.contains(cb)) {
      _messageEditedListeners.add(cb);
    }
  }

  void removeMessageEditedListener(MessageEventCallback cb) {
    _messageEditedListeners.remove(cb);
  }

  void addMessageDeletedListener(MessageEventCallback cb) {
    if (!_messageDeletedListeners.contains(cb)) {
      _messageDeletedListeners.add(cb);
    }
  }

  void removeMessageDeletedListener(MessageEventCallback cb) {
    _messageDeletedListeners.remove(cb);
  }

  void addMessagePinnedListener(MessageEventCallback cb) {
    if (!_messagePinnedListeners.contains(cb)) {
      _messagePinnedListeners.add(cb);
    }
  }

  void removeMessagePinnedListener(MessageEventCallback cb) {
    _messagePinnedListeners.remove(cb);
  }

  void addTypingListener(TypingCallback cb) {
    if (!_typingListeners.contains(cb)) _typingListeners.add(cb);
  }

  void removeTypingListener(TypingCallback cb) {
    _typingListeners.remove(cb);
  }

  void addPresenceListener(PresenceCallback cb) {
    if (!_presenceListeners.contains(cb)) _presenceListeners.add(cb);
  }

  void removePresenceListener(PresenceCallback cb) {
    _presenceListeners.remove(cb);
  }

  /// Cleanly disconnect socket
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _messageListeners.clear();
    _messageEditedListeners.clear();
    _messageDeletedListeners.clear();
    _messagePinnedListeners.clear();
    _typingListeners.clear();
    _presenceListeners.clear();
    _joinedChatIds.clear();
    _currentUserId = null;
  }

  /// Rebuilds an existing connection with the latest stored access token while
  /// preserving screen listeners and joined rooms.
  Future<void> reconnectWithLatestToken() async {
    final userId = _currentUserId;
    if (userId == null) return;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    await connect(userId);
  }

  void _dispatchMessageEvent(
    dynamic data,
    List<MessageEventCallback> listeners,
  ) {
    if (data is! Map) return;
    final event = Map<String, dynamic>.from(data);
    for (final callback in List<MessageEventCallback>.of(listeners)) {
      callback(event);
    }
  }
}
