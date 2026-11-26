import '../../../attendance/domain/entities/attendance_entities.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../curriculum/domain/entities/class_change.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../entities/teacher_monitoring.dart';

/// Pure aggregation of attendance sessions into per-teacher, per-course
/// delivery statistics for the Chairman's monitoring dashboard.
///
/// Counting rules:
///  * A "class conducted" is a distinct calendar day on which the teacher ran
///    at least one attendance session for the course. Re-launching a session
///    on the same day (which closes the previous one) does not double count.
///  * Students present for a class day = the highest `totalPresentCount` among
///    that day's sessions (re-launch splits are not summed, to avoid counting a
///    student twice).
///  * When [periodStart] is given, only sessions on/after that date count, and
///    expected classes = weekly routine slots (non-extra, recurring) that fell
///    between [periodStart] and [now] inclusive.
class TeacherMonitoringCalculator {
  const TeacherMonitoringCalculator._();

  static const _weekdayNames = {
    DateTime.monday: 'MONDAY',
    DateTime.tuesday: 'TUESDAY',
    DateTime.wednesday: 'WEDNESDAY',
    DateTime.thursday: 'THURSDAY',
    DateTime.friday: 'FRIDAY',
    DateTime.saturday: 'SATURDAY',
    DateTime.sunday: 'SUNDAY',
  };

