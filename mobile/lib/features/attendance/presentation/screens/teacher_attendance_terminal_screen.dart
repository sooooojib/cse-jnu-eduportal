import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/class_time.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../curriculum/data/repositories/class_change_repository.dart';
import '../../../curriculum/data/repositories/holiday_repository.dart';
import '../../../curriculum/domain/services/effective_schedule.dart';
import '../../data/services/attendance_excel_exporter.dart';
import '../../data/services/class_attendance_service.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../controllers/attendance_controller.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

/// The teacher's attendance screen.
///
/// * Start a class in **Code** mode (students type a code that changes every
///   20 s) or **By hand** (call the roll).
/// * The roster updates live as students mark themselves; each tap
///   (Present / Late / Absent) saves on its own.
/// * **Close & save** records everyone left as absent.
/// * Recent classes (7 days) can be reopened to fix mistakes.
/// * Course report: percentages, students below 75%, copy as CSV.
class TeacherAttendanceTerminalScreen extends StatefulWidget {
  final String? preselectedCourseId;

  /// The class (routine / one-day slot) this attendance is for.
  final String? slotId;
  final AttendanceController? controller;
  final AuthController? authController;
  final List<String>? assignedCourseIds;
  final bool showAppBar;

  const TeacherAttendanceTerminalScreen({
    super.key,
    this.preselectedCourseId,
    this.slotId,
    this.controller,
    this.authController,
    this.assignedCourseIds,
    this.showAppBar = true,
  });

  @override
  State<TeacherAttendanceTerminalScreen> createState() =>
      _TeacherAttendanceTerminalScreenState();
}

