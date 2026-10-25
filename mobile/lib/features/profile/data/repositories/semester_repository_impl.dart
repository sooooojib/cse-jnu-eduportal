import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/config/env_config.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/semester_upgrade_request_model.dart';
import '../../domain/entities/semester_status.dart';
import '../../domain/repositories/semester_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class SemesterRemoteDataSource {
  Future<SemesterStatusModel> getStatus();
  Future<SemesterStatusModel> requestUpgrade({required int requestedYear, required int requestedSemester});
  Future<SemesterStatusModel> changeUpgradeRequest({
    required String requestId,
    required int requestedYear,
    required int requestedSemester,
  });
  Future<void> dismissRejection({required String requestId});
  Future<List<SemesterUpgradeRequestModel>> getMyUpgradeRequests();
}

class SemesterRemoteDataSourceImpl implements SemesterRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  SemesterRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<SemesterStatusModel> getStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final userDoc = await _firestore.collection("users").doc(uid).get();
    if (!userDoc.exists) throw const ServerException(message: "User profile not found.");

    final userData = userDoc.data()!;
    final currentYear = userData["year"] as int?;
    final currentSemester = userData["semester"] as int?;

    // Check for any pending/recent upgrade request
    final upgradeSnap = await _firestore
        .collection("semesterUpgradeRequests")
        .where("studentId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .limit(10)
        .get();

    if (upgradeSnap.docs.isEmpty) {
      return SemesterStatusModel(
        currentYear: currentYear,
        currentSemester: currentSemester,
        status: (currentYear == null || currentSemester == null) ? "NO_ENROLLMENT" : "APPROVED",
      );
    }

    // Find the most recent non-dismissed request
    final nonDismissed = upgradeSnap.docs.where((doc) {
      final data = doc.data();
      return data["status"] != "DISMISSED" && data["isDismissed"] != true;
    }).toList();

    if (nonDismissed.isEmpty) {
      return SemesterStatusModel(
        currentYear: currentYear,
        currentSemester: currentSemester,
        status: (currentYear == null || currentSemester == null) ? "NO_ENROLLMENT" : "APPROVED",
      );
    }

    final latestDoc = nonDismissed.first;
    final req = latestDoc.data();

    return SemesterStatusModel.fromJson({
      "requestId": latestDoc.id,
      "id": latestDoc.id,
      "currentYear": currentYear,
      "currentSemester": currentSemester,
      ...req,
    });
  }

  @override
  Future<SemesterStatusModel> requestUpgrade({
    required int requestedYear,
    required int requestedSemester,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    // 1. Try Cloud Function
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('requestSemesterUpgrade');
        final res = await callable.call({
          'requestedYear': requestedYear,
          'requestedSemester': requestedSemester,
        });

        final data = res.data;
        if (data is Map) {
          return SemesterStatusModel.fromJson(Map<String, dynamic>.from(data));
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'already-exists' || e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? 'Failed to submit semester upgrade request.');
        }
        AppLogger.w('requestSemesterUpgrade callable note: $e. Falling back to direct Firestore creation.');
      } catch (e) {
        AppLogger.w('requestSemesterUpgrade error: $e. Falling back to direct Firestore creation.');
      }
    }

    // 2. Direct Firestore fallback
    final userDoc = await _firestore.collection("users").doc(uid).get();
    final userData = userDoc.data() ?? {};

    final currentYear = userData["year"] as int?;
    final currentSemester = userData["semester"] as int?;
    final studentName = userData["fullName"] as String? ?? "";
    final studentRoll = userData["studentId"] as String? ?? "";

    // Check duplicate pending request
    final dupSnap = await _firestore
        .collection("semesterUpgradeRequests")
        .where("studentId", isEqualTo: uid)
        .where("status", isEqualTo: "PENDING")
        .get();

    if (dupSnap.docs.isNotEmpty) {
      throw const ServerException(
        message: "You already have a pending enrollment/semester request. Please wait for administrator review or change your existing request.",
      );
    }

    final docRef = await _firestore.collection("semesterUpgradeRequests").add({
      "studentId": uid,
      "studentName": studentName,
      "studentRoll": studentRoll,
      "currentYear": currentYear ?? 1,
      "currentSemester": currentSemester ?? 1,
      "requestedYear": requestedYear,
      "requestedSemester": requestedSemester,
      "status": "PENDING",
      "rejectionReason": null,
      "isDismissed": false,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    return SemesterStatusModel(
      requestId: docRef.id,
      currentYear: currentYear,
      currentSemester: currentSemester,
      requestedYear: requestedYear,
      requestedSemester: requestedSemester,
      status: "PENDING",
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<SemesterStatusModel> changeUpgradeRequest({
    required String requestId,
    required int requestedYear,
    required int requestedSemester,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    // 1. Try Cloud Function
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('changeSemesterUpgradeRequest');
        final res = await callable.call({
          'requestId': requestId,
          'requestedYear': requestedYear,
          'requestedSemester': requestedSemester,
        });

        final data = res.data;
        if (data is Map) {
          return SemesterStatusModel.fromJson(Map<String, dynamic>.from(data));
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? 'Failed to update semester request.');
        }
        AppLogger.w('changeSemesterUpgradeRequest callable note: $e. Falling back to direct Firestore update.');
      } catch (e) {
        AppLogger.w('changeSemesterUpgradeRequest error: $e. Falling back to direct Firestore update.');
      }
    }

    // 2. Direct Firestore fallback
    final reqRef = _firestore.collection("semesterUpgradeRequests").doc(requestId);
    final reqDoc = await reqRef.get();
    if (!reqDoc.exists) throw const ServerException(message: "Semester request not found.");

    final reqData = reqDoc.data()!;
    if (reqData["status"] != "PENDING") {
      throw const ServerException(message: "Only pending requests can be modified.");
    }

    await reqRef.update({
      "requestedYear": requestedYear,
      "requestedSemester": requestedSemester,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    return SemesterStatusModel.fromJson({
      "requestId": requestId,
      ...reqData,
      "requestedYear": requestedYear,
      "requestedSemester": requestedSemester,
      "updatedAt": DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> dismissRejection({required String requestId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    // 1. Try Cloud Function
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('dismissSemesterRejection');
        await callable.call({'requestId': requestId});
        return;
      } catch (e) {
        AppLogger.w('dismissSemesterRejection callable note: $e. Falling back to direct Firestore update.');
      }
    }

    // 2. Direct Firestore fallback
    await _firestore.collection("semesterUpgradeRequests").doc(requestId).update({
      "isDismissed": true,
      "status": "DISMISSED",
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<SemesterUpgradeRequestModel>> getMyUpgradeRequests() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final snapshot = await _firestore
        .collection("semesterUpgradeRequests")
        .where("studentId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return SemesterUpgradeRequestModel.fromJson({"id": doc.id, ...doc.data()});
    }).toList();
  }
}

// ─── Repository ──────────────────────────────────────────────────────────────

class SemesterRepositoryImpl implements SemesterRepository {
  final SemesterRemoteDataSource remoteDataSource;

  SemesterRepositoryImpl({required this.remoteDataSource});

  @override
  Future<SemesterStatus> getStatus() async {
    try {
      return await remoteDataSource.getStatus();
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<SemesterStatus> requestUpgrade({required int requestedYear, required int requestedSemester}) async {
    try {
      return await remoteDataSource.requestUpgrade(
        requestedYear: requestedYear,
        requestedSemester: requestedSemester,
      );
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<SemesterStatus> changeUpgradeRequest({
    required String requestId,
    required int requestedYear,
    required int requestedSemester,
  }) async {
    try {
      return await remoteDataSource.changeUpgradeRequest(
        requestId: requestId,
        requestedYear: requestedYear,
        requestedSemester: requestedSemester,
      );
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> dismissRejection({required String requestId}) async {
    try {
      return await remoteDataSource.dismissRejection(requestId: requestId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<SemesterUpgradeRequest>> getMyUpgradeRequests() async {
    try {
      final list = await remoteDataSource.getMyUpgradeRequests();
      return List<SemesterUpgradeRequest>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
