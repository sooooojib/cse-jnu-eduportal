import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/config/env_config.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
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
    if (EnvConfig.isCloudFunctionsEnabled) {
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
        if (e.code == 'failed-precondition' || e.code == 'deadline-exceeded' || e.code == 'already-exists') {
          throw ServerException(message: e.message ?? "Failed to verify attendance code.");
        }
        AppLogger.w('submitAttendanceCode Cloud Function note ($e). Falling back to Firestore transaction.');
      } catch (e) {
        AppLogger.w('submitAttendanceCode error ($e). Falling back to Firestore transaction.');
      }
    }

    // 1. Query for the active session matching the code outside transaction
    // (Firestore transactions prohibit collection queries and require document references)
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
    final sessionRef = sessionDoc.reference;

    // 2. Authoritative Firestore Transaction with Document-Level Mutual Exclusion
    return await _firestore.runTransaction((transaction) async {
      final freshSession = await transaction.get(sessionRef);
      if (!freshSession.exists) {
        throw const ServerException(message: "Attendance session not found.");
      }
      final sessionData = freshSession.data() ?? {};
      if (sessionData["isActive"] != true) {
        throw const ServerException(message: "This attendance session is no longer active.");
      }

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
      final docId = "${sessionDoc.id}_$uid";
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
        "sessionId": sessionDoc.id,
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
      transaction.update(sessionRef, {
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
    if (EnvConfig.isCloudFunctionsEnabled) {
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
      } catch (e) {
        AppLogger.w('startAttendanceSession Cloud Function note ($e). Falling back to direct Firestore creation.');
      }
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
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('deactivateAttendanceSession');
        await callable.call({'sessionId': sessionId});
        return;
      } catch (e) {
        AppLogger.w('deactivateAttendanceSession Cloud Function note ($e). Falling back to direct Firestore update.');
      }
    }

    try {
      await _firestore.collection("attendanceSessions").doc(sessionId).update({
        "isActive": false,
        "status": "COMPLETED",
        "closedAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException(message: "Failed to deactivate attendance session: ${e.toString().replaceAll('Exception: ', '')}");
    }
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
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('getAttendanceSessionRoster');
        final result = await callable.call({'sessionId': sessionId});
        final data = result.data;
        if (data is Map && data['success'] == true) {
          return SessionRosterModel.fromJson(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        AppLogger.w('getAttendanceSessionRoster Cloud Function note ($e). Falling back to direct Firestore query.');
      }
    }

    final sessionDoc = await _firestore.collection("attendanceSessions").doc(sessionId).get();
    if (!sessionDoc.exists) throw const ServerException(message: "Session not found.");
    final sData = sessionDoc.data()!;

    final dynamic rawYear = sData["targetYear"];
    final dynamic rawSem = sData["targetSemester"];
    final int? yearInt = rawYear is int ? rawYear : int.tryParse(rawYear?.toString() ?? '');
    final int? semInt = rawSem is int ? rawSem : int.tryParse(rawSem?.toString() ?? '');
    final String courseId = sData["courseId"] as String? ?? "";

    final Map<String, Map<String, dynamic>> studentMap = {};

    void addStudent(String id, Map<String, dynamic> data) {
      final role = (data["role"] as String? ?? "").toUpperCase();
      if (role == "STUDENT" || role == "CR" || role.isEmpty) {
        studentMap[id] = data;
      }
    }

    // A. Query students by cohort (supporting int and String types)
    if (yearInt != null && semInt != null) {
      try {
        final snapInt = await _firestore.collection("users")
            .where("role", whereIn: ["STUDENT", "CR", "student", "cr"])
            .where("year", isEqualTo: yearInt)
            .where("semester", isEqualTo: semInt)
            .get();
        for (final doc in snapInt.docs) {
          addStudent(doc.id, doc.data());
        }
      } catch (e) {
        AppLogger.w('Cohort query with int error: $e');
      }

      if (studentMap.isEmpty) {
        try {
          final snapStr = await _firestore.collection("users")
              .where("role", whereIn: ["STUDENT", "CR", "student", "cr"])
              .where("year", isEqualTo: yearInt.toString())
              .where("semester", isEqualTo: semInt.toString())
              .get();
          for (final doc in snapStr.docs) {
            addStudent(doc.id, doc.data());
          }
        } catch (e) {
          AppLogger.w('Cohort query with string error: $e');
        }
      }
    }

    // B. Explicit enrollments for courseId
    if (courseId.isNotEmpty) {
      try {
        final enrollSnap = await _firestore.collection("enrollments")
            .where("courseId", isEqualTo: courseId)
            .get();
        for (final doc in enrollSnap.docs) {
          final sId = doc.data()["studentId"] as String?;
          if (sId != null && !studentMap.containsKey(sId)) {
            final sDoc = await _firestore.collection("users").doc(sId).get();
            if (sDoc.exists && sDoc.data() != null) {
              addStudent(sDoc.id, sDoc.data()!);
            }
          }
        }
      } catch (e) {
        AppLogger.w('Enrollments query error: $e');
      }
    }

    // C. Recorded attendance documents for this session
    final recordsSnap = await _firestore.collection("attendance")
        .where("sessionId", isEqualTo: sessionId)
        .get();

    final recordMap = {for (final doc in recordsSnap.docs) doc.data()["studentId"]: doc.data()};

    for (final recDoc in recordsSnap.docs) {
      final rec = recDoc.data();
      final sId = rec["studentId"] as String?;
      if (sId != null && !studentMap.containsKey(sId)) {
        final sDoc = await _firestore.collection("users").doc(sId).get();
        if (sDoc.exists && sDoc.data() != null) {
          addStudent(sDoc.id, sDoc.data()!);
        } else {
          studentMap[sId] = {
            "fullName": rec["studentName"] ?? "Student",
            "studentId": rec["studentRoll"] ?? "N/A",
            "role": "STUDENT",
          };
        }
      }
    }

    // D. If still empty, load candidate students across the users collection
    if (studentMap.isEmpty) {
      try {
        final allSnap = await _firestore.collection("users")
            .where("role", whereIn: ["STUDENT", "CR", "student", "cr"])
            .limit(100)
            .get();
        for (final doc in allSnap.docs) {
          final d = doc.data();
          final uYear = d["year"]?.toString();
          final uSem = d["semester"]?.toString();
          if (yearInt == null ||
              (uYear == yearInt.toString() && uSem == semInt?.toString()) ||
              uYear == null) {
            addStudent(doc.id, d);
          }
        }
      } catch (e) {
        AppLogger.w('Candidate students fallback error: $e');
      }
    }

    final roster = studentMap.entries.map((entry) {
      final sId = entry.key;
      final s = entry.value;
      final rec = recordMap[sId];
      return AttendanceRosterItemModel(
        studentId: sId,
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
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('updateAttendanceRoster');
        await callable.call({
          'sessionId': sessionId,
          'updates': updates.map((u) => {'studentId': u.studentId, 'status': u.status}).toList(),
        });
        return;
      } catch (e) {
        AppLogger.w('updateAttendanceRoster Cloud Function note ($e). Falling back to direct Firestore batch update.');
      }
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

    try {
      final presentSnap = await _firestore.collection("attendance")
          .where("sessionId", isEqualTo: sessionId)
          .where("status", isEqualTo: "PRESENT")
          .get();

      await _firestore.collection("attendanceSessions").doc(sessionId).update({
        "totalPresentCount": presentSnap.size,
        "updatedAt": now,
      });
    } catch (e) {
      AppLogger.w('Failed to update totalPresentCount on session ($e)');
    }
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
