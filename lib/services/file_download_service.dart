// lib/services/file_download_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/esp32_file_model.dart';
import 'ble_service.dart';

class FileDownloadService {
  final BleService _bleService;

  bool _isDownloading = false;
  String? _currentFilename;
  List<int> _receivedData = [];
  DateTime? _downloadStartTime;
  StreamSubscription? _dataSubscription;
  Timer? _timeoutTimer;
  Timer? _noDataTimer;
  Timer? _completionTimer;

  // Progress callbacks
  Function(double progress, String speed, String timeRemaining)? onProgress;
  Function(String filename, String localPath)? onComplete;
  Function(String error)? onError;

  FileDownloadService(this._bleService);

  bool get isDownloading => _isDownloading;

  Future<void> downloadFile(Esp32File file) async {
    if (_isDownloading) {
      throw Exception('Download already in progress');
    }

    try {
      _initializeDownload(file.name);
      _setupFixedDataListener();

      await Future.delayed(const Duration(milliseconds: 500));

      await _bleService.requestFile(file.name);

      _startTimeoutTimer();
      _startNoDataTimer();

    } catch (e) {
      _handleError('Failed to start download: $e');
    }
  }

  void _initializeDownload(String filename) {
    _isDownloading = true;
    _currentFilename = filename;
    _receivedData.clear();
    _downloadStartTime = DateTime.now();
  }

  void _setupFixedDataListener() {
    final dataStream = _bleService.fileDataStream;
    if (dataStream == null) {
      _handleError('File data stream not available');
      return;
    }

    _dataSubscription = dataStream.listen(
          (data) {
        if (!_isDownloading) {
          return;
        }

        _resetNoDataTimer();
        _completionTimer?.cancel();

        if (_isDefiniteCompletionMarker(data)) {
          if (_receivedData.isNotEmpty) {
            _completionTimer = Timer(Duration(milliseconds: 200), () {
              if (_isDownloading) {
                _completeTransfer();
              }
            });
          } else {
            _handleError('No data received from ESP32');
          }
          return;
        }

        if (_isValidAudioData(data)) {
          _receivedData.addAll(data);

          _resetTimeoutTimer();
          _updateProgress();

          if (data.length < 100 && _receivedData.length > 50000) {
            _completionTimer = Timer(Duration(milliseconds: 500), () {
              if (_isDownloading && _receivedData.isNotEmpty) {
                _completeTransfer();
              }
            });
          }
        }
      },
      onError: (error) {
        _handleError('Data stream error: $error');
      },
      onDone: () {
        if (_isDownloading && _receivedData.isNotEmpty) {
          _completeTransfer();
        }
      },
      cancelOnError: false,
    );
  }

  bool _isDefiniteCompletionMarker(List<int> data) {
    if (data.isEmpty) {
      return true;
    }

    if (data.length == 1) {
      if (data[0] == 0xFF || data[0] == 0x00 || data[0] == 0xEE) {
        return true;
      }
    }

    try {
      final String dataString = String.fromCharCodes(data);
      if (dataString.contains('COMPLETE') ||
          dataString.contains('END_OF_FILE') ||
          dataString.contains('TRANSFER_DONE') ||
          (dataString.contains('EOF') && dataString.length < 10)) {
        return true;
      }
    } catch (e) {
      // Not text data, continue
    }

    return false;
  }

  bool _isValidAudioData(List<int> data) {
    if (data.isEmpty) return false;

    if (_receivedData.isEmpty) {
      if (data.length >= 4) {
        final header = String.fromCharCodes(data.take(4));
        if (header == 'RIFF') {
          return true;
        } else {
          return false;
        }
      }
    }

    final textBytes = data.where((b) => b >= 32 && b <= 126).length;
    final textRatio = textBytes / data.length;

    if (textRatio > 0.7 && data.length > 20) {
      return false;
    }

    return true;
  }

  void _startNoDataTimer() {
    _noDataTimer = Timer(Duration(seconds: 15), () {
      if (_isDownloading && _receivedData.isEmpty) {
        _handleError('ESP32 not sending data - check connection');
      }
    });
  }

