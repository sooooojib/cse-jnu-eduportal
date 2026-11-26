import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/class_time.dart';
import '../../../../shared/widgets/dialogs/app_confirmation_dialog.dart';
import '../../../auth/domain/entities/user.dart';
import '../../data/repositories/class_change_repository.dart';
import '../../domain/entities/class_change.dart';
import 'class_change_sheet.dart';

/// "Class changes": one-day extra / cancelled / moved / not-taken classes for
/// the next 7 days, then the past 7 days.
///
/// * Students & CRs see changes for their batch; teachers for their courses.
/// * CRs and teachers get a "Change a class" button; whoever made a change
///   (or an admin) can undo it.
class ClassChangesCard extends StatefulWidget {
  final User user;
  final ClassChangeRepository? repository;

  /// Called after a change is added or undone (e.g. to refresh the dashboard).
  final VoidCallback? onChanged;
  final DateTime? now;

  const ClassChangesCard({super.key, required this.user, this.repository, this.onChanged, this.now});

  @override
  State<ClassChangesCard> createState() => ClassChangesCardState();
}

class ClassChangesCardState extends State<ClassChangesCard> {
  ClassChangeRepository? _repo;
  List<ClassChange> _changes = const [];
  bool _loading = true;

  bool get _canPlan => widget.user.role == UserRole.cr || widget.user.role.hasTeacherAccess;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? (sl.isRegistered<ClassChangeRepository>() ? sl<ClassChangeRepository>() : null);
    reload();
  }

  Future<void> reload() async {
    final repo = _repo;
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final now = widget.now ?? DateTime.now();
    final dates = [...ClassTime.pastDates(now).reversed, ...ClassTime.upcomingDates(now)];
    try {
      final u = widget.user;
      List<ClassChange> list;
      if (u.role.hasTeacherAccess) {
        final courses = await repo.plannableCourses(u);
        list = await repo.changesForCourses(
          courseIds: courses.map((c) => c.id).toSet(),
          from: dates.first,
          to: dates.last,
        );
      } else if (u.year != null && u.semester != null) {
        list = await repo.changesForBatch(year: u.year!, semester: u.semester!, from: dates.first, to: dates.last);
      } else {
        list = const [];
      }
      if (mounted) {
        setState(() {
          _changes = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openSheet() async {
    final saved = await ClassChangeSheet.show(context, user: widget.user, repository: _repo);
    if (saved == true) {
      await reload();
      widget.onChanged?.call();
    }
  }

  Future<void> _undo(ClassChange c) async {
    final ok = await AppConfirmationDialog.show(
      context: context,
      title: 'Undo this change?',
      message: '${c.type.label} for ${c.courseCode} on ${_day(c.date)} will be removed.',
      confirmText: 'Undo',
      isDestructive: true,
      icon: Icons.undo_rounded,
    );
    if (ok != true || _repo == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo!.undo(c.id);
      await reload();
      widget.onChanged?.call();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not undo: $e'), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  String _day(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    final today = ClassTime.dateOnly(widget.now ?? DateTime.now());
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('EEE, MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      key: const ValueKey('class_changes_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13263E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Class Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (_canPlan)
                TextButton.icon(
                  key: const ValueKey('open_change_sheet'),
                  onPressed: _openSheet,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: const Text('Change'),
                ),
            ],
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator(minHeight: 3))
          else ...[
            if (_upcomingChanges.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _canPlan
                      ? 'No changes in the next 7 days. Add an extra class, cancel or move one with "Change".'
                      : 'No changes in the next 7 days. Classes follow the normal routine.',
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
              )
            else
              ..._upcomingChanges.map((c) => _row(c, isDark, muted)),
            if (_pastChanges.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Past 7 days', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: muted)),
              ..._pastChanges.map((c) => _row(c, isDark, muted)),
            ],
          ],
        ],
      ),
    );
  }

  String get _todayKey => ClassTime.dateKey(widget.now ?? DateTime.now());

  /// Today onward, soonest first.
  List<ClassChange> get _upcomingChanges => _changes.where((c) => c.date.compareTo(_todayKey) >= 0).toList();

  /// Before today, most recent first.
  List<ClassChange> get _pastChanges =>
      _changes.where((c) => c.date.compareTo(_todayKey) < 0).toList()..sort((a, b) => b.date.compareTo(a.date));

  Widget _row(ClassChange c, bool isDark, Color muted) {
    final (color, icon) = switch (c.type) {
      ClassChangeType.extra => (const Color(0xFF047857), Icons.add_circle_outline_rounded),
      ClassChangeType.cancel => (const Color(0xFFDC2626), Icons.event_busy_rounded),
      ClassChangeType.move => (const Color(0xFFD97706), Icons.swap_horiz_rounded),
      ClassChangeType.notTaken => (const Color(0xFF9F1239), Icons.person_off_outlined),
    };
    final detail = switch (c.type) {
      ClassChangeType.extra => '${c.startTime}–${c.endTime} · ${c.room}',
      ClassChangeType.cancel => '${c.startTime}–${c.endTime} · ${c.room}',
      ClassChangeType.notTaken => '${c.startTime}–${c.endTime} · ${c.teacherName.isNotEmpty ? c.teacherName : c.room}',
      ClassChangeType.move => 'Now ${c.startTime}–${c.endTime} · ${c.room} (was ${c.originalStartTime ?? ''}, ${c.originalRoom ?? ''})',
    };
    final canUndo = c.createdBy == widget.user.id || widget.user.role.hasAdminAccess;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_day(c.date), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                      child: Text(c.type.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${c.courseCode}: ${c.courseTitle}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(detail, style: TextStyle(fontSize: 12, color: muted)),
                if ((c.reason ?? '').isNotEmpty) Text('“${c.reason}”', style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
          if (canUndo)
            IconButton(
              tooltip: 'Undo',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.undo_rounded, size: 18),
              onPressed: () => _undo(c),
            ),
        ],
      ),
    );
  }
}
