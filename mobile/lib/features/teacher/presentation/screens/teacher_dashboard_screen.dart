import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../controllers/teacher_dashboard_controller.dart';
import '../controllers/teacher_dashboard_state.dart';
import '../widgets/assigned_course_card.dart';
import '../widgets/teacher_metric_card.dart';
import '../widgets/teacher_profile_dialog.dart';
import '../widgets/teacher_quick_actions.dart';
import '../widgets/time_aware_classes_card.dart';
import '../../../attendance/presentation/screens/teacher_attendance_terminal_screen.dart';
import 'teacher_schedule_screen.dart';
import '../../../counseling/presentation/screens/teacher_counseling_screen.dart';
import '../../../feedback/presentation/screens/teacher_feedback_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final TeacherDashboardController? controller;
  final bool wrapWithScaffold;
  final void Function(int tabIndex)? onNavigateTab;

  const TeacherDashboardScreen({
    super.key,
    this.controller,
    this.wrapWithScaffold = true,
    this.onNavigateTab,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  late final TeacherDashboardController _controller;
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? sl<TeacherDashboardController>();
    _controller.addListener(_onControllerUpdate);

    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.state is TeacherDashboardInitial) {
        _controller.loadDashboardData();
      }
    });
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Sign Out?',
      message: 'Are you sure you want to end your faculty session and sign out?',
      confirmText: 'Sign Out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed == true && mounted) {
      final authController = sl<AuthController>();
      await authController.logout();
      if (mounted) {
        context.go(RouteNames.login);
      }
    }
  }



  void _showModuleComingSoon(String moduleName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Faculty Module',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The dedicated full interface for $moduleName is scheduled for the upcoming module stages.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openProfileDialog(User teacher, int assignedCount) {
    TeacherProfileDialog.show(
      context: context,
      teacher: teacher,
      assignedCoursesCount: assignedCount,
      onLogout: _handleLogout,
    );
  }

  void _handleStartAttendance(ScheduleSlot slot) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherAttendanceTerminalScreen(preselectedCourseId: slot.courseId),
      ),
    );
  }

  void _onBottomNavTapped(int index) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(index);
      return;
    }
    if (index == 0) {
      setState(() => _currentNavIndex = 0);
    } else if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TeacherAttendanceTerminalScreen(),
        ),
      );
    } else if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TeacherScheduleScreen(),
        ),
      );
    } else if (index == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TeacherCounselingScreen(),
        ),
      );
    } else if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TeacherFeedbackScreen(),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authController = sl<AuthController>();
    final currentUser = authController.currentUser;
    final state = _controller.state;
    final avatarProvider = _resolveAvatar(currentUser?.avatarUrl);

    if (!widget.wrapWithScaffold) {
      return _buildBody(context, state, currentUser, isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 8,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: GestureDetector(
            onTap: () {
              if (currentUser != null) {
                final assignedCount = state is TeacherDashboardLoaded
                    ? state.data.assignedCourses.length
                    : (currentUser.assignedCourseIds.length);
                _openProfileDialog(currentUser, assignedCount);
              }
            },
            child: CircleAvatar(
              radius: 19,
              backgroundColor: isDark
                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                  : const Color(0xFFEFF6FF),
              backgroundImage: avatarProvider,
              onBackgroundImageError: avatarProvider != null ? (_, __) {} : null,
              child: avatarProvider == null
                  ? Text(
                      currentUser != null && currentUser.fullName.isNotEmpty
                          ? currentUser.fullName.substring(0, 1).toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    )
                  : null,
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
            onPressed: () => context.push(RouteNames.notifications),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context, state, currentUser, isDark),
      bottomNavigationBar: _buildBottomNav(context, isDark),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TeacherDashboardState state,
    User? currentUser,
    bool isDark,
  ) {
    if (state is TeacherDashboardLoading) {
      return const AppLoadingView(
        message: 'Synchronizing departmental routine and courses...',
      );
    }

    if (state is TeacherDashboardError) {
      return AppErrorStateView(
        title: 'Unable to Load Dashboard',
        message: state.message,
        onRetry: () => _controller.loadDashboardData(),
      );
    }

    if (state is TeacherDashboardLoaded) {
      final data = state.data;

      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _controller.refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Teacher Welcome & Role Header
              _buildTeacherHeader(data, isDark),

              const SizedBox(height: 20),

              // 2. Metrics Grid
              _buildMetricsSection(data, isDark),

              const SizedBox(height: 24),

              // 3. Time-Aware Classes & Today's Exams Section (with toggle)
              TimeAwareClassesCard(
                classes: data.timeAwareClasses,
                exams: data.timeAwareExams,
                todayClasses: data.effectiveTodayClasses,
                tomorrowClasses: data.effectiveTomorrowClasses,
                todayExams: data.effectiveTodayExams,
                tomorrowExams: data.effectiveTomorrowExams,
                todayDateLabel: data.todayDateLabel.isNotEmpty ? data.todayDateLabel : data.targetDateLabel,
                tomorrowDateLabel: data.tomorrowDateLabel.isNotEmpty ? data.tomorrowDateLabel : data.targetDateLabel,
                isTomorrow: data.isTomorrow,
                dateLabel: data.targetDateLabel,
                onStartAttendance: _handleStartAttendance,
                onExamTap: (exam) => _showModuleComingSoon('Exam Invigilation (${exam.courseCode})'),
                onViewFullSchedule: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(2);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TeacherScheduleScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // 4. Quick Actions (below Today's Classes)
              TeacherQuickActions(
                onAttendance: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(1);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TeacherAttendanceTerminalScreen(),
                    ),
                  );
                },
                onSchedule: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(2);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TeacherScheduleScreen(),
                    ),
                  );
                },
                onCounseling: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(3);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TeacherCounselingScreen(),
                    ),
                  );
                },
                onFeedback: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(4);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TeacherFeedbackScreen(),
                    ),
                  );
                },
                onCourses: () => _showCoursesBottomSheet(data.assignedCourses),
                onNotifications: () => context.push(RouteNames.notifications),
                onProfile: () {
                  if (currentUser != null) {
                    _openProfileDialog(currentUser, data.assignedCourses.length);
                  }
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTeacherHeader(data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'Welcome back, ${data.teacherName.isNotEmpty ? data.teacherName : "Professor"}.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 8),
          RoleBadgeChip(role: data.role, isCompact: true),
        ],
      ),
    );
  }

  Widget _buildMetricsSection(data, bool isDark) {
    return Row(
      children: [
            Expanded(
              child: TeacherMetricCard(
                title: 'Counseling',
                count: '${data.pendingCounselingCount}',
                icon: Icons.groups_rounded,
                iconBackgroundColor: isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                    : const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF1D4ED8),
                badgeText: data.pendingCounselingCount > 0 ? 'Action' : null,
                badgeBackgroundColor: const Color(0xFFFFDAD6),
                badgeTextColor: const Color(0xFF93000A),
                onTap: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(3);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TeacherCounselingScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TeacherMetricCard(
                title: 'Feedback',
                count: '${data.feedbackCount}',
                icon: Icons.forum_rounded,
                iconBackgroundColor: isDark
                    ? const Color(0xFF047857).withValues(alpha: 0.25)
                    : const Color(0xFFECFDF5),
                iconColor: const Color(0xFF047857),
                onTap: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(4);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TeacherFeedbackScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TeacherMetricCard(
                title: 'Classes',
                count: '${data.classesTaughtCount}',
                icon: Icons.school_rounded,
                iconBackgroundColor: isDark
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : const Color(0xFFD3E4FE),
                iconColor: AppColors.primary,
                onTap: () => _showCoursesBottomSheet(data.assignedCourses),
              ),
            ),
          ],
        );
  }

  void _showCoursesBottomSheet(List<Course> courses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13263E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Assigned Curriculum Portfolio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${courses.length} Courses',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: courses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => AssignedCourseCard(
                        course: courses[i],
                        onTap: () {
                          Navigator.pop(ctx);
                          _showCourseDetailModal(courses[i]);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCourseDetailModal(Course course) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      course.code,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
                  Text(
                    '${course.credit} Credits • ${course.courseType}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                course.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Year ${course.year} • Semester ${course.semester}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              if (course.description != null && course.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  course.description!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeacherAttendanceTerminalScreen(preselectedCourseId: course.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Launch Attendance Terminal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    final selectedColor = isDark ? const Color(0xFF34D399) : AppColors.primary;
    final unselectedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1E33) : Colors.white,
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
            color: isDark
                ? Colors.black38
                : Colors.black.withValues(alpha: 0.04),
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
              color: isSelected ? selectedColor : unselectedColor,
              letterSpacing: -0.3,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 22,
              color: isSelected ? selectedColor : unselectedColor,
            );
          }),
          indicatorColor: selectedColor.withValues(alpha: 0.15),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentNavIndex,
          onDestinationSelected: _onBottomNavTapped,
          elevation: 0,
          backgroundColor: Colors.transparent,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Attendance',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Schedule',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'Counseling',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Feedback',
            ),
          ],
        ),
      ),
    );
  }
}
