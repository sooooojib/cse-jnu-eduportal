import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/role_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../cr/domain/entities/cr_dashboard_data.dart';
import '../../../cr/domain/repositories/cr_repository.dart';
import '../../../cr/domain/usecases/get_cr_dashboard_data_usecase.dart';
import '../../../cr/presentation/controllers/cr_dashboard_controller.dart';
import '../../../cr/presentation/controllers/cr_dashboard_state.dart';
import '../../../cr/presentation/widgets/cr_header_section.dart';
import '../../../cr/presentation/widgets/cr_metrics_grid.dart';
import '../../../cr/presentation/widgets/cr_semester_courses_card.dart';
import '../../../cr/presentation/widgets/cr_today_schedule_card.dart';
import '../../../cr/presentation/widgets/cr_tomorrow_schedule_card.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../curriculum/presentation/widgets/exam_details_dialog.dart';
import '../../../profile/presentation/widgets/student_profile_dialog.dart';
import '../widgets/app_settings_bottom_sheet.dart';

/// Student Dashboard Screen
///
/// Implements the exact same visual architecture, Bento metrics grid,
/// schedule feed, and semester courses cards as the CR Dashboard,
/// styled with the emerald scholar student theme tokens and omitting
/// CR-only administrative controls (e.g. tomorrow schedule broadcast).
class StudentDashboardShell extends StatefulWidget {
  final AuthController authController;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final bool wrapWithScaffold;
  final void Function(int tabIndex)? onNavigateTab;
  final CrDashboardController? controller;

  const StudentDashboardShell({
    super.key,
    required this.authController,
    required this.themeModeNotifier,
    this.wrapWithScaffold = true,
    this.onNavigateTab,
    this.controller,
  });

  @override
  State<StudentDashboardShell> createState() => _StudentDashboardShellState();
}