  void _resetNoDataTimer() {
    _noDataTimer?.cancel();
    if (_isDownloading) {
      _startNoDataTimer();
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(Duration(seconds: 60), () {
      if (_isDownloading) {
        if (_receivedData.isNotEmpty) {
          _completeTransfer();
        } else {
          _handleError('Download timeout - ESP32 not responding');
        }
      }
    });
  }

  void _resetTimeoutTimer() {
    _timeoutTimer?.cancel();
    _startTimeoutTimer();
  }

  void _updateProgress() {
    if (_downloadStartTime == null) return;

    final elapsed = DateTime.now().difference(_downloadStartTime!);
    final elapsedSeconds = elapsed.inMilliseconds / 1000.0;

    final bytesPerSecond = elapsedSeconds > 0 ? _receivedData.length / elapsedSeconds : 0.0;
    final speed = _formatSpeed(bytesPerSecond);

    final expectedSize = 150000;
    final progress = (_receivedData.length / expectedSize).clamp(0.0, 0.95);

    String timeRemaining = 'Calculating...';
    if (bytesPerSecond > 10) {
      final remainingBytes = expectedSize - _receivedData.length;
      final estimatedSecondsRemaining = (remainingBytes / bytesPerSecond).clamp(0.0, 300.0);
      timeRemaining = _formatTime(estimatedSecondsRemaining);
    }

    onProgress?.call(progress, speed, timeRemaining);
  }

  Future<void> _completeTransfer() async {
    if (!_isDownloading) {
      return;
    }

    if (_receivedData.isEmpty) {
      _handleError('No data received from ESP32');
      return;
    }

    if (_receivedData.length < 1000) {
      final asText = String.fromCharCodes(_receivedData.where((b) => b >= 32 && b <= 126));
      if (asText.contains('ERROR') || asText.contains('TEST') || asText.contains('FAIL')) {
        _handleError('Received error response instead of file data: $asText');
        return;
      }
    }

    if (_receivedData.length >= 12) {
      final riffHeader = String.fromCharCodes(_receivedData.take(4));
      final waveHeader = String.fromCharCodes(_receivedData.skip(8).take(4));

      if (riffHeader != 'RIFF' || waveHeader != 'WAVE') {
        _handleError('Received corrupted file data - not a valid WAV file');
        return;
      }
    }

    final filename = _currentFilename;
    if (filename == null || filename.isEmpty) {
      _handleError('Invalid filename during completion');
      return;
    }

    try {
      final Uint8List fileData = Uint8List.fromList(_receivedData);
      final String localPath = await _saveToLocalStorage(filename, fileData);

      onProgress?.call(1.0, _formatSpeed(_receivedData.length.toDouble()), 'Complete');

      await Future.delayed(const Duration(milliseconds: 300));

      final completedFilename = filename;
      final completedPath = localPath;

      _cleanup();

      onComplete?.call(completedFilename, completedPath);

    } catch (e) {
      _handleError('Failed to save file: $e');
    }
  }

  Future<String> _saveToLocalStorage(String filename, Uint8List data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/downloads');

      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final file = File('${downloadsDir.path}/$filename');
      await file.writeAsBytes(data);

      final savedFile = File(file.path);
      if (await savedFile.exists()) {
        final savedSize = await savedFile.length();
        return file.path;
      } else {
        throw Exception('File was not saved properly');
      }
    } catch (e) {
      rethrow;
    }
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toInt()} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String _formatTime(double seconds) {
    if (seconds < 60) {
      return '${seconds.toInt()} sec';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).toInt();
      return '$minutes min ${(seconds % 60).toInt()} sec';
    } else {
      return '5+ min';
    }
  }

  void _handleError(String error) {
    _cleanup();
    onError?.call(error);
  }

  void _cleanup() {
    _isDownloading = false;
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _noDataTimer?.cancel();
    _noDataTimer = null;
    _completionTimer?.cancel();
    _completionTimer = null;

    Future.delayed(const Duration(milliseconds: 100), () {
      _currentFilename = null;
      _receivedData.clear();
      _downloadStartTime = null;
    });
  }

  void cancelDownload() {
    if (_isDownloading) {
      _cleanup();
    }
  }
}