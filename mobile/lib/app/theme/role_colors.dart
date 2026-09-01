import 'package:flutter/material.dart';
import '../../core/constants/role_constants.dart';

class RoleColorScheme {
  final Color background;
  final Color text;
  final Color border;
  final Color primary;

  const RoleColorScheme({
    required this.background,
    required this.text,
    required this.border,
    required this.primary,
  });
}

class RoleColors {
  // Student - Emerald
  static const RoleColorScheme student = RoleColorScheme(
    background: Color(0xFFECFDF5),
    text: Color(0xFF047857),
    border: Color(0xFFA7F3D0),
    primary: Color(0xFF059669),
  );

  // Teacher - Royal Blue
  static const RoleColorScheme teacher = RoleColorScheme(
    background: Color(0xFFEFF6FF),
    text: Color(0xFF1D4ED8),
    border: Color(0xFFBFDBFE),
    primary: Color(0xFF2563EB),
  );

  // CR - Amber / Warm Orange
  static const RoleColorScheme cr = RoleColorScheme(
    background: Color(0xFFFFF7ED),
    text: Color(0xFFC2410C),
    border: Color(0xFFFED7AA),
    primary: Color(0xFFEA580C),
  );

  // Admin - Purple
  static const RoleColorScheme admin = RoleColorScheme(
    background: Color(0xFFFAF5FF),
    text: Color(0xFF7E22CE),
    border: Color(0xFFE9D5FF),
    primary: Color(0xFF9333EA),
  );

  static RoleColorScheme forRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        return student;
      case UserRole.teacher:
        return teacher;
      case UserRole.cr:
        return cr;
      case UserRole.admin:
        return admin;
    }
  }
}
