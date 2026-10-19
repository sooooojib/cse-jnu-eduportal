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
  });

  @override
  List<Object?> get props => [
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
  final String status; // 'PRESENT' | 'ABSENT'
  final bool isManualOverride;
  final String? verifiedAt;

  const AttendanceRosterItem({
    required this.studentId,
    required this.studentRoll,
    required this.studentName,
    required this.status,
    this.isManualOverride = false,
    this.verifiedAt,
  });

  bool get isPresent => status == 'PRESENT';

  AttendanceRosterItem copyWith({
    String? status,
    bool? isManualOverride,
    String? verifiedAt,
  }) {
    return AttendanceRosterItem(
      studentId: studentId,
      studentRoll: studentRoll,
      studentName: studentName,
      status: status ?? this.status,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      verifiedAt: verifiedAt ?? this.verifiedAt,
    );
  }

  @override
  List<Object?> get props => [studentId, studentRoll, studentName, status, isManualOverride, verifiedAt];
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

  const CourseAttendance({
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.attendedClasses,
    required this.totalClasses,
    required this.percentage,
    required this.isEligible,
  });

  @override
  List<Object?> get props => [courseId, courseCode, courseTitle, attendedClasses, totalClasses, percentage, isEligible];
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

  const AttendanceSummary({
    required this.overallPercentage,
    required this.totalAttended,
    required this.totalSessions,
    required this.courseSummaries,
    required this.recentRecords,
  });

  @override
  List<Object?> get props => [overallPercentage, totalAttended, totalSessions, courseSummaries, recentRecords];
}

