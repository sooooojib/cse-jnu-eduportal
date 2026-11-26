import 'package:cse_jnu_eduportal/core/utils/class_time.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/class_change.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/services/effective_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

ScheduleSlot slot(String id, String day, String start, String end, String room,
        {String teacher = 't1', String course = 'CSE-3101', int year = 3, int sem = 1, String? date}) =>
    ScheduleSlot(
      id: id, courseId: course, courseCode: course, courseTitle: 'Course', teacherId: teacher,
      teacherName: 'Teacher $teacher', dayOfWeek: day, startTime: start, endTime: end, room: room,
      targetYear: year, targetSemester: sem, date: date,
    );

ClassChange change(String id, ClassChangeType type, String date,
        {String? original, String start = '09:00 AM', String end = '10:30 AM', String room = 'Room 302',
        String teacher = 't1', String? reason}) =>
    ClassChange(
      id: id, type: type, date: date, dayOfWeek: 'FRIDAY', courseId: 'CSE-3105', courseCode: 'CSE-3105',
      courseTitle: 'SE', teacherId: teacher, teacherName: 'Teacher $teacher', targetYear: 3, targetSemester: 1,
      startTime: start, endTime: end, room: room, originalSlotId: original, reason: reason,
      createdBy: 'cr', createdByName: 'CR', createdByRole: 'CR',
    );

