import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';
import 'package:cse_jnu_eduportal/app/router/app_router.dart';
import 'package:cse_jnu_eduportal/app/router/route_names.dart';
import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';

import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/usecases/signup_request_usecase.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';

import 'package:cse_jnu_eduportal/features/dashboard/presentation/screens/authenticated_app_shell.dart';
import 'package:cse_jnu_eduportal/features/profile/presentation/widgets/student_profile_dialog.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/widgets/teacher_profile_dialog.dart';

import 'package:cse_jnu_eduportal/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/screens/student_attendance_screen.dart';

import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/controllers/schedule_controller.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/screens/student_schedule_screen.dart';

import 'package:cse_jnu_eduportal/features/counseling/domain/repositories/counseling_repository.dart';
import 'package:cse_jnu_eduportal/features/counseling/presentation/controllers/counseling_controller.dart';

import 'package:cse_jnu_eduportal/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:cse_jnu_eduportal/features/feedback/presentation/controllers/feedback_controller.dart';

import 'package:cse_jnu_eduportal/features/profile/domain/repositories/semester_repository.dart';
import 'package:cse_jnu_eduportal/features/profile/presentation/controllers/profile_controller.dart';

import 'package:cse_jnu_eduportal/features/notifications/domain/entities/notification_entities.dart';
import 'package:cse_jnu_eduportal/features/notifications/domain/repositories/notification_repository.dart';
import 'package:cse_jnu_eduportal/features/notifications/presentation/controllers/notification_controller.dart';

import 'package:cse_jnu_eduportal/features/teacher/domain/entities/teacher_dashboard_data.dart';
import 'package:cse_jnu_eduportal/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:cse_jnu_eduportal/features/teacher/domain/usecases/get_teacher_dashboard_data_usecase.dart';
import 'package:cse_jnu_eduportal/features/teacher/presentation/controllers/teacher_dashboard_controller.dart';

import 'package:cse_jnu_eduportal/features/cr/domain/entities/cr_dashboard_data.dart';
import 'package:cse_jnu_eduportal/features/cr/domain/repositories/cr_repository.dart';
import 'package:cse_jnu_eduportal/features/cr/domain/usecases/get_cr_dashboard_data_usecase.dart';
import 'package:cse_jnu_eduportal/features/cr/domain/usecases/add_tomorrow_slot_usecase.dart';
import 'package:cse_jnu_eduportal/features/cr/presentation/controllers/cr_dashboard_controller.dart';

import 'package:cse_jnu_eduportal/features/admin/domain/entities/admin_stats.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/repositories/admin_repository.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/usecases/admin_usecases.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/controllers/admin_dashboard_controller.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/screens/admin_management_screens.dart';

class MockAuthController extends Mock implements AuthController {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockSignupRequestUseCase extends Mock implements SignupRequestUseCase {}
class MockAttendanceRepo extends Mock implements AttendanceRepository {}
class MockCurriculumRepo extends Mock implements CurriculumRepository {}
class MockCounselingRepo extends Mock implements CounselingRepository {}
class MockFeedbackRepo extends Mock implements FeedbackRepository {}
class MockSemesterRepo extends Mock implements SemesterRepository {}
class MockNotificationRepo extends Mock implements NotificationRepository {}
class MockTeacherRepo extends Mock implements TeacherRepository {}
class MockCrRepo extends Mock implements CrRepository {}
class MockAdminRepo extends Mock implements AdminRepository {}
class FakeUser extends Fake implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthController mockAuthController;
  late MockLocalStorageService mockStorage;
  late ValueNotifier<ThemeMode> themeModeNotifier;

  const studentUser = User(
    id: 'uid_student',
    email: 'student@cse.jnu.ac.bd',
    fullName: 'Student User',
    role: UserRole.student,
    studentId: 'B200305001',
    year: 3,
    semester: 1,
    isActive: true,
  );

  const teacherUser = User(
    id: 'uid_teacher',
    email: 'layek@cse.jnu.ac.bd',
    fullName: 'Dr. Md. Abu Layek',
    role: UserRole.teacher,
    phone: '+8801700000000',
    isActive: true,
  );

