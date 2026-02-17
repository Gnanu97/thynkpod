// lib/models/esp32_file_model.dart
class Esp32File {
  final String name;
  final String size;
  final DateTime dateCreated;
  final String formatType; // mp3, wav, etc.
  final bool isDownloaded;
  final String? localPath;

  Esp32File({
    required this.name,
    required this.size,
    required this.dateCreated,
    required this.formatType,
    this.isDownloaded = false,
    this.localPath,
  });

  // Get file size in bytes for comparison
  int get sizeInBytes {
    final parts = size.split(' ');
    final value = double.parse(parts[0]);
    final unit = parts[1].toLowerCase();

    switch (unit) {
      case 'kb':
        return (value * 1024).round();
      case 'mb':
        return (value * 1024 * 1024).round();
      case 'gb':
        return (value * 1024 * 1024 * 1024).round();
      default:
        return value.round();
    }
  }

  // Get estimated duration based on file size (rough estimate for MP3)
  String get estimatedDuration {
    final bytes = sizeInBytes;
    final estimatedSeconds = (bytes / 16000).round(); // Rough MP3 estimation
    final minutes = estimatedSeconds ~/ 60;
    final seconds = estimatedSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  // Get file extension
  String get extension {
    return name.split('.').last.toLowerCase();
  }

  // Check if it's an audio file
  bool get isAudioFile {
    const audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a'];
    return audioExtensions.contains(extension);
  }

  // Format file creation time
  String get formattedDateTime {
    return '${dateCreated.day.toString().padLeft(2, '0')}/${dateCreated.month.toString().padLeft(2, '0')}/${dateCreated.year}  ${dateCreated.hour.toString().padLeft(2, '0')}:${dateCreated.minute.toString().padLeft(2, '0')}';
  }

  // Create copy with updated fields
  Esp32File copyWith({
    String? name,
    String? size,
    DateTime? dateCreated,
    String? formatType,
    bool? isDownloaded,
    String? localPath,
  }) {
    return Esp32File(
      name: name ?? this.name,
      size: size ?? this.size,
      dateCreated: dateCreated ?? this.dateCreated,
      formatType: formatType ?? this.formatType,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
    );
  }

  // Convert from simple filename to file object
  static Esp32File fromFilename(String filename) {
    return Esp32File(
      name: filename,
      size: '1.2 MB', // Default size - will be updated from ESP32
      dateCreated: DateTime.now(),
      formatType: filename.split('.').last.toLowerCase(),
    );
  }
}