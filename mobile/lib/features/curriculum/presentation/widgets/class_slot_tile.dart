import 'package:flutter/material.dart';
import '../../../../core/utils/class_time.dart';
import '../../domain/entities/curriculum_entities.dart';
import 'class_change_note.dart';
import 'course_kinds.dart';

/// The one class block used everywhere a class is listed (dashboards,
/// Schedule tab, central routine). Calm, calendar-style:
///
///   2:00 – 3:30 PM
///   Microprocessors & Assembly Language
///   Hardware Lab 2 · Theory
///   Dr. Md. Abu Layek                         Modify ›
///
/// Each class is its own soft block (fill only: no border, no stripe).
/// The course code is left out on purpose. A one-day change shows as a
/// small coloured note; a class that is not happening is struck through.
class ClassSlotTile extends StatelessWidget {
  final ScheduleSlot slot;

  /// Small widget at the end of the teacher line (e.g. the Modify button).
  final Widget? action;

  /// Extra content under the details (e.g. Start Attendance).
  final Widget? footer;

  /// Prefix the room line with the weekday (for "All days" lists).
  final bool showDay;

  /// Kept for callers; the block no longer changes for the next class.
  final bool highlight;

  /// "Exam in this slot: Mid-Term" when the semester has an exam then.
  final String? examNote;

  const ClassSlotTile({
    super.key,
    required this.slot,
    this.action,
    this.footer,
    this.showDay = false,
    this.highlight = false,
    this.examNote,
  });

  /// "9:00 AM" (no leading zero).
  static String shortTime(String raw) {
    final t = ClassTime.normalize(raw);
    return t.startsWith('0') ? t.substring(1) : t;
  }

  /// "9:00 – 10:30 AM", or "11:30 AM – 1:00 PM" across noon.
  static String timeRange(String start, String end) {
    final s = shortTime(start);
    final e = shortTime(end);
    if (s.length > 3 && e.length > 3 && s.substring(s.length - 2) == e.substring(e.length - 2)) {
      return '${s.substring(0, s.length - 3)} – $e';
    }
    return '$s – $e';
  }

  static bool _guessLab(ScheduleSlot s) {
    final t = s.courseTitle.toLowerCase();
    return t.contains('lab') || t.contains('sessional');
  }

  static String _dayLabel(String day) =>
      day.length < 3 ? day : day[0].toUpperCase() + day.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    CourseKinds.ensureLoaded();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strong = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final off = slot.isCancelled;
    final strike = off ? TextDecoration.lineThrough : null;
    final small = TextStyle(fontSize: 12.5, color: muted, decoration: strike);

    return ValueListenableBuilder<int>(
      valueListenable: CourseKinds.version,
      builder: (context, _, __) {
        final isLab = CourseKinds.isLab(slot.courseId) ?? _guessLab(slot);

        return Container(
          key: ValueKey('class_tile_${slot.id}'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F5F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeRange(slot.startTime, slot.endTime),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted, decoration: strike),
              ),
              const SizedBox(height: 3),
              Text(
                slot.courseTitle.isNotEmpty ? slot.courseTitle : slot.courseCode,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: off ? muted : strong,
                  decoration: strike,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      [
                        if (showDay) _dayLabel(slot.dayOfWeek),
                        slot.room.isNotEmpty ? slot.room : 'Room not set',
                      ].join(' · '),
                      style: small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(' · ', style: small),
                  Text(isLab ? 'Lab' : 'Theory', style: small),
                  // Old one-off extra classes carry no change note; tag them here.
                  if (slot.isExtraClass && !ClassChangeNote.shows(slot)) ...[
                    Text(' · ', style: small),
                    Text(
                      'Extra',
                      style: small.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slot.teacherName.isNotEmpty ? slot.teacherName : 'Teacher not set',
                      style: small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (action != null) ...[const SizedBox(width: 8), action!],
                ],
              ),
              if (ClassChangeNote.shows(slot)) ClassChangeNote(slot: slot),
              if (examNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    key: ValueKey('exam_note_${slot.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 13, color: Color(0xFF7C3AED)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            examNote!,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (footer != null) footer!,
            ],
          ),
        );
      },
    );
  }
}
