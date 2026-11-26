import 'package:flutter/material.dart';
import '../../domain/entities/curriculum_entities.dart';

/// Small coloured line under a class in a schedule list explaining a one-day
/// change: "Cancelled: Teacher on leave", "Moved from 09:00 AM, Room 302",
/// "Extra class", "Not taken".
class ClassChangeNote extends StatelessWidget {
  final ScheduleSlot slot;

  const ClassChangeNote({super.key, required this.slot});

  static bool shows(ScheduleSlot slot) => slot.changeNote != null && slot.changeNote!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Color color = slot.isNotTaken
        ? const Color(0xFF9F1239)
        : slot.isCancelled
            ? const Color(0xFFDC2626)
            : (slot.isMoved ? const Color(0xFFD97706) : const Color(0xFF047857));
    final IconData icon = slot.isNotTaken
        ? Icons.person_off_outlined
        : slot.isCancelled
            ? Icons.event_busy_rounded
            : (slot.isMoved ? Icons.swap_horiz_rounded : Icons.add_circle_outline_rounded);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                slot.changeNote!,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
