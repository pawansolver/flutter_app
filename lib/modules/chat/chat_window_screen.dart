import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../services/chat_service.dart';
import '../../services/single_audio_player_service.dart';
import '../../services/socket_service.dart';
import '../../services/voice_recorder_service.dart';
import '../../shared/permission_guidance.dart';
import 'camera_capture_screen.dart';
import 'message_actions_sheet.dart';

enum _DeliveryState { sending, uploading, failed }

class _PendingDelivery {
  _PendingDelivery({required this.key, required this.message, this.filePath});

  final String key;
  final MessageModel message;
  final String? filePath;
  MediaAttachment? attachment;
  _DeliveryState state = _DeliveryState.sending;
  double progress = 0;
  String? error;
  CancelToken? cancelToken;
}

class ChatWindowScreen extends StatefulWidget {
  const ChatWindowScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.avatarUrl,
    required this.isOnline,
    required this.currentUserId,
    this.recipientUserId,
    this.recipientPhone,
  });

  final int chatId;
  final String chatName;
  final String? avatarUrl;
  final bool isOnline;
  final int currentUserId;
  final int? recipientUserId;
  final String? recipientPhone;

  @override
  State<ChatWindowScreen> createState() => _ChatWindowScreenState();
}

class _ChatWindowScreenState extends State<ChatWindowScreen>
    with SingleTickerProviderStateMixin {
  static const _uuid = Uuid();
  static const _maxImageBytes = 10 * 1024 * 1024;
  static const _maxVideoBytes = 50 * 1024 * 1024;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _chatService = ChatService();
  final _socketService = SocketService();
  final _picker = ImagePicker();
  final _recorder = VoiceRecorderService();
  final _audioPlayer = SingleAudioPlayerService();

  final List<MessageModel> _messages = [];
  final Map<String, _PendingDelivery> _pending = {};
  bool _isLoading = true;
  bool _isLoadingOlder = false;
  bool _hasMore = false;
  String? _nextCursor;
  String? _error;
  bool _showEmojiPicker = false;
  bool _isTyping = false;
  bool _remoteIsTyping = false;
  bool _isOnline = false;
  bool _isRecording = false;
  bool _isStartingRecording = false;
  bool? _completeRecordingWhenStarted;
  Duration _recordingDuration = Duration.zero;
  Timer? _typingTimer;
  StreamSubscription<VoiceRecorderSnapshot>? _recorderSubscription;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.isOnline;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _messageController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);
    _recorderSubscription = _recorder.snapshots.listen(_onRecorderSnapshot);
    _socketService
      ..joinChat(widget.chatId)
      ..addMessageListener(_onSocketMessage)
      ..addMessageEditedListener(_onMessageEdited)
      ..addMessageDeletedListener(_onMessageDeleted)
      ..addMessagePinnedListener(_onMessagePinned)
      ..addMessageDeliveredListener(_onMessageDelivered)
      ..addMessageReadListener(_onMessageRead)
      ..addTypingListener(_onSocketTyping)
      ..addPresenceListener(_onPresenceChange);
    _loadMessages();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recorderSubscription?.cancel();
    for (final delivery in _pending.values) {
      delivery.cancelToken?.cancel('Conversation closed');
    }
    _messageController
      ..removeListener(_onTextChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _pulseController.dispose();
    _socketService
      ..leaveChat(widget.chatId)
      ..removeMessageListener(_onSocketMessage)
      ..removeMessageEditedListener(_onMessageEdited)
      ..removeMessageDeletedListener(_onMessageDeleted)
      ..removeMessagePinnedListener(_onMessagePinned)
      ..removeMessageDeliveredListener(_onMessageDelivered)
      ..removeMessageReadListener(_onMessageRead)
      ..removeTypingListener(_onSocketTyping)
      ..removePresenceListener(_onPresenceChange);
    unawaited(_recorder.dispose());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _chatService.getChatMessagePage(
        widget.chatId,
        widget.currentUserId,
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(_deduplicate(page.messages));
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
      unawaited(_chatService.markAllRead(widget.chatId, widget.currentUserId));
      for (final m in page.messages) {
        if (m.senderId != widget.currentUserId && m.id > 0 && !m.isRead) {
          _socketService.emitMessageRead(m.id, widget.chatId);
        }
      }
      _scrollToBottom(jump: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorText(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOlder() async {
    if (_isLoadingOlder || !_hasMore) return;
    setState(() => _isLoadingOlder = true);
    final oldExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    try {
      final page = await _chatService.getChatMessagePage(
        widget.chatId,
        widget.currentUserId,
        cursor: _nextCursor,
      );
      if (!mounted) return;
      final existingIds = _messages
          .where((m) => m.id > 0)
          .map((m) => m.id)
          .toSet();
      final older = page.messages
          .where(
            (message) => message.id <= 0 || !existingIds.contains(message.id),
          )
          .toList();
      setState(() {
        _messages.insertAll(0, older);
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _isLoadingOlder = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final addedExtent =
            _scrollController.position.maxScrollExtent - oldExtent;
        _scrollController.jumpTo(
          addedExtent.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingOlder = false);
      _showError('Could not load older messages: ${_errorText(error)}');
    }
  }

  List<MessageModel> _deduplicate(Iterable<MessageModel> input) {
    final ids = <int>{};
    final keys = <String>{};
    return input.where((message) {
      if (message.id > 0 && !ids.add(message.id)) return false;
      final key = message.idempotencyKey;
      return key == null || keys.add(key);
    }).toList();
  }

  void _onSocketMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    final message = MessageModel.fromJson(data);
    if (message.chatId != widget.chatId) return;
    _reconcile(message);
    if (message.senderId != widget.currentUserId) {
      if (message.id > 0) {
        _socketService.emitMessageDelivered(message.id, widget.chatId);
        _socketService.emitMessageRead(message.id, widget.chatId);
      }
      unawaited(_chatService.markAllRead(widget.chatId, widget.currentUserId));
    }
    _scrollToBottom();
  }

  void _onMessageEdited(Map<String, dynamic> event) {
    if (!mounted || _eventChatId(event) != widget.chatId) return;
    final messageId = _eventMessageId(event);
    final text = event['message']?.toString();
    if (messageId == null || text == null) return;
    setState(() {
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(
          message: text,
          isEdited: true,
        );
      }
    });
  }

  void _onMessageDeleted(Map<String, dynamic> event) {
    if (!mounted || _eventChatId(event) != widget.chatId) return;
    final messageId = _eventMessageId(event);
    if (messageId == null) return;
    setState(() {
      if (event['scope'] == 'for_me') {
        _messages.removeWhere((message) => message.id == messageId);
        return;
      }
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(
          clearMessage: true,
          messageType: 'deleted',
          isPinned: false,
        );
      }
    });
  }

  void _onMessagePinned(Map<String, dynamic> event) {
    if (!mounted || _eventChatId(event) != widget.chatId) return;
    final messageId = _eventMessageId(event);
    if (messageId == null) return;
    setState(() {
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(
          isPinned: event['is_pinned'] == true,
        );
      }
    });
  }

  void _onMessageDelivered(Map<String, dynamic> event) {
    if (!mounted || _eventChatId(event) != widget.chatId) return;
    final messageId = _eventMessageId(event);
    if (messageId == null) return;
    setState(() {
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(isDelivered: true);
      }
    });
  }

  void _onMessageRead(Map<String, dynamic> event) {
    if (!mounted || _eventChatId(event) != widget.chatId) return;
    final messageId = _eventMessageId(event);
    if (messageId == null) return;
    setState(() {
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index >= 0) {
        _messages[index] = _messages[index].copyWith(
          isDelivered: true,
          isRead: true,
        );
      }
    });
  }

  int? _eventChatId(Map<String, dynamic> event) =>
      int.tryParse((event['chatId'] ?? event['chat_id'])?.toString() ?? '');

  int? _eventMessageId(Map<String, dynamic> event) => int.tryParse(
    (event['messageId'] ?? event['message_id'])?.toString() ?? '',
  );

  void _reconcile(MessageModel confirmed, {String? fallbackKey}) {
    setState(() {
      final index = _messages.indexWhere(
        (message) =>
            message.canReconcileWith(confirmed) ||
            (fallbackKey != null && message.idempotencyKey == fallbackKey),
      );
      if (index >= 0) {
        _messages[index] = confirmed;
      } else if (!_messages.any((message) => message.id == confirmed.id)) {
        _messages.add(confirmed);
      }
      final key = confirmed.idempotencyKey ?? fallbackKey;
      if (key != null) _pending.remove(key);
      if (confirmed.id > 0) {
        var seen = false;
        _messages.removeWhere((message) {
          if (message.id != confirmed.id) return false;
          if (!seen) {
            seen = true;
            return false;
          }
          return true;
        });
      }
    });
  }

  void _onSocketTyping(int chatId, int userId, bool isTyping) {
    if (!mounted || chatId != widget.chatId || userId == widget.currentUserId) {
      return;
    }
    setState(() => _remoteIsTyping = isTyping);
  }

  void _onPresenceChange(int userId, bool isOnline) {
    if (!mounted || userId != widget.recipientUserId) return;
    setState(() => _isOnline = isOnline);
  }

  Future<void> _sendText() async {
    final typed = _messageController.text.trim();
    if (_editingMsg != null) {
      if (typed.isEmpty) {
        _showError('Message cannot be empty.');
        return;
      }
      await _submitEdit(typed);
      return;
    }
    final text = typed.isEmpty ? '👍' : typed;
    final reply = _replyingTo;
    final key = _uuid.v4();
    final optimistic = MessageModel(
      id: -DateTime.now().microsecondsSinceEpoch,
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      message: text,
      messageType: 'text',
      replyTo: reply?.id,
      replyToMessage: reply,
      isForwarded: false,
      isEdited: false,
      isPinned: false,
      createdAt: DateTime.now(),
      idempotencyKey: key,
    );
    final delivery = _PendingDelivery(key: key, message: optimistic);
    setState(() {
      _messages.add(optimistic);
      _pending[key] = delivery;
      _replyingTo = null;
      if (typed.isNotEmpty) _messageController.clear();
    });
    _scrollToBottom();
    await _deliverText(delivery);
  }

  Future<void> _deliverText(_PendingDelivery delivery) async {
    setState(() {
      delivery
        ..state = _DeliveryState.sending
        ..error = null;
    });
    try {
      final confirmed = await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        message: delivery.message.message ?? '',
        replyTo: delivery.message.replyTo,
        idempotencyKey: delivery.key,
      );
      if (mounted) _reconcile(confirmed, fallbackKey: delivery.key);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        delivery
          ..state = _DeliveryState.failed
          ..error = _errorText(error);
      });
    }
  }

  Future<void> _submitEdit(String text) async {
    final editing = _editingMsg;
    if (editing == null) return;
    try {
      final updated = await _chatService.editMessage(
        messageId: editing.id,
        userId: widget.currentUserId,
        message: text,
      );
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere(
          (message) => message.id == editing.id,
        );
        if (index >= 0) {
          _messages[index] = _messages[index].copyWith(
            message: updated.message,
            isEdited: true,
          );
        }
        _editingMsg = null;
        _messageController.clear();
      });
    } on ChatServiceException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError(_errorText(error));
    }
  }

  Future<void> _pickFromCamera() async {
    if (foundation.kIsWeb) {
      final file = await Navigator.push<XFile>(
        context,
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );
      if (file != null && mounted) {
        await _handlePickedMedia(file, video: false);
      }
      return;
    }
    await _pickMedia(ImageSource.camera, video: false);
  }

  Future<void> _pickFromGallery() async {
    final video = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (video == null || !mounted) return;
    await _pickMedia(ImageSource.gallery, video: video);
  }

  Future<void> _pickMedia(ImageSource source, {required bool video}) async {
    try {
      final file = video
          ? await _picker.pickVideo(
              source: source,
              maxDuration: const Duration(minutes: 2),
            )
          : await _picker.pickImage(
              source: source,
              imageQuality: 82,
              maxWidth: 1920,
              maxHeight: 1920,
            );
      if (file == null || !mounted) return;
      await _handlePickedMedia(file, video: video);
    } catch (error) {
      if (!mounted) return;
      if (isMediaPermissionError(error)) {
        await showPermissionSettingsDialog(
          context,
          title: source == ImageSource.camera
              ? 'Camera access needed'
              : 'Photo access needed',
          message: source == ImageSource.camera
              ? 'Allow camera access in app settings to take a photo.'
              : 'Allow photo access in app settings to attach media.',
        );
        return;
      }
      _showError('Could not select media: ${_errorText(error)}');
    }
  }

  Future<void> _handlePickedMedia(XFile file, {required bool video}) async {
    final size = await file.length();
    final maximum = video ? _maxVideoBytes : _maxImageBytes;
    if (size <= 0 || size > maximum) {
      _showError(
        '${video ? 'Video' : 'Image'} must be smaller than '
        '${maximum ~/ (1024 * 1024)} MB.',
      );
      return;
    }
    final previewBytes = video ? null : await file.readAsBytes();
    if (!mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send ${video ? 'video' : 'photo'}?'),
        content: video
            ? const SizedBox(
                height: 160,
                child: Center(child: Icon(Icons.play_circle, size: 72)),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  previewBytes!,
                  height: 260,
                  fit: BoxFit.contain,
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      await _queueMedia(
        file.path,
        video ? 'video' : 'image',
        MediaMetadata(
          fileName: file.name,
          sizeBytes: size,
          mimeType: _mediaMimeType(file.name, video: video),
        ),
      );
    }
  }

  Future<void> _queueMedia(
    String path,
    String type,
    MediaMetadata metadata,
  ) async {
    final reply = _replyingTo;
    final key = _uuid.v4();
    final optimistic = MessageModel(
      id: -DateTime.now().microsecondsSinceEpoch,
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      message: '',
      messageType: type,
      mediaUrl: path,
      mediaMetadata: metadata,
      replyTo: reply?.id,
      replyToMessage: reply,
      isForwarded: false,
      isEdited: false,
      isPinned: false,
      createdAt: DateTime.now(),
      idempotencyKey: key,
    );
    final delivery = _PendingDelivery(
      key: key,
      message: optimistic,
      filePath: path,
    );
    setState(() {
      _messages.add(optimistic);
      _pending[key] = delivery;
      _replyingTo = null;
    });
    _scrollToBottom();
    await _deliverMedia(delivery);
  }

  Future<void> _deliverMedia(_PendingDelivery delivery) async {
    final token = CancelToken();
    setState(() {
      delivery
        ..state = delivery.attachment == null
            ? _DeliveryState.uploading
            : _DeliveryState.sending
        ..progress = delivery.attachment == null ? 0 : 1
        ..error = null
        ..cancelToken = token;
    });
    try {
      final attachment =
          delivery.attachment ??
          await _chatService.uploadAttachment(
            filePath: delivery.filePath!,
            fileName: delivery.message.mediaMetadata?.fileName,
            mimeType: delivery.message.mediaMetadata?.mimeType,
            cancelToken: token,
            onProgress: (sent, total) {
              if (!mounted || total <= 0) return;
              setState(() => delivery.progress = sent / total);
            },
          );
      delivery.attachment = attachment;
      if (mounted) setState(() => delivery.state = _DeliveryState.sending);
      final confirmed = await _chatService.sendMediaMessage(
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        attachment: attachment,
        messageType: delivery.message.messageType,
        replyTo: delivery.message.replyTo,
        idempotencyKey: delivery.key,
        cancelToken: token,
      );
      if (mounted) _reconcile(confirmed, fallbackKey: delivery.key);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        delivery
          ..state = _DeliveryState.failed
          ..error = error is ChatServiceException && error.isCancelled
              ? 'Upload cancelled'
              : _errorText(error)
          ..cancelToken = null;
      });
      _showError('Media send failed: ${delivery.error}');
    }
  }

  String _mediaMimeType(String fileName, {required bool video}) {
    final extension = fileName.toLowerCase().split('.').last;
    if (video) {
      return switch (extension) {
        'mov' => 'video/quicktime',
        'avi' => 'video/x-msvideo',
        'webm' => 'video/webm',
        _ => 'video/mp4',
      };
    }
    return switch (extension) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isStartingRecording) return;
    setState(() {
      _isStartingRecording = true;
      _completeRecordingWhenStarted = null;
      _showEmojiPicker = false;
      _recordingDuration = Duration.zero;
    });
    try {
      await _recorder.start();
      if (!mounted) return;
      final completion = _completeRecordingWhenStarted;
      setState(() {
        _isStartingRecording = false;
        _isRecording = true;
      });
      if (completion == true) {
        await _finishRecording();
      } else if (completion == false) {
        await _cancelRecording();
      }
    } on VoiceRecorderException catch (error) {
      if (!mounted) return;
      setState(() => _isStartingRecording = false);
      if (error.settingsRequired) {
        await showPermissionSettingsDialog(
          context,
          title: 'Microphone access needed',
          message: error.message,
        );
      } else {
        _showError(error.message);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isStartingRecording = false);
      _showError(_errorText(error));
    }
  }

  void _onRecorderSnapshot(VoiceRecorderSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _recordingDuration = snapshot.duration;
      _isRecording =
          snapshot.status == VoiceRecorderStatus.recording ||
          snapshot.status == VoiceRecorderStatus.paused;
    });
    if (snapshot.error != null) _showError(snapshot.error!);
  }

  Future<void> _cancelRecording() async {
    if (_isStartingRecording) {
      setState(() => _completeRecordingWhenStarted = false);
      return;
    }
    try {
      await _recorder.cancel();
    } catch (error) {
      if (mounted) _showError(_errorText(error));
    }
  }

  Future<void> _finishRecording({bool send = true}) async {
    if (_isStartingRecording) {
      _completeRecordingWhenStarted = send;
      return;
    }
    if (!_isRecording) return;
    try {
      final duration = _recordingDuration;
      final path = await _recorder.stop();
      if (!send || path == null) {
        await _recorder.cancel();
        return;
      }
      if (duration < const Duration(milliseconds: 500)) {
        await _recorder.cancel();
        _showError('Voice note is too short.');
        return;
      }
      final size = await XFile(path).length();
      await _queueMedia(
        path,
        'audio',
        MediaMetadata(
          fileName: 'voice_${_uuid.v4()}.m4a',
          mimeType: 'audio/mp4',
          sizeBytes: size,
          duration: duration,
        ),
      );
    } catch (error) {
      if (mounted) _showError(_errorText(error));
    }
  }

  Future<void> _callRecipient() async {
    final raw = widget.recipientPhone?.trim();
    if (raw == null || raw.isEmpty) {
      _showError('No phone number is available for this contact.');
      return;
    }
    late final String phone;
    try {
      phone = ChatRecipient.normalizePhone(raw);
    } on FormatException catch (error) {
      _showError('Invalid phone number: ${error.message}');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (!await canLaunchUrl(uri)) {
        _showError('No SIM dialer is available on this device.');
        return;
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) _showError('The SIM dialer could not be opened.');
    } catch (_) {
      if (mounted) _showError('The SIM dialer could not be opened.');
    }
  }

  void _retry(MessageModel message) {
    final key = message.idempotencyKey;
    final delivery = key == null ? null : _pending[key];
    if (delivery == null) return;
    if (delivery.filePath == null) {
      unawaited(_deliverText(delivery));
    } else {
      unawaited(_deliverMedia(delivery));
    }
  }

  // ── Enterprise-level Facebook/WhatsApp Message Actions ────────────────────

  MessageModel? _replyingTo; // quoted reply state
  MessageModel? _editingMsg; // edit mode state

  void _showMessageActions(MessageModel message) {
    final pending = message.id <= 0;
    final mine = message.senderId == widget.currentUserId;
    final isDeleted = message.messageType == 'deleted';
    final hasText = (message.message ?? '').isNotEmpty;
    final canEdit =
        mine &&
        !pending &&
        hasText &&
        message.messageType == 'text' &&
        DateTime.now().difference(message.createdAt) <=
            const Duration(minutes: 15);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MessageActionsSheet(
        isPinned: message.isPinned,
        initiallyShowMore: pending,
        deleteLabel: pending
            ? message.messageType == 'image'
                  ? 'Remove failed photo'
                  : 'Remove failed message'
            : 'Delete for me',
        onReply: pending
            ? null
            : () {
                Navigator.pop(context);
                setState(() => _replyingTo = message);
                _focusNode.requestFocus();
              },
        onEdit: canEdit
            ? () {
                Navigator.pop(context);
                setState(() {
                  _replyingTo = null;
                  _editingMsg = message;
                  _messageController.text = message.message ?? '';
                  _messageController.selection = TextSelection.collapsed(
                    offset: _messageController.text.length,
                  );
                });
                _focusNode.requestFocus();
              }
            : null,
        onCopy: hasText
            ? () {
                Navigator.pop(context);
                _copyText(message.message!);
              }
            : null,
        onForward: !pending && !isDeleted
            ? () {
                Navigator.pop(context);
                unawaited(_showForwardDialog(message));
              }
            : null,
        onPin: !pending && !isDeleted
            ? () {
                Navigator.pop(context);
                unawaited(_togglePin(message));
              }
            : null,
        onDeleteForMe: () {
          Navigator.pop(context);
          unawaited(_confirmDeleteForMe(message));
        },
        onRetry: pending
            ? () {
                Navigator.pop(context);
                _retry(message);
              }
            : null,
        onUnsend: mine && !pending && !isDeleted
            ? () {
                Navigator.pop(context);
                unawaited(_confirmUnsend(message));
              }
            : null,
      ),
    );
  }

  void _copyText(String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showForwardDialog(MessageModel message) async {
    final chatsFuture = _chatService.getMyChats(widget.currentUserId);
    final targetChatId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .65,
        child: FutureBuilder<List<ChatModel>>(
          future: chatsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(_errorText(snapshot.error!)));
            }
            final chats = snapshot.data ?? const <ChatModel>[];
            if (chats.isEmpty) {
              return const Center(child: Text('No chats available'));
            }
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Forward to',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: chats.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: chat.avatarUrl == null
                              ? null
                              : NetworkImage(chat.avatarUrl!),
                          child: chat.avatarUrl == null
                              ? Text(chat.avatarInitial)
                              : null,
                        ),
                        title: Text(chat.displayName),
                        subtitle: Text(chat.lastMessage ?? 'Conversation'),
                        onTap: () => Navigator.pop(sheetContext, chat.id),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (targetChatId == null || !mounted) return;
    try {
      final forwarded = await _chatService.forwardMessage(
        messageId: message.id,
        targetChatId: targetChatId,
        senderId: widget.currentUserId,
      );
      if (!mounted) return;
      if (targetChatId == widget.chatId) _reconcile(forwarded);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message forwarded')));
    } on ChatServiceException catch (error) {
      if (mounted) _showError(error.message);
    }
  }

  Future<void> _togglePin(MessageModel message) async {
    try {
      final nextPinned = !message.isPinned;
      await _chatService.setMessagePinned(
        messageId: message.id,
        userId: widget.currentUserId,
        isPinned: nextPinned,
      );
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(isPinned: nextPinned);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextPinned ? '📌 Message pinned' : 'Message unpinned'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on ChatServiceException catch (error) {
      if (mounted) _showError(error.message);
    }
  }

  Future<void> _confirmDeleteForMe(MessageModel message) async {
    if (message.id <= 0) {
      _discardPendingMessage(message);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete for you?'),
        content: const Text(
          'This message will only be removed from your view.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _deleteForMe(message);
  }

  void _discardPendingMessage(MessageModel message) {
    final key = message.idempotencyKey;
    if (key != null) {
      _pending[key]?.cancelToken?.cancel('Removed by user');
    }
    setState(() {
      _messages.removeWhere((item) => identical(item, message));
      if (key != null) _pending.remove(key);
    });
  }

  Future<void> _confirmUnsend(MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsend message?'),
        content: const Text(
          'This message will be removed for everyone in this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unsend'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _deleteForEveryone(message);
  }

  Future<void> _deleteForMe(MessageModel message) async {
    try {
      await _chatService.deleteMessageForMe(message.id);
      if (!mounted) return;
      setState(() => _messages.removeWhere((m) => m.id == message.id));
    } on ChatServiceException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Could not delete message. Try again.');
    }
  }

  Future<void> _deleteForEveryone(MessageModel message) async {
    try {
      await _chatService.deleteMessageForEveryone(message.id);
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == message.id);
        if (idx != -1) {
          _messages[idx] = message.copyWith(
            clearMessage: true,
            messageType: 'deleted',
            isPinned: false,
          );
        }
      });
    } on ChatServiceException catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Could not delete message. Try again.');
    }
  }

  void _cancelUpload(MessageModel message) {
    final key = message.idempotencyKey;
    if (key != null) _pending[key]?.cancelToken?.cancel('Cancelled by user');
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _isTyping && mounted) setState(() => _isTyping = hasText);
    _socketService.emitTyping(widget.chatId, hasText);
    _typingTimer?.cancel();
    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _socketService.emitTyping(widget.chatId, false);
      });
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 100) {
      unawaited(_loadOlder());
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _errorText(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleBackspace() {
    final text = _messageController.text;
    final selection = _messageController.selection;
    if (text.isEmpty) {
      // If text is empty and user taps the cross/backspace button, close the emoji picker
      if (mounted) setState(() => _showEmojiPicker = false);
      return;
    }

    if (selection.start > 0 && selection.start == selection.end) {
      final newText = text.replaceRange(
        selection.start - 1,
        selection.start,
        '',
      );
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start - 1),
      );
    } else if (selection.start != selection.end && selection.start >= 0) {
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '',
      );
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    } else {
      final chars = text.characters;
      if (chars.isNotEmpty) {
        _messageController.text = chars.skipLast(1).string;
        _messageController.selection = TextSelection.collapsed(
          offset: _messageController.text.length,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFBF6F0),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInputArea(),
            if (_showEmojiPicker)
              SizedBox(
                height: 270,
                child: EmojiPicker(
                  textEditingController: _messageController,
                  onBackspacePressed: _handleBackspace,
                  config: Config(
                    emojiViewConfig: EmojiViewConfig(
                      backgroundColor: const Color(0xFFF9FAFB),
                      columns: 7,
                      emojiSizeMax:
                          28 *
                          (foundation.defaultTargetPlatform == TargetPlatform.iOS
                              ? 1.3
                              : 1),
                    ),
                    categoryViewConfig: const CategoryViewConfig(
                      backgroundColor: Color(0xFFF9FAFB),
                      indicatorColor: Color(0xFFFF6B00),
                      iconColorSelected: Color(0xFFFF6B00),
                      iconColor: Color(0xFF9CA3AF),
                      dividerColor: Color(0xFFE5E7EB),
                    ),
                    bottomActionBarConfig: BottomActionBarConfig(
                      backgroundColor: const Color(0xFFF3F4F6),
                      buttonColor: const Color(0xFFF3F4F6),
                      buttonIconColor: const Color(0xFF374151),
                      showBackspaceButton: true,
                      showSearchViewButton: true,
                      customBottomActionBar: (config, state, showSearchView) {
                        return Container(
                          height: 46,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            border: Border(
                              top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Search emoji',
                                icon: const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF4B5563),
                                  size: 22,
                                ),
                                onPressed: showSearchView,
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Backspace',
                                icon: const Icon(
                                  Icons.backspace_outlined,
                                  color: Color(0xFF4B5563),
                                  size: 20,
                                ),
                                onPressed: _handleBackspace,
                              ),
                              IconButton(
                                tooltip: 'Close',
                                icon: const Icon(
                                  Icons.keyboard_hide_rounded,
                                  color: Color(0xFFFF6B00),
                                  size: 24,
                                ),
                                onPressed: () {
                                  if (mounted) {
                                    setState(() => _showEmojiPicker = false);
                                  }
                                  _focusNode.unfocus();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    searchViewConfig: const SearchViewConfig(
                      backgroundColor: Color(0xFFF9FAFB),
                      buttonIconColor: Color(0xFFFF6B00),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: Colors.black,
            backgroundImage: widget.avatarUrl == null
                ? null
                : NetworkImage(widget.avatarUrl!),
            child: widget.avatarUrl == null
                ? Text(
                    widget.chatName.isEmpty
                        ? '?'
                        : widget.chatName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _remoteIsTyping
                      ? 'typing...'
                      : _isOnline
                      ? 'Online'
                      : 'Offline',
                  style: TextStyle(
                    color: _remoteIsTyping
                        ? Colors.black
                        : Colors.grey,
                    fontSize: 12,
                    fontStyle: _remoteIsTyping
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Call with SIM',
          icon: const Icon(Icons.call_outlined, color: Colors.black),
          onPressed: _callRecipient,
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: _loadMessages,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet.\nSay hello! 👋',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
        _focusNode.unfocus();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount:
            _messages.length +
            (_remoteIsTyping ? 1 : 0) +
            (_isLoadingOlder ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isLoadingOlder && index == 0) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final messageIndex = index - (_isLoadingOlder ? 1 : 0);
          if (_remoteIsTyping && messageIndex == _messages.length) {
            return _buildTypingBubble();
          }
          final message = _messages[messageIndex];
          return _buildMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final mine = message.senderId == widget.currentUserId;
    const foreground = Color(0xFF111827);
    final hasReply = message.replyToMessage != null;
    final hasForward = message.isForwarded;
    final isText = message.messageType == 'text';
    final hasText = (message.message ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showMessageActions(message),
          onTap: () => _showMessageActions(message),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFFFFE8D6) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: mine ? 0.05 : 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasForward)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          size: 13,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Forwarded',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (hasReply)
                  _buildReplyPreview(message.replyToMessage!, mine),
                if (!isText) ...[
                  _buildTypedContent(message, mine),
                  if (hasText) const SizedBox(height: 6),
                ],
                if (isText)
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    runSpacing: 2,
                    children: [
                      Text(
                        message.message ?? '',
                        style: const TextStyle(
                          color: foreground,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 1),
                        child: _buildTimeAndStatus(message, mine, foreground),
                      ),
                    ],
                  )
                else if (hasText)
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    runSpacing: 2,
                    children: [
                      Text(
                        message.message!,
                        style: const TextStyle(
                          color: foreground,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 1),
                        child: _buildTimeAndStatus(message, mine, foreground),
                      ),
                    ],
                  )
                else if (message.messageType != 'image')
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildTimeAndStatus(message, mine, foreground),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeAndStatus(
    MessageModel message,
    bool mine,
    Color foreground, {
    bool isOverlay = false,
  }) {
    final key = message.idempotencyKey;
    final delivery = key == null ? null : _pending[key];
    final color = isOverlay ? Colors.white70 : const Color(0xFF6B7280);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (message.isPinned) ...[
          Icon(Icons.push_pin, size: 10.5, color: color),
          const SizedBox(width: 2.5),
        ],
        if (message.isEdited)
          Text(
            'edited ',
            style: TextStyle(color: color, fontSize: 10),
          ),
        Text(
          message.formattedTime,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (mine) ...[
          const SizedBox(width: 3.5),
          if (delivery?.state == _DeliveryState.uploading)
            SizedBox.square(
              dimension: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                value: delivery!.progress == 0 ? null : delivery.progress,
                color: const Color(0xFFFF6B00),
              ),
            )
          else if (delivery?.state == _DeliveryState.failed)
            Icon(Icons.error_outline_rounded, size: 12, color: Colors.red.shade400)
          else if (delivery != null)
            Icon(Icons.schedule_rounded, size: 11, color: color)
          else if (message.isRead)
            const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFFFF6B00))
          else if (message.isDelivered)
            const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF9CA3AF))
          else
            const Icon(Icons.done_rounded, size: 14, color: Color(0xFF9CA3AF)),
        ],
      ],
    );
  }

  Widget _buildReplyPreview(MessageModel replied, bool mine) {
    final preview = (replied.message ?? '').trim();
    final label = preview.isNotEmpty
        ? preview
        : switch (replied.messageType) {
            'image' => 'Photo',
            'video' => 'Video',
            'audio' => 'Voice message',
            'document' => 'Document',
            _ => 'Message',
          };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFFFFD8BF) : const Color(0xFFFFF4EC),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFFFF6B00), width: 3.5),
        ),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: mine ? const Color(0xFF9A3412) : const Color(0xFF44403C),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTypedContent(MessageModel message, bool mine) {
    switch (message.messageType) {
      case 'image':
        return _buildImage(message);
      case 'video':
        return _mediaTile(
          Icons.play_circle_fill,
          message.mediaMetadata?.fileName ?? 'Video',
          mine,
          missing: message.mediaUrl == null,
        );
      case 'audio':
        return _buildAudio(message, mine);
      case 'document':
        return _mediaTile(
          Icons.description_outlined,
          message.mediaMetadata?.fileName ?? 'Document',
          mine,
          missing: message.mediaUrl == null,
        );
      case 'deleted':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            const Text(
              'This message was deleted',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImage(MessageModel message) {
    final source = message.mediaUrl;
    if (source == null || source.isEmpty) {
      return _mediaFailure('Image unavailable');
    }
    final uri = Uri.tryParse(source);
    final local = uri == null || !uri.hasScheme;
    final image = local
        ? Image.file(
            File(source),
            width: 240,
            height: 190,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _mediaFailure('Image unavailable'),
          )
        : Image.network(
            source,
            width: 240,
            height: 190,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    width: 240,
                    height: 190,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => _mediaFailure('Image failed to load'),
          );
    final imageWidget = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: image,
    );
    final hasCaption = (message.message ?? '').trim().isNotEmpty;
    if (hasCaption) return imageWidget;

    final mine = message.senderId == widget.currentUserId;
    return Stack(
      children: [
        imageWidget,
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _buildTimeAndStatus(
              message,
              mine,
              Colors.white,
              isOverlay: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudio(MessageModel message, bool mine) {
    final source = message.mediaUrl;
    if (source == null || source.isEmpty) {
      return _mediaFailure('Audio unavailable');
    }
    return StreamBuilder<AudioPlaybackSnapshot>(
      stream: _audioPlayer.snapshots,
      initialData: _audioPlayer.current,
      builder: (context, snapshot) {
        final playback = snapshot.data ?? _audioPlayer.current;
        final active = playback.source == source;
        final playing =
            active && playback.status == AudioPlaybackStatus.playing;
        final loading =
            active && playback.status == AudioPlaybackStatus.loading;
        final failed = active && playback.status == AudioPlaybackStatus.error;
        final duration = active && playback.duration > Duration.zero
            ? playback.duration
            : message.mediaMetadata?.duration ?? Duration.zero;
        final position = active ? playback.position : Duration.zero;
        final max = duration.inMilliseconds
            .toDouble()
            .clamp(1.0, double.infinity)
            .toDouble();
        return SizedBox(
          width: 245,
          child: Row(
            children: [
              IconButton(
                tooltip: playing ? 'Pause voice note' : 'Play voice note',
                onPressed: loading
                    ? null
                    : () async {
                        try {
                          await _audioPlayer.toggle(source);
                        } catch (error) {
                          if (mounted) _showError(_errorText(error));
                        }
                      },
                icon: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        failed
                            ? Icons.refresh
                            : playing
                            ? Icons.pause_circle
                            : Icons.play_circle,
                        color: mine ? Colors.white : Colors.black,
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Slider(
                      activeColor: const Color(0xFFFF6B00),
                      inactiveColor: const Color(0xFFE5E7EB),
                      value: position.inMilliseconds
                          .toDouble()
                          .clamp(0.0, max)
                          .toDouble(),
                      max: max,
                      onChanged: active && duration > Duration.zero
                          ? (value) => _audioPlayer.seek(
                              Duration(milliseconds: value.round()),
                            )
                          : null,
                    ),
                    Text(
                      failed
                          ? 'Playback failed'
                          : '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mediaTile(
    IconData icon,
    String label,
    bool mine, {
    required bool missing,
  }) {
    return SizedBox(
      width: 230,
      child: Row(
        children: [
          Icon(
            icon,
            size: 42,
            color: const Color(0xFFFF6B00),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              missing ? '$label unavailable' : label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaFailure(String text) {
    return Container(
      width: 220,
      height: 120,
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, color: Colors.grey),
            Text(
              text,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: FadeTransition(
          opacity: _pulseController,
          child: const Text('•••', style: TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_editingMsg != null || _replyingTo != null)
              _buildComposerContext(),
            _isRecording ? _buildRecordingUi() : _buildStandardInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerContext() {
    final editing = _editingMsg;
    final target = editing ?? _replyingTo!;
    final preview = (target.message ?? '').trim();
    final isEdit = editing != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isEdit ? const Color(0xFF3B82F6) : const Color(0xFFFF6B00),
            width: 3.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEdit ? Icons.edit_rounded : Icons.reply_rounded,
            size: 18,
            color: isEdit ? const Color(0xFF3B82F6) : const Color(0xFFFF6B00),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Editing message' : 'Replying',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isEdit ? const Color(0xFF3B82F6) : const Color(0xFFFF6B00),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview.isEmpty ? target.messageType : preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 14,
            onPressed: () {
              setState(() {
                if (_editingMsg != null) _messageController.clear();
                _editingMsg = null;
                _replyingTo = null;
              });
            },
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardInput() {
    final hasActionText = _editingMsg != null || _isTyping;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Main Input Pill
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Emoji Icon inside the pill
                IconButton(
                  tooltip: 'Choose emoji',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 38),
                  splashRadius: 16,
                  icon: Icon(
                    _showEmojiPicker
                        ? Icons.keyboard_outlined
                        : Icons.sentiment_satisfied_alt_outlined,
                    color: const Color(0xFF6B7280),
                    size: 22,
                  ),
                  onPressed: () {
                    if (_showEmojiPicker) {
                      setState(() => _showEmojiPicker = false);
                      _focusNode.requestFocus();
                    } else {
                      _focusNode.unfocus();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) setState(() => _showEmojiPicker = true);
                      });
                    }
                  },
                ),
                // Text Field
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onTap: () {
                        if (_showEmojiPicker) {
                          setState(() => _showEmojiPicker = false);
                        }
                      },
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        height: 1.3,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Message',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                // Attach Media Button
                IconButton(
                  tooltip: 'Attach media',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 38),
                  splashRadius: 16,
                  icon: const Icon(
                    Icons.attach_file_rounded,
                    color: Color(0xFF6B7280),
                    size: 20,
                  ),
                  onPressed: _pickFromGallery,
                ),
                if (!_isTyping) ...[
                  IconButton(
                    tooltip: 'Take photo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 38),
                    splashRadius: 16,
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF6B7280),
                      size: 20,
                    ),
                    onPressed: _pickFromCamera,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Dedicated Circular Action Button (Send / Mic)
        GestureDetector(
          onTap: () {
            if (_editingMsg != null || _isTyping) {
              _sendText();
            } else {
              _startRecording();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasActionText ? const Color(0xFFFF6B00) : const Color(0xFF111827),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (hasActionText ? const Color(0xFFFF6B00) : Colors.black)
                      .withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _editingMsg != null
                    ? Icons.check_rounded
                    : _isTyping
                        ? Icons.send_rounded
                        : Icons.mic_none_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingUi() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
      ),
      child: Row(
        children: [
          FadeTransition(
            opacity: _pulseController,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatDuration(_recordingDuration),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFDC2626),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Recording voice note...',
            style: TextStyle(
              color: Color(0xFF991B1B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _cancelRecording,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _finishRecording,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
