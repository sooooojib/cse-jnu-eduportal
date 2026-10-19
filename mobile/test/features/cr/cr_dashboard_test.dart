import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';
import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';
import 'package:cse_jnu_eduportal/features/counseling/domain/entities/counseling_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';

import 'package:cse_jnu_eduportal/features/cr/domain/entities/cr_dashboard_data.dart';
import 'package:cse_jnu_eduportal/features/cr/domain/repositories/cr_repository.dart';
import 'package:cse_jnu_eduportal/features/cr/domain/usecases/add_tomorrow_slot_usecase.dart';
import 'package:cse_jnu_eduportal/features/cr/domain/usecases/get_cr_dashboard_data_usecase.dart';
import 'package:cse_jnu_eduportal/features/cr/presentation/controllers/cr_dashboard_controller.dart';
import 'package:cse_jnu_eduportal/features/cr/presentation/controllers/cr_dashboard_state.dart';
import 'package:cse_jnu_eduportal/features/cr/presentation/screens/cr_dashboard_screen.dart';
import 'package:cse_jnu_eduportal/features/cr/presentation/widgets/cr_metric_card.dart';
import 'package:cse_jnu_eduportal/features/cr/presentation/widgets/cr_quick_actions_bar.dart';

class MockCrRepository extends Mock implements CrRepository {}
class MockAuthController extends Mock implements AuthController {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class FakeUser extends Fake implements User {}
class FakeScheduleSlot extends Fake implements ScheduleSlot {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCrRepository mockCrRepo;
  late MockAuthController mockAuthController;
  late MockLocalStorageService mockLocalStorageService;
  late GetCrDashboardDataUseCase getDataUseCase;
  late AddTomorrowSlotUseCase addSlotUseCase;

  const sampleCr = User(
    id: 'cr_sajib_uid',
    email: 'sajib.cr@cse.jnu.ac.bd',
    fullName: 'Sajib Ahmed',
    role: UserRole.cr,
    phone: '+8801700000000',
    studentId: '2022CSE001',
    year: 3,
    semester: 1,
  );

  const sampleCourse1 = Course(
    id: 'CSE-3101',
    code: 'CSE-3101',
    title: 'Data Structures & Algorithms',
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
    title: 'Database Management Lab',
    credit: 1.5,
    year: 3,
    semester: 1,
    courseType: 'LAB',
    teacherId: 'teacher_uzzal_uid',
    teacherName: 'Dr. Uzzal Kumar Acharjee',
  );

  const sampleSlot1 = ScheduleSlot(
    id: 'slot_1',
    courseId: 'CSE-3101',
    courseCode: 'CSE-3101',
    courseTitle: 'Data Structures & Algorithms',
    teacherId: 'teacher_layek_uid',
    teacherName: 'Dr. Md. Abu Layek',
    dayOfWeek: 'MONDAY',
    startTime: '09:00 AM',
    endTime: '10:30 AM',
    room: 'Room 302, Block A',
    targetYear: 3,
    targetSemester: 1,
    isExtraClass: false,
  );

  const sampleSlot2 = ScheduleSlot(
    id: 'slot_2',
    courseId: 'CSE-3102',
    courseCode: 'CSE-3102',
    courseTitle: 'Database Management Lab',
    teacherId: 'teacher_uzzal_uid',
    teacherName: 'Dr. Uzzal Kumar Acharjee',
    dayOfWeek: 'MONDAY',
    startTime: '11:30 AM',
    endTime: '01:00 PM',
    room: 'Lab 4, Block C',
    targetYear: 3,
    targetSemester: 1,
    isExtraClass: false,
  );

  const sampleTomorrowSlot = ScheduleSlot(
    id: 'slot_tomorrow_1',
    courseId: 'CSE-3101',
    courseCode: 'CSE-3101',
    courseTitle: 'Data Structures & Algorithms',
    teacherId: 'teacher_layek_uid',
    teacherName: 'Dr. Md. Abu Layek',
    dayOfWeek: 'TUESDAY',
    startTime: '10:00 AM',
    endTime: '11:30 AM',
    room: 'Room 204, Block B',
    targetYear: 3,
    targetSemester: 1,
    isExtraClass: true,
  );

  const sampleExam1 = Exam(
    id: 'exam_1',
    courseId: 'CSE-3101',
    courseCode: 'CSE-3101',
    courseTitle: 'Data Structures & Algorithms',
    title: 'Data Structures Midterm',
    examDate: '2026-11-15',
    startTime: '10:00 AM',
    endTime: '12:00 PM',
    room: 'Auditorium A',
    year: 3,
    semester: 1,
  );

