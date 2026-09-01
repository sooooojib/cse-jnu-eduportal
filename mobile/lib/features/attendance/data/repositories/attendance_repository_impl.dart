import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../models/attendance_models.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class AttendanceRemoteDataSource {
  Future<AttendanceSummaryModel> getMySummary();
  Future<Map<String, dynamic>> verifyCode(String code, {String? courseId});
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  AttendanceRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  @override
  Future<AttendanceSummaryModel> getMySummary() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    // Fetch all attendance records for this student
    final snapshot = await _firestore
        .collection("attendance")
        .where("studentId", isEqualTo: uid)
        .orderBy("date", descending: true)
        .get();

    final records = snapshot.docs.map((doc) {
      final data = {"id": doc.id, ...doc.data()};
      return AttendanceRecordModel.fromJson(data);
    }).toList();

    // Aggregate by courseCode
    final Map<String, List<AttendanceRecordModel>> byCourse = {};
    for (final r in records) {
      byCourse.putIfAbsent(r.courseCode, () => []).add(r);
    }

    final courseSummaries = byCourse.entries.map((entry) {
      final total = entry.value.length;
      final attended = entry.value.where((r) => r.status == "PRESENT").length;
      final pct = total > 0 ? (attended / total) * 100 : 0.0;
      return CourseAttendanceModel(
        courseId: entry.key,
        courseCode: entry.key,
        courseTitle: entry.value.first.courseTitle,
        attendedClasses: attended,
        totalClasses: total,
        percentage: pct,
        isEligible: pct >= 75,
      );
    }).toList();

    final totalAttended = records.where((r) => r.status == "PRESENT").length;
    final totalSessions = records.length;
    final overallPct = totalSessions > 0
        ? (totalAttended / totalSessions) * 100
        : 0.0;

    return AttendanceSummaryModel(
      overallPercentage: overallPct,
      totalAttended: totalAttended,
      totalSessions: totalSessions,
      courseSummaries: courseSummaries,
      recentRecords: records.take(10).toList(),
    );
  }

  @override
  Future<Map<String, dynamic>> verifyCode(String code, {String? courseId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    // Look up an active attendance session by its code
    final sessionSnap = await _firestore
        .collection("attendanceSessions")
        .where("code", isEqualTo: code)
        .where("isActive", isEqualTo: true)
        .limit(1)
        .get();

    if (sessionSnap.docs.isEmpty) {
      throw const ServerException(message: "Invalid or expired attendance code.");
    }

    final session = sessionSnap.docs.first;
    final sessionData = session.data();
    final sessionCourseId = sessionData["courseId"] as String? ?? "";

    if (courseId != null && courseId != sessionCourseId) {
      throw const ServerException(message: "Code does not match the selected course.");
    }

    // Mark student as present
    final recordRef = _firestore.collection("attendance").doc();
    await recordRef.set({
      "studentId": uid,
      "sessionId": session.id,
      "courseId": sessionCourseId,
      "courseCode": sessionData["courseCode"] ?? "",
      "courseTitle": sessionData["courseTitle"] ?? "",
      "status": "PRESENT",
      "date": sessionData["date"] ?? DateTime.now().toIso8601String(),
      "verifiedAt": FieldValue.serverTimestamp(),
    });

    return {
      "success": true,
      "message": "Attendance marked successfully.",
      "courseCode": sessionData["courseCode"],
    };
  }
}

// ─── Repository ──────────────────────────────────────────────────────────────

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceRemoteDataSource remoteDataSource;

  AttendanceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AttendanceSummary> getMySummary() async {
    try {
      return await remoteDataSource.getMySummary();
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<Map<String, dynamic>> verifyCode(String code, {String? courseId}) async {
    try {
      return await remoteDataSource.verifyCode(code, courseId: courseId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
