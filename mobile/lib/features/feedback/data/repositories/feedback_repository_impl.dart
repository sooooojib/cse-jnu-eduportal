import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
    String? courseCode,
    String? courseTitle,
    required int rating,
    required String comments,
    required bool isAnonymous,
    List<Attachment> attachments = const [],
  });

  Future<FeedbackItemModel> editFeedback({
    required String feedbackId,
    int? rating,
    String? comments,
    bool? isAnonymous,
    List<Attachment>? attachments,
  });

  Future<List<FeedbackItemModel>> getMySubmissions();

  Future<List<FeedbackItemModel>> getTeacherFeedback({
    required String teacherId,
    String filter = 'ALL',
  });

  Future<FeedbackItemModel> replyToFeedback({
    required String feedbackId,
    required String replyText,
    List<Attachment> attachments = const [],
  });

  Future<FeedbackItemModel> editFeedbackReply({
    required String feedbackId,
    required String replyId,
    required String replyText,
    List<Attachment>? attachments,
  });

  Future<List<FeedbackItemModel>> getAdminFeedback();
}

class FeedbackRemoteDataSourceImpl implements FeedbackRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  FeedbackRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<FeedbackItemModel> submitFeedback({
    required String teacherId,
    String? courseId,
    String? courseCode,
    String? courseTitle,
    required int rating,
    required String comments,
    required bool isAnonymous,
    List<Attachment> attachments = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final mappedAttachments = attachments
        .map((a) => {
              "id": a.id,
              "fileName": a.fileName,
              "fileUrl": a.fileUrl,
              "mimeType": a.mimeType,
              "fileSize": a.fileSize,
            })
        .toList();

    // 1. Attempt Cloud Function call
    try {
      final callable = _functions.httpsCallable('submitFeedback');
      final res = await callable.call({
        'teacherId': teacherId,
        if (courseId != null) 'courseId': courseId,
        if (courseCode != null) 'courseCode': courseCode,
        if (courseTitle != null) 'courseTitle': courseTitle,
        'rating': rating,
        'comments': comments,
        'isAnonymous': isAnonymous,
        'attachments': mappedAttachments,
      });

      final data = res.data;
      if (data is Map && data['feedback'] != null) {
        return FeedbackItemModel.fromJson(Map<String, dynamic>.from(data['feedback'] as Map));
      }
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to submit feedback.');
    } catch (_) {
      // Fallback to direct Firestore below
    }

    // 2. Direct Firestore fallback
    String teacherName = "Unknown Teacher";
    try {
      final teacherDoc = await _firestore.collection("users").doc(teacherId).get();
      if (teacherDoc.exists) {
        teacherName = teacherDoc.data()!["fullName"] as String? ?? teacherName;
      }
    } catch (_) {}

    String? resolvedCode = courseCode;
    String? resolvedTitle = courseTitle;
    if (courseId != null && (resolvedCode == null || resolvedTitle == null)) {
      try {
        final courseDoc = await _firestore.collection("courses").doc(courseId).get();
        if (courseDoc.exists) {
          final cData = courseDoc.data()!;
          resolvedCode ??= cData["code"] as String?;
          resolvedTitle ??= cData["title"] as String?;
        }
      } catch (_) {}
    }

    final currentUser = _auth.currentUser;
    final studentName = isAnonymous ? "Anonymous Student" : (currentUser?.displayName ?? "Student");
    final studentId = isAnonymous ? "ANONYMOUS" : uid;

    final feedbackPayload = <String, dynamic>{
      "studentId": studentId,
      "studentName": studentName,
      if (!isAnonymous && currentUser?.email != null) "studentEmail": currentUser!.email,
      "teacherId": teacherId,
      "teacherName": teacherName,
      if (courseId != null) "courseId": courseId,
      if (resolvedCode != null) "courseCode": resolvedCode,
      if (resolvedTitle != null) "courseTitle": resolvedTitle,
      "rating": rating,
      "comments": comments,
      "isAnonymous": isAnonymous,
      "attachments": mappedAttachments,
      "replies": <dynamic>[],
      "createdAt": FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection("feedback").add(feedbackPayload);

    // Save isolated identity in feedbackIdentities
    try {
      await _firestore.collection("feedbackIdentities").doc(docRef.id).set({
        "feedbackId": docRef.id,
        "studentId": uid,
        "studentName": currentUser?.displayName ?? "Student",
        "studentEmail": currentUser?.email ?? "",
        "teacherId": teacherId,
        "isAnonymous": isAnonymous,
        "createdAt": FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return FeedbackItemModel.fromJson({
      "id": docRef.id,
      ...feedbackPayload,
      "createdAt": DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<FeedbackItemModel> editFeedback({
    required String feedbackId,
    int? rating,
    String? comments,
    bool? isAnonymous,
    List<Attachment>? attachments,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    List<Map<String, dynamic>>? mappedAttachments;
    if (attachments != null) {
      mappedAttachments = attachments
          .map((a) => {
                "id": a.id,
                "fileName": a.fileName,
                "fileUrl": a.fileUrl,
                "mimeType": a.mimeType,
                "fileSize": a.fileSize,
              })
          .toList();
    }

    // 1. Try Cloud Function
    try {
      final callable = _functions.httpsCallable('editFeedback');
      final res = await callable.call({
        'feedbackId': feedbackId,
        if (rating != null) 'rating': rating,
        if (comments != null) 'comments': comments,
        if (isAnonymous != null) 'isAnonymous': isAnonymous,
        if (mappedAttachments != null) 'attachments': mappedAttachments,
      });

      final data = res.data;
      if (data is Map && data['feedback'] != null) {
        return FeedbackItemModel.fromJson(Map<String, dynamic>.from(data['feedback'] as Map));
      }
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to edit feedback.');
    } catch (_) {
      // Fallback to Firestore direct update
    }

    // 2. Direct Firestore fallback
    final docRef = _firestore.collection("feedback").doc(feedbackId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      throw const ServerException(message: "Feedback not found.");
    }

    final data = docSnap.data()!;
    final updateData = <String, dynamic>{
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (rating != null) updateData["rating"] = rating;
    if (comments != null) updateData["comments"] = comments;
    if (mappedAttachments != null) updateData["attachments"] = mappedAttachments;

    if (isAnonymous != null) {
      updateData["isAnonymous"] = isAnonymous;
      if (isAnonymous) {
        updateData["studentId"] = "ANONYMOUS";
        updateData["studentName"] = "Anonymous Student";
        updateData["studentEmail"] = FieldValue.delete();
      } else {
        updateData["studentId"] = uid;
        updateData["studentName"] = _auth.currentUser?.displayName ?? "Student";
        if (_auth.currentUser?.email != null) {
          updateData["studentEmail"] = _auth.currentUser!.email;
        }
      }
    }

    await docRef.update(updateData);
    final updatedSnap = await docRef.get();
    return FeedbackItemModel.fromJson({"id": feedbackId, ...updatedSnap.data()!});
  }

  @override
  Future<List<FeedbackItemModel>> getMySubmissions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    try {
      final identitiesSnap = await _firestore
          .collection("feedbackIdentities")
          .where("studentId", isEqualTo: uid)
          .get();

      if (identitiesSnap.docs.isNotEmpty) {
        final List<FeedbackItemModel> items = [];
        for (final idDoc in identitiesSnap.docs) {
          final doc = await _firestore.collection("feedback").doc(idDoc.id).get();
          if (doc.exists && doc.data() != null) {
            items.add(FeedbackItemModel.fromJson({"id": doc.id, ...doc.data()!}));
          }
        }
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      }
    } catch (_) {}

    final snapshot = await _firestore
        .collection("feedback")
        .where("studentId", isEqualTo: uid)
        .get();

    final list = snapshot.docs.map((doc) {
      return FeedbackItemModel.fromJson({"id": doc.id, ...doc.data()});
    }).toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<FeedbackItemModel>> getTeacherFeedback({
    required String teacherId,
    String filter = 'ALL',
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final snapshot = await _firestore
        .collection("feedback")
        .where("teacherId", isEqualTo: teacherId)
        .get();

    var items = snapshot.docs.map((doc) {
      final data = doc.data();
      // Enforce zero student identity leak for anonymous feedback
      if (data['isAnonymous'] == true) {
        data['studentId'] = 'ANONYMOUS';
        data['studentName'] = 'Anonymous Student';
        data.remove('studentEmail');
      }
      return FeedbackItemModel.fromJson({"id": doc.id, ...data});
    }).toList();

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (filter == 'REPLIED') {
      items = items.where((f) => f.hasReplied).toList();
    } else if (filter == 'NOT_REPLIED') {
      items = items.where((f) => !f.hasReplied).toList();
    }

    return items;
  }

  @override
  Future<FeedbackItemModel> replyToFeedback({
    required String feedbackId,
    required String replyText,
    List<Attachment> attachments = const [],
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final mappedAttachments = attachments
        .map((a) => {
              "id": a.id,
              "fileName": a.fileName,
              "fileUrl": a.fileUrl,
              "mimeType": a.mimeType,
              "fileSize": a.fileSize,
            })
        .toList();

    // 1. Try Cloud Function
    try {
      final callable = _functions.httpsCallable('replyToFeedback');
      final res = await callable.call({
        'feedbackId': feedbackId,
        'replyText': replyText,
        'attachments': mappedAttachments,
      });

      final data = res.data;
      if (data is Map && data['feedback'] != null) {
        return FeedbackItemModel.fromJson(Map<String, dynamic>.from(data['feedback'] as Map));
      }
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to reply to feedback.');
    } catch (_) {
      // Fallback
    }

    // 2. Direct Firestore fallback
    final docRef = _firestore.collection("feedback").doc(feedbackId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      throw const ServerException(message: "Feedback not found.");
    }

    final data = docSnap.data()!;
    if (data['teacherId'] != uid) {
      throw const ServerException(message: "You can only reply to feedback directed to you.");
    }

    final teacherName = _auth.currentUser?.displayName ?? (data['teacherName'] ?? 'Faculty');
    final newReply = {
      "id": "reply_${DateTime.now().millisecondsSinceEpoch}",
      "teacherId": uid,
      "teacherName": teacherName,
      "replyText": replyText,
      "attachments": mappedAttachments,
      "createdAt": DateTime.now().toIso8601String(),
    };

    final currentReplies = List<dynamic>.from(data['replies'] ?? []);
    currentReplies.add(newReply);

    await docRef.update({
      "replies": currentReplies,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    final updatedSnap = await docRef.get();
    return FeedbackItemModel.fromJson({"id": feedbackId, ...updatedSnap.data()!});
  }

  @override
  Future<FeedbackItemModel> editFeedbackReply({
    required String feedbackId,
    required String replyId,
    required String replyText,
    List<Attachment>? attachments,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    List<Map<String, dynamic>>? mappedAttachments;
    if (attachments != null) {
      mappedAttachments = attachments
          .map((a) => {
                "id": a.id,
                "fileName": a.fileName,
                "fileUrl": a.fileUrl,
                "mimeType": a.mimeType,
                "fileSize": a.fileSize,
              })
          .toList();
    }

    // 1. Try Cloud Function
    try {
      final callable = _functions.httpsCallable('editFeedbackReply');
      final res = await callable.call({
        'feedbackId': feedbackId,
        'replyId': replyId,
        'replyText': replyText,
        if (mappedAttachments != null) 'attachments': mappedAttachments,
      });

      final data = res.data;
      if (data is Map && data['feedback'] != null) {
        return FeedbackItemModel.fromJson(Map<String, dynamic>.from(data['feedback'] as Map));
      }
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(message: e.message ?? 'Failed to edit reply.');
    } catch (_) {
      // Fallback
    }

    // 2. Direct Firestore fallback
    final docRef = _firestore.collection("feedback").doc(feedbackId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      throw const ServerException(message: "Feedback not found.");
    }

    final data = docSnap.data()!;
    final replies = List<dynamic>.from(data['replies'] ?? []);
    final replyIndex = replies.indexWhere((r) => r is Map && r['id'] == replyId);

    if (replyIndex == -1) {
      throw const ServerException(message: "Reply not found.");
    }

    final existingReply = Map<String, dynamic>.from(replies[replyIndex] as Map);
    if (existingReply['teacherId'] != uid && data['teacherId'] != uid) {
      throw const ServerException(message: "You can only edit your own replies.");
    }

    existingReply['replyText'] = replyText;
    if (mappedAttachments != null) existingReply['attachments'] = mappedAttachments;
    existingReply['updatedAt'] = DateTime.now().toIso8601String();

    replies[replyIndex] = existingReply;

    await docRef.update({
      "replies": replies,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    final updatedSnap = await docRef.get();
    return FeedbackItemModel.fromJson({"id": feedbackId, ...updatedSnap.data()!});
  }

  @override
  Future<List<FeedbackItemModel>> getAdminFeedback() async {
    final snapshot = await _firestore.collection("feedback").get();

    final List<FeedbackItemModel> results = [];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      // If anonymous, admin has authorization to read feedbackIdentities to audit identity
      if (data['isAnonymous'] == true) {
        try {
          final identityDoc = await _firestore.collection("feedbackIdentities").doc(doc.id).get();
          if (identityDoc.exists && identityDoc.data() != null) {
            final idData = identityDoc.data()!;
            data['studentName'] = 'Anonymous (${idData['studentName'] ?? 'Student'})';
            data['studentEmail'] = idData['studentEmail'];
          }
        } catch (_) {}
      }
      results.add(FeedbackItemModel.fromJson({"id": doc.id, ...data}));
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
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
    String? courseCode,
    String? courseTitle,
    required int rating,
    required String comments,
    required bool isAnonymous,
    List<Attachment> attachments = const [],
  }) async {
    try {
      return await remoteDataSource.submitFeedback(
        teacherId: teacherId,
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
        rating: rating,
        comments: comments,
        isAnonymous: isAnonymous,
        attachments: attachments,
      );
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<FeedbackItem> editFeedback({
    required String feedbackId,
    int? rating,
    String? comments,
    bool? isAnonymous,
    List<Attachment>? attachments,
  }) async {
    try {
      return await remoteDataSource.editFeedback(
        feedbackId: feedbackId,
        rating: rating,
        comments: comments,
        isAnonymous: isAnonymous,
        attachments: attachments,
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

  @override
  Future<List<FeedbackItem>> getTeacherFeedback({
    required String teacherId,
    String filter = 'ALL',
  }) async {
    try {
      final list = await remoteDataSource.getTeacherFeedback(
        teacherId: teacherId,
        filter: filter,
      );
      return List<FeedbackItem>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<FeedbackItem> replyToFeedback({
    required String feedbackId,
    required String replyText,
    List<Attachment> attachments = const [],
  }) async {
    try {
      return await remoteDataSource.replyToFeedback(
        feedbackId: feedbackId,
        replyText: replyText,
        attachments: attachments,
      );
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<FeedbackItem> editFeedbackReply({
    required String feedbackId,
    required String replyId,
    required String replyText,
    List<Attachment>? attachments,
  }) async {
    try {
      return await remoteDataSource.editFeedbackReply(
        feedbackId: feedbackId,
        replyId: replyId,
        replyText: replyText,
        attachments: attachments,
      );
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<FeedbackItem>> getAdminFeedback() async {
    try {
      final list = await remoteDataSource.getAdminFeedback();
      return List<FeedbackItem>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
