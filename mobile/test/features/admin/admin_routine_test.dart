import 'package:cse_jnu_eduportal/features/admin/presentation/screens/admin_routine_screen.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/time_range_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../curriculum/class_change_sheet_test.dart' show FakeRepo;

class MockCurriculum extends Mock implements CurriculumRepository {}

ScheduleSlot routineSlot(String id, String day, String start, String end, String room,
        {String course = 'CSE-3101', String teacher = 't1', int year = 3, int sem = 1}) =>
    ScheduleSlot(
      id: id, courseId: course, courseCode: course, courseTitle: 'Course $course', teacherId: teacher,
      teacherName: 'Teacher $teacher', dayOfWeek: day, startTime: start, endTime: end, room: room,
      targetYear: year, targetSemester: sem,
    );

void main() {
  setUpAll(() => registerFallbackValue(routineSlot('f', 'SUNDAY', '09:00 AM', '10:00 AM', 'R')));

  const os = Course(id: 'CSE-3101', code: 'CSE-3101', title: 'Operating Systems', credit: 3, year: 1, semester: 1,
      courseType: 'THEORY', teacherId: 't1', teacherName: 'Teacher t1');

  late MockCurriculum curriculum;

  setUp(() {
    curriculum = MockCurriculum();
    when(() => curriculum.getSchedule(year: any(named: 'year'), semester: any(named: 'semester'))).thenAnswer(
      (_) async => [
        routineSlot('r1', 'SUNDAY', '09:00 AM', '10:30 AM', 'Room 302', year: 1),
        routineSlot('old', 'SUNDAY', '11:00 AM', '12:00 PM', 'Room 302', year: 1).copyWith(date: '2026-01-04'),
      ],
    );
    when(() => curriculum.getAllCourses(year: any(named: 'year'), semester: any(named: 'semester')))
        .thenAnswer((_) async => [os]);
    when(() => curriculum.getAllTeachers()).thenAnswer((_) async => [
          {'id': 't1', 'name': 'Teacher t1'},
          {'id': 't2', 'name': 'Teacher t2'},
        ]);
    when(() => curriculum.createScheduleSlot(any())).thenAnswer((i) async => i.positionalArguments.first as ScheduleSlot);
  });

  Future<void> pump(WidgetTester tester, FakeRepo changes) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: AdminRoutineScreen(curriculum: curriculum, changes: changes)));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the weekly routine by day, without one-off dated classes', (tester) async {
    await pump(tester, FakeRepo());
    expect(find.byKey(const ValueKey('routine_day_SUNDAY')), findsOneWidget);
    expect(find.byKey(const ValueKey('routine_day_THURSDAY')), findsOneWidget);
    expect(find.byKey(const ValueKey('routine_slot_r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('routine_slot_old')), findsNothing);
  });

  testWidgets('adding a class: a room clash in another batch blocks saving, a free room saves', (tester) async {
    // Another batch (Year 2) uses Room 302 on Monday 09:00–10:30.
    final changes = FakeRepo(routine: [routineSlot('y2', 'MONDAY', '09:00 AM', '10:30 AM', 'Room 302', teacher: 't9', year: 2)]);
    await pump(tester, changes);

    await tester.tap(find.byKey(const ValueKey('routine_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('routine_course')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSE-3101: Operating Systems').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('routine_daychip_MONDAY')));
    await tester.pumpAndSettle();
    // Set From = 09:00 AM; To follows with the usual class length.
    TimeRangeField.debugPicker = (_, __) async => '09:00 AM';
    addTearDown(() => TimeRangeField.debugPicker = null);
    await tester.tap(find.byKey(const ValueKey('time_from')));
    await tester.pumpAndSettle();
    expect(find.text('10:30 AM'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('routine_room')), 'Room 302');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('routine_clashes')), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('routine_save'))).onPressed, isNull);

    await tester.enterText(find.byKey(const ValueKey('routine_room')), 'Room 401');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('routine_clashes')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('routine_save')));
    await tester.pumpAndSettle();

    final saved = verify(() => curriculum.createScheduleSlot(captureAny())).captured.single as ScheduleSlot;
    expect(saved.dayOfWeek, 'MONDAY');
    expect(saved.room, 'Room 401');
    expect(saved.teacherId, 't1'); // taken from the course
    expect(saved.targetYear, 1);
    expect(saved.targetSemester, 1);
    expect(saved.date, isNull);
    expect(saved.isExtraClass, isFalse);
  });
}
