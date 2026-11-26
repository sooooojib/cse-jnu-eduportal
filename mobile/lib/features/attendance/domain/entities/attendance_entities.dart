import 'package:equatable/equatable.dart';

class AttendanceSession extends Equatable {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String teacherId;
  final String teacherName;
  final String code;
  final bool isActive;
  final String status;
  final String sessionDate;
  final int totalPresentCount;
  final String createdAt;
  final DateTime? expiresAt;

  /// CODE: students enter a rotating code. MANUAL: the teacher marks the
  /// roster by hand (no code).
  final String mode;

  /// After this time a self-marked student counts as LATE.
  final DateTime? lateAfter;

  /// The routine / one-day class this session belongs to (if started from it).
  final String? slotId;
  final int? targetYear;
  final int? targetSemester;

  bool get isManualMode => mode.toUpperCase() == 'MANUAL';

  const AttendanceSession({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.teacherId,
    required this.teacherName,
    required this.code,
    required this.isActive,
    required this.status,
    required this.sessionDate,
    this.totalPresentCount = 0,
    required this.createdAt,
    this.expiresAt,
    this.mode = 'CODE',
    this.lateAfter,
    this.slotId,
    this.targetYear,
    this.targetSemester,
  });

  AttendanceSession copyWith({String? code, bool? isActive, DateTime? expiresAt, String? status}) => AttendanceSession(
        id: id,
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
        teacherId: teacherId,
        teacherName: teacherName,
        code: code ?? this.code,
        isActive: isActive ?? this.isActive,
        status: status ?? this.status,
        sessionDate: sessionDate,
        totalPresentCount: totalPresentCount,
        createdAt: createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        mode: mode,
        lateAfter: lateAfter,
        slotId: slotId,
        targetYear: targetYear,
        targetSemester: targetSemester,
      );

  @override
  List<Object?> get props => [
        mode,
        lateAfter,
        slotId,
        targetYear,
        targetSemester,
        id,
        courseId,
        courseCode,
        courseTitle,
        teacherId,
        teacherName,
        code,
        isActive,
        status,
        sessionDate,
        totalPresentCount,
        createdAt,
        expiresAt,
      ];
}

class AttendanceRosterItem extends Equatable {
  final String studentId;
  final String studentRoll;
  final String studentName;
  final String status; // 'PRESENT' | 'LATE' | 'ABSENT'
  final bool isManualOverride;
  final String? verifiedAt;

  /// Who set the current status: 'SELF' (entered the code) or 'TEACHER'.
  /// Null when no record exists yet.
  final String? markedBy;

  const AttendanceRosterItem({
    required this.studentId,
    required this.studentRoll,
    required this.studentName,
    required this.status,
    this.isManualOverride = false,
    this.verifiedAt,
    this.markedBy,
  });

  /// Counts as attended (on time or late).
  bool get isPresent => status == 'PRESENT' || status == 'LATE';
  bool get isLate => status == 'LATE';
  bool get hasRecord => markedBy != null;

  AttendanceRosterItem copyWith({
    String? status,
    bool? isManualOverride,
    String? verifiedAt,
    String? markedBy,
  }) {
    return AttendanceRosterItem(
      studentId: studentId,
      studentRoll: studentRoll,
      studentName: studentName,
      status: status ?? this.status,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      markedBy: markedBy ?? this.markedBy,
    );
  }

  @override
  List<Object?> get props => [studentId, studentRoll, studentName, status, isManualOverride, verifiedAt, markedBy];
}

class SessionRoster extends Equatable {
  final String sessionId;
  final String courseCode;
  final String courseTitle;
  final String sessionDate;
  final String? code;
  final bool isActive;
  final int totalEnrolled;
  final int totalPresent;
  final List<AttendanceRosterItem> roster;

  const SessionRoster({
    required this.sessionId,
    required this.courseCode,
    required this.courseTitle,
    required this.sessionDate,
    this.code,
    required this.isActive,
    required this.totalEnrolled,
    required this.totalPresent,
    required this.roster,
  });

  @override
  List<Object?> get props => [sessionId, courseCode, courseTitle, sessionDate, code, isActive, totalEnrolled, totalPresent, roster];
}

class CourseAttendance extends Equatable {
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final int attendedClasses;
  final int totalClasses;
  final double percentage;
  final bool isEligible;

