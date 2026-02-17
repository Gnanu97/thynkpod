// lib/services/audio_player_service.dart - COMPLETE REPLACEMENT FILE
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerService extends ChangeNotifier {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _currentFilePath;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  double _volume = 1.0;

  AudioPlayerService() {
    _initializePlayer();
  }

  // Required getters for Notes widgets
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get currentlyPlayingFile => _currentFilePath;
  double get position => _position.inSeconds.toDouble();
  Duration get positionDuration => _position;
  Duration get durationTotal => _duration;
  double get speed => _speed;
  double get volume => _volume;

  double get progress {
    if (_duration.inMilliseconds > 0) {
      return _position.inMilliseconds / _duration.inMilliseconds;
    }
    return 0.0;
  }

  String get formattedPosition => _formatDuration(_position);
  String get formattedDuration => _formatDuration(_duration);

  void _initializePlayer() {
    _audioPlayer = AudioPlayer();

    // Listen to position changes
    _audioPlayer!.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    // Listen to duration changes
    _audioPlayer!.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    // Listen to player state changes
    _audioPlayer!.playerStateStream.listen((state) {
      final wasPlaying = _isPlaying;
      _isPlaying = state.playing;
      _isLoading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      // Handle completion
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _position = Duration.zero;
      }

      // Only notify if something actually changed
      if (wasPlaying != _isPlaying || _isLoading) {
        notifyListeners();
      }
    });
  }

  // Required method: play
  Future<void> play(String filePath) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Initialize player if not already done
      if (_audioPlayer == null) {
        _initializePlayer();
      }

      // Stop current playback if playing different file
      if (_currentFilePath != filePath && _isPlaying) {
        await _audioPlayer!.stop();
      }

      _currentFilePath = filePath;
      debugPrint('Playing audio file: $filePath');

      // Load and play the file
      await _audioPlayer!.setFilePath(filePath);
      await _audioPlayer!.play();

      _isPlaying = true;
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _isPlaying = false;
      _currentFilePath = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Required method: pause
  Future<void> pause() async {
    try {
      if (_audioPlayer != null && _isPlaying) {
        await _audioPlayer!.pause();
        _isPlaying = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error pausing audio: $e');
    }
  }

  // Required method: seek
  Future<void> seek(Duration position) async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.seek(position);
        _position = position;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error seeking audio: $e');
    }
  }

  // Required method: setPlaybackSpeed
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.setSpeed(speed);
        _speed = speed;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error setting playback speed: $e');
    }
  }

  // Additional methods for complete functionality
  Future<void> resume() async {
    try {
      if (_audioPlayer != null && !_isPlaying) {
        await _audioPlayer!.play();
        _isPlaying = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error resuming audio: $e');
    }
  }

  Future<void> stop() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        _isPlaying = false;
        _currentFilePath = null;
        _position = Duration.zero;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error stopping audio: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.setVolume(volume.clamp(0.0, 1.0));
        _volume = volume.clamp(0.0, 1.0);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  void skipForward([Duration? duration]) {
    final skipDuration = duration ?? const Duration(seconds: 10);
    final newPosition = _position + skipDuration;
    if (newPosition < _duration) {
      seek(newPosition);
    } else {
      seek(_duration);
    }
  }

  void skipBackward([Duration? duration]) {
    final skipDuration = duration ?? const Duration(seconds: 10);
    final newPosition = _position - skipDuration;
    if (newPosition > Duration.zero) {
      seek(newPosition);
    } else {
      seek(Duration.zero);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  // Method to check if a specific file is currently loaded
  bool isFileLoaded(String filePath) {
    return _currentFilePath == filePath;
  }

  // Method to get current playback state info
  Map<String, dynamic> get playbackState {
    return {
      'isPlaying': _isPlaying,
      'isLoading': _isLoading,
      'currentFile': _currentFilePath,
      'position': _position.inSeconds,
      'duration': _duration.inSeconds,
      'progress': progress,
      'speed': _speed,
      'volume': _volume,
    };
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }
}