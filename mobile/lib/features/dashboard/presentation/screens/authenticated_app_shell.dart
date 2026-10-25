import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../../../admin/presentation/screens/admin_management_screens.dart';
import '../../../admin/presentation/screens/admin_notification_hub_screen.dart';
import '../../../attendance/presentation/screens/student_attendance_screen.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_state.dart';
import '../../../counseling/presentation/screens/student_counseling_screen.dart';
import '../../../cr/presentation/screens/cr_dashboard_screen.dart';
import '../../../curriculum/presentation/screens/student_schedule_screen.dart';
import '../../../feedback/presentation/screens/student_feedback_screen.dart';
import '../../../notifications/presentation/screens/notification_list_screen.dart';
import '../../../profile/presentation/screens/student_profile_screen.dart';
import '../../../profile/presentation/widgets/student_profile_dialog.dart';
import '../../../teacher/presentation/screens/teacher_dashboard_screen.dart';
import '../../../teacher/presentation/screens/teacher_schedule_screen.dart';
import '../../../teacher/presentation/widgets/teacher_profile_dialog.dart';
import '../../../attendance/presentation/screens/teacher_attendance_terminal_screen.dart';
import '../../../counseling/presentation/screens/teacher_counseling_screen.dart';
import '../../../feedback/presentation/screens/teacher_feedback_screen.dart';
import '../../../../core/utils/avatar_image_resolver.dart';
import 'student_dashboard_shell.dart';

/// Unified Authenticated Application Shell
///
/// Serves as the authoritative master shell for all 4 roles:
/// - Student: Student Functions (Home, Attendance, Schedule, Counseling, Feedback)
/// - Teacher: Teacher Functions (Home, Attendance, Schedule, Counseling, Feedback)
/// - CR: Student + CR Functions (Home, Schedule, Attendance, Counseling, Feedback)
/// - Admin: Administrative Functions (Console, Users, Requests, Courses, Settings)
///
/// Features:
/// - Role-aware NavigationBar with 5 destinations per role
/// - Unified Top Bar: Profile avatar, brand header, role badge, theme toggle, notifications, settings, logout
/// - Back navigation stack handling (PopScope returning to Tab 0 before exit)
/// - Deep navigation and back navigation support
/// - Standardized logout confirmation dialog and session cleanup
class AuthenticatedAppShell extends StatefulWidget {
  final UserRole? role;
  final int initialIndex;
  final AuthController? authController;
  final ValueNotifier<ThemeMode>? themeModeNotifier;

  const AuthenticatedAppShell({
    super.key,
    this.role,
    this.initialIndex = 0,
    this.authController,
    this.themeModeNotifier,
  });

  @override
  State<AuthenticatedAppShell> createState() => _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<AuthenticatedAppShell> {
  late int _currentIndex;
  late final AuthController _authController;
  late final ValueNotifier<ThemeMode> _themeModeNotifier;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _authController = widget.authController ?? (sl.isRegistered<AuthController>() ? sl<AuthController>() : AuthController(
      loginUseCase: sl(),
      getCurrentUserUseCase: sl(),
      logoutUseCase: sl(),
    ));
    _themeModeNotifier = widget.themeModeNotifier ?? (sl.isRegistered<ThemeController>() ? sl<ThemeController>() : ValueNotifier(ThemeMode.system));
  }

