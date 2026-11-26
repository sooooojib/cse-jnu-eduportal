import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/class_time.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../curriculum/data/repositories/class_change_repository.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../curriculum/domain/repositories/curriculum_repository.dart';
import '../../../curriculum/domain/services/effective_schedule.dart';
import '../../../curriculum/presentation/widgets/class_slot_tile.dart';
import '../../../curriculum/presentation/widgets/course_kinds.dart';
import '../../../curriculum/presentation/widgets/time_range_field.dart';
import '../widgets/admin_filter_dropdown.dart';
import '../widgets/signup_approval_dialog.dart' show AcademicLevel;

/// The central weekly routine, one per semester (Year 1 · Semester 1 …
/// Year 4 · Semester 2), set by an admin or the Chairman.
///
/// Every week repeats this routine. CRs and teachers never edit it here;
/// they make one-day changes (extra / cancel / move / not taken) instead,
/// which leave the routine untouched.
class AdminRoutineScreen extends StatefulWidget {
  final CurriculumRepository? curriculum;
  final ClassChangeRepository? changes;

  const AdminRoutineScreen({super.key, this.curriculum, this.changes});

  @override
  State<AdminRoutineScreen> createState() => _AdminRoutineScreenState();
}

class _AdminRoutineScreenState extends State<AdminRoutineScreen> {
  /// Working days first (Sunday–Thursday), then the weekend.
  static const _workingDays = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY'];
  static const _weekend = ['FRIDAY', 'SATURDAY'];

  late final CurriculumRepository _curriculum;
  late final ClassChangeRepository _changes;

