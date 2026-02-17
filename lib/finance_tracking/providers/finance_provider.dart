import 'package:flutter/foundation.dart';
import '../services/finance_database_service.dart';
import '../models/financial_transaction.dart';
import '../utils/validation_utils.dart';

enum TimePeriod { today, week, month }

class FinanceProvider extends ChangeNotifier {
  final FinanceDatabaseService _dbService = FinanceDatabaseService();

  List<FinancialTransaction> _transactions = [];
  TimePeriod _selectedPeriod = TimePeriod.today;
  bool _isLoading = false;
  String? _lastError;

  // Cache for different time periods to avoid repeated queries
  Map<TimePeriod, List<FinancialTransaction>> _transactionCache = {};
  DateTime? _lastCacheUpdate;

  TimePeriod get selectedPeriod => _selectedPeriod;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  List<FinancialTransaction> get transactions => _transactions;

  List<FinancialTransaction> get filteredTransactions {
    return _transactions; // Already filtered by the targeted query
  }

  double get totalSpending {
    return _transactions.fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<String, double> get categoryTotals {
    final Map<String, double> totals = {};
    for (final transaction in _transactions) {
      totals[transaction.category] = (totals[transaction.category] ?? 0) + transaction.amount;
    }
    return totals;
  }

  Map<String, double> get categoryPercentages {
    final totals = categoryTotals;
    final total = totalSpending;
    if (total == 0) return {};
    return totals.map((key, value) => MapEntry(key, (value / total) * 100));
  }

  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      await _loadTransactionsForPeriod(_selectedPeriod);
    } catch (e) {
      _setError('Failed to initialize: $e');
      debugPrint('Finance Provider: Initialization failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadTransactionsForPeriod(TimePeriod period) async {
    try {
      // Check cache first (valid for 5 minutes)
      if (_isCacheValid(period)) {
        _transactions = _transactionCache[period] ?? [];
        notifyListeners();
        return;
      }

      List<FinancialTransaction> transactions;
      final now = DateTime.now();

      switch (period) {
        case TimePeriod.today:
          transactions = await _dbService.getTodayTransactions();
          break;

        case TimePeriod.week:
          final startOfWeek = _getStartOfWeek(now);
          transactions = await _dbService.getWeekTransactions(startOfWeek);
          break;

        case TimePeriod.month:
          transactions = await _dbService.getMonthTransactions(now.year, now.month);
          break;
      }

      // Update cache
      _transactionCache[period] = transactions;
      _lastCacheUpdate = DateTime.now();

      _transactions = transactions;
      _clearError();

      debugPrint('Finance Provider: Loaded ${transactions.length} transactions for $period');

    } catch (e) {
      _setError('Failed to load transactions: $e');
      debugPrint('Finance Provider: Failed to load transactions: $e');
      _transactions = [];
    }

    notifyListeners();
  }

  bool _isCacheValid(TimePeriod period) {
    if (_lastCacheUpdate == null || !_transactionCache.containsKey(period)) {
      return false;
    }

    final cacheAge = DateTime.now().difference(_lastCacheUpdate!);
    return cacheAge.inMinutes < 5; // Cache valid for 5 minutes
  }

  void setTimePeriod(TimePeriod period) async {
    if (_selectedPeriod == period) return;

    _selectedPeriod = period;
    _setLoading(true);

    try {
      await _loadTransactionsForPeriod(period);
    } catch (e) {
      _setError('Failed to switch time period: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<FinancialTransaction>> processVoiceTransaction(String transcript, String audioFileName) async {
    try {
      _clearError();
      final transactions = await _dbService.detectFinancialTransactions(transcript, audioFileName);

      if (transactions.isNotEmpty) {
        // Clear cache to force refresh
        _transactionCache.clear();
        await _loadTransactionsForPeriod(_selectedPeriod);
      }

      return transactions;
    } catch (e) {
      _setError('Voice processing failed: $e');
      debugPrint('Voice transaction processing failed: $e');
      return [];
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    try {
      _clearError();
      final success = await _dbService.deleteTransaction(transactionId);

      if (success) {
        // Clear cache and reload
        _transactionCache.clear();
        await _loadTransactionsForPeriod(_selectedPeriod);
      }

      return success;
    } catch (e) {
      _setError('Delete failed: $e');
      debugPrint('Delete transaction failed: $e');
      return false;
    }
  }

  Future<bool> editTransaction(String transactionId, FinancialTransaction updatedTransaction) async {
    try {
      _clearError();

      // Validate transaction data
      final validation = TransactionValidator.validateTransaction(
        amount: updatedTransaction.amount,
        category: updatedTransaction.category,
        description: updatedTransaction.description,
        date: updatedTransaction.date,
        quantity: updatedTransaction.quantity,
      );

      if (!validation.isValid) {
        _setError('Invalid transaction data: ${validation.allErrors}');
        return false;
      }

      final success = await _dbService.updateTransaction(transactionId, updatedTransaction);

      if (success) {
        // Clear cache and reload
        _transactionCache.clear();
        await _loadTransactionsForPeriod(_selectedPeriod);
      }

      return success;
    } catch (e) {
      _setError('Edit failed: $e');
      debugPrint('Edit transaction failed: $e');
      return false;
    }
  }

  List<FinancialTransaction> getTransactionsByCategory(String category) {
    return _transactions.where((t) => t.category == category).toList();
  }

  // NEW: Get transactions for specific date (used by calendar and weekly chart)
  Future<List<FinancialTransaction>> getTransactionsForDate(DateTime date) async {
    try {
      _clearError();
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      return await _dbService.getDateRangeTransactions(startOfDay, endOfDay);
    } catch (e) {
      _setError('Failed to get date transactions: $e');
      return [];
    }
  }



  // NEW: Get transactions for specific week (used by weekly chart)
  Future<List<FinancialTransaction>> getTransactionsForWeek(DateTime startOfWeek) async {
    try {
      _clearError();
      return await _dbService.getWeekTransactions(startOfWeek);
    } catch (e) {
      _setError('Failed to get week transactions: $e');
      return [];
    }
  }

  // NEW: Get transactions for date range (used by calendar)
  Future<List<FinancialTransaction>> getTransactionsForDateRange(DateTime start, DateTime end) async {
    try {
      _clearError();
      return await _dbService.getDateRangeTransactions(start, end);
    } catch (e) {
      _setError('Failed to get date range transactions: $e');
      return [];
    }
  }

  // FIXED: Proper start of week calculation (Monday-based)
  DateTime _getStartOfWeek(DateTime date) {
    // ISO week starts on Monday (weekday 1)
    final daysFromMonday = date.weekday - 1;
    final startOfWeek = date.subtract(Duration(days: daysFromMonday));
    return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
  }

  // NEW: Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      return await _dbService.getDatabaseStats();
    } catch (e) {
      debugPrint('Failed to get database stats: $e');
      return {'error': e.toString()};
    }
  }

  // NEW: Refresh current view
  Future<void> refresh() async {
    _transactionCache.clear();
    _setLoading(true);

    try {
      await _loadTransactionsForPeriod(_selectedPeriod);
    } catch (e) {
      _setError('Refresh failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }

  void _clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dbService.close();
    super.dispose();
  }
}