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
import 'package:cse_jnu_eduportal/features/auth/domain/entities/signup_request.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/usecases/signup_request_usecase.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';

import 'package:cse_jnu_eduportal/features/profile/domain/entities/semester_status.dart';
import 'package:cse_jnu_eduportal/features/profile/domain/repositories/semester_repository.dart';
import 'package:cse_jnu_eduportal/features/profile/presentation/controllers/profile_controller.dart';

import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/controllers/schedule_controller.dart';

import 'package:cse_jnu_eduportal/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/controllers/attendance_controller.dart';

import 'package:cse_jnu_eduportal/features/counseling/domain/repositories/counseling_repository.dart';
import 'package:cse_jnu_eduportal/features/counseling/presentation/controllers/counseling_controller.dart';

import 'package:cse_jnu_eduportal/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:cse_jnu_eduportal/features/feedback/presentation/controllers/feedback_controller.dart';

import 'package:cse_jnu_eduportal/features/notifications/domain/repositories/notification_repository.dart';
import 'package:cse_jnu_eduportal/features/notifications/presentation/controllers/notification_controller.dart';

import 'package:cse_jnu_eduportal/features/admin/domain/entities/admin_stats.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/repositories/admin_repository.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/usecases/admin_usecases.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/controllers/admin_dashboard_controller.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/widgets/admin_pending_signups_card.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/widgets/admin_pending_semester_card.dart';

class MockAdminRepository extends Mock implements AdminRepository {}
class MockAuthController extends Mock implements AuthController {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockSignupRequestUseCase extends Mock implements SignupRequestUseCase {}

class MockCurriculumRepo extends Mock implements CurriculumRepository {}
class MockAttendanceRepo extends Mock implements AttendanceRepository {}
class MockCounselingRepo extends Mock implements CounselingRepository {}
class MockFeedbackRepo extends Mock implements FeedbackRepository {}
class MockSemesterRepo extends Mock implements SemesterRepository {}
class MockNotificationRepo extends Mock implements NotificationRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAdminRepository mockAdminRepo;
  late MockAuthController mockAuthController;
  late MockLocalStorageService mockLocalStorageService;
  late MockSignupRequestUseCase mockSignupRequestUseCase;
  late ValueNotifier<ThemeMode> themeModeNotifier;

  const adminUser = User(
    id: 'uid_admin_1',
    email: 'admin@cse.jnu.ac.bd',
    fullName: 'Chief Administrator',
    role: UserRole.admin,
  );

  const studentUser = User(
    id: 'uid_student_1',
    email: 'student@cse.jnu.ac.bd',
    fullName: 'Student User',
    role: UserRole.student,
  );

  const sampleStats = AdminOverviewStats(
    totalStudents: 142,
    totalTeachers: 17,
    totalCrs: 8,
    totalCourses: 32,
    pendingSignups: 3,
    pendingSemesterRequests: 2,
    activeSessions: 1,
  );

  final sampleSignups = [
    const SignupRequest(
      id: 'req_1',
      email: 'applicant1@cse.jnu.ac.bd',
      fullName: 'Tanvir Ahmed',
      role: UserRole.student,
      studentId: '2023CSE012',
      status: 'PENDING',
      createdAt: '2026-10-01T10:00:00Z',
    ),
    const SignupRequest(
      id: 'req_2',
      email: 'faculty_applicant@cse.jnu.ac.bd',
      fullName: 'Dr. Kamal Hossain',
      role: UserRole.teacher,
      phone: '+8801700000000',
      status: 'PENDING',
      createdAt: '2026-10-01T11:00:00Z',
    ),
  ];

  final sampleSemesterRequests = [
    const SemesterUpgradeRequest(
      id: 'sem_1',
      studentId: 'uid_student_45',
      studentName: 'Nusrat Jahan',
      studentRoll: '2022CSE045',
      currentYear: 2,
      currentSemester: 2,
      requestedYear: 3,
      requestedSemester: 1,
      status: 'PENDING',
      createdAt: '2026-10-01T08:00:00Z',
    ),
  ];

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    mockAdminRepo = MockAdminRepository();
    mockAuthController = MockAuthController();
    mockLocalStorageService = MockLocalStorageService();
    mockSignupRequestUseCase = MockSignupRequestUseCase();
    themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

