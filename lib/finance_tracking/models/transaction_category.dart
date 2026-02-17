import 'package:flutter/material.dart';

enum TransactionCategory {
  food('Food', Icons.restaurant, Color(0xFFFF6B6B)),
  transportation('Transportation', Icons.directions_car, Color(0xFF4ECDC4)),
  health('Health', Icons.local_hospital, Color(0xFF45B7D1)),
  shopping('Shopping', Icons.shopping_bag, Color(0xFFF6CEB4)),
  education('Education', Icons.school, Color(0xFFECCA57)),
  essentials('Essentials', Icons.home, Color(0xFF96F2D7)),
  entertainment('Entertainment', Icons.movie, Color(0xFF8BB500)),
  other('Other', Icons.category, Color(0xFFC5CDE7));

  const TransactionCategory(this.displayName, this.icon, this.color);

  final String displayName;
  final IconData icon;
  final Color color;

  static TransactionCategory fromString(String category) {
    return TransactionCategory.values.firstWhere(
          (c) => c.displayName.toLowerCase() == category.toLowerCase(),
      orElse: () => TransactionCategory.other,
    );
  }

  static List<String> get allCategoryNames =>
      TransactionCategory.values.map((c) => c.displayName).toList();
}