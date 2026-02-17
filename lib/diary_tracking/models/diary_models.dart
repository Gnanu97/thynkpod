// lib/diary_tracking/models/diary_models.dart - FIXED VERSION
class DailyEntry {
  final String id;
  final String date;
  final DateTime timestamp;

  // Core tracking categories
  final String? moodEmoji;
  final double? moodScore;
  final String? stressEmoji;
  final double? stressScore;
  final String? sleepEmoji;
  final double? sleepScore;
  final String? socialEmoji;
  final double? socialScore;
  final String? foodEmoji;
  final double? foodScore;

  // AI analysis
  final double? aiAvgMood;
  final double? aiAvgStress;
  final String? aiSummary;
  final String? overallSentiment;

  final DateTime createdAt;
  final DateTime updatedAt;

  DailyEntry({
    required this.id,
    required this.date,
    required this.timestamp,
    this.moodEmoji,
    this.moodScore,
    this.stressEmoji,
    this.stressScore,
    this.sleepEmoji,
    this.sleepScore,
    this.socialEmoji,
    this.socialScore,
    this.foodEmoji,
    this.foodScore,
    this.aiAvgMood,
    this.aiAvgStress,
    this.aiSummary,
    this.overallSentiment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyEntry.fromMap(Map<String, dynamic> map) {
    return DailyEntry(
      id: map['id'],
      date: map['date'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      moodEmoji: map['mood_emoji'],
      moodScore: map['mood_score']?.toDouble(),
      stressEmoji: map['stress_emoji'],
      stressScore: map['stress_score']?.toDouble(),
      sleepEmoji: map['sleep_emoji'],
      sleepScore: map['sleep_score']?.toDouble(),
      socialEmoji: map['social_emoji'],
      socialScore: map['social_score']?.toDouble(),
      foodEmoji: map['food_emoji'],
      foodScore: map['food_score']?.toDouble(),
      aiAvgMood: map['ai_avg_mood']?.toDouble(),
      aiAvgStress: map['ai_avg_stress']?.toDouble(),
      aiSummary: map['ai_summary'],
      overallSentiment: map['overall_sentiment'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'mood_emoji': moodEmoji,
      'mood_score': moodScore,
      'stress_emoji': stressEmoji,
      'stress_score': stressScore,
      'sleep_emoji': sleepEmoji,
      'sleep_score': sleepScore,
      'social_emoji': socialEmoji,
      'social_score': socialScore,
      'food_emoji': foodEmoji,
      'food_score': foodScore,
      'ai_avg_mood': aiAvgMood,
      'ai_avg_stress': aiAvgStress,
      'ai_summary': aiSummary,
      'overall_sentiment': overallSentiment,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}

// DiaryEntry alias for backwards compatibility
class DiaryEntry extends DailyEntry {
  // Additional fields for compatibility with groq_sentiment_service.dart
  double? get userEmotionScore => moodScore;
  double? get aiAvgEmotion => aiAvgMood;
  String? get userEmotionEmoji => moodEmoji;
  String? get userStressEmoji => stressEmoji;

  DiaryEntry({
    required super.id,
    required super.date,
    required super.timestamp,
    super.moodEmoji,
    super.moodScore,
    super.stressEmoji,
    super.stressScore,
    super.sleepEmoji,
    super.sleepScore,
    super.socialEmoji,
    super.socialScore,
    super.foodEmoji,
    super.foodScore,
    super.aiAvgMood,
    super.aiAvgStress,
    super.aiSummary,
    super.overallSentiment,
    required super.createdAt,
    required super.updatedAt,
  });
}

class EmotionInput {
  final String id;
  final String date;
  final DateTime timestamp;
  final String emotionEmoji;
  final String stressEmoji;
  final double emotionScore;
  final double stressScore;

  EmotionInput({
    required this.id,
    required this.date,
    required this.timestamp,
    required this.emotionEmoji,
    required this.stressEmoji,
    required this.emotionScore,
    required this.stressScore,
  });

  factory EmotionInput.fromMap(Map<String, dynamic> map) {
    return EmotionInput(
      id: map['id'],
      date: map['date'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      emotionEmoji: map['emotion_emoji'],
      stressEmoji: map['stress_emoji'],
      emotionScore: (map['emotion_score'] as num).toDouble(),
      stressScore: (map['stress_score'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'emotion_emoji': emotionEmoji,
      'stress_emoji': stressEmoji,
      'emotion_score': emotionScore,
      'stress_score': stressScore,
    };
  }
}

class AudioSentiment {
  final String id;
  final String audioFileId;
  final DateTime timestamp;
  final double emotionScore;
  final double stressScore;
  final List<String> moodKeywords;
  final double confidence;

  AudioSentiment({
    required this.id,
    required this.audioFileId,
    required this.timestamp,
    required this.emotionScore,
    required this.stressScore,
    required this.moodKeywords,
    required this.confidence,
  });

  factory AudioSentiment.fromMap(Map<String, dynamic> map) {
    return AudioSentiment(
      id: map['id'],
      audioFileId: map['audio_file_id'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      emotionScore: (map['emotion_score'] as num).toDouble(),
      stressScore: (map['stress_score'] as num).toDouble(),
      moodKeywords: (map['mood_keywords'] as String).split(','),
      confidence: (map['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audio_file_id': audioFileId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'emotion_score': emotionScore,
      'stress_score': stressScore,
      'mood_keywords': moodKeywords.join(','),
      'confidence': confidence,
    };
  }
}

class EmojiMapping {
  // Mood emojis (1-5 scale)
  static const Map<String, double> moodEmojis = {
    '😭': 1.0, '😢': 2.0, '😐': 3.0, '😊': 4.0, '😄': 5.0,
  };

  // Stress emojis (1-5 scale, inverted)
  static const Map<String, double> stressEmojis = {
    '🤯': 5.0, '😰': 4.0, '😬': 3.0, '😌': 2.0, '😴': 1.0,
  };

  // Sleep emojis (1-5 scale)
  static const Map<String, double> sleepEmojis = {
    '😵': 1.0, '😪': 2.0, '😐': 3.0, '😊': 4.0, '😴': 5.0,
  };

  // Social emojis (1-5 scale)
  static const Map<String, double> socialEmojis = {
    '😞': 1.0, '😕': 2.0, '😐': 3.0, '😊': 4.0, '🥳': 5.0,
  };

  // Food emojis (1-5 scale)
  static const Map<String, double> foodEmojis = {
    '🤢': 1.0, '😕': 2.0, '😐': 3.0, '😋': 4.0, '🤤': 5.0,
  };

  // Additional emotion mappings for compatibility with groq service
  static const Map<String, double> emotionEmojis = {
    '😢': 1.5, '😕': 3.5, '😐': 5.5, '🙂': 7.5, '😊': 9.5,
  };

  static double getScore(String emoji, String category) {
    switch (category) {
      case 'mood': return moodEmojis[emoji] ?? 3.0;
      case 'stress': return stressEmojis[emoji] ?? 3.0;
      case 'sleep': return sleepEmojis[emoji] ?? 3.0;
      case 'social': return socialEmojis[emoji] ?? 3.0;
      case 'food': return foodEmojis[emoji] ?? 3.0;
      default: return 3.0;
    }
  }

  static String getEmojiFromScore(double score, String category) {
    Map<String, double> mapping;
    switch (category) {
      case 'mood': mapping = moodEmojis; break;
      case 'stress': mapping = stressEmojis; break;
      case 'sleep': mapping = sleepEmojis; break;
      case 'social': mapping = socialEmojis; break;
      case 'food': mapping = foodEmojis; break;
      default: return '😐';
    }

    String closest = '😐';
    double minDiff = double.infinity;

    mapping.forEach((emoji, value) {
      double diff = (value - score).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = emoji;
      }
    });

    return closest;
  }

  // Legacy methods for compatibility with groq_sentiment_service.dart
  static double getEmotionScore(String emoji) => emotionEmojis[emoji] ?? 5.5;
  static double getStressScore(String emoji) => stressEmojis[emoji] ?? 3.0;

  static String getEmotionFromScore(double score) {
    if (score <= 2.0) return '😢';
    if (score <= 4.0) return '😕';
    if (score <= 6.0) return '😐';
    if (score <= 8.0) return '🙂';
    return '😊';
  }

  static String getStressFromScore(double score) {
    if (score >= 8.5) return '🤯';
    if (score >= 6.5) return '😰';
    if (score >= 4.5) return '😬';
    if (score >= 2.5) return '😌';
    return '😴';
  }
}