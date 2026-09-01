import 'package:intl/intl.dart';

class Formatters {
  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('MMM dd, yyyy • hh:mm a');

  static String formatDate(DateTime? date) {
    if (date == null) return '—';
    return _dateFormat.format(date.toLocal());
  }

  static String formatTime(DateTime? time) {
    if (time == null) return '—';
    return _timeFormat.format(time.toLocal());
  }

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '—';
    return _dateTimeFormat.format(dateTime.toLocal());
  }

  static String formatTimeString(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '—';
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final dt = DateTime(2026, 1, 1, hour, minute);
        return _timeFormat.format(dt);
      }
    } catch (_) {}
    return timeStr;
  }

  static String formatSemester(int? year, int? semester) {
    if (year == null || semester == null) return '—';
    return 'Year $year, Sem $semester';
  }
}
