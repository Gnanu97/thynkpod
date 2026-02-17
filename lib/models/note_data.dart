// lib/models/note_data.dart - COMPLETE FILE
import 'audio_file_data.dart';

class NoteData {
  final String id;
  final String title;
  final String filename;
  final String filePath;
  final String transcript;
  final String summary;
  final DateTime createdAt;
  final double? durationSeconds;
  final int fileSizeBytes;

  NoteData({
    required this.id,
    required this.title,
    required this.filename,
    required this.filePath,
    required this.transcript,
    required this.summary,
    required this.createdAt,
    this.durationSeconds,
    required this.fileSizeBytes,
  });

  // Create NoteData from AudioFileData
  factory NoteData.fromAudioFile(AudioFileData audioFile, String generatedTitle) {
    return NoteData(
      id: audioFile.filename, // Use filename as unique ID
      title: generatedTitle.isNotEmpty ? generatedTitle : 'Voice Note',
      filename: audioFile.filename,
      filePath: audioFile.filePath,
      transcript: audioFile.transcript ?? '',
      summary: audioFile.aiAnalysis ?? '',
      createdAt: audioFile.createdAt,
      durationSeconds: audioFile.durationSeconds,
      fileSizeBytes: audioFile.fileSizeBytes,
    );
  }

  // Helper method to get formatted date
  String get formattedDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  // Helper method to get formatted time
  String get formattedTime {
    final hour = createdAt.hour;
    final minute = createdAt.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
  }

  // Helper method to get formatted duration
  String get formattedDuration {
    if (durationSeconds == null) return '0:00';

    final duration = Duration(seconds: durationSeconds!.round());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  // Helper method to get formatted file size
  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '${fileSizeBytes}B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  // Helper method to get transcript preview (first 2 lines)
  String get transcriptPreview {
    final lines = transcript.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 'No transcript available';

    if (lines.length == 1) return lines.first;
    return '${lines.first}\n${lines.length > 1 ? lines[1] : ''}';
  }

  // Helper method to get summary preview (first paragraph)
  String get summaryPreview {
    final sentences = summary.split('.').where((s) => s.trim().isNotEmpty).toList();
    if (sentences.isEmpty) return 'No summary available';

    return '${sentences.first.trim()}.';
  }

  // Helper method to check if note has audio file
  bool get hasAudioFile {
    return filePath.isNotEmpty;
  }

  // Helper method to get audio file extension
  String get audioFileExtension {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'AUDIO';
  }

  // Helper method to get relative time (e.g., "2 hours ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return formattedDate;
    }
  }

  @override
  String toString() {
    return 'NoteData{id: $id, title: $title, filename: $filename}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteData && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}