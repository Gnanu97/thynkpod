// lib/finance_tracking/screens/finance_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/finance_provider.dart';
import '../models/transaction_category.dart';
import '../widgets/weekly_bar_chart.dart';
import 'category_detail_screen.dart';
import 'finance_calendar_screen.dart';

class FinanceDashboardScreen extends StatefulWidget {
  const FinanceDashboardScreen({Key? key}) : super(key: key);

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                  _buildHeader(context),
                  _buildTimePeriodSelector(context),
                  Expanded(
                    child: Consumer<FinanceProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }
                        return _buildContent(context, provider);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FinanceCalendarScreen()),
                );
              },
              backgroundColor: const Color(0xFFA0A0A0),
              child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  shape: BoxShape.circle
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Text(
                'Finance Tracker',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600
                )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePeriodSelector(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildPeriodButton(context, provider, TimePeriod.today, 'Today'),
              const SizedBox(width: 8),
              _buildPeriodButton(context, provider, TimePeriod.week, 'Week'),
              const SizedBox(width: 8),
              _buildPeriodButton(context, provider, TimePeriod.month, 'Month'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodButton(BuildContext context, FinanceProvider provider, TimePeriod period, String label) {
    final isSelected = provider.selectedPeriod == period;

    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setTimePeriod(period),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, FinanceProvider provider) {
    if (provider.selectedPeriod == TimePeriod.week) {
      return SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            WeeklyBarChart(provider: provider),
            const SizedBox(height: 20),
            _buildTotalCard(provider),
            const SizedBox(height: 100),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCleanPieChart(provider),
                const SizedBox(width: 20),
                Expanded(child: _buildCategorySummary(context, provider)),
              ],
            ),
            const SizedBox(height: 30),
            _buildCategoryBullets(context, provider),
            const SizedBox(height: 20),
            _buildTotalCard(provider),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // Clean pie chart without labels - only colors
  Widget _buildCleanPieChart(FinanceProvider provider) {
    final categoryTotals = provider.categoryTotals;
    final totalSpending = provider.totalSpending;

    if (categoryTotals.isEmpty || totalSpending == 0) {
      return Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  '₹0',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700
                  )
              ),
              Text(
                  'No Data',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12
                  )
              ),
            ],
          ),
        ),
      );
    }

    // Create pie chart sections without labels
    final sections = categoryTotals.entries.map((entry) {
      final category = TransactionCategory.fromString(entry.key);

      return PieChartSectionData(
        color: category.color,
        value: entry.value,
        title: '', // Remove title completely
        radius: 35,
        titleStyle: const TextStyle(fontSize: 0), // Hide any potential title
      );
    }).toList();

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 25,
              startDegreeOffset: -90,
            ),
          ),
        ),
        // Empty center - no text
        const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildCategorySummary(BuildContext context, FinanceProvider provider) {
    final percentages = provider.categoryPercentages;

    if (percentages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16)
        ),
        child: const Center(
          child: Text(
              'No expenses recorded',
              style: TextStyle(fontSize: 14, color: Color(0xFF737373))
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: percentages.entries.take(6).map((entry) {
          final categoryColor = TransactionCategory.fromString(entry.key).color;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: categoryColor,
                      shape: BoxShape.circle
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry.value.toInt()}%',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF737373)
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryBullets(BuildContext context, FinanceProvider provider) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: TransactionCategory.values.length,
      itemBuilder: (context, index) {
        final category = TransactionCategory.values[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => CategoryDetailScreen(category: category.displayName,timePeriod: provider.selectedPeriod)
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.displayName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotalCard(FinanceProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total: ₹${provider.totalSpending.toInt()}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFFA0A0A0),
                    size: 24,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: Colors.grey[300]),
                const SizedBox(height: 16),
                ...provider.categoryTotals.entries.map((entry) {
                  final categoryColor = TransactionCategory.fromString(entry.key).color;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: categoryColor,
                              shape: BoxShape.circle
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87
                            ),
                          ),
                        ),
                        Text(
                          '₹${entry.value.toInt()}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF737373)
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}