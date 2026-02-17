import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/transaction_category.dart';
import '../models/financial_transaction.dart';
import '../widgets/transaction_edit_dialog.dart';
import '../utils/validation_utils.dart';

class CategoryDetailScreen extends StatelessWidget {
  final String category;
  final DateTime? selectedDate; // Add this
  final TimePeriod? timePeriod;  // Add this

  const CategoryDetailScreen({
    Key? key,
    required this.category,
    this.selectedDate,
    this.timePeriod,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categoryEnum = TransactionCategory.fromString(category);

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
              _buildHeader(context, categoryEnum),
              Expanded(
                child: Consumer<FinanceProvider>(
                  builder: (context, provider, child) {
                    var transactions = provider.getTransactionsByCategory(category);

                    // Filter by specific date if provided
                    if (selectedDate != null) {
                      transactions = transactions.where((transaction) {
                        return transaction.date.year == selectedDate!.year &&
                            transaction.date.month == selectedDate!.month &&
                            transaction.date.day == selectedDate!.day;
                      }).toList();
                    }

                    if (transactions.isEmpty) {
                      return _buildEmptyState();
                    }
                    return _buildTransactionsList(context, transactions, provider);
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TransactionCategory categoryEnum) {
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: categoryEnum.color,
              shape: BoxShape.circle,
            ),
            child: Icon(categoryEnum.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$category Expenses',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context, List<FinancialTransaction> transactions, FinanceProvider provider) {
    final totalAmount = transactions.fold(0.0, (sum, t) => sum + t.amount);
    final totalQuantity = transactions.fold(0, (sum, t) => sum + t.quantity);
    final totalSpending = provider.totalSpending;
    final percentage = totalSpending > 0 ? (totalAmount / totalSpending * 100).round() : 0;

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  _formatDate(DateTime.now()),
                  style: const TextStyle(
                    color: Color(0xFF737373),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      return _buildTransactionItem(context, transactions[index], provider);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total $category: ₹${totalAmount.toInt()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '$percentage% of expenses',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF737373),
                            ),
                          ),
                        ],
                      ),
                      if (totalQuantity > transactions.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Items: $totalQuantity',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF737373),
                                ),
                              ),
                              Text(
                                '${transactions.length} transactions',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF737373),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTransactionItem(BuildContext context, FinancialTransaction transaction, FinanceProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: TransactionCategory.fromString(transaction.category).color,
              borderRadius: BorderRadius.circular(3),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatTime(transaction.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF737373),
                      ),
                    ),
                    if (transaction.quantity > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TransactionCategory.fromString(transaction.category).color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          transaction.priceBreakdown,
                          style: TextStyle(
                            fontSize: 10,
                            color: TransactionCategory.fromString(transaction.category).color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${transaction.amount.toInt()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA0A0A0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.mic, size: 12, color: Color(0xFFA0A0A0)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEditDialog(context, transaction, provider),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showDeleteConfirmation(context, transaction, provider),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, FinancialTransaction transaction, FinanceProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => TransactionEditDialog(
        transaction: transaction,
        onSave: (updatedTransaction) async {
          final success = await provider.editTransaction(transaction.id, updatedTransaction);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${updatedTransaction.displayText} updated successfully'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                margin: const EdgeInsets.all(16),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update transaction'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, FinancialTransaction transaction, FinanceProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: const Text(
            'Delete Transaction',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this transaction?',
                style: TextStyle(color: Color(0xFF737373), fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 30,
                      decoration: BoxDecoration(
                        color: TransactionCategory.fromString(transaction.category).color,
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
                            '₹${transaction.amount.toInt()}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF737373),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF737373))),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _deleteTransaction(context, transaction, provider);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(BuildContext context, FinancialTransaction transaction, FinanceProvider provider) async {
    try {
      final success = await provider.deleteTransaction(transaction.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${transaction.displayText} deleted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete transaction'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.white70),
          SizedBox(height: 20),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Record expenses via voice to see them here',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}