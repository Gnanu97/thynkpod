// lib/diary_tracking/screens/diary_main_screen.dart - ENHANCED WITH DATABASE INTEGRATION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/diary_provider.dart';
import '../services/groq_sentiment_service.dart';
import '../models/diary_models.dart';
import '../../services/audio_database_service.dart';
import '../../models/audio_file_data.dart';
import 'monthly_trends_screen.dart';

class DiaryMainScreen extends StatefulWidget {
  const DiaryMainScreen({Key? key}) : super(key: key);

  @override
  State<DiaryMainScreen> createState() => _DiaryMainScreenState();
}

class _DiaryMainScreenState extends State<DiaryMainScreen> {
  bool _isAnalyzing = false;
  bool _isLoadingSummary = false;
  DateTime _selectedDate = DateTime.now();
  String? _dailySummary;
  late GroqSentimentService _sentimentService;
  late AudioDatabaseService _audioService;

  @override
  void initState() {
    super.initState();
    _sentimentService = GroqSentimentService();
    _audioService = AudioDatabaseService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiaryProvider>().loadTodaysData();
      _loadDailySummary();
    });
  }

  Future<void> _loadDailySummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      // Get all transcripts for the selected date using your database service
      final transcripts = await _audioService.getTranscriptsForDate(_selectedDate);

      if (transcripts.isNotEmpty) {
        // Combine all transcripts for the day
        final combinedText = transcripts.map((t) => t.transcript).join(' ');

        // Generate summary using Groq API
        final summary = await _sentimentService.generateDailySummary(combinedText);
        setState(() => _dailySummary = summary);
      } else {
        setState(() => _dailySummary = null);
      }
    } catch (e) {
      debugPrint('Error loading daily summary: $e');
      setState(() => _dailySummary = null);
    }
    setState(() => _isLoadingSummary = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFA0A0A0), Color(0xFF3A3A3A)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: Consumer<DiaryProvider>(builder: _buildContent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Text(
              'Daily Tracker',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, DiaryProvider provider, Widget? child) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildDatePicker(),
                const SizedBox(height: 20),
                _buildDailySummary(),
                const SizedBox(height: 20),
                _buildQuickEntry(provider),
                if (provider.todaysEntry?.aiSummary?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 20),
                  _buildAIAnalysisResult(provider),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        _buildBottomTrendsButton(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              color: Colors.white.withOpacity(0.9),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, MMMM d, y').format(_selectedDate),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF3A3A3A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Summary of the Day',
                  style: TextStyle(
                    color: Color(0xFF3A3A3A),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _isLoadingSummary
                ? Container(
              key: const ValueKey('loading'),
              height: 120,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF737373),
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Analyzing your day...',
                      style: TextStyle(
                        color: Color(0xFF737373),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : _dailySummary != null
                ? Container(
              key: const ValueKey('summary'),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF737373).withOpacity(0.2),
                ),
              ),
              child: Text(
                _dailySummary!,
                style: const TextStyle(
                  color: Color(0xFF3A3A3A),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            )
                : Container(
              key: const ValueKey('empty'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF737373).withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.mic_off_outlined,
                    color: const Color(0xFF737373).withOpacity(0.6),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No recordings found for this date',
                    style: TextStyle(
                      color: const Color(0xFF737373).withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start recording to see your daily summary',
                    style: TextStyle(
                      color: const Color(0xFF737373).withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickEntry(DiaryProvider provider) {
    final entry = provider.todaysEntry;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('How was your day?', style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 18, fontWeight: FontWeight.w700)),
              Text(DateTime.now().day.toString(), style: const TextStyle(color: Color(0xFF737373), fontSize: 32, fontWeight: FontWeight.w300)),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildCategoryItem('Mood', entry?.moodEmoji ?? '😐', _getColor(entry?.moodScore, 'mood'), () => _showCategoryModal('mood', entry?.moodEmoji)),
              _buildCategoryItem('Stress', entry?.stressEmoji ?? '😌', _getColor(entry?.stressScore, 'stress'), () => _showCategoryModal('stress', entry?.stressEmoji)),
              _buildCategoryItem('Sleep', entry?.sleepEmoji ?? '😴', _getColor(entry?.sleepScore, 'sleep'), () => _showCategoryModal('sleep', entry?.sleepEmoji)),
              _buildCategoryItem('Social', entry?.socialEmoji ?? '😊', _getColor(entry?.socialScore, 'social'), () => _showCategoryModal('social', entry?.socialEmoji)),
              _buildCategoryItem('Food', entry?.foodEmoji ?? '😋', _getColor(entry?.foodScore, 'food'), () => _showCategoryModal('food', entry?.foodEmoji)),
              _buildAIAnalysisButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String label, String emoji, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAnalysisButton() {
    return GestureDetector(
      onTap: _isAnalyzing ? null : _performAIAnalysis,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isAnalyzing
                ? [const Color(0xFF9E9E9E), const Color(0xFF616161)]
                : [const Color(0xFF2196F3), const Color(0xFF1565C0)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isAnalyzing ? null : [
            BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isAnalyzing
                  ? const SizedBox(
                key: ValueKey('loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(
                key: ValueKey('icon'),
                Icons.auto_awesome,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isAnalyzing ? 'Analyzing...' : 'AI Analysis',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAnalysisResult(DiaryProvider provider) {
    final entry = provider.todaysEntry!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1565C0)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text('AI Analysis', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              if (entry.aiAvgMood != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getMoodColor(entry.aiAvgMood!).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Mood: ${entry.aiAvgMood!.toStringAsFixed(1)}',
                    style: TextStyle(color: _getMoodColor(entry.aiAvgMood!), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(entry.aiSummary!, style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.6)),
          if (entry.overallSentiment != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getSentimentColor(entry.overallSentiment!).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Overall: ${entry.overallSentiment!.toUpperCase()}',
                style: TextStyle(color: _getSentimentColor(entry.overallSentiment!), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomTrendsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonthlyTrendsScreen())),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.trending_up, size: 20),
              SizedBox(width: 8),
              Text('View Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF3A3A3A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF3A3A3A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _dailySummary = null;
      });
      _loadDailySummary();
    }
  }

  Future<void> _performAIAnalysis() async {
    setState(() => _isAnalyzing = true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final audioFiles = await _audioService.getAudioFilesForDate(today);
      final transcripts = audioFiles.where((f) => f.hasTranscript && f.transcript?.isNotEmpty == true).map((f) => f.transcript!).toList();

      if (transcripts.isEmpty) {
        _showDialog('No Voice Data', 'No voice recordings found for today. Please record some audio first to enable AI analysis.', Icons.info_outline, Colors.orange);
        return;
      }

      final combinedTranscript = transcripts.join('\n\n--- Next Recording ---\n\n');

      // Use the correct method from your GroqSentimentService
      final analysisResult = await _sentimentService.analyzeSentiment(combinedTranscript);

      // Extract mood and stress scores from the analysis
      final avgMood = (analysisResult['mood_score'] as num?)?.toDouble() ?? 3.0;
      final avgStress = (analysisResult['stress_score'] as num?)?.toDouble() ?? 3.0;
      final overallSentiment = _calculateSentiment(avgMood, avgStress);

      // Generate daily summary using the correct method signature
      final summary = await _sentimentService.generateDailySummary(combinedTranscript);

      if (!mounted) return;

      await context.read<DiaryProvider>().updateAIAnalysis(
        avgMood: avgMood,
        avgStress: avgStress,
        summary: summary,
        sentiment: overallSentiment,
      );
    } catch (e) {
      _showDialog('Error', 'Failed to perform AI analysis. Please try again.', Icons.error_outline, Colors.red);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showCategoryModal(String category, String? currentEmoji) {
    final emojis = _getEmojisForCategory(category);
    String? selectedEmoji = currentEmoji;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How was your $category?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF3A3A3A))),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis.map((emoji) {
                    final isSelected = selectedEmoji == emoji;
                    return GestureDetector(
                      onTap: () => setState(() => selectedEmoji = emoji),
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF2196F3).withOpacity(0.1) : Colors.grey[100],
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!, width: 2),
                        ),
                        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedEmoji != null ? () {
                          Navigator.pop(context);
                          context.read<DiaryProvider>().updateCategory(category, selectedEmoji!);
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods remain the same
  String _calculateSentiment(double mood, double stress) {
    if (mood >= 7.0 && stress <= 4.0) return 'positive';
    if (mood >= 5.5 && stress <= 6.0) return 'mixed';
    if (mood <= 4.0 || stress >= 7.0) return 'challenging';
    return 'neutral';
  }

  void _showDialog(String title, String content, IconData icon, Color iconColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [Icon(icon, color: iconColor), const SizedBox(width: 8), Text(title)]),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Color _getColor(double? score, String category) {
    if (score == null) return const Color(0xFF737373);
    if (score >= 4.5) return const Color(0xFF4CAF50);
    if (score >= 3.5) return const Color(0xFF8BC34A);
    if (score >= 2.5) return const Color(0xFFFFC107);
    if (score >= 1.5) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  Color _getMoodColor(double score) {
    if (score >= 4.0) return const Color(0xFF4CAF50);
    if (score >= 3.0) return const Color(0xFF8BC34A);
    if (score >= 2.5) return const Color(0xFFFFC107);
    return const Color(0xFFFF5722);
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive': return const Color(0xFF4CAF50);
      case 'mixed': return const Color(0xFFFFC107);
      case 'challenging': return const Color(0xFFFF5722);
      default: return const Color(0xFF737373);
    }
  }

  List<String> _getEmojisForCategory(String category) {
    switch (category) {
      case 'mood': return ['😭', '😢', '😐', '😊', '😄'];
      case 'stress': return ['🤯', '😰', '😬', '😌', '😴'];
      case 'sleep': return ['😵', '😪', '😐', '😊', '😴'];
      case 'social': return ['😞', '😕', '😐', '😊', '🥳'];
      case 'food': return ['🤢', '😕', '😐', '😋', '🤤'];
      default: return ['😐'];
    }
  }
}