import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/class_time.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../auth/domain/entities/user.dart';
import '../../data/repositories/class_change_repository.dart';
import '../../domain/entities/class_change.dart';
import '../../domain/entities/curriculum_entities.dart';
import 'class_change_sheet.dart';

/// What can be done to one class on one date from its Modify button.
enum ClassAction { move, cancel, notTaken, undo }

/// Rules for the Modify button. Kept pure so they are easy to test.
class ClassActions {
  ClassActions._();

  /// CR: classes of their own semester. Teacher / Chairman: their own courses.
  static bool canModify(User user, ScheduleSlot slot) {
    if (user.role == UserRole.cr) {
      return slot.targetYear == user.year && slot.targetSemester == user.semester;
    }
    if (user.role.hasTeacherAccess) {
      return slot.teacherId == user.id || user.assignedCourseIds.contains(slot.courseId);
    }
    return false;
  }

  /// True when the slot already carries a one-day change that might be undone.
  static bool hasChange(ScheduleSlot slot) => slot.isCancelled || slot.isMoved || slot.id.startsWith('change_');

  /// Options offered for [slot] on [date], given the time [now].
  ///
  /// * Move / Cancel: the class has not started yet (and is not already
  ///   changed: undo first).
  /// * Not taken (CR only): the class time has started or passed, within the
  ///   past 7 days.
  /// * Undo: the class carries a change (checked against its creator when the
  ///   menu opens).
  static List<ClassAction> available({
    required User user,
    required ScheduleSlot slot,
    required DateTime date,
    required DateTime now,
  }) {
    if (!canModify(user, slot)) return const [];
    final today = ClassTime.dateOnly(now);
    final day = ClassTime.dateOnly(date);
    final daysAgo = today.difference(day).inDays;
    final nowMin = now.hour * 60 + now.minute;
    final startMin = ClassTime.toMinutes(slot.startTime) ?? 0;
    final started = daysAgo > 0 || (daysAgo == 0 && nowMin >= startMin);
    final isCr = user.role == UserRole.cr;

    final out = <ClassAction>[];
    final plain = !slot.isCancelled && !slot.isMoved && !slot.isExtraClass;
    if (plain && !started && daysAgo <= 0) out.addAll([ClassAction.move, ClassAction.cancel]);
    if (isCr && started && !slot.isCancelled && daysAgo <= 7) out.add(ClassAction.notTaken);
    if (hasChange(slot) && daysAgo <= 7) out.add(ClassAction.undo);
    return out;
  }
}

/// Small rounded "Modify" button shown at the end of a class row for the CR
/// (own semester) and teachers (own courses). Hidden when nothing applies.
class ClassModifyButton extends StatelessWidget {
  final User user;
  final ScheduleSlot slot;
  final DateTime date;
  final VoidCallback? onChanged;
  final ClassChangeRepository? repository;
  final DateTime? now;

  const ClassModifyButton({
    super.key,
    required this.user,
    required this.slot,
    required this.date,
    this.onChanged,
    this.repository,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final actions = ClassActions.available(user: user, slot: slot, date: date, now: now ?? DateTime.now());
    if (actions.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
    // Plain text link: quiet, but clearly tappable.
    return InkWell(
      key: ValueKey('modify_${slot.id}'),
      borderRadius: BorderRadius.circular(999),
      onTap: () => ClassActionsSheet.show(
        context,
        user: user,
        slot: slot,
        date: date,
        actions: actions,
        onChanged: onChanged,
        repository: repository,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Modify', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: green)),
            Icon(Icons.chevron_right_rounded, size: 18, color: green),
          ],
        ),
      ),
    );
  }
}

/// The short menu opened by Modify. Each option opens the change form with
/// the class and day already chosen.
class ClassActionsSheet extends StatefulWidget {
  final User user;
  final ScheduleSlot slot;
  final DateTime date;
  final List<ClassAction> actions;
  final ClassChangeRepository? repository;

  const ClassActionsSheet({
    super.key,
    required this.user,
    required this.slot,
    required this.date,
    required this.actions,
    this.repository,
  });

  static Future<void> show(
    BuildContext context, {
    required User user,
    required ScheduleSlot slot,
    required DateTime date,
    required List<ClassAction> actions,
    VoidCallback? onChanged,
    ClassChangeRepository? repository,
  }) async {
    final picked = await showModalBottomSheet<ClassAction>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ClassActionsSheet(user: user, slot: slot, date: date, actions: actions, repository: repository),
    );
    if (picked == null || !context.mounted) return;

