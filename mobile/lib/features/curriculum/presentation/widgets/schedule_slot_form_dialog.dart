import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../controllers/schedule_controller.dart';

class ScheduleSlotFormDialog extends StatefulWidget {
  final ScheduleSlot? existingSlot;
  final UserRole userRole;
  final int? defaultYear;
  final int? defaultSemester;
  final String? preselectedTeacherId;
  final String? preselectedTeacherName;

  const ScheduleSlotFormDialog({
    super.key,
    this.existingSlot,
    required this.userRole,
    this.defaultYear,
    this.defaultSemester,
    this.preselectedTeacherId,
    this.preselectedTeacherName,
  });

  static Future<bool?> show({
    required BuildContext context,
    ScheduleSlot? existingSlot,
    required UserRole userRole,
    int? defaultYear,
    int? defaultSemester,
    String? preselectedTeacherId,
    String? preselectedTeacherName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScheduleSlotFormDialog(
        existingSlot: existingSlot,
        userRole: userRole,
        defaultYear: defaultYear,
        defaultSemester: defaultSemester,
        preselectedTeacherId: preselectedTeacherId,
        preselectedTeacherName: preselectedTeacherName,
      ),
    );
  }

  @override
  State<ScheduleSlotFormDialog> createState() => _ScheduleSlotFormDialogState();
}