  const crUser = User(
    id: 'uid_cr',
    email: 'cr@cse.jnu.ac.bd',
    fullName: 'Class Representative',
    role: UserRole.cr,
    studentId: 'B200305002',
    year: 3,
    semester: 1,
    isActive: true,
  );

  const adminUser = User(
    id: 'uid_admin',
    email: 'admin@cse.jnu.ac.bd',
    fullName: 'System Administrator',
    role: UserRole.admin,
    isActive: true,
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(FakeUser());
  });

  setUp(() async {
    await sl.reset();
    mockAuthController = MockAuthController();
    mockStorage = MockLocalStorageService();
    themeModeNotifier = ValueNotifier(ThemeMode.light);

    when(() => mockAuthController.addListener(any())).thenReturn(null);
    when(() => mockAuthController.removeListener(any())).thenReturn(null);
    when(() => mockStorage.getThemeMode()).thenReturn('system');

    sl.registerLazySingleton<LocalStorageService>(() => mockStorage);
    sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: sl()));
    sl.registerLazySingleton<AuthController>(() => mockAuthController);
    sl.registerLazySingleton<SignupRequestUseCase>(() => MockSignupRequestUseCase());

    // Curriculum
    final currRepo = MockCurriculumRepo();
    when(() => currRepo.getSchedule()).thenAnswer((_) async => []);
    when(() => currRepo.getExams()).thenAnswer((_) async => []);
    sl.registerFactory<ScheduleController>(() => ScheduleController(
      getScheduleUseCase: GetScheduleUseCase(currRepo),
    ));
    sl.registerFactory<ExamsController>(() => ExamsController(
      getExamsUseCase: GetExamsUseCase(currRepo),
    ));

    // Attendance
    final attRepo = MockAttendanceRepo();
    sl.registerFactory<AttendanceController>(() => AttendanceController(
      getAttendanceSummaryUseCase: GetAttendanceSummaryUseCase(attRepo),
      verifyAttendanceCodeUseCase: VerifyAttendanceCodeUseCase(attRepo),
    ));

    // Counseling
    final counRepo = MockCounselingRepo();
    when(() => counRepo.getAvailableSlots(teacherId: any(named: 'teacherId'))).thenAnswer((_) async => []);
    when(() => counRepo.getMyBookings()).thenAnswer((_) async => []);
    sl.registerFactory<CounselingController>(() => CounselingController(
      getAvailableSlotsUseCase: GetAvailableSlotsUseCase(counRepo),
      requestBookingUseCase: RequestBookingUseCase(counRepo),
      getMyBookingsUseCase: GetMyBookingsUseCase(counRepo),
      cancelBookingUseCase: CancelBookingUseCase(counRepo),
    ));

    // Feedback
    final fbRepo = MockFeedbackRepo();
    sl.registerFactory<FeedbackController>(() => FeedbackController(
      submitFeedbackUseCase: SubmitFeedbackUseCase(fbRepo),
      getMyFeedbackUseCase: GetMyFeedbackUseCase(fbRepo),
    ));

    // Profile
    final semRepo = MockSemesterRepo();
    sl.registerFactory<ProfileController>(() => ProfileController(
      getSemesterStatusUseCase: GetSemesterStatusUseCase(semRepo),
      requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(semRepo),
    ));

    // Notifications
    final notifRepo = MockNotificationRepo();
    when(() => notifRepo.getNotifications()).thenAnswer((_) async => const NotificationFeed(notifications: [], unreadCount: 0));
    sl.registerFactory<NotificationController>(() => NotificationController(
      getNotificationsUseCase: GetNotificationsUseCase(notifRepo),
      markNotificationReadUseCase: MarkNotificationReadUseCase(notifRepo),
      markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(notifRepo),
    ));

    // Teacher Repo
    final teacherRepo = MockTeacherRepo();
    when(() => teacherRepo.getTeacherDashboardData(
      teacher: any(named: 'teacher'),
      currentTime: any(named: 'currentTime'),
    )).thenAnswer((_) async => const TeacherDashboardData(
      teacherId: 'uid_teacher',
      teacherName: 'Dr. Md. Abu Layek',
      email: 'layek@cse.jnu.ac.bd',
      role: UserRole.teacher,
      pendingCounselingCount: 2,
      feedbackCount: 5,
      classesTaughtCount: 14,
      assignedCourses: [],
      timeAwareClasses: [],
      isTomorrow: false,
      targetDateLabel: 'Today · Oct 19, 2026',
      dayOfWeek: 'MONDAY',
    ));
    sl.registerFactory<TeacherDashboardController>(() => TeacherDashboardController(
      getTeacherDashboardDataUseCase: GetTeacherDashboardDataUseCase(teacherRepo),
      authController: mockAuthController,
    ));

    // CR Repo
    final crRepo = MockCrRepo();
    when(() => crRepo.getCrDashboardData(
      crUser: any(named: 'crUser'),
      currentTime: any(named: 'currentTime'),
    )).thenAnswer((invocation) async {
      final user = invocation.namedArguments[#crUser] as User?;
      return CrDashboardData(
        crId: user?.id ?? 'uid_cr',
        crName: user?.fullName ?? 'Class Representative',
        email: user?.email ?? 'cr@cse.jnu.ac.bd',
        role: user?.role ?? UserRole.cr,
        year: user?.year ?? 3,
        semester: user?.semester ?? 1,
        attendancePercentage: 92.5,
        attendedClasses: 37,
        totalClasses: 40,
        isAttendanceEligible: true,
        classesTodayCount: 3,
        availableCounselingSlotsCount: 2,
        myActiveCounselingCount: 1,
        upcomingExamsCount: 1,
        targetDateLabel: 'Today · Oct 19, 2026',
        dayOfWeek: 'MONDAY',
        tomorrowDateLabel: 'Tomorrow · Oct 20, 2026',
      );
    });
    sl.registerFactory<CrDashboardController>(() => CrDashboardController(
      getCrDashboardDataUseCase: GetCrDashboardDataUseCase(crRepo),
      addTomorrowSlotUseCase: AddTomorrowSlotUseCase(crRepo),
      authController: mockAuthController,
    ));

    // Admin Repo
    final adminRepo = MockAdminRepo();
    when(() => adminRepo.getOverviewStats()).thenAnswer((_) async => const AdminOverviewStats());
    when(() => adminRepo.getPendingSignupRequests()).thenAnswer((_) async => []);
    when(() => adminRepo.getPendingSemesterRequests()).thenAnswer((_) async => []);
    when(() => adminRepo.getAllUsers(roleFilter: any(named: 'roleFilter'))).thenAnswer((_) async => []);
    when(() => adminRepo.getAllCourses()).thenAnswer((_) async => []);
    when(() => adminRepo.getAllCourseAssignments()).thenAnswer((_) async => []);
    sl.registerFactory<AdminDashboardController>(() => AdminDashboardController(
      getDataUseCase: GetAdminDashboardDataUseCase(adminRepo),
      approveSignupUseCase: ApproveSignupRequestUseCase(adminRepo),
      rejectSignupUseCase: RejectSignupRequestUseCase(adminRepo),
      approveSemesterUseCase: ApproveSemesterUpgradeUseCase(adminRepo),
      rejectSemesterUseCase: RejectSemesterUpgradeUseCase(adminRepo),
    ));
  });

  group('STAGE 19 — Authenticated App Shell Unification & Navigation Tests', () {
    testWidgets('1. Student Shell renders 5 role-specific bottom destinations and switches tabs', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: studentUser));
      when(() => mockAuthController.currentUser).thenReturn(studentUser);

      await tester.pumpWidget(MaterialApp(
        home: AuthenticatedAppShell(
          role: UserRole.student,
          authController: mockAuthController,
          themeModeNotifier: themeModeNotifier,
        ),
      ));
      await tester.pumpAndSettle();

      // Check header and branding
      expect(find.text('JnU EduPortal'), findsOneWidget);
      expect(find.textContaining('Student User'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verify all 5 Student bottom navigation destinations
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Attendance'), findsWidgets);
      expect(find.text('Schedule'), findsWidgets);
      expect(find.text('Counsel'), findsOneWidget);
      expect(find.text('Feedback'), findsWidgets);

      // Tap Attendance in bottom nav
      final attendanceTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Attendance'),
      );
      await tester.tap(attendanceTab);
      await tester.pumpAndSettle();

      // Verified attendance terminal view loaded
      expect(find.byType(StudentAttendanceScreen), findsOneWidget);

      // Tap Schedule in bottom nav
      final scheduleTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Schedule'),
      );
      await tester.tap(scheduleTab);
      await tester.pumpAndSettle();
      expect(find.byType(StudentScheduleScreen), findsOneWidget);
    });

    testWidgets('2. Teacher Shell renders Professor Dashboard and role-specific destinations', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: teacherUser));
      when(() => mockAuthController.currentUser).thenReturn(teacherUser);

      await tester.pumpWidget(MaterialApp(
        home: AuthenticatedAppShell(
          role: UserRole.teacher,
          authController: mockAuthController,
          themeModeNotifier: themeModeNotifier,
        ),
      ));
      await tester.pumpAndSettle();

      // Verifies Professor greeting and identity
      expect(find.textContaining('Dr. Md. Abu Layek'), findsOneWidget);
      expect(find.text('Professor / Faculty'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verifies 5 teacher destinations
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Attendance'), findsWidgets);
      expect(find.text('Schedule'), findsWidgets);
      expect(find.text('Counseling'), findsWidgets);
      expect(find.text('Feedback'), findsWidgets);
    });

    testWidgets('3. CR Shell renders Class Representative Dashboard with management hub', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: crUser));
      when(() => mockAuthController.currentUser).thenReturn(crUser);

      await tester.pumpWidget(MaterialApp(
        home: AuthenticatedAppShell(
          role: UserRole.cr,
          authController: mockAuthController,
          themeModeNotifier: themeModeNotifier,
        ),
      ));
      await tester.pumpAndSettle();

      // Verifies CR Greeting & Hub
      expect(find.text('Class Representative'), findsWidgets);
      expect(find.textContaining('Manage Tomorrow'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verifies 5 CR destinations
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Schedule'), findsWidgets);
      expect(find.text('Attendance'), findsWidgets);
      expect(find.text('Counseling'), findsWidgets);
      expect(find.text('Feedback'), findsWidgets);
    });

    testWidgets('4. Admin Shell renders Admin Console with 5 mobile navigation destinations', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: adminUser));
      when(() => mockAuthController.currentUser).thenReturn(adminUser);

      await tester.pumpWidget(MaterialApp(
        home: AuthenticatedAppShell(
          role: UserRole.admin,
          authController: mockAuthController,
          themeModeNotifier: themeModeNotifier,
        ),
      ));
      await tester.pumpAndSettle();

      // Verifies Admin Header & console
      expect(find.text('JnU EduPortal'), findsWidgets);
      expect(find.text('Administrator'), findsWidgets);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verifies 5 Admin destinations
      expect(find.text('Console'), findsOneWidget);
      expect(find.text('Users'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);

      // Tap Users tab
      final usersTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Users'),
      );
      await tester.tap(usersTab);
      await tester.pumpAndSettle();
      expect(find.byType(AdminUserDirectoryScreen), findsOneWidget);
    });

    testWidgets('5. Profile menu opens on avatar tap with details and sign out; App Settings & Preferences is totally removed', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: studentUser));
      when(() => mockAuthController.currentUser).thenReturn(studentUser);

      await tester.pumpWidget(MaterialApp(
        home: AuthenticatedAppShell(
          role: UserRole.student,
          authController: mockAuthController,
          themeModeNotifier: themeModeNotifier,
        ),
      ));
      await tester.pumpAndSettle();

      // Top bar no longer contains Settings icon
      expect(find.byTooltip('Settings'), findsNothing);

      // Tap profile avatar in top bar
      final avatar = find.byType(CircleAvatar).first;
      await tester.tap(avatar);
      await tester.pumpAndSettle();

      // Profile dialog appears with unified menu layout
      expect(find.byType(StudentProfileDialog), findsOneWidget);
      expect(find.text('Computer Science & Engineering'), findsOneWidget);
      expect(find.text('Year 3, Semester 1'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);

      // App Settings & Preferences is completely removed for all users
      expect(find.text('App Settings & Preferences'), findsNothing);

      // Sign Out button is present directly in the profile menu
      await tester.scrollUntilVisible(
        find.text('Sign Out Student Session'),
        100,
        scrollable: find.descendant(of: find.byType(StudentProfileDialog), matching: find.byType(Scrollable)).first,
      );
      expect(find.text('Sign Out Student Session'), findsOneWidget);
    });

    testWidgets('5b. Admin avatar tap opens unified profile menu without App Settings & Preferences', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: adminUser));
      when(() => mockAuthController.currentUser).thenReturn(adminUser);

      await tester.pumpWidget(MaterialApp(
        home: AuthenticatedAppShell(
          role: UserRole.admin,
          authController: mockAuthController,
          themeModeNotifier: themeModeNotifier,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap profile avatar in top bar
      final avatar = find.byType(CircleAvatar).first;
      await tester.tap(avatar);
      await tester.pumpAndSettle();

      // Admin profile dialog appears with unified menu layout
      expect(find.byType(TeacherProfileDialog), findsOneWidget);
      expect(find.text('Computer Science & Engineering'), findsOneWidget);
      expect(find.text('Full System Control'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);

      // App Settings & Preferences is completely removed
      expect(find.text('App Settings & Preferences'), findsNothing);

      // Sign Out Admin Session is present
      await tester.scrollUntilVisible(
        find.text('Sign Out Admin Session'),
        100,
        scrollable: find.descendant(of: find.byType(TeacherProfileDialog), matching: find.byType(Scrollable)).first,
      );
      expect(find.text('Sign Out Admin Session'), findsOneWidget);
    });

    testWidgets('6. Sign Out action prompts AppConfirmationDialog and completes logout', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: studentUser));
      when(() => mockAuthController.currentUser).thenReturn(studentUser);
      when(() => mockAuthController.logout()).thenAnswer((_) async {});

      final router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.studentDashboard,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Find Sign Out icon button
      final signOutBtn = find.byTooltip('Sign Out');
      expect(signOutBtn, findsOneWidget);

      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog displayed
      expect(find.text('Sign Out?'), findsOneWidget);
      expect(find.text('Sign Out'), findsWidgets);

      // Tap confirm button
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Sign Out');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Logout executed
      verify(() => mockAuthController.logout()).called(1);
    });

    testWidgets('7. PopScope back navigation returns to Home Tab (index 0) from any sub-tab', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: studentUser));
      when(() => mockAuthController.currentUser).thenReturn(studentUser);

      await tester.pumpWidget(MaterialApp(
        home: AuthenticatedAppShell(
          role: UserRole.student,
          authController: mockAuthController,
          themeModeNotifier: themeModeNotifier,
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to Attendance (Tab 1)
      final attendanceTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Attendance'),
      );
      await tester.tap(attendanceTab);
      await tester.pumpAndSettle();

      expect(find.byType(StudentAttendanceScreen), findsOneWidget);

      // Simulate Android back button invocation
      final popScope = tester.widget<PopScope>(find.byWidgetPredicate((w) => w is PopScope).first);
      popScope.onPopInvokedWithResult?.call(false, null);
      await tester.pumpAndSettle();

      // Returned to Home Tab
      expect(find.byType(StudentAttendanceScreen), findsNothing);
      expect(find.text("Today's Schedule"), findsOneWidget);
    });

    testWidgets('8. Session restoration correctly enters authoritative dashboard for all 4 roles', (tester) async {
      // Test Student entry
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: studentUser));
      when(() => mockAuthController.currentUser).thenReturn(studentUser);

      var router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.login,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text("Today's Schedule"), findsOneWidget);

      // Test Teacher entry
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: teacherUser));
      when(() => mockAuthController.currentUser).thenReturn(teacherUser);

      router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.login,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Professor / Faculty'), findsWidgets);

      // Test CR entry
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: crUser));
      when(() => mockAuthController.currentUser).thenReturn(crUser);

      router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.login,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Class Representative'), findsWidgets);

      // Test Admin entry
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: adminUser));
      when(() => mockAuthController.currentUser).thenReturn(adminUser);

      router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.login,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Administrator'), findsWidgets);
      expect(find.text('Console'), findsWidgets);
    });
  });
}
