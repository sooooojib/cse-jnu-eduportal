import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/class_time.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/exam_support_repository.dart';
import '../../data/repositories/holiday_repository.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/services/effective_schedule.dart';
import '../../domain/services/exam_rules.dart';
import '../controllers/schedule_controller.dart';
import 'time_range_field.dart';

/// Schedule or edit an exam. Same calm style as the class forms:
/// type, course, title, date, From / To, room (with suggestions), invigilator,
/// instructions, and a clash check before saving.
///
/// * Admin / Chairman: any semester and course.
/// * Teacher: only their own courses (the semester comes from the course).
/// * CR: their own semester; every type except Final.
///
/// Changing the date or start time of an existing exam records where it was
/// ("Postponed from …"). After saving, the semester's students are notified.
class ExamFormDialog extends StatefulWidget {
  final Exam? existingExam;
  final UserRole userRole;
  final int? defaultYear;
  final int? defaultSemester;
  final String? preselectedTeacherId;
  final String? preselectedTeacherName;
  final List<String>? teacherAssignedCourseIds;

  const ExamFormDialog({
    super.key,
    this.existingExam,
    required this.userRole,
    this.defaultYear,
    this.defaultSemester,
    this.preselectedTeacherId,
    this.preselectedTeacherName,
    this.teacherAssignedCourseIds,
  });

  static Future<bool?> show({
    required BuildContext context,
    Exam? existingExam,
    required UserRole userRole,
    int? defaultYear,
    int? defaultSemester,
    String? preselectedTeacherId,
    String? preselectedTeacherName,
    List<String>? teacherAssignedCourseIds,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ExamFormDialog(
        existingExam: existingExam,
        userRole: userRole,
        defaultYear: defaultYear,
        defaultSemester: defaultSemester,
        preselectedTeacherId: preselectedTeacherId,
        preselectedTeacherName: preselectedTeacherName,
        teacherAssignedCourseIds: teacherAssignedCourseIds,
      ),
    );
  }

  @override
  State<ExamFormDialog> createState() => _ExamFormDialogState();
}

