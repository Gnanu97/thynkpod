// lib/diary_tracking/services/diary_database_service.dart - UPDATED VERSION
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../../services/audio_database_service.dart';
import '../models/diary_models.dart';

class DiaryDatabaseService {
  static final DiaryDatabaseService _instance = DiaryDatabaseService._internal();
  factory DiaryDatabaseService() => _instance;
  DiaryDatabaseService._internal();

  Future<Database> get database async => AudioDatabaseService().database;

  Future<void> initializeDiaryTables() async {
    final db = await database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_entries (
        id TEXT PRIMARY KEY,
        date TEXT UNIQUE,
        timestamp INTEGER,
        mood_emoji TEXT,
        mood_score REAL,
        stress_emoji TEXT,
        stress_score REAL,
        sleep_emoji TEXT,
        sleep_score REAL,
        social_emoji TEXT,
        social_score REAL,
        food_emoji TEXT,
        food_score REAL,
        ai_avg_mood REAL,
        ai_avg_stress REAL,
        ai_summary TEXT,
        overall_sentiment TEXT,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');

    // Add indexes for performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_daily_entries_date ON daily_entries(date)');
  }

  Future<void> saveDailyEntry(DailyEntry entry) async {
    final db = await database;
    await db.insert(
      'daily_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveHistoricalEntry(DateTime date, String moodEmoji, String stressEmoji) async {
    final db = await database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Get mood and stress scores from emojis
    final moodScore = EmojiMapping.getScore(moodEmoji, 'mood');
    final stressScore = EmojiMapping.getScore(stressEmoji, 'stress');

    final entry = DailyEntry(
      id: dateStr,
      date: dateStr,
      timestamp: date,
      moodEmoji: moodEmoji,
      moodScore: moodScore,
      stressEmoji: stressEmoji,
      stressScore: stressScore,
      overallSentiment: _calculateSentiment(moodScore, stressScore),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await saveDailyEntry(entry);
  }

  String _calculateSentiment(double moodScore, double stressScore) {
    if (moodScore >= 4.0 && stressScore <= 2.0) return 'positive';
    if (moodScore <= 2.0 || stressScore >= 4.0) return 'challenging';
    return 'mixed';
  }

  Future<DailyEntry?> getDailyEntry(String date) async {
    final db = await database;
    final result = await db.query(
      'daily_entries',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return DailyEntry.fromMap(result.first);
  }

  Future<List<Map<String, dynamic>>> getMonthlyChartData(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    final result = await db.query(
      'daily_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        startDate.toIso8601String().substring(0, 10),
        endDate.toIso8601String().substring(0, 10),
      ],
      orderBy: 'date ASC',
    );

    return result.map((row) {
      // Ensure valid data with fallbacks
      double? moodScore = row['mood_score'] as double?;
      double? stressScore = row['stress_score'] as double?;

      // Validate and clamp scores
      if (moodScore != null) {
        if (moodScore.isNaN || moodScore.isInfinite) moodScore = null;
        else moodScore = moodScore.clamp(1.0, 5.0);
      }

      if (stressScore != null) {
        if (stressScore.isNaN || stressScore.isInfinite) stressScore = null;
        else stressScore = stressScore.clamp(1.0, 5.0);
      }

      return {
        'day': DateTime.parse(row['date'] as String).day,
        'moodScore': moodScore,
        'stressScore': stressScore,
        'sleepScore': _validateScore(row['sleep_score'] as double?),
        'socialScore': _validateScore(row['social_score'] as double?),
        'foodScore': _validateScore(row['food_score'] as double?),
        'moodEmoji': row['mood_emoji'] as String?,
        'stressEmoji': row['stress_emoji'] as String?,
      };
    }).toList();
  }

  double? _validateScore(double? score) {
    if (score == null) return null;
    if (score.isNaN || score.isInfinite) return null;
    return score.clamp(1.0, 5.0);
  }

  Future<Map<String, int>> getCategoryDistribution(int year, int month, String category) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    final result = await db.query(
      'daily_entries',
      columns: ['${category}_emoji'],
      where: 'date >= ? AND date <= ? AND ${category}_emoji IS NOT NULL',
      whereArgs: [
        startDate.toIso8601String().substring(0, 10),
        endDate.toIso8601String().substring(0, 10),
      ],
    );

    final Map<String, int> distribution = {};
    for (final row in result) {
      final emoji = row['${category}_emoji'] as String?;
      if (emoji != null) {
        distribution[emoji] = (distribution[emoji] ?? 0) + 1;
      }
    }

    return distribution;
  }

  Future<List<DailyEntry>> getMonthlyEntries(int year, int month) async {
    final db = await database;
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    final result = await db.query(
      'daily_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [
        startDate.toIso8601String().substring(0, 10),
        endDate.toIso8601String().substring(0, 10),
      ],
      orderBy: 'date ASC',
    );

    return result.map((map) => DailyEntry.fromMap(map)).toList();
  }

  Future<bool> hasDataForDate(String date) async {
    final db = await database;
    final result = await db.query(
      'daily_entries',
      columns: ['id'],
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> deleteEntry(String date) async {
    final db = await database;
    await db.delete(
      'daily_entries',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<Map<String, dynamic>> getMonthlyStats(int year, int month) async {
    final entries = await getMonthlyEntries(year, month);

    if (entries.isEmpty) {
      return {
        'totalEntries': 0,
        'averageMood': 0.0,
        'averageStress': 0.0,
        'bestDay': null,
        'worstDay': null,
      };
    }

    final moodScores = entries
        .where((e) => e.moodScore != null)
        .map((e) => e.moodScore!)
        .toList();

    final stressScores = entries
        .where((e) => e.stressScore != null)
        .map((e) => e.stressScore!)
        .toList();

    final avgMood = moodScores.isNotEmpty
        ? moodScores.reduce((a, b) => a + b) / moodScores.length
        : 0.0;

    final avgStress = stressScores.isNotEmpty
        ? stressScores.reduce((a, b) => a + b) / stressScores.length
        : 0.0;

    // Find best and worst days
    DailyEntry? bestDay;
    DailyEntry? worstDay;
    double bestScore = 0.0;
    double worstScore = 6.0;

    for (final entry in entries) {
      if (entry.moodScore != null) {
        if (entry.moodScore! > bestScore) {
          bestScore = entry.moodScore!;
          bestDay = entry;
        }
        if (entry.moodScore! < worstScore) {
          worstScore = entry.moodScore!;
          worstDay = entry;
        }
      }
    }

    return {
      'totalEntries': entries.length,
      'averageMood': avgMood,
      'averageStress': avgStress,
      'bestDay': bestDay,
      'worstDay': worstDay,
    };
  }
}