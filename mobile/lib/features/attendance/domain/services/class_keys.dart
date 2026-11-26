/// S2-13 "double periods": one class = one (day, routine slot). Two sessions
/// of a course on one day for two different routine slots are two classes;
/// sessions on that day without a slot (or for the same slot) are the same
/// class. Keys: "2026-11-27" (no slot) or "2026-11-27#slotId".
class ClassKeys {
  ClassKeys._();

  static String of(String date, String? slotId) =>
      (slotId == null || slotId.isEmpty) ? date : '$date#$slotId';

  static String dateOf(String key) {
    final i = key.indexOf('#');
    return i < 0 ? key : key.substring(0, i);
  }

  /// On a day that has slot classes, the plain-day entry is the same class
  /// as one of them, so it is dropped.
  static Set<String> normalize(Iterable<String> keys) {
    final all = keys.toSet();
    final slottedDays = {for (final k in all) if (k.contains('#')) dateOf(k)};
    return {for (final k in all) if (k.contains('#') || !slottedDays.contains(k)) k};
  }

  /// Which of [held] the student attended, given their [present] keys. Older
  /// marks may carry only the day: a plain day counts for one not-yet-matched
  /// class that day. Returns (attended, presentNotInHeld).
  static (Set<String>, Set<String>) match(Set<String> held, Set<String> present) {
    final went = present.intersection(held);
    final leftover = <String>{};
    for (final p in (present.difference(held).toList()..sort())) {
      final day = dateOf(p);
      if (!p.contains('#')) {
        final free = held.where((h) => dateOf(h) == p && !went.contains(h)).toList()..sort();
        if (free.isNotEmpty) {
          went.add(free.first);
          continue;
        }
      } else if (held.contains(day) && !went.contains(day)) {
        went.add(day);
        continue;
      }
      leftover.add(p);
    }
    return (went, leftover);
  }

  /// Column labels for sorted keys: "26.11.26", or "26.11.26 (1)" /
  /// "26.11.26 (2)" when one day had two classes.
  static List<String> labels(List<String> sortedKeys, String Function(String date) format) {
    final perDay = <String, int>{};
    for (final k in sortedKeys) {
      perDay[dateOf(k)] = (perDay[dateOf(k)] ?? 0) + 1;
    }
    final seen = <String, int>{};
    return [
      for (final k in sortedKeys)
        perDay[dateOf(k)]! > 1
            ? '${format(dateOf(k))} (${seen[dateOf(k)] = (seen[dateOf(k)] ?? 0) + 1})'
            : format(dateOf(k)),
    ];
  }
}
