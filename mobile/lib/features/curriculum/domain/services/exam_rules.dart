import '../../../../core/constants/role_constants.dart';
import '../../../../core/utils/class_time.dart';
import '../../../auth/domain/entities/user.dart';
import '../entities/curriculum_entities.dart';
import 'effective_schedule.dart';

/// Exam types and their labels.
class ExamTypes {
  ExamTypes._();

  static const all = ['MID_TERM', 'FINAL', 'QUIZ', 'LAB_EXAM', 'CT'];

  static String label(String type) => switch (type.toUpperCase()) {
        'FINAL' => 'Final',
        'MID_TERM' => 'Mid-Term',
        'QUIZ' => 'Quiz',
        'LAB_EXAM' => 'Lab Exam',
        'CT' => 'Class Test',
        _ => type,
      };

  /// Default title and length (minutes) for a type.
  static (String, int) preset(String type) => switch (type.toUpperCase()) {
        'FINAL' => ('Semester Final Examination', 180),
        'QUIZ' => ('Quiz', 45),
        'LAB_EXAM' => ('Lab Exam', 180),
        'CT' => ('Class Test', 45),
        _ => ('Mid-Term Examination', 120),
      };
}

/// Who may schedule and change exams. Mirrors `match /exams` in the
/// security rules.
///
/// * Admin / Chairman: any exam.
/// * Teacher: exams of their own courses.
/// * CR: exams of their own semester, every type except the Final.
class ExamPermissions {
  ExamPermissions._();

  static bool isOwnCourse(User user, String courseId, {String? courseTeacherId}) =>
      courseTeacherId == user.id || user.assignedCourseIds.contains(courseId);

  /// Types this user may choose when scheduling.
  static List<String> typesFor(User user) =>
      user.role == UserRole.cr ? ExamTypes.all.where((t) => t != 'FINAL').toList() : ExamTypes.all;

  static bool canSchedule(User user) =>
      user.role.hasAdminAccess || user.role.hasTeacherAccess || user.role == UserRole.cr;

  /// May [user] edit / cancel [exam]? [courseTeacherId] is the course's
  /// teacher when known.
  static bool canManage(User user, Exam exam, {String? courseTeacherId}) {
    if (user.role.hasAdminAccess) return true;
    if (user.role.hasTeacherAccess) {
      return isOwnCourse(user, exam.courseId, courseTeacherId: courseTeacherId) || exam.createdBy == user.id;
    }
    if (user.role == UserRole.cr) {
      return user.year == exam.year && user.semester == exam.semester && exam.type.toUpperCase() != 'FINAL';
    }
    return false;
  }

  /// Only Admin / Chairman delete; everyone else cancels instead.
  static bool canDelete(User user) => user.role.hasAdminAccess;
}

/// Clash check for an exam before saving (no Cloud Functions needed).
class ExamClashes {
  ExamClashes._();

  /// Problems with [exam] given everything else on its date: other exams
  /// ([examsThatDay], all semesters) and classes ([classesThatDay], the
  /// effective schedule for all semesters).
  ///
  /// * Room busy with another exam or another semester's class.
  /// * The semester already has another exam at that time.
  /// * The invigilator is teaching another semester or invigilating.
  ///
  /// The semester's own class at the same time is not a clash: the exam
  /// takes its place (the class shows "Exam in this slot").
  static List<ScheduleClash> find({
    required Exam exam,
    required List<Exam> examsThatDay,
    required List<ScheduleSlot> classesThatDay,
  }) {
    final start = ClassTime.toMinutes(exam.startTime);
    final end = ClassTime.toMinutes(exam.endTime);
    if (start == null || end == null || end <= start) {
      return const [ScheduleClash('TIME', 'The exam must end after it starts.')];
    }
    final room = exam.room.trim().toLowerCase();
    final invigilator = exam.invigilatorId ?? '';
    final out = <ScheduleClash>[];
    String when(String a, String b) => '${ClassTime.normalize(a)}–${ClassTime.normalize(b)}';

    for (final e in examsThatDay) {
      if (e.id == exam.id || e.isCancelled || e.examDate != exam.examDate) continue;
      final s = ClassTime.toMinutes(e.startTime);
      final f = ClassTime.toMinutes(e.endTime);
      if (s == null || f == null || !ClassTime.overlaps(start, end, s, f)) continue;
      if (room.isNotEmpty && e.room.trim().toLowerCase() == room) {
        out.add(ScheduleClash('ROOM', '${e.room} has an exam (${e.courseCode}) at ${when(e.startTime, e.endTime)}.'));
      }
      if (e.year == exam.year && e.semester == exam.semester) {
        out.add(ScheduleClash(
            'BATCH', 'Year ${e.year} · Semester ${e.semester} already has an exam (${e.courseCode}) at ${when(e.startTime, e.endTime)}.'));
      }
      if (invigilator.isNotEmpty && e.invigilatorId == invigilator) {
        out.add(ScheduleClash('TEACHER', 'The invigilator is already on duty (${e.courseCode}) at ${when(e.startTime, e.endTime)}.'));
      }
    }

    for (final c in classesThatDay) {
      if (c.isCancelled) continue;
      final s = ClassTime.toMinutes(c.startTime);
      final f = ClassTime.toMinutes(c.endTime);
      if (s == null || f == null || !ClassTime.overlaps(start, end, s, f)) continue;
      final sameBatch = c.targetYear == exam.year && c.targetSemester == exam.semester;
      if (sameBatch) continue;
      final name = c.courseTitle.isNotEmpty ? c.courseTitle : c.courseCode;
      if (room.isNotEmpty && c.room.trim().toLowerCase() == room) {
        out.add(ScheduleClash('ROOM', '${c.room} has a class ($name) at ${when(c.startTime, c.endTime)}.'));
      }
      if (invigilator.isNotEmpty && c.teacherId == invigilator) {
        out.add(ScheduleClash('TEACHER', 'The invigilator is teaching $name at ${when(c.startTime, c.endTime)}.'));
      }
    }
    return out;
  }

  /// Exams of the class's semester that overlap [slot] on [dateKey].
  static List<Exam> examsDuring(ScheduleSlot slot, String dateKey, List<Exam> exams) {
    final s = ClassTime.toMinutes(slot.startTime);
    final f = ClassTime.toMinutes(slot.endTime);
    if (s == null || f == null) return const [];
    return exams.where((e) {
      if (e.isCancelled || e.examDate != dateKey) return false;
      if (e.year != slot.targetYear || e.semester != slot.targetSemester) return false;
      final a = ClassTime.toMinutes(e.startTime);
      final b = ClassTime.toMinutes(e.endTime);
      return a != null && b != null && ClassTime.overlaps(s, f, a, b);
    }).toList();
  }
}

/// Friendly date words for exams.
class ExamDates {
  ExamDates._();

  static DateTime? parse(String key) => DateTime.tryParse(key);

  /// "Today", "Tomorrow", "in 3 days", "2 days ago".
  static String relative(String dateKey, DateTime now) {
    final d = parse(dateKey);
    if (d == null) return '';
    final diff = ClassTime.dateOnly(d).difference(ClassTime.dateOnly(now)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return diff > 0 ? 'in $diff days' : '${-diff} days ago';
  }

  /// Upcoming = today or later.
  static bool isUpcoming(Exam e, DateTime now) => e.examDate.compareTo(ClassTime.dateKey(now)) >= 0;
}
