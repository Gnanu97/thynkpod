// lib/diary_tracking/screens/monthly_trends_screen.dart - COMPACT VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../providers/diary_provider.dart';

class MonthlyTrendsScreen extends StatefulWidget {
  const MonthlyTrendsScreen({Key? key}) : super(key: key);

  @override
  State<MonthlyTrendsScreen> createState() => _MonthlyTrendsScreenState();
}

class _MonthlyTrendsScreenState extends State<MonthlyTrendsScreen> {
  DateTime _currentMonth = DateTime.now();
  List<Map<String, dynamic>> _monthData = [];
  bool _isLoading = true;
  bool _isWeeklyView = true;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    try {
      final provider = context.read<DiaryProvider>();
      _monthData = await provider.getMonthlyChartData(_currentMonth.year, _currentMonth.month);
    } catch (e) {
      debugPrint('Error loading month data: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMonthNavigator(),
            Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.white)) : _buildChartsView()),
          ],
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
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(child: Text('Mood Chart', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    final monthName = DateFormat('MMMM yyyy').format(_currentMonth);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
              _loadMonthData();
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
            ),
          ),
          Expanded(child: Center(child: Text(monthName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)))),
          GestureDetector(
            onTap: () {
              final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
              if (nextMonth.isBefore(DateTime.now()) || (nextMonth.year == DateTime.now().year && nextMonth.month == DateTime.now().month)) {
                setState(() => _currentMonth = nextMonth);
                _loadMonthData();
              }
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCalendarChart(),
          const SizedBox(height: 16),
          _buildMoodDistribution(),
          const SizedBox(height: 16),
          _buildChart(),
        ],
      ),
    );
  }

  Widget _buildCalendarChart() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF2a2a2a), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)))))
                .toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayIndex = index - (firstWeekday % 7) + 1;
              if (dayIndex < 1 || dayIndex > daysInMonth) return Container();
              final dayData = _monthData.firstWhere((data) => data['day'] == dayIndex, orElse: () => <String, dynamic>{});
              return _buildCalendarDay(dayIndex, dayData);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDay(int day, Map<String, dynamic> dayData) {
    final hasData = dayData.isNotEmpty;
    final moodScore = dayData['moodScore'] as double?;
    final selectedDate = DateTime(_currentMonth.year, _currentMonth.month, day);
    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    final isPastDay = selectedDate.isBefore(DateTime.now()) && !isToday;

    Color dayColor;
    String emoji = '+';

    if (hasData && moodScore != null) {
      if (moodScore >= 4.0) { dayColor = const Color(0xFF4CAF50); emoji = '😄'; }
      else if (moodScore >= 3.0) { dayColor = const Color(0xFF8BC34A); emoji = '😊'; }
      else if (moodScore >= 2.0) { dayColor = const Color(0xFFFFC107); emoji = '😐'; }
      else { dayColor = const Color(0xFFFF5722); emoji = '😢'; }
    } else {
      dayColor = Colors.white.withOpacity(0.1);
    }

    return GestureDetector(
      onTap: () => _showDayInputModal(selectedDate, hasData),
      child: Container(
        decoration: BoxDecoration(
          color: dayColor,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasData && moodScore != null)
              Text(emoji, style: const TextStyle(fontSize: 16))
            else if (isPastDay || isToday)
              Icon(Icons.add, color: Colors.white.withOpacity(0.7), size: 16)
            else
              Icon(Icons.add, color: Colors.white.withOpacity(0.3), size: 12),
            Text(day.toString(), style: TextStyle(color: hasData ? Colors.white : Colors.white60, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodDistribution() {
    final distribution = _calculateMoodDistribution();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF2a2a2a), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Mood Count', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Tap on mood to see more', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 160, height: 160,
              child: CustomPaint(
                painter: DonutChartPainter(distribution),
                child: Center(child: Text('${distribution.values.fold(0, (sum, count) => sum + count)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w300))),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('😄', 'great', distribution['great'] ?? 0, const Color(0xFF4CAF50)),
              _buildLegendItem('😊', 'good', distribution['good'] ?? 0, const Color(0xFF8BC34A)),
              _buildLegendItem('😐', 'okay', distribution['okay'] ?? 0, const Color(0xFFFFC107)),
              _buildLegendItem('😢', 'bad', distribution['bad'] ?? 0, const Color(0xFFFF5722)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String emoji, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
        ),
        const SizedBox(height: 4),
        Text(count.toString(), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _buildChart() {
    if (_monthData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        height: 300,
        decoration: BoxDecoration(color: const Color(0xFF2a2a2a), borderRadius: BorderRadius.circular(16)),
        child: const Column(
          children: [
            Text('Mood Chart', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 20),
            Expanded(child: Center(child: Text('No data to display\nStart tracking your mood!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 16)))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      height: 350, // Fixed height for better layout
      decoration: BoxDecoration(color: const Color(0xFF2a2a2a), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mood Chart', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const Text('Daily mood trends this month', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildChartButton('Monthly', !_isWeeklyView, () => setState(() => _isWeeklyView = false))),
              const SizedBox(width: 12),
              Expanded(child: _buildChartButton('Weekly', _isWeeklyView, () => setState(() => _isWeeklyView = true))),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isWeeklyView
                ? CustomPaint(painter: WeeklyChartPainter(_monthData, _currentMonth), size: Size.infinite)
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 2, // Double screen width for monthly view
                child: CustomPaint(painter: MonthlyChartPainter(_monthData, _currentMonth), size: Size.infinite),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartButton(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2196F3), width: 1),
        ),
        child: Center(
          child: Text(title, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF2196F3), fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  void _showDayInputModal(DateTime selectedDate, bool hasExistingData) {
    final isPastOrToday = selectedDate.isBefore(DateTime.now()) || DateUtils.isSameDay(selectedDate, DateTime.now());
    if (!isPastOrToday) return;
    showDialog(context: context, builder: (context) => DayInputModal(selectedDate: selectedDate, hasExistingData: hasExistingData, onSaved: _loadMonthData));
  }

  Map<String, int> _calculateMoodDistribution() {
    final distribution = {'great': 0, 'good': 0, 'okay': 0, 'bad': 0};
    for (final dayData in _monthData) {
      final moodScore = dayData['moodScore'] as double?;
      if (moodScore != null) {
        if (moodScore >= 4.0) distribution['great'] = (distribution['great'] ?? 0) + 1;
        else if (moodScore >= 3.0) distribution['good'] = (distribution['good'] ?? 0) + 1;
        else if (moodScore >= 2.0) distribution['okay'] = (distribution['okay'] ?? 0) + 1;
        else distribution['bad'] = (distribution['bad'] ?? 0) + 1;
      }
    }
    return distribution;
  }
}

class DayInputModal extends StatefulWidget {
  final DateTime selectedDate;
  final bool hasExistingData;
  final VoidCallback onSaved;
  const DayInputModal({Key? key, required this.selectedDate, required this.hasExistingData, required this.onSaved}) : super(key: key);
  @override
  State<DayInputModal> createState() => _DayInputModalState();
}

class _DayInputModalState extends State<DayInputModal> {
  String? selectedMoodEmoji;
  String? selectedStressEmoji;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(widget.selectedDate);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.hasExistingData ? 'Update $dateStr' : 'Add Entry for $dateStr', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF3A3A3A))),
            const SizedBox(height: 24),
            const Text('How was your mood?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['😭', '😢', '😐', '😊', '😄'].map((emoji) {
                final isSelected = selectedMoodEmoji == emoji;
                return GestureDetector(
                  onTap: () => setState(() => selectedMoodEmoji = emoji),
                  child: Container(
                    width: 45, height: 45,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2196F3).withOpacity(0.1) : Colors.grey[100],
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!, width: 2),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('How was your stress level?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['🤯', '😰', '😬', '😌', '😴'].map((emoji) {
                final isSelected = selectedStressEmoji == emoji;
                return GestureDetector(
                  onTap: () => setState(() => selectedStressEmoji = emoji),
                  child: Container(
                    width: 45, height: 45,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF2196F3).withOpacity(0.1) : Colors.grey[100],
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!, width: 2),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
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
                    onPressed: (selectedMoodEmoji != null && selectedStressEmoji != null) ? () async {
                      await _saveDayEntry();
                      Navigator.pop(context);
                      widget.onSaved();
                    } : null,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDayEntry() async {
    if (selectedMoodEmoji == null || selectedStressEmoji == null) return;
    try {
      final provider = context.read<DiaryProvider>();
      await provider.saveHistoricalEntry(widget.selectedDate, selectedMoodEmoji!, selectedStressEmoji!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Entry saved for ${DateFormat('MMM d').format(widget.selectedDate)}'), backgroundColor: const Color(0xFF4CAF50)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save entry'), backgroundColor: Color(0xFFFF5722)));
    }
  }
}

class DonutChartPainter extends CustomPainter {
  final Map<String, int> data;
  DonutChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final innerRadius = radius * 0.6;
    final total = data.values.fold(0, (sum, count) => sum + count);
    if (total == 0) return;

    final colors = [const Color(0xFF4CAF50), const Color(0xFF8BC34A), const Color(0xFFFFC107), const Color(0xFFFF5722)];
    double startAngle = -90 * 3.14159 / 180;

    int colorIndex = 0;
    for (final entry in data.entries) {
      if (entry.value > 0) {
        final sweepAngle = (entry.value / total) * 2 * 3.14159;
        final paint = Paint()..color = colors[colorIndex % colors.length]..style = PaintingStyle.stroke..strokeWidth = radius - innerRadius;
        canvas.drawArc(Rect.fromCircle(center: center, radius: (radius + innerRadius) / 2), startAngle, sweepAngle, false, paint);
        startAngle += sweepAngle;
      }
      colorIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WeeklyChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final DateTime currentMonth;

  WeeklyChartPainter(this.data, this.currentMonth);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final validData = data.where((d) => d['moodScore'] != null).toList()..sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
    if (validData.isEmpty) return;

    final weekData = validData.length > 7 ? validData.sublist(validData.length - 7) : validData;

    // Fixed emoji positioning issue with adequate left padding
    const padding = EdgeInsets.fromLTRB(60, 20, 20, 40); // Increased left padding
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    final textStyle = TextStyle(color: Colors.white60, fontSize: 11);
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 1;
    final linePaint = Paint()..color = const Color(0xFF64B5F6)..strokeWidth = 3..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = const Color(0xFF64B5F6);
    final areaPaint = Paint()..color = const Color(0xFF64B5F6).withOpacity(0.1);

    final yAxisLeft = padding.left;
    final yAxisTop = padding.top;
    final yAxisBottom = size.height - padding.bottom;

    // Y-axis
    canvas.drawLine(Offset(yAxisLeft, yAxisTop), Offset(yAxisLeft, yAxisBottom), Paint()..color = Colors.white.withOpacity(0.3)..strokeWidth = 2);

    // Y-axis emojis with proper spacing
    for (int i = 1; i <= 5; i++) {
      final y = yAxisBottom - ((i - 1) / 4) * chartHeight;
      canvas.drawLine(Offset(yAxisLeft, y), Offset(yAxisLeft + chartWidth, y), gridPaint);

      final emoji = ['😢', '😕', '😐', '😊', '😄'][i - 1];
      final emojiPainter = TextPainter(text: TextSpan(text: emoji, style: TextStyle(fontSize: 16)), textDirection: ui.TextDirection.ltr);
      emojiPainter.layout();
      // Fixed positioning - emojis now have enough space
      emojiPainter.paint(canvas, Offset(yAxisLeft - 30, y - emojiPainter.height / 2));
    }

    // X-axis
    canvas.drawLine(Offset(yAxisLeft, yAxisBottom), Offset(yAxisLeft + chartWidth, yAxisBottom), Paint()..color = Colors.white.withOpacity(0.3)..strokeWidth = 2);

    // Draw data
    final daySpacing = weekData.length > 1 ? chartWidth / (weekData.length - 1) : 0;
    final path = Path();
    final areaPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < weekData.length; i++) {
      final day = weekData[i]['day'] as int;
      final moodScore = (weekData[i]['moodScore'] as double).clamp(1.0, 5.0);
      final x = yAxisLeft + (weekData.length > 1 ? i * daySpacing : chartWidth / 2);
      final y = yAxisBottom - ((moodScore - 1) / 4) * chartHeight;

      points.add(Offset(x, y));

      // X-axis labels
      final textPainter = TextPainter(text: TextSpan(text: day.toString(), style: textStyle), textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, yAxisBottom + 8));

      if (i == 0) {
        path.moveTo(x, y);
        areaPath.moveTo(x, yAxisBottom);
        areaPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
    }

    if (points.isNotEmpty) {
      areaPath.lineTo(points.last.dx, yAxisBottom);
      areaPath.close();
    }

    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 6, pointPaint);
      canvas.drawCircle(point, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class MonthlyChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final DateTime currentMonth;

  MonthlyChartPainter(this.data, this.currentMonth);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final validData = data.where((d) => d['moodScore'] != null).toList()..sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
    if (validData.isEmpty) return;

    // More generous padding for emojis
    const padding = EdgeInsets.fromLTRB(60, 20, 20, 40);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;
    final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

    final textStyle = TextStyle(color: Colors.white60, fontSize: 10);
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.08)..strokeWidth = 0.8;
    final linePaint = Paint()..color = const Color(0xFF64B5F6)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = const Color(0xFF64B5F6);
    final areaPaint = Paint()..color = const Color(0xFF64B5F6).withOpacity(0.08);

    final yAxisLeft = padding.left;
    final yAxisTop = padding.top;
    final yAxisBottom = size.height - padding.bottom;

    // Y-axis
    canvas.drawLine(Offset(yAxisLeft, yAxisTop), Offset(yAxisLeft, yAxisBottom), Paint()..color = Colors.white.withOpacity(0.4)..strokeWidth = 1.5);

    // Y-axis emojis with fixed positioning
    for (int i = 1; i <= 5; i++) {
      final y = yAxisBottom - ((i - 1) / 4) * chartHeight;
      canvas.drawLine(Offset(yAxisLeft, y), Offset(yAxisLeft + chartWidth, y), gridPaint);

      final emoji = ['😢', '😕', '😐', '😊', '😄'][i - 1];
      final emojiPainter = TextPainter(text: TextSpan(text: emoji, style: TextStyle(fontSize: 14)), textDirection: ui.TextDirection.ltr);
      emojiPainter.layout();
      // Positioned with enough clearance from Y-axis
      emojiPainter.paint(canvas, Offset(yAxisLeft - 35, y - emojiPainter.height / 2));
    }

    // X-axis
    canvas.drawLine(Offset(yAxisLeft, yAxisBottom), Offset(yAxisLeft + chartWidth, yAxisBottom), Paint()..color = Colors.white.withOpacity(0.4)..strokeWidth = 1.5);

    // All grid lines with ALL date labels shown
    for (int day = 1; day <= daysInMonth; day++) {
      final x = yAxisLeft + ((day - 1) / (daysInMonth - 1)) * chartWidth;
      canvas.drawLine(Offset(x, yAxisTop), Offset(x, yAxisBottom), gridPaint);

      // Show ALL dates on x-axis
      final textPainter = TextPainter(text: TextSpan(text: day.toString(), style: textStyle), textDirection: ui.TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, yAxisBottom + 6));
    }

    // Draw data - connect only actual data points
    final path = Path();
    final areaPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < validData.length; i++) {
      final dayData = validData[i];
      final day = dayData['day'] as int;
      final moodScore = (dayData['moodScore'] as double).clamp(1.0, 5.0);
      final x = yAxisLeft + ((day - 1) / (daysInMonth - 1)) * chartWidth;
      final y = yAxisBottom - ((moodScore - 1) / 4) * chartHeight;

      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
        areaPath.moveTo(x, yAxisBottom);
        areaPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        areaPath.lineTo(x, y);
      }
    }

    if (points.isNotEmpty) {
      areaPath.lineTo(points.last.dx, yAxisBottom);
      areaPath.close();
    }

    // Draw area, line, and points
    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      // Subtle glow
      canvas.drawCircle(point, 8, Paint()..color = const Color(0xFF64B5F6).withOpacity(0.2));
      // Main point
      canvas.drawCircle(point, 5, pointPaint);
      // White border
      canvas.drawCircle(point, 5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}