  /// Class days ("yyyy-MM-dd") the student missed, newest first.
  final List<String> absentDates;
  final int lateCount;

  const CourseAttendance({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.attendedClasses,
    required this.totalClasses,
    required this.percentage,
    required this.isEligible,
    this.absentDates = const [],
    this.lateCount = 0,
  });

  /// How many more classes can be missed and stay at 75% or above
  /// (null when already below 75%).
  int? get canMiss {
    if (totalClasses == 0) return null;
    final x = (attendedClasses / 0.75 - totalClasses).floor();
    return x >= 0 ? x : null;
  }

  /// Classes in a row needed to get back to 75% (0 when already there).
  int get needToAttend {
    final n = (3 * totalClasses - 4 * attendedClasses);
    return n > 0 ? n : 0;
  }

  @override
  List<Object?> get props =>
      [courseId, courseCode, courseTitle, attendedClasses, totalClasses, percentage, isEligible, absentDates, lateCount];
}

class AttendanceRecord extends Equatable {
  final String id;
  final String? sessionId;
  final String? courseId;
  final String courseCode;
  final String courseTitle;
  final String status;
  final String verifiedAt;
  final String? date;
  final String? studentId;
  final String? studentName;
  final String? studentRoll;
  final bool isManualOverride;

  const AttendanceRecord({
    required this.id,
    this.sessionId,
    this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.status,
    required this.verifiedAt,
    this.date,
    this.studentId,
    this.studentName,
    this.studentRoll,
    this.isManualOverride = false,
  });

  @override
  List<Object?> get props => [
        id,
        sessionId,
        courseId,
        courseCode,
        courseTitle,
        status,
        verifiedAt,
        date,
        studentId,
        studentName,
        studentRoll,
        isManualOverride,
      ];
}

class AttendanceVerificationResult extends Equatable {
  final bool success;
  final String message;
  final String? courseCode;
  final String? courseTitle;
  final String? recordId;

  const AttendanceVerificationResult({
    required this.success,
    required this.message,
    this.courseCode,
    this.courseTitle,
    this.recordId,
  });

  @override
  List<Object?> get props => [success, message, courseCode, courseTitle, recordId];
}

class AttendanceSummary extends Equatable {
  final double overallPercentage;
  final int totalAttended;
  final int totalSessions;
  final List<CourseAttendance> courseSummaries;
  final List<AttendanceRecord> recentRecords;
  final bool isFromCache;

  const AttendanceSummary({
    required this.overallPercentage,
    required this.totalAttended,
    required this.totalSessions,
    required this.courseSummaries,
    required this.recentRecords,
    this.isFromCache = false,
  });

  @override
  List<Object?> get props => [overallPercentage, totalAttended, totalSessions, courseSummaries, recentRecords, isFromCache];
}


/// One student's line in a course attendance report.
class StudentAttendanceRow extends Equatable {
  final String studentId;
  final String studentRoll;
  final String studentName;
  final int attended;
  final int late;
  final int held;

  const StudentAttendanceRow({
    required this.studentId,
    required this.studentRoll,
    required this.studentName,
    required this.attended,
    required this.late,
    required this.held,
  });

  double get percentage => held == 0 ? 0 : attended / held * 100;
  bool get isBelow75 => held > 0 && percentage < 75;

  @override
  List<Object?> get props => [studentId, studentRoll, studentName, attended, late, held];
}

/// Attendance of every student in a course (for teachers and the Chairman).
class CourseAttendanceReport extends Equatable {
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final List<String> classDates;
  final List<StudentAttendanceRow> rows;

  const CourseAttendanceReport({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.classDates,
    required this.rows,
  });

  List<StudentAttendanceRow> get below75 => rows.where((r) => r.isBelow75).toList();

  /// Spreadsheet-friendly text (paste into Excel / Google Sheets).
  String toCsv() {
    String q(String v) => v.contains(',') || v.contains('"') ? '"${v.replaceAll('"', '""')}"' : v;
    final b = StringBuffer('Roll,Name,Attended,Late,Classes held,Percentage\n');
    for (final r in rows) {
      b.writeln([q(r.studentRoll), q(r.studentName), r.attended, r.late, r.held, r.percentage.toStringAsFixed(1)].join(','));
    }
    return b.toString();
  }

  @override
  List<Object?> get props => [courseId, courseCode, courseTitle, classDates, rows];
}
