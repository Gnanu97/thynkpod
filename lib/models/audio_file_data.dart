// lib/models/audio_file_data.dart - COMPLETE FIXED FILE
class AudioFileData {
  final int? id;
  final String filename;
  String? displayName;
  final String filePath;
  final int fileSizeBytes;
  final double? durationSeconds;

  final String? transcript;
  final String? aiAnalysis;
  String? title;

  final bool hasTranscript;
  final bool hasAIAnalysis;

  final DateTime createdAt;
  final DateTime updatedAt;

  AudioFileData({
    this.id,
    required this.filename,
    this.displayName,
    required this.filePath,
    required this.fileSizeBytes,
    this.durationSeconds,
    this.transcript,
    this.aiAnalysis,
    this.title,
    required this.hasTranscript,
    required this.hasAIAnalysis,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AudioFileData.fromMap(Map<String, dynamic> map) {
    return AudioFileData(
      id: map['id'] as int?,
      filename: map['filename'] as String,
      displayName: map['display_name'] as String?,
      filePath: map['file_path'] as String,
      fileSizeBytes: map['file_size_bytes'] as int,
      durationSeconds: map['duration_seconds'] as double?,
      transcript: map['transcript'] as String?,
      aiAnalysis: map['ai_analysis'] as String?,
      title: map['title'] as String?,
      hasTranscript: (map['has_transcript'] as int? ?? 0) == 1,
      hasAIAnalysis: (map['has_ai_analysis'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filename': filename,
      'display_name': displayName,
      'file_path': filePath,
      'file_size_bytes': fileSizeBytes,
      'duration_seconds': durationSeconds,
      'transcript': transcript,
      'ai_analysis': aiAnalysis,
      'title': title,
      'has_transcript': hasTranscript ? 1 : 0,
      'has_ai_analysis': hasAIAnalysis ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AudioFileData.fromFileInfo({
    required String filename,
    required String filePath,
    required int fileSizeBytes,
    required double durationSeconds,
    String? displayName,
  }) {
    final now = DateTime.now();
    return AudioFileData(
      filename: filename,
      displayName: displayName ?? filename,
      filePath: filePath,
      fileSizeBytes: fileSizeBytes,
      durationSeconds: durationSeconds,
      title: null,
      hasTranscript: false,
      hasAIAnalysis: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  AudioFileData copyWith({
    int? id,
    String? filename,
    String? displayName,
    String? filePath,
    int? fileSizeBytes,
    double? durationSeconds,
    String? transcript,
    String? aiAnalysis,
    String? title,
    bool? hasTranscript,
    bool? hasAIAnalysis,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AudioFileData(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      displayName: displayName ?? this.displayName,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      transcript: transcript ?? this.transcript,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      title: title ?? this.title,
      hasTranscript: hasTranscript ?? this.hasTranscript,
      hasAIAnalysis: hasAIAnalysis ?? this.hasAIAnalysis,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // FIX: Add missing getters
  String get displayTitle {
    if (title != null && title!.isNotEmpty) {
      return title!;
    }
    if (displayName != null && displayName!.isNotEmpty && displayName != filename) {
      return displayName!;
    }
    return 'Voice Note';
  }

  bool get isReadyForNotes {
    return hasTranscript && hasAIAnalysis && filePath.isNotEmpty;
  }

  // FIX: Add these missing getters
  bool get isFullyProcessed => hasTranscript && hasAIAnalysis;
  String get effectiveDisplayName => displayName ?? filename;

  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '${fileSizeBytes}B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  String get formattedDuration {
    if (durationSeconds == null) return '0:00';

    final duration = Duration(seconds: durationSeconds!.round());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileExtension {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  bool get isAudioFile {
    final audioExtensions = ['wav', 'mp3', 'm4a', 'aac', 'ogg', 'flac'];
    return audioExtensions.contains(fileExtension);
  }

  String get audioCodec {
    switch (fileExtension) {
      case 'wav': return 'WAV';
      case 'mp3': return 'MP3';
      case 'm4a': return 'AAC';
      case 'aac': return 'AAC';
      case 'ogg': return 'OGG';
      case 'flac': return 'FLAC';
      default: return 'AUDIO';
    }
  }

  String get processingStatus {
    if (hasTranscript && hasAIAnalysis) return 'Complete';
    if (hasTranscript) return 'Transcript Ready';
    return 'Pending';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
    }
  }

  @override
  String toString() {
    return 'AudioFileData{filename: $filename, title: $title, hasTranscript: $hasTranscript, hasAIAnalysis: $hasAIAnalysis}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioFileData && other.filename == filename;
  }

  @override
  int get hashCode => filename.hashCode;
}