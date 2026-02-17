import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/financial_transaction.dart';

class FinanceAIService {
  static const String _apiKey = '';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'openai/gpt-oss-120b';

  Future<List<FinancialTransaction>> detectMultipleTransactions(String transcript, String audioFileName) async {
    const systemPrompt = '''Extract ALL financial transactions with quantity information.

FORMAT - Use EXACT format for each transaction:
---START---
Amount: [total amount number only]
Quantity: [number of items, default 1]
Unit_Price: [price per item]
Category: [Food, Transportation, Health, Shopping, Education, Essentials, Entertainment, Other]
Description: [item name without quantity]
---END---

EXAMPLES:

Input: "8 Biryani for 800 rupees and vegetables for 150"
Output:
---START---
Amount: 800
Quantity: 8
Unit_Price: 100
Category: Food
Description: Biryani
---END---
---START---
Amount: 150
Quantity: 1
Unit_Price: 150
Category: Food
Description: vegetables
---END---

Input: "Had lunch for 200 rupees"
Output:
---START---
Amount: 200
Quantity: 1
Unit_Price: 200
Category: Food
Description: lunch
---END---

CATEGORIZATION RULES:
- Biryani, pani puri, food items -> Food (NOT Shopping)
- Items bought at mall/store -> determine by item type
- Fruits, vegetables -> Food
- Medicine -> Health
- Transport -> Transportation

Extract ALL transactions with proper quantities.''';

    final userPrompt = "Transcript: \"$transcript\"";

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': 500,
          'temperature': 0.05,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] as String;

        debugPrint('AI Response: $aiResponse');

        if (aiResponse.trim() == 'NO_TRANSACTIONS') {
          return [];
        }

