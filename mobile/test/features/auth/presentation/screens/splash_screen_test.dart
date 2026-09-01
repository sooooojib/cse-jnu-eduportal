import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/screens/splash_screen.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';
import 'package:cse_jnu_eduportal/app/router/route_names.dart';

class MockAuthController extends Mock implements AuthController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthController mockAuthController;

  setUp(() {
    mockAuthController = MockAuthController();
    when(() => mockAuthController.state).thenReturn(const AuthInitial());
    when(() => mockAuthController.checkAuthStatus()).thenAnswer((_) async {});
  });

  Widget createTestWidget() {
    final router = GoRouter(
      initialLocation: RouteNames.initial,
      routes: [
        GoRoute(
          path: RouteNames.initial,
          builder: (context, state) => SplashScreen(authController: mockAuthController),
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => const Scaffold(body: Text('Login Screen')),
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

  group('SplashScreen Widget', () {
    testWidgets('calls checkAuthStatus and renders splash branding', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('JnU EduPortal'), findsOneWidget);
      expect(find.text('Department of Computer Science & Engineering'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      verify(() => mockAuthController.checkAuthStatus()).called(1);
    });
  });
}