class _ScheduleSlotFormDialogState extends State<ScheduleSlotFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final ScheduleController _scheduleController;

  // Form State
  Course? _selectedCourse;
  Map<String, String>? _selectedTeacher;
  String _selectedDay = 'SUNDAY';
  String _selectedRoom = 'Room 401';
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  bool _isExtraClass = false;
  int _targetYear = 1;
  int _targetSemester = 1;

  // Options
  List<Course> _availableCourses = [];
  List<Map<String, String>> _availableTeachers = [];
  bool _isLoadingOptions = true;
  String? _formError;
  bool _isSubmitting = false;

  // Tomorrow calculations for CR
  late final String _tomorrowDateString;
  late final String _tomorrowDayOfWeek;

  final List<String> _daysOfWeek = [
    'SUNDAY',
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
  ];

  final List<String> _availableRooms = [
    'Room 401',
    'Room 402',
    'Room 403',
    'Room 501',
    'Room 501 (Academic Complex)',
    'Room 601',
    'Room 602',
    'Lab 1 (Networking)',
    'Lab 2 (Software)',
    'Lab 3 (AI & Data)',
    'Lab 4 (Systems)',
  ];

  @override
  void initState() {
    super.initState();
    _scheduleController = sl<ScheduleController>();

    // Calculate tomorrow in Bangladesh Time (UTC+6)
    final nowUtc = DateTime.now().toUtc();
    final bdTime = nowUtc.add(const Duration(hours: 6));
    final tomorrow = bdTime.add(const Duration(days: 1));
    _tomorrowDateString = "${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";

    final weekdayNames = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    _tomorrowDayOfWeek = weekdayNames[tomorrow.weekday - 1];

    _targetYear = widget.existingSlot?.targetYear ?? widget.defaultYear ?? 1;
    _targetSemester = widget.existingSlot?.targetSemester ?? widget.defaultSemester ?? 1;
    _isExtraClass = widget.existingSlot?.isExtraClass ?? (widget.userRole == UserRole.cr);

    if (widget.existingSlot != null) {
      _selectedDay = widget.existingSlot!.dayOfWeek;
    } else if (widget.userRole == UserRole.cr) {
      _selectedDay = _tomorrowDayOfWeek;
    } else {
      _selectedDay = 'SUNDAY';
    }

    if (widget.existingSlot != null) {
      _selectedRoom = widget.existingSlot!.room;
      if (_selectedRoom.isNotEmpty && !_availableRooms.contains(_selectedRoom)) {
        _availableRooms.insert(0, _selectedRoom);
      }
      _startTime = _parseTimeOfDay(widget.existingSlot!.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
      _endTime = _parseTimeOfDay(widget.existingSlot!.endTime) ?? const TimeOfDay(hour: 10, minute: 30);
    }

    _loadFormOptions();
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.trim().split(RegExp(r'[:\s]'));
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        if (parts.length >= 3) {
          final ampm = parts[2].toUpperCase();
          if (ampm == 'PM' && hour < 12) hour += 12;
          if (ampm == 'AM' && hour == 12) hour = 0;
        }
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final hourOfPeriod = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final hourStr = hourOfPeriod.toString().padLeft(2, '0');
    final minuteStr = tod.minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr $period';
  }

  Future<void> _loadFormOptions() async {
    setState(() => _isLoadingOptions = true);
    final courses = await _scheduleController.fetchAvailableCourses(
      year: _targetYear,
      semester: _targetSemester,
    );
    final teachers = await _scheduleController.fetchAvailableTeachers();

    if (!mounted) return;

    setState(() {
      _availableCourses = courses;
      _availableTeachers = teachers;
      _isLoadingOptions = false;

      // Match existing slot or defaults
      if (widget.existingSlot != null) {
        _selectedCourse = courses.cast<Course?>().firstWhere(
              (c) => c?.id == widget.existingSlot!.courseId || c?.code == widget.existingSlot!.courseCode,
              orElse: () => null,
            );
        if (_selectedCourse == null && widget.existingSlot!.courseCode.isNotEmpty) {
          final fallbackCourse = Course(
            id: widget.existingSlot!.courseId.isNotEmpty ? widget.existingSlot!.courseId : widget.existingSlot!.courseCode,
            code: widget.existingSlot!.courseCode,
            title: widget.existingSlot!.courseTitle.isNotEmpty ? widget.existingSlot!.courseTitle : widget.existingSlot!.courseCode,
            credit: 3.0,
            year: _targetYear,
            semester: _targetSemester,
            courseType: 'THEORY',
          );
          _availableCourses = [fallbackCourse, ..._availableCourses];
          _selectedCourse = fallbackCourse;
        }

        _selectedTeacher = teachers.cast<Map<String, String>?>().firstWhere(
              (t) => t?['id'] == widget.existingSlot!.teacherId,
              orElse: () => null,
            );
        if (_selectedTeacher == null && widget.existingSlot!.teacherId.isNotEmpty) {
          final fallbackTeacher = {
            'id': widget.existingSlot!.teacherId,
            'name': widget.existingSlot!.teacherName.isNotEmpty ? widget.existingSlot!.teacherName : 'Assigned Faculty',
          };
          _availableTeachers = [fallbackTeacher, ..._availableTeachers];
          _selectedTeacher = fallbackTeacher;
        }
      }

      if (_selectedCourse == null && _availableCourses.isNotEmpty) {
        _selectedCourse = _availableCourses.first;
      }

      if (_selectedTeacher == null) {
        if (widget.preselectedTeacherId != null) {
          _selectedTeacher = _availableTeachers.cast<Map<String, String>?>().firstWhere(
                (t) => t?['id'] == widget.preselectedTeacherId,
                orElse: () => _availableTeachers.isNotEmpty ? _availableTeachers.first : null,
              );
        } else if (_availableTeachers.isNotEmpty) {
          _selectedTeacher = _availableTeachers.first;
        }
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Ensure end time is at least 30 minutes after start
          final startMinutes = picked.hour * 60 + picked.minute;
          final endMinutes = _endTime.hour * 60 + _endTime.minute;
          if (endMinutes <= startMinutes) {
            final newEndMinutes = startMinutes + 90;
            _endTime = TimeOfDay(hour: (newEndMinutes ~/ 60) % 24, minute: newEndMinutes % 60);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _checkTeacherAvailability() async {
    if (_selectedTeacher == null) return;
    final teacherId = _selectedTeacher!['id']!;
    final teacherName = _selectedTeacher!['name']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return FutureBuilder<TeacherAvailability?>(
          future: _scheduleController.fetchTeacherAvailability(
            teacherId: teacherId,
            dayOfWeek: _selectedDay,
            date: widget.userRole == UserRole.cr ? _tomorrowDateString : null,
          ),
          builder: (context, snapshot) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Availability: $teacherName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Day: $_selectedDay${widget.userRole == UserRole.cr ? ' (Tomorrow: $_tomorrowDateString)' : ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError || snapshot.data == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Unable to load availability schedule.', style: TextStyle(color: Colors.red)),
                    )
                  else ...[
                    const Text(
                      'Free Time Windows (08:00 AM - 05:00 PM):',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (snapshot.data!.freeWindows.isEmpty)
                      const Text('No free windows available on this day.', style: TextStyle(color: Colors.orange))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: snapshot.data!.freeWindows.map((fw) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857).withOpacity(0.12),
                              border: Border.all(color: const Color(0xFF047857)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${fw.startTime} - ${fw.endTime} (${fw.durationMinutes} min)',
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scheduled / Busy Slots:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    if (snapshot.data!.busySlots.isEmpty)
                      const Text('Faculty has no scheduled classes on this day.', style: TextStyle(color: Colors.grey))
                    else
                      Column(
                        children: snapshot.data!.busySlots.map((bs) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_busy, color: Colors.redAccent, size: 20),
                            title: Text('${bs.courseCode} (${bs.startTime} - ${bs.endTime})'),
                            subtitle: Text('Room: ${bs.room}'),
                          );
                        }).toList(),
                      ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    setState(() => _formError = null);

    if (_selectedCourse == null) {
      setState(() => _formError = 'Please select a course.');
      return;
    }

    if (_selectedTeacher == null) {
      setState(() => _formError = 'Please select a teacher.');
      return;
    }

    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    final duration = endMin - startMin;

    if (duration <= 0) {
      setState(() => _formError = 'End time must be after start time.');
      return;
    }

    if (duration < 30 || duration > 240) {
      setState(() => _formError = 'Class duration must be between 30 minutes and 4 hours.');
      return;
    }

    final slot = ScheduleSlot(
      id: widget.existingSlot?.id ?? '',
      courseId: _selectedCourse!.id,
      courseCode: _selectedCourse!.code,
      courseTitle: _selectedCourse!.title,
      teacherId: _selectedTeacher!['id']!,
      teacherName: _selectedTeacher!['name']!,
      dayOfWeek: _selectedDay,
      startTime: _formatTimeOfDay(_startTime),
      endTime: _formatTimeOfDay(_endTime),
      room: _selectedRoom,
      targetYear: _targetYear,
      targetSemester: _targetSemester,
      isExtraClass: _isExtraClass,
      date: _selectedDay == _tomorrowDayOfWeek
          ? (widget.userRole == UserRole.cr ? _tomorrowDateString : widget.existingSlot?.date)
          : widget.existingSlot?.date,
      createdBy: widget.existingSlot?.createdBy,
      status: widget.existingSlot?.status ?? 'SCHEDULED',
    );

    setState(() => _isSubmitting = true);

    bool success;
    if (widget.existingSlot != null) {
      success = await _scheduleController.updateSlot(slot);
    } else {
      success = await _scheduleController.createSlot(slot);
    }

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        final rawErr = _scheduleController.actionError ?? 'Failed to save schedule slot.';
        final cleanErr = rawErr
            .replaceAll('Exception: ', '')
            .replaceAll('ServerException: ', '')
            .replaceAll('Failure: ', '')
            .trim();
        if (cleanErr.isEmpty ||
            cleanErr.toUpperCase() == 'NOT_FOUND' ||
            cleanErr.toLowerCase().contains('not_found') ||
            cleanErr.toLowerCase().contains('internal')) {
          _formError = 'Unable to save schedule slot. Please try again.';
        } else if (cleanErr.contains('permission-denied')) {
          _formError = 'Permission denied. Only authorized CR, Teacher, or Admin can modify this slot.';
        } else {
          _formError = cleanErr;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingSlot != null;
    final isCr = widget.userRole == UserRole.cr;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCr ? const Color(0xFFC2410C).withOpacity(0.15) : AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_calendar_rounded : Icons.add_circle_outline_rounded,
                      color: isCr ? const Color(0xFFC2410C) : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Class Schedule' : 'Schedule New Class',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          isCr ? 'CR Routine Mode (Year $_targetYear · Sem $_targetSemester)' : 'Academic Scheduling Terminal',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCr ? const Color(0xFF2563EB) : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: _isLoadingOptions
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // CR Routine Helper Banner
                            if (isCr)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'CR Routine Editor · Defaulted to tomorrow ($_tomorrowDayOfWeek) · Select any day to set future routine for Year $_targetYear, Sem $_targetSemester.',
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Error Callout Banner
                            if (_formError != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  border: Border.all(color: Colors.redAccent),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _formError!,
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Course Selection Dropdown
                            Builder(
                              builder: (context) {
                                final Map<String, Course> courseMap = {};
                                if (_selectedCourse != null) {
                                  courseMap[_selectedCourse!.id] = _selectedCourse!;
                                }
                                for (final c in _availableCourses) {
                                  courseMap[c.id] = c;
                                }
                                final effectiveCourses = courseMap.values.toList();
                                final currentCourse = _selectedCourse != null ? courseMap[_selectedCourse!.id] : (effectiveCourses.isNotEmpty ? effectiveCourses.first : null);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Course *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<Course>(
                                      value: currentCourse,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? AppColors.surfaceContainerDark : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      items: effectiveCourses.map((c) {
                                        return DropdownMenuItem<Course>(
                                          value: c,
                                          child: Text('${c.code}: ${c.title}', overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedCourse = val);
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Teacher Selection + Availability Check
                            Builder(
                              builder: (context) {
                                final Map<String, Map<String, String>> teacherMap = {};
                                if (_selectedTeacher != null && (_selectedTeacher!['id']?.isNotEmpty ?? false)) {
                                  teacherMap[_selectedTeacher!['id']!] = _selectedTeacher!;
                                }
                                for (final t in _availableTeachers) {
                                  final id = t['id'];
                                  if (id != null && id.isNotEmpty) {
                                    teacherMap[id] = t;
                                  }
                                }
                                final effectiveTeachers = teacherMap.values.toList();
                                final currentTeacher = _selectedTeacher != null ? teacherMap[_selectedTeacher!['id']] : (effectiveTeachers.isNotEmpty ? effectiveTeachers.first : null);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Flexible(
                                          child: Text(
                                            'Faculty / Teacher *',
                                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: _checkTeacherAvailability,
                                          icon: const Icon(Icons.event_available, size: 16),
                                          label: const Text('Check Availability', style: TextStyle(fontSize: 12)),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<Map<String, String>>(
                                      value: currentTeacher,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? AppColors.surfaceContainerDark : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      items: effectiveTeachers.map((t) {
                                        return DropdownMenuItem<Map<String, String>>(
                                          value: t,
                                          child: Text(t['name'] ?? '', overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedTeacher = val);
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Day of Week
                            Builder(
                              builder: (context) {
                                final effectiveDays = <String>{
                                  if (_selectedDay.isNotEmpty) _selectedDay,
                                  ..._daysOfWeek,
                                }.toList();
                                final currentDay = effectiveDays.contains(_selectedDay) ? _selectedDay : effectiveDays.first;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Day of Week *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: currentDay,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? AppColors.surfaceContainerDark : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      items: effectiveDays.map((d) {
                                        final isTomorrow = d == _tomorrowDayOfWeek;
                                        return DropdownMenuItem<String>(
                                          value: d,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(d),
                                              if (isTomorrow)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF0284C7).withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Text(
                                                    'Tomorrow',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF0284C7),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedDay = val);
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Room Selection
                            Builder(
                              builder: (context) {
                                final effectiveRooms = <String>{
                                  if (_selectedRoom.isNotEmpty) _selectedRoom,
                                  ..._availableRooms,
                                }.toList();
                                final currentRoom = effectiveRooms.contains(_selectedRoom) ? _selectedRoom : effectiveRooms.first;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Classroom / Lab *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: currentRoom,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? AppColors.surfaceContainerDark : const Color(0xFFF8FAFC),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      ),
                                      items: effectiveRooms.map((r) {
                                        return DropdownMenuItem<String>(
                                          value: r,
                                          child: Text(r),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedRoom = val);
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Time Picker Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Start Time *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () => _pickTime(isStart: true),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.surfaceContainerDark : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _formatTimeOfDay(_startTime),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('End Time *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () => _pickTime(isStart: false),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.surfaceContainerDark : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                _formatTimeOfDay(_endTime),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              const Icon(Icons.access_time_filled, size: 18, color: AppColors.primary),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Extra Class Toggle
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Mark as Extra / Make-up Class', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: const Text('Highlights slot in yellow/amber badge for students', style: TextStyle(fontSize: 11)),
                              value: _isExtraClass,
                              activeColor: AppColors.primary,
                              onChanged: (val) => setState(() => _isExtraClass = val),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Actions Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerDark : AppColors.surfaceContainerLight,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCr ? const Color(0xFFC2410C) : AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Save Changes' : (isCr && _selectedDay == _tomorrowDayOfWeek ? 'Schedule for Tomorrow' : 'Schedule Class')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
