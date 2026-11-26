import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/role_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/cache_metadata.dart';
import '../../../../core/utils/avatar_image_resolver.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../../shared/widgets/states/cached_data_badge.dart';
import '../../../../shared/widgets/theme/theme_toggle_button.dart';
import '../../../attendance/domain/entities/attendance_entities.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../curriculum/presentation/widgets/class_change_sheet.dart';
import '../../../curriculum/presentation/widgets/class_changes_card.dart';
import '../../../curriculum/presentation/widgets/exam_details_dialog.dart';
import '../../../curriculum/presentation/widgets/exam_form_dialog.dart';
import '../../../curriculum/presentation/widgets/exam_tile.dart';
import '../../../profile/presentation/widgets/student_profile_dialog.dart';
import '../controllers/cr_dashboard_controller.dart';
import '../controllers/cr_dashboard_state.dart';
import 'cr_header_section.dart';
import 'cr_metrics_grid.dart';
import 'cr_semester_courses_card.dart';
import 'cr_today_schedule_card.dart';
import 'cr_transfer_cards.dart';

/// Shared home view for both regular Students and Class Representatives (CRs).
///
/// Renders identical cards, metrics, live-attendance prompt, holiday banner,
/// today/tomorrow effective routine, class-change feed, and semester courses;
/// CR mode only unlocks one-day class-change creation, exam scheduling, and the
/// standalone CR bottom-nav fallback when [wrapWithScaffold] is true.
class BatchDashboardView extends StatefulWidget {
  final CrDashboardController controller;
  final AuthController? authController;
  final bool isCrMode;
  final bool wrapWithScaffold;
  final void Function(int tabIndex)? onNavigateTab;

  const BatchDashboardView({
    super.key,
    required this.controller,
    this.authController,
    required this.isCrMode,
    this.wrapWithScaffold = false,
    this.onNavigateTab,
  });

  @override
  State<BatchDashboardView> createState() => _BatchDashboardViewState();
}

class _BatchDashboardViewState extends State<BatchDashboardView> {
  final _changesKey = GlobalKey<ClassChangesCardState>();
  int _currentBottomNavIndex = 0;

  AuthController? get _auth =>
      widget.authController ??
      (sl.isRegistered<AuthController>() ? sl<AuthController>() : null);

  User? get _currentUser =>
      widget.controller.currentCrUser ?? _auth?.currentUser;

  Future<void> _handleLogout() async {
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Sign Out?',
      message: widget.isCrMode
          ? 'Are you sure you want to end your CR session and sign out?'
          : 'Are you sure you want to end your student session and sign out?',
      confirmText: 'Sign Out',
      isDestructive: true,
      icon: Icons.logout_rounded,
    );

