import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../models/notification_models.dart';
import '../../domain/entities/notification_entities.dart';
import '../../domain/repositories/notification_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class NotificationRemoteDataSource {
  Future<NotificationFeedModel> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> registerDeviceToken(String token);
  Future<void> unregisterDeviceToken(String token);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  NotificationRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  @override
  Future<NotificationFeedModel> getNotifications() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final userSnapshot = await _firestore
        .collection("notifications")
        .where("userId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .limit(50)
        .get();

    final allSnapshot = await _firestore
        .collection("notifications")
        .where("userId", isEqualTo: "ALL")
        .orderBy("createdAt", descending: true)
        .limit(20)
        .get();

    final combinedDocs = [...userSnapshot.docs, ...allSnapshot.docs];
    // Deduplicate and sort descending by createdAt
    final uniqueMap = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in combinedDocs) {
      uniqueMap[doc.id] = doc;
    }

    final items = uniqueMap.values.map((doc) {
      return AppNotificationModel.fromJson({"id": doc.id, ...doc.data()!});
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final unreadCount = items.where((n) => !n.isRead).length;

    return NotificationFeedModel(
      unreadCount: unreadCount,
      notifications: items,
    );
  }

  @override
  Future<void> markAsRead(String id) async {
    await _firestore.collection("notifications").doc(id).update({
      "isRead": true,
      "readAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markAllAsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection("notifications")
        .where("userId", isEqualTo: uid)
        .where("isRead", isEqualTo: false)
        .get();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        "isRead": true,
        "readAt": FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> registerDeviceToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || token.trim().isEmpty) return;

    await _firestore.collection("users").doc(uid).update({
      "fcmTokens": FieldValue.arrayUnion([token.trim()]),
      "lastDeviceTokenUpdatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || token.trim().isEmpty) return;

    await _firestore.collection("users").doc(uid).update({
      "fcmTokens": FieldValue.arrayRemove([token.trim()]),
      "lastDeviceTokenUpdatedAt": FieldValue.serverTimestamp(),
    });
  }
}

// ─── Repository ──────────────────────────────────────────────────────────────

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;

  NotificationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<NotificationFeed> getNotifications() async {
    try {
      return await remoteDataSource.getNotifications();
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await remoteDataSource.markAsRead(id);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await remoteDataSource.markAllAsRead();
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> registerDeviceToken(String token) async {
    try {
      await remoteDataSource.registerDeviceToken(token);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    try {
      await remoteDataSource.unregisterDeviceToken(token);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
