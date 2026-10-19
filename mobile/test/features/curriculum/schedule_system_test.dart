import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/error/failures.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/controllers/schedule_controller.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/screens/student_schedule_screen.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/widgets/schedule_slot_form_dialog.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/screens/teacher_schedule_screen.dart';

class MockCurriculumRepository extends Mock implements CurriculumRepository {}
class MockAuthController extends Mock implements AuthController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCurriculumRepository mockRepo;
  late MockAuthController mockAuth;

  final sampleStudent = User(
    id: 'student_123',
    email: 'student@cse.jnu.ac.bd',
    fullName: 'Sadia Rahman',
    role: UserRole.student,
    year: 3,
    semester: 1,
  );

  final sampleCr = User(
    id: 'cr_123',
    email: 'cr@cse.jnu.ac.bd',
    fullName: 'Tanzil Ahmed (CR)',
    role: UserRole.cr,
    year: 3,
    semester: 1,
  );

  final sampleTeacher = User(
    id: 'teacher_layek',
    email: 'layek@cse.jnu.ac.bd',
    fullName: 'Dr. Md. Abu Layek',
    role: UserRole.teacher,
    assignedCourseIds: const ['CSE-3101', 'CSE-3102'],
  );

  const sampleSlot1 = ScheduleSlot(
    id: 'slot_1',
    courseId: 'c1',
    courseCode: 'CSE-3101',
    courseTitle: 'Operating Systems',
    teacherId: 'teacher_layek',
    teacherName: 'Dr. Md. Abu Layek',
    dayOfWeek: 'SUNDAY',
    startTime: '09:00 AM',
    endTime: '10:30 AM',
    room: 'Room 501',
    targetYear: 3,
    targetSemester: 1,
  );

  const sampleSlot2 = ScheduleSlot(
    id: 'slot_2',
    courseId: 'c2',
    courseCode: 'CSE-3102',
    courseTitle: 'Database Systems',
    teacherId: 'teacher_layek',
    teacherName: 'Dr. Md. Abu Layek',
    dayOfWeek: 'SUNDAY',
    startTime: '11:00 AM',
    endTime: '12:30 PM',
    room: 'Lab 2 (Software)',
    targetYear: 3,
    targetSemester: 1,
    isExtraClass: true,
  );

  const sampleExam = Exam(
    id: 'exam_1',
    courseId: 'c1',
    courseCode: 'CSE-3101',
    courseTitle: 'Operating Systems Mid-term',
    title: 'Mid-term Exam',
    examDate: '2026-10-30',
    startTime: '10:00 AM',
    endTime: '12:00 PM',
    room: 'Room 501',
    year: 3,
    semester: 1,
  );

  setUpAll(() {
    registerFallbackValue(sampleSlot1);
  });

  setUp(() async {
    mockRepo = MockCurriculumRepository();
    mockAuth = MockAuthController();

    when(() => mockAuth.addListener(any())).thenReturn(null);
    when(() => mockAuth.removeListener(any())).thenReturn(null);
    when(() => mockAuth.state).thenReturn(Authenticated(user: sampleStudent));
    when(() => mockAuth.currentUser).thenReturn(sampleStudent);

    when(() => mockRepo.getSchedule(
      day: any(named: 'day'),
      year: any(named: 'year'),
      semester: any(named: 'semester'),
      teacherId: any(named: 'teacherId'),
    )).thenAnswer((_) async => [sampleSlot1, sampleSlot2]);

    when(() => mockRepo.getExams()).thenAnswer((_) async => [sampleExam]);
    when(() => mockRepo.getAllCourses(
      year: any(named: 'year'),
      semester: any(named: 'semester'),
    )).thenAnswer((_) async => [
      const Course(
        id: 'c1',
        code: 'CSE-3101',
        title: 'Operating Systems',
        credit: 3.0,
        year: 3,
        semester: 1,
        courseType: 'THEORY',
      ),
    ]);
    when(() => mockRepo.getAllTeachers()).thenAnswer((_) async => [
      {'id': 'teacher_layek', 'name': 'Dr. Md. Abu Layek'},
    ]);

    await sl.reset();
    sl.registerLazySingleton<AuthController>(() => mockAuth);
    sl.registerLazySingleton<CurriculumRepository>(() => mockRepo);
    sl.registerLazySingleton<GetScheduleUseCase>(() => GetScheduleUseCase(sl()));
    sl.registerLazySingleton<CreateScheduleSlotUseCase>(() => CreateScheduleSlotUseCase(sl()));
    sl.registerLazySingleton<UpdateScheduleSlotUseCase>(() => UpdateScheduleSlotUseCase(sl()));
    sl.registerLazySingleton<DeleteScheduleSlotUseCase>(() => DeleteScheduleSlotUseCase(sl()));
    sl.registerLazySingleton<GetTeacherAvailabilityUseCase>(() => GetTeacherAvailabilityUseCase(sl()));
    sl.registerLazySingleton<GetWhatsAppBroadcastUseCase>(() => GetWhatsAppBroadcastUseCase(sl()));
    sl.registerLazySingleton<GetAllCoursesUseCase>(() => GetAllCoursesUseCase(sl()));
    sl.registerLazySingleton<GetAllTeachersUseCase>(() => GetAllTeachersUseCase(sl()));
    sl.registerLazySingleton<GetExamsUseCase>(() => GetExamsUseCase(sl()));

    sl.registerFactory<ScheduleController>(() => ScheduleController(
      getScheduleUseCase: sl(),
      createScheduleSlotUseCase: sl(),
      updateScheduleSlotUseCase: sl(),
      deleteScheduleSlotUseCase: sl(),
      getTeacherAvailabilityUseCase: sl(),
      getWhatsAppBroadcastUseCase: sl(),
      getAllCoursesUseCase: sl(),
      getAllTeachersUseCase: sl(),
    ));

    sl.registerFactory<ExamsController>(() => ExamsController(getExamsUseCase: sl()));
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. DOMAIN & CONTROLLER UNIT TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('Schedule Entities & Controller Unit Tests', () {
    test('ScheduleSlot copyWith and equality work correctly', () {
      final copy = sampleSlot1.copyWith(isExtraClass: true, room: 'Room 401');
      expect(copy.isExtraClass, true);
      expect(copy.room, 'Room 401');
      expect(copy.courseCode, sampleSlot1.courseCode);
      expect(copy.id, sampleSlot1.id);
    });

    test('TeacherAvailability and WhatsAppBroadcastData hold correct properties', () {
      const avail = TeacherAvailability(
        teacherId: 'teacher_layek',
        teacherName: 'Dr. Md. Abu Layek',
        dayOfWeek: 'SUNDAY',
        busySlots: [
          TeacherAvailabilitySlot(startTime: '09:00 AM', endTime: '10:30 AM', courseCode: 'CSE-3101', room: 'Room 501'),
        ],
        freeWindows: [
          TeacherAvailabilityWindow(startTime: '10:30 AM', endTime: '05:00 PM', durationMinutes: 390),
        ],
      );

      expect(avail.freeWindows.length, 1);
      expect(avail.busySlots.length, 1);
      expect(avail.busySlots.first.room, 'Room 501');

      const broadcast = WhatsAppBroadcastData(
        date: '2026-10-20',
        dayOfWeek: 'MONDAY',
        slotCount: 2,
        broadcastText: 'Tomorrow Class Routine',
        whatsappUrl: 'https://wa.me/?text=Tomorrow',
      );

      expect(broadcast.slotCount, 2);
      expect(broadcast.dayOfWeek, 'MONDAY');
    });

    test('ScheduleController fetchSchedule emits ScheduleLoaded with slots', () async {
      final controller = sl<ScheduleController>();
      expect(controller.state, isA<ScheduleInitial>());

      await controller.fetchSchedule(day: 'SUNDAY');
      expect(controller.state, isA<ScheduleLoaded>());
      final loaded = controller.state as ScheduleLoaded;
      expect(loaded.slots.length, 2);
      expect(loaded.selectedDay, 'SUNDAY');
    });

    test('ScheduleController fetchSchedule emits ScheduleError when repo throws', () async {
      when(() => mockRepo.getSchedule(
        day: any(named: 'day'),
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        teacherId: any(named: 'teacherId'),
      )).thenThrow(const ServerFailure(message: 'Failed to load schedule.'));

      final controller = sl<ScheduleController>();
      await controller.fetchSchedule(day: 'SUNDAY');

      expect(controller.state, isA<ScheduleError>());
      expect((controller.state as ScheduleError).message, 'Failed to load schedule.');
    });

    test('ScheduleController toggleViewMode alternates between list and calendar', () async {
      final controller = sl<ScheduleController>();
      await controller.fetchSchedule();

      expect(controller.isCalendarView, false);
      controller.toggleViewMode();
      expect(controller.isCalendarView, true);
      controller.toggleViewMode();
      expect(controller.isCalendarView, false);
    });

    test('ScheduleController createSlot delegates to usecase and refreshes schedule', () async {
      when(() => mockRepo.createScheduleSlot(any())).thenAnswer((_) async => sampleSlot1);

      final controller = sl<ScheduleController>();
      final success = await controller.createSlot(sampleSlot1);

      expect(success, true);
      expect(controller.actionSuccess, contains('CSE-3101'));
      verify(() => mockRepo.createScheduleSlot(sampleSlot1)).called(1);
    });

    test('ScheduleController deleteSlot delegates to usecase and refreshes schedule', () async {
      when(() => mockRepo.deleteScheduleSlot(any())).thenAnswer((_) async {});

      final controller = sl<ScheduleController>();
      final success = await controller.deleteSlot('slot_1');

      expect(success, true);
      verify(() => mockRepo.deleteScheduleSlot('slot_1')).called(1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. STUDENT SCHEDULE SCREEN WIDGET TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('StudentScheduleScreen Widget Tests', () {
    testWidgets('Renders Routine and Exam tabs, Day Filter chips, and slot details', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const StudentScheduleScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Class Routine'), findsOneWidget);
      expect(find.text('Exam Schedule'), findsOneWidget);

      // Verify Day Filter Chips
      expect(find.text('All Days'), findsOneWidget);
      expect(find.text('SUN'), findsWidgets);
      expect(find.text('MON'), findsOneWidget);

      // Verify slot cards
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('Room 501'), findsOneWidget);
      expect(find.text('Extra'), findsOneWidget);
    });

    testWidgets('Schedule renders pure List View without calendar view toggle', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const StudentScheduleScreen()));
      await tester.pumpAndSettle();

      // Verify calendar toggle button is not present
      expect(find.byTooltip('Switch to Calendar View'), findsNothing);
      expect(find.byTooltip('Switch to List View'), findsNothing);

      // Verify slot details rendered in list view
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('Database Systems'), findsOneWidget);
    });

    testWidgets('CR view displays Tomorrow-Only Banner, Schedule for Tomorrow, and WhatsApp Broadcaster', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sampleCr);
      when(() => mockAuth.state).thenReturn(Authenticated(user: sampleCr));

      await tester.pumpWidget(buildTestableWidget(const StudentScheduleScreen()));
      await tester.pumpAndSettle();

      expect(find.text('CR Schedule Terminal'), findsOneWidget);
      expect(find.text('Tomorrow Only'), findsOneWidget);
      expect(find.text('Schedule for Tomorrow'), findsWidgets);
      expect(find.text('Broadcast on WhatsApp'), findsOneWidget);

      // Tapping Broadcast on WhatsApp triggers modal
      when(() => mockRepo.getWhatsAppBroadcast(year: any(named: 'year'), semester: any(named: 'semester')))
          .thenAnswer((_) async => const WhatsAppBroadcastData(
                date: '2026-10-20',
                dayOfWeek: 'MONDAY',
                slotCount: 2,
                broadcastText: '📢 *CSE JnU EduPortal — Class Routine for Tomorrow*',
                whatsappUrl: 'https://wa.me/?text=Routine',
              ));

      await tester.tap(find.text('Broadcast on WhatsApp'));
      await tester.pumpAndSettle();

      expect(find.text('WhatsApp Broadcast'), findsOneWidget);
      expect(find.text('Copy Message'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('Renders empty state when no classes are scheduled', (tester) async {
      when(() => mockRepo.getSchedule(
        day: any(named: 'day'),
        year: any(named: 'year'),
        semester: any(named: 'semester'),
        teacherId: any(named: 'teacherId'),
      )).thenAnswer((_) async => []);

      await tester.pumpWidget(buildTestableWidget(const StudentScheduleScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No classes scheduled for this filter.'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. TEACHER SCHEDULE SCREEN WIDGET TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('TeacherScheduleScreen Widget Tests', () {
    testWidgets('Renders Faculty Schedule Hub, Routine Grid, and Add Class action', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sampleTeacher);
      when(() => mockAuth.state).thenReturn(Authenticated(user: sampleTeacher));

      await tester.pumpWidget(buildTestableWidget(const TeacherScheduleScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Faculty Schedule Hub'), findsOneWidget);
      expect(find.text('Routine Grid'), findsOneWidget);
      expect(find.text('Manage Exams'), findsOneWidget);
      expect(find.text('Add Class'), findsWidgets);

      // Verify timeline cards
      expect(find.textContaining('Operating Systems'), findsWidgets);
      expect(find.text('Room 501'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('Tapping delete icon shows AppConfirmationDialog', (tester) async {
      when(() => mockAuth.currentUser).thenReturn(sampleTeacher);
      when(() => mockAuth.state).thenReturn(Authenticated(user: sampleTeacher));

      await tester.pumpWidget(buildTestableWidget(const TeacherScheduleScreen()));
      await tester.pumpAndSettle();

      final deleteBtnFinder = find.byIcon(Icons.delete_outline).first;
      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Delete Class Slot?'), findsOneWidget);
      expect(find.text('Delete Slot'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. SCHEDULE SLOT FORM DIALOG WIDGET TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('ScheduleSlotFormDialog Widget Tests', () {
    testWidgets('For CR role, locks day to tomorrow and displays CR tomorrow-only rule', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduleSlotFormDialog(
              userRole: UserRole.cr,
              defaultYear: 3,
              defaultSemester: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('CR Mode — Approved Tomorrow-Only Rule'), findsOneWidget);
      expect(find.textContaining('CR Rule: Scheduling is strictly restricted to tomorrow'), findsOneWidget);
      expect(find.text('Schedule for Tomorrow'), findsOneWidget);
      expect(find.text('Course *'), findsOneWidget);
      expect(find.text('Faculty / Teacher *'), findsOneWidget);
      expect(find.text('Classroom / Lab *'), findsOneWidget);
      expect(find.text('Start Time *'), findsOneWidget);
      expect(find.text('End Time *'), findsOneWidget);
    });
  });
}
