import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/services/exam_rules.dart';
import 'class_slot_tile.dart';

/// One exam in a list, in the same calm style as the class blocks:
///
///   Thu, Nov 26 · 10:00 AM – 12:00 PM              in 3 days
///   Operating Systems
///   Mid-Term · Room 401
///   (Postponed from … / Cancelled: …)
class ExamTile extends StatelessWidget {
  final Exam exam;
  final VoidCallback? onTap;
  final DateTime? now;

  const ExamTile({super.key, required this.exam, this.onTap, this.now});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strong = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final off = exam.isCancelled;
    final strike = off ? TextDecoration.lineThrough : null;
    final d = DateTime.tryParse(exam.examDate);
    final date = d == null ? exam.examDate : DateFormat('EEE, MMM d').format(d);
    final rel = ExamDates.relative(exam.examDate, now ?? DateTime.now());
    final soon = rel == 'Today' || rel == 'Tomorrow';
    final small = TextStyle(fontSize: 12.5, color: muted, decoration: strike);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('exam_tile_${exam.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F5F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$date · ${ClassSlotTile.timeRange(exam.startTime, exam.endTime)}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted, decoration: strike),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (rel.isNotEmpty && !off)
                    Text(
                      rel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: soon ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)) : muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                exam.courseTitle.isNotEmpty ? exam.courseTitle : exam.courseCode,
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
              Text(
                [
                  exam.title.isNotEmpty && exam.title != ExamTypes.preset(exam.type).$1
                      ? '${ExamTypes.label(exam.type)}: ${exam.title}'
                      : ExamTypes.label(exam.type),
                  exam.room,
                ].join(' · '),
                style: small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((exam.invigilatorName ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Invigilator: ${exam.invigilatorName}', style: small, overflow: TextOverflow.ellipsis),
                ),
              if (off)
                _note((exam.statusNote ?? '').isNotEmpty ? 'Cancelled: ${exam.statusNote}' : 'Cancelled',
                    const Color(0xFFDC2626), Icons.event_busy_rounded)
              else if (exam.wasMoved)
                _note('Postponed from ${_short(exam.previousDate!)}', const Color(0xFFD97706), Icons.swap_horiz_rounded),
            ],
          ),
        ),
      ),
    );
  }

  static String _short(String key) {
    final d = DateTime.tryParse(key);
    return d == null ? key : DateFormat('EEE, MMM d').format(d);
  }

  Widget _note(String text, Color color, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(text,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      );
}
