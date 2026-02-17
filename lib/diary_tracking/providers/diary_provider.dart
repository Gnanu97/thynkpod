// lib/diary_tracking/providers/diary_provider.dart - ENHANCED VERSION
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_models.dart';
import '../services/diary_database_service.dart';

class DiaryProvider extends ChangeNotifier {
  final DiaryDatabaseService _dbService = DiaryDatabaseService();

  DailyEntry? _todaysEntry;
  bool _isLoading = false;
  String? _error;

  DailyEntry? get todaysEntry => _todaysEntry;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> initialize() async {
    await _dbService.initializeDiaryTables();
    await loadTodaysData();
  }

  Future<void> loadTodaysData() async {
    _setLoading(true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _todaysEntry = await _dbService.getDailyEntry(today);
    } catch (e) {
      _setError('Failed to load data: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateCategory(String category, String emoji) async {
    _setLoading(true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final score = EmojiMapping.getScore(emoji, category);

      final updatedEntry = DailyEntry(
        id: _todaysEntry?.id ?? today,
        date: today,
        timestamp: DateTime.now(),
        moodEmoji: category == 'mood' ? emoji : _todaysEntry?.moodEmoji,
        moodScore: category == 'mood' ? score : _todaysEntry?.moodScore,
        stressEmoji: category == 'stress' ? emoji : _todaysEntry?.stressEmoji,
        stressScore: category == 'stress' ? score : _todaysEntry?.stressScore,
        sleepEmoji: category == 'sleep' ? emoji : _todaysEntry?.sleepEmoji,
        sleepScore: category == 'sleep' ? score : _todaysEntry?.sleepScore,
        socialEmoji: category == 'social' ? emoji : _todaysEntry?.socialEmoji,
        socialScore: category == 'social' ? score : _todaysEntry?.socialScore,
        foodEmoji: category == 'food' ? emoji : _todaysEntry?.foodEmoji,
        foodScore: category == 'food' ? score : _todaysEntry?.foodScore,
        aiAvgMood: _todaysEntry?.aiAvgMood,
        aiAvgStress: _todaysEntry?.aiAvgStress,
        aiSummary: _todaysEntry?.aiSummary,
        overallSentiment: _calculateOverallSentiment(
          category == 'mood' ? score : _todaysEntry?.moodScore,
          category == 'stress' ? score : _todaysEntry?.stressScore,
        ),
        createdAt: _todaysEntry?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _dbService.saveDailyEntry(updatedEntry);
      _todaysEntry = updatedEntry;
      notifyListeners();
    } catch (e) {
      _setError('Failed to update $category: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateAIAnalysis({
    required double avgMood,
    required double avgStress,
    required String summary,
    required String sentiment,
  }) async {
    _setLoading(true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final updatedEntry = DailyEntry(
        id: _todaysEntry?.id ?? today,
        date: today,
        timestamp: DateTime.now(),
        moodEmoji: _todaysEntry?.moodEmoji,
        moodScore: _todaysEntry?.moodScore,
        stressEmoji: _todaysEntry?.stressEmoji,
        stressScore: _todaysEntry?.stressScore,
        sleepEmoji: _todaysEntry?.sleepEmoji,
        sleepScore: _todaysEntry?.sleepScore,
        socialEmoji: _todaysEntry?.socialEmoji,
        socialScore: _todaysEntry?.socialScore,
        foodEmoji: _todaysEntry?.foodEmoji,
        foodScore: _todaysEntry?.foodScore,
        aiAvgMood: avgMood,
        aiAvgStress: avgStress,
        aiSummary: summary,
        overallSentiment: sentiment,
        createdAt: _todaysEntry?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _dbService.saveDailyEntry(updatedEntry);
      _todaysEntry = updatedEntry;
      notifyListeners();
    } catch (e) {
      _setError('Failed to update AI analysis: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveHistoricalEntry(DateTime date, String moodEmoji, String stressEmoji) async {
    try {
      await _dbService.saveHistoricalEntry(date, moodEmoji, stressEmoji);
      notifyListeners();
    } catch (e) {
      _setError('Failed to save historical entry: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMonthlyChartData(int year, int month) async {
    try {
      return await _dbService.getMonthlyChartData(year, month);
    } catch (e) {
      _setError('Failed to load chart data: $e');
      return [];
    }
  }

  Future<bool> hasDataForDate(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      return await _dbService.hasDataForDate(dateStr);
    } catch (e) {
      _setError('Failed to check date data: $e');
      return false;
    }
  }

  Future<DailyEntry?> getEntryForDate(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      return await _dbService.getDailyEntry(dateStr);
    } catch (e) {
      _setError('Failed to get entry for date: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getMonthlyStats(int year, int month) async {
    try {
      return await _dbService.getMonthlyStats(year, month);
    } catch (e) {
      _setError('Failed to get monthly stats: $e');
      return {
        'totalEntries': 0,
        'averageMood': 0.0,
        'averageStress': 0.0,
        'bestDay': null,
        'worstDay': null,
      };
    }
  }

  Future<void> deleteEntry(DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      await _dbService.deleteEntry(dateStr);

      if (DateUtils.isSameDay(date, DateTime.now())) {
        await loadTodaysData();
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to delete entry: $e');
    }
  }

  String _calculateOverallSentiment(double? mood, double? stress) {
    final avgMood = mood ?? 3.0;
    final avgStress = stress ?? 3.0;

    if (avgMood >= 4.0 && avgStress <= 2.0) return 'positive';
    if (avgMood <= 2.0 || avgStress >= 4.0) return 'challenging';
    return 'mixed';
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
    debugPrint('DiaryProvider Error: $error');
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

class EmojiMapping {
  static double getScore(String emoji, String category) {
    switch (category) {
      case 'mood':
        switch (emoji) {
          case '😭': return 1.0;
          case '😢': return 2.0;
          case '😐': return 3.0;
          case '😊': return 4.0;
          case '😄': return 5.0;
          default: return 3.0;
        }
      case 'stress':
        switch (emoji) {
          case '🤯': return 5.0;
          case '😰': return 4.0;
          case '😬': return 3.0;
          case '😌': return 2.0;
          case '😴': return 1.0;
          default: return 3.0;
        }
      case 'sleep':
        switch (emoji) {
          case '😵': return 1.0;
          case '😪': return 2.0;
          case '😐': return 3.0;
          case '😊': return 4.0;
          case '😴': return 5.0;
          default: return 3.0;
        }
      case 'social':
        switch (emoji) {
          case '😞': return 1.0;
          case '😕': return 2.0;
          case '😐': return 3.0;
          case '😊': return 4.0;
          case '🥳': return 5.0;
          default: return 3.0;
        }
      case 'food':
        switch (emoji) {
          case '🤢': return 1.0;
          case '😕': return 2.0;
          case '😐': return 3.0;
          case '😋': return 4.0;
          case '🤤': return 5.0;
          default: return 3.0;
        }
      default: return 3.0;
    }
  }

  static String getEmotionFromScore(double score) {
    if (score >= 4.5) return '😄';
    if (score >= 3.5) return '😊';
    if (score >= 2.5) return '😐';
    if (score >= 1.5) return '😢';
    return '😭';
  }

  static String getStressFromScore(double score) {
    if (score >= 4.5) return '🤯';
    if (score >= 3.5) return '😰';
    if (score >= 2.5) return '😬';
    if (score >= 1.5) return '😌';
    return '😴';
  }
}