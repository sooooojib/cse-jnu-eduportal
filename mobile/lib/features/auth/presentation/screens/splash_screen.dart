import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/constants/role_constants.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../../../../shared/widgets/states/app_minimal_launch_view.dart';

class SplashScreen extends StatefulWidget {
  final AuthController authController;

  const SplashScreen({
    super.key,
    required this.authController,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bootstrap();
      }
    });
  }

  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();
    await widget.authController.checkAuthStatus();
    stopwatch.stop();

    // Hold for a smooth minimum duration on app boot so the launch screen is clearly shown
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      const minDuration = Duration(milliseconds: 1400);
      final remaining = minDuration - stopwatch.elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
    }

    if (!mounted) return;

    final state = widget.authController.state;
    if (state is Authenticated) {
      _routeForRole(state.user.role);
    } else {
      context.go(RouteNames.welcome);
    }
  }

  void _routeForRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        context.go(RouteNames.studentDashboard);
        break;
      case UserRole.teacher:
        context.go(RouteNames.teacherDashboard);
        break;
      case UserRole.cr:
        context.go(RouteNames.crDashboard);
        break;
      case UserRole.admin:
        context.go(RouteNames.adminDashboard);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AppMinimalLaunchView();
  }
}
