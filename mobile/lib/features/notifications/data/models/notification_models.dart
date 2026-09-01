import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/notification_entities.dart';

String _tsToString(dynamic value) {
  if (value == null) return DateTime.now().toIso8601String();
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value.toString();
}

class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.title,
    required super.body,
    required super.notificationType,
    super.referenceType,
    super.referenceId,
    required super.isRead,
    required super.createdAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      notificationType: json['notificationType'] as String? ?? 'GENERAL',
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: _tsToString(json['createdAt']),
    );
  }

  factory AppNotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotificationModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'notificationType': notificationType,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'isRead': isRead,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'notificationType': notificationType,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class NotificationFeedModel extends NotificationFeed {
  const NotificationFeedModel({
    required super.unreadCount,
    required super.notifications,
  });

  factory NotificationFeedModel.fromJson(Map<String, dynamic> json) {
    final list = (json['notifications'] as List? ?? [])
        .map((e) => AppNotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return NotificationFeedModel(
      unreadCount: json['unreadCount'] as int? ?? 0,
      notifications: List<AppNotification>.from(list),
    );
  }
}
