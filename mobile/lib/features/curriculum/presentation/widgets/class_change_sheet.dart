import 'package:flutter/material.dart';
import 'time_range_field.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/class_time.dart';
import '../../../auth/domain/entities/user.dart';
import '../../data/repositories/class_change_repository.dart';
import '../../domain/entities/class_change.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/services/effective_schedule.dart';

/// One form for one-day class changes used by the CR (their own batch) and
/// teachers (their own courses). The weekly routine itself is never edited.
///
/// * Teachers: extra / cancel / move, today .. next 7 days.
/// * CR (and admins): also the past 7 days, plus "Not taken" reports for a
///   class that was due but did not happen (today or earlier).
class ClassChangeSheet extends StatefulWidget {
  final User user;
  final ClassChangeRepository? repository;
  final ClassChangeType initialType;
  final DateTime? initialDate;
  final DateTime? now;

  /// Opened from a class's Modify button: the type, day and class are already
  /// chosen, so those steps are skipped.
  final String? initialSlotId;

  const ClassChangeSheet({
    super.key,
    required this.user,
    this.repository,
    this.initialType = ClassChangeType.extra,
    this.initialDate,
    this.now,
    this.initialSlotId,
  });

  /// Returns true when a change was saved.
  static Future<bool?> show(
    BuildContext context, {
    required User user,
    ClassChangeType initialType = ClassChangeType.extra,
    DateTime? initialDate,
    String? initialSlotId,
    ClassChangeRepository? repository,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ClassChangeSheet(
        user: user,
        repository: repository,
        initialType: initialType,
        initialDate: initialDate,
        initialSlotId: initialSlotId,
      ),
    );
  }

  @override
  State<ClassChangeSheet> createState() => _ClassChangeSheetState();
}

class _ClassChangeSheetState extends State<ClassChangeSheet> {
  late final ClassChangeRepository _repo;
  late final List<DateTime> _upcoming; // today .. +7
  late final List<DateTime> _past; // yesterday .. -7 (CR / admin only)
  late ClassChangeType _type;
  late DateTime _date;

  List<Course> _courses = const [];
  List<ScheduleSlot> _routine = const []; // that weekday, all batches
  List<ClassChange> _dayChanges = const []; // that date, all batches
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Course? _course; // extra class
  ScheduleSlot? _target; // class to cancel / move
  String? _start;
  String? _end;
  final _roomCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  bool get _isCr => widget.user.role == UserRole.cr;

  /// Opened from a class's Modify button (type, day and class fixed).
  bool get _focused => widget.initialSlotId != null;

  /// CR and admins can record what happened in the past week and report
  /// classes that were not taken. Teachers only plan ahead.
  bool get _canReport => _isCr || widget.user.role.hasAdminAccess;

  DateTime get _today => _upcoming.first;
  bool _same(DateTime a, DateTime b) =>
      ClassTime.dateKey(a) == ClassTime.dateKey(b);
  bool get _isPastDate => _date.isBefore(_today);

