import '../../../../core/constants/role_constants.dart';
import '../../../curriculum/presentation/widgets/exam_details_dialog.dart';
import '../../../curriculum/presentation/widgets/exam_tile.dart';
import '../../../curriculum/domain/services/exam_rules.dart';
import '../../../curriculum/presentation/widgets/class_change_note.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/communication/whatsapp_share_dialog.dart';
import '../../../../core/communication/whatsapp_share_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/class_time.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../curriculum/presentation/widgets/class_actions_sheet.dart';
import '../../../curriculum/presentation/widgets/class_slot_tile.dart';
import '../../domain/entities/cr_dashboard_data.dart';

class CrTodayScheduleCard extends StatefulWidget {
  final CrDashboardData data;
  final VoidCallback onViewFullSchedule;
  final VoidCallback? onManageTomorrowTap;

  /// When set (the CR), each class of their semester gets a Modify button.
  final User? user;

  /// Called after a class is changed from its Modify button.
  final VoidCallback? onChanged;

  const CrTodayScheduleCard({
    super.key,
    required this.data,
    required this.onViewFullSchedule,
    this.onManageTomorrowTap,
    this.user,
    this.onChanged,
  });

  @override
  State<CrTodayScheduleCard> createState() => _CrTodayScheduleCardState();
}

class _CrTodayScheduleCardState extends State<CrTodayScheduleCard> {
  int _selectedTab = 0; // 0 for Classes, 1 for Exams
  late int _selectedDay; // 0 for Today, 1 for Tomorrow

  @override
  void initState() {
    super.initState();
    // Respect widget.data.isTomorrow calculated by datasource/domain
    _selectedDay = widget.data.isTomorrow ? 1 : 0;
  }

  bool get isShowingTomorrow => _selectedDay == 1;

  DateTime get _shownDate {
    final today = ClassTime.dateOnly(DateTime.now());
    return isShowingTomorrow ? today.add(const Duration(days: 1)) : today;
  }

  List<ScheduleSlot> get currentClasses =>
      isShowingTomorrow ? widget.data.tomorrowClasses : widget.data.todayClasses;

  String get currentDateLabel {
    final raw = isShowingTomorrow
        ? widget.data.tomorrowDateLabel
        : widget.data.targetDateLabel;
    if (raw.isNotEmpty && !raw.startsWith('Today · ') && !raw.startsWith('Tomorrow · ')) {
      return raw;
    }
    final now = DateTime.now();
    final date = isShowingTomorrow ? now.add(const Duration(days: 1)) : now;
    return DateFormat('EEEE · MMM d, yyyy').format(date);
  }

  void _handleWhatsAppBroadcast(BuildContext context) {
    final buffer = StringBuffer();
    final dayText = isShowingTomorrow ? 'tomorrow' : 'today';
    buffer.writeln('*Department of Computer Science & Engineering, JnU*');
    buffer.writeln('*Class Routine Notice*');
    buffer.writeln('');
    buffer.writeln('*Date:* $currentDateLabel');
    buffer.writeln('*Batch:* Year ${widget.data.year}, Semester ${widget.data.semester}');
    buffer.writeln('────────────────────────────────────────');

    final classes = currentClasses;

    if (classes.isEmpty) {
      buffer.writeln('Notice: There are no classes scheduled for $dayText.');
    } else {
      buffer.writeln('*Scheduled Classes:*');
      buffer.writeln('');
      for (int i = 0; i < classes.length; i++) {
        final slot = classes[i];
        if (slot.isCancelled) {
          buffer.writeln('${i + 1}. ~${slot.courseCode}: ${slot.courseTitle}~ *${slot.isNotTaken ? 'NOT TAKEN' : 'CANCELLED'}*');
          if (ClassChangeNote.shows(slot)) buffer.writeln('   ${slot.changeNote}');
          if (i < classes.length - 1) buffer.writeln('');
          continue;
        }
        buffer.writeln('${i + 1}. *${slot.courseCode}: ${slot.courseTitle}*');
        buffer.writeln('   Time: ${slot.startTime} - ${slot.endTime}');
        buffer.writeln('   Room: ${slot.room}');
        if (slot.teacherName.isNotEmpty) {
          buffer.writeln('   Faculty: ${slot.teacherName}');
        }
        if (slot.isMoved || slot.isExtraClass) {
          buffer.writeln('   Note: ${slot.changeNote ?? 'Extra Class'}');
        }
        if (i < classes.length - 1) {
          buffer.writeln('');
        }
      }
    }

    final messageText = buffer.toString();

    WhatsAppShareDialog.show(
      context,
      title: 'WhatsApp Broadcast',
      subtitle: '$currentDateLabel (Year ${widget.data.year}, Sem ${widget.data.semester})',
      messageText: messageText,
      shareService: sl.isRegistered<WhatsAppShareService>() ? sl<WhatsAppShareService>() : null,
    );
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
          // Header with Title & Date (Time-Aware, Matching Faculty TimeAwareClassesCard)
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
                          // The Today | Tomorrow switch already says which day it is.
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

                    // Day Switcher Pill (Today | Tomorrow) in the same card
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

                // Tomorrow: two quiet links (each class also has its own Modify).
                if (isShowingTomorrow && widget.onManageTomorrowTap != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onManageTomorrowTap,
                        icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                        label: const Text('Change a Class'),
                      ),
                      TextButton.icon(
                        onPressed: () => _handleWhatsAppBroadcast(context),
                        icon: const Icon(Icons.forum_outlined, size: 18),
                        label: const Text('Share on WhatsApp'),
                      ),
                    ],
                  ),
                ],

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
                          count: widget.data.upcomingExams.length,
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
                : (widget.data.upcomingExams.isEmpty
                    ? _buildExamsEmptyState(context, isDark)
                    : _buildExamsTimeline(context, isDark)),
          ),

          // Bottom Action: View Full Routine Link
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
                  ? 'Your next-day timetable is clear for research or self-study.'
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
                  ? 'No upcoming semester examinations scheduled for tomorrow.'
                  : 'No upcoming semester examinations scheduled right now.',
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
        final examsNow = ExamClashes.examsDuring(slot, ClassTime.dateKey(_shownDate), widget.data.upcomingExams);
        return ClassSlotTile(
          slot: slot,
          highlight: index == 0 && !isShowingTomorrow,
          examNote: examsNow.isEmpty ? null : 'Exam in this slot: ${ExamTypes.label(examsNow.first.type)}',
          action: user == null
              ? null
              : ClassModifyButton(
                  user: user,
                  slot: slot,
                  date: _shownDate,
                  onChanged: widget.onChanged,
                ),
        );
      },
    );
  }

  Widget _buildExamsTimeline(BuildContext context, bool isDark) {
    final exams = widget.data.upcomingExams;
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
            final changed = await ExamDetailsDialog.show(
              context: context,
              exam: exam,
              userRole: user?.role ?? UserRole.student,
              userYear: user?.year ?? widget.data.year,
              userSemester: user?.semester ?? widget.data.semester,
              userId: user?.id,
            );
            if (changed == true) widget.onChanged?.call();
          },
        );
      },
    );
  }
}
