import 'package:flutter/material.dart';
export 'teacher_requests_view.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../admin/domain/entities/teacher_monitoring.dart';
import '../../../admin/domain/repositories/teacher_monitoring_repository.dart';
import '../../../admin/presentation/controllers/admin_dashboard_controller.dart';
import '../../../admin/presentation/controllers/admin_dashboard_state.dart';
import '../../../admin/presentation/screens/teacher_course_monitoring_screen.dart';
import '../../../admin/presentation/widgets/admin_overview_grid.dart';
import '../../../admin/presentation/widgets/admin_pending_signups_card.dart';
import '../../../admin/presentation/widgets/admin_quick_actions_grid.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

/// "Department Admin" content for the Chairman, rendered inside the faculty
/// dashboard when the Admin View is selected.
class ChairmanAdminView extends StatefulWidget {
  final AdminDashboardController? controller;
  final TeacherMonitoringRepository? monitoringRepository;

  const ChairmanAdminView({super.key, this.controller, this.monitoringRepository});

  @override
  State<ChairmanAdminView> createState() => _ChairmanAdminViewState();
}

class _ChairmanAdminViewState extends State<ChairmanAdminView> {
  late final AdminDashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? sl<AdminDashboardController>();
    _controller.addListener(_onChange);
    _controller.loadDashboard();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    final state = _controller.state;
    if (state is AdminDashboardLoaded) {
      final msg = state.actionSuccessMessage ?? state.actionErrorMessage;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor:
              state.actionSuccessMessage != null ? const Color(0xFF047857) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state is AdminDashboardError) {
      return AppErrorStateView(
        title: 'Unable to Load Department Data',
        message: state.message,
        onRetry: () => _controller.loadDashboard(refresh: true),
      );
    }
    if (state is! AdminDashboardLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: AppLoadingView(message: 'Loading department administration...'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminOverviewGrid(
          stats: state.stats,
          onStudentsTap: () => context.push('${RouteNames.adminUsers}?role=students'),
          onFacultyTap: () => context.push('${RouteNames.adminUsers}?role=faculty'),
          onCrsTap: () => context.push('${RouteNames.adminUsers}?role=cr'),
          onCoursesTap: () => context.push(RouteNames.adminCourses),
          onPendingSignupsTap: () => context.push(RouteNames.adminSignupRequests),
          onPendingSemesterTap: () => context.push(RouteNames.adminSemesterRequests),
          onUsersTap: () => context.push(RouteNames.adminUsers),
        ),
        const SizedBox(height: 20),
        if (state.pendingSignups.isNotEmpty) ...[
          AdminPendingSignupsCard(
            requests: state.pendingSignups,
            onApprove: (req, year, semester) => _controller.approveSignup(
              requestId: req.id,
              assignedYear: year,
              assignedSemester: semester,
            ),
            onReject: (req, reason) => _controller.rejectSignup(requestId: req.id, reason: reason),
            onViewAll: () => context.push(RouteNames.adminSignupRequests),
          ),
          const SizedBox(height: 20),
        ],
        TeacherMonitoringSummaryCard(repository: widget.monitoringRepository),
        const SizedBox(height: 20),
        const AdminQuickActionsGrid(),
      ],
    );
  }
}

/// Compact Chairman overview of teacher class delivery with a link to the
/// full [TeacherCourseMonitoringScreen].
class TeacherMonitoringSummaryCard extends StatefulWidget {
  final TeacherMonitoringRepository? repository;

  const TeacherMonitoringSummaryCard({super.key, this.repository});

  @override
  State<TeacherMonitoringSummaryCard> createState() => _TeacherMonitoringSummaryCardState();
}

class _TeacherMonitoringSummaryCardState extends State<TeacherMonitoringSummaryCard> {
  TeacherMonitoringReport? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = widget.repository ?? sl<TeacherMonitoringRepository>();
      final report = await repo.loadReport(periodStart: MonitoringPeriodPreference.read());
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final report = _report;

    // Only teachers whose courses have targets set can be ranked by progress.
    final withTargets = report?.teachers.where((t) => t.overallProgress != null).toList() ?? const [];
    final lagging = [...withTargets]..sort((a, b) => a.overallProgress!.compareTo(b.overallProgress!));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, color: Color(0xFF4338CA)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Teacher Class Delivery',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => context.push(RouteNames.adminTeacherMonitoring),
                child: const Text('Open'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_error != null)
            Text('Could not load delivery data.', style: TextStyle(fontSize: 12, color: muted))
          else if (report == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else ...[
            Text(
              '${report.totalClassesConducted} classes held across ${report.courseCount} course assignments'
              '${report.periodStart == null ? ' (all time)' : ' this period'}',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
            if (lagging.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Lowest syllabus progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted)),
              const SizedBox(height: 6),
              for (final t in lagging.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(t.teacherName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        flex: 2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: t.overallProgress!,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(t.overallProgress! * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
