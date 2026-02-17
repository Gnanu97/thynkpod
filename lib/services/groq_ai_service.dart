// lib/services/groq_ai_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GroqAIService {
  static const String _apiKey = '';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static const String _defaultModel = 'openai/gpt-oss-120b';
  static const String _fastModel = 'openai/gpt-oss-120b';
  static const String _qualityModel = 'mixtral-8x7b-32768';

  Future<String> analyze(String transcript) async {
    return await summarizeTranscript(transcript);
  }

  Future<String> summarizeTranscript(String transcript) async {
    final prompt = '''
Analyze this audio transcript and provide a comprehensive, well-structured summary:

"$transcript"

Please provide a detailed analysis using this EXACT format:

**📋 MAIN TOPICS & THEMES:**
• [List the primary subjects discussed]
• [Include any recurring themes or patterns]

**🔑 KEY INSIGHTS & INFORMATION:**
• [Important facts, data, or revelations mentioned]
• [Significant quotes or statements]
• [Technical details or specifications]

**✅ ACTION ITEMS & DECISIONS:**
• [Tasks or commitments mentioned]
• [Decisions made or conclusions reached]
• [Deadlines or next steps identified]

**👥 PEOPLE, PLACES & ENTITIES:**
• [Names of people mentioned]
• [Locations, companies, or organizations]
• [Products, services, or brands referenced]

**📊 NUMBERS & DATES:**
• [Specific dates, times, or deadlines]
• [Financial figures, statistics, or measurements]
• [Quantities or percentages mentioned]

**🎯 SENTIMENT & TONE:**
• [Overall mood: positive, neutral, concerned, urgent, etc.]
• [Speaker attitudes and emotions]
• [Level of formality: casual, professional, formal]

**📝 EXECUTIVE SUMMARY:**
• [Concise 2-3 sentence overview of the entire conversation]
• [Main outcome or conclusion]
• [Most important takeaway]

**📌 ADDITIONAL NOTES:**
• [Any unclear sections or transcription gaps]
• [Context that might be helpful]
• [Recommendations for follow-up]

Focus on extracting maximum value even if some parts of the transcript are unclear. Prioritize actionable information and key insights.
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _defaultModel,
          'messages': [
            {
              'role': 'system',
              'content': '''You are an expert AI assistant specializing in audio transcript analysis. You excel at:
- Extracting actionable insights from conversations
- Organizing information in clear, structured formats
- Identifying key themes, decisions, and action items
- Understanding context even with transcription errors
- Providing comprehensive yet concise analysis
- Maintaining professional, helpful tone

Always use the exact formatting requested and be thorough in your analysis.''',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 800,
          'temperature': 0.3,
          'top_p': 0.9,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final choices = data['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          throw Exception('No response choices returned from Groq API');
        }

        final message = choices[0]['message'];
        if (message == null || message['content'] == null) {
          throw Exception('Invalid response format from Groq API');
        }

        final result = message['content'] as String;

        if (data['usage'] != null) {
          final usage = data['usage'];
          debugPrint('Token usage: ${usage['total_tokens']} total');
        }

        return result.trim();
      } else {
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']?['message'] ?? 'Unknown API error';
          throw Exception('Groq AI API error (${response.statusCode}): $errorMessage');
        } catch (e) {
          throw Exception('Groq AI API error: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Network error: Please check your internet connection and try again.');
      } else if (e.toString().contains('401')) {
        throw Exception('API authentication failed: Please check your Groq API key.');
      } else if (e.toString().contains('429')) {
        throw Exception('Rate limit exceeded: Please wait a moment and try again.');
      } else if (e.toString().contains('500')) {
        throw Exception('Groq service temporarily unavailable: Please try again later.');
      } else {
        rethrow;
      }
    }
  }

  Future<String> extractKeywords(String transcript) async {
    final prompt = '''
Extract the most important keywords and phrases from this transcript:

"$transcript"

Provide a well-organized list using this format:

**🏷️ KEY TERMS:**
• [Important words and concepts]
• [Technical terms or jargon]

**👤 PEOPLE & ENTITIES:**
• [Names of people mentioned]
• [Companies, organizations, brands]

**📍 PLACES & LOCATIONS:**
• [Cities, addresses, venues]
• [Geographic references]

**📊 NUMBERS & DATA:**
• [Dates, times, deadlines]
• [Financial figures, quantities]
• [Statistics or measurements]

**🎯 ACTION KEYWORDS:**
• [Verbs indicating tasks or decisions]
• [Priority or urgency indicators]

Focus only on the most relevant and actionable elements.
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _fastModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a keyword extraction specialist. Extract the most important and actionable elements from text, organizing them clearly and concisely.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 300,
          'temperature': 0.2,
          'top_p': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['choices'][0]['message']['content'] as String;
        return result.trim();
      } else {
        throw Exception('Groq AI API error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> analyzeConversation(String transcript) async {
    final prompt = '''
Perform a detailed conversation analysis of this transcript:

"$transcript"

Provide comprehensive insights using this structure:

**🎭 CONVERSATION PROFILE:**
• Type: [meeting, interview, lecture, phone call, casual chat, etc.]
• Participants: [number of speakers and roles if identifiable]
• Duration: [estimated length based on content]
• Setting: [formal, informal, professional, personal]

**🎯 SENTIMENT ANALYSIS:**
• Overall tone: [positive, neutral, concerned, urgent, excited, etc.]
• Emotional progression: [how sentiment changes throughout]
• Key emotional moments: [highlights of strong reactions]

**💬 COMMUNICATION PATTERNS:**
• Speaking style: [conversational, formal, technical, casual]
• Question types: [clarifying, probing, rhetorical, etc.]
• Decision-making process: [collaborative, directive, consensus-based]

**🔍 CONTENT ANALYSIS:**
• Information density: [light, moderate, information-heavy]
• Technical complexity: [basic, intermediate, advanced]
• Clarity: [clear, some ambiguity, needs clarification]

**⚡ URGENCY & PRIORITY INDICATORS:**
• Time-sensitive items: [immediate, short-term, long-term]
• Priority levels: [high, medium, low priority items]
• Deadlines mentioned: [specific dates or timeframes]

**🎯 ACTIONABILITY SCORE:**
• Overall score: [1-10 scale]
• Reasoning: [why this score was assigned]
• Improvement suggestions: [how to make more actionable]

Provide specific examples from the transcript to support your analysis.
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _qualityModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a conversation analysis expert specializing in understanding communication patterns, sentiment, and actionable insights from dialogue.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 700,
          'temperature': 0.3,
          'top_p': 0.9,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['choices'][0]['message']['content'] as String;
        return result.trim();
      } else {
        throw Exception('Groq AI API error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> extractActionItems(String transcript) async {
    final prompt = '''
Extract all actionable items from this transcript:

"$transcript"

Organize them using this format:

**🚨 IMMEDIATE ACTIONS (0-24 hours):**
• [Tasks that need immediate attention]
• [Urgent decisions or responses required]

**📅 SHORT-TERM ACTIONS (1-7 days):**
• [Tasks with near-term deadlines]
• [Follow-up items and scheduled activities]

**📆 MEDIUM-TERM ACTIONS (1-4 weeks):**
• [Project milestones and deliverables]
• [Planning and preparation tasks]

**🎯 LONG-TERM ACTIONS (1+ months):**
• [Strategic initiatives and goals]
• [Major projects or commitments]

**👤 ASSIGNED RESPONSIBILITIES:**
• [Person]: [specific task or responsibility]
• [Role/Team]: [their assigned actions]

**⏰ DEADLINES & TIMEFRAMES:**
• [Task]: [specific deadline or timeframe]
• [Milestone]: [target completion date]

**🔄 FOLLOW-UP REQUIRED:**
• [Items needing status updates]
• [Meetings or check-ins to schedule]
• [Reports or documentation needed]

**❓ UNCLEAR/PENDING ITEMS:**
• [Actions mentioned but need clarification]
• [Dependencies waiting for other decisions]

Focus on concrete, actionable items that can be tracked and completed.
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _defaultModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a task extraction specialist. Your goal is to identify all actionable items, commitments, and responsibilities from conversations, organizing them by priority and timeline.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 600,
          'temperature': 0.2,
          'top_p': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['choices'][0]['message']['content'] as String;
        return result.trim();
      } else {
        throw Exception('Groq AI API error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> generateMeetingSummary(String transcript) async {
    final prompt = '''
Generate a professional meeting summary from this transcript:

"$transcript"

Create a comprehensive summary using this executive format:

**📊 MEETING OVERVIEW**
• Date/Time: [if mentioned or "As recorded"]
• Participants: [number and roles if identifiable]
• Purpose: [main objective of the meeting]
• Duration: [estimated length]

**🎯 KEY DECISIONS MADE**
• [List all concrete decisions reached]
• [Include rationale where mentioned]

**📋 ACTION ITEMS & ASSIGNMENTS**
• [Specific tasks with owners if mentioned]
• [Deadlines and timelines]

**📝 IMPORTANT DISCUSSIONS**
• [Major topics covered]
• [Key points raised and debated]

**📊 DATA & METRICS MENTIONED**
• [Numbers, statistics, or measurements]
• [Performance indicators or targets]

**⚠️ RISKS & CONCERNS RAISED**
• [Potential problems identified]
• [Mitigation strategies discussed]

**💡 OPPORTUNITIES IDENTIFIED**
• [Potential benefits or improvements]
• [New initiatives or ideas proposed]

**🔄 FOLLOW-UP REQUIRED**
• [Next meeting scheduled]
• [Reports or updates needed]
• [External stakeholders to contact]

**📝 EXECUTIVE SUMMARY**
[2-3 sentence summary of the meeting outcome and next steps]

Format this as a professional document suitable for distribution to stakeholders.
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _qualityModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are an executive assistant specializing in meeting documentation. Create professional, comprehensive meeting summaries that capture all important decisions, actions, and discussions in a format suitable for executive review and distribution.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'max_tokens': 800,
          'temperature': 0.3,
          'top_p': 0.9,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['choices'][0]['message']['content'] as String;
        return result.trim();
      } else {
        throw Exception('Groq AI API error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  bool get isConfigured => _apiKey.isNotEmpty && _apiKey != 'YOUR_GROQ_API_KEY_HERE';

  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _fastModel,
          'messages': [
            {
              'role': 'user',
              'content': 'Test connection. Please respond with "Connection successful" and current timestamp.',
            }
          ],
          'max_tokens': 50,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final testResponse = data['choices'][0]['message']['content'] as String;

        return {
          'success': true,
          'message': 'Connection successful',
          'response': testResponse,
          'model': _fastModel,
          'usage': data['usage'],
        };
      } else {
        return {
          'success': false,
          'message': 'Connection failed: ${response.statusCode}',
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
        'error': e.toString(),
      };
    }
  }

  List<String> get availableModels => [
    _fastModel,
    _qualityModel,
    'llama3-70b-8192',
    'gemma-7b-it',
  ];

  String get currentModel => _defaultModel;

  Future<bool> isHealthy() async {
    try {
      final result = await testConnection();
      return result['success'] ?? false;
    } catch (e) {
      return false;
    }
  }
}