    if (picked == ClassAction.undo) {
      final repo = repository ?? sl<ClassChangeRepository>();
      final change = await findChange(repo, slot, date);
      if (change == null || !context.mounted) return;
      final ok = await AppConfirmationDialog.show(
        context: context,
        title: 'Undo this change?',
        message: '${change.type.label} for ${slot.courseTitle.isNotEmpty ? slot.courseTitle : slot.courseCode} '
            'on ${DateFormat('EEE, MMM d').format(date)} will be removed.',
        confirmText: 'Undo',
        isDestructive: true,
        icon: Icons.undo_rounded,
      );
      if (ok != true || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await repo.undo(change.id);
        onChanged?.call();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Could not undo: $e'), backgroundColor: const Color(0xFFDC2626)));
      }
      return;
    }

    final type = switch (picked) {
      ClassAction.move => ClassChangeType.move,
      ClassAction.cancel => ClassChangeType.cancel,
      _ => ClassChangeType.notTaken,
    };
    final saved = await ClassChangeSheet.show(
      context,
      user: user,
      initialType: type,
      initialDate: date,
      initialSlotId: slot.id,
      repository: repository,
    );
    if (saved == true) onChanged?.call();
  }

  /// The change behind a changed slot on [date] (null if none).
  static Future<ClassChange?> findChange(ClassChangeRepository repo, ScheduleSlot slot, DateTime date) async {
    final changes = await repo.changesOn(date);
    if (slot.id.startsWith('change_')) {
      final id = slot.id.substring('change_'.length);
      // A not-taken report on an extra class is newer than the extra itself.
      return changes.where((c) => c.originalSlotId == slot.id).firstOrNull ??
          changes.where((c) => c.id == id).firstOrNull;
    }
    final wanted = slot.isNotTaken
        ? ClassChangeType.notTaken
        : (slot.isMoved ? ClassChangeType.move : ClassChangeType.cancel);
    return changes.where((c) => c.originalSlotId == slot.id && c.type == wanted).firstOrNull;
  }

  @override
  State<ClassActionsSheet> createState() => _ClassActionsSheetState();
}

class _ClassActionsSheetState extends State<ClassActionsSheet> {
  /// Undo is shown only once we know who made the change.
  bool _checkingUndo = false;
  ClassChange? _change;

  bool get _offersUndo => widget.actions.contains(ClassAction.undo);

  @override
  void initState() {
    super.initState();
    if (_offersUndo) _checkUndo();
  }

  Future<void> _checkUndo() async {
    setState(() => _checkingUndo = true);
    try {
      final repo = widget.repository ?? sl<ClassChangeRepository>();
      final c = await ClassActionsSheet.findChange(repo, widget.slot, widget.date);
      if (mounted) setState(() => _change = c);
    } catch (_) {
      // Leave undo hidden.
    } finally {
      if (mounted) setState(() => _checkingUndo = false);
    }
  }

  bool get _canUndo =>
      _change != null && (_change!.createdBy == widget.user.id || widget.user.role.hasAdminAccess);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final s = widget.slot;
    final when = '${DateFormat('EEE, MMM d').format(widget.date)} · '
        '${ClassTime.normalize(s.startTime)}–${ClassTime.normalize(s.endTime)}';

    Widget option(ClassAction a, IconData icon, Color color, String title, String subtitle) => ListTile(
          key: ValueKey('class_action_${a.name}'),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, size: 18, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () => Navigator.of(context).pop(a),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.courseTitle.isNotEmpty ? s.courseTitle : s.courseCode,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(when, style: TextStyle(fontSize: 12.5, color: muted)),
              ],
            ),
          ),
          if (widget.actions.contains(ClassAction.move))
            option(ClassAction.move, Icons.swap_horiz_rounded, const Color(0xFFD97706), 'Move or change room',
                'New time or room for this day only'),
          if (widget.actions.contains(ClassAction.cancel))
            option(ClassAction.cancel, Icons.event_busy_rounded, const Color(0xFFDC2626), 'Cancel class',
                'Students see it struck through with your reason'),
          if (widget.actions.contains(ClassAction.notTaken))
            option(ClassAction.notTaken, Icons.person_off_outlined, const Color(0xFF9F1239), 'Mark not taken',
                'The class was due but did not happen'),
          if (_offersUndo && _checkingUndo)
            const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator(minHeight: 3)),
          if (_offersUndo && !_checkingUndo && _canUndo)
            option(ClassAction.undo, Icons.undo_rounded, const Color(0xFF475569), 'Undo change',
                'Back to the normal routine for this day'),
          if (_offersUndo && !_checkingUndo && _change != null && !_canUndo)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                '${_change!.type.label} by ${_change!.createdByName.isNotEmpty ? _change!.createdByName : 'someone else'}. '
                'Only they or an admin can undo it.',
                style: TextStyle(fontSize: 12.5, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}
