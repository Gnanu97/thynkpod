// lib/diary_tracking/services/groq_sentiment_service.dart - ENHANCED WITH DAILY SUMMARY
import 'dart:convert';
import 'package:http/http.dart' as http;

class GroqSentimentService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _apiKey = 'YOUR_GROQ_API_KEY'; // Replace with your actual API key

  // Existing sentiment analysis method
  Future<Map<String, dynamic>> analyzeSentiment(String text) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'mixtral-8x7b-32768',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a sentiment analysis expert. Analyze the emotional content of the given text and provide scores for different aspects of wellbeing on a scale of 1-5 (1 being very negative, 5 being very positive).

Return your response in this exact JSON format:
{
  "mood_score": number,
  "stress_score": number,
  "sleep_score": number,
  "social_score": number,
  "food_score": number,
  "mood_emoji": "emoji",
  "stress_emoji": "emoji",
  "sleep_emoji": "emoji",
  "social_emoji": "emoji", 
  "food_emoji": "emoji",
  "analysis": "brief analysis of the emotional state"
}

For stress_score: 1 = very stressed, 5 = very relaxed
For other scores: 1 = very negative, 5 = very positive'''
            },
            {
              'role': 'user',
              'content': text
            }
          ],
          'temperature': 0.3,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        // Try to parse JSON from the response
        try {
          final jsonStart = content.indexOf('{');
          final jsonEnd = content.lastIndexOf('}');
          if (jsonStart != -1 && jsonEnd != -1) {
            final jsonStr = content.substring(jsonStart, jsonEnd + 1);
            return jsonDecode(jsonStr);
          }
        } catch (e) {
          print('Error parsing JSON response: $e');
        }

        // Fallback if JSON parsing fails
        return _generateFallbackAnalysis(text);
      } else {
        throw Exception('Failed to analyze sentiment: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in sentiment analysis: $e');
      return _generateFallbackAnalysis(text);
    }
  }

  // NEW: Daily summary generation method
  Future<String> generateDailySummary(String combinedTranscripts) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'mixtral-8x7b-32768',
          'messages': [
            {
              'role': 'system',
              'content': '''You are an AI assistant that creates insightful daily summaries. 
              
Your task is to analyze a day's worth of audio transcripts and create a comprehensive, thoughtful summary that captures:

1. **Key Activities & Events**: What did the person do throughout the day?
2. **Emotional Journey**: How did their mood and emotions evolve?
3. **Interactions & Relationships**: Who did they interact with and how?
4. **Challenges & Achievements**: What obstacles did they face and what did they accomplish?
5. **Insights & Patterns**: Any notable patterns, thoughts, or realizations?

Guidelines:
- Write in a warm, understanding tone
- Keep it between 150-250 words
- Focus on meaningful moments rather than mundane details
- Be empathetic and non-judgmental
- Highlight positive aspects while acknowledging difficulties
- Use "you" to address the person directly
- End with an encouraging or reflective note

If the transcripts are unclear or fragmented, focus on the emotional tone and general themes.'''
            },
            {
              'role': 'user',
              'content': 'Please create a daily summary based on these audio transcripts from today:\n\n$combinedTranscripts'
            }
          ],
          'temperature': 0.7,
          'max_tokens': 400,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        throw Exception('Failed to generate summary: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating daily summary: $e');
      return _generateFallbackSummary(combinedTranscripts);
    }
  }

  // NEW: Weekly summary generation
  Future<String> generateWeeklySummary(List<String> dailySummaries) async {
    try {
      final combinedSummaries = dailySummaries.join('\n\n---\n\n');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'mixtral-8x7b-32768',
          'messages': [
            {
              'role': 'system',
              'content': '''You are creating a weekly reflection summary based on daily summaries.

Create a comprehensive weekly overview that includes:
1. **Week Overview**: Major themes and patterns
2. **Emotional Trends**: How emotions and mood evolved throughout the week
3. **Key Achievements**: Significant accomplishments and progress
4. **Challenges Faced**: Main difficulties and how they were handled
5. **Growth & Insights**: Personal development and realizations
6. **Looking Forward**: Positive momentum and areas for focus

