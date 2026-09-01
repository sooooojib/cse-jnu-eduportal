import 'package:flutter/foundation.dart';
import '../../domain/entities/notification_entities.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../../../core/error/failures.dart';

abstract class NotificationState {}
class NotificationInitial extends NotificationState {}
class NotificationLoading extends NotificationState {}
class NotificationLoaded extends NotificationState {
  final NotificationFeed feed;
  NotificationLoaded(this.feed);
}
class NotificationError extends NotificationState {
  final String message;
  NotificationError(this.message);
}

class NotificationController extends ChangeNotifier {
  final GetNotificationsUseCase getNotificationsUseCase;
  final MarkNotificationReadUseCase markNotificationReadUseCase;
  final MarkAllNotificationsReadUseCase markAllNotificationsReadUseCase;

  NotificationState _state = NotificationInitial();
  int _unreadCount = 0;

  NotificationController({
    required this.getNotificationsUseCase,
    required this.markNotificationReadUseCase,
    required this.markAllNotificationsReadUseCase,
  });

  NotificationState get state => _state;
  int get unreadCount => _unreadCount;

  Future<void> fetchNotifications() async {
    _state = NotificationLoading();
    notifyListeners();

    try {
      final feed = await getNotificationsUseCase.execute();
      _unreadCount = feed.unreadCount;
      _state = NotificationLoaded(feed);
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = NotificationError(message);
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await markNotificationReadUseCase.execute(id);
      await fetchNotifications();
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await markAllNotificationsReadUseCase.execute();
      await fetchNotifications();
    } catch (_) {}
  }
}
