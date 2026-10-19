import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';

abstract class PushNotificationService {
  Future<void> initialize({void Function(String route)? onNavigate});
  Future<String?> getDeviceToken();
  Future<void> registerCurrentToken();
  Future<void> unregisterCurrentToken();
  Stream<RemoteMessage> get onForegroundMessage;
  void Function(String route)? get navigateHandler;
}

class PushNotificationServiceImpl implements PushNotificationService {
  final FirebaseMessaging _messaging;
  final NotificationRepository _notificationRepository;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  void Function(String route)? _navigateHandler;
  String? _lastKnownToken;

  PushNotificationServiceImpl({
    FirebaseMessaging? messaging,
    required NotificationRepository notificationRepository,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _notificationRepository = notificationRepository;

  @override
  void Function(String route)? get navigateHandler => _navigateHandler;

  @override
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  @override
  Future<void> initialize({void Function(String route)? onNavigate}) async {
    _navigateHandler = onNavigate;

    try {
      // 1. Request user permission on native platforms
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM Authorization status: ${settings.authorizationStatus}');

      // 2. Fetch initial device token and register
      await registerCurrentToken();

      // 3. Listen for token refreshes
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token refreshed: $newToken');
        _lastKnownToken = newToken;
        try {
          await _notificationRepository.registerDeviceToken(newToken);
        } catch (e) {
          debugPrint('Failed to register refreshed FCM token: $e');
        }
      });

      // 4. Handle notification tap when application is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageTap(message);
      });

      // 5. Handle notification tap when application was terminated and launched
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    } catch (e) {
      debugPrint('PushNotificationService initialization error: $e');
    }
  }

  @override
  Future<String?> getDeviceToken() async {
    try {
      _lastKnownToken ??= await _messaging.getToken();
      return _lastKnownToken;
    } catch (e) {
      debugPrint('Failed to get FCM device token: $e');
      return null;
    }
  }

  @override
  Future<void> registerCurrentToken() async {
    try {
      final token = await getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await _notificationRepository.registerDeviceToken(token);
        debugPrint('Device FCM token successfully registered with backend.');
      }
    } catch (e) {
      debugPrint('Error registering device token: $e');
    }
  }

  @override
  Future<void> unregisterCurrentToken() async {
    try {
      final token = _lastKnownToken ?? await getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await _notificationRepository.unregisterDeviceToken(token);
        debugPrint('Device FCM token successfully unregistered on logout.');
      }
    } catch (e) {
      debugPrint('Error unregistering device token: $e');
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('Notification clicked with payload data: ${message.data}');
    final route = resolveDeepLinkRoute(message.data);
    if (route != null && _navigateHandler != null) {
      _navigateHandler!(route);
    }
  }

  static String? resolveDeepLinkRoute(Map<String, dynamic> data) {
    // 1. Direct route in payload data
    final explicitRoute = data['route'] as String?;
    if (explicitRoute != null && explicitRoute.trim().isNotEmpty) {
      return explicitRoute.trim();
    }

    // 2. Type-based route mapping
    final type = (data['notificationType'] as String? ?? '').toUpperCase();
    switch (type) {
      case 'COUNSELING_STATUS':
      case 'COUNSELING_APPROVED':
      case 'COUNSELING_SLOT':
        return '/counseling';
      case 'FEEDBACK_REPLY':
        return '/feedback';
      case 'FEEDBACK_SUBMISSION':
        return '/teacher/feedback';
      case 'SEMESTER_DECISION':
      case 'SEMESTER':
      case 'SEMESTER_UPGRADE':
        return '/profile';
      case 'ATTENDANCE':
      case 'ATTENDANCE_VERIFIED':
        return '/attendance';
      case 'SIGNUP_DECISION':
        return '/dashboard/student';
      case 'NOTICE':
      default:
        return '/notifications';
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundSubscription?.cancel();
  }
}
