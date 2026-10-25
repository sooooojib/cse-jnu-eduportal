import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';
import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';

import 'package:cse_jnu_eduportal/features/teacher/domain/entities/teacher_dashboard_data.dart';
import 'package:cse_jnu_eduportal/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:cse_jnu_eduportal/features/teacher/domain/usecases/get_teacher_dashboard_data_usecase.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/controllers/teacher_dashboard_controller.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/controllers/teacher_dashboard_state.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/screens/teacher_dashboard_screen.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/widgets/teacher_metric_card.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/widgets/time_aware_classes_card.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/widgets/assigned_course_card.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/widgets/teacher_quick_actions.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/widgets/teacher_profile_dialog.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/screens/teacher_attendance_terminal_screen.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/controllers/schedule_controller.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/screens/teacher_schedule_screen.dart';

class MockTeacherRepository extends Mock implements TeacherRepository {}
class MockAuthController extends Mock implements AuthController {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockCurriculumRepository extends Mock implements CurriculumRepository {}

class FakeUser extends Fake implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTeacherRepository mockTeacherRepo;
  late MockAuthController mockAuthController;
  late MockLocalStorageService mockLocalStorageService;
  late GetTeacherDashboardDataUseCase useCase;

  const sampleTeacher = User(
    id: 'teacher_layek_uid',
    email: 'layek@cse.jnu.ac.bd',
    fullName: 'Dr. Md. Abu Layek',
    role: UserRole.teacher,
    phone: '+8801711000000',
    assignedCourseIds: ['CSE-3101', 'CSE-3102'],
  );

  const sampleCourse1 = Course(
    id: 'CSE-3101',
    code: 'CSE-3101',
    title: 'Operating Systems',
    credit: 3.0,
    year: 3,
    semester: 1,
    courseType: 'THEORY',
    teacherId: 'teacher_layek_uid',
    teacherName: 'Dr. Md. Abu Layek',
  );

  const sampleCourse2 = Course(
    id: 'CSE-3102',
    code: 'CSE-3102',
    title: 'Operating Systems Sessional',
    credit: 1.5,
    year: 3,
    semester: 1,
    courseType: 'LAB',
    teacherId: 'teacher_layek_uid',
    teacherName: 'Dr. Md. Abu Layek',
  );

  const sampleSlot1 = ScheduleSlot(
    id: 'sch_sun_0900',
    courseId: 'CSE-3101',
    courseCode: 'CSE-3101',
    courseTitle: 'Operating Systems',
    teacherId: 'teacher_layek_uid',
    teacherName: 'Dr. Md. Abu Layek',
    dayOfWeek: 'SUNDAY',
    startTime: '09:00',
    endTime: '10:30',
    room: 'Room 501',
    targetYear: 3,
    targetSemester: 1,
  );

  const sampleSlot2 = ScheduleSlot(
    id: 'sch_sun_1100',
    courseId: 'CSE-3102',
    courseCode: 'CSE-3102',
    courseTitle: 'Operating Systems Sessional',
    teacherId: 'teacher_layek_uid',
    teacherName: 'Dr. Md. Abu Layek',
    dayOfWeek: 'SUNDAY',
    startTime: '11:00',
    endTime: '13:30',
    room: 'Lab 2',
    targetYear: 3,
    targetSemester: 1,
  );

