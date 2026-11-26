import '../../../../core/utils/class_time.dart';
import '../entities/class_change.dart';
import '../entities/curriculum_entities.dart';

/// A clash found when planning a change, in plain words for the user.
class ScheduleClash {
  final String kind; // ROOM | TEACHER | BATCH
  final String message;
  const ScheduleClash(this.kind, this.message);
}

/// Combines the weekly routine with one-day changes.
///
/// Rules:
///  * Routine slots repeat weekly by `dayOfWeek`. Legacy slots that carry a
///    specific `date` only apply on that date.
///  * CANCEL keeps the class in the list with status CANCELLED (so students
///    see it was cancelled) but it no longer occupies a room or teacher.
///  * MOVE replaces the time/room for that date, status MOVED.
///  * EXTRA adds a one-day class.
///  * NOT_TAKEN marks a routine, moved or extra class as not held (status
///    NOT_TAKEN, reported after the fact by the CR).
class EffectiveSchedule {
  EffectiveSchedule._();

  static List<ScheduleSlot> forDate({
    required List<ScheduleSlot> routine,
    required List<ClassChange> changes,
    required DateTime date,
  }) {
    final key = ClassTime.dateKey(date);
    final day = ClassTime.dayOfWeek(date);

    final todays = changes.where((c) => c.date == key).toList();
    final cancels = {for (final c in todays.where((c) => c.type == ClassChangeType.cancel)) c.originalSlotId: c};
    final moves = {for (final c in todays.where((c) => c.type == ClassChangeType.move)) c.originalSlotId: c};
    final notTaken = {for (final c in todays.where((c) => c.type == ClassChangeType.notTaken)) c.originalSlotId: c};

    final result = <ScheduleSlot>[];
    for (final s in routine) {
      if (s.dayOfWeek.toUpperCase() != day) continue;
      if (s.date != null && s.date!.isNotEmpty && s.date != key) continue;
      if (s.isCancelled) continue;

      final cancel = cancels[s.id];
      final move = moves[s.id];
      if (cancel != null) {
        result.add(s.copyWith(
          status: 'CANCELLED',
          changeNote: (cancel.reason?.trim().isNotEmpty ?? false) ? 'Cancelled: ${cancel.reason!.trim()}' : 'Cancelled',
        ));
      } else if (move != null) {
        result.add(s.copyWith(
          startTime: move.startTime,
          endTime: move.endTime,
          room: move.room,
          status: 'MOVED',
          changeNote: 'Moved from ${ClassTime.normalize(s.startTime)}, ${s.room}',
        ));
      } else {
        result.add(s);
      }
    }

    for (final c in todays.where((c) => c.type == ClassChangeType.extra)) {
      result.add(ScheduleSlot(
        id: 'change_${c.id}',
        courseId: c.courseId,
        courseCode: c.courseCode,
        courseTitle: c.courseTitle,
        teacherId: c.teacherId,
        teacherName: c.teacherName,
        dayOfWeek: day,
        startTime: c.startTime,
        endTime: c.endTime,
        room: c.room,
        targetYear: c.targetYear,
        targetSemester: c.targetSemester,
        isExtraClass: true,
        date: key,
        status: 'SCHEDULED',
        createdBy: c.createdBy,
        changeNote: (c.reason?.trim().isNotEmpty ?? false) ? 'Extra class: ${c.reason!.trim()}' : 'Extra class',
      ));
    }

    // Not-taken reports apply last, on top of a move or to an extra class.
    for (var i = 0; i < result.length; i++) {
      final s = result[i];
      final report = notTaken[s.id];
      if (report == null || s.isCancelled) continue;
      final why = report.reason?.trim() ?? '';
      result[i] = s.copyWith(status: 'NOT_TAKEN', changeNote: why.isNotEmpty ? 'Not taken: $why' : 'Not taken');
    }

    result.sort((a, b) => (ClassTime.toMinutes(a.startTime) ?? 0).compareTo(ClassTime.toMinutes(b.startTime) ?? 0));
    return result;
  }

  /// Checks a planned class against everything happening on [date] (all
  /// batches). [ignoreSlotId] is the routine slot being moved, so it does not
  /// clash with itself.
  static List<ScheduleClash> findClashes({
    required List<ScheduleSlot> routine,
    required List<ClassChange> changes,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String room,
    required String teacherId,
    required int targetYear,
    required int targetSemester,
    String? ignoreSlotId,
  }) {
    final start = ClassTime.toMinutes(startTime);
    final end = ClassTime.toMinutes(endTime);
    if (start == null || end == null || end <= start) {
      return const [ScheduleClash('TIME', 'End time must be after start time.')];
    }
    final roomKey = room.trim().toLowerCase();
    final clashes = <ScheduleClash>[];

    for (final s in forDate(routine: routine, changes: changes, date: date)) {
      if (s.isCancelled || s.id == ignoreSlotId) continue;
      final ss = ClassTime.toMinutes(s.startTime);
      final se = ClassTime.toMinutes(s.endTime);
      if (ss == null || se == null || !ClassTime.overlaps(start, end, ss, se)) continue;

      final when = '${ClassTime.normalize(s.startTime)}–${ClassTime.normalize(s.endTime)}';
      if (roomKey.isNotEmpty && s.room.trim().toLowerCase() == roomKey) {
        clashes.add(ScheduleClash('ROOM', '${s.room} is booked for ${s.courseCode} at $when.'));
      }
      if (teacherId.isNotEmpty && s.teacherId == teacherId) {
        clashes.add(ScheduleClash('TEACHER', '${s.teacherName.isNotEmpty ? s.teacherName : 'The teacher'} is teaching ${s.courseCode} at $when.'));
      }
      if (s.targetYear == targetYear && s.targetSemester == targetSemester) {
        clashes.add(ScheduleClash('BATCH', 'Your batch already has ${s.courseCode} at $when.'));
      }
    }
    return clashes;
  }

  /// Distinct class periods used in the routine (for quick time buttons).
  static List<(String, String)> commonPeriods(List<ScheduleSlot> routine, {int max = 6}) {
    final counts = <String, int>{};
    final pairs = <String, (String, String)>{};
    for (final s in routine) {
      final a = ClassTime.toMinutes(s.startTime);
      final b = ClassTime.toMinutes(s.endTime);
      if (a == null || b == null || b <= a) continue;
      final k = '$a-$b';
      counts[k] = (counts[k] ?? 0) + 1;
      pairs[k] = (ClassTime.format(a), ClassTime.format(b));
    }
    final keys = counts.keys.toList()
      ..sort((x, y) => int.parse(x.split('-')[0]).compareTo(int.parse(y.split('-')[0])));
    final top = (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(max).map((e) => e.key).toSet();
    return keys.where(top.contains).map((k) => pairs[k]!).toList();
  }
}
