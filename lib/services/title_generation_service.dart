// lib/services/title_generation_service.dart - CLEAN ERROR-FREE VERSION
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TitleGenerationService {
  static const String _apiKey = '';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'openai/gpt-oss-120b';

  Future<String> generateFromSummary(String aiSummary) async {
    if (aiSummary.isEmpty) {
      return _generateFallbackTitle();
    }

    try {
      final title = await _generateAITitle(aiSummary);
      if (title.isNotEmpty && _isValidTitle(title)) {
        return title;
      }
    } catch (e) {
      debugPrint('AI title generation failed: $e');
    }

    return _generateRuleBasedTitle(aiSummary);
  }

  Future<String> _generateAITitle(String aiSummary) async {
    final prompt = 'Create a short 4-5 word title for this voice note:\n\nSummary: "$aiSummary"\n\nExamples: "Morning Work Planning", "Family Trip Ideas", "Budget Review Notes"\n\nGenerate only the title:';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You create short 4-5 word titles for voice notes. Focus on main topic.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'max_tokens': 20,
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return _cleanTitle(content);
      }
    } catch (e) {
      debugPrint('AI API error: $e');
    }
    return '';
  }

  String _cleanTitle(String title) {
    if (title.isEmpty) return '';

    String cleaned = title
        .replaceAll('"', '')
        .replaceAll("'", '')
        .trim();

    // Take only first 5 words
    final words = cleaned.split(' ')
        .where((word) => word.isNotEmpty)
        .take(5)
        .toList();

    // Capitalize each word
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).toList();

    return capitalizedWords.join(' ');
  }

  String _generateRuleBasedTitle(String aiSummary) {
    final summary = aiSummary.toLowerCase();

    if (summary.contains('meeting')) {
      if (summary.contains('work')) return 'Work Meeting Notes';
      if (summary.contains('team')) return 'Team Meeting Discussion';
      return 'Meeting Discussion Notes';
    }

    if (summary.contains('planning')) {
      if (summary.contains('trip')) return 'Trip Planning Session';
      if (summary.contains('work')) return 'Work Planning Notes';
      return 'Planning Session Notes';
    }

    if (summary.contains('review')) {
      if (summary.contains('project')) return 'Project Review Session';
      return 'Review Session Notes';
    }

    if (summary.contains('personal')) {
      if (summary.contains('goals')) return 'Personal Goals Review';
      return 'Personal Notes Session';
    }

    if (summary.contains('health')) return 'Health Discussion Notes';
    if (summary.contains('shopping')) return 'Shopping List Notes';
    if (summary.contains('financial')) return 'Financial Planning Discussion';
    if (summary.contains('learning')) return 'Learning Session Notes';
    if (summary.contains('work')) return 'Work Discussion Notes';
    if (summary.contains('family')) return 'Family Discussion Notes';
    if (summary.contains('travel')) return 'Travel Planning Notes';

    return _generateFallbackTitle();
  }

  String _generateFallbackTitle() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Morning Voice Notes';
    if (hour < 17) return 'Afternoon Voice Notes';
    return 'Evening Voice Notes';
  }

  bool _isValidTitle(String title) {
    if (title.isEmpty || title.length < 5) return false;
    if (title.length > 30) return false;

    final words = title.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < 2 || words.length > 6) return false;

    return !title.toLowerCase().contains('untitled');
  }

  Future<String> generateWithPrefix(String aiSummary, String prefix) async {
    final baseTitle = await generateFromSummary(aiSummary);
    if (baseTitle.toLowerCase().startsWith(prefix.toLowerCase())) {
      return baseTitle;
    }
    return '$prefix $baseTitle';
  }

  bool isValidTitle(String title) {
    return _isValidTitle(title);
  }

  Future<List<String>> generateMultipleTitles(String aiSummary, {int count = 3}) async {
    final titles = <String>[];

    try {
      final aiTitle = await _generateAITitle(aiSummary);
      if (aiTitle.isNotEmpty && _isValidTitle(aiTitle)) {
        titles.add(aiTitle);
      }
    } catch (e) {
      debugPrint('AI title generation failed: $e');
    }

    final ruleTitle = _generateRuleBasedTitle(aiSummary);
    if (!titles.contains(ruleTitle) && _isValidTitle(ruleTitle)) {
      titles.add(ruleTitle);
    }

    if (titles.length < count) {
      final fallbackTitle = _generateFallbackTitle();
      if (!titles.contains(fallbackTitle)) {
        titles.add(fallbackTitle);
      }
    }

    return titles.take(count).toList();
  }
}