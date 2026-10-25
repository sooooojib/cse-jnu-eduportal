import 'package:flutter/material.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../teacher/presentation/widgets/teacher_profile_dialog.dart';

/// Facade for Administrator Profile Dialog, presenting the exact unified
/// profile menu design for system administrators.
class AdminProfileDialog {
  const AdminProfileDialog._();

  static Future<void> show({
    required BuildContext context,
    required User admin,
    required Future<void> Function() onLogout,
  }) {
    return TeacherProfileDialog.show(
      context: context,
      teacher: admin,
      assignedCoursesCount: 0,
      onLogout: onLogout,
    );
  }
}
