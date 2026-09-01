import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/semester_status.dart';
import '../../domain/repositories/semester_repository.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class SemesterStatusModel extends SemesterStatus {
  const SemesterStatusModel({
    super.currentYear,
    super.currentSemester,
    super.requestedYear,
    super.requestedSemester,
    required super.status,
    super.rejectionReason,
    super.updatedAt,
  });

  factory SemesterStatusModel.fromJson(Map<String, dynamic> json) {
    return SemesterStatusModel(
      currentYear: json["currentYear"] as int?,
      currentSemester: json["currentSemester"] as int?,
      requestedYear: json["requestedYear"] as int?,
      requestedSemester: json["requestedSemester"] as int?,
      status: json["semesterStatus"] as String? ?? json["status"] as String? ?? "NONE",
      rejectionReason: json["rejectionReason"] as String?,
      updatedAt: json["updatedAt"] as String?,
    );
  }
}

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class SemesterRemoteDataSource {
  Future<SemesterStatusModel> getStatus();
  Future<SemesterStatusModel> requestUpgrade({required int requestedYear, required int requestedSemester});
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

    final now = DateTime.now().toIso8601String();
    await _firestore.collection("semesterUpgradeRequests").add({
      "studentId": uid,
      "requestedYear": requestedYear,
      "requestedSemester": requestedSemester,
      "status": "PENDING",
      "createdAt": now,
    });

    return SemesterStatusModel(
      currentYear: userData["year"] as int?,
      currentSemester: userData["semester"] as int?,
      requestedYear: requestedYear,
      requestedSemester: requestedSemester,
      status: "PENDING",
      updatedAt: now,
    );
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
}
