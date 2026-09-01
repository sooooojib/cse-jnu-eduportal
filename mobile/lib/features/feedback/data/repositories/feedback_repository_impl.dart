import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../models/feedback_models.dart';
import '../../domain/entities/feedback_entities.dart';
import '../../domain/repositories/feedback_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class FeedbackRemoteDataSource {
  Future<FeedbackItemModel> submitFeedback({
    required String teacherId,
    String? courseId,
    required int rating,
    required String comments,
    required bool isAnonymous,
  });
  Future<List<FeedbackItemModel>> getMySubmissions();
}

class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  FeedbackRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  @override
  Future<FeedbackItemModel> submitFeedback({
    required String teacherId,
    String? courseId,
    required int rating,
    required String comments,
    required bool isAnonymous,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    // Fetch teacher name from Firestore
    String teacherName = "Unknown Teacher";
    try {
      final teacherDoc = await _firestore.collection("users").doc(teacherId).get();
      if (teacherDoc.exists) {
        teacherName = teacherDoc.data()!["fullName"] as String? ?? teacherName;
      }
    } catch (_) {}

    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      "studentId": isAnonymous ? "ANONYMOUS" : uid,
      "teacherId": teacherId,
      "teacherName": teacherName,
      if (courseId != null) "courseId": courseId,
      "rating": rating,
      "comments": comments,
      "isAnonymous": isAnonymous,
      "replies": <dynamic>[],
      "createdAt": now,
    };

    final docRef = await _firestore.collection("feedback").add(payload);
    return FeedbackItemModel.fromJson({"id": docRef.id, ...payload});
  }

  @override
  Future<List<FeedbackItemModel>> getMySubmissions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final snapshot = await _firestore
        .collection("feedback")
        .where("studentId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return FeedbackItemModel.fromJson({"id": doc.id, ...doc.data()});
    }).toList();
  }
}

// ─── Repository ──────────────────────────────────────────────────────────────

class FeedbackRepositoryImpl implements FeedbackRepository {
  final FeedbackRemoteDataSource remoteDataSource;

  FeedbackRepositoryImpl({required this.remoteDataSource});

  @override
  Future<FeedbackItem> submitFeedback({
    required String teacherId,
    String? courseId,
    required int rating,
    required String comments,
    required bool isAnonymous,
  }) async {
    try {
      return await remoteDataSource.submitFeedback(
        teacherId: teacherId,
        courseId: courseId,
        rating: rating,
        comments: comments,
        isAnonymous: isAnonymous,
      );
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<FeedbackItem>> getMySubmissions() async {
    try {
      final list = await remoteDataSource.getMySubmissions();
      return List<FeedbackItem>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
