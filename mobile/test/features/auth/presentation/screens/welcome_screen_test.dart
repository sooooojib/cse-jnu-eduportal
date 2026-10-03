import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/screens/welcome_screen.dart';
import 'package:cse_jnu_eduportal/app/router/route_names.dart';
import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockLocalStorageService mockLocalStorageService;

  setUp(() async {
    await sl.reset();
    mockLocalStorageService = MockLocalStorageService();
    when(() => mockLocalStorageService.getThemeMode()).thenReturn('system');
    sl.registerLazySingleton<LocalStorageService>(
      () => mockLocalStorageService,
    );
    sl.registerLazySingleton<ThemeController>(
      () => ThemeController(localStorageService: sl()),
    );
  });

  Widget createTestWidget() {
    final router = GoRouter(
      initialLocation: RouteNames.welcome,
      routes: [
        GoRoute(
          path: RouteNames.welcome,
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) =>
              const Scaffold(body: Text('Login Screen')),
        ),
        GoRoute(
          path: RouteNames.signupRequest,
          builder: (context, state) =>
              const Scaffold(body: Text('Signup Request Screen')),
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets(
    'WelcomeScreen renders all brand elements, buttons, and opens public discovery sheets',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify brand titles
      expect(find.text('JnU EduPortal'), findsOneWidget);
      expect(find.text('Departmental Operating System'), findsOneWidget);
      expect(find.text('Jagannath University · Dept. of CSE'), findsOneWidget);

      // Verify main action buttons
      expect(find.text('Sign In to Dashboard'), findsOneWidget);
      expect(find.text('Request New Account'), findsOneWidget);

      // Verify Public Services Section
      expect(find.text('EXPLORE PUBLIC SERVICES'), findsOneWidget);
      expect(find.text('Class & Exam Routines'), findsOneWidget);
      expect(find.text('Faculty & Teacher Directory'), findsOneWidget);
      expect(find.text('B.Sc. & M.Sc. Curriculum'), findsNothing);
      expect(find.text('Department Office & Helpdesk'), findsOneWidget);

      // Tap Class & Exam Routines and verify bottom sheet opens
      await tester.ensureVisible(find.text('Class & Exam Routines'));
      await tester.tap(find.text('Class & Exam Routines'));
      await tester.pumpAndSettle();

      expect(
        find.text('Spring 2026 Academic Session · JnU CSE'),
        findsOneWidget,
      );
      expect(
        find.text('Central Master Class Routine (Spring 2026)'),
        findsOneWidget,
      );
      expect(
        find.text('13th Batch (4th Year, 2nd Sem) Full Routine'),
        findsOneWidget,
      );

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap Faculty Directory and verify bottom sheet opens
      await tester.ensureVisible(find.text('Faculty & Teacher Directory'));
      await tester.tap(find.text('Faculty & Teacher Directory'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Md. Abu Layek'), findsOneWidget);
      expect(find.text('layek@cse.jnu.ac.bd'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap Department Office & Helpdesk and verify bottom sheet opens with correct info
      await tester.ensureVisible(find.text('Department Office & Helpdesk'));
      await tester.tap(find.text('Department Office & Helpdesk'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '5th & 7th Floor, New Academic Building\n9-10, Chittaranjan Avenue, Dhaka 1100',
        ),
        findsOneWidget,
      );
      expect(
        find.text('+880 2226640038\nEmail: cse@jnu.ac.bd'),
        findsOneWidget,
      );

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Tap Sign In and verify navigation to Login Screen
      await tester.ensureVisible(find.text('Sign In to Dashboard'));
      await tester.tap(find.text('Sign In to Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
    },
  );
}
