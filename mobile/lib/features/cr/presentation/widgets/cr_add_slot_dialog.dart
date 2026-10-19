import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../domain/entities/cr_dashboard_data.dart';

class CrAddSlotDialog extends StatefulWidget {
  final CrDashboardData data;
  final Future<bool> Function(ScheduleSlot slot) onAddSlot;

  const CrAddSlotDialog({
    super.key,
    required this.data,
    required this.onAddSlot,
  });

  static Future<void> show(
    BuildContext context, {
    required CrDashboardData data,
    required Future<bool> Function(ScheduleSlot slot) onAddSlot,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrAddSlotDialog(data: data, onAddSlot: onAddSlot),
    );
  }

  @override
  State<CrAddSlotDialog> createState() => _CrAddSlotDialogState();
}

class _CrAddSlotDialogState extends State<CrAddSlotDialog> {
  final _formKey = GlobalKey<FormState>();
  Course? _selectedCourse;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _roomController;
  late final TextEditingController _teacherController;
  bool _isExtraClass = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.enrolledCourses.isNotEmpty) {
      _selectedCourse = widget.data.enrolledCourses.first;
    }
    _startTimeController = TextEditingController(text: '09:00 AM');
    _endTimeController = TextEditingController(text: '10:30 AM');
    _roomController = TextEditingController(text: 'Room 302, Block A');
    _teacherController = TextEditingController(text: _selectedCourse?.teacherName ?? '');
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _roomController.dispose();
    _teacherController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an enrolled course')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final slot = ScheduleSlot(
      id: '',
      courseId: _selectedCourse!.id,
      courseCode: _selectedCourse!.code,
      courseTitle: _selectedCourse!.title,
      teacherId: _selectedCourse!.teacherId ?? '',
      teacherName: _teacherController.text.trim(),
      dayOfWeek: _dayOfWeekFromLabel(widget.data.tomorrowDateLabel),
      startTime: _startTimeController.text.trim(),
      endTime: _endTimeController.text.trim(),
      room: _roomController.text.trim(),
      targetYear: widget.data.year,
      targetSemester: widget.data.semester,
      isExtraClass: _isExtraClass,
    );

    final success = await widget.onAddSlot(slot);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${slot.courseCode} to tomorrow\'s schedule!'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add slot. Please check network/permissions.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _dayOfWeekFromLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('sun')) return 'SUNDAY';
    if (lower.contains('mon')) return 'MONDAY';
    if (lower.contains('tue')) return 'TUESDAY';
    if (lower.contains('wed')) return 'WEDNESDAY';
    if (lower.contains('thu')) return 'THURSDAY';
    if (lower.contains('fri')) return 'FRIDAY';
    if (lower.contains('sat')) return 'SATURDAY';
    return 'SUNDAY';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                  Text(
                    'Add Class for Tomorrow',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Schedule slot for ${widget.data.tomorrowDateLabel} (Year ${widget.data.year} · Sem ${widget.data.semester})',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),

              // Course Selector
              const Text('Select Course', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              if (widget.data.enrolledCourses.isEmpty)
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'e.g. CSE-3101',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    _selectedCourse = Course(
                      id: val,
                      code: val,
                      title: val,
                      credit: 3.0,
                      year: widget.data.year,
                      semester: widget.data.semester,
                      courseType: 'THEORY',
                    );
                  },
                )
              else
                DropdownButtonFormField<Course>(
                  initialValue: _selectedCourse,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: widget.data.enrolledCourses.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text('${c.code}: ${c.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCourse = val;
                      if (val?.teacherName != null && val!.teacherName!.isNotEmpty) {
                        _teacherController.text = val.teacherName!;
                      }
                    });
                  },
                ),
              const SizedBox(height: 14),

              // Timing Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _startTimeController,
                          decoration: InputDecoration(
                            hintText: '09:00 AM',
                            prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _endTimeController,
                          decoration: InputDecoration(
                            hintText: '10:30 AM',
                            prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Room & Teacher Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Room Allocation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _roomController,
                          decoration: InputDecoration(
                            hintText: 'Room 302, Block A',
                            prefixIcon: const Icon(Icons.meeting_room_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Instructor Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _teacherController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Dr. Layek',
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Extra Class Checkbox
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _isExtraClass,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _isExtraClass = val ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Mark as Extra / Makeup Class',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save Class Slot',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
