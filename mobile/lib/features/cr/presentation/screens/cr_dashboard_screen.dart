import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../controllers/cr_dashboard_controller.dart';
import '../controllers/cr_dashboard_state.dart';
import '../widgets/cr_add_slot_dialog.dart';
import '../widgets/cr_header_section.dart';
import '../widgets/cr_metrics_grid.dart';
import '../widgets/cr_semester_courses_card.dart';
import '../widgets/cr_today_schedule_card.dart';
import '../widgets/cr_tomorrow_schedule_card.dart';
import '../../../dashboard/presentation/widgets/app_settings_bottom_sheet.dart';
import '../../../profile/presentation/widgets/student_profile_dialog.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../curriculum/presentation/widgets/exam_details_dialog.dart';
import '../../../curriculum/presentation/widgets/exam_form_dialog.dart';

class CrDashboardScreen extends StatefulWidget {
  final CrDashboardController? controller;
  final bool wrapWithScaffold;
  final void Function(int tabIndex)? onNavigateTab;

  const CrDashboardScreen({
    super.key,
    this.controller,
    this.wrapWithScaffold = true,
    this.onNavigateTab,
  });

  @override
  State<CrDashboardScreen> createState() => _CrDashboardScreenState();
}

class _CrDashboardScreenState extends State<CrDashboardScreen> {
  late final CrDashboardController _controller;
  int _currentBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? sl<CrDashboardController>();
    _controller.loadDashboardData();
  }

  Future<void> _handleLogout() async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Sign Out?',
      message: 'Are you sure you want to end your CR session and sign out?',
      confirmText: 'Sign Out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed == true && mounted) {
      final auth = sl<AuthController>();
      await auth.logout();
      if (mounted) {
        context.go(RouteNames.login);
      }
    }
  }

  void _handleBottomNavTap(int index) {
    if (index == 0) return; // Already on dashboard
    setState(() => _currentBottomNavIndex = index);

    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(index);
      return;
    }

    switch (index) {
      case 1:
        context.push(RouteNames.attendanceTerminal);
        break;
      case 2:
        context.push(RouteNames.schedule);
        break;
      case 3:
        context.push(RouteNames.counseling);
        break;
      case 4:
        context.push(RouteNames.feedback);
        break;
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
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFDC2626)),
                            tooltip: 'Schedule New Exam',
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              final user = sl<AuthController>().currentUser;
                              final created = await ExamFormDialog.show(
                                context: context,
                                userRole: UserRole.cr,
                                defaultYear: user?.year,
                                defaultSemester: user?.semester,
                              );
                              if (created == true) {
                                _controller.loadDashboardData();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
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
                                final user = sl<AuthController>().currentUser;
                                final changed = await ExamDetailsDialog.show(
                                  context: context,
                                  exam: ex,
                                  userRole: UserRole.cr,
                                  userYear: user?.year,
                                  userSemester: user?.semester,
                                  userId: user?.id,
                                );
                                if (changed == true) {
                                  _controller.loadDashboardData();
                                }
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
    final User? currentUser = _controller.currentCrUser;
    final initials = currentUser != null && currentUser.fullName.isNotEmpty
        ? currentUser.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'CR';

    final content = ValueListenableBuilder<CrDashboardState>(
      valueListenable: _controller,
      builder: (context, state, _) {
        if (state is CrDashboardLoading) {
          return const AppLoadingView(
            message: 'Loading Class Representative Dashboard...',
          );
        }

        if (state is CrDashboardError) {
          return AppErrorStateView(
            title: 'Unable to Load CR Dashboard',
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

                  // 2. Metrics Grid (Bento Style)
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

                  // 3. CR Tomorrow Schedule Card with WhatsApp Broadcaster
                  CrTomorrowScheduleCard(
                    data: data,
                    onManageTomorrowTap: () {
                      CrAddSlotDialog.show(
                        context,
                        data: data,
                        onAddSlot: (slot) => _controller.addTomorrowSlot(slot),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // 4. Today's Schedule Card
                  CrTodayScheduleCard(
                    data: data,
                    onViewFullSchedule: () => widget.onNavigateTab != null
                        ? widget.onNavigateTab!(2)
                        : context.push(RouteNames.schedule),
                  ),

                  const SizedBox(height: 20),

                  // 5. Semester Courses & Progress
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
              backgroundColor: isDark ? const Color(0xFF451A03) : const Color(0xFFFFEDD5),
              child: Text(
                initials,
                style: TextStyle(
                  color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
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
          const SizedBox(width: 8),
        ],
      ),
      body: content,
      bottomNavigationBar: _buildBottomNav(context, isDark),
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: _currentBottomNavIndex,
        onDestinationSelected: _handleBottomNavTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fingerprint_outlined),
            selectedIcon: Icon(Icons.fingerprint_rounded, color: AppColors.primary),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology_rounded, color: AppColors.primary),
            label: 'Counseling',
          ),
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review_rounded, color: AppColors.primary),
            label: 'Feedback',
          ),
        ],
      ),
    );
  }
}