    when(() => mockAuthController.addListener(any())).thenReturn(null);
    when(() => mockAuthController.removeListener(any())).thenReturn(null);
    when(() => mockAuthController.state).thenReturn(const Authenticated(user: adminUser));
    when(() => mockAuthController.currentUser).thenReturn(adminUser);
    when(() => mockLocalStorageService.getThemeMode()).thenReturn('system');

    await sl.reset();
    sl.registerLazySingleton<LocalStorageService>(() => mockLocalStorageService);
    sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: sl()));
    sl.registerLazySingleton<SignupRequestUseCase>(() => mockSignupRequestUseCase);
    sl.registerLazySingleton<AuthController>(() => mockAuthController);
    sl.registerLazySingleton<AdminRepository>(() => mockAdminRepo);

    // Register controllers for scaffold tabs when testing redirection
    final curRepo = MockCurriculumRepo();
    when(() => curRepo.getSchedule()).thenAnswer((_) async => []);
    when(() => curRepo.getExams()).thenAnswer((_) async => []);
    when(() => curRepo.getMyCourses()).thenAnswer((_) async => []);
    sl.registerFactory<ScheduleController>(() => ScheduleController(getScheduleUseCase: GetScheduleUseCase(curRepo)));
    sl.registerFactory<ExamsController>(() => ExamsController(getExamsUseCase: GetExamsUseCase(curRepo)));

    final attRepo = MockAttendanceRepo();
    sl.registerFactory<AttendanceController>(() => AttendanceController(
      getAttendanceSummaryUseCase: GetAttendanceSummaryUseCase(attRepo),
      verifyAttendanceCodeUseCase: VerifyAttendanceCodeUseCase(attRepo),
    ));

    final counRepo = MockCounselingRepo();
    sl.registerFactory<CounselingController>(() => CounselingController(
      getAvailableSlotsUseCase: GetAvailableSlotsUseCase(counRepo),
      requestBookingUseCase: RequestBookingUseCase(counRepo),
      getMyBookingsUseCase: GetMyBookingsUseCase(counRepo),
      cancelBookingUseCase: CancelBookingUseCase(counRepo),
    ));

    final fbRepo = MockFeedbackRepo();
    sl.registerFactory<FeedbackController>(() => FeedbackController(
      submitFeedbackUseCase: SubmitFeedbackUseCase(fbRepo),
      getMyFeedbackUseCase: GetMyFeedbackUseCase(fbRepo),
    ));

    final semRepo = MockSemesterRepo();
    sl.registerFactory<ProfileController>(() => ProfileController(
      getSemesterStatusUseCase: GetSemesterStatusUseCase(semRepo),
      requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(semRepo),
    ));

    final notifRepo = MockNotificationRepo();
    sl.registerFactory<NotificationController>(() => NotificationController(
      getNotificationsUseCase: GetNotificationsUseCase(notifRepo),
      markNotificationReadUseCase: MarkNotificationReadUseCase(notifRepo),
      markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(notifRepo),
    ));
  });

  AdminDashboardController createTestController({
    AdminOverviewStats? stats,
    List<SignupRequest>? signups,
    List<SemesterUpgradeRequest>? semesterRequests,
    Exception? errorToThrow,
  }) {
    if (errorToThrow != null) {
      when(() => mockAdminRepo.getOverviewStats()).thenThrow(errorToThrow);
      when(() => mockAdminRepo.getPendingSignupRequests()).thenThrow(errorToThrow);
      when(() => mockAdminRepo.getPendingSemesterRequests()).thenThrow(errorToThrow);
    } else {
      when(() => mockAdminRepo.getOverviewStats()).thenAnswer((_) async => stats ?? sampleStats);
      when(() => mockAdminRepo.getPendingSignupRequests()).thenAnswer((_) async => signups ?? sampleSignups);
      when(() => mockAdminRepo.getPendingSemesterRequests()).thenAnswer((_) async => semesterRequests ?? sampleSemesterRequests);
    }

    when(() => mockAdminRepo.approveSignup(
      requestId: any(named: 'requestId'),
      assignedYear: any(named: 'assignedYear'),
      assignedSemester: any(named: 'assignedSemester'),
    )).thenAnswer((_) async {});

    when(() => mockAdminRepo.rejectSignup(
      requestId: any(named: 'requestId'),
      reason: any(named: 'reason'),
    )).thenAnswer((_) async {});

    when(() => mockAdminRepo.approveSemesterUpgrade(
      requestId: any(named: 'requestId'),
    )).thenAnswer((_) async {});

    when(() => mockAdminRepo.rejectSemesterUpgrade(
      requestId: any(named: 'requestId'),
      reason: any(named: 'reason'),
    )).thenAnswer((_) async {});

    return AdminDashboardController(
      getDataUseCase: GetAdminDashboardDataUseCase(mockAdminRepo),
      approveSignupUseCase: ApproveSignupRequestUseCase(mockAdminRepo),
      rejectSignupUseCase: RejectSignupRequestUseCase(mockAdminRepo),
      approveSemesterUseCase: ApproveSemesterUpgradeUseCase(mockAdminRepo),
      rejectSemesterUseCase: RejectSemesterUpgradeUseCase(mockAdminRepo),
    );
  }

  Widget createTestApp(AdminDashboardController controller) {
    return MaterialApp(
      home: AdminDashboardScreen(
        controller: controller,
        authController: mockAuthController,
      ),
    );
  }

  group('Stage 15: Admin Dashboard Presentation & Logic Tests', () {
    testWidgets('1. Dashboard Loading state renders indicator', (tester) async {
      when(() => mockAdminRepo.getOverviewStats()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        return sampleStats;
      });
      when(() => mockAdminRepo.getPendingSignupRequests()).thenAnswer((_) async => []);
      when(() => mockAdminRepo.getPendingSemesterRequests()).thenAnswer((_) async => []);

      final controller = AdminDashboardController(
        getDataUseCase: GetAdminDashboardDataUseCase(mockAdminRepo),
        approveSignupUseCase: ApproveSignupRequestUseCase(mockAdminRepo),
        rejectSignupUseCase: RejectSignupRequestUseCase(mockAdminRepo),
        approveSemesterUseCase: ApproveSemesterUpgradeUseCase(mockAdminRepo),
        rejectSemesterUseCase: RejectSemesterUpgradeUseCase(mockAdminRepo),
      );

      await tester.pumpWidget(createTestApp(controller));
      expect(find.text('Loading Department Administration...'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Loading Department Administration...'), findsNothing);
    });

    testWidgets('2. Successful data loading displays overview metrics & admin credentials', (tester) async {
      final controller = createTestController();

      await tester.pumpWidget(createTestApp(controller));
      await tester.pumpAndSettle();

      // Header checks
      expect(find.text('Admin Console'), findsOneWidget);
      expect(find.text('Welcome, Chief Administrator'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);

      // System Overview metrics checks
      expect(find.text('System Overview'), findsOneWidget);
      expect(find.text('142'), findsOneWidget);
      expect(find.text('Total Students'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('Total Faculty'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Class Reps'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
      expect(find.text('Total Courses'), findsOneWidget);
      expect(find.text('Pending Signups'), findsOneWidget);
      expect(find.text('Semester Requests'), findsWidgets);
    });

    testWidgets('3. Populated pending cards display petitioner info and level transitions', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                AdminPendingSignupsCard(requests: sampleSignups, onApprove: (_, __, ___) {}, onReject: (_, __) {}),
                AdminPendingSemesterCard(requests: sampleSemesterRequests, onApprove: (_) {}, onReject: (_, __) {}),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Pending Signup Requests list items
      expect(find.text('Tanvir Ahmed'), findsOneWidget);
      expect(find.text('2023CSE012'), findsOneWidget);
      expect(find.text('Dr. Kamal Hossain'), findsOneWidget);

      // Pending Semester Request item
      expect(find.text('Nusrat Jahan'), findsOneWidget);
      expect(find.text('2022CSE045'), findsOneWidget);
      expect(find.text('Y2S2'), findsOneWidget);
      expect(find.text('Y3S1'), findsOneWidget);
    });

    testWidgets('4. Empty pending cards display proper empty state messages', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                AdminPendingSignupsCard(requests: const [], onApprove: (_, __, ___) {}, onReject: (_, __) {}),
                AdminPendingSemesterCard(requests: const [], onApprove: (_) {}, onReject: (_, __) {}),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Pending Signups'), findsOneWidget);
      expect(find.text('All student and teacher registration petitions have been reviewed.'), findsOneWidget);
      expect(find.text('No Pending Promotions'), findsOneWidget);
      expect(find.text('All student semester upgrade petitions have been reviewed.'), findsOneWidget);
    });

    testWidgets('5. Error state renders AppErrorStateView and retry button recovers', (tester) async {
      when(() => mockAdminRepo.getOverviewStats()).thenThrow(Exception('Firestore unreachable.'));
      when(() => mockAdminRepo.getPendingSignupRequests()).thenThrow(Exception('Firestore unreachable.'));
      when(() => mockAdminRepo.getPendingSemesterRequests()).thenThrow(Exception('Firestore unreachable.'));

      final controller = AdminDashboardController(
        getDataUseCase: GetAdminDashboardDataUseCase(mockAdminRepo),
        approveSignupUseCase: ApproveSignupRequestUseCase(mockAdminRepo),
        rejectSignupUseCase: RejectSignupRequestUseCase(mockAdminRepo),
        approveSemesterUseCase: ApproveSemesterUpgradeUseCase(mockAdminRepo),
        rejectSemesterUseCase: RejectSemesterUpgradeUseCase(mockAdminRepo),
      );

      await tester.pumpWidget(createTestApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Admin Console'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Now mock successful recovery on retry
      when(() => mockAdminRepo.getOverviewStats()).thenAnswer((_) async => sampleStats);
      when(() => mockAdminRepo.getPendingSignupRequests()).thenAnswer((_) async => sampleSignups);
      when(() => mockAdminRepo.getPendingSemesterRequests()).thenAnswer((_) async => sampleSemesterRequests);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Admin Console'), findsNothing);
      expect(find.text('System Overview'), findsOneWidget);
    });

    testWidgets('6. Quick Actions renders with User Directory shortcut', (tester) async {
      final controller = createTestController();

      await tester.pumpWidget(createTestApp(controller));
      await tester.pumpAndSettle();

      // User Directory inside Administrative Quick Actions
      expect(find.text('User Directory'), findsOneWidget);
      expect(find.text('Directory & Roles'), findsOneWidget);

      // Quick Actions
      expect(find.text('Administrative Quick Actions'), findsOneWidget);
      expect(find.text('Signup Requests'), findsOneWidget);
      expect(find.text('Course Catalog'), findsOneWidget);
      expect(find.text('Teacher Courses'), findsOneWidget);
      expect(find.text('Attendance Logs'), findsOneWidget);
      expect(find.text('Course Feedback'), findsOneWidget);
      expect(find.text('Notice & Alerts'), findsOneWidget);

      // System Settings removed from quick actions
      expect(find.text('System Settings'), findsNothing);
      expect(find.text('Preferences & Config'), findsNothing);

      // Admin Control & Authority removed from dashboard
      expect(find.text('Admin Control & Authority'), findsNothing);
    });
  });

  group('Stage 15: Admin Route Authorization & Navigation Guards Tests', () {
    testWidgets('7. Admin user is granted access to Admin Dashboard route', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: adminUser));
      when(() => mockAuthController.currentUser).thenReturn(adminUser);

      final router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.adminDashboard,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Admin Console'), findsOneWidget);
    });

    testWidgets('8. Non-admin (Student) attempting to access Admin Dashboard is redirected', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: studentUser));
      when(() => mockAuthController.currentUser).thenReturn(studentUser);

      final router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.adminDashboard,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Student redirected to student dashboard
      expect(find.text('Admin Console'), findsNothing);
      expect(find.text('Hi, Student User 👋'), findsOneWidget);
    });

    testWidgets('9. Non-admin (Student) attempting to access /admin/users sub-route is redirected', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: studentUser));
      when(() => mockAuthController.currentUser).thenReturn(studentUser);

      final router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.adminUsers,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('User Directory'), findsNothing);
      expect(find.text('Hi, Student User 👋'), findsOneWidget);
    });

    testWidgets('10. Admin can navigate to User Directory screen', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: adminUser));
      when(() => mockAuthController.currentUser).thenReturn(adminUser);

      final router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.adminUsers,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Department User Directory'), findsOneWidget);
      expect(find.text('Faculty'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('CRs'), findsOneWidget);
    });
  });
}