  AcademicLevel _level = AcademicLevel.all.first;
  List<ScheduleSlot> _slots = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _curriculum = widget.curriculum ?? sl<CurriculumRepository>();
    _changes = widget.changes ?? sl<ClassChangeRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _curriculum.getSchedule(year: _level.year, semester: _level.semester);
      try {
        final courses = await _curriculum.getAllCourses(year: _level.year, semester: _level.semester);
        CourseKinds.seed({for (final c in courses) c.id: c.isLab});
      } catch (_) {}
      // Only the weekly routine: no one-off (dated) or extra classes.
      final routine = all.where((s) => !s.isExtraClass && (s.date == null || s.date!.isEmpty)).toList();
      if (!mounted) return;
      setState(() {
        _slots = routine;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the routine. ($e)';
      });
    }
  }

  List<ScheduleSlot> _slotsOn(String day) => _slots.where((s) => s.dayOfWeek.toUpperCase() == day).toList()
    ..sort((a, b) => (ClassTime.toMinutes(a.startTime) ?? 0).compareTo(ClassTime.toMinutes(b.startTime) ?? 0));

  Future<void> _openEditor({ScheduleSlot? slot, String? day}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => RoutineSlotEditor(
        level: _level,
        slot: slot,
        initialDay: day ?? slot?.dayOfWeek.toUpperCase() ?? 'SUNDAY',
        curriculum: _curriculum,
        changes: _changes,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(ScheduleSlot s) async {
    final ok = await AppConfirmationDialog.show(
      context: context,
      title: 'Remove from routine?',
      message: '${s.courseCode} on ${_dayLabel(s.dayOfWeek)} at ${ClassTime.normalize(s.startTime)} '
          'will be removed from every week.',
      confirmText: 'Remove',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _curriculum.deleteScheduleSlot(s.id);
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not remove: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  static String _dayLabel(String day) => day.isEmpty ? day : day[0] + day.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final days = [..._workingDays, ..._weekend.where((d) => _slotsOn(d).isNotEmpty)];

    return Scaffold(
      appBar: AppBar(title: const Text('Class Routine')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('routine_add'),
        onPressed: _loading ? null : () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Class'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            AdminFilterDropdown<AcademicLevel>(
              key: const ValueKey('routine_level'),
              label: 'Semester',
              icon: Icons.school_outlined,
              value: _level,
              options: [for (final l in AcademicLevel.all) FilterOption(l, l.label)],
              onChanged: (l) {
                if (l == null || l == _level) return;
                setState(() => _level = l);
                _load();
              },
            ),
            const SizedBox(height: 10),
            Text(
              'This routine repeats every week. CRs and teachers can only make one-day changes on top of it.',
              style: TextStyle(fontSize: 12.5, color: muted),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C)))
            else
              for (final day in days) _dayCard(day, isDark, muted),
            if (!_loading && _error == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openEditor(day: 'SATURDAY'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add a weekend class'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(String day, bool isDark, Color muted) {
    final slots = _slotsOn(day);
    return Container(
      key: ValueKey('routine_day_$day'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_dayLabel(day), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text(
                slots.isEmpty ? 'No classes' : '${slots.length} class${slots.length == 1 ? '' : 'es'}',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              IconButton(
                tooltip: 'Add a class on ${_dayLabel(day)}',
                onPressed: () => _openEditor(day: day),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          for (final s in slots)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: InkWell(
                key: ValueKey('routine_slot_${s.id}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openEditor(slot: s),
                child: ClassSlotTile(
                  slot: s,
                  action: IconButton(
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: () => _delete(s),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Add or edit one weekly routine class for a semester, with a clash check
/// against every batch's routine on that weekday (room, teacher, batch).
class RoutineSlotEditor extends StatefulWidget {
  final AcademicLevel level;
  final ScheduleSlot? slot;
  final String initialDay;
  final CurriculumRepository curriculum;
  final ClassChangeRepository changes;

  const RoutineSlotEditor({
    super.key,
    required this.level,
    required this.initialDay,
    required this.curriculum,
    required this.changes,
    this.slot,
  });

  @override
  State<RoutineSlotEditor> createState() => _RoutineSlotEditorState();
}

class _RoutineSlotEditorState extends State<RoutineSlotEditor> {
  static const _days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];

  List<Course> _courses = const [];
  List<Map<String, String>> _teachers = const [];
  List<ScheduleSlot> _dayRoutine = const []; // all batches, that weekday
  bool _loadingDay = true;
  bool _saving = false;

  late String _day;
  String? _courseId;
  String? _teacherId;
  String? _start;
  String? _end;
  final _roomCtrl = TextEditingController();

  bool get _editing => widget.slot != null;

  @override
  void initState() {
    super.initState();
    final s = widget.slot;
    _day = widget.initialDay.toUpperCase();
    if (s != null) {
      _courseId = s.courseId;
      _teacherId = s.teacherId.isEmpty ? null : s.teacherId;
      _start = ClassTime.normalize(s.startTime);
      _end = ClassTime.normalize(s.endTime);
      _roomCtrl.text = s.room;
    }
    _loadLists();
    _loadDay();
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final results = await Future.wait([
        widget.curriculum.getAllCourses(year: widget.level.year, semester: widget.level.semester),
        widget.curriculum.getAllTeachers(),
      ]);
      if (!mounted) return;
      setState(() {
        _courses = (results[0] as List<Course>)..sort((a, b) => a.code.compareTo(b.code));
        _teachers = (results[1] as List<Map<String, String>>)
          ..sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      });
    } catch (_) {}
  }

  Future<void> _loadDay() async {
    setState(() => _loadingDay = true);
    try {
      final list = await widget.changes.routineForDay(_day);
      if (!mounted) return;
      setState(() {
        _dayRoutine = list;
        _loadingDay = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDay = false);
    }
  }

  Course? get _course => _courses.where((c) => c.id == _courseId).firstOrNull;

  String get _teacherName {
    final t = _teachers.where((t) => t['id'] == _teacherId).firstOrNull;
    if (t != null) return t['name'] ?? '';
    if (_teacherId == _course?.teacherId) return _course?.teacherName ?? '';
    return widget.slot?.teacherName ?? '';
  }

  /// Next date falling on [_day], used to reuse the date-based clash check.
  DateTime get _sampleDate {
    final today = ClassTime.dateOnly(DateTime.now());
    for (var i = 0; i < 7; i++) {
      final d = today.add(Duration(days: i));
      if (ClassTime.dayOfWeek(d) == _day) return d;
    }
    return today;
  }

  List<ScheduleClash> get _clashes {
    if (_start == null || _end == null) return const [];
    // Weekly routine only; one-off dated slots do not block a weekly class.
    final routine = _dayRoutine.where((s) => s.date == null || s.date!.isEmpty).toList();
    return EffectiveSchedule.findClashes(
      routine: routine,
      changes: const [],
      date: _sampleDate,
      startTime: _start!,
      endTime: _end!,
      room: _roomCtrl.text,
      teacherId: _teacherId ?? '',
      targetYear: widget.level.year,
      targetSemester: widget.level.semester,
      ignoreSlotId: widget.slot?.id,
    );
  }

  bool get _canSave =>
      !_saving &&
      !_loadingDay &&
      _courseId != null &&
      _start != null &&
      _end != null &&
      _roomCtrl.text.trim().isNotEmpty &&
      _clashes.isEmpty;

  Future<void> _save() async {
    final c = _course;
    final base = widget.slot;
    final slot = ScheduleSlot(
      id: base?.id ?? '',
      courseId: _courseId!,
      courseCode: c?.code ?? base?.courseCode ?? '',
      courseTitle: c?.title ?? base?.courseTitle ?? '',
      teacherId: _teacherId ?? '',
      teacherName: _teacherName,
      dayOfWeek: _day,
      startTime: _start!,
      endTime: _end!,
      room: _roomCtrl.text.trim(),
      targetYear: widget.level.year,
      targetSemester: widget.level.semester,
      createdBy: base?.createdBy,
    );
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.curriculum.updateScheduleSlot(slot);
      } else {
        await widget.curriculum.createScheduleSlot(slot);
      }
      messenger.showSnackBar(SnackBar(
        content: Text('${slot.courseCode} saved in the routine'),
        backgroundColor: const Color(0xFF047857),
      ));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e'), backgroundColor: const Color(0xFFDC2626)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final clashes = _clashes;
    final teacherIds = _teachers.map((t) => t['id']).toSet();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(_editing ? 'Edit Routine Class' : 'Add Routine Class',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${widget.level.label} · repeats every week', style: TextStyle(fontSize: 12.5, color: muted)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey('routine_course'),
              initialValue: _courses.any((c) => c.id == _courseId) ? _courseId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Course', prefixIcon: Icon(Icons.menu_book_outlined)),
              hint: Text(_courses.isEmpty ? 'No courses for this semester yet' : 'Choose a course'),
              items: [
                for (final c in _courses)
                  DropdownMenuItem(value: c.id, child: Text('${c.code}: ${c.title}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (id) => setState(() {
                _courseId = id;
                final c = _course;
                if (c?.teacherId != null && c!.teacherId!.isNotEmpty) _teacherId = c.teacherId;
              }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('routine_teacher_${_teacherId ?? ''}'),
              initialValue: teacherIds.contains(_teacherId) ? _teacherId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Teacher', prefixIcon: Icon(Icons.person_outline_rounded)),
              hint: const Text('Choose a teacher'),
              items: [
                for (final t in _teachers)
                  DropdownMenuItem(value: t['id'], child: Text(t['name'] ?? '', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (id) => setState(() => _teacherId = id),
            ),
            const SizedBox(height: 16),
            const Text('Day', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in _days)
                  ChoiceChip(
                    key: ValueKey('routine_daychip_$d'),
                    label: Text(d.substring(0, 1) + d.substring(1, 3).toLowerCase()),
                    selected: _day == d,
                    onSelected: (_) {
                      setState(() => _day = d);
                      _loadDay();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Time', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TimeRangeField(
              start: _start,
              end: _end,
              onChanged: (a, b) => setState(() {
                _start = a;
                _end = b;
              }),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('routine_room'),
              controller: _roomCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Room', prefixIcon: Icon(Icons.meeting_room_outlined)),
            ),
            if (clashes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                key: const ValueKey('routine_clashes'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('This time doesn\'t work:',
                        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))),
                    const SizedBox(height: 4),
                    ...clashes.map((c) => Text(
                          '• ${c.message.replaceFirst('Your batch', 'This semester')}',
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
                        )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('routine_save'),
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_editing ? 'Save Changes' : 'Add to Routine'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