  final sampleDashboardData = CrDashboardData(
    crId: sampleCr.id,
    crName: sampleCr.fullName,
    email: sampleCr.email,
    phone: sampleCr.phone,
    role: UserRole.cr,
    year: 3,
    semester: 1,
    studentId: '2022CSE001',
    semesterStatus: 'APPROVED',
    attendancePercentage: 94.2,
    attendedClasses: 32,
    totalClasses: 34,
    isAttendanceEligible: true,
    courseAttendances: const [
      CourseAttendance(
        courseId: 'CSE-3101',
        courseCode: 'CSE-3101',
        courseTitle: 'Data Structures & Algorithms',
        attendedClasses: 19,
        totalClasses: 20,
        percentage: 95.0,
        isEligible: true,
      ),
      CourseAttendance(
        courseId: 'CSE-3102',
        courseCode: 'CSE-3102',
        courseTitle: 'Database Management Lab',
        attendedClasses: 13,
        totalClasses: 14,
        percentage: 92.8,
        isEligible: true,
      ),
    ],
    classesTodayCount: 2,
    todayClasses: const [sampleSlot1, sampleSlot2],
    tomorrowClasses: const [sampleTomorrowSlot],
    availableCounselingSlotsCount: 5,
    myActiveCounselingCount: 1,
    myBookings: const [
      CounselingBooking(
        id: 'booking_1',
        slotId: 'slot_c_1',
        studentId: 'cr_sajib_uid',
        studentName: 'Sajib Ahmed',
        teacherId: 'teacher_layek_uid',
        teacherName: 'Dr. Md. Abu Layek',
        category: 'ACADEMIC_ADVISING',
        notes: 'Discussion on algorithm project',
        status: 'PENDING',
        slotDate: '2026-10-25',
        startTime: '02:00 PM',
        endTime: '03:00 PM',
        createdAt: '2026-10-19T00:00:00Z',
      ),
    ],
    upcomingExamsCount: 1,
    upcomingExams: const [sampleExam1],
    enrolledCourses: const [sampleCourse1, sampleCourse2],
    targetDateLabel: 'Monday · Oct 19, 2026',
    dayOfWeek: 'MONDAY',
    tomorrowDateLabel: 'Tuesday · Oct 20, 2026',
  );

