import '../../../curriculum/presentation/widgets/exam_details_dialog.dart';
import '../../../curriculum/presentation/widgets/exam_tile.dart';
import '../../../curriculum/domain/services/exam_rules.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/class_time.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../curriculum/presentation/widgets/class_actions_sheet.dart';
import '../../../curriculum/presentation/widgets/class_slot_tile.dart';

class TimeAwareClassesCard extends StatefulWidget {
  final List<ScheduleSlot> classes;
  final List<Exam> exams;
  final List<ScheduleSlot>? todayClasses;
  final List<ScheduleSlot>? tomorrowClasses;
  final List<Exam>? todayExams;
  final List<Exam>? tomorrowExams;
  final bool isTomorrow;
  final String dateLabel;
  final String? todayDateLabel;
  final String? tomorrowDateLabel;
  final Function(ScheduleSlot slot)? onStartAttendance;
  final Function(Exam exam)? onExamTap;
  final VoidCallback? onViewFullSchedule;

  /// When set (the teacher), their own classes get a Modify button.
  final User? user;

  /// Called after a class is changed from its Modify button.
  final VoidCallback? onChanged;

  const TimeAwareClassesCard({
    super.key,
    required this.classes,
    this.exams = const [],
    this.todayClasses,
    this.tomorrowClasses,
    this.todayExams,
    this.tomorrowExams,
    required this.isTomorrow,
    required this.dateLabel,
    this.todayDateLabel,
    this.tomorrowDateLabel,
    this.onStartAttendance,
    this.onExamTap,
    this.onViewFullSchedule,
    this.user,
    this.onChanged,
  });

  @override
  State<TimeAwareClassesCard> createState() => _TimeAwareClassesCardState();
}

class _TimeAwareClassesCardState extends State<TimeAwareClassesCard> {
  int _selectedTab = 0; // 0 for Classes, 1 for Exams
  late int _selectedDay; // 0 for Today, 1 for Tomorrow

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.isTomorrow ? 1 : 0;
  }

  bool get isShowingTomorrow => _selectedDay == 1;

  DateTime get _shownDate {
    final today = ClassTime.dateOnly(DateTime.now());
    return isShowingTomorrow ? today.add(const Duration(days: 1)) : today;
  }

  List<ScheduleSlot> get currentClasses {
    if (isShowingTomorrow) {
      if (widget.tomorrowClasses != null) return widget.tomorrowClasses!;
      return widget.isTomorrow ? widget.classes : const [];
    } else {
      if (widget.todayClasses != null) return widget.todayClasses!;
      return !widget.isTomorrow ? widget.classes : const [];
    }
  }

  List<Exam> get currentExams {
    if (isShowingTomorrow) {
      if (widget.tomorrowExams != null) return widget.tomorrowExams!;
      return widget.isTomorrow ? widget.exams : const [];
    } else {
      if (widget.todayExams != null) return widget.todayExams!;
      return !widget.isTomorrow ? widget.exams : const [];
    }
  }

  String get currentDateLabel {
    if (isShowingTomorrow) {
      if (widget.tomorrowDateLabel != null && widget.tomorrowDateLabel!.isNotEmpty) {
        return widget.tomorrowDateLabel!;
      }
    } else {
      if (widget.todayDateLabel != null && widget.todayDateLabel!.isNotEmpty) {
        return widget.todayDateLabel!;
      }
    }
    final raw = widget.dateLabel;
    if (raw.isNotEmpty && !raw.startsWith('Today · ') && !raw.startsWith('Tomorrow · ')) {
      return raw;
    }
    final now = DateTime.now();
    final date = isShowingTomorrow ? now.add(const Duration(days: 1)) : now;
    return DateFormat('EEEE · MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title, Date & Day Switcher Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.transparent, // same as the card: less nesting
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTab == 0 ? 'Classes' : 'Exams',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentDateLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Day Switcher Pill (Today | Tomorrow)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F1E33)
                            : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDayPill(
                            label: 'Today',
                            index: 0,
                            isDark: isDark,
                          ),
                          _buildDayPill(
                            label: 'Tomorrow',
                            index: 1,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Toggle Segmented Control (Classes vs Exams)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F1E33)
                        : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildToggleItem(
                          title: "Classes",
                          count: currentClasses.length,
                          index: 0,
                          isDark: isDark,
                        ),
                      ),
                      Expanded(
                        child: _buildToggleItem(
                          title: "Exams",
                          count: currentExams.length,
                          index: 1,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body: Classes or Exams Timeline / Empty State
          Padding(
            padding: const EdgeInsets.all(20),
            child: _selectedTab == 0
                ? (currentClasses.isEmpty
                    ? _buildEmptyState(context, isDark)
                    : _buildClassesTimeline(context, isDark))
                : (currentExams.isEmpty
                    ? _buildExamsEmptyState(context, isDark)
                    : _buildExamsTimeline(context, isDark)),
          ),

          // Bottom Action: View Full Weekly Routine Link
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9),
                ),
              ),
            ),
            child: InkWell(
              onTap: widget.onViewFullSchedule,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View Full Weekly Routine',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayPill({
    required String label,
    required int index,
    required bool isDark,
  }) {
    final bool isSelected = _selectedDay == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required int count,
    required int index,
    required bool isDark,
  }) {
    final bool isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? const Color(0xFF34D399).withValues(alpha: 0.25)
                          : AppColors.primary.withValues(alpha: 0.12))
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? (isDark ? const Color(0xFF34D399) : AppColors.primary)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 36,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isShowingTomorrow
                  ? 'No classes scheduled for tomorrow'
                  : 'No classes scheduled for today',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isShowingTomorrow
                  ? 'Your next-day timetable is clear for research or office hours.'
                  : 'Check tomorrow’s routine or full weekly timetable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamsEmptyState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_turned_in_rounded,
                size: 36,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isShowingTomorrow
                  ? 'No exams scheduled for tomorrow'
                  : 'No exams scheduled for today',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isShowingTomorrow
                  ? 'Your next-day assessment duties are clear.'
                  : 'No invigilation or assessment duties assigned for today.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesTimeline(BuildContext context, bool isDark) {
    final classes = currentClasses;

    // Each class is its own box, so the list needs no end marker.
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: classes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final slot = classes[index];
        final user = widget.user;
        final examsNow = ExamClashes.examsDuring(slot, ClassTime.dateKey(_shownDate), currentExams);
        return ClassSlotTile(
          slot: slot,
          highlight: index == 0 && !isShowingTomorrow,
          examNote: examsNow.isEmpty ? null : 'Exam in this slot: ${ExamTypes.label(examsNow.first.type)}',
          action: user == null
              ? null
              : ClassModifyButton(user: user, slot: slot, date: _shownDate, onChanged: widget.onChanged),
          // Start Attendance (today's classes that are happening)
          footer: (!isShowingTomorrow && widget.onStartAttendance != null && !slot.isCancelled)
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onStartAttendance!(slot),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                    label: const Text('Start Attendance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildExamsTimeline(BuildContext context, bool isDark) {
    final exams = currentExams;
    final user = widget.user;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final exam = exams[index];
        return ExamTile(
          exam: exam,
          onTap: () async {
            if (user == null) {
              widget.onExamTap?.call(exam);
              return;
            }
            final changed = await ExamDetailsDialog.show(
              context: context,
              exam: exam,
              userRole: user.role,
              userId: user.id,
              teacherAssignedCourseIds: user.assignedCourseIds,
            );
            if (changed == true) widget.onChanged?.call();
          },
        );
      },
    );
  }
}