  static TeacherMonitoringReport build({
    required List<User> users,
    required List<Course> courses,
    required List<CourseAssignment> assignments,
    required List<AttendanceSession> sessions,
    required List<ScheduleSlot> routineSlots,
    List<ClassChange> classChanges = const [],
    DateTime? periodStart,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final start = periodStart == null ? null : _dateOnly(periodStart);
    final startKey = start == null ? null : _dateKey(start);
    final todayKey = _dateKey(today);

    final usersById = {for (final u in users) u.id: u};
    final coursesById = {for (final c in courses) c.id: c};

    // Cohort sizes by "year-semester".
    final cohortSizes = <String, int>{};
    for (final u in users) {
      if (u.role.isStudentSide && u.isActive && u.year != null && u.semester != null) {
        final key = '${u.year}-${u.semester}';
        cohortSizes[key] = (cohortSizes[key] ?? 0) + 1;
      }
    }

    // 1. Teacher -> course pairs from assignments, course owners, and sessions.
    final pairs = <String, Set<String>>{};
    void addPair(String teacherId, String courseId) {
      if (teacherId.isEmpty || courseId.isEmpty) return;
      pairs.putIfAbsent(teacherId, () => <String>{}).add(courseId);
    }

    for (final a in assignments) {
      addPair(a.teacherId, a.courseId);
    }
    for (final c in courses) {
      if (c.teacherId != null) addPair(c.teacherId!, c.id);
    }

    // 2. Group sessions by teacher+course, restricted to the period.
    final sessionsByPair = <String, List<AttendanceSession>>{};
    for (final s in sessions) {
      final date = _normalizeDateKey(s.sessionDate);
      if (date == null) continue;
      if (startKey != null && date.compareTo(startKey) < 0) continue;
      if (date.compareTo(todayKey) > 0) continue;
      addPair(s.teacherId, s.courseId);
      sessionsByPair.putIfAbsent('${s.teacherId}|${s.courseId}', () => []).add(s);
    }

    // Include faculty who have no courses yet so the Chairman can see them.
    for (final u in users) {
      if (u.role.hasTeacherAccess) pairs.putIfAbsent(u.id, () => <String>{});
    }

    // 3. Routine slot counts by teacher+course.
    final weeklySlotsByPair = <String, List<String>>{};
    for (final slot in routineSlots) {
      if (slot.isExtraClass || (slot.date != null && slot.date!.isNotEmpty)) continue;
      if ((slot.status ?? 'SCHEDULED').toUpperCase() == 'CANCELLED') continue;
      final teacherId = slot.teacherId.isNotEmpty
          ? slot.teacherId
          : (coursesById[slot.courseId]?.teacherId ?? '');
      if (teacherId.isEmpty) continue;
      weeklySlotsByPair
          .putIfAbsent('$teacherId|${slot.courseId}', () => [])
          .add(slot.dayOfWeek.toUpperCase());
    }

    final dayCounts = start == null ? null : _weekdayOccurrences(start, today);

    // One-day changes inside the period (up to today). They form the class
    // log, and adjust what was expected: a cancelled class is no longer
    // expected, an extra class is. A "not taken" class stays expected, so it
    // shows up as missed.
    final expectedDelta = <String, int>{};
    final changesByPair = <String, List<ClassChange>>{};
    for (final c in classChanges) {
      if (startKey != null && c.date.compareTo(startKey) < 0) continue;
      if (c.date.compareTo(todayKey) > 0) continue;
      final teacherId = c.teacherId.isNotEmpty ? c.teacherId : (coursesById[c.courseId]?.teacherId ?? '');
      if (teacherId.isEmpty) continue;
      final k = '$teacherId|${c.courseId}';
      addPair(teacherId, c.courseId);
      changesByPair.putIfAbsent(k, () => []).add(c);
      if (c.type == ClassChangeType.cancel) expectedDelta[k] = (expectedDelta[k] ?? 0) - 1;
      if (c.type == ClassChangeType.extra) expectedDelta[k] = (expectedDelta[k] ?? 0) + 1;
    }
    for (final list in changesByPair.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }

    final summaries = <TeacherDeliverySummary>[];
    pairs.forEach((teacherId, courseIds) {
      final user = usersById[teacherId];
      final courseStats = <CourseDeliveryStats>[];

      for (final courseId in courseIds) {
        final key = '$teacherId|$courseId';
        final pairSessions = sessionsByPair[key] ?? const <AttendanceSession>[];
        final course = coursesById[courseId];

        // Merge sessions by day.
        final byDay = <String, List<AttendanceSession>>{};
        for (final s in pairSessions) {
          byDay.putIfAbsent(_normalizeDateKey(s.sessionDate)!, () => []).add(s);
        }
        final history = byDay.entries
            .map((e) => DeliveredClass(
                  date: e.key,
                  sessionCount: e.value.length,
                  presentCount: e.value.fold<int>(
                    0,
                    (m, s) => s.totalPresentCount > m ? s.totalPresentCount : m,
                  ),
                ))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final sample = pairSessions.isNotEmpty ? pairSessions.first : null;
        final year = course?.year ?? 0;
        final semester = course?.semester ?? 0;
        final weeklyDays = weeklySlotsByPair[key] ?? const <String>[];
        final base = weeklyDays.fold<int>(0, (sum, d) => sum + (dayCounts?[d] ?? 0));
        final delta = expectedDelta[key] ?? 0;
        final expected = (dayCounts == null || (weeklyDays.isEmpty && delta == 0))
            ? null
            : (base + delta < 0 ? 0 : base + delta);

        courseStats.add(CourseDeliveryStats(
          courseId: courseId,
          courseCode: course?.code ?? sample?.courseCode ?? courseId,
          courseTitle: course?.title ?? sample?.courseTitle ?? '',
          year: year,
          semester: semester,
          isLab: course?.isLab ?? false,
          targetClasses: course?.targetClasses,
          classesConducted: history.length,
          sessionCount: pairSessions.length,
          cohortSize: cohortSizes['$year-$semester'] ?? 0,
          averagePresent: history.isEmpty
              ? null
              : history.fold<int>(0, (s, h) => s + h.presentCount) / history.length,
          weeklyRoutineSlots: weeklyDays.length,
          expectedClassesSoFar: expected,
          lastClassDate: history.isEmpty ? null : history.first.date,
          history: history,
          changes: changesByPair[key] ?? const [],
        ));
      }

      courseStats.sort((a, b) => a.courseCode.compareTo(b.courseCode));

      final fallbackName = sessionsByPair.entries
          .where((e) => e.key.startsWith('$teacherId|') && e.value.isNotEmpty)
          .map((e) => e.value.first.teacherName)
          .firstWhere((n) => n.isNotEmpty, orElse: () => 'Unknown Faculty');

      summaries.add(TeacherDeliverySummary(
        teacherId: teacherId,
        teacherName: (user?.fullName.isNotEmpty ?? false) ? user!.fullName : fallbackName,
        role: user?.role.value ?? 'TEACHER',
        courses: courseStats,
      ));
    });

    // Anyone who ran sessions is listed (even a non-faculty admin), alphabetically.
    summaries.sort((a, b) => a.teacherName.toLowerCase().compareTo(b.teacherName.toLowerCase()));

    return TeacherMonitoringReport(
      teachers: summaries,
      periodStart: start,
      generatedAt: now ?? DateTime.now(),
    );
  }

  /// How many times each weekday occurs between [from] and [to] inclusive.
  static Map<String, int> _weekdayOccurrences(DateTime from, DateTime to) {
    final counts = <String, int>{};
    if (to.isBefore(from)) return counts;
    final days = to.difference(from).inDays + 1;
    final fullWeeks = days ~/ 7;
    for (final name in _weekdayNames.values) {
      counts[name] = fullWeeks;
    }
    final remainder = days % 7;
    for (var i = 0; i < remainder; i++) {
      final d = from.add(Duration(days: fullWeeks * 7 + i));
      final name = _weekdayNames[d.weekday]!;
      counts[name] = counts[name]! + 1;
    }
    return counts;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Accepts "yyyy-MM-dd" or ISO timestamps; returns "yyyy-MM-dd" or null.
  static String? _normalizeDateKey(String raw) {
    if (raw.length >= 10) {
      final head = raw.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(head)) return head;
    }
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? null : _dateKey(parsed);
  }
}