void main() {
  final friday = DateTime(2026, 11, 27); // a Friday
  const fridayKey = '2026-11-27';

  group('ClassTime', () {
    test('reads mixed time formats', () {
      expect(ClassTime.toMinutes('09:00'), 540);
      expect(ClassTime.toMinutes('9:00 AM'), 540);
      expect(ClassTime.toMinutes('02:30 PM'), 870);
      expect(ClassTime.toMinutes('12:00 PM'), 720);
      expect(ClassTime.toMinutes('12:15 AM'), 15);
      expect(ClassTime.toMinutes('nonsense'), isNull);
      expect(ClassTime.format(870), '02:30 PM');
      expect(ClassTime.dayOfWeek(friday), 'FRIDAY');
    });

    test('offers today plus the next 7 days', () {
      final days = ClassTime.upcomingDates(DateTime(2026, 11, 26, 18));
      expect(days.length, 8);
      expect(ClassTime.dateKey(days.first), '2026-11-26');
      expect(ClassTime.dateKey(days.last), '2026-12-03');
    });
  });

  group('EffectiveSchedule.forDate', () {
    final routine = [
      slot('a', 'FRIDAY', '09:00', '10:30', 'Room 302'),
      slot('b', 'FRIDAY', '11:00 AM', '12:30 PM', 'Room 402', teacher: 't2', course: 'CSE-3103'),
      slot('c', 'MONDAY', '09:00', '10:30', 'Room 302'),
      slot('old', 'FRIDAY', '02:00 PM', '03:00 PM', 'Lab 1', date: '2026-11-20'), // legacy one-off, last week
    ];

    test('uses only that weekday and ignores one-off classes from other dates', () {
      final r = EffectiveSchedule.forDate(routine: routine, changes: const [], date: friday);
      expect(r.map((s) => s.id), ['a', 'b']);
    });

    test('applies cancel, move and extra for that date only', () {
      final changes = [
        change('x', ClassChangeType.cancel, fridayKey, original: 'a', reason: 'Teacher on leave'),
        change('y', ClassChangeType.move, fridayKey, original: 'b', start: '03:00 PM', end: '04:30 PM', room: 'Room 501'),
        change('z', ClassChangeType.extra, fridayKey, start: '01:00 PM', end: '02:00 PM', room: 'Room 302'),
        change('w', ClassChangeType.cancel, '2026-12-04', original: 'a'), // next week: no effect
      ];
      final r = EffectiveSchedule.forDate(routine: routine, changes: changes, date: friday);
      expect(r.map((s) => s.id), ['a', 'change_z', 'b']); // sorted by (new) start time

      final a = r.firstWhere((s) => s.id == 'a');
      expect(a.isCancelled, isTrue);
      expect(a.changeNote, 'Cancelled: Teacher on leave');

      final b = r.firstWhere((s) => s.id == 'b');
      expect(b.isMoved, isTrue);
      expect(b.room, 'Room 501');
      expect(b.changeNote, 'Moved from 11:00 AM, Room 402');

      final z = r.firstWhere((s) => s.id == 'change_z');
      expect(z.isExtraClass, isTrue);
      expect(z.date, fridayKey);
    });

    test('returns empty list on official department holidays', () {
      final r = EffectiveSchedule.forDate(
        routine: routine,
        changes: const [],
        date: friday,
        holidays: const {fridayKey: 'Victory Day'},
      );
      expect(r, isEmpty);
    });
  });

  group('EffectiveSchedule.findClashes', () {
    final routine = [
      slot('a', 'FRIDAY', '09:00', '10:30', 'Room 302'),
      slot('other', 'FRIDAY', '09:00', '10:30', 'Room 501', teacher: 't9', course: 'CSE-1101', year: 1),
    ];

    List<ScheduleClash> check({
      String start = '09:30 AM',
      String end = '10:00 AM',
      String room = 'Room 302',
      String teacher = 't1',
      int year = 3,
      List<ClassChange> changes = const [],
      String? ignore,
    }) =>
        EffectiveSchedule.findClashes(
          routine: routine, changes: changes, date: friday, startTime: start, endTime: end, room: room,
          teacherId: teacher, targetYear: year, targetSemester: 1, ignoreSlotId: ignore,
        );

    test('detects room, teacher and batch clashes in plain words', () {
      final c = check();
      expect(c.map((x) => x.kind).toSet(), {'ROOM', 'TEACHER', 'BATCH'});
      expect(c.first.message, contains('Room 302 is booked for CSE-3101'));
    });

    test('free slot has no clashes; touching edges do not clash', () {
      expect(check(start: '10:30 AM', end: '12:00 PM'), isEmpty);
    });

    test('room booked by another batch still clashes', () {
      final c = check(room: 'room 501', teacher: 't5', year: 2);
      expect(c.single.kind, 'ROOM');
    });

    test('a cancelled class frees the room, teacher and batch', () {
      final c = check(changes: [change('x', ClassChangeType.cancel, fridayKey, original: 'a')]);
      expect(c, isEmpty);
    });

    test('moving a class does not clash with its own old time', () {
      expect(check(ignore: 'a'), isEmpty);
    });

    test('rejects an end time before the start time', () {
      expect(check(start: '11:00 AM', end: '10:00 AM').single.kind, 'TIME');
    });
  });

  test('common periods come from the routine, ordered by time', () {
    final periods = EffectiveSchedule.commonPeriods([
      slot('a', 'SUNDAY', '11:00 AM', '12:30 PM', 'R'),
      slot('b', 'MONDAY', '09:00', '10:30', 'R'),
      slot('c', 'TUESDAY', '09:00 AM', '10:30 AM', 'R'),
    ]);
    expect(periods, [('09:00 AM', '10:30 AM'), ('11:00 AM', '12:30 PM')]);
  });

  group('not taken', () {
    test('marks a routine class as not taken with the reason', () {
      final list = EffectiveSchedule.forDate(
        routine: [slot('a', 'FRIDAY', '09:00 AM', '10:30 AM', 'Room 302')],
        changes: [change('n', ClassChangeType.notTaken, fridayKey, original: 'a', reason: 'Teacher absent')],
        date: friday,
      );
      expect(list.single.isNotTaken, isTrue);
      expect(list.single.isCancelled, isTrue);
      expect(list.single.changeNote, 'Not taken: Teacher absent');
    });

    test('applies on top of a move and to an extra class', () {
      final list = EffectiveSchedule.forDate(
        routine: [slot('a', 'FRIDAY', '09:00 AM', '10:30 AM', 'Room 302')],
        changes: [
          change('m', ClassChangeType.move, fridayKey, original: 'a', start: '02:00 PM', end: '03:30 PM'),
          change('n', ClassChangeType.notTaken, fridayKey, original: 'a'),
          change('x', ClassChangeType.extra, fridayKey, start: '11:00 AM', end: '12:00 PM'),
          change('nx', ClassChangeType.notTaken, fridayKey, original: 'change_x'),
        ],
        date: friday,
      );
      expect(list, hasLength(2));
      expect(list.every((s) => s.isNotTaken), isTrue);
      expect(list.firstWhere((s) => s.id == 'a').startTime, '02:00 PM');
    });

    test('a not-taken class does not block the room', () {
      final clashes = EffectiveSchedule.findClashes(
        routine: [slot('a', 'FRIDAY', '09:00 AM', '10:30 AM', 'Room 302')],
        changes: [change('n', ClassChangeType.notTaken, fridayKey, original: 'a')],
        date: friday,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        room: 'Room 302',
        teacherId: 'tX',
        targetYear: 2,
        targetSemester: 1,
      );
      expect(clashes, isEmpty);
    });
  });

  group('holidays', () {
    test('a holiday drops the weekly routine but keeps one-day extra classes', () {
      final list = EffectiveSchedule.forDate(
        routine: [slot('a', 'FRIDAY', '09:00 AM', '10:30 AM', 'Room 302')],
        changes: [change('x', ClassChangeType.extra, fridayKey, start: '11:00 AM', end: '12:00 PM')],
        date: friday,
        holidays: {fridayKey: 'Victory Day'},
      );
      expect(list.map((s) => s.id), ['change_x']);
    });

    test('routine classes do not clash on a holiday', () {
      final clashes = EffectiveSchedule.findClashes(
        routine: [slot('a', 'FRIDAY', '09:00 AM', '10:30 AM', 'Room 302')],
        changes: const [],
        date: friday,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        room: 'Room 302',
        teacherId: 't1',
        targetYear: 3,
        targetSemester: 1,
        holidays: {fridayKey: 'Victory Day'},
      );
      expect(clashes, isEmpty);
    });
  });
}
