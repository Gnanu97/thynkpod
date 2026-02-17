// lib/finance_tracking/utils/validation_utils.dart
import '../models/transaction_category.dart';

class ValidationResult {
  final bool isValid;
  final List<String> errors;

  const ValidationResult({
    required this.isValid,
    required this.errors,
  });

  String get firstError => errors.isNotEmpty ? errors.first : '';
  String get allErrors => errors.join('\n');
}

class TransactionValidator {
  static ValidationResult validateTransaction({
    required double amount,
    required String category,
    required String description,
    required DateTime date,
    int quantity = 1,
  }) {
    final errors = <String>[];

    // Validate amount
    final amountValidation = validateAmount(amount);
    if (!amountValidation.isValid) {
      errors.addAll(amountValidation.errors);
    }

    // Validate quantity
    final quantityValidation = validateQuantity(quantity);
    if (!quantityValidation.isValid) {
      errors.addAll(quantityValidation.errors);
    }

    // Validate category
    final categoryValidation = validateCategory(category);
    if (!categoryValidation.isValid) {
      errors.addAll(categoryValidation.errors);
    }

    // Validate description
    final descriptionValidation = validateDescription(description);
    if (!descriptionValidation.isValid) {
      errors.addAll(descriptionValidation.errors);
    }

    // Validate date
    final dateValidation = validateDate(date);
    if (!dateValidation.isValid) {
      errors.addAll(dateValidation.errors);
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  static ValidationResult validateAmount(double amount) {
    final errors = <String>[];

    if (amount <= 0) {
      errors.add('Amount must be greater than zero');
    } else if (amount > 999999) {
      errors.add('Amount cannot exceed ₹999,999');
    } else if (amount.toString().contains('.') &&
        amount.toString().split('.')[1].length > 2) {
      errors.add('Amount can have maximum 2 decimal places');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  static ValidationResult validateQuantity(int quantity) {
    final errors = <String>[];

    if (quantity <= 0) {
      errors.add('Quantity must be at least 1');
    } else if (quantity > 9999) {
      errors.add('Quantity cannot exceed 9,999');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  static ValidationResult validateCategory(String category) {
    final errors = <String>[];
    final validCategories = TransactionCategory.allCategoryNames;

    if (category.trim().isEmpty) {
      errors.add('Category is required');
    } else if (!validCategories.contains(category)) {
      errors.add('Invalid category selected');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  static ValidationResult validateDescription(String description) {
    final errors = <String>[];

    if (description.trim().isEmpty) {
      errors.add('Description is required');
    } else if (description.trim().length < 2) {
      errors.add('Description must be at least 2 characters');
    } else if (description.length > 100) {
      errors.add('Description cannot exceed 100 characters');
    } else if (description.trim() != description) {
      errors.add('Description cannot start or end with spaces');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  static ValidationResult validateDate(DateTime date) {
    final errors = <String>[];
    final now = DateTime.now();
    final twoYearsAgo = now.subtract(const Duration(days: 730));
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    if (date.isBefore(twoYearsAgo)) {
      errors.add('Date cannot be more than 2 years ago');
    } else if (date.isAfter(tomorrow)) {
      errors.add('Date cannot be in the future');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  // Helper method to format currency
  static String formatCurrency(double amount) {
    if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  // Helper method to validate and format input
  static double? parseAmount(String input) {
    final cleaned = input.replaceAll(RegExp(r'[₹,\s]'), '');
    return double.tryParse(cleaned);
  }

  static int? parseQuantity(String input) {
    final cleaned = input.replaceAll(RegExp(r'[,\s]'), '');
    return int.tryParse(cleaned);
  }
}