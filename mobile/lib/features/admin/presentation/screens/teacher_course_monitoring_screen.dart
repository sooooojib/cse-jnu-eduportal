import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../../shared/widgets/states/app_empty_state_view.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../curriculum/domain/entities/class_change.dart';
import '../../domain/entities/teacher_monitoring.dart';
import '../../domain/repositories/teacher_monitoring_repository.dart';
import '../widgets/admin_filter_dropdown.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

/// Persists the monitoring period start (usually the semester start date).
class MonitoringPeriodPreference {
  MonitoringPeriodPreference._();

  static const _key = 'teacher_monitoring_period_start';

  static DateTime? read() {
    if (!sl.isRegistered<LocalStorageService>()) return null;
    final raw = sl<LocalStorageService>().getString(_key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<void> write(DateTime? date) async {
    if (!sl.isRegistered<LocalStorageService>()) return;
    final storage = sl<LocalStorageService>();
    if (date == null) {
      await storage.remove(_key);
    } else {
      await storage.setString(_key, DateFormat('yyyy-MM-dd').format(date));
    }
  }
}

/// Chairman / Admin view: how many classes each teacher has delivered per
/// course, progress against the course benchmark, student turnout, and (when a
/// semester start date is set) held vs. scheduled routine classes.
class TeacherCourseMonitoringScreen extends StatefulWidget {
  final TeacherMonitoringRepository? repository;
  final bool showAppBar;

  const TeacherCourseMonitoringScreen({
    super.key,
    this.repository,
    this.showAppBar = true,
  });

  @override
  State<TeacherCourseMonitoringScreen> createState() => _TeacherCourseMonitoringScreenState();
}

class _TeacherCourseMonitoringScreenState extends State<TeacherCourseMonitoringScreen> {
  late final TeacherMonitoringRepository _repository;
  TeacherMonitoringReport? _report;
  bool _isLoading = true;
  String? _error;
  DateTime? _periodStart;
  String? _teacherFilter; // teacherId
  String? _cohortFilter; // "year-semester"

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? sl<TeacherMonitoringRepository>();
    _periodStart = MonitoringPeriodPreference.read();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final report = await _repository.loadReport(periodStart: _periodStart);
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
        if (_teacherFilter != null && !report.teachers.any((t) => t.teacherId == _teacherFilter)) {
          _teacherFilter = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _pickPeriodStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodStart ?? DateTime(now.year, now.month, 1),
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Semester / monitoring start date',
    );
    if (picked == null) return;
    await MonitoringPeriodPreference.write(picked);
    setState(() => _periodStart = picked);
    _load();
  }

  Future<void> _clearPeriodStart() async {
    await MonitoringPeriodPreference.write(null);
    setState(() => _periodStart = null);
    _load();
  }

  List<TeacherDeliverySummary> get _visibleTeachers {
    final report = _report;
    if (report == null) return const [];
    return report.teachers
        .where((t) => _teacherFilter == null || t.teacherId == _teacherFilter)
        .map((t) {
          if (_cohortFilter == null) return t;
          final courses = t.courses.where((c) => '${c.year}-${c.semester}' == _cohortFilter).toList();
          return TeacherDeliverySummary(
            teacherId: t.teacherId,
            teacherName: t.teacherName,
            role: t.role,
            courses: courses,
          );
        })
        .where((t) => _cohortFilter == null || t.courses.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Course Monitoring'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _load,
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && _report == null) {
      return const Center(child: AppLoadingView(message: 'Aggregating class delivery...'));
    }
    if (_error != null && _report == null) {
      return Center(
        child: AppErrorStateView(
          title: 'Unable to Load Monitoring Data',
          message: _error!,
          onRetry: _load,
        ),
      );
    }

    final teachers = _visibleTeachers;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _buildFilters(context),
          const SizedBox(height: 12),
          _buildPeriodBanner(context),
          const SizedBox(height: 12),
          _buildTotals(context, teachers),
          const SizedBox(height: 12),
          if (teachers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: AppEmptyStateView(
                title: 'No Faculty Activity',
                message: 'No teachers or courses match the selected filters.',
              ),
            )
          else
            ...teachers.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TeacherCard(
                    summary: t,
                    hasPeriod: _periodStart != null,
                    onShowHistory: (c) => _showHistory(context, t, c),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final report = _report;
    return Row(
      children: [
        Expanded(
          child: AdminFilterDropdown<String>(
            key: const ValueKey('monitoring_teacher_filter'),
            label: 'Teacher',
            icon: Icons.person_search_outlined,
            value: _teacherFilter,
            options: [
              const FilterOption(null, 'All teachers'),
              ...?report?.teachers.map((t) => FilterOption(t.teacherId, t.teacherName)),
            ],
            onChanged: (v) => setState(() => _teacherFilter = v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AdminFilterDropdown<String>(
            key: const ValueKey('monitoring_semester_filter'),
            label: 'Semester',
            value: _cohortFilter,
            options: [
              const FilterOption(null, 'All semesters'),
              for (var y = 1; y <= 4; y++)
                for (var sem = 1; sem <= 2; sem++) FilterOption('$y-$sem', '$y.$sem'),
            ],
            onChanged: (v) => setState(() => _cohortFilter = v),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPeriod = _periodStart != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: hasPeriod
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
            : (isDark ? const Color(0xFF3B2F0B) : const Color(0xFFFEF3C7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            hasPeriod ? Icons.event_available_outlined : Icons.info_outline_rounded,
            size: 20,
            color: hasPeriod ? const Color(0xFF2563EB) : const Color(0xFFB45309),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasPeriod
                  ? 'Counting classes since ${_dateFmt.format(_periodStart!)}. Missed classes are estimated from the weekly routine.'
                  : 'Showing all-time classes. Set the semester start date to count this semester only and estimate missed routine classes.',
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: _pickPeriodStart,
            child: Text(hasPeriod ? 'Change' : 'Set date'),
          ),
          if (hasPeriod)
            IconButton(
              tooltip: 'Clear start date',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: _clearPeriodStart,
            ),
        ],
      ),
    );
  }

  Widget _buildTotals(BuildContext context, List<TeacherDeliverySummary> teachers) {
    final classes = teachers.fold<int>(0, (s, t) => s + t.totalClassesConducted);
    final courses = teachers.fold<int>(0, (s, t) => s + t.courses.length);
    final missedKnown = teachers.map((t) => t.totalMissedEstimate).whereType<int>().toList();
    final missed = missedKnown.isEmpty ? null : missedKnown.fold<int>(0, (s, m) => s + m);
    final notTaken = teachers.fold<int>(0, (s, t) => s + t.totalNotTaken);

    return Row(
      children: [
        _metric(context, 'Faculty', '${teachers.length}', Icons.groups_2_outlined, const Color(0xFF1D4ED8)),
        const SizedBox(width: 8),
        _metric(context, 'Courses', '$courses', Icons.menu_book_outlined, const Color(0xFF047857)),
        const SizedBox(width: 8),
        _metric(context, 'Classes held', '$classes', Icons.fact_check_outlined, const Color(0xFF7E22CE)),
        const SizedBox(width: 8),
        _metric(context, 'Not taken', '$notTaken', Icons.person_off_outlined, const Color(0xFF9F1239)),
        if (missed != null) ...[
          const SizedBox(width: 8),
          _metric(context, 'Est. missed', '$missed', Icons.event_busy_outlined, const Color(0xFFDC2626)),
        ],
      ],
    );
  }

  Widget _metric(BuildContext context, String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13263E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory(BuildContext context, TeacherDeliverySummary teacher, CourseDeliveryStats course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, controller) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${course.courseCode}: ${course.courseTitle}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${teacher.teacherName} • ${course.classesConducted} held'
                        '${course.emptySessions.isNotEmpty ? ' • ${course.emptySessions.length} empty (0 present)' : ''}'
                        '${course.notTakenCount > 0 ? ' • ${course.notTakenCount} not taken' : ''}'
                        '${course.cancelledCount > 0 ? ' • ${course.cancelledCount} cancelled' : ''}'
                        '${course.extraCount > 0 ? ' • ${course.extraCount} extra' : ''}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _ClassLogList(course: course, controller: controller),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final TeacherDeliverySummary summary;
  final bool hasPeriod;
  final void Function(CourseDeliveryStats course) onShowHistory;

  const _TeacherCard({
    required this.summary,
    required this.hasPeriod,
    required this.onShowHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = UserRole.fromString(summary.role);
    return Material(
      color: isDark ? const Color(0xFF13263E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  summary.teacherName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (role.hasTeacherAccess) RoleBadgeChip(role: role, isCompact: true),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              summary.courses.isEmpty
                  ? 'No assigned courses'
                  : '${summary.totalClassesConducted} classes across ${summary.courses.length} '
                      'course${summary.courses.length == 1 ? '' : 's'}'
                      '${summary.totalNotTaken > 0 ? ' • ${summary.totalNotTaken} not taken' : ''}'
                      '${summary.totalMissedEstimate != null && summary.totalMissedEstimate! > 0 ? ' • ~${summary.totalMissedEstimate} missed' : ''}',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
          ),
          children: [
            for (final c in summary.courses) _CourseRow(course: c, hasPeriod: hasPeriod, onShowHistory: onShowHistory),
          ],
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final CourseDeliveryStats course;
  final bool hasPeriod;
  final void Function(CourseDeliveryStats course) onShowHistory;

  const _CourseRow({required this.course, required this.hasPeriod, required this.onShowHistory});

  Color _progressColor(double p) {
    if (p >= 0.75) return const Color(0xFF059669);
    if (p >= 0.4) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final progress = course.progress;
    final unit = course.isLab ? 'lab sessions' : 'classes';
    final turnout = course.averageTurnout;
    final last = course.lastClassDate == null ? null : DateTime.tryParse(course.lastClassDate!);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1F33) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${course.courseCode}: ${course.courseTitle}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
              if (course.year > 0)
                Text('Y${course.year}S${course.semester}', style: TextStyle(fontSize: 11, color: muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            course.targetClasses != null
                ? 'Classes conducted: ${course.classesConducted} / ${course.targetClasses} $unit'
                : 'Classes conducted: ${course.classesConducted} $unit',
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          if (progress != null)
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      color: _progressColor(progress),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            )
          else
            Text(
              'Target not set. Add a target class count in Course Catalog to track progress.',
              style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: muted),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (hasPeriod && course.expectedClassesSoFar != null)
                _stat(
                  Icons.event_available_outlined,
                  'Held ${course.classesConducted} of ${course.expectedClassesSoFar} scheduled'
                  '${course.missedClassesEstimate! > 0 ? ' (~${course.missedClassesEstimate} missed)' : ''}',
                  course.missedClassesEstimate! > 0 ? const Color(0xFFDC2626) : muted,
                ),
              if (hasPeriod && course.expectedClassesSoFar == null)
                _stat(Icons.event_busy_outlined, 'No weekly routine slots', muted),
              _stat(
                Icons.groups_outlined,
                turnout != null
                    ? 'Avg. turnout ${(turnout * 100).toStringAsFixed(1)}%'
                    : (course.averagePresent != null
                        ? 'Avg. ${course.averagePresent!.toStringAsFixed(1)} present'
                        : 'No attendance yet'),
                muted,
              ),
              if (course.emptySessions.isNotEmpty)
                _stat(
                  Icons.warning_amber_rounded,
                  '${course.emptySessions.length} empty (0 present)',
                  const Color(0xFFD97706),
                ),
              if (course.notTakenCount > 0)
                _stat(
                  Icons.person_off_outlined,
                  '${course.notTakenCount} not taken (reported by CR)',
                  const Color(0xFF9F1239),
                ),
              if (course.cancelledCount > 0)
                _stat(Icons.event_busy_outlined, '${course.cancelledCount} cancelled', muted),
              if (course.extraCount > 0)
                _stat(Icons.add_circle_outline_rounded, '${course.extraCount} extra', muted),
              if (last != null) _stat(Icons.history_rounded, 'Last class ${DateFormat('MMM d').format(last)}', muted),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onShowHistory(course),
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: const Text('Class log'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11.5, color: color)),
      ],
    );
  }
}

/// One line in a course's class log: a held class (from attendance) or a
/// one-day change (extra, cancelled, moved, not taken).
class _LogEntry {
  final String date;
  final DeliveredClass? held;
  final ClassChange? change;
  const _LogEntry.held(this.date, this.held) : change = null;
  const _LogEntry.change(this.date, this.change) : held = null;
}

class _ClassLogList extends StatelessWidget {
  final CourseDeliveryStats course;
  final ScrollController controller;

  const _ClassLogList({required this.course, required this.controller});

  @override
  Widget build(BuildContext context) {
    final entries = <_LogEntry>[
      for (final h in course.history) _LogEntry.held(h.date, h),
      for (final h in course.emptySessions) _LogEntry.held(h.date, h),
      for (final c in course.changes) _LogEntry.change(c.date, c),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (entries.isEmpty) return const Center(child: Text('Nothing recorded yet.'));

    return ListView.separated(
      controller: controller,
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = entries[i];
        final date = DateTime.tryParse(e.date);
        final when = date == null ? e.date : DateFormat('EEE, MMM d, yyyy').format(date);
        final h = e.held;
        if (h != null) {
          final isZeroPresent = h.presentCount == 0;
          final absentCount = (course.cohortSize - h.presentCount).clamp(0, course.cohortSize);
          final countsLabel = course.cohortSize > 0
              ? '${h.presentCount} Present · $absentCount Absent'
              : '${h.presentCount} Present';
          return ListTile(
            dense: true,
            leading: Icon(
              isZeroPresent ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: isZeroPresent ? const Color(0xFFD97706) : const Color(0xFF059669),
            ),
            title: Text(when),
            subtitle: Text(
              isZeroPresent
                  ? '0 Present · Not counted as held'
                  : (h.sessionCount > 1
                      ? 'Held · ${h.sessionCount} sessions (re-launched)'
                      : 'Held'),
            ),
            trailing: Text(
              countsLabel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isZeroPresent ? const Color(0xFFD97706) : null,
              ),
            ),
          );
        }
        final c = e.change!;
        final (color, icon) = switch (c.type) {
          ClassChangeType.notTaken => (const Color(0xFF9F1239), Icons.person_off_outlined),
          ClassChangeType.cancel => (const Color(0xFFDC2626), Icons.event_busy_outlined),
          ClassChangeType.move => (const Color(0xFFD97706), Icons.swap_horiz_rounded),
          ClassChangeType.extra => (const Color(0xFF047857), Icons.add_circle_outline_rounded),
        };
        final detail = c.type == ClassChangeType.move
            ? 'Moved to ${c.startTime}, ${c.room} (was ${c.originalStartTime ?? ''})'
            : '${c.type.label} · ${c.startTime}–${c.endTime}';
        final by = c.createdByName.isNotEmpty ? 'by ${c.createdByName}' : '';
        final reason = (c.reason ?? '').trim();
        return ListTile(
          dense: true,
          leading: Icon(icon, color: color),
          title: Text(when),
          subtitle: Text(
            [detail, if (reason.isNotEmpty) '"$reason"', if (by.isNotEmpty) by].join('\n'),
          ),
          trailing: Text(
            c.type.label,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color),
          ),
        );
      },
    );
  }
}