  @override
  void didUpdateWidget(covariant AuthenticatedAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() {
        _currentIndex = widget.initialIndex;
      });
    }
  }

  void _onTabSelected(int index) {
    if (mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  ImageProvider? _resolveAvatar(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();

    // 1. Base64
    if (trimmed.startsWith('data:image')) {
      final commaIdx = trimmed.indexOf(',');
      if (commaIdx != -1) {
        try {
          final base64Str = trimmed.substring(commaIdx + 1);
          return MemoryImage(base64Decode(base64Str));
        } catch (_) {
          return null;
        }
      }
    }

    // 2. Prevent local paths (/data/... or file:///...) from being treated as NetworkImage
    if (trimmed.startsWith('/') || trimmed.startsWith('file:')) {
      if (!kIsWeb) {
        try {
          String cleanPath = trimmed;
          if (trimmed.startsWith('file:')) {
            final uri = Uri.tryParse(trimmed);
            cleanPath = uri != null && uri.isScheme('file') ? uri.toFilePath() : trimmed.replaceFirst(RegExp(r'^file:\/{1,3}'), '/');
          }
          final file = File(cleanPath);
          if (file.existsSync()) {
            return FileImage(file);
          }
        } catch (_) {}
      }
      return null;
    }

    // 3. Remote HTTP/HTTPS URLs with non-empty host
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.hasAuthority && uri.host.isNotEmpty) {
        return NetworkImage(trimmed);
      }
      return null;
    }

    return null;
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Sign Out?',
      message: 'Are you sure you want to end your active session and sign out of JnU EduPortal?',
      confirmText: 'Sign Out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed == true && mounted) {
      await _authController.logout();
      if (mounted) {
        context.go(RouteNames.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = _authController.state;
    final currentUser = authState is Authenticated ? authState.user : _authController.currentUser;
    final role = widget.role ?? currentUser?.role ?? UserRole.student;
    final isDark = context.isDarkMode;

    // Role-tailored destinations & screens for Admin, Teacher, CR, and Student
    final List<Widget> screens;
    final List<NavigationDestination> destinations;
    final Color roleColor;
    final String shellTitle;

    if (role == UserRole.admin) {
      roleColor = const Color(0xFF7E22CE);
      shellTitle = 'Admin Console';
      screens = [
        AdminDashboardScreen(
          authController: _authController,
          onNavigateTab: _onTabSelected,
        ),
        const AdminUserDirectoryScreen(showAppBar: false),
        const AdminSignupRequestsScreen(showAppBar: false),
        const AdminCourseManagementScreen(showAppBar: false),
        const AdminSettingsScreen(showAppBar: false),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Console',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_alt_outlined),
          selectedIcon: Icon(Icons.people_alt_rounded),
          label: 'Users',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_turned_in_outlined),
          selectedIcon: Icon(Icons.assignment_turned_in_rounded),
          label: 'Requests',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: 'Courses',
        ),
        NavigationDestination(
          icon: Icon(Icons.tune_outlined),
          selectedIcon: Icon(Icons.tune_rounded),
          label: 'Settings',
        ),
      ];
    } else if (role == UserRole.teacher) {
      roleColor = const Color(0xFF1D4ED8);
      shellTitle = 'JnU EduPortal';
      screens = [
        TeacherDashboardScreen(
          wrapWithScaffold: false,
          onNavigateTab: _onTabSelected,
        ),
        const TeacherAttendanceTerminalScreen(showAppBar: false),
        const TeacherScheduleScreen(showAppBar: false),
        const TeacherCounselingScreen(showAppBar: false),
        const TeacherFeedbackScreen(showAppBar: false),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check_rounded),
          label: 'Attendance',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Schedule',
        ),
        NavigationDestination(
          icon: Icon(Icons.support_agent_outlined),
          selectedIcon: Icon(Icons.support_agent_rounded),
          label: 'Counseling',
        ),
        NavigationDestination(
          icon: Icon(Icons.rate_review_outlined),
          selectedIcon: Icon(Icons.rate_review_rounded),
          label: 'Feedback',
        ),
      ];
    } else if (role == UserRole.cr) {
      roleColor = const Color(0xFFC2410C);
      shellTitle = 'JnU EduPortal';
      screens = [
        CrDashboardScreen(
          wrapWithScaffold: false,
          onNavigateTab: _onTabSelected,
        ),
        const StudentAttendanceScreen(),
        const StudentScheduleScreen(),
        const StudentCounselingScreen(),
        const StudentFeedbackScreen(),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check_rounded),
          label: 'Attendance',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Schedule',
        ),
        NavigationDestination(
          icon: Icon(Icons.support_agent_outlined),
          selectedIcon: Icon(Icons.support_agent_rounded),
          label: 'Counseling',
        ),
        NavigationDestination(
          icon: Icon(Icons.rate_review_outlined),
          selectedIcon: Icon(Icons.rate_review_rounded),
          label: 'Feedback',
        ),
      ];
    } else {
      // Default: Student
      roleColor = const Color(0xFF047857);
      shellTitle = 'JnU EduPortal';
      screens = [
        StudentDashboardShell(
          authController: _authController,
          themeModeNotifier: _themeModeNotifier,
          wrapWithScaffold: false,
          onNavigateTab: _onTabSelected,
        ),
        const StudentAttendanceScreen(),
        const StudentScheduleScreen(),
        const StudentCounselingScreen(),
        const StudentFeedbackScreen(),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check_rounded),
          label: 'Attendance',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month_rounded),
          label: 'Schedule',
        ),
        NavigationDestination(
          icon: Icon(Icons.support_agent_outlined),
          selectedIcon: Icon(Icons.support_agent_rounded),
          label: 'Counsel',
        ),
        NavigationDestination(
          icon: Icon(Icons.rate_review_outlined),
          selectedIcon: Icon(Icons.rate_review_rounded),
          label: 'Feedback',
        ),
      ];
    }

    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return PopScope(
      canPop: safeIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        appBar: AppBar(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          elevation: 0,
          scrolledUnderElevation: 1,
          titleSpacing: 12,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: GestureDetector(
              onTap: () {
                final user = currentUser ?? _authController.currentUser;
                if (user == null) return;
                if (role == UserRole.admin) {
                  TeacherProfileDialog.show(
                    context: context,
                    teacher: user,
                    assignedCoursesCount: 0,
                    onLogout: () => _handleLogout(context),
                  );
                } else if (role == UserRole.teacher) {
                  TeacherProfileDialog.show(
                    context: context,
                    teacher: user,
                    assignedCoursesCount: user.assignedCourseIds.length,
                    onLogout: () => _handleLogout(context),
                  );
                } else {
                  StudentProfileDialog.show(
                    context: context,
                    student: user,
                    onLogout: () => _handleLogout(context),
                  );
                }
              },
              child: Builder(
                builder: (context) {
                  final avatarProvider = _resolveAvatar(currentUser?.avatarUrl);
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: roleColor.withValues(alpha: 0.15),
                    backgroundImage: avatarProvider,
                    onBackgroundImageError: avatarProvider != null ? (_, __) {} : null,
                    child: avatarProvider == null
                        ? Text(
                            currentUser != null && currentUser.fullName.isNotEmpty
                                ? currentUser.fullName.substring(0, 1).toUpperCase()
                                : (role == UserRole.admin ? 'A' : (role == UserRole.teacher ? 'T' : (role == UserRole.cr ? 'C' : 'S'))),
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
          title: Center(
            child: Text(
              'JnU EduPortal',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: -0.4,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          actions: [
            const ThemeToggleButton(showBackground: false),
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                if (role == UserRole.admin) {
                  context.push(RouteNames.adminNotifications);
                } else {
                  context.push(RouteNames.notifications);
                }
              },
            ),
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              onPressed: () => _handleLogout(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(
          index: safeIndex,
          children: screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? roleColor
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  letterSpacing: -0.3,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
                final isSelected = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: 22,
                  color: isSelected
                      ? roleColor
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                );
              }),
              indicatorColor: roleColor.withValues(alpha: 0.15),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: _onTabSelected,
              elevation: 0,
              backgroundColor: Colors.transparent,
              destinations: destinations,
            ),
          ),
        ),
      ),
    );
  }
}