class _StudentDashboardShellState extends State<StudentDashboardShell> {
  late final CrDashboardController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else if (sl.isRegistered<CrDashboardController>()) {
      _controller = sl<CrDashboardController>();
      _ownsController = false;
    } else if (sl.isRegistered<GetCrDashboardDataUseCase>()) {
      _controller = CrDashboardController(
        getCrDashboardDataUseCase: sl<GetCrDashboardDataUseCase>(),
        authController: widget.authController,
      );
      _ownsController = true;
    } else {
      final user = widget.authController.currentUser;
      _controller = CrDashboardController(
        getCrDashboardDataUseCase: _StubGetCrDashboardDataUseCase(user),
        authController: widget.authController,
      );
      _ownsController = true;
    }
    _controller.loadDashboardData();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Sign Out?',
      message: 'Are you sure you want to end your student session and sign out?',
      confirmText: 'Sign Out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed == true && mounted) {
      await widget.authController.logout();
      if (mounted) {
        context.go(RouteNames.login);
      }
    }
  }

  void _showExamsBottomSheet(List<Exam> exams) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_rounded, color: Color(0xFFDC2626), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Upcoming Exams (${exams.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (exams.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No upcoming exams scheduled for your semester.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: exams.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final ex = exams[i];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                final user = widget.authController.currentUser;
                                await ExamDetailsDialog.show(
                                  context: context,
                                  exam: ex,
                                  userRole: UserRole.student,
                                  userYear: user?.year,
                                  userSemester: user?.semester,
                                  userId: user?.id,
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white12
                                        : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.event_note_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${ex.courseCode}: ${ex.title}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Date: ${ex.examDate} · ${ex.startTime} - ${ex.endTime} (${ex.room})',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Sem ${ex.semester}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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

  void _showSemesterChangeDialog(int currentYear, int currentSemester) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.school_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Academic Term Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Active Cohort: Year $currentYear, Semester $currentSemester.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 10),
              const Text(
                'To petition for a semester upgrade or update class allocation records, you can visit the Profile portal.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push(RouteNames.studentProfile);
              },
              child: const Text('Open Profile & Petition'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final User? currentUser = widget.authController.currentUser;
    final initials = currentUser != null && currentUser.fullName.isNotEmpty
        ? currentUser.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'ST';

    final content = ValueListenableBuilder<CrDashboardState>(
      valueListenable: _controller,
      builder: (context, state, _) {
        if (state is CrDashboardLoading) {
          return const AppLoadingView(
            message: 'Loading Student Dashboard...',
          );
        }

        if (state is CrDashboardError) {
          return AppErrorStateView(
            title: 'Unable to Load Student Dashboard',
            message: state.message,
            retryText: 'Retry',
            onRetry: () => _controller.loadDashboardData(),
          );
        }

        if (state is CrDashboardLoaded) {
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
                  // 1. Header Section
                  CrHeaderSection(
                    data: data,
                    onRequestSemesterChange: () =>
                        _showSemesterChangeDialog(data.year, data.semester),
                  ),

                  const SizedBox(height: 18),

                  // 2. Metrics Grid (Bento Style: Attendance, Classes Today, Counseling, Upcoming Exams)
                  CrMetricsGrid(
                    data: data,
                    onAttendanceTap: () => widget.onNavigateTab != null
                        ? widget.onNavigateTab!(1)
                        : context.push(RouteNames.attendanceTerminal),
                    onClassesTodayTap: () => widget.onNavigateTab != null
                        ? widget.onNavigateTab!(2)
                        : context.push(RouteNames.schedule),
                    onCounselingTap: () => widget.onNavigateTab != null
                        ? widget.onNavigateTab!(3)
                        : context.push(RouteNames.counseling),
                    onUpcomingExamsTap: () => _showExamsBottomSheet(data.upcomingExams),
                  ),

                  const SizedBox(height: 20),

                  // 3. Today's Schedule Card
                  CrTodayScheduleCard(
                    data: data,
                    onViewFullSchedule: () => widget.onNavigateTab != null
                        ? widget.onNavigateTab!(2)
                        : context.push(RouteNames.schedule),
                  ),

                  const SizedBox(height: 20),

                  // 4. Tomorrow's Schedule Card (Next-Day Timeline)
                  CrTomorrowScheduleCard(
                    data: data,
                    isCr: false,
                    onManageTomorrowTap: () {},
                  ),

                  const SizedBox(height: 20),

                  // 4. Semester Courses & Progress
                  CrSemesterCoursesCard(
                    data: data,
                    onCourseTap: () => widget.onNavigateTab != null
                        ? widget.onNavigateTab!(1)
                        : context.push(RouteNames.attendanceTerminal),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );

    if (!widget.wrapWithScaffold) {
      return content;
    }

    final roleColors = RoleColors.forRole(UserRole.student, isDark: isDark);

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FF),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () {
              if (currentUser != null) {
                StudentProfileDialog.show(
                  context: context,
                  student: currentUser,
                  onLogout: _handleLogout,
                );
              }
            },
            child: CircleAvatar(
              backgroundColor: isDark
                  ? roleColors.primary.withValues(alpha: 0.2)
                  : roleColors.background,
              child: Text(
                initials,
                style: TextStyle(
                  color: isDark ? roleColors.text : roleColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
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
        ],
      ),
      body: content,
    );
  }
}

class _StubGetCrDashboardDataUseCase implements GetCrDashboardDataUseCase {
  final User? user;
  _StubGetCrDashboardDataUseCase(this.user);

  @override
  CrRepository get repository => throw UnimplementedError();

  @override
  Future<CrDashboardData> execute({required User crUser, DateTime? currentTime}) async {
    final effectiveUser = user ?? crUser;
    return CrDashboardData(
      crId: effectiveUser.id,
      crName: effectiveUser.fullName,
      email: effectiveUser.email,
      phone: effectiveUser.phone,
      avatarUrl: effectiveUser.avatarUrl,
      role: effectiveUser.role,
      year: effectiveUser.year ?? 1,
      semester: effectiveUser.semester ?? 1,
      studentId: effectiveUser.studentId,
      attendancePercentage: 85.0,
      attendedClasses: 17,
      totalClasses: 20,
      isAttendanceEligible: true,
      classesTodayCount: 0,
      availableCounselingSlotsCount: 0,
      myActiveCounselingCount: 0,
      upcomingExamsCount: 0,
      targetDateLabel: 'Today · Oct 19, 2026',
      dayOfWeek: 'MONDAY',
      tomorrowDateLabel: 'Tomorrow · Oct 20, 2026',
    );
  }
}
