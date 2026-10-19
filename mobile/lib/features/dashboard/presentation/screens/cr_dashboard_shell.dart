import 'package:flutter/material.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'authenticated_app_shell.dart';

/// Backward-compatible entry point delegating to [AuthenticatedAppShell]
/// for [UserRole.cr].
class CrDashboardShell extends StatelessWidget {
  final AuthController authController;
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const CrDashboardShell({
    super.key,
    required this.authController,
    required this.themeModeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return AuthenticatedAppShell(
      role: UserRole.cr,
      authController: authController,
      themeModeNotifier: themeModeNotifier,
    );
  }
}
