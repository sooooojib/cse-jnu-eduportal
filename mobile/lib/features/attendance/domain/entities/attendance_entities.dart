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
      ];
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
  final String courseCode;
  final String courseTitle;
  final String status;
  final String verifiedAt;
  final String? studentId;
  final String? studentName;
  final String? studentRoll;
  final bool isManualOverride;

  const AttendanceRecord({
    required this.id,
    required this.courseCode,
    required this.courseTitle,
    required this.status,
    required this.verifiedAt,
    this.studentId,
    this.studentName,
    this.studentRoll,
    this.isManualOverride = false,
  });

  @override
  List<Object?> get props => [id, courseCode, courseTitle, status, verifiedAt, studentId, studentName, studentRoll, isManualOverride];
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
