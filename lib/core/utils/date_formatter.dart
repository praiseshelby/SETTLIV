import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _shortDate = DateFormat('d MMM');
  static final DateFormat _dayOfWeekAndDate = DateFormat('EEE, d MMM');
  static final DateFormat _fullDate = DateFormat('d MMMM yyyy');

  /// Returns friendly group header: "Today", "Yesterday", or "Sun, 15 Nov"
  static String formatDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final difference = today.difference(target).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7 && difference > 0) return _dayOfWeekAndDate.format(date);
    return _dayOfWeekAndDate.format(date);
  }

  static String formatShort(DateTime date) => _shortDate.format(date);
  static String formatFull(DateTime date) => _fullDate.format(date);
}
