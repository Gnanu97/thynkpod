// lib/finance_tracking/widgets/weekly_bar_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/finance_provider.dart';
import '../models/financial_transaction.dart';
import '../models/transaction_category.dart';

class WeeklyBarChart extends StatefulWidget {
  final FinanceProvider provider;

  const WeeklyBarChart({Key? key, required this.provider}) : super(key: key);

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart> {
  DateTime? _selectedDate;
  DateTime _currentWeek = DateTime.now();
  List<FinancialTransaction> _weekTransactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    setState(() => _isLoading = true);

    try {
      final startOfWeek = _getStartOfWeek(_currentWeek);
      final transactions = await widget.provider.getTransactionsForWeek(startOfWeek);

      setState(() {
        _weekTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Failed to load week data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 280,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF3A3A3A)),
        ),
      );
    }

    final weekData = _getWeekData();

    return Column(
      children: [
        Container(
          height: 280,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Spending',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getWeekRangeText(_getStartOfWeek(_currentWeek)),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF737373),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _navigateWeek(-1),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Color(0xFF737373),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _navigateWeek(1),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF737373),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tap any day to see category breakdown',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF737373),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _getMaxAmount(weekData) * 1.2,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        if (event is FlTapUpEvent && barTouchResponse?.spot != null) {
                          final index = barTouchResponse!.spot!.touchedBarGroupIndex;
                          final date = _getStartOfWeek(_currentWeek).add(Duration(days: index));
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      },
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => const Color(0xFF3A3A3A),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final date = _getStartOfWeek(_currentWeek).add(Duration(days: groupIndex));
                          return BarTooltipItem(
                            '${_getDayName(date)}\n${date.day}\n₹${rod.toY.toInt()}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final date = _getStartOfWeek(_currentWeek).add(Duration(days: value.toInt()));
                            final dayName = _getDayName(date);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '$dayName\n${date.day}',
                                style: const TextStyle(
                                  color: Color(0xFF737373),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                          reservedSize: 35,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          interval: _getYAxisInterval(weekData),
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value == 0) return const SizedBox.shrink();

                            final interval = _getYAxisInterval(weekData);
                            if ((value % interval).abs() > 0.01) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                _formatYAxisValue(value),
                                style: const TextStyle(
                                  color: Color(0xFF737373),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _getYAxisInterval(weekData),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    barGroups: weekData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final amount = entry.value;
                      final isToday = _isTodayIndex(index);
                      final isSelected = _selectedDate != null && _isSelectedIndex(index);

                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: amount,
                            color: isSelected
                                ? const Color(0xFF4CAF50)
                                : isToday
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFA0A0A0),
                            width: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_selectedDate != null)
          _buildSelectedDateDetails(),
      ],
    );
  }

  Widget _buildSelectedDateDetails() {
    if (_selectedDate == null) return const SizedBox.shrink();

    // Get transactions for selected date from the loaded week data
    final selectedDateTransactions = _weekTransactions.where((transaction) {
      return _isSameDate(transaction.date, _selectedDate!);
    }).toList();

    // Group by category
    final categoryTotals = <String, double>{};
    final categoryTransactions = <String, List<FinancialTransaction>>{};

    for (final transaction in selectedDateTransactions) {
      final category = transaction.category;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + transaction.amount;
      categoryTransactions[category] = (categoryTransactions[category] ?? [])..add(transaction);
    }

    final totalAmount = selectedDateTransactions.fold(0.0, (sum, t) => sum + t.amount);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatSelectedDate(_selectedDate!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₹${totalAmount.toInt()}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (selectedDateTransactions.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'No expenses recorded',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categoryTotals.length,
                itemBuilder: (context, index) {
                  final categoryName = categoryTotals.keys.elementAt(index);
                  final categoryAmount = categoryTotals[categoryName]!;
                  final transactions = categoryTransactions[categoryName]!;
                  final category = TransactionCategory.fromString(categoryName);

                  return GestureDetector(
                    onTap: () => _showCategoryTransactions(context, categoryName, transactions),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: category.color.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(category.icon, color: category.color, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  category.displayName,
                                  style: TextStyle(
                                    color: category.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${transactions.length} item${transactions.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(
                            '₹${categoryAmount.toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCategoryTransactions(BuildContext context, String categoryName, List<FinancialTransaction> transactions) {
    final category = TransactionCategory.fromString(categoryName);
    final totalAmount = transactions.fold(0.0, (sum, t) => sum + t.amount);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500),
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: category.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(category.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$categoryName - ${_formatSelectedDate(_selectedDate!)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Total: ₹${totalAmount.toInt()} • ${transactions.length} items',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF737373),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 20, color: Color(0xFF737373)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: category.color.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: category.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaction.displayText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF737373),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${transaction.amount.toInt()}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: category.color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateWeek(int direction) {
    setState(() {
      _currentWeek = _currentWeek.add(Duration(days: 7 * direction));
      _selectedDate = null; // Clear selection when changing weeks
    });
    _loadWeekData();
  }

  List<double> _getWeekData() {
    final startOfWeek = _getStartOfWeek(_currentWeek);
    final weekData = List<double>.filled(7, 0.0);

    for (final transaction in _weekTransactions) {
      final dayIndex = transaction.date.difference(startOfWeek).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        weekData[dayIndex] += transaction.amount;
      }
    }
    return weekData;
  }

  // FIXED: Proper start of week calculation (Monday-based, timezone-aware)
  DateTime _getStartOfWeek(DateTime date) {
    // Convert to local date only (removes time component)
    final localDate = DateTime(date.year, date.month, date.day);
    // ISO week starts on Monday (weekday 1)
    final daysFromMonday = localDate.weekday - 1;
    return localDate.subtract(Duration(days: daysFromMonday));
  }

  double _getMaxAmount(List<double> data) {
    final max = data.isEmpty ? 100.0 : data.reduce((a, b) => a > b ? a : b);
    return max == 0 ? 100.0 : max;
  }

  double _getYAxisInterval(List<double> data) {
    final max = _getMaxAmount(data);

    if (max <= 100) return 25;
    if (max <= 500) return 100;
    if (max <= 1000) return 250;
    if (max <= 2000) return 500;
    if (max <= 5000) return 1000;
    if (max <= 10000) return 2000;
    if (max <= 20000) return 5000;
    if (max <= 50000) return 10000;
    if (max <= 100000) return 20000;

    return (max / 4).roundToDouble();
  }

  String _formatYAxisValue(double value) {
    if (value >= 1000) {
      final thousands = value / 1000;
      if (thousands == thousands.round()) {
        return '₹${thousands.round()}k';
      } else {
        return '₹${thousands.toStringAsFixed(1)}k';
      }
    } else {
      return '₹${value.round()}';
    }
  }

  String _getDayName(DateTime date) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[date.weekday % 7];
  }

  bool _isTodayIndex(int index) {
    final today = DateTime.now();
    final todayLocal = DateTime(today.year, today.month, today.day);
    final startOfWeek = _getStartOfWeek(_currentWeek);
    final targetDate = startOfWeek.add(Duration(days: index));

    return todayLocal == targetDate;
  }

  bool _isSelectedIndex(int index) {
    if (_selectedDate == null) return false;
    final startOfWeek = _getStartOfWeek(_currentWeek);
    final targetDate = startOfWeek.add(Duration(days: index));
    final selectedLocal = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);

    return selectedLocal == targetDate;
  }

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getWeekRangeText(DateTime startOfWeek) {
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    if (startOfWeek.month == endOfWeek.month) {
      // Same month: "Sep 2-8, 2025"
      return '${months[startOfWeek.month - 1]} ${startOfWeek.day}-${endOfWeek.day}, ${startOfWeek.year}';
    } else {
      // Different months: "Aug 30 - Sep 5, 2025"
      return '${months[startOfWeek.month - 1]} ${startOfWeek.day} - ${months[endOfWeek.month - 1]} ${endOfWeek.day}, ${startOfWeek.year}';
    }
  }

  bool _isCurrentWeek() {
    final now = DateTime.now();
    final currentWeekStart = _getStartOfWeek(now);
    final viewingWeekStart = _getStartOfWeek(_currentWeek);

    return currentWeekStart == viewingWeekStart;
  }

  String _formatSelectedDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }
}