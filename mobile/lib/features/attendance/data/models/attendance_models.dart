import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/attendance_entities.dart';

String _tsToString(dynamic value) {
  if (value == null) return DateTime.now().toIso8601String();
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value.toString();
}

class AttendanceSessionModel extends AttendanceSession {
  const AttendanceSessionModel({
    required super.id,
    required super.courseId,
    required super.courseCode,
    required super.courseTitle,
    required super.teacherId,
    required super.teacherName,
    required super.code,
    required super.isActive,
    required super.status,
    required super.sessionDate,
    super.totalPresentCount = 0,
    required super.createdAt,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    return AttendanceSessionModel(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      courseCode: json['courseCode'] as String? ?? '',
      courseTitle: json['courseTitle'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      code: json['code'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      status: json['status'] as String? ?? 'ACTIVE',
      sessionDate: json['sessionDate'] as String? ?? json['date'] as String? ?? '',
      totalPresentCount: json['totalPresentCount'] as int? ?? 0,
      createdAt: _tsToString(json['createdAt']),
    );
  }

  factory AttendanceSessionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AttendanceSessionModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'code': code,
      'isActive': isActive,
      'status': status,
      'sessionDate': sessionDate,
      'totalPresentCount': totalPresentCount,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'courseId': courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'code': code,
      'isActive': isActive,
      'status': status,
      'sessionDate': sessionDate,
      'totalPresentCount': totalPresentCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class CourseAttendanceModel extends CourseAttendance {
  const CourseAttendanceModel({
    required super.courseId,
    required super.courseCode,
    required super.courseTitle,
    required super.attendedClasses,
    required super.totalClasses,
    required super.percentage,
    required super.isEligible,
  });

  factory CourseAttendanceModel.fromJson(Map<String, dynamic> json) {
    return CourseAttendanceModel(
      courseId: json['courseId'] as String? ?? '',
      courseCode: json['courseCode'] as String? ?? '',
      courseTitle: json['courseTitle'] as String? ?? '',
      attendedClasses: json['attendedClasses'] as int? ?? 0,
      totalClasses: json['totalClasses'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      isEligible: json['isEligible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'attendedClasses': attendedClasses,
      'totalClasses': totalClasses,
      'percentage': percentage,
      'isEligible': isEligible,
    };
  }
}

class AttendanceRecordModel extends AttendanceRecord {
  const AttendanceRecordModel({
    required super.id,
    required super.courseCode,
    required super.courseTitle,
    required super.status,
    required super.verifiedAt,
    super.studentId,
    super.studentName,
    super.studentRoll,
    super.isManualOverride = false,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] as String? ?? '',
      courseCode: json['courseCode'] as String? ?? '',
      courseTitle: json['courseTitle'] as String? ?? '',
      status: json['status'] as String? ?? 'PRESENT',
      verifiedAt: _tsToString(json['verifiedAt'] ?? json['date']),
      studentId: json['studentId'] as String?,
      studentName: json['studentName'] as String?,
      studentRoll: json['studentRoll'] as String?,
      isManualOverride: json['isManualOverride'] as bool? ?? false,
    );
  }

  factory AttendanceRecordModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AttendanceRecordModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'status': status,
      'verifiedAt': verifiedAt,
      if (studentId != null) 'studentId': studentId,
      if (studentName != null) 'studentName': studentName,
      if (studentRoll != null) 'studentRoll': studentRoll,
      'isManualOverride': isManualOverride,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'status': status,
      'verifiedAt': FieldValue.serverTimestamp(),
      if (studentId != null) 'studentId': studentId,
      if (studentName != null) 'studentName': studentName,
      if (studentRoll != null) 'studentRoll': studentRoll,
      'isManualOverride': isManualOverride,
    };
  }
}

class AttendanceSummaryModel extends AttendanceSummary {
  const AttendanceSummaryModel({
    required super.overallPercentage,
    required super.totalAttended,
    required super.totalSessions,
    required super.courseSummaries,
    required super.recentRecords,
  });

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) {
    final summaries = (json['courseSummaries'] as List? ?? [])
        .map((e) => CourseAttendanceModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final records = (json['recentRecords'] as List? ?? [])
        .map((e) => AttendanceRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return AttendanceSummaryModel(
      overallPercentage: (json['overallPercentage'] as num?)?.toDouble() ?? 0.0,
      totalAttended: json['totalAttended'] as int? ?? 0,
      totalSessions: json['totalSessions'] as int? ?? 0,
      courseSummaries: List<CourseAttendance>.from(summaries),
      recentRecords: List<AttendanceRecord>.from(records),
    );
  }
}
