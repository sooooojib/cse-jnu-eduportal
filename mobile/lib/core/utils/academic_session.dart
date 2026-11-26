/// Helpers for JnU academic sessions (batches), e.g. "2021-2022".
class AcademicSession {
  AcademicSession._();

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{4})$');

  /// True for "YYYY-YYYY" where the second year is the first year + 1.
  static bool isValid(String? session) {
    if (session == null) return false;
    final m = _pattern.firstMatch(session.trim());
    if (m == null) return false;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    return b == a + 1 && a >= 2000 && a <= 2100;
  }

  /// Sessions offered in the signup dropdown, newest first.
  /// With [now] in 2026 this returns 2025-2026 ... 2018-2019.
  static List<String> availableSessions({DateTime? now, int count = 8}) {
    final latestStart = (now ?? DateTime.now()).year - 1;
    return List.generate(count, (i) {
      final start = latestStart - i;
      return '$start-${start + 1}';
    });
  }
}