class _TeacherAttendanceTerminalScreenState
    extends State<TeacherAttendanceTerminalScreen> {
  late final AttendanceController _controller;
  late final AuthController? _authController;

  String? _selectedCourseId;
  String _mode = 'CODE';
  int _selectedDuration = 15;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _ticker;
  List<AttendanceSession> _recent = const [];

  /// Non-expired session found for [_selectedCourseId]; never auto-started on dropdown pick.
  AttendanceSession? _openSessionForCourse;

  /// A past session being corrected (null = today's live flow).
  AttendanceSession? _past;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else if (sl.isRegistered<AttendanceController>()) {
      _controller = sl<AttendanceController>();
    } else {
      final repo = sl.isRegistered<AttendanceRepository>()
          ? sl<AttendanceRepository>()
          : const _FallbackAttendanceRepository();
      _controller = AttendanceController(
        getAttendanceSummaryUseCase: GetAttendanceSummaryUseCase(repo),
        verifyAttendanceCodeUseCase: VerifyAttendanceCodeUseCase(repo),
        startAttendanceSessionUseCase: StartAttendanceSessionUseCase(repo),
        deactivateAttendanceSessionUseCase: DeactivateAttendanceSessionUseCase(
          repo,
        ),
        getActiveAttendanceSessionUseCase: GetActiveAttendanceSessionUseCase(
          repo,
        ),
        getSessionRosterUseCase: GetSessionRosterUseCase(repo),
        updateAttendanceRosterUseCase: UpdateAttendanceRosterUseCase(repo),
        service: sl.isRegistered<ClassAttendanceService>()
            ? sl<ClassAttendanceService>()
            : null,
      );
    }
    _authController =
        widget.authController ??
        (sl.isRegistered<AuthController>() ? sl<AuthController>() : null);
    _selectedCourseId = widget.preselectedCourseId;

    _controller.addListener(_onControllerChanged);
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    // One ticker drives the countdown and the "code changes in" hint.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _controller.activeSession != null) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _initCourseAndSession(),
    );
  }

  List<String> get _assignedIds =>
      widget.assignedCourseIds ??
      _authController?.currentUser?.assignedCourseIds ??
      const [];

  /// The teacher's courses (where they are the course teacher or assigned),
  /// as (id, label). Falls back to the assigned ids when courses can't load.
  List<(String, String)> _courses = const [];

  List<(String, String)> get _courseOptions {
    final list = [..._courses];
    for (final id in _assignedIds) {
      if (list.every((c) => c.$1 != id)) list.add((id, id));
    }
    final sel = _selectedCourseId;
    if (sel != null && list.every((c) => c.$1 != sel)) list.add((sel, sel));
    return list;
  }

  Future<void> _checkOpenSessionForSelectedCourse(String courseId) async {
    final open = await _controller.findOpenSession(courseId);
    if (!mounted || _selectedCourseId != courseId) return;
    setState(() => _openSessionForCourse = open);
  }

  Future<void> _loadCourses() async {
    final user = _authController?.currentUser;
    if (user == null || !sl.isRegistered<ClassChangeRepository>()) return;
    try {
      final list = await sl<ClassChangeRepository>().plannableCourses(user);
      if (!mounted) return;
      setState(() {
        _courses = [
          for (final c in list)
            (c.id, c.title.isNotEmpty ? '${c.title} · ${c.code}' : c.code),
        ];
        if (_selectedCourseId == null && _courses.isNotEmpty) {
          _selectedCourseId = _courses.first.$1;
          _checkOpenSessionForSelectedCourse(_selectedCourseId!);
        }
      });
    } catch (_) {}
  }

  void _initCourseAndSession() {
    if (_selectedCourseId == null && _assignedIds.isNotEmpty) {
      _selectedCourseId = _assignedIds.first;
    }
    if (widget.preselectedCourseId != null) {
      _controller.loadActiveSession(widget.preselectedCourseId!);
    } else if (_selectedCourseId != null) {
      _checkOpenSessionForSelectedCourse(_selectedCourseId!);
    }
    _loadCourses();
    _closeStaleThenLoadRecent();
  }

  /// S2-09: sessions left open (app closed) are closed now, with absences.
  Future<void> _closeStaleThenLoadRecent() async {
    final closed = await _controller.closeStaleSessions();
    if (closed > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Closed $closed earlier class${closed == 1 ? '' : 'es'} left open; unmarked students were recorded absent.'),
      ));
    }
    await _loadRecent();
  }

  Future<void> _closeOne(AttendanceSession s) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.closeSession(s);
      messenger.showSnackBar(const SnackBar(content: Text('Class closed; unmarked students were recorded absent.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not close: ${friendlyError(e)}')));
    }
    await _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final list = await _controller.recentSessions();
      if (mounted) setState(() => _recent = list);
    } catch (_) {}
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.pauseLive();
    if (_controller.hasUnsavedChanges)
      _controller.saveRoster().catchError((_) {});
    _searchController.dispose();
    super.dispose();
  }

  /// Plain-language error (never the raw Firebase text).
  String _err(Object e) {
    final raw = friendlyError(e).trim();
    final lower = raw.toLowerCase();
    if (lower.contains('permission-denied') || lower.contains('permission')) {
      return 'You can\'t change this attendance session. It belongs to another teacher or is already closed.';
    }
    if (lower.contains('unavailable') || lower.contains('network')) {
      return 'No internet connection. Please try again.';
    }
    return (raw.isEmpty || lower == 'internal') ? 'Something went wrong. Please try again.' : raw;
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error
            ? const Color(0xFFDC2626)
            : const Color(0xFF047857),
      ),
    );
  }

  Future<bool> _confirmIfNoScheduledClassToday(String courseId) async {
    if (widget.slotId != null || !sl.isRegistered<ClassChangeRepository>()) {
      return true;
    }
    try {
      final now = ClassTime.now();
      final day = ClassTime.dayOfWeek(now);
      final todayKey = ClassTime.dateKey(now);
      final repo = sl<ClassChangeRepository>();
      final holidays = sl.isRegistered<HolidayRepository>()
          ? await sl<HolidayRepository>().holidayMap()
          : const <String, String>{};
      final holidayReason = holidays[todayKey];
      if (holidayReason != null) {
        if (!mounted) return false;
        final go = await AppConfirmationDialog.show(
          context: context,
          title: 'Today is a holiday',
          message:
              '$holidayReason — no regular classes are scheduled today. Start an extra / makeup attendance session anyway?',
          confirmText: 'Start Anyway',
          icon: Icons.event_busy_outlined,
        );
        return go == true;
      }

      final routineFuture = repo.routineForDay(day);
      final changesFuture = repo.changesOn(now);
      final routine = await routineFuture;
      final changes = await changesFuture;
      final effective = EffectiveSchedule.forDate(
        routine: routine,
        changes: changes,
        date: now,
        holidays: holidays,
      );
      final courseSlots = effective.where((s) => s.courseId == courseId).toList();
      final activeToday = courseSlots.any((s) => !s.isCancelled && !s.isNotTaken);
      if (activeToday) return true;

      if (!mounted) return false;
      final wasCancelled = courseSlots.any((s) => s.isCancelled);
      final go = await AppConfirmationDialog.show(
        context: context,
        title: wasCancelled ? 'Class cancelled today' : 'No class scheduled today',
        message: wasCancelled
            ? 'This course\'s class today was marked cancelled. Start an attendance session anyway?'
            : 'No class is scheduled for this course today. Start an extra / makeup attendance session?',
        confirmText: 'Start Anyway',
        icon: Icons.warning_amber_rounded,
      );
      return go == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _handleStartSession() async {
    if (_selectedCourseId == null) {
      _snack('Choose a course first.', error: true);
      return;
    }
    final proceed = await _confirmIfNoScheduledClassToday(_selectedCourseId!);
    if (!proceed || !mounted) return;
    try {
      await _controller.startSession(
        courseId: _selectedCourseId!,
        durationMinutes: _selectedDuration,
        mode: _mode,
        slotId: widget.slotId,
      );
      if (mounted) {
        _snack(
          _mode == 'MANUAL'
              ? 'Class started. Mark students below.'
              : 'Attendance is open. Show the code to the class.',
        );
      }
    } catch (e) {
      if (mounted) _snack(_err(e), error: true);
    }
  }

  Future<void> _handleDeactivateSession() async {
    final session = _controller.activeSession;
    if (session == null) return;
    final unmarked = _controller.editableRoster
        .where((r) => !r.hasRecord && !r.isPresent)
        .length;
    final confirmed = await AppConfirmationDialog.show(
      context: context,
      title: 'Close attendance?',
      message: session.isManualMode
          ? 'Attendance for this class will be saved. Students not marked present are recorded absent.'
          : 'The code stops working. Students who did not mark ($unmarked) are recorded absent.',
      confirmText: 'Close & Save',
      isDestructive: true,
      icon: Icons.stop_circle_rounded,
    );
    if (confirmed != true || !mounted) return;
    try {
      await _controller.finishSession();
      if (mounted) _snack('Attendance saved.');
      _loadRecent();
    } catch (e) {
      if (mounted) _snack(_err(e), error: true);
    }
  }

  Future<void> _handleSaveRoster() async {
    try {
      await _controller.saveRoster();
      if (mounted) _snack('Attendance roster saved successfully.');
    } catch (e) {
      if (mounted) _snack(_err(e), error: true);
    }
  }

  Future<void> _openPast(AttendanceSession s) async {
    setState(() => _past = s);
    await _controller.openPastSession(s);
  }

  void _closePast() {
    if (_controller.hasUnsavedChanges)
      _controller.saveRoster().catchError((_) {});
    setState(() => _past = null);
    _controller.pauseLive();
    if (_selectedCourseId != null)
      _controller.loadActiveSession(_selectedCourseId!);
    _loadRecent();
  }

  Future<void> _openReport() async {
    final courseId = _selectedCourseId;
    if (courseId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          _CourseReportSheet(load: () => _controller.courseReport(courseId)),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _controller.activeSession;
    final live = active != null && active.isActive;
    final showRoster =
        live || _past != null || _controller.editableRoster.isNotEmpty;
    final roster = _controller.editableRoster.where((r) {
      if (_searchQuery.isEmpty) return true;
      return r.studentName.toLowerCase().contains(_searchQuery) ||
          r.studentRoll.toLowerCase().contains(_searchQuery);
    }).toList();
    final hasService = _controller.service != null;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text('Attendance'))
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_past != null)
              _pastHeader(_past!, isDark)
            else if (live)
              _liveCard(active, isDark)
            else
              _startCard(isDark),
            if (showRoster) ...[
              const SizedBox(height: 18),
              _rosterSection(roster, isDark),
            ],
            if (!live && _past == null && hasService) ...[
              const SizedBox(height: 22),
              _recentSection(isDark),
            ],
          ],
        ),
      ),
      // Without the live service (older setup) the roster is saved with a button.
      bottomNavigationBar: (!hasService && showRoster) ? _saveBar() : null,
    );
  }

  Widget _card(bool isDark, {required Widget child, Key? key}) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF13263E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
      ),
    ),
    child: child,
  );

  Color _muted(bool isDark) =>
      isDark ? Colors.white60 : const Color(0xFF64748B);

  /// Course dropdown (full width, inside the card).
  Widget _coursePicker(bool isDark) {
    final options = _courseOptions;
    if (options.isEmpty) {
      return Text(
        'No courses yet. Ask the admin to set you as the teacher of a course.',
        style: TextStyle(fontSize: 13, color: _muted(isDark)),
      );
    }
    return DropdownButtonFormField<String>(
      key: const ValueKey('attendance_course'),
      initialValue: options.any((o) => o.$1 == _selectedCourseId)
          ? _selectedCourseId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Course',
        prefixIcon: Icon(Icons.menu_book_outlined),
      ),
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o.$1,
            child: Text(o.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id == null || id == _selectedCourseId) return;
        setState(() {
          _selectedCourseId = id;
          _openSessionForCourse = null;
        });
        _checkOpenSessionForSelectedCourse(id);
      },
    );
  }

  /// A full-width row of equal choices (e.g. 10 / 15 / 30 min).
  Widget _choiceRow<T>({
    required Key key,
    required List<(T, String)> options,
    required T value,
    required ValueChanged<T> onChanged,
  }) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        key: key,
        showSelectedIcon: false,
        segments: [
          for (final o in options)
            ButtonSegment(value: o.$1, label: Text(o.$2)),
        ],
        selected: {value},
        onSelectionChanged: (sel) => onChanged(sel.first),
      ),
    );
  }

  Widget _startCard(bool isDark) {
    final muted = _muted(isDark);
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
    );
    return _card(
      isDark,
      key: const ValueKey('attendance_start_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Take Attendance',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            _mode == 'MANUAL'
                ? 'Call the roll and mark each student. No code needed.'
                : 'Students type the code on your screen. It changes every 20 seconds.',
            style: TextStyle(fontSize: 12.5, color: muted),
          ),
          const SizedBox(height: 16),
          _coursePicker(isDark),
          if (_controller.service != null) ...[
            label('How students mark'),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                key: const ValueKey('attendance_mode'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'CODE',
                    label: Text('Code'),
                    icon: Icon(Icons.pin_outlined),
                  ),
                  ButtonSegment(
                    value: 'MANUAL',
                    label: Text('By hand'),
                    icon: Icon(Icons.checklist_rounded),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
          ],
          if (_mode == 'CODE') ...[
            label('Code open for'),
            _choiceRow<int>(
              key: const ValueKey('attendance_duration'),
              options: const [(10, '10 min'), (15, '15 min'), (30, '30 min')],
              value: _selectedDuration,
              onChanged: (m) => setState(() => _selectedDuration = m),
            ),
          ],
          if (_openSessionForCourse != null && _openSessionForCourse!.courseId == _selectedCourseId) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_outline_rounded, size: 20, color: Color(0xFF047857)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'An open attendance session is already running for this course.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final s = _openSessionForCourse;
                      if (s != null) {
                        setState(() => _openSessionForCourse = null);
                        _controller.resumeSession(s);
                      }
                    },
                    child: const Text('Resume'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const ValueKey('attendance_start'),
              onPressed:
                  (_controller.isStartingSession || _selectedCourseId == null)
                  ? null
                  : _handleStartSession,
              icon: _controller.isStartingSession
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(
                _controller.isStartingSession
                    ? 'Starting…'
                    : 'Start Attendance Session',
              ),
            ),
          ),
          if (_controller.service != null && _selectedCourseId != null)
            Center(
              child: TextButton.icon(
                key: const ValueKey('attendance_report'),
                onPressed: _openReport,
                icon: const Icon(Icons.insights_outlined, size: 18),
                label: const Text('Course report'),
              ),
            ),
        ],
      ),
    );
  }

  String _mmss(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  Widget _liveCard(AttendanceSession s, bool isDark) {
    final muted = _muted(isDark);
    final left = s.expiresAt?.difference(ClassTime.instant()) ?? Duration.zero;
    final code = _controller.currentCode;
    final issued = _controller.codeIssuedAt;
    final every = ClassAttendanceService.rotateEvery.inSeconds;
    final changesIn = issued == null
        ? null
        : (every - DateTime.now().difference(issued).inSeconds).clamp(0, every);
    final green = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);

    return _card(
      isDark,
      key: const ValueKey('attendance_live_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.courseTitle.isNotEmpty ? s.courseTitle : s.courseCode,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!s.isManualMode)
                Text(
                  left.isNegative || left == Duration.zero
                      ? 'Expired'
                      : 'Closes in ${_mmss(left)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (s.isManualMode)
            Text(
              'Taking attendance by hand. Tap each student below.',
              style: TextStyle(color: muted),
            )
          else ...[
            Center(
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  _snack('Code copied.');
                },
                child: Text(
                  code.split('').join(' '),
                  key: const ValueKey('attendance_code'),
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: green,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                _controller.service == null
                    ? 'Verification code'
                    : 'New code in ${changesIn ?? every}s · keep this screen open',
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Present: ${_controller.presentCount} / ${_controller.editableRoster.length}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!s.isManualMode && _controller.service != null) ...[
                OutlinedButton(
                  key: const ValueKey('attendance_extend'),
                  onPressed: () => _controller.extendSession(minutes: 5),
                  child: const Text('+5 min'),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('attendance_close'),
                  onPressed: _controller.isDeactivatingSession
                      ? null
                      : _handleDeactivateSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.stop_circle_rounded, size: 18),
                  label: Text(
                    _controller.isDeactivatingSession
                        ? 'Saving…'
                        : 'Close & Save',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pastHeader(AttendanceSession s, bool isDark) {
    final d = DateTime.tryParse(s.sessionDate);
    return _card(
      isDark,
      key: const ValueKey('attendance_past_card'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.courseTitle.isNotEmpty ? s.courseTitle : s.courseCode,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${d == null ? s.sessionDate : DateFormat('EEE, MMM d').format(d)} · corrections save automatically',
                  style: TextStyle(fontSize: 12.5, color: _muted(isDark)),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _closePast, child: const Text('Done')),
        ],
      ),
    );
  }

  Widget _rosterSection(List<AttendanceRosterItem> roster, bool isDark) {
    final muted = _muted(isDark);
    final saving = _controller.isSavingRoster || _controller.hasUnsavedChanges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Students (${_controller.editableRoster.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_controller.service != null)
              Text(
                saving
                    ? 'Saving…'
                    : (_controller.lastSaveOk
                          ? 'All changes saved'
                          : 'Not saved – tap again'),
                key: const ValueKey('attendance_save_state'),
                style: TextStyle(
                  fontSize: 12,
                  color: _controller.lastSaveOk
                      ? muted
                      : const Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => _controller.markAll('PRESENT'),
              child: const Text('Mark All Present'),
            ),
            TextButton(
              onPressed: () => _controller.markAll('ABSENT'),
              child: const Text(
                'Mark All Absent',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search name or roll',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        if (_controller.isLoadingRoster)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (roster.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _searchQuery.isEmpty
                  ? 'No students found for this semester.'
                  : 'No students matching "$_searchQuery"',
              style: TextStyle(color: muted),
            ),
          )
        else
          for (final r in roster) _studentRow(r, isDark),
      ],
    );
  }

  Widget _studentRow(AttendanceRosterItem r, bool isDark) {
    final muted = _muted(isDark);
    final tag = r.markedBy == 'SELF'
        ? 'Self'
        : (r.markedBy == 'TEACHER' ? 'By teacher' : null);
    return Container(
      key: ValueKey('student_${r.studentId}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [r.studentRoll, if (tag != null) tag].join(' · '),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          _statusChip(r, 'PRESENT', 'P', const Color(0xFF059669)),
          const SizedBox(width: 4),
          _statusChip(r, 'ABSENT', 'A', const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _statusChip(
    AttendanceRosterItem r,
    String status,
    String short,
    Color color,
  ) {
    final selected = r.status == status;
    return InkWell(
      key: ValueKey('mark_${r.studentId}_$status'),
      borderRadius: BorderRadius.circular(999),
      onTap: () => _controller.setStudentStatus(r.studentId, status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          short,
          semanticsLabel: status,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  Widget _recentSection(bool isDark) {
    final muted = _muted(isDark);
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Classes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          Text(
            'Last 7 days. Open one to fix a mistake.',
            style: TextStyle(fontSize: 12.5, color: muted),
          ),
          const SizedBox(height: 8),
          if (_recent.isEmpty)
            Text('No classes yet.', style: TextStyle(color: muted))
          else
            for (final s in _recent.take(12))
              InkWell(
                key: ValueKey('recent_${s.id}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openPast(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.courseTitle.isNotEmpty
                                  ? s.courseTitle
                                  : s.courseCode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${_dateLabel(s.sessionDate)} · ${s.totalPresentCount} present'
                              '${s.isManualMode ? ' · by hand' : ''}${s.isActive ? ' · open' : ''}',
                              style: TextStyle(fontSize: 12.5, color: muted),
                            ),
                          ],
                        ),
                      ),
                      if (_controller.isStale(s))
                        TextButton(
                          key: ValueKey('close_${s.id}'),
                          onPressed: () => _closeOne(s),
                          child: const Text('Close'),
                        )
                      else
                        Icon(Icons.chevron_right_rounded, color: muted),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _dateLabel(String key) {
    final d = DateTime.tryParse(key);
    return d == null ? key : DateFormat('EEE, MMM d').format(d);
  }

  Widget _saveBar() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _controller.isSavingRoster ? null : _handleSaveRoster,
          icon: const Icon(Icons.save_rounded),
          label: Text(
            _controller.isSavingRoster
                ? 'Saving Roster...'
                : 'Save Attendance (${_controller.presentCount} Present)',
          ),
        ),
      ),
    ),
  );
}

/// Course report: every student's attendance, below-75% first, copy as CSV.
class _CourseReportSheet extends StatefulWidget {
  final Future<CourseAttendanceReport?> Function() load;
  const _CourseReportSheet({required this.load});

  @override
  State<_CourseReportSheet> createState() => _CourseReportSheetState();
}

class _CourseReportSheetState extends State<_CourseReportSheet> {
  CourseAttendanceReport? _report;
  String? _error;
  bool _exporting = false;
  String? _exportMessage;
  bool _exportIsError = false;

  @override
  void initState() {
    super.initState();
    widget
        .load()
        .then((r) {
          if (mounted) setState(() => _report = r);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = friendlyError(e));
        });
  }

  Future<void> _exportExcel(CourseAttendanceReport report) async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _exportMessage = null;
      _exportIsError = false;
    });
    try {
      await AttendanceExcelExporter.exportAndShare(report);
      if (mounted) {
        setState(() {
          _exportMessage = 'Excel sheet ready (${report.courseCode}_attendance.xlsx).';
          _exportIsError = false;
        });
      }
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _exportMessage =
            'App rebuild required: stop the app and run flutter run so new export plugins load.';
        _exportIsError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exportMessage = 'Could not export Excel sheet: ${friendlyError(e)}';
        _exportIsError = true;
      });
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final r = _report;
    final rows = r == null
        ? const <StudentAttendanceRow>[]
        : ([...r.below75, ...r.rows.where((x) => !x.isBelow75)]);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r == null
                            ? 'Course report'
                            : (r.courseTitle.isNotEmpty
                                  ? r.courseTitle
                                  : r.courseCode),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (r != null)
                        Text(
                          '${r.classDates.length} classes held · ${r.below75.length} below 75%',
                          style: TextStyle(fontSize: 12.5, color: muted),
                        ),
                    ],
                  ),
                ),
                if (r != null) ...[
                  FilledButton.tonalIcon(
                    key: const ValueKey('report_export_excel'),
                    onPressed: _exporting ? null : () => _exportExcel(r),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: _exporting
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.table_view_rounded, size: 17),
                    label: Text(_exporting ? 'Exporting...' : 'Export Excel'),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    key: const ValueKey('report_copy_csv'),
                    tooltip: 'Copy CSV',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: r.toCsv()));
                      setState(() {
                        _exportMessage = 'CSV copied. Paste it into Excel or Google Sheets.';
                        _exportIsError = false;
                      });
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 20),
                  ),
                ],
              ],
            ),
          ),
          if (_exportMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _exportIsError
                      ? const Color(0xFFDC2626).withValues(alpha: 0.12)
                      : const Color(0xFF006A4E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _exportMessage!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _exportIsError
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF006A4E),
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _error != null
                ? Center(
                    child: Text(
                      'Could not load the report.',
                      style: TextStyle(color: muted),
                    ),
                  )
                : r == null
                ? const Center(child: CircularProgressIndicator())
                : rows.isEmpty
                ? Center(
                    child: Text(
                      'No students yet.',
                      style: TextStyle(color: muted),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final x = rows[i];
                      final low = x.isBelow75;
                      return ListTile(
                        dense: true,
                        title: Text(
                          x.studentName.isNotEmpty
                              ? x.studentName
                              : x.studentRoll,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${x.studentRoll} · ${x.attended}/${x.held}'),
                        trailing: Text(
                          '${x.percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: low
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF059669),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FallbackAttendanceRepository implements AttendanceRepository {
  const _FallbackAttendanceRepository();

  @override
  Future<AttendanceSummary> getMySummary({int? year, int? semester}) async {
    return const AttendanceSummary(
      overallPercentage: 0,
      totalAttended: 0,
      totalSessions: 0,
      courseSummaries: [],
      recentRecords: [],
    );
  }

  @override
  Future<AttendanceVerificationResult> verifyCode(
    String code, {
    String? courseId,
  }) async {
    return const AttendanceVerificationResult(
      success: false,
      message: 'Not connected',
    );
  }

  @override
  Future<AttendanceSession> startSession({
    required String courseId,
    int? durationMinutes,
  }) async {
    return AttendanceSession(
      id: 'mock_sess',
      courseId: courseId,
      courseCode: courseId,
      courseTitle: courseId,
      teacherId: 'teacher',
      teacherName: 'Faculty',
      code: '000000',
      isActive: true,
      status: 'ACTIVE',
      sessionDate: '2026-10-19',
      totalPresentCount: 0,
      createdAt: '2026-10-19T10:00:00Z',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<void> deactivateSession({required String sessionId}) async {}

  @override
  Future<AttendanceSession?> getActiveSession({
    required String courseId,
  }) async => null;

  @override
  Future<SessionRoster> getSessionRoster({required String sessionId}) async {
    return const SessionRoster(
      sessionId: 'mock_sess',
      courseCode: '',
      courseTitle: '',
      sessionDate: '2026-10-19',
      isActive: false,
      totalEnrolled: 0,
      totalPresent: 0,
      roster: [],
    );
  }

  @override
  Future<void> updateRoster({
    required String sessionId,
    required List<AttendanceRosterItem> updates,
  }) async {}
}
