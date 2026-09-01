import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/screens/login_screen.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';
import 'package:cse_jnu_eduportal/app/router/route_names.dart';

import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';

class MockAuthController extends Mock implements AuthController {}
class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthController mockAuthController;
  late MockLocalStorageService mockLocalStorageService;

  setUp(() async {
    mockAuthController = MockAuthController();
    when(() => mockAuthController.state).thenReturn(const AuthInitial());
    when(() => mockAuthController.addListener(any())).thenReturn(null);
    when(() => mockAuthController.removeListener(any())).thenReturn(null);

    await sl.reset();
    mockLocalStorageService = MockLocalStorageService();
    when(() => mockLocalStorageService.getThemeMode()).thenReturn('system');
    sl.registerLazySingleton<LocalStorageService>(() => mockLocalStorageService);
    sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: sl()));
  });

  Widget createTestWidget() {
    final router = GoRouter(
      initialLocation: RouteNames.login,
      routes: [
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => LoginScreen(authController: mockAuthController),
        ),
        GoRoute(
          path: RouteNames.signupRequest,
          builder: (context, state) => const Scaffold(body: Text('Signup Request Screen')),
        ),
        GoRoute(
          path: RouteNames.studentDashboard,
          builder: (context, state) => const Scaffold(body: Text('Student Dashboard')),
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  group('LoginScreen Widget', () {
    testWidgets('renders all input fields, buttons, and brand badges', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Log in to Portal'), findsOneWidget);
      expect(find.text('JnU EduPortal'), findsOneWidget);
      expect(find.text('Email address'), findsWidgets);
      expect(find.text('Password'), findsWidgets);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.textContaining('Sign up'), findsOneWidget);
    });

    testWidgets('triggers validation on empty submission', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Email address is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('calls login on AuthController when valid credentials entered', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      when(() => mockAuthController.login(
            email: 'student@cse.jnu.ac.bd',
            password: 'Password123!',
          )).thenAnswer((_) async => true);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;

      await tester.ensureVisible(emailField);
      await tester.enterText(emailField, 'student@cse.jnu.ac.bd');

      await tester.ensureVisible(passwordField);
      await tester.enterText(passwordField, 'Password123!');

      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      verify(() => mockAuthController.login(
            email: 'student@cse.jnu.ac.bd',
            password: 'Password123!',
          )).called(1);
    });
  });
}
