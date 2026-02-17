// lib/finance_tracking/utils/date_time_utils.dart
import 'package:flutter/foundation.dart';

class DateTimeUtils {
  // Private constructor to prevent instantiation
  DateTimeUtils._();

  /// Get the start of today in local time (00:00:00)
  static DateTime getStartOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Get the end of today in local time (23:59:59.999)
  static DateTime getEndOfToday() {
    final startOfToday = getStartOfToday();
    return startOfToday.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
  }

  /// Get the start of the week (Monday) in local time
  static DateTime getStartOfWeek([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    final localDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

    // ISO week starts on Monday (weekday 1)
    final daysFromMonday = localDate.weekday - 1;
    return localDate.subtract(Duration(days: daysFromMonday));
  }

  /// Get the end of the week (Sunday) in local time
  static DateTime getEndOfWeek([DateTime? date]) {
    final startOfWeek = getStartOfWeek(date);
    return startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
  }

  /// Get the start of the month in local time
  static DateTime getStartOfMonth([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    return DateTime(targetDate.year, targetDate.month, 1);
  }

  /// Get the end of the month in local time
  static DateTime getEndOfMonth([DateTime? date]) {
    final targetDate = date ?? DateTime.now();
    final nextMonth = DateTime(targetDate.year, targetDate.month + 1, 1);
    return nextMonth.subtract(const Duration(milliseconds: 1));
  }

  /// Check if two dates are the same day (ignoring time)
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Check if a date is today
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// Format date for display (e.g., "3 Sep 2025")
  static String formatDisplayDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Format date range (e.g., "Sep 2-8, 2025" or "Aug 30 - Sep 5, 2025")
  static String formatDateRange(DateTime start, DateTime end) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    if (start.month == end.month && start.year == end.year) {
      // Same month and year
      return '${months[start.month - 1]} ${start.day}-${end.day}, ${start.year}';
    } else if (start.year == end.year) {
      // Same year, different months
      return '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}, ${start.year}';
    } else {
      // Different years
      return '${months[start.month - 1]} ${start.day}, ${start.year} - ${months[end.month - 1]} ${end.day}, ${end.year}';
    }
  }

  /// Format time (e.g., "14:30")
  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Convert DateTime to UTC for database storage
  static String toUtcIsoString(DateTime localDateTime) {
    return localDateTime.toUtc().toIso8601String();
  }

  /// Convert UTC ISO string from database to local DateTime
  static DateTime fromUtcIsoString(String utcIsoString) {
    return DateTime.parse(utcIsoString).toLocal();
  }

  /// Get timezone offset in hours
  static double getTimezoneOffsetHours() {
    final now = DateTime.now();
    return now.timeZoneOffset.inMilliseconds / (1000 * 60 * 60);
  }

  /// Log timezone information for debugging
  static void logTimezoneInfo() {
    final now = DateTime.now();
    final utcNow = now.toUtc();

    debugPrint('=== TIMEZONE INFO ===');
    debugPrint('Local time: $now');
    debugPrint('UTC time: $utcNow');
    debugPrint('Timezone offset: ${now.timeZoneOffset}');
    debugPrint('Offset hours: ${getTimezoneOffsetHours()}');
    debugPrint('Start of today (local): ${getStartOfToday()}');
    debugPrint('Start of week (local): ${getStartOfWeek()}');
    debugPrint('Start of month (local): ${getStartOfMonth()}');
    debugPrint('====================');
  }

  /// Validate that a date is reasonable for a financial transaction
  static bool isValidTransactionDate(DateTime date) {
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));
    final oneWeekFromNow = now.add(const Duration(days: 7));

    return date.isAfter(oneYearAgo) && date.isBefore(oneWeekFromNow);
  }

  /// Get a human-readable relative date (e.g., "Today", "Yesterday", "2 days ago")
  static String getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = getStartOfToday();
    final dateOnly = DateTime(date.year, date.month, date.day);

    final difference = today.difference(dateOnly).inDays;

    switch (difference) {
      case 0:
        return 'Today';
      case 1:
        return 'Yesterday';
      case -1:
        return 'Tomorrow';
      default:
        if (difference > 0) {
          return '$difference days ago';
        } else {
          return 'In ${-difference} days';
        }
    }
  }
}