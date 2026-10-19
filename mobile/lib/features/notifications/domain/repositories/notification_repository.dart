import '../entities/notification_entities.dart';

abstract class NotificationRepository {
  Future<NotificationFeed> getNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> registerDeviceToken(String token);
  Future<void> unregisterDeviceToken(String token);
}

class GetNotificationsUseCase {
  final NotificationRepository repository;
  GetNotificationsUseCase(this.repository);

  Future<NotificationFeed> execute() => repository.getNotifications();
}

class MarkNotificationReadUseCase {
  final NotificationRepository repository;
  MarkNotificationReadUseCase(this.repository);

  Future<void> execute(String id) => repository.markAsRead(id);
}

class MarkAllNotificationsReadUseCase {
  final NotificationRepository repository;
  MarkAllNotificationsReadUseCase(this.repository);

  Future<void> execute() => repository.markAllAsRead();
}

class RegisterDeviceTokenUseCase {
  final NotificationRepository repository;
  RegisterDeviceTokenUseCase(this.repository);

  Future<void> execute(String token) => repository.registerDeviceToken(token);
}

class UnregisterDeviceTokenUseCase {
  final NotificationRepository repository;
  UnregisterDeviceTokenUseCase(this.repository);

  Future<void> execute(String token) => repository.unregisterDeviceToken(token);
}