  final sampleDashboardData = TeacherDashboardData(
    teacherId: 'teacher_layek_uid',
    teacherName: 'Dr. Md. Abu Layek',
    email: 'layek@cse.jnu.ac.bd',
    phone: '+8801711000000',
    role: UserRole.teacher,
    pendingCounselingCount: 4,
    feedbackCount: 18,
    classesTaughtCount: 12,
    assignedCourses: const [sampleCourse1, sampleCourse2],
    timeAwareClasses: const [sampleSlot1, sampleSlot2],
    isTomorrow: false,
    targetDateLabel: "Today · Oct 19, 2026",
    dayOfWeek: "SUNDAY",
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(FakeUser());
  });

  setUp(() async {
    mockTeacherRepo = MockTeacherRepository();
    mockAuthController = MockAuthController();
    mockLocalStorageService = MockLocalStorageService();
    useCase = GetTeacherDashboardDataUseCase(mockTeacherRepo);

    when(() => mockAuthController.addListener(any())).thenReturn(null);
    when(() => mockAuthController.removeListener(any())).thenReturn(null);
    when(() => mockAuthController.state).thenReturn(const Authenticated(user: sampleTeacher));
    when(() => mockAuthController.currentUser).thenReturn(sampleTeacher);
    when(() => mockLocalStorageService.getThemeMode()).thenReturn('system');

    await sl.reset();
    sl.registerLazySingleton<LocalStorageService>(() => mockLocalStorageService);
    sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: sl()));
    sl.registerLazySingleton<AuthController>(() => mockAuthController);
    sl.registerLazySingleton<TeacherRepository>(() => mockTeacherRepo);
    sl.registerLazySingleton<GetTeacherDashboardDataUseCase>(() => useCase);
    sl.registerFactory<TeacherDashboardController>(() => TeacherDashboardController(
      getTeacherDashboardDataUseCase: sl(),
      authController: sl(),
    ));

    final mockCurriculumRepo = MockCurriculumRepository();
    when(() => mockCurriculumRepo.getSchedule(
      day: any(named: 'day'),
      year: any(named: 'year'),
      semester: any(named: 'semester'),
      teacherId: any(named: 'teacherId'),
    )).thenAnswer((_) async => []);
    when(() => mockCurriculumRepo.getExams()).thenAnswer((_) async => []);
    sl.registerFactory<ScheduleController>(() => ScheduleController(getScheduleUseCase: GetScheduleUseCase(mockCurriculumRepo)));
    sl.registerFactory<ExamsController>(() => ExamsController(getExamsUseCase: GetExamsUseCase(mockCurriculumRepo)));
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. DOMAIN & CONTROLLER UNIT TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('Teacher Dashboard Domain & Controller', () {
    test('TeacherDashboardData holds exact properties and supports equality', () {
      final copy = TeacherDashboardData(
        teacherId: 'teacher_layek_uid',
        teacherName: 'Dr. Md. Abu Layek',
        email: 'layek@cse.jnu.ac.bd',
        phone: '+8801711000000',
        role: UserRole.teacher,
        pendingCounselingCount: 4,
        feedbackCount: 18,
        classesTaughtCount: 12,
        assignedCourses: const [sampleCourse1, sampleCourse2],
        timeAwareClasses: const [sampleSlot1, sampleSlot2],
        isTomorrow: false,
        targetDateLabel: "Today · Oct 19, 2026",
        dayOfWeek: "SUNDAY",
      );

      expect(sampleDashboardData, equals(copy));
      expect(sampleDashboardData.assignedCourses.length, 2);
      expect(sampleDashboardData.timeAwareClasses.length, 2);
      expect(sampleDashboardData.pendingCounselingCount, 4);
      expect(sampleDashboardData.feedbackCount, 18);
      expect(sampleDashboardData.classesTaughtCount, 12);
    });

    test('TeacherDashboardController loads data and emits Loaded state', () async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );

      expect(controller.state, const TeacherDashboardInitial());

      await controller.loadDashboardData();

      expect(controller.state, isA<TeacherDashboardLoaded>());
      final loaded = controller.state as TeacherDashboardLoaded;
      expect(loaded.data.teacherName, 'Dr. Md. Abu Layek');
      expect(loaded.data.assignedCourses.length, 2);
    });

    test('TeacherDashboardController emits Error state when repo throws', () async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenThrow(Exception('Firestore network disconnected'));

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );

      await controller.loadDashboardData();

      expect(controller.state, isA<TeacherDashboardError>());
      final err = controller.state as TeacherDashboardError;
      expect(err.message, contains('Firestore network disconnected'));
    });

    test('TeacherDashboardController emits Error when unauthenticated', () async {
      when(() => mockAuthController.currentUser).thenReturn(null);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );

      await controller.loadDashboardData();

      expect(controller.state, isA<TeacherDashboardError>());
      final err = controller.state as TeacherDashboardError;
      expect(err.message, 'User is not authenticated.');
    });

    test('Time-aware window logic: 05:00-16:59 is today, 17:00-04:59 is tomorrow', () {
      final morningTime = DateTime(2026, 10, 19, 9, 30); // 09:30 AM
      final eveningTime = DateTime(2026, 10, 19, 17, 1); // 05:01 PM
      final lateNightTime = DateTime(2026, 10, 20, 2, 15); // 02:15 AM
      final afternoonTime = DateTime(2026, 10, 19, 16, 59); // 04:59 PM

      bool isTomorrowWindow(DateTime t) => t.hour >= 17 || t.hour < 5;

      expect(isTomorrowWindow(morningTime), isFalse);
      expect(isTomorrowWindow(afternoonTime), isFalse);
      expect(isTomorrowWindow(eveningTime), isTrue);
      expect(isTomorrowWindow(lateNightTime), isTrue);
    });

    test('Internal attendance markers are excluded from ordinary classes', () {
      const normalClass = ScheduleSlot(
        id: 's1',
        courseId: 'c1',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        teacherId: 't1',
        teacherName: 'Dr. Layek',
        dayOfWeek: 'SUNDAY',
        startTime: '09:00',
        endTime: '10:30',
        room: '501',
        targetYear: 3,
        targetSemester: 1,
      );

      const markerClass1 = ScheduleSlot(
        id: 'm1',
        courseId: 'c1',
        courseCode: 'ATT_CSE-3101',
        courseTitle: 'Attendance Marker Session',
        teacherId: 't1',
        teacherName: 'Dr. Layek',
        dayOfWeek: 'SUNDAY',
        startTime: '09:00',
        endTime: '10:30',
        room: 'Terminal',
        targetYear: 3,
        targetSemester: 1,
      );

      const markerClass2 = ScheduleSlot(
        id: 'm2',
        courseId: 'c2',
        courseCode: 'INTERNAL_MARKER',
        courseTitle: 'Internal Marker',
        teacherId: 't1',
        teacherName: 'Dr. Layek',
        dayOfWeek: 'SUNDAY',
        startTime: '10:00',
        endTime: '11:00',
        room: 'Server',
        targetYear: 3,
        targetSemester: 1,
      );

      bool isInternalMarker(ScheduleSlot slot) {
        final code = slot.courseCode.toUpperCase();
        final title = slot.courseTitle.toLowerCase();
        return code.startsWith('ATT_') ||
            code.startsWith('INTERNAL_') ||
            code.contains('MARKER') ||
            title.contains('attendance marker') ||
            title.contains('internal marker');
      }

      final slots = [normalClass, markerClass1, markerClass2];
      final filtered = slots.where((s) => !isInternalMarker(s)).toList();

      expect(filtered.length, 1);
      expect(filtered.first.courseCode, 'CSE-3101');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. WIDGET RENDERING & UI TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('Teacher Dashboard Screen Widgets', () {
    testWidgets('Renders loading state properly', (tester) async {
      final completer = Completer<TeacherDashboardData>();
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) => completer.future);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );

      controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Synchronizing departmental routine and courses...'), findsOneWidget);

      // Complete future to clean up state
      completer.complete(sampleDashboardData);
      await tester.pumpAndSettle();
    });

    testWidgets('Renders error state and clicking retry reloads dashboard', (tester) async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenThrow(Exception('Timeout loading schedule'));

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );

      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pump();

      expect(find.text('Unable to Load Dashboard'), findsOneWidget);
      expect(find.text('Timeout loading schedule'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Now mock success for retry
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back, Dr. Md. Abu Layek.'), findsOneWidget);
    });

    testWidgets('Renders Teacher Identity: name, role badge, avatar, and top bar', (tester) async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      // Top App Bar
      expect(find.text('JnU EduPortal'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      // Greeting & Role
      expect(find.text('Welcome back, Dr. Md. Abu Layek.'), findsOneWidget);
      expect(find.text('Professor / Faculty'), findsOneWidget);
    });

    testWidgets('Renders 3 Metric Cards with counts and action badges', (tester) async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byType(TeacherMetricCard), findsNWidgets(3));

      // Metric 1: Counseling
      expect(find.text('Counseling'), findsWidgets);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget); // Action badge for pending counseling

      // Metric 2: Feedback
      expect(find.text('Feedback'), findsWidgets);
      expect(find.text('18'), findsOneWidget);

      // Metric 3: Classes
      expect(find.text('Classes'), findsWidgets);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('Renders Quick Actions bar with all 7 requested options', (tester) async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byType(TeacherQuickActions), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);

      // Verify all 7 action labels
      expect(find.text('Attendance'), findsWidgets);
      expect(find.text('Schedule'), findsWidgets);
      expect(find.text('Counseling'), findsWidgets);
      expect(find.text('Feedback'), findsWidgets);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Renders Time-Aware Classes and Start Attendance action', (tester) async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byType(TimeAwareClassesCard), findsOneWidget);
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text("Today · Oct 19, 2026"), findsOneWidget);

      // Classes details
      expect(find.text('Operating Systems'), findsWidgets);
      expect(find.text('Room 501'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      expect(find.text('Operating Systems Sessional'), findsWidgets);
      expect(find.text('Lab 2'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);

      // Start Attendance button
      expect(find.text('Start Attendance'), findsNWidgets(2));
      expect(find.text('End of scheduled classes'), findsOneWidget);
    });

    testWidgets('Renders Assigned Courses with code, title, credit, type, year, semester', (tester) async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      // Tap "Courses" in Quick Actions to open Assigned Curriculum Portfolio sheet
      await tester.ensureVisible(find.text('Courses'));
      await tester.tap(find.text('Courses'));
      await tester.pumpAndSettle();

      expect(find.text('Assigned Curriculum Portfolio'), findsOneWidget);
      expect(find.byType(AssignedCourseCard), findsNWidgets(2));

      // Course 1
      expect(find.text('CSE-3101'), findsWidgets);
      expect(find.text('3.0 Cr'), findsOneWidget);
      expect(find.text('THEORY'), findsOneWidget);
      expect(find.text('Y3 · S1'), findsWidgets);

      // Course 2
      expect(find.text('CSE-3102'), findsWidgets);
      expect(find.text('1.5 Cr'), findsOneWidget);
      expect(find.text('LAB'), findsOneWidget);
    });

    testWidgets('Toggles between Classes and Exams in time-aware card', (tester) async {
      const sampleExam = Exam(
        id: 'exam_cse3101',
        courseId: 'CSE-3101',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        title: 'Mid-Term: Operating Systems',
        examDate: 'Oct 19, 2026',
        startTime: '10:00',
        endTime: '12:00',
        room: 'Main Exam Hall A',
        year: 3,
        semester: 1,
      );

      final dataWithExam = TeacherDashboardData(
        teacherId: 'teacher_layek_uid',
        teacherName: 'Dr. Md. Abu Layek',
        email: 'layek@cse.jnu.ac.bd',
        role: UserRole.teacher,
        pendingCounselingCount: 4,
        feedbackCount: 18,
        classesTaughtCount: 12,
        assignedCourses: const [sampleCourse1, sampleCourse2],
        timeAwareClasses: const [sampleSlot1, sampleSlot2],
        timeAwareExams: const [sampleExam],
        isTomorrow: false,
        targetDateLabel: "Today · Oct 19, 2026",
        dayOfWeek: "SUNDAY",
      );

      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => dataWithExam);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      // Initially on Classes tab
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('Operating Systems'), findsWidgets);

      // Tap Exams toggle
      final examsTabFinder = find.descendant(
        of: find.byType(TimeAwareClassesCard),
        matching: find.text('Exams'),
      );
      await tester.tap(examsTabFinder);
      await tester.pumpAndSettle();

      // Now on Exams tab
      expect(find.text("Today's Exams"), findsOneWidget);
      expect(find.text('Mid-Term: Operating Systems'), findsOneWidget);
      expect(find.text('Main Exam Hall A'), findsOneWidget);
      expect(find.text('Invigilator Duty'), findsOneWidget);

      // Tap back to Classes toggle
      final classesTabFinder = find.descendant(
        of: find.byType(TimeAwareClassesCard),
        matching: find.text('Classes'),
      );
      await tester.tap(classesTabFinder);
      await tester.pumpAndSettle();
      expect(find.text("Today's Schedule"), findsOneWidget);
    });

    testWidgets('Renders empty state when classes list is empty', (tester) async {
      final emptyClassesData = TeacherDashboardData(
        teacherId: 'teacher_layek_uid',
        teacherName: 'Dr. Md. Abu Layek',
        email: 'layek@cse.jnu.ac.bd',
        role: UserRole.teacher,
        pendingCounselingCount: 0,
        feedbackCount: 0,
        classesTaughtCount: 0,
        assignedCourses: const [sampleCourse1],
        timeAwareClasses: const [],
        isTomorrow: true,
        targetDateLabel: "Tomorrow · Oct 20, 2026",
        dayOfWeek: "MONDAY",
      );

      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => emptyClassesData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text("Tomorrow's Schedule"), findsOneWidget);
      expect(find.text('Next-Day'), findsOneWidget);
      expect(find.text('No classes scheduled for tomorrow'), findsOneWidget);
    });

    testWidgets('Tapping avatar opens TeacherProfileDialog with details and sign out', (tester) async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      // Tap leading avatar (GestureDetector with CircleAvatar)
      await tester.tap(find.byType(CircleAvatar).first);
      await tester.pumpAndSettle();

      expect(find.byType(TeacherProfileDialog), findsOneWidget);
      expect(find.text('Computer Science & Engineering'), findsOneWidget);
      expect(find.text('2 Courses'), findsOneWidget);
      expect(find.text('Sign Out Faculty Session'), findsOneWidget);
    });

    testWidgets('Allows editing faculty profile name and phone number', (tester) async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(TeacherDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      // Open profile dialog
      await tester.tap(find.byType(CircleAvatar).first);
      await tester.pumpAndSettle();

      // Tap "Edit Info" button
      expect(find.text('Edit Info'), findsOneWidget);
      await tester.tap(find.text('Edit Info'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Faculty Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Contact Phone'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel to return to view
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Faculty Profile'), findsNothing);
      expect(find.text('Dr. Md. Abu Layek'), findsWidgets);
    });

    testWidgets('Renders Bottom Navigation Bar with all 5 destinations and triggers actions', (tester) async {
      when(() => mockTeacherRepo.getTeacherDashboardData(
            teacher: any(named: 'teacher'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = TeacherDashboardController(
        getTeacherDashboardDataUseCase: useCase,
        authController: mockAuthController,
      );
      await controller.loadDashboardData();

      await tester.pumpWidget(buildTestableWidget(
        TeacherDashboardScreen(
          controller: controller,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Attendance'), findsWidgets);
      expect(find.text('Schedule'), findsWidgets);
      expect(find.text('Counseling'), findsWidgets);
      expect(find.text('Feedback'), findsWidgets);

      // Tap Attendance in bottom nav -> opens TeacherAttendanceTerminalScreen
      final attendanceDestFinder = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Attendance'),
      );
      await tester.tap(attendanceDestFinder);
      await tester.pumpAndSettle();

      expect(find.byType(TeacherAttendanceTerminalScreen), findsOneWidget);

      // Pop back to dashboard
      final navigatorState = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigatorState.pop();
      await tester.pumpAndSettle();

      // Tap Schedule in bottom nav -> opens TeacherScheduleScreen
      final scheduleDestFinder = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Schedule'),
      );
      await tester.tap(scheduleDestFinder);
      await tester.pumpAndSettle();

      expect(find.byType(TeacherScheduleScreen), findsOneWidget);
    });
  });
}
