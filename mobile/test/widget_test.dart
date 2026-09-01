import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/app/theme/theme_controller.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';
import 'package:cse_jnu_eduportal/app/router/route_names.dart';
import 'package:go_router/go_router.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/screens/splash_screen.dart';

class MockAuthController extends Mock implements AuthController {}
class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthController mockAuthController;
  late MockLocalStorageService mockLocalStorageService;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    mockAuthController = MockAuthController();
    when(() => mockAuthController.state).thenReturn(const AuthInitial());
    when(() => mockAuthController.checkAuthStatus()).thenAnswer((_) async {});

    await sl.reset();
    mockLocalStorageService = MockLocalStorageService();
    when(() => mockLocalStorageService.getThemeMode()).thenReturn('system');
    sl.registerLazySingleton<LocalStorageService>(() => mockLocalStorageService);
    sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: sl()));
  });

  testWidgets('SplashScreen initializes and displays branding', (WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: RouteNames.initial,
      routes: [
        GoRoute(
          path: RouteNames.initial,
          builder: (context, state) => SplashScreen(authController: mockAuthController),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('JnU EduPortal'), findsWidgets);
    expect(find.text('Department of Computer Science & Engineering'), findsOneWidget);
  });
}
