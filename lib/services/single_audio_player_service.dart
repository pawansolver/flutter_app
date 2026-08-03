import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../core/api_config.dart';

enum AudioPlaybackStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  completed,
  error,
  disposed,
}

class AudioPlaybackSnapshot {
  const AudioPlaybackSnapshot({
    required this.status,
    required this.position,
    required this.duration,
    this.source,
    this.error,
  });

  final AudioPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final String? source;
  final String? error;

  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }
}

class AudioPlaybackException implements Exception {
  const AudioPlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One reusable player prevents overlapping voice notes in a conversation.
///
/// The playback audio session uses the media/speaker route. Calling [load] or
/// [play] with a different source stops the currently active source first.
class SingleAudioPlayerService {
  SingleAudioPlayerService({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subscriptions.add(_player.positionStream.listen((_) => _emit()));
    _subscriptions.add(_player.durationStream.listen((_) => _emit()));
    _subscriptions.add(_player.playerStateStream.listen(_onPlayerState));
  }

  final AudioPlayer _player;
  final StreamController<AudioPlaybackSnapshot> _snapshots =
      StreamController<AudioPlaybackSnapshot>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  String? _source;
  String? _error;
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  bool _disposed = false;

  Stream<AudioPlaybackSnapshot> get snapshots => _snapshots.stream;
  AudioPlaybackSnapshot get current => AudioPlaybackSnapshot(
    status: _status,
    position: _player.position,
    duration: _player.duration ?? Duration.zero,
    source: _source,
    error: _error,
  );

  Future<void> load(String source) async {
    _ensureUsable();
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      throw const AudioPlaybackException('Audio source cannot be empty.');
    }
    if (_source == trimmed &&
        _status != AudioPlaybackStatus.error &&
        _status != AudioPlaybackStatus.idle) {
      return;
    }

    try {
      _status = AudioPlaybackStatus.loading;
      _error = null;
      _emit();
      await _player.stop();

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);

      _source = trimmed;
      await _player.setAudioSource(AudioSource.uri(_sourceUri(trimmed)));
      _status = AudioPlaybackStatus.ready;
      _emit();
    } catch (error) {
      final exception = AudioPlaybackException('Unable to load audio: $error');
      _setError(exception.message);
      throw exception;
    }
  }

  Future<void> play([String? source]) async {
    _ensureUsable();
    if (source != null && source.trim() != _source) await load(source);
    if (_source == null) {
      throw const AudioPlaybackException(
        'Load an audio source before playing.',
      );
    }

    try {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } catch (error) {
      final exception = AudioPlaybackException('Unable to play audio: $error');
      _setError(exception.message);
      throw exception;
    }
  }

  Future<void> pause() async {
    _ensureUsable();
    await _player.pause();
  }

  Future<void> toggle(String source) async {
    _ensureUsable();
    if (_source == source && _player.playing) {
      await pause();
    } else {
      await play(source);
    }
  }

  Future<void> seek(Duration position) async {
    _ensureUsable();
    final duration = _player.duration;
    final safePosition = duration == null || position <= duration
        ? position
        : duration;
    await _player.seek(safePosition.isNegative ? Duration.zero : safePosition);
  }

  Future<void> stop() async {
    _ensureUsable();
    await _player.stop();
    await _player.seek(Duration.zero);
    _status = _source == null
        ? AudioPlaybackStatus.idle
        : AudioPlaybackStatus.ready;
    _emit();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    _status = AudioPlaybackStatus.disposed;
    _emit();
    await _snapshots.close();
  }

  void _onPlayerState(PlayerState state) {
    if (_disposed) return;
    if (state.processingState == ProcessingState.completed) {
      _status = AudioPlaybackStatus.completed;
    } else if (state.processingState == ProcessingState.loading ||
        state.processingState == ProcessingState.buffering) {
      _status = AudioPlaybackStatus.loading;
    } else if (state.playing) {
      _status = AudioPlaybackStatus.playing;
    } else if (_source != null) {
      _status = _player.position > Duration.zero
          ? AudioPlaybackStatus.paused
          : AudioPlaybackStatus.ready;
    }
    _emit();
  }

  Uri _sourceUri(String source) {
    final uri = Uri.tryParse(source);
    // Already an absolute URL (http/https) → use as-is
    if (uri != null && uri.hasScheme) return uri;
    // Relative path (e.g. /uploads/file.ogg from old DB records)
    // → normalize using ApiConfig so it resolves against the correct server
    final normalized = ApiConfig.normalizeMediaUrl(source);
    if (normalized != null) {
      final normUri = Uri.tryParse(normalized);
      if (normUri != null && normUri.hasScheme) return normUri;
    }
    // Last resort: treat as local file (only valid on emulator/local)
    return Uri.file(File(source).absolute.path);
  }

  void _setError(String message) {
    _error = message;
    _status = AudioPlaybackStatus.error;
    _emit();
  }

  void _emit() {
    if (!_snapshots.isClosed) _snapshots.add(current);
  }

  void _ensureUsable() {
    if (_disposed) {
      throw const AudioPlaybackException(
        'Audio player has already been disposed.',
      );
    }
  }
}
