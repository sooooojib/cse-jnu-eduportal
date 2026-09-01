import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cse_jnu_eduportal/app/theme/app_colors.dart';
import 'package:cse_jnu_eduportal/app/theme/role_colors.dart';
import 'package:cse_jnu_eduportal/app/theme/app_theme.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Emerald Scholar Design Tokens & Theme Engine', () {
    test('AppColors contains proper brand primary and terminal colors', () {
      expect(AppColors.primary, const Color(0xFF006948));
      expect(AppColors.terminalCanvas, const Color(0xFF18181B));
      expect(AppColors.terminalGlow, const Color(0xFF34D399));
    });

    test('RoleColors maps distinct color palettes for all 4 roles', () {
      final studentScheme = RoleColors.forRole(UserRole.student);
      final teacherScheme = RoleColors.forRole(UserRole.teacher);
      final crScheme = RoleColors.forRole(UserRole.cr);
      final adminScheme = RoleColors.forRole(UserRole.admin);

      expect(studentScheme.text, const Color(0xFF047857));
      expect(teacherScheme.text, const Color(0xFF1D4ED8));
      expect(crScheme.text, const Color(0xFFC2410C));
      expect(adminScheme.text, const Color(0xFF7E22CE));
    });

    test('AppTheme creates valid light and dark ThemeData configurations', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.primary, AppColors.primary);
      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
    });
  });
}
