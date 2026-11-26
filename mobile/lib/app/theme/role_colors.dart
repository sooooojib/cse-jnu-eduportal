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
  // Light Schemes
  static const RoleColorScheme student = RoleColorScheme(
    background: Color(0xFFECFDF5),
    text: Color(0xFF047857),
    border: Color(0xFFA7F3D0),
    primary: Color(0xFF059669),
  );

  static const RoleColorScheme teacher = RoleColorScheme(
    background: Color(0xFFEFF6FF),
    text: Color(0xFF1D4ED8),
    border: Color(0xFFBFDBFE),
    primary: Color(0xFF2563EB),
  );

  static const RoleColorScheme cr = RoleColorScheme(
    background: Color(0xFFFFF7ED),
    text: Color(0xFFC2410C),
    border: Color(0xFFFED7AA),
    primary: Color(0xFFEA580C),
  );

  static const RoleColorScheme admin = RoleColorScheme(
    background: Color(0xFFFAF5FF),
    text: Color(0xFF7E22CE),
    border: Color(0xFFE9D5FF),
    primary: Color(0xFF9333EA),
  );

  // Chairman: royal indigo with gold accent
  static const RoleColorScheme chairman = RoleColorScheme(
    background: Color(0xFFEEF2FF),
    text: Color(0xFF3730A3),
    border: Color(0xFFFCD34D),
    primary: Color(0xFFD97706),
  );

  // Dark Schemes
  static const RoleColorScheme studentDark = RoleColorScheme(
    background: Color(0xFF064E3B),
    text: Color(0xFF6EE7B7),
    border: Color(0xFF059669),
    primary: Color(0xFF34D399),
  );

  static const RoleColorScheme teacherDark = RoleColorScheme(
    background: Color(0xFF1E3A8A),
    text: Color(0xFF93C5FD),
    border: Color(0xFF2563EB),
    primary: Color(0xFF60A5FA),
  );

  static const RoleColorScheme crDark = RoleColorScheme(
    background: Color(0xFF7C2D12),
    text: Color(0xFFFDBA74),
    border: Color(0xFFEA580C),
    primary: Color(0xFFFB923C),
  );

  static const RoleColorScheme adminDark = RoleColorScheme(
    background: Color(0xFF581C87),
    text: Color(0xFFD8B4FE),
    border: Color(0xFF9333EA),
    primary: Color(0xFFA855F7),
  );

  static const RoleColorScheme chairmanDark = RoleColorScheme(
    background: Color(0xFF312E81),
    text: Color(0xFFC7D2FE),
    border: Color(0xFFF59E0B),
    primary: Color(0xFFFBBF24),
  );

  static RoleColorScheme forRole(UserRole role, {bool isDark = false}) {
    if (isDark) {
      switch (role) {
        case UserRole.student:
          return studentDark;
        case UserRole.teacher:
          return teacherDark;
        case UserRole.chairman:
          return chairmanDark;
        case UserRole.cr:
          return crDark;
        case UserRole.admin:
          return adminDark;
      }
    }
    switch (role) {
      case UserRole.student:
        return student;
      case UserRole.teacher:
        return teacher;
      case UserRole.chairman:
        return chairman;
      case UserRole.cr:
        return cr;
      case UserRole.admin:
        return admin;
    }
  }
}
