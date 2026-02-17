// lib/services/audio_player_service.dart - OPTIMIZED FOR PHONE & ESP32
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

enum AudioPlayerState { stopped, loading, playing, paused, error }

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal() {
    _initializePlayer();
  }

  final AudioPlayer _player = AudioPlayer();

  AudioPlayerState _state = AudioPlayerState.stopped;
  String? _currentFilePath;
  String? _currentFileName;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;
  String? _errorMessage;

  // Getters
  AudioPlayerState get state => _state;
  String? get currentFilePath => _currentFilePath;
  String? get currentFileName => _currentFileName;
  Duration get duration => _duration;
  Duration get position => _position;
  double get volume => _volume;
  double get speed => _speed;
  String? get errorMessage => _errorMessage;

  bool get isPlaying => _state == AudioPlayerState.playing;
  bool get isPaused => _state == AudioPlayerState.paused;
  bool get isLoading => _state == AudioPlayerState.loading;
  bool get hasError => _state == AudioPlayerState.error;
  bool get hasAudio => _currentFilePath != null;
  String? get currentlyPlayingFile => _currentFilePath;

  double get progress {
    if (_duration.inMilliseconds == 0) return 0.0;
    final prog = _position.inMilliseconds / _duration.inMilliseconds;
    return prog.isNaN || prog.isInfinite ? 0.0 : prog.clamp(0.0, 1.0);
  }

  String get formattedPosition => _formatDuration(_position);
  String get formattedDuration => _formatDuration(_duration);

  bool isActiveFile(String? filePath) => _currentFilePath == filePath;
  bool isFileLoaded(String filePath) => _currentFilePath == filePath;

  // 👈 IMPROVED: Smart toggle - same file = pause/play, different file = load new
  Future<void> togglePlayback(String filePath) async {
    if (_currentFilePath == filePath) {
      // Same file - just toggle play/pause
      await togglePlayPause();
    } else {
      // Different file - load and play
      final fileName = filePath.split('/').last;
      await playAudio(filePath, fileName);
    }
  }

  void _initializePlayer() {
    _player.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    _player.durationStream.listen((duration) {
      if (duration != null && duration.inMilliseconds > 0) {
        _duration = duration;
        notifyListeners();
      }
    });

    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;

      switch (processingState) {
        case ProcessingState.idle:
          _setState(AudioPlayerState.stopped);
          break;
        case ProcessingState.loading:
        case ProcessingState.buffering:
          _setState(AudioPlayerState.loading);
          break;
        case ProcessingState.ready:
          _setState(isPlaying ? AudioPlayerState.playing : AudioPlayerState.paused);
          break;
        case ProcessingState.completed:
          _setState(AudioPlayerState.stopped);
          _position = Duration.zero;
          notifyListeners();
          break;
      }
    });
  }

  // 👈 MAIN PLAY METHOD - Works for both phone and ESP32
  Future<void> playAudio(String filePath, String fileName) async {
    try {
      debugPrint('🎵 Playing: $filePath');

      // If same file and stopped, restart
      if (_currentFilePath == filePath && _state == AudioPlayerState.stopped) {
        await _player.seek(Duration.zero);
        await _player.play();
        return;
      }

      // If same file is playing/paused, toggle
      if (_currentFilePath == filePath &&
          (_state == AudioPlayerState.paused || _state == AudioPlayerState.playing)) {
        await togglePlayPause();
        return;
      }

      _setState(AudioPlayerState.loading);
      _currentFilePath = filePath;
      _currentFileName = fileName;
      _errorMessage = null;

      _duration = Duration.zero;
      _position = Duration.zero;
      notifyListeners();

      await _player.stop();
      await _player.setVolume(_volume);

      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found');
      }

      final fileSize = await file.length();
      debugPrint('🎵 File size: ${_formatBytes(fileSize)}');

      if (fileSize < 1000) {
        throw Exception('File too small (corrupted?)');
      }

      // Try loading with fallback methods
      bool loaded = false;

      try {
        await _player.setFilePath(filePath);
        loaded = true;
        debugPrint('✅ Loaded with setFilePath');
      } catch (e) {
        debugPrint('⚠️ setFilePath failed, trying setUrl...');
        try {
          await _player.setUrl(Uri.file(filePath).toString());
          loaded = true;
          debugPrint('✅ Loaded with setUrl');
        } catch (e2) {
          debugPrint('⚠️ setUrl failed, trying setAudioSource...');
          await _player.setAudioSource(AudioSource.file(filePath));
          loaded = true;
          debugPrint('✅ Loaded with setAudioSource');
        }
      }

      if (!loaded) {
        throw Exception('Could not load audio file');
      }

      await _player.play();
      debugPrint('✅ Playback started');

    } catch (e) {
      debugPrint('❌ Playback failed: $e');
      _errorMessage = 'Playback error: $e';
      _setState(AudioPlayerState.error);
      rethrow;
    }
  }

  Future<void> play(String filePath) async {
    final fileName = filePath.split('/').last;
    await playAudio(filePath, fileName);
  }

  Future<void> togglePlayPause() async {
    try {
      if (_state == AudioPlayerState.playing) {
        await _player.pause();
      } else if (_state == AudioPlayerState.paused) {
        await _player.play();
      } else if (_state == AudioPlayerState.stopped && _currentFilePath != null) {
        await _player.seek(Duration.zero);
        await _player.play();
      }
    } catch (e) {
      debugPrint('❌ Toggle error: $e');
      _setState(AudioPlayerState.error);
    }
  }

  Future<void> pause() async {
    try {
      if (isPlaying) {
        await _player.pause();
      }
    } catch (e) {
      debugPrint('❌ Pause error: $e');
    }
  }

  Future<void> pauseAudio() async => await pause();

  Future<void> resumeAudio() async {
    try {
      if (_state == AudioPlayerState.paused) {
        await _player.play();
      }
    } catch (e) {
      debugPrint('❌ Resume error: $e');
    }
  }

  Future<void> stopAudio() async {
    try {
      await _player.stop();
      _position = Duration.zero;
      _setState(AudioPlayerState.stopped);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Stop error: $e');
    }
  }

  Future<void> stopPlayback() async => await stopAudio();

  Future<void> clearAudio() async {
    try {
      await _player.stop();
      _currentFilePath = null;
      _currentFileName = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _errorMessage = null;
      _setState(AudioPlayerState.stopped);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Clear error: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
      _position = position;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Seek error: $e');
    }
  }

  Future<void> skipForward([Duration duration = const Duration(seconds: 5)]) async {
    final newPosition = _position + duration;
    final maxPosition = _duration.inMilliseconds > 0 ? _duration : Duration(seconds: 300);
    await seekTo(newPosition > maxPosition ? maxPosition : newPosition);
  }

  Future<void> skipBackward([Duration duration = const Duration(seconds: 5)]) async {
    final newPosition = _position - duration;
    await seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  Future<void> setVolume(double newVolume) async {
    try {
      _volume = newVolume.clamp(0.0, 1.0);
      await _player.setVolume(_volume);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Volume error: $e');
    }
  }

  Future<void> setPlaybackSpeed(double newSpeed) async {
    try {
      _speed = newSpeed.clamp(0.25, 4.0);
      await _player.setSpeed(_speed);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Speed error: $e');
    }
  }

  void _setState(AudioPlayerState newState) {
    if (_state != newState) {
      debugPrint('🎵 ${_state.name} → ${newState.name}');
      _state = newState;
      notifyListeners();
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inMilliseconds <= 0) return '0:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      final hours = twoDigits(duration.inHours);
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> get playbackState => {
    'isPlaying': isPlaying,
    'isLoading': isLoading,
    'isPaused': isPaused,
    'currentFile': _currentFilePath,
    'fileName': _currentFileName,
    'position': _position.inSeconds,
    'duration': _duration.inSeconds,
    'progress': progress,
    'volume': _volume,
    'speed': _speed,
  };

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}