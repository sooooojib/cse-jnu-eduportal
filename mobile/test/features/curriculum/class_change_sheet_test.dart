import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/utils/class_time.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/repositories/class_change_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/class_change.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/class_change_sheet.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/time_range_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRepo implements ClassChangeRepository {
  final List<ScheduleSlot> routine;
  final List<Course> courses;
  final List<ClassChange> created = [];
  FakeRepo({this.routine = const [], this.courses = const []});

  @override
  Future<List<ScheduleSlot>> routineForDay(String dayOfWeek) async =>
      routine.where((s) => s.dayOfWeek == dayOfWeek).toList();
  @override
  Future<List<ClassChange>> changesOn(DateTime date) async => const [];
  @override
  Future<List<ClassChange>> changesForBatch({required int year, required int semester, required DateTime from, required DateTime to}) async => const [];
  @override
  Future<List<ClassChange>> changesForCourses({required Set<String> courseIds, required DateTime from, required DateTime to}) async => const [];
  @override
  Future<List<Course>> plannableCourses(User user) async => courses;
  @override
  Future<void> create(ClassChange change) async => created.add(change);
  @override
  Future<void> undo(String changeId) async {}
}

const cr = User(id: 'cr', email: 'c@x.bd', fullName: 'CR', role: UserRole.cr, year: 3, semester: 1, session: '2021-2022');
const os = Course(id: 'CSE-3101', code: 'CSE-3101', title: 'Operating Systems', credit: 3, year: 3, semester: 1,
    courseType: 'THEORY', teacherId: 't1', teacherName: 'Dr. Layek');

void main() {
  final now = DateTime(2026, 11, 26, 10); // Thursday
  final tomorrow = DateTime(2026, 11, 27); // Friday
  final routine = [
    ScheduleSlot(id: 'a', courseId: 'CSE-3105', courseCode: 'CSE-3105', courseTitle: 'SE', teacherId: 't2',
        teacherName: 'Dr. Sharmin', dayOfWeek: 'FRIDAY', startTime: '09:00 AM', endTime: '10:30 AM',
        room: 'Room 302', targetYear: 3, targetSemester: 1),
  ];

  Future<FakeRepo> open(WidgetTester tester, {ClassChangeType type = ClassChangeType.extra}) async {
    final repo = FakeRepo(routine: routine, courses: [os]);
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ClassChangeSheet(user: cr, repository: repo, now: now, initialDate: tomorrow, initialType: type),
      ),
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('extra class: a clash blocks saving, a free time saves', (tester) async {
    final repo = await open(tester);

    await tester.tap(find.byKey(const ValueKey('change_course')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSE-3101: Operating Systems').last);
    await tester.pumpAndSettle();

    // 09:00-10:30 clashes with SE for the same batch.
    // Set From = 09:00 AM; To follows with the usual class length.
    TimeRangeField.debugPicker = (_, __) async => '09:00 AM';
    addTearDown(() => TimeRangeField.debugPicker = null);
    await tester.tap(find.byKey(const ValueKey('time_from')));
    await tester.pumpAndSettle();
    expect(find.text('10:30 AM'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('change_room')), 'Room 302');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('change_clashes')), findsOneWidget);
    expect(find.textContaining('Room 302 is booked for CSE-3105'), findsOneWidget);
    expect(find.textContaining('Your batch already has CSE-3105'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('change_save'))).onPressed, isNull);

    // A different room still clashes for the batch; move the time instead -> free.
    await tester.enterText(find.byKey(const ValueKey('change_room')), 'Room 501');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('change_clashes')), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('cancel: pick tomorrow\'s class and save without times', (tester) async {
    final repo = await open(tester, type: ClassChangeType.cancel);

    expect(find.text('Which class to cancel?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('target_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change_save')));
    await tester.pumpAndSettle();

    expect(repo.created.single.type, ClassChangeType.cancel);
    expect(repo.created.single.originalSlotId, 'a');
    expect(repo.created.single.date, ClassTime.dateKey(tomorrow));
    expect(repo.created.single.createdBy, 'cr');
  });

  testWidgets('only today and the next 7 days are offered', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('date_2026-11-26')), findsOneWidget);
    expect(find.byKey(const ValueKey('date_2026-12-03')), findsOneWidget);
    expect(find.byKey(const ValueKey('date_2026-12-04')), findsNothing);
  });

  testWidgets('CR reports a class as not taken for an earlier day', (tester) async {
    final repo = FakeRepo(routine: [
      ScheduleSlot(id: 'w', courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS', teacherId: 't1',
          teacherName: 'Dr. Layek', dayOfWeek: 'TUESDAY', startTime: '09:00 AM', endTime: '10:30 AM',
          room: 'Room 302', targetYear: 3, targetSemester: 1),
    ], courses: [os]);
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ClassChangeSheet(user: cr, repository: repo, now: now, initialType: ClassChangeType.notTaken),
      ),
    ));
    await tester.pumpAndSettle();

    // Not taken offers today and the past week only.
    expect(find.byKey(const ValueKey('date_2026-11-27')), findsNothing);
    expect(find.byKey(const ValueKey('date_2026-11-19')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('date_2026-11-24'))); // Tuesday
    await tester.pumpAndSettle();

    expect(find.text('Which class was not taken?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('target_w')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change_save')));
    await tester.pumpAndSettle();

    final c = repo.created.single;
    expect(c.type, ClassChangeType.notTaken);
    expect(c.date, '2026-11-24');
    expect(c.originalSlotId, 'w');
    expect(c.teacherId, 't1');
  });

  testWidgets('teachers do not get Not taken or earlier days', (tester) async {
    const teacher = User(id: 't1', email: 't@x.bd', fullName: 'T', role: UserRole.teacher);
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ClassChangeSheet(user: teacher, repository: FakeRepo(courses: [os]), now: now)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Not taken'), findsNothing);
    expect(find.byKey(const ValueKey('date_earlier')), findsNothing);
  });
}
