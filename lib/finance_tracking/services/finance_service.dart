import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/financial_transaction.dart';

class FinanceService extends ChangeNotifier {
  final Map<String, FinancialTransaction> _transactions = {};
  late File _financeFile;
  bool _initialized = false;

  List<FinancialTransaction> get transactions => _transactions.values.toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  double get totalExpenses => _transactions.values.fold(0, (sum, t) => sum + t.amount);

  Map<String, double> get categoryTotals {
    final Map<String, double> totals = {};
    for (final transaction in _transactions.values) {
      totals[transaction.category] = (totals[transaction.category] ?? 0) + transaction.amount;
    }
    return totals;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    final financeDir = Directory('${dir.path}/finance');
    if (!await financeDir.exists()) await financeDir.create();

    _financeFile = File('${financeDir.path}/transactions.json');
    await _loadTransactions();
    _initialized = true;
    debugPrint('Finance: Initialized with ${_transactions.length} transactions');
  }

  Future<void> _loadTransactions() async {
    if (!await _financeFile.exists()) return;

    final content = await _financeFile.readAsString();
    final Map<String, dynamic> json = jsonDecode(content);

    _transactions.clear();
    json.forEach((key, value) {
      _transactions[key] = FinancialTransaction.fromJson(value);
    });
  }

  Future<void> _saveTransactions() async {
    final json = _transactions.map((key, value) => MapEntry(key, value.toJson()));
    await _financeFile.writeAsString(jsonEncode(json));
  }

  Future<FinancialTransaction?> detectFinancialTransaction(String transcript, String audioFileName) async {
    final patterns = [
      RegExp(r'(?:paid|spent|cost|₹|rs\.?)\s*(\d+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:₹|rs\.?)', caseSensitive: false),
      RegExp(r'for\s+(\d+(?:\.\d{1,2})?)', caseSensitive: false),
    ];

    double? amount;
    for (final pattern in patterns) {
      final match = pattern.firstMatch(transcript);
      if (match != null) {
        amount = double.tryParse(match.group(1) ?? '');
        if (amount != null && amount > 0) break;
      }
    }

    if (amount == null || amount <= 0) return null;

    final category = _detectCategory(transcript);
    final description = _extractDescription(transcript, category);

    final transaction = FinancialTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      category: category,
      description: description,
      date: DateTime.now(),
      audioFileName: audioFileName,
    );

    await _saveTransaction(transaction);
    return transaction;
  }

  String _detectCategory(String transcript) {
    final text = transcript.toLowerCase();

    if (text.contains(RegExp(r'\b(food|eat|ate|lunch|dinner|breakfast|pani puri|pizza|coffee|restaurant)\b'))) return 'Food';
    if (text.contains(RegExp(r'\b(taxi|uber|bus|train|petrol|transport|travel|auto)\b'))) return 'Transportation';
    if (text.contains(RegExp(r'\b(doctor|medicine|hospital|health|medical|pharmacy)\b'))) return 'Health';
    if (text.contains(RegExp(r'\b(shopping|clothes|buy|purchase|market|store)\b'))) return 'Shopping';
    if (text.contains(RegExp(r'\b(book|course|education|study|school|college)\b'))) return 'Education';
    if (text.contains(RegExp(r'\b(rent|electricity|water|bill|grocery|essential)\b'))) return 'Essentials';
    if (text.contains(RegExp(r'\b(movie|game|entertainment|fun|party)\b'))) return 'Entertainment';

    return 'Other';
  }

  String _extractDescription(String transcript, String category) {
    final text = transcript.toLowerCase().trim();

    if (text.contains('pani puri')) return 'pani puri';
    if (text.contains('coffee')) return 'coffee';
    if (text.contains('lunch')) return 'lunch';
    if (text.contains('taxi') || text.contains('uber')) return 'taxi ride';
    if (text.contains('medicine')) return 'medicine';

    return category.toLowerCase();
  }

  Future<void> _saveTransaction(FinancialTransaction transaction) async {
    _transactions[transaction.id] = transaction;
    await _saveTransactions();
    notifyListeners();
  }

  List<FinancialTransaction> getTransactionsByCategory(String category) {
    return transactions.where((t) => t.category == category).toList();
  }

  List<FinancialTransaction> getTransactionsForPeriod(DateTime start, DateTime end) {
    return transactions.where((t) =>
    t.date.isAfter(start.subtract(const Duration(days: 1))) &&
        t.date.isBefore(end.add(const Duration(days: 1)))
    ).toList();
  }
}