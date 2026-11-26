import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/config/env_config.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/authoritative_guard.dart';
import '../../../../core/network/safe_retry_policy.dart';
import '../models/attendance_models.dart';
import '../services/class_attendance_service.dart';
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
  final AuthoritativeGuard? _authoritativeGuard;

  /// Direct-database logic (rotating codes, late, auto-absent, who marked).
  final ClassAttendanceService _service;

  AttendanceRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    FirebaseFunctions? functions,
    AuthoritativeGuard? authoritativeGuard,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _service = ClassAttendanceServiceImpl(firestore: firestore, auth: auth),
        _functions = functions ?? FirebaseFunctions.instance,
        _authoritativeGuard = authoritativeGuard ?? (sl.isRegistered<AuthoritativeGuard>() ? sl<AuthoritativeGuard>() : null);

  @override
  Future<AttendanceSummaryModel> getMySummary() async {
    // Attended ÷ held, where held = class days of the student's semester.
    return await _service.mySummary() as AttendanceSummaryModel;
  }

  @override
  Future<AttendanceVerificationResult> verifyCode(String code, {String? courseId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length != 6) {
      throw const ServerException(message: "Verification code must be exactly 6 characters.");
    }

    // Authoritative Server Validation: Never allow offline attendance verification
    if (_authoritativeGuard != null) {
      await _authoritativeGuard.ensureAuthoritativeServer(
        operationName: "Attendance verification",
      );
    }

    return await SafeRetryPolicy.execute<AttendanceVerificationResult>(
      idempotencyKey: 'verify_code_${uid}_$cleanCode',
      operationName: 'Attendance verification',
      action: () async {
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

        // Direct path: rotating code checked by the security rules.
        return await _service.markWithCode(cleanCode, courseId: courseId);
      },
    );
  }

  @override
  Future<AttendanceSessionModel> startSession({required String courseId, int? durationMinutes}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    if (_authoritativeGuard != null) {
      await _authoritativeGuard.ensureAuthoritativeServer(
        operationName: "Creating attendance session",
      );
    }

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

    // Direct path: code kept private to the teacher, rotating.
    return await _service.startClassSession(courseId: courseId, durationMinutes: duration) as AttendanceSessionModel;
  }

  @override
  Future<void> deactivateSession({required String sessionId}) async {
    if (_authoritativeGuard != null) {
      await _authoritativeGuard.ensureAuthoritativeServer(
        operationName: "Closing attendance session",
      );
    }

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

    // Only this semester's students and those enrolled (no guessing from other semesters).

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
        // Who set it: SELF (entered the code) or TEACHER; null = no record yet.
        markedBy: rec == null
            ? null
            : (rec["markedBy"] as String? ?? ((rec["isManualOverride"] as bool? ?? false) ? "TEACHER" : "SELF")),
      );
    }).toList();

    roster.sort((a, b) => a.studentRoll.compareTo(b.studentRoll));
    final presentCount = roster.where((r) => r.isPresent).length;

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
    if (_authoritativeGuard != null) {
      await _authoritativeGuard.ensureAuthoritativeServer(
        operationName: "Updating attendance roster",
      );
    }

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

    await _service.saveMarks(sessionId: sessionId, items: updates);
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
