// lib/services/speech_to_text_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SpeechToTextService {
  // GROQ WHISPER CONFIG
  static const String _apiKey =
      '';
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const String _model = 'whisper-large-v3-turbo';

  Future<String> transcribe(String audioFilePath) async {
    return await transcribeAudio(audioFilePath);
  }

  Future<String> transcribeAudio(String audioFilePath) async {
    try {
      debugPrint('Starting Groq transcription for: $audioFilePath');

      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $audioFilePath');
      }

      final fileSize = await file.length();
      debugPrint('File size: ${_formatFileSize(fileSize)}');

      // Safety limit for Whisper on Groq (adjust if needed)
      if (fileSize > 25 * 1024 * 1024) {
        throw Exception('File too large for transcription (max 25MB)');
      }

      if (fileSize == 0) {
        throw Exception('Audio file is empty');
      }

      // Groq Whisper expects multipart/form‑data similar to your curl:
      // curl ... -F "model=whisper-large-v3-turbo" -F "file=@./audio.m4a" ...
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_baseUrl),
      )
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = _model
        ..fields['temperature'] = '0'
        ..fields['response_format'] = 'verbose_json'
        ..files.add(await http.MultipartFile.fromPath('file', audioFilePath));

      debugPrint('Sending request to Groq Whisper API...');

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw Exception('Transcription request timed out after 2 minutes');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('Groq API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData =
        jsonDecode(response.body) as Map<String, dynamic>;

        // For verbose_json Groq follows Whisper: main text in `text`
        final text = (responseData['text'] ?? '').toString().trim();
        if (text.isEmpty) {
          return 'No clear speech detected in this audio file. Please ensure the audio contains clear speech and try again.';
        }

        debugPrint('Transcription completed successfully');
        debugPrint('Transcript length: ${text.length} characters');
        return text;
      } else {
        final errorBody = response.body;
        debugPrint('Groq API Error: ${response.statusCode} - $errorBody');
        throw Exception(
            'Groq Whisper API error (${response.statusCode}): $errorBody');
      }
    } catch (e) {
      debugPrint('Transcription error: $e');

      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('TimeoutException') ||
          msg.contains('HandshakeException')) {
        throw Exception(
            'Network error: Please check your internet connection and try again.');
      } else if (msg.contains('401') || msg.contains('403')) {
        throw Exception(
            'Groq API authentication failed: Please check your API key.');
      } else if (msg.contains('429')) {
        throw Exception(
            'Rate limit exceeded: Please wait a moment and try again.');
      } else if (msg.contains('413')) {
        throw Exception('File too large: Please use a smaller audio file.');
      } else {
        throw Exception('Transcription failed: $e');
      }
    }
  }

  // --- helpers kept from your original code ---

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // These format helpers are still useful for validation / UI if you use them elsewhere:
  List<String> get supportedFormats => [
    'wav',
    'flac',
    'mp3',
    'ogg',
    'm4a',
    'aac',
    'webm',
  ];

  bool isSupportedFormat(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return supportedFormats.contains(extension);
  }

  String get formatRequirements => '''
Supported audio formats:
• WAV (recommended for best quality)
• FLAC (lossless compression)
• MP3 (compressed, widely supported)
• OGG (open source format)
• M4A/AAC (Apple format)
• WebM (web optimized)

Requirements:
• Maximum file size: ~25 MB
• Sample rate: 8–48 kHz (16 kHz recommended)
• Audio should contain clear speech
• Avoid background noise for best results
''';

  bool get isConfigured => _apiKey.isNotEmpty;
}
