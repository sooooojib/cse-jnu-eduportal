import 'package:flutter/material.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

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
    return AdminDashboardScreen(authController: authController);
  }
}
