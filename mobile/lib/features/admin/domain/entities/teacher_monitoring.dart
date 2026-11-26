import 'package:equatable/equatable.dart';
import '../../../curriculum/domain/entities/class_change.dart';

/// One delivered class day for a course (sessions re-launched on the same day
/// are merged into one class).
class DeliveredClass extends Equatable {
  final String date; // yyyy-MM-dd
  final int sessionCount;
  final int presentCount;

  const DeliveredClass({
    required this.date,
    required this.sessionCount,
    required this.presentCount,
  });

  @override
  List<Object?> get props => [date, sessionCount, presentCount];
}

/// Delivery statistics for one teacher teaching one course.
class CourseDeliveryStats extends Equatable {
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final int year;
  final int semester;
  final bool isLab;

  /// Target number of classes set on the course, or null if not set.
  final int? targetClasses;

  /// Distinct class days on which the teacher ran an attendance session.
  final int classesConducted;

  /// Raw number of attendance sessions (includes same-day re-launches).
  final int sessionCount;

  /// Number of students in the course's Year/Semester cohort (0 if unknown).
  final int cohortSize;

  /// Average students present per class, or null if no classes yet.
  final double? averagePresent;

  /// Weekly recurring routine slots for this teacher & course.
  final int weeklyRoutineSlots;

  /// Routine slot occurrences between the monitoring period start and today,
  /// or null when no period start is set or there is no routine.
  final int? expectedClassesSoFar;

  final String? lastClassDate;

  /// Delivered classes, newest first.
  final List<DeliveredClass> history;

  /// One-day changes in the period (up to today), newest first: extra,
  /// cancelled, moved, and classes the CR reported as not taken.
  final List<ClassChange> changes;

  const CourseDeliveryStats({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.year,
    required this.semester,
    required this.isLab,
    required this.targetClasses,
    required this.classesConducted,
    required this.sessionCount,
    required this.cohortSize,
    required this.averagePresent,
    required this.weeklyRoutineSlots,
    required this.expectedClassesSoFar,
    required this.lastClassDate,
    required this.history,
    this.changes = const [],
  });

  int _count(ClassChangeType t) => changes.where((c) => c.type == t).length;

  /// Classes the CR reported as due but not held.
  int get notTakenCount => _count(ClassChangeType.notTaken);
  int get cancelledCount => _count(ClassChangeType.cancel);
  int get movedCount => _count(ClassChangeType.move);
  int get extraCount => _count(ClassChangeType.extra);

  /// Progress against the course target, 0.0 - 1.0 (capped), or null when
  /// the course has no target set.
  double? get progress {
    final target = targetClasses;
    if (target == null || target <= 0) return null;
    return (classesConducted / target).clamp(0.0, 1.0);
  }

  /// Average student turnout as a fraction of the cohort, or null if unknown.
  double? get averageTurnout {
    if (averagePresent == null || cohortSize <= 0) return null;
    return (averagePresent! / cohortSize).clamp(0.0, 1.0);
  }

  /// Scheduled routine classes that have no matching delivered class so far.
  int? get missedClassesEstimate {
    if (expectedClassesSoFar == null) return null;
    final missed = expectedClassesSoFar! - classesConducted;
    return missed < 0 ? 0 : missed;
  }

  /// Share of scheduled routine classes actually held, 0.0 - 1.0.
  double? get routineAdherence {
    if (expectedClassesSoFar == null || expectedClassesSoFar! <= 0) return null;
    return (classesConducted / expectedClassesSoFar!).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
        courseId,
        courseCode,
        courseTitle,
        year,
        semester,
        isLab,
        targetClasses,
        classesConducted,
        sessionCount,
        cohortSize,
        averagePresent,
        weeklyRoutineSlots,
        expectedClassesSoFar,
        lastClassDate,
        history,
        changes,
      ];
}

/// All courses delivered by one teacher.
class TeacherDeliverySummary extends Equatable {
  final String teacherId;
  final String teacherName;
  final String role; // TEACHER | CHAIRMAN
  final List<CourseDeliveryStats> courses;

  const TeacherDeliverySummary({
    required this.teacherId,
    required this.teacherName,
    required this.role,
    required this.courses,
  });

  int get totalClassesConducted => courses.fold(0, (s, c) => s + c.classesConducted);

  /// Classes reported as not taken across all courses.
  int get totalNotTaken => courses.fold(0, (s, c) => s + c.notTakenCount);
  /// Progress across the courses that have a target set, or null if none do.
  double? get overallProgress {
    final withTarget = courses.where((c) => c.targetClasses != null && c.targetClasses! > 0).toList();
    if (withTarget.isEmpty) return null;
    final held = withTarget.fold<int>(0, (s, c) => s + c.classesConducted);
    final target = withTarget.fold<int>(0, (s, c) => s + c.targetClasses!);
    return (held / target).clamp(0.0, 1.0);
  }

  int? get totalMissedEstimate {
    final known = courses.where((c) => c.missedClassesEstimate != null).toList();
    if (known.isEmpty) return null;
    return known.fold<int>(0, (s, c) => s + c.missedClassesEstimate!);
  }

  String? get lastClassDate {
    final dates = courses.map((c) => c.lastClassDate).whereType<String>().toList()..sort();
    return dates.isEmpty ? null : dates.last;
  }

  @override
  List<Object?> get props => [teacherId, teacherName, role, courses];
}

/// Department-wide monitoring snapshot.
class TeacherMonitoringReport extends Equatable {
  final List<TeacherDeliverySummary> teachers;
  final DateTime? periodStart;
  final DateTime generatedAt;

  const TeacherMonitoringReport({
    required this.teachers,
    required this.periodStart,
    required this.generatedAt,
  });

  int get totalClassesConducted => teachers.fold(0, (s, t) => s + t.totalClassesConducted);
  int get courseCount => teachers.fold(0, (s, t) => s + t.courses.length);

  @override
  List<Object?> get props => [teachers, periodStart, generatedAt];
}
