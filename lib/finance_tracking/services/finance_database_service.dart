import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../models/financial_transaction.dart';
import 'finance_ai_service.dart';

class FinanceDatabaseService extends ChangeNotifier {
  static Database? _database;
  static final FinanceDatabaseService _instance = FinanceDatabaseService._internal();
  factory FinanceDatabaseService() => _instance;
  FinanceDatabaseService._internal();

  final FinanceAIService _aiService = FinanceAIService();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'finance.db');

    return await openDatabase(
      path,
      version: 3, // Increased version for new indexes
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Create main table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        quantity INTEGER DEFAULT 1,
        unit_price REAL NOT NULL,
        audio_file_id TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Add performance indexes
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    try {
      // Index for date-based queries (most important)
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');

      // Index for category-based queries
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)');

      // Index for chronological sorting
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at)');

      // Composite index for date + category queries
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date_category ON transactions(date, category)');

      debugPrint('Database indexes created successfully');
    } catch (e) {
      debugPrint('Error creating indexes: $e');
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle version 1 to 2 upgrade
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN quantity INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE transactions ADD COLUMN unit_price REAL DEFAULT 0');
        await db.execute('UPDATE transactions SET unit_price = amount WHERE unit_price = 0');
        debugPrint('Database upgraded to version 2');
      } catch (e) {
        debugPrint('Database upgrade v1->v2 warning: $e');
      }
    }

    // Handle version 2 to 3 upgrade - add indexes
    if (oldVersion < 3) {
      await _createIndexes(db);
      debugPrint('Database upgraded to version 3 with indexes');
    }
  }

  // NEW: Date-specific query methods (replacing getAllTransactions)
  Future<List<FinancialTransaction>> getTodayTransactions() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'date DESC',
    );

    return _mapResultsToTransactions(maps);
  }

  Future<List<FinancialTransaction>> getWeekTransactions(DateTime startOfWeek) async {
    final db = await database;
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfWeek.toIso8601String(), endOfWeek.toIso8601String()],
      orderBy: 'date DESC',
    );

    return _mapResultsToTransactions(maps);
  }

  Future<List<FinancialTransaction>> getMonthTransactions(int year, int month) async {
    final db = await database;
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [startOfMonth.toIso8601String(), endOfMonth.toIso8601String()],
      orderBy: 'date DESC',
    );

    return _mapResultsToTransactions(maps);
  }

  Future<List<FinancialTransaction>> getTransactionsByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'date DESC',
    );

    return _mapResultsToTransactions(maps);
  }

  Future<List<FinancialTransaction>> getDateRangeTransactions(DateTime start, DateTime end) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );

    return _mapResultsToTransactions(maps);
  }

  // Helper method to convert query results to FinancialTransaction objects
  List<FinancialTransaction> _mapResultsToTransactions(List<Map<String, dynamic>> maps) {
    return List.generate(maps.length, (i) {
      return FinancialTransaction(
        id: maps[i]['id'].toString(), // Convert int ID to string for model consistency
        amount: maps[i]['amount'].toDouble(),
        quantity: maps[i]['quantity'] ?? 1,
        unitPrice: maps[i]['unit_price']?.toDouble() ?? maps[i]['amount'].toDouble(),
        category: maps[i]['category'],
        description: maps[i]['description'],
        date: DateTime.parse(maps[i]['date']),
        audioFileName: maps[i]['audio_file_id'] ?? '',
      );
    });
  }

  // MODIFIED: Keep this for backward compatibility, but add limit
  Future<List<FinancialTransaction>> getAllTransactions({int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
      limit: limit, // Add optional limit to prevent memory issues
    );

    return _mapResultsToTransactions(maps);
  }

  Future<int> insertTransaction(FinancialTransaction transaction) async {
    final db = await database;
    return await db.insert('transactions', {
      'date': transaction.date.toIso8601String(),
      'category': transaction.category,
      'description': transaction.description,
      'amount': transaction.amount,
      'quantity': transaction.quantity,
      'unit_price': transaction.unitPrice,
      'audio_file_id': transaction.audioFileName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> insertMultipleTransactions(List<FinancialTransaction> transactions) async {
    final db = await database;
    int totalInserted = 0;

    await db.transaction((txn) async {
      for (final transaction in transactions) {
        await txn.insert('transactions', {
          'date': transaction.date.toIso8601String(),
          'category': transaction.category,
          'description': transaction.description,
          'amount': transaction.amount,
          'quantity': transaction.quantity,
          'unit_price': transaction.unitPrice,
          'audio_file_id': transaction.audioFileName,
          'created_at': DateTime.now().toIso8601String(),
        });
        totalInserted++;
      }
    });

    debugPrint('Inserted $totalInserted transactions');
    return totalInserted;
  }

  Future<bool> updateTransaction(String transactionId, FinancialTransaction transaction) async {
    try {
      final db = await database;
      final result = await db.update(
        'transactions',
        {
          'date': transaction.date.toIso8601String(),
          'category': transaction.category,
          'description': transaction.description,
          'amount': transaction.amount,
          'quantity': transaction.quantity,
          'unit_price': transaction.unitPrice,
          // Don't update audio_file_id and created_at
        },
        where: 'id = ?',
        whereArgs: [int.parse(transactionId)],
      );

      if (result > 0) {
        notifyListeners();
        debugPrint('Updated transaction: $transactionId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Update transaction failed: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    try {
      final db = await database;
      final result = await db.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [int.parse(transactionId)], // Convert string ID back to int
      );

      if (result > 0) {
        notifyListeners();
        debugPrint('Deleted transaction: $transactionId');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Delete transaction failed: $e');
      return false;
    }
  }

  // MODIFIED: AI detection now returns proper integer IDs
  Future<List<FinancialTransaction>> detectFinancialTransactions(String transcript, String audioFileName) async {
    try {
      debugPrint('Processing transcript: "$transcript"');

      final aiTransactions = await _aiService.detectMultipleTransactions(transcript, audioFileName);

      if (aiTransactions.isNotEmpty) {
        // Insert transactions and get their actual database IDs
        final insertedTransactions = <FinancialTransaction>[];

        for (final transaction in aiTransactions) {
          final insertedId = await insertTransaction(transaction);

          // Create new transaction object with correct database ID
          final correctedTransaction = FinancialTransaction(
            id: insertedId.toString(),
            amount: transaction.amount,
            quantity: transaction.quantity,
            unitPrice: transaction.unitPrice,
            category: transaction.category,
            description: transaction.description,
            date: transaction.date,
            audioFileName: transaction.audioFileName,
          );

          insertedTransactions.add(correctedTransaction);
        }

        notifyListeners();

        debugPrint('Saved ${insertedTransactions.length} transactions with proper IDs');
        for (final t in insertedTransactions) {
          debugPrint('  - ID:${t.id} ${t.quantity}x ${t.description}: ₹${t.amount} (${t.category})');
        }

        return insertedTransactions;
      } else {
        debugPrint('No financial transactions detected');
        return [];
      }

    } catch (e) {
      debugPrint('AI financial detection failed: $e');
      return [];
    }
  }

  // Backward compatibility method
  Future<FinancialTransaction?> detectFinancialTransaction(String transcript, String audioFileName) async {
    final transactions = await detectFinancialTransactions(transcript, audioFileName);
    return transactions.isNotEmpty ? transactions.first : null;
  }

  // NEW: Database health check method
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;

    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM transactions');
    final totalCount = countResult.first['count'] as int;

    final sizeResult = await db.rawQuery('PRAGMA page_size');
    final pageCount = await db.rawQuery('PRAGMA page_count');
    final pageSize = sizeResult.first['page_size'] as int;
    final pages = pageCount.first['page_count'] as int;
    final dbSizeKB = (pageSize * pages) / 1024;

    return {
      'totalTransactions': totalCount,
      'databaseSizeKB': dbSizeKB.round(),
      'hasIndexes': true,
    };
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}