        return _parseTransactions(aiResponse, audioFileName);
      } else {
        debugPrint('API Error: ${response.statusCode}');
        return _fallbackDetection(transcript, audioFileName);
      }
    } catch (e) {
      debugPrint('AI Service Error: $e');
      return _fallbackDetection(transcript, audioFileName);
    }
  }

  List<FinancialTransaction> _parseTransactions(String response, String audioFileName) {
    final transactions = <FinancialTransaction>[];

    try {
      final blocks = response.split('---START---');

      for (int i = 1; i < blocks.length; i++) {
        final block = blocks[i];
        final endIndex = block.indexOf('---END---');

        if (endIndex == -1) continue;

        final content = block.substring(0, endIndex).trim();
        final transaction = _parseTransactionBlock(content, audioFileName, i - 1);

        if (transaction != null) {
          transactions.add(transaction);
          debugPrint('Parsed: ${transaction.quantity}x ${transaction.description} = ₹${transaction.amount}');
        }
      }

      return transactions;

    } catch (e) {
      debugPrint('Parse error: $e');
      return [];
    }
  }

  FinancialTransaction? _parseTransactionBlock(String content, String audioFileName, int index) {
    try {
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();

      double? amount;
      int quantity = 1;
      double? unitPrice;
      String category = 'Other';
      String description = 'Transaction';

      for (final line in lines) {
        final trimmedLine = line.trim();

        if (trimmedLine.startsWith('Amount:')) {
          final amountStr = trimmedLine.replaceFirst('Amount:', '').trim();
          amount = double.tryParse(amountStr);
        } else if (trimmedLine.startsWith('Quantity:')) {
          final quantityStr = trimmedLine.replaceFirst('Quantity:', '').trim();
          quantity = int.tryParse(quantityStr) ?? 1;
        } else if (trimmedLine.startsWith('Unit_Price:')) {
          final unitPriceStr = trimmedLine.replaceFirst('Unit_Price:', '').trim();
          unitPrice = double.tryParse(unitPriceStr);
        } else if (trimmedLine.startsWith('Category:')) {
          category = trimmedLine.replaceFirst('Category:', '').trim();
        } else if (trimmedLine.startsWith('Description:')) {
          description = trimmedLine.replaceFirst('Description:', '').trim();
        }
      }

      if (amount != null && amount > 0) {
        if (unitPrice == null || unitPrice <= 0) {
          unitPrice = quantity > 0 ? amount / quantity : amount;
        }

        return FinancialTransaction(
          id: '${DateTime.now().millisecondsSinceEpoch}_$index',
          amount: amount,
          quantity: quantity,
          unitPrice: unitPrice,
          category: _validateCategory(category),
          description: description.isNotEmpty ? description : 'Transaction',
          date: DateTime.now(),
          audioFileName: audioFileName,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Block parse error: $e');
      return null;
    }
  }

  List<FinancialTransaction> _fallbackDetection(String transcript, String audioFileName) {
    debugPrint('Using fallback detection');
    final transactions = <FinancialTransaction>[];

    final patterns = [
      RegExp(r'(\d+)\s+([a-zA-Z]+).*?(\d+(?:\.\d{1,2})?)\s*(?:₹|rs\.?|rupees?)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:₹|rs\.?|rupees?)', caseSensitive: false),
    ];

    try {
      for (final pattern in patterns) {
        final matches = pattern.allMatches(transcript);
        int index = 0;

        for (final match in matches) {
          double? amount;
          int quantity = 1;
          String description = 'item';

          if (pattern == patterns[0] && match.groupCount >= 3) {
            quantity = int.tryParse(match.group(1) ?? '') ?? 1;
            description = match.group(2) ?? 'item';
            amount = double.tryParse(match.group(3) ?? '');
          } else {
            amount = double.tryParse(match.group(1) ?? '');
          }

          if (amount != null && amount > 0) {
            final context = _getContextAroundMatch(transcript, match.start, match.end);
            final category = _detectCategoryFromContext(context);

            if (quantity <= 1) {
              description = _extractDescriptionFromContext(context);
            }

            final unitPrice = quantity > 0 ? amount / quantity : amount;

            transactions.add(FinancialTransaction(
              id: '${DateTime.now().millisecondsSinceEpoch}_fallback_${index++}',
              amount: amount,
              quantity: quantity,
              unitPrice: unitPrice,
              category: category,
              description: description,
              date: DateTime.now(),
              audioFileName: audioFileName,
            ));
          }
        }
      }

      // Remove duplicates by amount
      final uniqueTransactions = <FinancialTransaction>[];
      final seenAmounts = <double>{};

      for (final transaction in transactions) {
        if (!seenAmounts.contains(transaction.amount)) {
          uniqueTransactions.add(transaction);
          seenAmounts.add(transaction.amount);
        }
      }

      return uniqueTransactions;

    } catch (e) {
      debugPrint('Fallback detection failed: $e');
      return [];
    }
  }

  String _getContextAroundMatch(String text, int start, int end) {
    final contextRange = 50;
    final contextStart = (start - contextRange).clamp(0, text.length);
    final contextEnd = (end + contextRange).clamp(0, text.length);
    return text.substring(contextStart, contextEnd).toLowerCase();
  }

  String _detectCategoryFromContext(String context) {
    if (context.contains(RegExp(r'\b(biryani|food|eat|dinner|lunch|coffee|restaurant|pani puri|fruits|vegetables)\b'))) return 'Food';
    if (context.contains(RegExp(r'\b(taxi|transport|uber|auto|bus|travel)\b'))) return 'Transportation';
    if (context.contains(RegExp(r'\b(medicine|doctor|hospital|health)\b'))) return 'Health';
    if (context.contains(RegExp(r'\b(shopping|clothes|buy|store|mall)\b'))) return 'Shopping';
    if (context.contains(RegExp(r'\b(groceries|grocery|essential|bill|rent)\b'))) return 'Essentials';
    if (context.contains(RegExp(r'\b(movie|entertainment|game|fun)\b'))) return 'Entertainment';
    if (context.contains(RegExp(r'\b(book|education|course|study)\b'))) return 'Education';
    return 'Other';
  }

  String _extractDescriptionFromContext(String context) {
    final words = context.split(RegExp(r'\W+'));
    final relevantWords = words.where((word) =>
    word.length > 2 &&
        !['paid', 'spent', 'cost', 'rupees', 'then', 'for', 'went', 'today'].contains(word)
    ).take(2);

    return relevantWords.isNotEmpty ? relevantWords.join(' ') : 'transaction';
  }

  String _validateCategory(String category) {
    const validCategories = [
      'Food', 'Transportation', 'Health', 'Shopping',
      'Education', 'Essentials', 'Entertainment', 'Other'
    ];
    return validCategories.contains(category) ? category : 'Other';
  }

  // Backward compatibility
  Future<FinancialTransaction?> detectFinancialTransaction(String transcript, String audioFileName) async {
    final transactions = await detectMultipleTransactions(transcript, audioFileName);
    return transactions.isNotEmpty ? transactions.first : null;
  }
}