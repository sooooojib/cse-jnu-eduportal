/// Helpers for class times and dates. Routine times are stored in mixed
/// formats ("09:00", "9:00 AM", "02:00 PM"), so everything goes through here.
class ClassTime {
  ClassTime._();

  // ─── Bangladesh time (S2-10) ─────────────────────────────────────────────
  // The department runs on Asia/Dhaka time (UTC+6, no daylight saving).
  // "Today", the weekday and the time of day come from here, not from the
  // phone's own time zone. [serverOffset] (server clock minus phone clock) is
  // learned once after sign-in, so a phone with a wrong clock still gets the
  // right day.

  /// Server clock minus phone clock.
  static Duration serverOffset = Duration.zero;

  /// The real current moment, corrected by the server clock. Use it for
  /// deadlines such as a session's expiry.
  static DateTime instant() => DateTime.now().add(serverOffset);

  /// Bangladesh wall-clock time now (for today / weekday / time of day).
  static DateTime now() => dhaka(instant());

  /// Wall-clock time in Bangladesh at the moment [t].
  static DateTime dhaka(DateTime t) {
    final u = t.toUtc().add(const Duration(hours: 6));
    return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second, u.millisecond);
  }

  /// Today's date in Bangladesh, "2026-11-27".
  static String todayKey() => dateKey(now());

  /// Midday in Bangladesh of a calendar date, as a real moment (06:00 UTC).
  static DateTime dhakaMidday(DateTime date) => DateTime.utc(date.year, date.month, date.day, 6);

  static const List<String> weekdayNames = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
  ];

  /// Minutes since midnight, or null if the string can't be read.
  static int? toMinutes(String raw) {
    final s = raw.trim().toUpperCase();
    final m = RegExp(r'^(\d{1,2})[:.](\d{2})\s*(AM|PM)?$').firstMatch(s);
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final ampm = m.group(3);
    if (min > 59 || h > 23) return null;
    if (ampm == 'PM' && h < 12) h += 12;
    if (ampm == 'AM' && h == 12) h = 0;
    return h * 60 + min;
  }

  /// 540 -> "09:00 AM".
  static String format(int minutes) {
    final h24 = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final suffix = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
  }

  /// Normalises any readable time to "hh:mm AM/PM"; returns [raw] otherwise.
  static String normalize(String raw) {
    final m = toMinutes(raw);
    return m == null ? raw : format(m);
  }

  /// True when [aStart, aEnd) and [bStart, bEnd) overlap.
  static bool overlaps(int aStart, int aEnd, int bStart, int bEnd) => aStart < bEnd && bStart < aEnd;

  /// "2026-11-27".
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// "FRIDAY".
  static String dayOfWeek(DateTime d) => weekdayNames[d.weekday - 1];

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Today plus the next [days] days (default: 8 dates, today .. today+7).
  static List<DateTime> upcomingDates(DateTime now, {int days = 7}) {
    final start = dateOnly(now);
    return List.generate(days + 1, (i) => DateTime(start.year, start.month, start.day + i));
  }

  /// The [days] days before today, most recent first (yesterday, ...).
  static List<DateTime> pastDates(DateTime now, {int days = 7}) {
    final start = dateOnly(now);
    return List.generate(days, (i) => DateTime(start.year, start.month, start.day - 1 - i));
  }
}
