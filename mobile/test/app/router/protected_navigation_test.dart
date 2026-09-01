import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/usecases/signup_request_usecase.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';
import 'package:cse_jnu_eduportal/app/router/app_router.dart';
import 'package:cse_jnu_eduportal/app/router/route_names.dart';
import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';

// Curriculum
import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/controllers/schedule_controller.dart';

// Attendance
import 'package:cse_jnu_eduportal/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/controllers/attendance_controller.dart';

// Counseling
import 'package:cse_jnu_eduportal/features/counseling/domain/repositories/counseling_repository.dart';
import 'package:cse_jnu_eduportal/features/counseling/presentation/controllers/counseling_controller.dart';

// Feedback
import 'package:cse_jnu_eduportal/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:cse_jnu_eduportal/features/feedback/presentation/controllers/feedback_controller.dart';

// Profile
import 'package:cse_jnu_eduportal/features/profile/domain/repositories/semester_repository.dart';
import 'package:cse_jnu_eduportal/features/profile/presentation/controllers/profile_controller.dart';

// Notifications
import 'package:cse_jnu_eduportal/features/notifications/domain/repositories/notification_repository.dart';
import 'package:cse_jnu_eduportal/features/notifications/presentation/controllers/notification_controller.dart';

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
  late MockAuthController mockAuthController;
  late MockLocalStorageService mockLocalStorageService;
  late MockSignupRequestUseCase mockSignupRequestUseCase;
  late ValueNotifier<ThemeMode> themeModeNotifier;

  const teacherUser = User(
    id: 'uid_teacher',
    email: 'teacher@cse.jnu.ac.bd',
    fullName: 'Teacher User',
    role: UserRole.teacher,
    phone: '+8801700000000',
  );

  const adminUser = User(
    id: 'uid_admin',
    email: 'admin@cse.jnu.ac.bd',
    fullName: 'Admin User',
    role: UserRole.admin,
  );

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    mockAuthController = MockAuthController();
    mockLocalStorageService = MockLocalStorageService();
    mockSignupRequestUseCase = MockSignupRequestUseCase();
    themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

    when(() => mockAuthController.addListener(any())).thenReturn(null);
    when(() => mockAuthController.removeListener(any())).thenReturn(null);
    when(() => mockLocalStorageService.getThemeMode()).thenReturn('system');

    await sl.reset();
    sl.registerLazySingleton<LocalStorageService>(() => mockLocalStorageService);
    sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: sl()));
    sl.registerLazySingleton<SignupRequestUseCase>(() => mockSignupRequestUseCase);
    sl.registerLazySingleton<AuthController>(() => mockAuthController);

    // Register empty mock controllers for scaffold pages
    final curRepo = MockCurriculumRepo();
    when(() => curRepo.getSchedule()).thenAnswer((_) async => []);
    when(() => curRepo.getExams()).thenAnswer((_) async => []);
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

  group('Protected Navigation & Role Routing Guards Tests', () {
    testWidgets('Unauthenticated user is redirected to Login Screen from protected route', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Unauthenticated());
      when(() => mockAuthController.currentUser).thenReturn(null);

      final router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.studentDashboard,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Log in to Portal'), findsOneWidget);
    });

    testWidgets('Teacher attempting to access Admin Dashboard is redirected to Teacher Dashboard', (tester) async {
      when(() => mockAuthController.state).thenReturn(const Authenticated(user: teacherUser));
      when(() => mockAuthController.currentUser).thenReturn(teacherUser);

      final router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.adminDashboard,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Faculty Portal'), findsOneWidget);
    });

    testWidgets('Admin user is permitted on Admin Dashboard', (tester) async {
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

    testWidgets('Disabled account user is redirected to Login Screen', (tester) async {
      when(() => mockAuthController.state)
          .thenReturn(const AuthAccountDisabled(message: 'Your account has been deactivated.'));
      when(() => mockAuthController.currentUser).thenReturn(null);

      final router = AppRouter.createRouter(
        themeModeNotifier: themeModeNotifier,
        initialLocation: RouteNames.adminDashboard,
        authController: mockAuthController,
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Log in to Portal'), findsOneWidget);
    });
  });
}
