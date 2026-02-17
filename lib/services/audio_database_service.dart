// lib/services/audio_database_service.dart - ENHANCED WITH PHONE RECORDING SUPPORT
import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/audio_file_data.dart';

class AudioDatabaseService extends ChangeNotifier {
  static Database? _database;
  static final AudioDatabaseService _instance = AudioDatabaseService._internal();
  factory AudioDatabaseService() => _instance;
  AudioDatabaseService._internal();

  // Table names
  static const String _audioTable = 'audio_files';
  static const String _transcriptTable = 'transcripts';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // UPDATED: Database initialization with migration support for source field
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'audio_files.db');

    return await openDatabase(
      path,
      version: 4, // 👈 Increment version to add source field
      onCreate: _createDatabase,
      onUpgrade: _migrateDatabase,
    );
  }

  // UPDATED: Create database with title, source columns and transcripts table
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_audioTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT UNIQUE NOT NULL,
        display_name TEXT,
        file_path TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL,
        duration_seconds REAL,
        
        source TEXT DEFAULT 'esp32',
        
        transcript TEXT,
        ai_analysis TEXT,
        title TEXT,
        
        has_transcript INTEGER DEFAULT 0,
        has_ai_analysis INTEGER DEFAULT 0,
        
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Transcripts table for better querying
    await db.execute('''
      CREATE TABLE $_transcriptTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audio_file_id INTEGER NOT NULL,
        transcript TEXT NOT NULL,
        confidence REAL DEFAULT 0.0,
        created_at INTEGER NOT NULL,
        date_only TEXT NOT NULL,
        FOREIGN KEY (audio_file_id) REFERENCES $_audioTable (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''CREATE INDEX idx_filename ON $_audioTable(filename)''');
    await db.execute('''CREATE INDEX idx_source ON $_audioTable(source)''');
    await db.execute('''CREATE INDEX idx_transcript_date ON $_transcriptTable (date_only)''');
    await db.execute('''CREATE INDEX idx_transcript_audio_id ON $_transcriptTable (audio_file_id)''');

    debugPrint('✅ Audio database created successfully with source field');
  }

  // UPDATED: Migration method with source field support
  Future<void> _migrateDatabase(Database db, int oldVersion, int newVersion) async {
    debugPrint('📦 Migrating database from version $oldVersion to $newVersion');

    // Add title column (version 2)
    if (oldVersion < 2) {
      try {
        final result = await db.rawQuery("PRAGMA table_info($_audioTable)");
        final columns = result.map((row) => row['name'] as String).toList();

        if (!columns.contains('title')) {
          await db.execute('ALTER TABLE $_audioTable ADD COLUMN title TEXT');
          debugPrint('✅ Added title column to audio_files table');
        }
      } catch (e) {
        debugPrint('❌ Migration error (title): $e');
      }
    }

    // Add transcripts table (version 3)
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_transcriptTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            audio_file_id INTEGER NOT NULL,
            transcript TEXT NOT NULL,
            confidence REAL DEFAULT 0.0,
            created_at INTEGER NOT NULL,
            date_only TEXT NOT NULL,
            FOREIGN KEY (audio_file_id) REFERENCES $_audioTable (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_transcript_date ON $_transcriptTable (date_only)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_transcript_audio_id ON $_transcriptTable (audio_file_id)');

        await _migrateExistingTranscripts(db);
        debugPrint('✅ Added transcripts table and migrated existing data');
      } catch (e) {
        debugPrint('❌ Migration error (transcripts): $e');
      }
    }

    // 👈 NEW: Add source column (version 4)
    if (oldVersion < 4) {
      try {
        final result = await db.rawQuery("PRAGMA table_info($_audioTable)");
        final columns = result.map((row) => row['name'] as String).toList();

        if (!columns.contains('source')) {
          await db.execute('ALTER TABLE $_audioTable ADD COLUMN source TEXT DEFAULT "esp32"');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_source ON $_audioTable(source)');
          debugPrint('✅ Added source column to audio_files table');
        }
      } catch (e) {
        debugPrint('❌ Migration error (source): $e');
      }
    }
  }

  Future<void> _migrateExistingTranscripts(Database db) async {
    final audioFiles = await db.query(
      _audioTable,
      where: 'transcript IS NOT NULL AND transcript != ""',
    );

    for (final file in audioFiles) {
      final createdAt = file['created_at'] as int;
      final dateOnly = _extractDateOnlyFromTimestamp(createdAt);

      final existingTranscript = await db.query(
        _transcriptTable,
        where: 'audio_file_id = ?',
        whereArgs: [file['id']],
      );

      if (existingTranscript.isEmpty) {
        await db.insert(_transcriptTable, {
          'audio_file_id': file['id'],
          'transcript': file['transcript'],
          'confidence': 1.0,
          'created_at': createdAt,
          'date_only': dateOnly,
        });
      }
    }
  }

  String _extractDateOnlyFromTimestamp(int timestamp) {
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  // UPDATED: Save audio file with source parameter
  Future<void> saveAudioFile(AudioFileData audioFile, {String source = 'esp32'}) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final data = audioFile.toMap();
      data['updated_at'] = now;
      data['source'] = source; // 👈 Add source field

      await insertOrReplace(_audioTable, data);
      debugPrint('✅ Audio file saved: ${audioFile.filename} (source: $source)');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error saving audio file: $e');
      rethrow;
    }
  }

  // 👈 NEW: Quick insert method for phone recordings
  Future<int> insertPhoneRecording({
    required String filename,
    required String filePath,
    required int fileSizeBytes,
    required double durationSeconds,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final id = await db.insert(
        _audioTable,
        {
          'filename': filename,
          'display_name': filename.replaceAll('_', ' ').replaceAll('.wav', ''),
          'file_path': filePath,
          'file_size_bytes': fileSizeBytes,
          'duration_seconds': durationSeconds,
          'source': 'phone', // 👈 Mark as phone recording
          'created_at': now,
          'updated_at': now,
          'has_transcript': 0,
          'has_ai_analysis': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('✅ Phone recording inserted: $filename (ID: $id)');
      notifyListeners();
      return id;
    } catch (e) {
      debugPrint('❌ Error inserting phone recording: $e');
      rethrow;
    }
  }

  // 👈 NEW: Get recordings by source
  Future<List<AudioFileData>> getAudioFilesBySource(String source) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _audioTable,
        where: 'source = ?',
        whereArgs: [source],
        orderBy: 'created_at DESC',
      );

      debugPrint('📋 Retrieved ${result.length} $source recordings');
      return result.map((map) => AudioFileData.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error getting $source recordings: $e');
      return [];
    }
  }

  // 👈 NEW: Get recording counts by source
  Future<Map<String, int>> getRecordingCountsBySource() async {
    try {
      final db = await database;

      final phoneCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_audioTable WHERE source = ?', ['phone'])
      ) ?? 0;

      final esp32Count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_audioTable WHERE source = ?', ['esp32'])
      ) ?? 0;

      return {
        'phone': phoneCount,
        'esp32': esp32Count,
        'total': phoneCount + esp32Count,
      };
    } catch (e) {
      debugPrint('❌ Error getting recording counts: $e');
      return {'phone': 0, 'esp32': 0, 'total': 0};
    }
  }

  /// Get audio file with all metadata
  Future<AudioFileData?> getAudioFile(String filename) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _audioTable,
        where: 'filename = ?',
        whereArgs: [filename],
        limit: 1,
      );

      if (result.isNotEmpty) {
        return AudioFileData.fromMap(result.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting audio file: $e');
      return null;
    }
  }

  /// Insert or replace helper method
  Future<void> insertOrReplace(String table, Map<String, dynamic> data) async {
    try {
      final db = await database;
      await db.insert(
        table,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error in insertOrReplace: $e');
      rethrow;
    }
  }

  /// Update user-friendly display name
  Future<void> updateDisplayName(String filename, String newDisplayName) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = await db.update(
        _audioTable,
        {
          'display_name': newDisplayName.trim(),
          'updated_at': now,
        },
        where: 'filename = ?',
        whereArgs: [filename],
      );

      if (result > 0) {
        debugPrint('Display name updated: $filename -> $newDisplayName');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating display name: $e');
      rethrow;
    }
  }

  /// Save transcript and mark as available
  Future<void> saveTranscript(String filename, String transcript) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = await db.update(
        _audioTable,
        {
          'transcript': transcript,
          'has_transcript': 1,
          'updated_at': now,
        },
        where: 'filename = ?',
        whereArgs: [filename],
      );

      if (result > 0) {
        debugPrint('Transcript saved: $filename');

        // Also save to transcripts table for date-based queries
        final audioFile = await db.query(_audioTable, where: 'filename = ?', whereArgs: [filename]);
        if (audioFile.isNotEmpty) {
          final audioFileId = audioFile.first['id'] as int;
          final createdAt = audioFile.first['created_at'] as int;
          final dateOnly = _extractDateOnlyFromTimestamp(createdAt);

          final existingTranscript = await db.query(
            _transcriptTable,
            where: 'audio_file_id = ?',
            whereArgs: [audioFileId],
          );

          if (existingTranscript.isEmpty) {
            await db.insert(_transcriptTable, {
              'audio_file_id': audioFileId,
              'transcript': transcript,
              'confidence': 1.0,
              'created_at': createdAt,
              'date_only': dateOnly,
            });
          } else {
            await db.update(
              _transcriptTable,
              {
                'transcript': transcript,
                'confidence': 1.0,
              },
              where: 'audio_file_id = ?',
              whereArgs: [audioFileId],
            );
          }
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error saving transcript: $e');
      rethrow;
    }
  }

  /// Save AI analysis and mark as available
  Future<void> saveAIAnalysis(String filename, String analysis) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = await db.update(
        _audioTable,
        {
          'ai_analysis': analysis,
          'has_ai_analysis': 1,
          'updated_at': now,
        },
        where: 'filename = ?',
        whereArgs: [filename],
      );

      if (result > 0) {
        debugPrint('AI analysis saved: $filename');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error saving AI analysis: $e');
      rethrow;
    }
  }

  /// Update note title
  Future<void> updateNoteTitle(String filename, String title) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final result = await db.update(
        _audioTable,
        {
          'title': title.trim(),
          'updated_at': now,
        },
        where: 'filename = ?',
        whereArgs: [filename],
      );

      if (result > 0) {
        debugPrint('✅ Title updated: $filename -> "$title"');
        notifyListeners();
      } else {
        debugPrint('❌ No file found to update title: $filename');
      }
    } catch (e) {
      debugPrint('❌ Error updating title: $e');
      rethrow;
    }
  }

  /// Get all audio files (for notes screen)
  Future<List<AudioFileData>> getAllAudioFiles() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _audioTable,
        orderBy: 'created_at DESC',
      );

      debugPrint('📋 Retrieved ${result.length} audio files from database');
      return result.map((map) => AudioFileData.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error getting all audio files: $e');
      return [];
    }
  }

  /// Get files with transcripts and analysis (for notes)
  Future<List<AudioFileData>> getProcessedAudioFiles() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _audioTable,
        where: 'has_transcript = ? AND has_ai_analysis = ?',
        whereArgs: [1, 1],
        orderBy: 'created_at DESC',
      );

      debugPrint('📋 Retrieved ${result.length} processed audio files for notes');
      return result.map((map) => AudioFileData.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error getting processed audio files: $e');
      return [];
    }
  }

  /// Check if file has title
  Future<bool> hasTitle(String filename) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _audioTable,
        columns: ['title'],
        where: 'filename = ?',
        whereArgs: [filename],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final title = result.first['title'] as String?;
        return title != null && title.isNotEmpty;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error checking title existence: $e');
      return false;
    }
  }

  /// Get files without titles (for batch title generation)
  Future<List<AudioFileData>> getFilesWithoutTitles() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _audioTable,
        where: 'has_transcript = ? AND has_ai_analysis = ? AND (title IS NULL OR title = "")',
        whereArgs: [1, 1],
        orderBy: 'created_at DESC',
      );

      debugPrint('🏷️ Found ${result.length} files without titles');
      return result.map((map) => AudioFileData.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error getting files without titles: $e');
      return [];
    }
  }

  Future<List<AudioFileData>> getAudioFilesForDate(String date) async {
    try {
      final db = await database;

      final targetDate = DateTime.parse(date);
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final List<Map<String, dynamic>> result = await db.query(
        _audioTable,
        where: 'created_at >= ? AND created_at < ?',
        whereArgs: [
          startOfDay.millisecondsSinceEpoch,
          endOfDay.millisecondsSinceEpoch,
        ],
        orderBy: 'created_at DESC',
      );

      debugPrint('📅 Found ${result.length} audio files for date $date');
      return result.map((map) => AudioFileData.fromMap(map)).toList();
    } catch (e) {
      debugPrint('❌ Error getting audio files for date $date: $e');
      return [];
    }
  }

  /// Check if file exists in database
  Future<bool> fileExists(String filename) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.query(
        _audioTable,
        where: 'filename = ?',
        whereArgs: [filename],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking file existence: $e');
      return false;
    }
  }

  /// Delete audio file from database
  Future<void> deleteAudioFile(String filename) async {
    try {
      final db = await database;
      final result = await db.delete(
        _audioTable,
        where: 'filename = ?',
        whereArgs: [filename],
      );

      if (result > 0) {
        debugPrint('Audio file deleted: $filename');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting audio file: $e');
      rethrow;
    }
  }

  /// Clear all data from database
  Future<void> clearAllData() async {
    try {
      final db = await database;
      await db.delete(_transcriptTable);
      await db.delete(_audioTable);
      debugPrint('All audio data cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing data: $e');
      rethrow;
    }
  }

  /// UPDATED: Get database statistics with source breakdown
  Future<Map<String, int>> getStats() async {
    try {
      final db = await database;

      final totalFiles = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_audioTable')
      ) ?? 0;

      final phoneRecordings = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_audioTable WHERE source = ?', ['phone'])
      ) ?? 0;

      final esp32Recordings = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_audioTable WHERE source = ?', ['esp32'])
      ) ?? 0;

      final withTranscripts = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_audioTable WHERE has_transcript = 1')
      ) ?? 0;

      final withAnalysis = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_audioTable WHERE has_ai_analysis = 1')
      ) ?? 0;

      final withTitles = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM $_audioTable WHERE title IS NOT NULL AND title != ""')
      ) ?? 0;

      return {
        'total_files': totalFiles,
        'phone_recordings': phoneRecordings, // 👈 NEW
        'esp32_recordings': esp32Recordings, // 👈 NEW
        'with_transcripts': withTranscripts,
        'with_analysis': withAnalysis,
        'with_titles': withTitles,
      };
    } catch (e) {
      debugPrint('Error getting stats: $e');
      return {};
    }
  }

  // TRANSCRIPT METHODS (unchanged)

  Future<List<TranscriptData>> getTranscriptsForDate(DateTime date) async {
    final db = await database;
    final dateString = DateFormat('yyyy-MM-dd').format(date);

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT t.*, a.filename, a.created_at as file_created_at
      FROM $_transcriptTable t
      JOIN $_audioTable a ON t.audio_file_id = a.id
      WHERE t.date_only = ?
      ORDER BY t.created_at ASC
    ''', [dateString]);

    return List.generate(maps.length, (i) => TranscriptData.fromMap(maps[i]));
  }

  Future<List<TranscriptData>> getTranscriptsForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startString = DateFormat('yyyy-MM-dd').format(startDate);
    final endString = DateFormat('yyyy-MM-dd').format(endDate);

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT t.*, a.filename, a.created_at as file_created_at
      FROM $_transcriptTable t
      JOIN $_audioTable a ON t.audio_file_id = a.id
      WHERE t.date_only BETWEEN ? AND ?
      ORDER BY t.created_at ASC
    ''', [startString, endString]);

    return List.generate(maps.length, (i) => TranscriptData.fromMap(maps[i]));
  }

  Future<Map<String, int>> getDailyTranscriptCounts(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    final startString = DateFormat('yyyy-MM-dd').format(startDate);
    final endString = DateFormat('yyyy-MM-dd').format(endDate);

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT date_only, COUNT(*) as count
      FROM $_transcriptTable
      WHERE date_only BETWEEN ? AND ?
      GROUP BY date_only
    ''', [startString, endString]);

    final Map<String, int> counts = {};
    for (final row in result) {
      counts[row['date_only']] = row['count'] as int;
    }

    return counts;
  }

  Future<List<TranscriptData>> searchTranscripts(String query, {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;
    String whereClause = 't.transcript LIKE ?';
    List<dynamic> whereArgs = ['%$query%'];

    if (startDate != null && endDate != null) {
      final startString = DateFormat('yyyy-MM-dd').format(startDate);
      final endString = DateFormat('yyyy-MM-dd').format(endDate);
      whereClause += ' AND t.date_only BETWEEN ? AND ?';
      whereArgs.addAll([startString, endString]);
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT t.*, a.filename, a.created_at as file_created_at
      FROM $_transcriptTable t
      JOIN $_audioTable a ON t.audio_file_id = a.id
      WHERE $whereClause
      ORDER BY t.created_at DESC
    ''', whereArgs);

    return List.generate(maps.length, (i) => TranscriptData.fromMap(maps[i]));
  }

  Future<List<TranscriptData>> getRecentTranscripts({int days = 7}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final cutoffString = DateFormat('yyyy-MM-dd').format(cutoffDate);

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT t.*, a.filename, a.created_at as file_created_at
      FROM $_transcriptTable t
      JOIN $_audioTable a ON t.audio_file_id = a.id
      WHERE t.date_only >= ?
      ORDER BY t.created_at DESC
    ''', [cutoffString]);

    return List.generate(maps.length, (i) => TranscriptData.fromMap(maps[i]));
  }

  Future<Map<String, dynamic>> getTranscriptStatistics() async {
    final db = await database;

    final totalResult = await db.rawQuery('SELECT COUNT(*) as total FROM $_transcriptTable');
    final total = totalResult.first['total'] as int;

    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayResult = await db.rawQuery(
      'SELECT COUNT(*) as today FROM $_transcriptTable WHERE date_only = ?',
      [todayString],
    );
    final today = todayResult.first['today'] as int;

    final weekAgoString = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 7)));
    final weekResult = await db.rawQuery(
      'SELECT COUNT(*) as week FROM $_transcriptTable WHERE date_only >= ?',
      [weekAgoString],
    );
    final week = weekResult.first['week'] as int;

    return {
      'total': total,
      'today': today,
      'this_week': week,
    };
  }
}

// Transcript data model (unchanged)
class TranscriptData {
  final int id;
  final int audioFileId;
  final String transcript;
  final double confidence;
  final DateTime createdAt;
  final String dateOnly;
  final String? filename;

  TranscriptData({
    required this.id,
    required this.audioFileId,
    required this.transcript,
    required this.confidence,
    required this.createdAt,
    required this.dateOnly,
    this.filename,
  });

  factory TranscriptData.fromMap(Map<String, dynamic> map) {
    return TranscriptData(
      id: map['id'] as int,
      audioFileId: map['audio_file_id'] as int,
      transcript: map['transcript'] as String,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      dateOnly: map['date_only'] as String,
      filename: map['filename'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audio_file_id': audioFileId,
      'transcript': transcript,
      'confidence': confidence,
      'created_at': createdAt.millisecondsSinceEpoch,
      'date_only': dateOnly,
    };
  }
}