    if (confirmed == true && mounted) {
      await _auth?.logout();
      if (mounted) {
        context.go(RouteNames.login);
      }
    }
  }

  void _handleBottomNavTap(int index) {
    if (index == _currentBottomNavIndex) return;
    setState(() => _currentBottomNavIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        context.push(RouteNames.attendanceTerminal);
        setState(() => _currentBottomNavIndex = 0);
        break;
      case 2:
        context.push(RouteNames.schedule);
        setState(() => _currentBottomNavIndex = 0);
        break;
      case 3:
        context.push(RouteNames.counseling);
        setState(() => _currentBottomNavIndex = 0);
        break;
      case 4:
        context.push(RouteNames.feedback);
        setState(() => _currentBottomNavIndex = 0);
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
                          if (widget.isCrMode)
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFDC2626)),
                              tooltip: 'Schedule New Exam',
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                final user = _currentUser;
                                final created = await ExamFormDialog.show(
                                  context: context,
                                  userRole: UserRole.cr,
                                  defaultYear: user?.year,
                                  defaultSemester: user?.semester,
                                );
                                if (created == true) {
                                  widget.controller.loadDashboardData();
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
                          // Same calm exam card as the Exam Schedule: shows
                          // "in 3 days", and cancelled / postponed notes.
                          return ExamTile(
                            exam: ex,
                            onTap: () async {
                              Navigator.of(ctx).pop();
                              final user = _currentUser;
                              final changed = await ExamDetailsDialog.show(
                                context: context,
                                exam: ex,
                                userRole: widget.isCrMode ? UserRole.cr : UserRole.student,
                                userYear: user?.year,
                                userSemester: user?.semester,
                                userId: user?.id,
                              );
                              if (changed == true) {
                                widget.controller.loadDashboardData();
                              }
                            },
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
                shape: const StadiumBorder(),
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

  void _openAttendanceTab() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
    } else {
      context.push(RouteNames.attendanceTerminal);
    }
  }

  void _openScheduleTab() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(2);
    } else {
      context.push(RouteNames.schedule);
    }
  }

  void _openCounselingTab() {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(3);
    } else {
      context.push(RouteNames.counseling);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _currentUser;
    final defaultInitial = widget.isCrMode ? 'CR' : 'S';
    final initials = currentUser != null && currentUser.fullName.isNotEmpty
        ? currentUser.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : defaultInitial;

    final content = ValueListenableBuilder<CrDashboardState>(
      valueListenable: widget.controller,
      builder: (context, state, _) {
        if (state is CrDashboardLoading) {
          return AppLoadingView(
            message: widget.isCrMode
                ? 'Loading Class Representative Dashboard...'
                : 'Loading Student Dashboard...',
          );
        }

        if (state is CrDashboardError) {
          return AppErrorStateView(
            title: widget.isCrMode ? 'Unable to Load CR Dashboard' : 'Unable to Load Dashboard',
            message: state.message,
            retryText: 'Retry',
            onRetry: () => widget.controller.loadDashboardData(),
          );
        }

        if (state is CrDashboardLoaded) {
          final data = state.data;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => widget.controller.refreshData(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.isFromCache)
                    CachedDataBadge(
                      metadata: CacheMetadata.cached(
                        message: widget.isCrMode
                            ? 'Showing cached CR dashboard (Offline)'
                            : 'Showing cached dashboard (Offline)',
                      ),
                      onRefresh: () => widget.controller.refreshData(),
                    ),

                  // 1. Header Section
                  CrHeaderSection(
                    data: data,
                    onRequestSemesterChange: () =>
                        _showSemesterChangeDialog(data.year, data.semester),
                  ),

                  // 1b. Live Attendance Open Now banner (jumps straight to Attendance tab)
                  if (data.openAttendanceSessions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _LiveAttendanceBanner(
                      sessions: data.openAttendanceSessions,
                      onTap: _openAttendanceTab,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // 1c. My Class card (classmates list + CR role transfer)
                  const MyClassCard(),

                  const SizedBox(height: 18),

                  // 2. Metrics Grid (Bento Style)
                  CrMetricsGrid(
                    data: data,
                    onAttendanceTap: _openAttendanceTab,
                    onClassesTodayTap: _openScheduleTab,
                    onCounselingTap: _openCounselingTab,
                    onUpcomingExamsTap: () => _showExamsBottomSheet(data.upcomingExams),
                  ),

                  const SizedBox(height: 20),

                  // 2b. Holiday notice if Today / Tomorrow is marked a department holiday
                  if (data.activeHolidayTitle != null) ...[
                    _HolidayBanner(
                      title: data.activeHolidayTitle!,
                      isTomorrow: data.isTomorrow,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3. Classes card (Today | Tomorrow)
                  CrTodayScheduleCard(
                    data: data,
                    user: currentUser,
                    onChanged: widget.isCrMode
                        ? () {
                            widget.controller.refreshData();
                            _changesKey.currentState?.reload();
                          }
                        : null,
                    onViewFullSchedule: _openScheduleTab,
                    onManageTomorrowTap: widget.isCrMode
                        ? () async {
                            if (currentUser == null) return;
                            final saved = await ClassChangeSheet.show(
                              context,
                              user: currentUser,
                              initialDate: DateTime.now().add(const Duration(days: 1)),
                            );
                            if (saved == true) {
                              widget.controller.refreshData();
                              _changesKey.currentState?.reload();
                            }
                          }
                        : null,
                  ),

                  const SizedBox(height: 20),

                  // 4. One-day changes for the next 7 days
                  if (currentUser != null) ...[
                    ClassChangesCard(
                      key: _changesKey,
                      user: currentUser,
                      onChanged: () => widget.controller.refreshData(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 5. Semester Courses & Progress
                  CrSemesterCoursesCard(
                    data: data,
                    onCourseTap: _openAttendanceTab,
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

    final roleColors = RoleColors.forRole(
      widget.isCrMode ? UserRole.cr : UserRole.student,
      isDark: isDark,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 16,
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
            child: Center(
              child: Builder(
                builder: (context) {
                  final avatarProvider = AvatarImageResolver.resolve(currentUser?.avatarUrl);
                  return CircleAvatar(
                    backgroundColor: widget.isCrMode
                        ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFFEDD5))
                        : (isDark ? roleColors.primary.withValues(alpha: 0.2) : roleColors.background),
                    backgroundImage: avatarProvider,
                    onBackgroundImageError: avatarProvider != null ? (_, __) {} : null,
                    child: avatarProvider == null
                        ? Text(
                            initials,
                            style: TextStyle(
                              color: widget.isCrMode
                                  ? (isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C))
                                  : (isDark ? roleColors.text : roleColors.primary),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
        ),
        title: Text(
          'JnU EduPortal',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
          if (widget.isCrMode) const SizedBox(width: 8),
        ],
      ),
      body: content,
      bottomNavigationBar: widget.isCrMode ? _buildCrBottomNav(context, isDark) : null,
    );
  }

  Widget _buildCrBottomNav(BuildContext context, bool isDark) {
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

/// Calm card used for the dashboard notices (white / dark card, thin border,
/// one plain icon) so they match the rest of the app.
BoxDecoration _noticeDecoration(bool isDark) => BoxDecoration(
      color: isDark ? const Color(0xFF13263E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
    );

class _LiveAttendanceBanner extends StatelessWidget {
  final List<AttendanceSession> sessions;
  final VoidCallback onTap;

  const _LiveAttendanceBanner({required this.sessions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final codes = sessions.map((s) => s.courseCode.isNotEmpty ? s.courseCode : s.courseId).join(', ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('live_attendance_banner'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: _noticeDecoration(isDark),
          child: Row(
            children: [
              Icon(Icons.pin_outlined, color: green, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sessions.length == 1
                          ? 'Attendance Open Now'
                          : 'Attendance Open (${sessions.length} Classes)',
                      style: TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$codes — Tap to enter class code',
                      style: TextStyle(color: muted, fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _HolidayBanner extends StatelessWidget {
  final String title;
  final bool isTomorrow;

  const _HolidayBanner({required this.title, required this.isTomorrow});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _noticeDecoration(isDark),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isTomorrow ? 'Tomorrow' : 'Today'} is a Holiday: $title',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text('No regular classes are scheduled.', style: TextStyle(fontSize: 12.5, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
