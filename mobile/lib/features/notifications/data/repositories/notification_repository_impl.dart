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

    final snapshot = await _firestore
        .collection("notifications")
        .where("userId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .limit(50)
        .get();

    final items = snapshot.docs.map((doc) {
      return AppNotificationModel.fromJson({"id": doc.id, ...doc.data()});
    }).toList();

    final unreadCount = items.where((n) => !n.isRead).length;

    return NotificationFeedModel(
      unreadCount: unreadCount,
      notifications: items,
    );
  }

  @override
  Future<void> markAsRead(String id) async {
    await _firestore.collection("notifications").doc(id).update({"isRead": true});
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
      batch.update(doc.reference, {"isRead": true});
    }
    await batch.commit();
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
}
