import 'package:flutter/material.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'authenticated_app_shell.dart';

/// Backward-compatible entry point delegating to [AuthenticatedAppShell]
/// for [UserRole.admin].
class AdminDashboardShell extends StatelessWidget {
  final AuthController authController;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const AdminDashboardShell({
    super.key,
    required this.authController,
    required this.themeModeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return AuthenticatedAppShell(
      role: UserRole.admin,
      authController: authController,
      themeModeNotifier: themeModeNotifier,
    );
  }
}
