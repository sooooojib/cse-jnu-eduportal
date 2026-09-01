import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../core/constants/role_constants.dart';
import '../../core/di/injection_container.dart';
import '../../features/auth/domain/usecases/signup_request_usecase.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/auth_state.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_request_screen.dart';
import '../../features/dashboard/presentation/screens/student_main_scaffold.dart';
import '../../features/dashboard/presentation/screens/teacher_dashboard_shell.dart';
import '../../features/dashboard/presentation/screens/cr_dashboard_shell.dart';
import '../../features/dashboard/presentation/screens/admin_dashboard_shell.dart';
import '../../features/profile/presentation/screens/student_profile_screen.dart';
import '../../features/notifications/presentation/screens/notification_list_screen.dart';
import '../../shared/presentation/foundation_preview_screen.dart';

class AppRouter {
  static GoRouter createRouter({
    required ValueNotifier<ThemeMode> themeModeNotifier,
    String initialLocation = RouteNames.initial,
    AuthController? authController,
  }) {
    final auth = authController ?? sl<AuthController>();
    final signupUseCase = sl<SignupRequestUseCase>();

    return GoRouter(
      initialLocation: initialLocation,
      refreshListenable: auth,
      redirect: (context, state) {
        final authState = auth.state;
        final isLoggingIn = state.matchedLocation == RouteNames.login;
        final isSigningUp = state.matchedLocation == RouteNames.signupRequest;
        final isSplash = state.matchedLocation == RouteNames.initial;
        final isPreview = state.matchedLocation == RouteNames.foundationPreview;

        // Allow splash, preview, and signup requests without auth
        if (isSplash || isPreview || isSigningUp) return null;

        // If unauthenticated or disabled, redirect all protected paths to login
        if (authState is! Authenticated) {
          return isLoggingIn ? null : RouteNames.login;
        }

        // Authenticated user role protection
        final user = authState.user;
        final currentPath = state.matchedLocation;

        if (isLoggingIn) {
          return _getDashboardRouteForRole(user.role);
        }

        // Role-based route authorization guards
        if (currentPath == RouteNames.adminDashboard && user.role != UserRole.admin) {
          return _getDashboardRouteForRole(user.role);
        }
        if (currentPath == RouteNames.teacherDashboard &&
            user.role != UserRole.teacher &&
            user.role != UserRole.admin) {
          return _getDashboardRouteForRole(user.role);
        }
        if (currentPath == RouteNames.crDashboard &&
            user.role != UserRole.cr &&
            user.role != UserRole.admin) {
          return _getDashboardRouteForRole(user.role);
        }

        return null;
      },
      routes: [
        // Splash / Bootstrapping
        GoRoute(
          path: RouteNames.initial,
          builder: (context, state) => SplashScreen(
            authController: auth,
          ),
        ),

        // Authentication Flow
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => LoginScreen(
            authController: auth,
          ),
        ),
        GoRoute(
          path: RouteNames.signupRequest,
          builder: (context, state) => SignupRequestScreen(
            signupRequestUseCase: signupUseCase,
          ),
        ),

        // Role Dashboard Shells
        GoRoute(
          path: RouteNames.studentDashboard,
          builder: (context, state) => const StudentMainScaffold(initialIndex: 0),
        ),
        GoRoute(
          path: RouteNames.attendanceTerminal,
          builder: (context, state) => const StudentMainScaffold(initialIndex: 1),
        ),
        GoRoute(
          path: RouteNames.schedule,
          builder: (context, state) => const StudentMainScaffold(initialIndex: 2),
        ),
        GoRoute(
          path: RouteNames.counseling,
          builder: (context, state) => const StudentMainScaffold(initialIndex: 3),
        ),
        GoRoute(
          path: RouteNames.feedback,
          builder: (context, state) => const StudentMainScaffold(initialIndex: 4),
        ),
        GoRoute(
          path: RouteNames.studentProfile,
          builder: (context, state) => const StudentProfileScreen(),
        ),
        GoRoute(
          path: RouteNames.notifications,
          builder: (context, state) => const NotificationListScreen(),
        ),

        GoRoute(
          path: RouteNames.teacherDashboard,
          builder: (context, state) => TeacherDashboardShell(
            authController: auth,
            themeModeNotifier: themeModeNotifier,
          ),
        ),
        GoRoute(
          path: RouteNames.crDashboard,
          builder: (context, state) => CrDashboardShell(
            authController: auth,
            themeModeNotifier: themeModeNotifier,
          ),
        ),
        GoRoute(
          path: RouteNames.adminDashboard,
          builder: (context, state) => AdminDashboardShell(
            authController: auth,
            themeModeNotifier: themeModeNotifier,
          ),
        ),

        // Design System Foundation Showcase
        GoRoute(
          path: RouteNames.foundationPreview,
          builder: (context, state) => FoundationPreviewScreen(
            themeModeNotifier: themeModeNotifier,
          ),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Page not found: ${state.uri}'),
        ),
      ),
    );
  }

  static String _getDashboardRouteForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return RouteNames.adminDashboard;
      case UserRole.teacher:
        return RouteNames.teacherDashboard;
      case UserRole.cr:
        return RouteNames.crDashboard;
      case UserRole.student:
        return RouteNames.studentDashboard;
    }
  }
}
