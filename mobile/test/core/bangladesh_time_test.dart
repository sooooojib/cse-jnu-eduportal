import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/core/utils/class_time.dart';

/// S2-10: "today" is the Bangladesh date, from the server-corrected clock.
void main() {
  tearDown(() => ClassTime.serverOffset = Duration.zero);

  test('a moment is read as Bangladesh wall-clock time (UTC+6)', () {
    // 20:30 UTC on Nov 26 is already 02:30 on Nov 27 in Dhaka.
    final t = DateTime.utc(2026, 11, 26, 20, 30);
    final d = ClassTime.dhaka(t);
    expect(ClassTime.dateKey(d), '2026-11-27');
    expect((d.hour, d.minute), (2, 30));
    expect(ClassTime.dayOfWeek(d), 'FRIDAY');
  });

  test('a wrong phone clock is corrected by the server offset', () {
    final real = ClassTime.todayKey();
    ClassTime.serverOffset = const Duration(days: 3); // phone is 3 days behind
    final corrected = DateTime.parse(ClassTime.todayKey());
    expect(corrected.difference(DateTime.parse(real)).inDays, 3);
  });

  test('class-change timestamps are midday in Dhaka of that date', () {
    final ts = ClassTime.dhakaMidday(DateTime(2026, 12, 1));
    expect(ts.isUtc, isTrue);
    expect(ts.hour, 6);
    expect(ClassTime.dateKey(ClassTime.dhaka(ts)), '2026-12-01');
  });
}