Keep it between 200-300 words, encouraging and insightful.'''
            },
            {
              'role': 'user',
              'content': 'Create a weekly summary based on these daily summaries:\n\n$combinedSummaries'
            }
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        throw Exception('Failed to generate weekly summary: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating weekly summary: $e');
      return 'Unable to generate weekly summary at this time. Please try again later.';
    }
  }

  // NEW: Get insights from transcript patterns
  Future<Map<String, dynamic>> generateInsights(List<String> recentTranscripts) async {
    try {
      final combinedText = recentTranscripts.join(' ');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'mixtral-8x7b-32768',
          'messages': [
            {
              'role': 'system',
              'content': '''Analyze these audio transcripts and provide insights in JSON format:

{
  "mood_trend": "improving/declining/stable",
  "stress_indicators": ["list", "of", "stress", "signs"],
  "positive_patterns": ["list", "of", "good", "patterns"],
  "concerns": ["list", "of", "potential", "concerns"],
  "recommendations": ["actionable", "suggestions"],
  "key_themes": ["main", "life", "themes"],
  "social_connections": "assessment of social interactions",
  "work_life_balance": "assessment of balance"
}'''
            },
            {
              'role': 'user',
              'content': 'Analyze these recent transcripts for patterns and insights:\n\n$combinedText'
            }
          ],
          'temperature': 0.5,
          'max_tokens': 600,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];

        try {
          final jsonStart = content.indexOf('{');
          final jsonEnd = content.lastIndexOf('}');
          if (jsonStart != -1 && jsonEnd != -1) {
            final jsonStr = content.substring(jsonStart, jsonEnd + 1);
            return jsonDecode(jsonStr);
          }
        } catch (e) {
          print('Error parsing insights JSON: $e');
        }
      }

      return _generateFallbackInsights();
    } catch (e) {
      print('Error generating insights: $e');
      return _generateFallbackInsights();
    }
  }

  // Fallback methods for when API calls fail
  Map<String, dynamic> _generateFallbackAnalysis(String text) {
    // Simple keyword-based analysis as fallback
    final words = text.toLowerCase().split(' ');
    double moodScore = 3.0;

    // Positive words increase score
    const positiveWords = ['happy', 'good', 'great', 'excellent', 'wonderful', 'amazing', 'love', 'joy'];
    // Negative words decrease score
    const negativeWords = ['sad', 'bad', 'terrible', 'awful', 'hate', 'angry', 'frustrated', 'stressed'];

    for (String word in words) {
      if (positiveWords.contains(word)) moodScore += 0.5;
      if (negativeWords.contains(word)) moodScore -= 0.5;
    }

    moodScore = moodScore.clamp(1.0, 5.0);

    return {
      'mood_score': moodScore,
      'stress_score': 3.0,
      'sleep_score': 3.0,
      'social_score': 3.0,
      'food_score': 3.0,
      'mood_emoji': moodScore >= 4 ? '😊' : moodScore >= 3 ? '😐' : '😔',
      'stress_emoji': '😌',
      'sleep_emoji': '😴',
      'social_emoji': '😊',
      'food_emoji': '😋',
      'analysis': 'Basic analysis of emotional content'
    };
  }

  String _generateFallbackSummary(String transcripts) {
    return '''Today's recordings capture various moments from your day. While the specific details may vary, your voice and thoughts reflect the ongoing journey of daily life. 

Each recording represents a moment in time - whether sharing thoughts, planning activities, or processing experiences. These audio snapshots create a unique record of your day, preserving both the mundane and meaningful moments that make up your personal story.

Take a moment to reflect on the themes that emerged in your recordings today. What patterns do you notice in your thoughts and feelings?''';
  }

  Map<String, dynamic> _generateFallbackInsights() {
    return {
      'mood_trend': 'stable',
      'stress_indicators': ['irregular sleep patterns', 'busy schedule'],
      'positive_patterns': ['regular recording', 'self-reflection'],
      'concerns': [],
      'recommendations': ['maintain recording habit', 'prioritize rest'],
      'key_themes': ['daily reflection', 'personal growth'],
      'social_connections': 'maintaining regular interactions',
      'work_life_balance': 'working towards better balance'
    };
  }
}