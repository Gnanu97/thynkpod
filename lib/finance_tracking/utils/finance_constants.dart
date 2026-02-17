import 'package:flutter/material.dart';

// Design System Constants
class FinanceConstants {
  // Colors
  static const Color primaryGradientStart = Color(0xFFA0A0A0);
  static const Color primaryGradientEnd = Color(0xFF3A3A3A);
  static const Color secondaryGray = Color(0xFF737373);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Color(0xFF737373);

  // Category Colors
  static const Color foodColor = Color(0xFFFF6B6B);
  static const Color transportationColor = Color(0xFF4ECDC4);
  static const Color healthColor = Color(0xFF45B7D1);
  static const Color shoppingColor = Color(0xFFF6CEB4);
  static const Color educationColor = Color(0xFFECCA57);
  static const Color essentialsColor = Color(0xFF96F2D7);
  static const Color entertainmentColor = Color(0xFF8BB500);
  static const Color otherColor = Color(0xFFC5CDE7);

  // Border Radius
  static const double cardRadius = 16.0;
  static const double buttonRadius = 20.0;
  static const double smallRadius = 8.0;
  static const double miniRadius = 4.0;

  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 20.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingLarge = 20.0;

  // Font Sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeXLarge = 18.0;
  static const double fontSizeXXLarge = 22.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryGradientStart, primaryGradientEnd],
  );

  // Box Shadows
  static const BoxShadow cardShadow = BoxShadow(
    color: Colors.black12,
    blurRadius: 8.0,
    offset: Offset(0, 2),
  );

  // Text Styles
  static const TextStyle headerStyle = TextStyle(
    color: Colors.white,
    fontSize: fontSizeXXLarge,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyStyle = TextStyle(
    color: textPrimary,
    fontSize: fontSizeMedium,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle captionStyle = TextStyle(
    color: textSecondary,
    fontSize: fontSizeSmall,
  );

  // Icon Sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 24.0;

  // Currency Formatting
  static String formatCurrency(double amount) {
    return '₹${amount.toInt()}';
  }

  // Date Formatting
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}