  /// Day chips for the current type.
  List<DateTime> get _dateChoices {
    if (_type == ClassChangeType.notTaken) return [_today, ..._past];
    return [if (_isPastDate) _date, ..._upcoming];
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? sl<ClassChangeRepository>();
    final now = widget.now ?? DateTime.now();
    _upcoming = ClassTime.upcomingDates(now);
    _past = _canReport ? ClassTime.pastDates(now) : const [];
    _type = widget.initialType == ClassChangeType.notTaken && !_canReport
        ? ClassChangeType.extra
        : widget.initialType;
    final all = [..._past, ..._upcoming];
    final fallback = _type == ClassChangeType.notTaken
        ? _upcoming[0]
        : _upcoming[1];
    _date = widget.initialDate == null
        ? fallback
        : all.firstWhere(
            (d) => _same(d, widget.initialDate!),
            orElse: () => fallback,
          );
    if (_type == ClassChangeType.notTaken && _date.isAfter(_today)) {
      _date = _today;
    }
    _loadCourses();
    _loadDay();
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final list = await _repo.plannableCourses(widget.user);
      if (mounted) setState(() => _courses = list);
    } catch (_) {}
  }

  Future<void> _loadDay() async {
    setState(() {
      _loading = true;
      _error = null;
      _target = null;
    });
    List<ScheduleSlot> routine;
    try {
      routine = await _repo.routineForDay(ClassTime.dayOfWeek(_date));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the routine for this day. ($e)';
      });
      return;
    }
    try {
      final changes = await _repo.changesOn(_date);
      if (!mounted) return;
      setState(() {
        _routine = routine;
        _dayChanges = changes;
        _loading = false;
      });
      if (_focused && _type != ClassChangeType.extra) {
        final match = _myClassesThatDay
            .where((s) => s.id == widget.initialSlotId)
            .firstOrNull;
        if (match != null) _pickTarget(match);
      }
    } catch (e) {
      if (!mounted) return;
      final denied =
          e.toString().toLowerCase().contains('denied') ||
          e.toString().toLowerCase().contains('permission');
      setState(() {
        _routine = routine;
        _loading = false;
        _error = denied
            ? 'Class changes are not enabled on the server yet. Ask the admin to deploy the latest security rules (firebase deploy --only firestore:rules).'
            : 'Could not load this day\'s class changes. ($e)';
      });
    }
  }

  /// Classes on the chosen date that this user may cancel, move, or report
  /// as not taken (moved and extra classes can also be not taken).
  List<ScheduleSlot> get _myClassesThatDay {
    final courseIds = _courses.map((c) => c.id).toSet();
    final notTaken = _type == ClassChangeType.notTaken;
    return EffectiveSchedule.forDate(
          routine: _routine,
          changes: _dayChanges,
          date: _date,
        )
        .where(
          (s) =>
              !s.isCancelled && (notTaken || (!s.isMoved && !s.isExtraClass)),
        )
        .where(
          (s) => _isCr
              ? (s.targetYear == widget.user.year &&
                    s.targetSemester == widget.user.semester)
              : courseIds.contains(s.courseId),
        )
        .toList();
  }

  /// A move must change the time or the room.
  bool get _movesSomething {
    final t = _target;
    if (t == null) return false;
    return _start != ClassTime.normalize(t.startTime) ||
        _end != ClassTime.normalize(t.endTime) ||
        _roomCtrl.text.trim().toLowerCase() != t.room.trim().toLowerCase();
  }

  /// Length of a usual class in this routine (for a new extra class).
  int get _usualLength {
    final p = EffectiveSchedule.commonPeriods(_routine, max: 1);
    if (p.isEmpty) return 90;
    final a = ClassTime.toMinutes(p.first.$1) ?? 0;
    final b = ClassTime.toMinutes(p.first.$2) ?? 90;
    return b > a ? b - a : 90;
  }

  List<ScheduleClash> get _clashes {
    if (_type == ClassChangeType.cancel ||
        _type == ClassChangeType.notTaken ||
        _start == null ||
        _end == null) {
      return const [];
    }
    final teacherId = _type == ClassChangeType.extra
        ? (_course?.teacherId ?? '')
        : (_target?.teacherId ?? '');
    final year = _type == ClassChangeType.extra
        ? (_course?.year ?? 0)
        : (_target?.targetYear ?? 0);
    final sem = _type == ClassChangeType.extra
        ? (_course?.semester ?? 0)
        : (_target?.targetSemester ?? 0);
    return EffectiveSchedule.findClashes(
      routine: _routine,
      changes: _dayChanges,
      date: _date,
      startTime: _start!,
      endTime: _end!,
      room: _roomCtrl.text,
      teacherId: teacherId,
      targetYear: year,
      targetSemester: sem,
      ignoreSlotId: _type == ClassChangeType.move ? _target?.id : null,
    );
  }

  bool get _canSave {
    if (_saving || _loading) return false;
    switch (_type) {
      case ClassChangeType.extra:
        return _course != null &&
            _start != null &&
            _end != null &&
            _roomCtrl.text.trim().isNotEmpty &&
            _clashes.isEmpty;
      case ClassChangeType.cancel:
      case ClassChangeType.notTaken:
        return _target != null;
      case ClassChangeType.move:
        return _target != null &&
            _start != null &&
            _end != null &&
            _roomCtrl.text.trim().isNotEmpty &&
            _movesSomething &&
            _clashes.isEmpty;
    }
  }

  void _pickCourse(Course? c) {
    setState(() {
      _course = c;
      if (c != null && _roomCtrl.text.trim().isEmpty) {
        final usual = _routine
            .where((s) => s.courseId == c.id)
            .map((s) => s.room)
            .firstWhere((r) => r.isNotEmpty, orElse: () => '');
        _roomCtrl.text = usual;
      }
    });
  }

  void _pickTarget(ScheduleSlot s) {
    setState(() {
      _target = s;
      _roomCtrl.text = s.room;
      _start = ClassTime.normalize(s.startTime);
      _end = ClassTime.normalize(s.endTime);
    });
  }

  Future<void> _save() async {
    final u = widget.user;
    final key = ClassTime.dateKey(_date);
    final day = ClassTime.dayOfWeek(_date);
    final ClassChange change;
    if (_type == ClassChangeType.extra) {
      final c = _course!;
      change = ClassChange(
        id: '',
        type: _type,
        date: key,
        dayOfWeek: day,
        courseId: c.id,
        courseCode: c.code,
        courseTitle: c.title,
        teacherId: c.teacherId ?? '',
        teacherName: c.teacherName ?? '',
        targetYear: c.year,
        targetSemester: c.semester,
        startTime: _start!,
        endTime: _end!,
        room: _roomCtrl.text.trim(),
        reason: _reasonCtrl.text,
        createdBy: u.id,
        createdByName: u.fullName,
        createdByRole: u.role.value,
      );
    } else {
      final s = _target!;
      final cancel =
          _type == ClassChangeType.cancel || _type == ClassChangeType.notTaken;
      change = ClassChange(
        id: '',
        type: _type,
        date: key,
        dayOfWeek: day,
        courseId: s.courseId,
        courseCode: s.courseCode,
        courseTitle: s.courseTitle,
        teacherId: s.teacherId,
        teacherName: s.teacherName,
        targetYear: s.targetYear,
        targetSemester: s.targetSemester,
        startTime: cancel ? ClassTime.normalize(s.startTime) : _start!,
        endTime: cancel ? ClassTime.normalize(s.endTime) : _end!,
        room: cancel ? s.room : _roomCtrl.text.trim(),
        originalSlotId: s.id,
        originalStartTime: ClassTime.normalize(s.startTime),
        originalRoom: s.room,
        reason: _reasonCtrl.text,
        createdBy: u.id,
        createdByName: u.fullName,
        createdByRole: u.role.value,
      );
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await _repo.create(change);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${change.type.label}: ${change.courseCode} on ${DateFormat('EEE, MMM d').format(_date)}',
          ),
          backgroundColor: const Color(0xFF047857),
        ),
      );
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dateLabel(DateTime d) {
    final diff = d.difference(_today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('EEE d').format(d);
  }

  void _selectType(ClassChangeType t) {
    final reloadDay = t == ClassChangeType.notTaken && _date.isAfter(_today);
    setState(() {
      _type = t;
      _target = null;
      if (reloadDay) _date = _today;
      if (_type != ClassChangeType.extra) {
        _start = null;
        _end = null;
        _roomCtrl.clear();
      }
    });
    if (reloadDay) _loadDay();
  }

  void _selectDate(DateTime d) {
    setState(() => _date = d);
    _loadDay();
  }

  String get _targetQuestion => switch (_type) {
    ClassChangeType.cancel => 'Which class to cancel?',
    ClassChangeType.move => 'Which class to move?',
    ClassChangeType.notTaken => 'Which class was not taken?',
    ClassChangeType.extra => '',
  };

  String get _focusedTitle => switch (_type) {
    ClassChangeType.move => 'Move or Change Room',
    ClassChangeType.cancel => 'Cancel Class',
    ClassChangeType.notTaken => 'Mark Not Taken',
    ClassChangeType.extra => 'Extra Class',
  };

  String get _saveLabel => switch (_type) {
    ClassChangeType.cancel => 'Cancel This Class',
    ClassChangeType.notTaken => 'Report Not Taken',
    _ => 'Save Change',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final clashes = _clashes;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                decoration: BoxDecoration(
                  color: muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _focused ? _focusedTitle : 'Change a Class',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            if (_focused)
              Text(
                _target == null
                    ? DateFormat('EEEE, MMM d').format(_date)
                    : '${_target!.courseTitle.isNotEmpty ? _target!.courseTitle : _target!.courseCode} · '
                          '${DateFormat('EEE, MMM d').format(_date)}\n'
                          'Now: ${ClassTime.normalize(_target!.startTime)} – ${ClassTime.normalize(_target!.endTime)} · ${_target!.room}',
                style: TextStyle(fontSize: 12.5, color: muted),
              )
            else
              Text(
                _isCr
                    ? 'One-day changes for Year ${widget.user.year} · Semester ${widget.user.semester}, from last week to next week. The weekly routine stays the same.'
                    : 'One-day changes for your courses, today to next week. The weekly routine stays the same.',
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
            const SizedBox(height: 16),

            // 1. What
            if (!_focused) ...[
              SegmentedButton<ClassChangeType>(
                key: const ValueKey('change_type'),
                showSelectedIcon: false,
                segments: _canReport
                    // Four options: text only so they fit on a phone.
                    ? const [
                        ButtonSegment(
                          value: ClassChangeType.extra,
                          label: Text('Extra'),
                        ),
                        ButtonSegment(
                          value: ClassChangeType.cancel,
                          label: Text('Cancel'),
                        ),
                        ButtonSegment(
                          value: ClassChangeType.move,
                          label: Text('Move'),
                        ),
                        ButtonSegment(
                          value: ClassChangeType.notTaken,
                          label: Text('Not taken'),
                        ),
                      ]
                    : const [
                        ButtonSegment(
                          value: ClassChangeType.extra,
                          label: Text('Extra'),
                          icon: Icon(Icons.add_rounded),
                        ),
                        ButtonSegment(
                          value: ClassChangeType.cancel,
                          label: Text('Cancel'),
                          icon: Icon(Icons.event_busy_rounded),
                        ),
                        ButtonSegment(
                          value: ClassChangeType.move,
                          label: Text('Move'),
                          icon: Icon(Icons.swap_horiz_rounded),
                        ),
                      ],
                selected: {_type},
                onSelectionChanged: (s) => _selectType(s.first),
              ),
              if (_type == ClassChangeType.notTaken)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Use this when a class was due but did not happen. It is recorded under the teacher in the Chairman\'s monitoring.',
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                ),
              const SizedBox(height: 18),

              // 2. When
              _label('Day'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final d in _dateChoices)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          key: ValueKey('date_${ClassTime.dateKey(d)}'),
                          label: Text(_dateLabel(d)),
                          selected: _same(d, _date),
                          onSelected: (_) => _selectDate(d),
                        ),
                      ),
                    if (_past.isNotEmpty && _type != ClassChangeType.notTaken)
                      PopupMenuButton<DateTime>(
                        key: const ValueKey('date_earlier'),
                        tooltip: 'An earlier day',
                        onSelected: _selectDate,
                        itemBuilder: (_) => [
                          for (final d in _past)
                            PopupMenuItem(
                              value: d,
                              child: Text(
                                '${_dateLabel(d)} · ${DateFormat('MMM d').format(d)}',
                              ),
                            ),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.history_rounded, size: 16),
                          label: const Text('Earlier'),
                          shape: const StadiumBorder(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                key: const ValueKey('change_load_error'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 13,
                  ),
                ),
              )
            else ...[
              // 3. Which class
              if (_type == ClassChangeType.extra) ...[
                _label('Course'),
                DropdownButtonFormField<Course>(
                  key: const ValueKey('change_course'),
                  initialValue: _course,
                  isExpanded: true,
                  hint: const Text('Choose a course'),
                  items: _courses
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            '${c.code}: ${c.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _pickCourse,
                ),
                if (_course != null && (_course!.teacherName ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 8),
                    child: Text(
                      'Teacher: ${_course!.teacherName}',
                      style: TextStyle(fontSize: 12.5, color: muted),
                    ),
                  ),
              ] else if (_focused) ...[
                if (_target == null)
                  Text(
                    'This class can no longer be changed for this day.',
                    style: TextStyle(color: muted),
                  ),
              ] else ...[
                _label(_targetQuestion),
                if (_myClassesThatDay.isEmpty)
                  Text(
                    _type == ClassChangeType.notTaken
                        ? 'No classes left on this day to report.'
                        : 'No classes on this day to ${_type == ClassChangeType.cancel ? 'cancel' : 'move'}.',
                    style: TextStyle(color: muted),
                  )
                else
                  ..._myClassesThatDay.map((s) => _classOption(s, isDark)),
              ],

              // 4. Time & room
              if ((_type == ClassChangeType.extra ||
                      _type == ClassChangeType.move) &&
                  (_type == ClassChangeType.extra || _target != null)) ...[
                const SizedBox(height: 18),
                _label(_type == ClassChangeType.move ? 'New time' : 'Time'),
                TimeRangeField(
                  start: _start,
                  end: _end,
                  defaultMinutes: _usualLength,
                  onChanged: (a, b) => setState(() {
                    _start = a;
                    _end = b;
                  }),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('change_room'),
                  controller: _roomCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Room',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                ),
              ],

              const SizedBox(height: 14),
              TextField(
                controller: _reasonCtrl,
                decoration: InputDecoration(
                  labelText: switch (_type) {
                    ClassChangeType.cancel => 'Reason (shown to students)',
                    ClassChangeType.notTaken => 'What happened? (optional)',
                    _ => 'Note (optional)',
                  },
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),

              if (clashes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  key: const ValueKey('change_clashes'),
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
                      const Text(
                        'This time doesn\'t work:',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...clashes.map(
                        (c) => Text(
                          '• ${c.message}',
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('change_save'),
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    ),
  );

  Widget _classOption(ScheduleSlot s, bool isDark) {
    final selected = _target?.id == s.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('target_${s.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _pickTarget(s),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF047857)
                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? const Color(0xFF047857) : Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.courseCode}: ${s.courseTitle}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${ClassTime.normalize(s.startTime)}–${ClassTime.normalize(s.endTime)} · ${s.room}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
