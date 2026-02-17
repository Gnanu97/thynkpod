import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PhoneRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  bool get isRecording => _isRecording;

  // Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();

    if (status.isPermanentlyDenied) {
      openAppSettings();
      return false;
    }

    return status.isGranted;
  }

  // Start recording
  Future<String?> startRecording() async {
    try {
      // Check permission
      if (!await _recorder.hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          return null;
        }
      }

      // Get app directory
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');

      // Create recordings directory if it doesn't exist
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${recordingsDir.path}/recording_$timestamp.wav';

      // Start recording with WAV format (16kHz, 16-bit, mono - matching ESP32)
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 128000,
          numChannels: 1, // Mono recording
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      print('📱 Phone recording started: $_currentRecordingPath');
      return _currentRecordingPath;

    } catch (e) {
      print('❌ Failed to start recording: $e');
      return null;
    }
  }

  // Stop recording and return file info
  Future<Map<String, dynamic>?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      final path = await _recorder.stop();
      _isRecording = false;

      if (path == null || _recordingStartTime == null) return null;

      // Get file info
      final file = File(path);
      final fileSize = await file.length();
      final duration = DateTime.now().difference(_recordingStartTime!).inSeconds;
      final fileName = path.split('/').last;

      print('📱 Phone recording stopped: $fileName');
      print('📊 Size: ${fileSize} bytes, Duration: ${duration}s');

      return {
        'fileName': fileName,
        'filePath': path,
        'fileSize': fileSize,
        'duration': duration,
        'source': 'phone',
      };

    } catch (e) {
      print('❌ Failed to stop recording: $e');
      return null;
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.cancel();
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;
    }
  }

  // Get recording duration while recording
  Stream<Duration>? getRecordingStream() {
    if (_recordingStartTime == null) return null;

    return Stream.periodic(const Duration(milliseconds: 100), (_) {
      return DateTime.now().difference(_recordingStartTime!);
    });
  }

  // Dispose recorder
  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