class _ExamFormDialogState extends State<ExamFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final ExamsController _examsController;
  ExamSupportRepository? _support;
  User? _user;

  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _invigilatorController = TextEditingController();
  TextEditingController? _roomController;

  Course? _selectedCourse;
  String _type = 'MID_TERM';
  late DateTime _date;
  String? _start;
  String? _end;
  String _initialRoom = '';
  late int _year;
  late int _semester;

  List<Course> _courses = [];
  List<String> _rooms = [];
  List<Exam> _examsThatDay = const [];
  List<ScheduleSlot> _classesThatDay = const [];
  bool _loadingCourses = true;
  bool _submitting = false;
  String? _formError;

  bool get _isEdit => widget.existingExam != null;
  bool get _isCr => widget.userRole == UserRole.cr;
  bool get _isTeacherOnly => widget.userRole.hasTeacherAccess && !widget.userRole.hasAdminAccess;
  bool get _isAdmin => widget.userRole.hasAdminAccess;

  List<String> get _types => _isCr ? ExamTypes.all.where((t) => t != 'FINAL').toList() : ExamTypes.all;

  @override
  void initState() {
    super.initState();
    _examsController = sl<ExamsController>();
    _support = sl.isRegistered<ExamSupportRepository>() ? sl<ExamSupportRepository>() : null;
    _loadHolidays();
    _user = sl.isRegistered<AuthController>() ? sl<AuthController>().currentUser : null;

    final e = widget.existingExam;
    _year = e?.year ?? widget.defaultYear ?? _user?.year ?? 1;
    _semester = e?.semester ?? widget.defaultSemester ?? _user?.semester ?? 1;
    _type = e?.type ?? 'MID_TERM';
    if (!_types.contains(_type) && !_isEdit) _type = _types.first;
    final preset = ExamTypes.preset(_type);
    _titleController.text = e?.title ?? preset.$1;
    _instructionsController.text = e?.instructions ?? '';
    _invigilatorController.text = e?.invigilatorName ?? widget.preselectedTeacherName ?? '';
    _initialRoom = e?.room ?? '';
    _date = DateTime.tryParse(e?.examDate ?? '') ?? ClassTime.dateOnly(DateTime.now()).add(const Duration(days: 1));
    _start = e == null ? '10:00 AM' : ClassTime.normalize(e.startTime);
    _end = e == null ? ClassTime.format(600 + preset.$2) : ClassTime.normalize(e.endTime);

    _loadCourses();
    _loadRooms();
    _loadDay();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _invigilatorController.dispose();
    super.dispose();
  }

  // ─── Data ──────────────────────────────────────────────────────────────

  Future<void> _loadCourses() async {
    setState(() => _loadingCourses = true);
    try {
      List<Course> list;
      if (_isTeacherOnly) {
        // Teachers: only their own courses, any semester.
        final all = await _examsController.fetchAvailableCourses();
        final uid = _user?.id ?? widget.preselectedTeacherId;
        final assigned = {...?widget.teacherAssignedCourseIds, ...?_user?.assignedCourseIds};
        list = all.where((c) => c.teacherId == uid || assigned.contains(c.id)).toList();
      } else {
        list = await _examsController.fetchAvailableCourses(year: _year, semester: _semester);
      }
      list.sort((a, b) => a.code.compareTo(b.code));
      if (!mounted) return;
      setState(() {
        _courses = list;
        final e = widget.existingExam;
        _selectedCourse = e != null
            ? list.where((c) => c.id == e.courseId || c.code == e.courseCode).firstOrNull
            : (list.isNotEmpty ? list.first : null);
        _applyCourseSemester();
        _loadingCourses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCourses = false;
        _formError = 'Could not load the courses.';
      });
    }
  }

  /// For teachers the semester follows the chosen course.
  void _applyCourseSemester() {
    final c = _selectedCourse;
    if (c != null && _isTeacherOnly) {
      _year = c.year;
      _semester = c.semester;
    }
  }

  Future<void> _loadRooms() async {
    final s = _support;
    if (s == null) return;
    try {
      final rooms = await s.knownRooms();
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {}
  }

  /// S2-13: department holidays, to warn when an exam falls on one.
  Map<String, String> _holidays = const {};

  Future<void> _loadHolidays() async {
    if (!sl.isRegistered<HolidayRepository>()) return;
    try {
      final map = await sl<HolidayRepository>().holidayMap();
      if (mounted) setState(() => _holidays = map);
    } catch (_) {}
  }

  String? get _holidayTitle => _holidays[ClassTime.dateKey(_date)];

  Future<void> _loadDay() async {
    final s = _support;
    if (s == null) return;
    try {
      final key = ClassTime.dateKey(_date);
      final results = await Future.wait([s.examsOn(key), s.classesOn(_date)]);
      if (!mounted) return;
      setState(() {
        _examsThatDay = results[0] as List<Exam>;
        _classesThatDay = results[1] as List<ScheduleSlot>;
      });
    } catch (_) {
      // Without the data the server rules still apply; the clash check is skipped.
    }
  }

  // ─── Building the exam ─────────────────────────────────────────────────

  String get _room => (_roomController?.text ?? _initialRoom).trim();

  Exam? get _draft {
    final c = _selectedCourse;
    if (c == null || _start == null || _end == null) return null;
    final old = widget.existingExam;
    final key = ClassTime.dateKey(_date);
    final moved = old != null && (old.examDate != key || ClassTime.normalize(old.startTime) != _start);
    final teacherSelf = widget.userRole.hasTeacherAccess ? (_user?.id ?? widget.preselectedTeacherId) : null;
    return Exam(
      id: old?.id ?? '',
      courseId: c.id,
      courseCode: c.code,
      courseTitle: c.title,
      title: _titleController.text.trim(),
      examDate: key,
      startTime: _start!,
      endTime: _end!,
      room: _room,
      // Always the course's own semester (the rules require it).
      year: c.year,
      semester: c.semester,
      type: _type,
      instructions: _instructionsController.text.trim().isEmpty ? null : _instructionsController.text.trim(),
      invigilatorName: _invigilatorController.text.trim().isEmpty ? null : _invigilatorController.text.trim(),
      invigilatorId: old?.invigilatorId ?? teacherSelf,
      createdBy: old?.createdBy ?? _user?.id,
      creatorRole: old?.creatorRole ?? widget.userRole.value,
      // Editing a cancelled exam reschedules it.
      status: 'SCHEDULED',
      statusNote: old?.isCancelled == true ? '' : old?.statusNote,
      previousDate: moved ? old.examDate : old?.previousDate,
      previousStartTime: moved ? ClassTime.normalize(old.startTime) : old?.previousStartTime,
    );
  }

  List<ScheduleClash> get _clashes {
    final d = _draft;
    if (d == null) return const [];
    return ExamClashes.find(exam: d, examsThatDay: _examsThatDay, classesThatDay: _classesThatDay);
  }

  int get _duration {
    final a = ClassTime.toMinutes(_start ?? '');
    final b = ClassTime.toMinutes(_end ?? '');
    return (a == null || b == null) ? 0 : b - a;
  }

  void _selectType(String t) {
    final preset = ExamTypes.preset(t);
    setState(() {
      // Only replace the title if it is still a default one.
      final defaults = ExamTypes.all.map((x) => ExamTypes.preset(x).$1).toSet();
      if (_titleController.text.trim().isEmpty || defaults.contains(_titleController.text.trim())) {
        _titleController.text = preset.$1;
      }
      _type = t;
      final s = ClassTime.toMinutes(_start ?? '') ?? 600;
      _end = ClassTime.format((s + preset.$2).clamp(0, 23 * 60 + 59));
    });
  }

  Future<void> _pickDate() async {
    final today = ClassTime.dateOnly(DateTime.now());
    final first = _isEdit && _date.isBefore(today) ? _date : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(first) ? first : _date,
      firstDate: first,
      lastDate: DateTime(today.year + 2),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _loadDay();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final draft = _draft;
    if (draft == null) {
      setState(() => _formError = 'Choose a course and a time.');
      return;
    }
    if (_duration < 15 || _duration > 300) {
      setState(() => _formError = 'An exam must be between 15 minutes and 5 hours.');
      return;
    }
    if (_clashes.isNotEmpty) return;

    setState(() {
      _submitting = true;
      _formError = null;
    });
    final ok = _isEdit ? await _examsController.updateExam(draft) : await _examsController.createExam(draft);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _submitting = false;
        _formError = _examsController.actionError ?? 'Could not save the exam. Please try again.';
      });
      return;
    }

    // Tell the semester (best effort; the exam is already saved).
    final s = _support;
    final u = _user;
    if (s != null && u != null) {
      // Use the saved exam (a new exam only gets its id when saved), so the
      // notice points at the real exam (the security rules check this).
      final saved = _isEdit ? draft : (_examsController.lastCreatedExam ?? draft);
      final msg = ExamSupportRepositoryImpl.message(saved, kind: _isEdit ? 'change' : 'new');
      if (saved.id.isNotEmpty) s.notifySemester(saved, title: msg.$1, body: msg.$2, sender: u);
    }
    Navigator.of(context).pop(true);
  }

  // ─── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final clashes = _clashes;
    final old = widget.existingExam;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
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
              Text(_isEdit ? 'Edit Exam' : 'Schedule Examination',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                _isCr
                    ? 'Year $_year · Semester $_semester. Finals are set by the course teacher or the Chairman.'
                    : (old != null && old.isCancelled
                        ? 'This exam is cancelled. Saving will reschedule it.'
                        : 'The semester\'s students are notified when you save.'),
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
              const SizedBox(height: 16),

              if (_formError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16)),
                  child: Text(_formError!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                ),
                const SizedBox(height: 14),
              ],

              // Type
              _label('Type'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _types)
                    ChoiceChip(
                      key: ValueKey('exam_type_$t'),
                      label: Text(ExamTypes.label(t)),
                      selected: _type == t,
                      onSelected: _submitting ? null : (_) => _selectType(t),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Semester (admins only pick it; teachers get it from the course; CR is fixed)
              if (_isAdmin) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _year,
                        decoration: const InputDecoration(labelText: 'Year'),
                        items: [for (final y in [1, 2, 3, 4]) DropdownMenuItem(value: y, child: Text('Year $y'))],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _year = v);
                          _loadCourses();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _semester,
                        decoration: const InputDecoration(labelText: 'Semester'),
                        items: [for (final s in [1, 2]) DropdownMenuItem(value: s, child: Text('Semester $s'))],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _semester = v);
                          _loadCourses();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Course
              if (_loadingCourses)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator(minHeight: 3))
              else
                DropdownButtonFormField<String>(
                  key: const ValueKey('exam_course'),
                  initialValue: _selectedCourse?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Course', prefixIcon: Icon(Icons.menu_book_outlined)),
                  hint: Text(_courses.isEmpty ? 'No courses available' : 'Choose a course'),
                  items: [
                    for (final c in _courses)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          _isTeacherOnly ? '${c.title} · Y${c.year}S${c.semester}' : c.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (id) => setState(() {
                            _selectedCourse = _courses.where((c) => c.id == id).firstOrNull;
                            _applyCourseSemester();
                          }),
                  validator: (v) => v == null ? 'Choose a course' : null,
                ),
              const SizedBox(height: 14),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.edit_note_rounded)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Exam title is required' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                key: const ValueKey('exam_date'),
                onTap: _submitting ? null : _pickDate,
                borderRadius: BorderRadius.circular(20),
                child: InputDecorator(
                  isEmpty: false,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(
                    '${DateFormat('EEE, MMM d, yyyy').format(_date)} · ${ExamDates.relative(ClassTime.dateKey(_date), DateTime.now())}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (_holidayTitle != null)
                Padding(
                  key: const ValueKey('exam_holiday_warning'),
                  padding: const EdgeInsets.only(top: 6, left: 6),
                  child: Text(
                    'This day is a holiday (${_holidayTitle!}). You can still save, but students may not expect an exam.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 14),

              // From / To
              TimeRangeField(
                start: _start,
                end: _end,
                defaultMinutes: ExamTypes.preset(_type).$2,
                onChanged: (a, b) => setState(() {
                  _start = a;
                  _end = b;
                }),
              ),
              if (old != null && old.wasMoved)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 6),
                  child: Text('Originally ${old.previousDate}, ${old.previousStartTime ?? ''}',
                      style: TextStyle(fontSize: 12, color: muted)),
                ),
              const SizedBox(height: 14),

              // Room with suggestions from the routine and other exams
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _initialRoom),
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  return q.isEmpty ? _rooms : _rooms.where((r) => r.toLowerCase().contains(q));
                },
                onSelected: (_) => setState(() {}),
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  _roomController = controller;
                  return TextFormField(
                    key: const ValueKey('exam_room'),
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: 'Room', prefixIcon: Icon(Icons.meeting_room_outlined)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a room' : null,
                    onChanged: (_) => setState(() {}),
                  );
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _invigilatorController,
                decoration: const InputDecoration(
                  labelText: 'Invigilator (optional)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _instructionsController,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Syllabus / instructions (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),

              if (clashes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  key: const ValueKey('exam_clashes'),
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
                      ...clashes.map((c) => Text('• ${c.message}',
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('exam_save'),
                  onPressed: (_submitting || clashes.isNotEmpty) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEdit ? 'Update Exam' : 'Schedule Exam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      );
}
