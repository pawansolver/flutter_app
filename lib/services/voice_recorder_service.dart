import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

enum VoiceRecorderStatus { idle, recording, paused, stopped, error, disposed }

class VoiceRecorderSnapshot {
  const VoiceRecorderSnapshot({
    required this.status,
    required this.duration,
    this.filePath,
    this.error,
  });

  final VoiceRecorderStatus status;
  final Duration duration;
  final String? filePath;
  final String? error;
}

class VoiceRecorderException implements Exception {
  const VoiceRecorderException(this.message, {this.settingsRequired = false});

  final String message;
  final bool settingsRequired;

  @override
  String toString() => message;
}

/// Owns one microphone recording session and its temporary output.
class VoiceRecorderService {
  factory VoiceRecorderService({
    AudioRecorder? recorder,
    Uuid uuid = const Uuid(),
  }) => VoiceRecorderService._(recorder ?? AudioRecorder(), uuid);

  VoiceRecorderService._(this._recorder, this._uuid);

  final AudioRecorder _recorder;
  final Uuid _uuid;
  final StreamController<VoiceRecorderSnapshot> _snapshots =
      StreamController<VoiceRecorderSnapshot>.broadcast();
  final Stopwatch _stopwatch = Stopwatch();

  Timer? _ticker;
  String? _filePath;
  VoiceRecorderStatus _status = VoiceRecorderStatus.idle;
  bool _disposed = false;

  Stream<VoiceRecorderSnapshot> get snapshots => _snapshots.stream;
  VoiceRecorderSnapshot get current => VoiceRecorderSnapshot(
    status: _status,
    duration: _stopwatch.elapsed,
    filePath: _filePath,
  );

  Future<void> start() async {
    _ensureUsable();
    if (_status == VoiceRecorderStatus.recording ||
        _status == VoiceRecorderStatus.paused) {
      throw const VoiceRecorderException('A recording is already active.');
    }

    try {
      if (!kIsWeb) {
        var permission = await Permission.microphone.status;
        if (permission.isDenied) {
          permission = await Permission.microphone.request();
        }
        if (!permission.isGranted) {
          final settingsRequired =
              permission.isPermanentlyDenied || permission.isRestricted;
          throw VoiceRecorderException(
            settingsRequired
                ? 'Microphone access is disabled. Enable it in app settings to '
                      'record voice notes.'
                : 'Microphone permission is required to record audio.',
            settingsRequired: settingsRequired,
          );
        }
      }
      if (!await _recorder.hasPermission(request: kIsWeb)) {
        throw const VoiceRecorderException(
          'Microphone access is unavailable on this device.',
          settingsRequired: false,
        );
      }

      final fileName = 'voice_${_uuid.v4()}.m4a';
      if (kIsWeb) {
        // The web recorder ignores this path and returns a blob: URL on stop.
        // path_provider intentionally has no web implementation.
        _filePath = fileName;
      } else {
        final directory = await getTemporaryDirectory();
        _filePath = path.join(directory.path, fileName);
      }
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _filePath!,
      );

      _stopwatch
        ..reset()
        ..start();
      _status = VoiceRecorderStatus.recording;
      _startTicker();
      _emit();
    } on VoiceRecorderException {
      _setError();
      rethrow;
    } catch (error) {
      final exception = VoiceRecorderException(
        'Unable to start recording: $error',
      );
      _setError(exception.message);
      throw exception;
    }
  }

  Future<void> pause() async {
    _ensureUsable();
    if (_status != VoiceRecorderStatus.recording) return;
    try {
      await _recorder.pause();
      _stopwatch.stop();
      _status = VoiceRecorderStatus.paused;
      _emit();
    } catch (error) {
      throw VoiceRecorderException('Unable to pause recording: $error');
    }
  }

  Future<void> resume() async {
    _ensureUsable();
    if (_status != VoiceRecorderStatus.paused) return;
    try {
      await _recorder.resume();
      _stopwatch.start();
      _status = VoiceRecorderStatus.recording;
      _emit();
    } catch (error) {
      throw VoiceRecorderException('Unable to resume recording: $error');
    }
  }

  Future<String?> stop() async {
    _ensureUsable();
    if (_status != VoiceRecorderStatus.recording &&
        _status != VoiceRecorderStatus.paused) {
      return _filePath;
    }
    try {
      final result = await _recorder.stop();
      _stopwatch.stop();
      _ticker?.cancel();
      _status = VoiceRecorderStatus.stopped;
      _filePath = result ?? _filePath;
      _emit();
      return _filePath;
    } catch (error) {
      final exception = VoiceRecorderException(
        'Unable to finish recording: $error',
      );
      _setError(exception.message);
      throw exception;
    }
  }

  Future<void> cancel() async {
    _ensureUsable();
    try {
      if (_status == VoiceRecorderStatus.recording ||
          _status == VoiceRecorderStatus.paused) {
        await _recorder.cancel();
      }
      final filePath = _filePath;
      if (!kIsWeb && filePath != null) {
        final file = File(filePath);
        if (await file.exists()) await file.delete();
      }
      _ticker?.cancel();
      _stopwatch
        ..stop()
        ..reset();
      _filePath = null;
      _status = VoiceRecorderStatus.idle;
      _emit();
    } catch (error) {
      throw VoiceRecorderException('Unable to cancel recording: $error');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _ticker?.cancel();
    if (_status == VoiceRecorderStatus.recording ||
        _status == VoiceRecorderStatus.paused) {
      await _recorder.cancel();
    }
    await _recorder.dispose();
    _stopwatch.stop();
    _disposed = true;
    _status = VoiceRecorderStatus.disposed;
    _emit();
    await _snapshots.close();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_status == VoiceRecorderStatus.recording) _emit();
    });
  }

  void _setError([String? message]) {
    _ticker?.cancel();
    _stopwatch.stop();
    _status = VoiceRecorderStatus.error;
    _emit(error: message);
  }

  void _emit({String? error}) {
    if (_snapshots.isClosed) return;
    _snapshots.add(
      VoiceRecorderSnapshot(
        status: _status,
        duration: _stopwatch.elapsed,
        filePath: _filePath,
        error: error,
      ),
    );
  }

  void _ensureUsable() {
    if (_disposed) {
      throw const VoiceRecorderException(
        'Voice recorder has already been disposed.',
      );
    }
  }
}
