import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  final String id;
  final String title;
  final String body;
  final String notificationType;
  final String? referenceType;
  final String? referenceId;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.notificationType,
    this.referenceType,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, title, body, notificationType, referenceType, referenceId, isRead, createdAt];
}

class NotificationFeed extends Equatable {
  final int unreadCount;
  final List<AppNotification> notifications;

  const NotificationFeed({
    required this.unreadCount,
    required this.notifications,
  });

  @override
  List<Object?> get props => [unreadCount, notifications];
}
