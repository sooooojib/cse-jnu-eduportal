import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../models/attendance_models.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class AttendanceRemoteDataSource {
  Future<AttendanceSummaryModel> getMySummary();
  Future<AttendanceVerificationResult> verifyCode(String code, {String? courseId});
  Future<AttendanceSessionModel> startSession({required String courseId, int? durationMinutes});
  Future<void> deactivateSession({required String sessionId});
  Future<AttendanceSessionModel?> getActiveSession({required String courseId});
  Future<SessionRosterModel> getSessionRoster({required String sessionId});
  Future<void> updateRoster({required String sessionId, required List<AttendanceRosterItem> updates});
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  AttendanceRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<AttendanceSummaryModel> getMySummary() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final snapshot = await _firestore
        .collection("attendance")
        .where("studentId", isEqualTo: uid)
        .orderBy("date", descending: true)
        .get();

    final records = snapshot.docs.map((doc) {
      final data = {"id": doc.id, ...doc.data()};
      return AttendanceRecordModel.fromJson(data);
    }).toList();

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
      recentRecords: records.take(15).toList(),
    );
  }

  @override
  Future<AttendanceVerificationResult> verifyCode(String code, {String? courseId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length != 6) {
      throw const ServerException(message: "Verification code must be exactly 6 characters.");
    }

    // Attempt Server-Side Cloud Function first for authoritative execution
    try {
      final callable = _functions.httpsCallable('submitAttendanceCode');
      final result = await callable.call({
        'code': cleanCode,
        if (courseId != null) 'courseId': courseId,
      });

      final data = result.data;
      if (data is Map && data['success'] == true) {
        return AttendanceVerificationResult(
          success: true,
          message: data['message'] as String? ?? "Attendance verified successfully.",
          courseCode: data['courseCode'] as String?,
          courseTitle: data['courseTitle'] as String?,
          recordId: data['recordId'] as String?,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(message: e.message ?? "Failed to verify attendance code.");
    } catch (_) {
      // Fall through to atomic client-side transaction fallback if cloud functions unreachable
    }

    // Authoritative Firestore Transaction Fallback with Mutual Exclusion
    return await _firestore.runTransaction((transaction) async {
      final sessionSnap = await _firestore
          .collection("attendanceSessions")
          .where("code", isEqualTo: cleanCode)
          .where("isActive", isEqualTo: true)
          .limit(1)
          .get();

      if (sessionSnap.docs.isEmpty) {
        throw const ServerException(message: "Invalid or expired attendance code.");
      }

      final sessionDoc = sessionSnap.docs.first;
      final sessionData = sessionDoc.data();
      final sessionId = sessionDoc.id;

      // Check Expiration
      final expiresAt = sessionData['expiresAt'];
      if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
        throw const ServerException(message: "This attendance session has expired.");
      }

      final sessionCourseId = sessionData["courseId"] as String? ?? "";
      if (courseId != null && courseId != sessionCourseId) {
        throw const ServerException(message: "Code does not match the selected course.");
      }

      // Check Duplicate Attendance via Composite Document ID
      final docId = "${sessionId}_$uid";
      final recordRef = _firestore.collection("attendance").doc(docId);
      final existingRecord = await transaction.get(recordRef);
      if (existingRecord.exists) {
        throw const ServerException(message: "You have already attended this session.");
      }

      // Fetch user profile for denormalized roll and name
      final userDoc = await transaction.get(_firestore.collection("users").doc(uid));
      final userData = userDoc.data() ?? {};
      final studentName = userData["fullName"] as String? ?? "";
      final studentRoll = userData["studentId"] as String? ?? "";

      // Write Present Record
      transaction.set(recordRef, {
        "id": docId,
        "sessionId": sessionId,
        "studentId": uid,
        "studentName": studentName,
        "studentRoll": studentRoll,
        "courseId": sessionCourseId,
        "courseCode": sessionData["courseCode"] ?? "",
        "courseTitle": sessionData["courseTitle"] ?? "",
        "status": "PRESENT",
        "isManualOverride": false,
        "date": sessionData["sessionDate"] ?? sessionData["date"] ?? DateTime.now().toIso8601String().substring(0, 10),
        "verifiedAt": FieldValue.serverTimestamp(),
      });

      // Increment total count atomically
      transaction.update(sessionDoc.reference, {
        "totalPresentCount": FieldValue.increment(1),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      return AttendanceVerificationResult(
        success: true,
        message: "Attendance marked successfully.",
        courseCode: sessionData["courseCode"] as String?,
        courseTitle: sessionData["courseTitle"] as String?,
        recordId: docId,
      );
    });
  }

  @override
  Future<AttendanceSessionModel> startSession({required String courseId, int? durationMinutes}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final duration = durationMinutes ?? 15;

    // 1. Authoritative Cloud Function
    try {
      final callable = _functions.httpsCallable('startAttendanceSession');
      final result = await callable.call({
        'courseId': courseId,
        'durationMinutes': duration,
      });

      final data = result.data;
      if (data is Map && data['success'] == true && data['session'] is Map) {
        return AttendanceSessionModel.fromJson(Map<String, dynamic>.from(data['session'] as Map));
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented' || e.code == 'unavailable') {
        // Fallback to Firestore
      } else {
        throw ServerException(message: e.message ?? "Failed to start attendance session.");
      }
    } catch (_) {
      // Fallback
    }

    // 2. Transactional Firestore Fallback
    final courseDoc = await _firestore.collection("courses").doc(courseId).get();
    if (!courseDoc.exists) throw const ServerException(message: "Course not found.");
    final courseData = courseDoc.data()!;

    // Deactivate previous active sessions for this course
    final oldSessions = await _firestore.collection("attendanceSessions")
        .where("courseId", isEqualTo: courseId)
        .where("teacherId", isEqualTo: uid)
        .where("isActive", isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in oldSessions.docs) {
      batch.update(doc.reference, {
        "isActive": false,
        "status": "COMPLETED",
        "closedAt": FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Generate safe 6-character code
    const chars = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
    final rand = Random.secure();
    final code = List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();

    final sessionRef = _firestore.collection("attendanceSessions").doc();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(minutes: duration));

    final sessionMap = {
      "id": sessionRef.id,
      "courseId": courseId,
      "courseCode": courseData["code"] ?? courseId,
      "courseTitle": courseData["title"] ?? "",
      "teacherId": uid,
      "teacherName": courseData["teacherName"] ?? "Professor",
      "code": code,
      "isActive": true,
      "status": "ACTIVE",
      "sessionDate": now.toIso8601String().substring(0, 10),
      "startTime": FieldValue.serverTimestamp(),
      "expiresAt": Timestamp.fromDate(expiresAt),
      "targetYear": courseData["year"] ?? 1,
      "targetSemester": courseData["semester"] ?? 1,
      "totalPresentCount": 0,
      "createdAt": FieldValue.serverTimestamp(),
    };

    await sessionRef.set(sessionMap);
    return AttendanceSessionModel.fromJson(sessionMap);
  }

  @override
  Future<void> deactivateSession({required String sessionId}) async {
    try {
      final callable = _functions.httpsCallable('deactivateAttendanceSession');
      await callable.call({'sessionId': sessionId});
      return;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented' || e.code == 'unavailable') {
        // Fallback to Firestore
      } else {
        throw ServerException(message: e.message ?? "Failed to deactivate attendance session.");
      }
    } catch (_) {
      // Fallback
    }

    await _firestore.collection("attendanceSessions").doc(sessionId).update({
      "isActive": false,
      "status": "COMPLETED",
      "closedAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<AttendanceSessionModel?> getActiveSession({required String courseId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final query = await _firestore.collection("attendanceSessions")
        .where("courseId", isEqualTo: courseId)
        .where("isActive", isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return AttendanceSessionModel.fromFirestore(query.docs.first);
  }

  @override
  Future<SessionRosterModel> getSessionRoster({required String sessionId}) async {
    try {
      final callable = _functions.httpsCallable('getAttendanceSessionRoster');
      final result = await callable.call({'sessionId': sessionId});
      final data = result.data;
      if (data is Map && data['success'] == true) {
        return SessionRosterModel.fromJson(Map<String, dynamic>.from(data));
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented' || e.code == 'unavailable') {
        // Fallback to Firestore
      } else {
        throw ServerException(message: e.message ?? "Failed to load session roster.");
      }
    } catch (_) {
      // Fallback
    }

    final sessionDoc = await _firestore.collection("attendanceSessions").doc(sessionId).get();
    if (!sessionDoc.exists) throw const ServerException(message: "Session not found.");
    final sData = sessionDoc.data()!;

    final studentsSnap = await _firestore.collection("users")
        .where("role", whereIn: ["STUDENT", "CR"])
        .where("year", isEqualTo: sData["targetYear"])
        .where("semester", isEqualTo: sData["targetSemester"])
        .get();

    final recordsSnap = await _firestore.collection("attendance")
        .where("sessionId", isEqualTo: sessionId)
        .get();

    final recordMap = {for (final doc in recordsSnap.docs) doc.data()["studentId"]: doc.data()};

    final roster = studentsSnap.docs.map((doc) {
      final s = doc.data();
      final rec = recordMap[doc.id];
      return AttendanceRosterItemModel(
        studentId: doc.id,
        studentRoll: s["studentId"] as String? ?? "N/A",
        studentName: s["fullName"] as String? ?? "Student",
        status: rec != null ? (rec["status"] as String? ?? "ABSENT") : "ABSENT",
        isManualOverride: rec != null ? (rec["isManualOverride"] as bool? ?? false) : false,
      );
    }).toList();

    roster.sort((a, b) => a.studentRoll.compareTo(b.studentRoll));
    final presentCount = roster.where((r) => r.status == "PRESENT").length;

    return SessionRosterModel(
      sessionId: sessionId,
      courseCode: sData["courseCode"] ?? "",
      courseTitle: sData["courseTitle"] ?? "",
      sessionDate: sData["sessionDate"] ?? "",
      code: sData["code"],
      isActive: sData["isActive"] ?? false,
      totalEnrolled: roster.length,
      totalPresent: presentCount,
      roster: roster,
    );
  }

  @override
  Future<void> updateRoster({required String sessionId, required List<AttendanceRosterItem> updates}) async {
    try {
      final callable = _functions.httpsCallable('updateAttendanceRoster');
      await callable.call({
        'sessionId': sessionId,
        'updates': updates.map((u) => {'studentId': u.studentId, 'status': u.status}).toList(),
      });
      return;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented' || e.code == 'unavailable') {
        // Fallback to Firestore
      } else {
        throw ServerException(message: e.message ?? "Failed to update attendance roster.");
      }
    } catch (_) {
      // Fallback
    }

    final sessionDoc = await _firestore.collection("attendanceSessions").doc(sessionId).get();
    if (!sessionDoc.exists) throw const ServerException(message: "Session not found.");
    final sData = sessionDoc.data()!;

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final item in updates) {
      final recordId = "${sessionId}_${item.studentId}";
      final recordRef = _firestore.collection("attendance").doc(recordId);

      batch.set(recordRef, {
        "id": recordId,
        "sessionId": sessionId,
        "studentId": item.studentId,
        "studentName": item.studentName,
        "studentRoll": item.studentRoll,
        "courseId": sData["courseId"],
        "courseCode": sData["courseCode"],
        "courseTitle": sData["courseTitle"],
        "status": item.status,
        "isManualOverride": true,
        "date": sData["sessionDate"] ?? DateTime.now().toIso8601String().substring(0, 10),
        "verifiedAt": item.status == "PRESENT" ? now : null,
        "updatedAt": now,
      }, SetOptions(merge: true));
    }

    await batch.commit();

    final presentSnap = await _firestore.collection("attendance")
        .where("sessionId", isEqualTo: sessionId)
        .where("status", isEqualTo: "PRESENT")
        .get();

    await _firestore.collection("attendanceSessions").doc(sessionId).update({
      "totalPresentCount": presentSnap.size,
      "updatedAt": now,
    });
  }
}

// ─── Repository Implementation ───────────────────────────────────────────────

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
  Future<AttendanceVerificationResult> verifyCode(String code, {String? courseId}) async {
    try {
      return await remoteDataSource.verifyCode(code, courseId: courseId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<AttendanceSession> startSession({required String courseId, int? durationMinutes}) async {
    try {
      return await remoteDataSource.startSession(courseId: courseId, durationMinutes: durationMinutes);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> deactivateSession({required String sessionId}) async {
    try {
      return await remoteDataSource.deactivateSession(sessionId: sessionId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<AttendanceSession?> getActiveSession({required String courseId}) async {
    try {
      return await remoteDataSource.getActiveSession(courseId: courseId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<SessionRoster> getSessionRoster({required String sessionId}) async {
    try {
      return await remoteDataSource.getSessionRoster(sessionId: sessionId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> updateRoster({required String sessionId, required List<AttendanceRosterItem> updates}) async {
    try {
      return await remoteDataSource.updateRoster(sessionId: sessionId, updates: updates);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
