import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/utils/class_time.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/class_change.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/class_actions_sheet.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/class_change_sheet.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/class_slot_tile.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/course_kinds.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/time_range_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'class_change_sheet_test.dart' show FakeRepo;

const cr = User(id: 'cr', email: 'c@x.bd', fullName: 'CR', role: UserRole.cr, year: 3, semester: 1);
const student = User(id: 's', email: 's@x.bd', fullName: 'S', role: UserRole.student, year: 3, semester: 1);
const teacher = User(id: 't1', email: 't@x.bd', fullName: 'T', role: UserRole.teacher);
const otherTeacher = User(id: 't9', email: 'o@x.bd', fullName: 'O', role: UserRole.teacher);

const os = _os;
const _os = ScheduleSlot(
  id: 'r1', courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'Operating Systems', teacherId: 't1',
  teacherName: 'Dr. Layek', dayOfWeek: 'THURSDAY', startTime: '09:00 AM', endTime: '10:30 AM', room: 'Room 302',
  targetYear: 3, targetSemester: 1,
);

void main() {
  final thursday = DateTime(2026, 11, 26);
  final before = DateTime(2026, 11, 26, 8); // before class
  final during = DateTime(2026, 11, 26, 9, 30); // class has started

  group('Modify options', () {
    List<ClassAction> opts(User u, {ScheduleSlot slot = os, DateTime? date, required DateTime now}) =>
        ClassActions.available(user: u, slot: slot, date: date ?? thursday, now: now);

    test('CR: move / cancel before the class, not taken once it has started', () {
      expect(opts(cr, now: before), [ClassAction.move, ClassAction.cancel]);
      expect(opts(cr, now: during), [ClassAction.notTaken]);
      expect(opts(cr, date: DateTime(2026, 11, 20), now: before), [ClassAction.notTaken]);
      expect(opts(cr, date: DateTime(2026, 11, 10), now: before), isEmpty); // older than a week
    });

    test('teacher: own course only, and never not taken', () {
      expect(opts(teacher, now: before), [ClassAction.move, ClassAction.cancel]);
      expect(opts(teacher, now: during), isEmpty);
      expect(opts(otherTeacher, now: before), isEmpty);
    });

    test('students and other batches get nothing', () {
      expect(opts(student, now: before), isEmpty);
      expect(opts(cr, slot: os.copyWith(targetYear: 2), now: before), isEmpty);
    });

    test('a changed class offers undo instead of another move', () {
      final moved = os.copyWith(status: 'MOVED', changeNote: 'Moved from 09:00 AM, Room 302');
      expect(opts(cr, slot: moved, now: before), [ClassAction.undo]);
      final cancelled = os.copyWith(status: 'CANCELLED', changeNote: 'Cancelled');
      expect(opts(cr, slot: cancelled, now: during), [ClassAction.undo]);
    });
  });

  group('Class row', () {
    setUp(CourseKinds.reset);

    testWidgets('time, name, room and kind, teacher; no course code', (tester) async {
      CourseKinds.seed({'CSE-3101': false});
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ClassSlotTile(slot: os))));
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('9:00 – 10:30 AM'), findsOneWidget); // calendar-style time line
      expect(find.text('Room 302'), findsOneWidget);
      expect(find.text('Theory'), findsOneWidget);
      expect(find.text('Dr. Layek'), findsOneWidget);
      expect(find.textContaining('CSE-3101'), findsNothing);
    });

    testWidgets('Theory / Lab comes from the course', (tester) async {
      CourseKinds.seed({'CSE-3101': true});
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ClassSlotTile(slot: os))));
      expect(find.text('Lab'), findsOneWidget);
    });
  });

  testWidgets('Modify → Cancel opens the form with the class already chosen', (tester) async {
    // The form offers dates relative to the real clock, so use today.
    final today = DateTime.now();
    final thursday = DateTime(today.year, today.month, today.day);
    final before = thursday; // midnight: the late class has not started
    final os = _os.copyWith(dayOfWeek: ClassTime.dayOfWeek(thursday), startTime: '11:58 PM', endTime: '11:59 PM');
    final repo = FakeRepo(routine: [os], courses: const []);
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ClassSlotTile(
          slot: os,
          action: ClassModifyButton(user: cr, slot: os, date: thursday, now: before, repository: repo),
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('modify_r1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('class_action_move')), findsOneWidget);
    expect(find.byKey(const ValueKey('class_action_notTaken')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('class_action_cancel')));
    await tester.pumpAndSettle();

    // Focused form: no type switch, no day chips, no class list.
    expect(find.byType(ClassChangeSheet), findsOneWidget);
    expect(find.text('Cancel Class'), findsOneWidget);
    expect(find.byKey(const ValueKey('change_type')), findsNothing);
    expect(find.byKey(const ValueKey('target_r1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('change_save')));
    await tester.pumpAndSettle();
    final c = repo.created.single;
    expect(c.type, ClassChangeType.cancel);
    expect(c.originalSlotId, 'r1');
    expect(c.date, ClassTime.dateKey(thursday));
  });

  testWidgets('no Modify button when nothing applies', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ClassModifyButton(user: student, slot: os, date: thursday, now: before)),
    ));
    expect(find.text('Modify'), findsNothing);
  });

  testWidgets('Move form: From / To start at the current time; changing From keeps the length', (tester) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final slot = _os.copyWith(dayOfWeek: ClassTime.dayOfWeek(day), startTime: '11:00 PM', endTime: '11:30 PM');
    final repo = FakeRepo(routine: [slot], courses: const []);
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ClassChangeSheet(
          user: cr, repository: repo, initialType: ClassChangeType.move, initialDate: day, initialSlotId: 'r1'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('11:00 PM'), findsWidgets);
    expect(find.text('11:30 PM'), findsWidgets);
    expect(find.textContaining('Now: 11:00 PM – 11:30 PM'), findsOneWidget);

    // Nothing changed yet: Save is off.
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('change_save'))).onPressed, isNull);

    TimeRangeField.debugPicker = (_, __) async => '10:00 PM';
    addTearDown(() => TimeRangeField.debugPicker = null);
    await tester.tap(find.byKey(const ValueKey('time_from')));
    await tester.pumpAndSettle();
    expect(find.text('10:30 PM'), findsOneWidget); // 30-minute class stays 30 minutes

    await tester.tap(find.byKey(const ValueKey('change_save')));
    await tester.pumpAndSettle();
    expect(repo.created.single.startTime, '10:00 PM');
    expect(repo.created.single.endTime, '10:30 PM');
  });
}