  setUpAll(() {
    registerFallbackValue(FakeUser());
    registerFallbackValue(FakeScheduleSlot());
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    mockCrRepo = MockCrRepository();
    mockAuthController = MockAuthController();
    mockLocalStorageService = MockLocalStorageService();
    getDataUseCase = GetCrDashboardDataUseCase(mockCrRepo);
    addSlotUseCase = AddTomorrowSlotUseCase(mockCrRepo);

    when(() => mockAuthController.state).thenReturn(const Authenticated(user: sampleCr));

    if (sl.isRegistered<AuthController>()) {
      sl.unregister<AuthController>();
    }
    sl.registerLazySingleton<AuthController>(() => mockAuthController);

    if (sl.isRegistered<ThemeController>()) {
      sl.unregister<ThemeController>();
    }
    when(() => mockLocalStorageService.getThemeMode()).thenReturn('light');
    sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: mockLocalStorageService));
  });

  tearDown(() {
    if (sl.isRegistered<AuthController>()) {
      sl.unregister<AuthController>();
    }
    if (sl.isRegistered<ThemeController>()) {
      sl.unregister<ThemeController>();
    }
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: child,
    );
  }

  group('CR Dashboard Domain & Data Tests', () {
    test('CrDashboardData holds exact properties and supports equality', () {
      expect(sampleDashboardData.crName, 'Sajib Ahmed');
      expect(sampleDashboardData.attendancePercentage, 94.2);
      expect(sampleDashboardData.classesTodayCount, 2);
      expect(sampleDashboardData.availableCounselingSlotsCount, 5);
      expect(sampleDashboardData.upcomingExamsCount, 1);
      expect(sampleDashboardData.tomorrowClasses.length, 1);
      expect(sampleDashboardData.isAttendanceEligible, isTrue);

      final duplicate = CrDashboardData(
        crId: sampleCr.id,
        crName: sampleCr.fullName,
        email: sampleCr.email,
        phone: sampleCr.phone,
        role: UserRole.cr,
        year: 3,
        semester: 1,
        studentId: '2022CSE001',
        semesterStatus: 'APPROVED',
        attendancePercentage: 94.2,
        attendedClasses: 32,
        totalClasses: 34,
        isAttendanceEligible: true,
        courseAttendances: sampleDashboardData.courseAttendances,
        classesTodayCount: 2,
        todayClasses: sampleDashboardData.todayClasses,
        tomorrowClasses: sampleDashboardData.tomorrowClasses,
        availableCounselingSlotsCount: 5,
        myActiveCounselingCount: 1,
        myBookings: sampleDashboardData.myBookings,
        upcomingExamsCount: 1,
        upcomingExams: sampleDashboardData.upcomingExams,
        enrolledCourses: sampleDashboardData.enrolledCourses,
        targetDateLabel: 'Monday · Oct 19, 2026',
        dayOfWeek: 'MONDAY',
        tomorrowDateLabel: 'Tuesday · Oct 20, 2026',
      );

      expect(sampleDashboardData, equals(duplicate));
    });

    test('GetCrDashboardDataUseCase executes successfully', () async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final result = await getDataUseCase.execute(crUser: sampleCr);

      expect(result.crName, 'Sajib Ahmed');
      expect(result.classesTodayCount, 2);
      verify(() => mockCrRepo.getCrDashboardData(crUser: sampleCr)).called(1);
    });

    test('AddTomorrowSlotUseCase delegates to repository', () async {
      when(() => mockCrRepo.addTomorrowClassSlot(
            crUser: any(named: 'crUser'),
            slot: any(named: 'slot'),
          )).thenAnswer((_) async => {});

      await addSlotUseCase.execute(crUser: sampleCr, slot: sampleTomorrowSlot);

      verify(() => mockCrRepo.addTomorrowClassSlot(
            crUser: sampleCr,
            slot: sampleTomorrowSlot,
          )).called(1);
    });
  });

  group('CR Dashboard Controller Tests', () {
    test('CrDashboardController loads data and emits CrDashboardLoaded state', () async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      expect(controller.value, isA<CrDashboardInitial>());

      final future = controller.loadDashboardData();
      expect(controller.value, isA<CrDashboardLoading>());

      await future;

      expect(controller.value, isA<CrDashboardLoaded>());
      final loadedState = controller.value as CrDashboardLoaded;
      expect(loadedState.data.attendancePercentage, 94.2);
      expect(loadedState.data.classesTodayCount, 2);
    });

    test('CrDashboardController emits CrDashboardError when repo throws', () async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenThrow(Exception('Firestore connection failure'));

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await controller.loadDashboardData();

      expect(controller.value, isA<CrDashboardError>());
      final errorState = controller.value as CrDashboardError;
      expect(errorState.message, contains('Firestore connection failure'));
    });

    test('CrDashboardController emits CrDashboardError when unauthenticated', () async {
      when(() => mockAuthController.state).thenReturn(const Unauthenticated());

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await controller.loadDashboardData();

      expect(controller.value, isA<CrDashboardError>());
      final errorState = controller.value as CrDashboardError;
      expect(errorState.message, contains('Not authenticated'));
    });

    test('CrDashboardController addTomorrowSlot calls usecase and refreshes', () async {
      when(() => mockCrRepo.addTomorrowClassSlot(
            crUser: any(named: 'crUser'),
            slot: any(named: 'slot'),
          )).thenAnswer((_) async => {});

      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      final success = await controller.addTomorrowSlot(sampleTomorrowSlot);
      expect(success, isTrue);

      verify(() => mockCrRepo.addTomorrowClassSlot(
            crUser: sampleCr,
            slot: sampleTomorrowSlot,
          )).called(1);
    });
  });

  group('CR Dashboard Screen & Widget Tests', () {
    testWidgets('Renders loading state properly', (tester) async {
      final completer = Completer<CrDashboardData>();
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) => completer.future);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pump();

      expect(find.text('Loading Class Representative Dashboard...'), findsOneWidget);

      completer.complete(sampleDashboardData);
      await tester.pumpAndSettle();
    });

    testWidgets('Renders error state and clicking retry reloads dashboard', (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenThrow(Exception('Timeout loading schedule'));

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load CR Dashboard'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('CR Dashboard'), findsOneWidget);
    });

    testWidgets('Renders CR Identity, Active Semester, and Greeting Header', (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      // Top App Bar
      expect(find.text('JnU EduPortal'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      // Header
      expect(find.text('CR Dashboard'), findsOneWidget);
      expect(find.text('Class Representative'), findsOneWidget);
      expect(find.text('Welcome back, Sajib Ahmed.'), findsOneWidget);

      // Semester Box
      expect(find.text('Active Semester'), findsOneWidget);
      expect(find.text('Year 3 · Semester 1'), findsOneWidget);
      expect(find.text('Request Change'), findsOneWidget);
    });

    testWidgets('Renders 4 Bento Metric Cards with counts and badges', (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byType(CrMetricCard), findsNWidgets(4));

      // Metric 1: Attendance
      expect(find.text('My Attendance'), findsOneWidget);
      expect(find.text('94.2%'), findsOneWidget);
      expect(find.text('Eligible'), findsOneWidget);

      // Metric 2: Classes Today
      expect(find.text('Classes Today'), findsOneWidget);
      expect(find.text('2 Slots'), findsOneWidget);

      // Metric 3: Counseling
      expect(find.text('Counseling Slots'), findsOneWidget);
      expect(find.text('5 Available'), findsOneWidget);
      expect(find.text('1 Booked'), findsOneWidget);

      // Metric 4: Upcoming Exams
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('1 Exams'), findsOneWidget);
      expect(find.text('Term Exam'), findsOneWidget);
    });

    testWidgets('Renders Manage Tomorrow Schedule card and Broadcast dialog', (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text("Manage Tomorrow's Schedule"), findsOneWidget);
      expect(find.text('Broadcast'), findsOneWidget);
      expect(find.text('Add Class Slot'), findsOneWidget);

      // Tap Broadcast on WhatsApp
      await tester.ensureVisible(find.text('Broadcast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Broadcast'));
      await tester.pumpAndSettle();

      expect(find.text('WhatsApp Broadcast'), findsOneWidget);
      expect(find.text('Copy Message'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping Add Class Slot opens CrAddSlotDialog', (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add Class Slot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Class Slot'));
      await tester.pumpAndSettle();

      expect(find.text('Add Class for Tomorrow'), findsOneWidget);
      expect(find.text('Save Class Slot'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets("Renders Today's Schedule timeline with slots", (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('CSE-3101: Data Structures & Algorithms'), findsOneWidget);
      expect(find.text('CSE-3102: Database Management Lab'), findsOneWidget);
      expect(find.text('09:00 AM'), findsOneWidget);
      expect(find.text('Room 302, Block A'), findsOneWidget);
      expect(find.text('Lab 4, Block C'), findsOneWidget);
      expect(find.text('Theory'), findsOneWidget);
      expect(find.text('Lab'), findsOneWidget);
    });

    testWidgets("Renders empty state when today has no classes", (tester) async {
      final emptyTodayData = CrDashboardData(
        crId: sampleCr.id,
        crName: sampleCr.fullName,
        email: sampleCr.email,
        phone: sampleCr.phone,
        role: UserRole.cr,
        year: 3,
        semester: 1,
        studentId: '2022CSE001',
        attendancePercentage: 0.0,
        attendedClasses: 0,
        totalClasses: 0,
        isAttendanceEligible: true,
        classesTodayCount: 0,
        todayClasses: const [],
        tomorrowClasses: const [],
        availableCounselingSlotsCount: 0,
        myActiveCounselingCount: 0,
        upcomingExamsCount: 0,
        enrolledCourses: const [],
        targetDateLabel: 'Sunday · Oct 18, 2026',
        dayOfWeek: 'SUNDAY',
        tomorrowDateLabel: 'Monday · Oct 19, 2026',
      );

      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => emptyTodayData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('No classes scheduled for today'), findsOneWidget);
    });

    testWidgets('Renders Semester Courses with attendance percentages', (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.text('Semester Courses'), findsOneWidget);
      expect(find.text('CSE-3101 · Data Structures & Algorithms'), findsOneWidget);
      expect(find.text('95%'), findsOneWidget);
      expect(find.text('CSE-3102 · Database Management Lab'), findsOneWidget);
      expect(find.text('93%'), findsOneWidget);
    });

    testWidgets('Older redundant Quick Actions menu with errors is removed from CR Dashboard', (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byType(CrQuickActionsBar), findsNothing);
      expect(find.text('Student View'), findsNothing);
    });

    testWidgets('Tapping Upcoming Exams metric opens exams bottom sheet', (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming Exams (1)'), findsOneWidget);
      expect(find.text('CSE-3101: Data Structures Midterm'), findsOneWidget);
      expect(find.text('Date: 2026-11-15 · 10:00 AM - 12:00 PM (Auditorium A)'), findsOneWidget);
      expect(find.text('Sem 1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('Renders Bottom Navigation Bar with 5 destinations', (tester) async {
      when(() => mockCrRepo.getCrDashboardData(
            crUser: any(named: 'crUser'),
            currentTime: any(named: 'currentTime'),
          )).thenAnswer((_) async => sampleDashboardData);

      final controller = CrDashboardController(
        getCrDashboardDataUseCase: getDataUseCase,
        addTomorrowSlotUseCase: addSlotUseCase,
        authController: mockAuthController,
      );

      await tester.pumpWidget(buildTestableWidget(CrDashboardScreen(controller: controller)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Attendance'), findsWidgets);
      expect(find.text('Schedule'), findsWidgets);
      expect(find.text('Counseling'), findsWidgets);
      expect(find.text('Feedback'), findsWidgets);
    });
  });
}
