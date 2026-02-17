// lib/finance_tracking/screens/finance_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/financial_transaction.dart';
import '../models/transaction_category.dart';

class FinanceCalendarScreen extends StatefulWidget {
  const FinanceCalendarScreen({Key? key}) : super(key: key);

  @override
  State<FinanceCalendarScreen> createState() => _FinanceCalendarScreenState();
}

class _FinanceCalendarScreenState extends State<FinanceCalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  List<FinancialTransaction> _selectedDateTransactions = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA0A0A0), Color(0xFF3A3A3A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Consumer<FinanceProvider>(
                    builder: (context, provider, child) {
                      return Column(
                        children: [
                          _buildCalendarHeader(),
                          _buildWeekDaysHeader(),
                          Expanded(
                            child: _buildCalendarGrid(provider),
                          ),
                          if (_selectedDate != null)
                            _buildSelectedDateDetails(),
                        ],
                      );
                    },
                  ),
                ),
              ),
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
              width: 44, height: 44,
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
              'Expense Calendar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                _selectedDate = null; // Clear selection when changing months
              });
            },
            child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
          ),
          Text(
            _getMonthYearText(_currentMonth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                _selectedDate = null; // Clear selection when changing months
              });
            },
            child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDaysHeader() {
    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: weekDays.map((day) => Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(FinanceProvider provider) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;

    return FutureBuilder<List<FinancialTransaction>>(
      // FIXED: Load transactions specifically for the calendar month being viewed
      future: provider.getTransactionsForDateRange(
          firstDayOfMonth,
          lastDayOfMonth.add(const Duration(days: 1))
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Error loading calendar data',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final monthTransactions = snapshot.data ?? [];

        // Group transactions by date
        final expensesByDate = <int, double>{};
        for (final transaction in monthTransactions) {
          // Only include transactions from the current month being viewed
          if (transaction.date.year == _currentMonth.year &&
              transaction.date.month == _currentMonth.month) {
            final day = transaction.date.day;
            expensesByDate[day] = (expensesByDate[day] ?? 0) + transaction.amount;
          }
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.8,
          ),
          itemCount: firstDayOfWeek + lastDayOfMonth.day,
          itemBuilder: (context, index) {
            if (index < firstDayOfWeek) {
              return const SizedBox.shrink(); // Empty cells for days before month start
            }

            final day = index - firstDayOfWeek + 1;
            final currentDate = DateTime(_currentMonth.year, _currentMonth.month, day);
            final isToday = _isSameDate(currentDate, DateTime.now());
            final isSelected = _selectedDate != null && _isSameDate(currentDate, _selectedDate!);
            final totalExpense = expensesByDate[day] ?? 0;

            return GestureDetector(
              onTap: () async {
                // Load transactions for the selected date
                final transactions = await provider.getTransactionsForDate(currentDate);
                setState(() {
                  _selectedDate = currentDate;
                  _selectedDateTransactions = transactions;
                });
              },
              child: _buildDayCell(day, totalExpense, isToday, isSelected),
            );
          },
        );
      },
    );
  }

  Widget _buildDayCell(int day, double totalExpense, bool isToday, bool isSelected) {
    Color backgroundColor = Colors.transparent;
    Color textColor = Colors.white;
    Color borderColor = Colors.transparent;

    if (isSelected) {
      backgroundColor = const Color(0xFF4CAF50);
    } else if (isToday) {
      borderColor = const Color(0xFFA0A0A0);
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (totalExpense > 0) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                totalExpense >= 1000
                    ? '${(totalExpense / 1000).toStringAsFixed(1)}k'
                    : '${totalExpense.toInt()}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedDateDetails() {
    if (_selectedDate == null) return const SizedBox.shrink();

    // Use the loaded transactions instead of filtering from provider
    final selectedDateTransactions = _selectedDateTransactions;

    // Group by category and calculate totals
    final categoryTotals = <String, double>{};
    final categoryTransactions = <String, List<FinancialTransaction>>{};

    for (final transaction in selectedDateTransactions) {
      final category = transaction.category;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + transaction.amount;
      categoryTransactions[category] = (categoryTransactions[category] ?? [])..add(transaction);
    }

    final totalAmount = selectedDateTransactions.fold(0.0, (sum, t) => sum + t.amount);

    return Container(
      margin: const EdgeInsets.all(16),
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
                    onTap: () {
                      _showCategoryTransactions(context, categoryName, transactions);
                    },
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
              // Header
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
                      child: const Icon(
                        Icons.close,
                        size: 20,
                        color: Color(0xFF737373),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Transactions List
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
                        border: Border.all(
                          color: category.color.withOpacity(0.2),
                        ),
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

  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _getMonthYearText(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatSelectedDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}