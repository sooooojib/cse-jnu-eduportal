import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../controllers/schedule_controller.dart';

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
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
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

  // Form State
  Course? _selectedCourse;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _invigilatorController = TextEditingController();

  String _selectedType = 'MID_TERM';
  String _selectedRoom = 'Room 401';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);
  int _targetYear = 1;
  int _targetSemester = 1;

  // Options & Loading
  List<Course> _availableCourses = [];
  bool _isLoadingOptions = true;
  String? _formError;
  bool _isSubmitting = false;

  final List<String> _examTypes = [
    'MID_TERM',
    'FINAL',
    'QUIZ',
    'LAB_EXAM',
    'CT',
  ];

  final List<String> _availableRooms = [
    'Room 401',
    'Room 402',
    'Room 403',
    'Room 501',
    'Main Exam Hall A',
    'Main Exam Hall B',
    'Lab 1 (Networking)',
    'Lab 2 (Software)',
    'Lab 4 (Systems)',
  ];

  @override
  void initState() {
    super.initState();
    _examsController = sl<ExamsController>();

    _targetYear = widget.existingExam?.year ?? widget.defaultYear ?? 1;
    _targetSemester = widget.existingExam?.semester ?? widget.defaultSemester ?? 1;
    _selectedType = widget.existingExam?.type ?? 'MID_TERM';
    _selectedRoom = widget.existingExam?.room ?? 'Room 401';
    _titleController.text = widget.existingExam?.title ?? 'Mid-Term Examination';
    _instructionsController.text = widget.existingExam?.instructions ?? '';
    _invigilatorController.text = widget.existingExam?.invigilatorName ?? widget.preselectedTeacherName ?? '';

    if (widget.existingExam != null) {
      try {
        final parts = widget.existingExam!.examDate.split('-');
        if (parts.length == 3) {
          _selectedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      } catch (_) {}

      _startTime = _parseTimeOfDay(widget.existingExam!.startTime) ?? const TimeOfDay(hour: 10, minute: 0);
      _endTime = _parseTimeOfDay(widget.existingExam!.endTime) ?? const TimeOfDay(hour: 12, minute: 0);
    }

    _loadCourses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _invigilatorController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim();
      final isPm = clean.toUpperCase().contains('PM');
      final isAm = clean.toUpperCase().contains('AM');
      final timeParts = clean.split(' ')[0].split(':');
      if (timeParts.length == 2) {
        int h = int.parse(timeParts[0]);
        final m = int.parse(timeParts[1]);
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        return TimeOfDay(hour: h, minute: m);
      }
    } catch (_) {}
    return null;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _formatDate(DateTime d) {
    return "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  int _calculateDurationMinutes() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return endMinutes - startMinutes;
  }

  String _formatDurationString() {
    final mins = _calculateDurationMinutes();
    if (mins <= 0) return 'Invalid Time';
    final hours = mins ~/ 60;
    final rem = mins % 60;
    if (hours > 0 && rem > 0) return '${hours}h ${rem}m';
    if (hours > 0) return '${hours}h';
    return '${rem}m';
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoadingOptions = true);
    try {
      final courses = await _examsController.fetchAvailableCourses(
        year: _targetYear,
        semester: _targetSemester,
      );

      setState(() {
        _availableCourses = courses;
        if (widget.existingExam != null) {
          _selectedCourse = courses.cast<Course?>().firstWhere(
            (c) => c?.id == widget.existingExam!.courseId || c?.code == widget.existingExam!.courseCode,
            orElse: () => null,
          );
        } else if (widget.userRole == UserRole.teacher && widget.teacherAssignedCourseIds != null) {
          _selectedCourse = courses.cast<Course?>().firstWhere(
            (c) => widget.teacherAssignedCourseIds!.contains(c?.id),
            orElse: () => courses.isNotEmpty ? courses.first : null,
          );
        } else if (courses.isNotEmpty) {
          _selectedCourse = courses.first;
        }
        _isLoadingOptions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingOptions = false;
        _formError = 'Failed to load courses for Year $_targetYear Semester $_targetSemester.';
      });
    }
  }

  void _onTypePresetSelected(String type) {
    setState(() {
      _selectedType = type;
      switch (type) {
        case 'MID_TERM':
          _titleController.text = 'Mid-Term Examination';
          _startTime = const TimeOfDay(hour: 10, minute: 0);
          _endTime = const TimeOfDay(hour: 12, minute: 0);
          break;
        case 'FINAL':
          _titleController.text = 'Semester Final Examination';
          _startTime = const TimeOfDay(hour: 10, minute: 0);
          _endTime = const TimeOfDay(hour: 13, minute: 0);
          break;
        case 'QUIZ':
          _titleController.text = 'Quiz Examination';
          _startTime = const TimeOfDay(hour: 10, minute: 0);
          _endTime = const TimeOfDay(hour: 10, minute: 45);
          break;
        case 'LAB_EXAM':
          _titleController.text = 'Lab Practical Examination';
          _startTime = const TimeOfDay(hour: 9, minute: 0);
          _endTime = const TimeOfDay(hour: 12, minute: 0);
          if (!_selectedRoom.contains('Lab')) {
            _selectedRoom = 'Lab 2 (Software)';
          }
          break;
        case 'CT':
          _titleController.text = 'Class Test';
          _startTime = const TimeOfDay(hour: 11, minute: 0);
          _endTime = const TimeOfDay(hour: 11, minute: 45);
          break;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstAllowedDate = widget.existingExam == null
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year - 2);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstAllowedDate) ? firstAllowedDate : _selectedDate,
      firstDate: firstAllowedDate,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Adjust end time if end <= start
        final startM = picked.hour * 60 + picked.minute;
        final endM = _endTime.hour * 60 + _endTime.minute;
        if (endM <= startM) {
          final newEndM = startM + 90; // Default 1.5 hour duration
          _endTime = TimeOfDay(hour: (newEndM ~/ 60) % 24, minute: newEndM % 60);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourse == null) {
      setState(() => _formError = 'Please select a valid course for this exam.');
      return;
    }

    final durationMins = _calculateDurationMinutes();
    if (durationMins <= 0) {
      setState(() => _formError = 'Exam end time must be strictly after start time.');
      return;
    }
    if (durationMins < 15 || durationMins > 300) {
      setState(() => _formError = 'Exam duration must be between 15 minutes and 5 hours.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    final examDateStr = _formatDate(_selectedDate);
    final startTimeStr = _formatTimeOfDay(_startTime);
    final endTimeStr = _formatTimeOfDay(_endTime);

    final examToSave = Exam(
      id: widget.existingExam?.id ?? '',
      courseId: _selectedCourse!.id,
      courseCode: _selectedCourse!.code,
      courseTitle: _selectedCourse!.title,
      title: _titleController.text.trim(),
      examDate: examDateStr,
      startTime: startTimeStr,
      endTime: endTimeStr,
      room: _selectedRoom,
      year: _targetYear,
      semester: _targetSemester,
      type: _selectedType,
      instructions: _instructionsController.text.trim().isEmpty ? null : _instructionsController.text.trim(),
      invigilatorName: _invigilatorController.text.trim().isEmpty ? null : _invigilatorController.text.trim(),
      invigilatorId: widget.userRole == UserRole.teacher ? widget.preselectedTeacherId : null,
    );

    bool success = false;
    if (widget.existingExam == null) {
      success = await _examsController.createExam(examToSave);
    } else {
      success = await _examsController.updateExam(examToSave);
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _formError = _examsController.actionError ?? 'Failed to save exam schedule. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.existingExam != null;
    final isCr = widget.userRole == UserRole.cr;
    final durationMins = _calculateDurationMinutes();
    final isDurationValid = durationMins >= 15 && durationMins <= 300;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.surfaceContainerDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerHighDark : AppColors.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_calendar_rounded : Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Exam Schedule' : 'Schedule Examination',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isCr
                              ? 'Year $_targetYear • Semester $_targetSemester (CR Cohort)'
                              : 'Academic Examination Management',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.onSurfaceVariantDark : AppColors.onSurfaceVariantLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Error Banner
                      if (_formError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formError!,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // CR Cohort Locked Banner or Year/Sem Selector
                      if (isCr) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Class Representative: Locked to your registered academic cohort (Year $_targetYear, Semester $_targetSemester).',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Academic Year', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    value: _targetYear,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: [1, 2, 3, 4].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                                    onChanged: _isSubmitting
                                        ? null
                                        : (v) {
                                            if (v != null) {
                                              setState(() => _targetYear = v);
                                              _loadCourses();
                                            }
                                          },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Semester', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<int>(
                                    value: _targetSemester,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: [1, 2].map((s) => DropdownMenuItem(value: s, child: Text('Semester $s'))).toList(),
                                    onChanged: _isSubmitting
                                        ? null
                                        : (v) {
                                            if (v != null) {
                                              setState(() => _targetSemester = v);
                                              _loadCourses();
                                            }
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Course Dropdown
                      const Text('Course *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      if (_isLoadingOptions)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<Course>(
                          value: _selectedCourse,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.school_outlined, size: 20),
                          ),
                          items: _availableCourses.map((c) {
                            return DropdownMenuItem<Course>(
                              value: c,
                              child: Text(
                                '${c.code}: ${c.title}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: _isSubmitting
                              ? null
                              : (c) {
                                  if (c != null) {
                                    setState(() => _selectedCourse = c);
                                  }
                                },
                          validator: (v) => v == null ? 'Course selection is required' : null,
                        ),
                      const SizedBox(height: 16),

                      // Exam Type Preset Chips
                      const Text('Exam Type & Title Preset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _examTypes.map((type) {
                          final isSelected = _selectedType == type;
                          String label = type;
                          if (type == 'MID_TERM') label = 'Mid-Term';
                          if (type == 'FINAL') label = 'Final';
                          if (type == 'QUIZ') label = 'Quiz';
                          if (type == 'LAB_EXAM') label = 'Lab Exam';
                          if (type == 'CT') label = 'Class Test';

                          return ChoiceChip(
                            label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withOpacity(0.15),
                            labelStyle: TextStyle(color: isSelected ? AppColors.primary : null),
                            onSelected: _isSubmitting ? null : (_) => _onTypePresetSelected(type),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Title field
                      const Text('Exam Title *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: 'e.g. Mid-Term Examination',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Exam title is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Exam Date Picker
                      const Text('Exam Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isSubmitting ? null : _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Text(
                                _formatDate(_selectedDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              const Text('Change Date', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Start & End Time Pickers + Duration Badge
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Start Time *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _isSubmitting ? null : _pickStartTime,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.withOpacity(0.4)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text(_formatTimeOfDay(_startTime), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                                const Text('End Time *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _isSubmitting ? null : _pickEndTime,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.withOpacity(0.4)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.schedule_rounded, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text(_formatTimeOfDay(_endTime), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Duration info pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDurationValid ? Colors.green.withOpacity(0.08) : Colors.redAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDurationValid ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDurationValid ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                              size: 14,
                              color: isDurationValid ? Colors.green : Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Duration: ${_formatDurationString()} ${isDurationValid ? "" : "(Valid: 15m - 5h)"}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDurationValid ? Colors.green : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Exam Room Dropdown
                      const Text('Exam Room / Hall *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedRoom,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.room_outlined, size: 20),
                        ),
                        items: _availableRooms.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: _isSubmitting ? null : (r) => setState(() => _selectedRoom = r ?? _selectedRoom),
                      ),
                      const SizedBox(height: 16),

                      // Invigilator Name
                      const Text('Invigilator Duty / Supervisor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _invigilatorController,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: 'e.g. Dr. Anisur Rahman',
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Instructions / Syllabus Notes
                      const Text('Syllabus / Instructions (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _instructionsController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: 'e.g. Chapters 1-4. Scientific calculators are permitted. Bring departmental ID.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.outlineDark.withOpacity(0.15) : AppColors.outlineLight.withOpacity(0.15),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEdit ? 'Update Exam' : 'Schedule Exam',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
