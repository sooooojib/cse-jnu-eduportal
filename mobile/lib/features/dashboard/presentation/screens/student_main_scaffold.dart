import 'package:flutter/material.dart';
import '../../../../core/constants/role_constants.dart';
import 'authenticated_app_shell.dart';

/// Backward-compatible entry point delegating to [AuthenticatedAppShell]
/// for [UserRole.student].
class StudentMainScaffold extends StatelessWidget {
  final int initialIndex;
  final UserRole? role;

  const StudentMainScaffold({super.key, this.initialIndex = 0, this.role});

  @override
  Widget build(BuildContext context) {
    return AuthenticatedAppShell(
      role: role,
      initialIndex: initialIndex,
    );
  }
}
