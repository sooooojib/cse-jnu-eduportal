import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../models/semester_upgrade_request_model.dart';
import '../../domain/entities/semester_status.dart';
import '../../domain/repositories/semester_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class SemesterRemoteDataSource {
  Future<SemesterStatusModel> getStatus();
  Future<SemesterStatusModel> requestUpgrade({required int requestedYear, required int requestedSemester});
  Future<List<SemesterUpgradeRequestModel>> getMyUpgradeRequests();
}

class SemesterRemoteDataSourceImpl implements SemesterRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  SemesterRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  @override
  Future<SemesterStatusModel> getStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final userDoc = await _firestore.collection("users").doc(uid).get();
    if (!userDoc.exists) throw const ServerException(message: "User profile not found.");

    final userData = userDoc.data()!;

    // Check for any pending/recent upgrade request
    final upgradeSnap = await _firestore
        .collection("semesterUpgradeRequests")
        .where("studentId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .limit(1)
        .get();

    if (upgradeSnap.docs.isEmpty) {
      return SemesterStatusModel(
        currentYear: userData["year"] as int?,
        currentSemester: userData["semester"] as int?,
        status: "NONE",
      );
    }

    final req = upgradeSnap.docs.first.data();
    return SemesterStatusModel.fromJson({
      "currentYear": userData["year"],
      "currentSemester": userData["semester"],
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

    final userDoc = await _firestore.collection("users").doc(uid).get();
    final userData = userDoc.data() ?? {};

    final currentYear = userData["year"] as int? ?? 1;
    final currentSemester = userData["semester"] as int? ?? 1;
    final studentName = userData["fullName"] as String? ?? "";
    final studentRoll = userData["studentId"] as String? ?? "";

    await _firestore.collection("semesterUpgradeRequests").add({
      "studentId": uid,
      "studentName": studentName,
      "studentRoll": studentRoll,
      "currentYear": currentYear,
      "currentSemester": currentSemester,
      "requestedYear": requestedYear,
      "requestedSemester": requestedSemester,
      "status": "PENDING",
      "rejectionReason": null,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    return SemesterStatusModel(
      currentYear: currentYear,
      currentSemester: currentSemester,
      requestedYear: requestedYear,
      requestedSemester: requestedSemester,
      status: "PENDING",
      updatedAt: DateTime.now().toIso8601String(),
    );
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
  Future<List<SemesterUpgradeRequest>> getMyUpgradeRequests() async {
    try {
      final list = await remoteDataSource.getMyUpgradeRequests();
      return List<SemesterUpgradeRequest>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
