import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/core/notifications/push_notification_service.dart';
import 'package:cse_jnu_eduportal/features/notifications/domain/entities/notification_entities.dart';
import 'package:cse_jnu_eduportal/features/notifications/domain/repositories/notification_repository.dart';
import 'package:cse_jnu_eduportal/features/notifications/data/models/notification_models.dart';
import 'package:cse_jnu_eduportal/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:cse_jnu_eduportal/features/notifications/presentation/screens/notification_list_screen.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart' as di;

class MockNotificationRepository extends Mock implements NotificationRepository {}
class MockGetNotificationsUseCase extends Mock implements GetNotificationsUseCase {}
class MockMarkNotificationReadUseCase extends Mock implements MarkNotificationReadUseCase {}
class MockMarkAllNotificationsReadUseCase extends Mock implements MarkAllNotificationsReadUseCase {}
class MockPushNotificationService extends Mock implements PushNotificationService {}

void main() {
  group('STAGE 27: Notification Entities & Data Models Tests', () {
    test('1. AppNotificationModel fromJson, toJson and toFirestore with deep link route', () {
      final json = {
        'id': 'notif_001',
        'title': 'Counseling Booking Approved',
        'body': 'Your appointment with Dr. Layek on 2026-10-25 was approved.',
        'notificationType': 'COUNSELING_STATUS',
        'referenceType': 'COUNSELING',
        'referenceId': 'book_999',
        'route': '/counseling',
        'isRead': false,
        'createdAt': '2026-10-20T10:00:00.000Z',
      };

      final model = AppNotificationModel.fromJson(json);

      expect(model.id, 'notif_001');
      expect(model.title, 'Counseling Booking Approved');
      expect(model.notificationType, 'COUNSELING_STATUS');
      expect(model.referenceId, 'book_999');
      expect(model.route, '/counseling');
      expect(model.isRead, false);

      final exportedJson = model.toJson();
      expect(exportedJson['route'], '/counseling');
      expect(exportedJson['isRead'], false);

      final firestoreData = model.toFirestore();
      expect(firestoreData['route'], '/counseling');
      expect(firestoreData['title'], 'Counseling Booking Approved');
    });

    test('2. NotificationFeedModel parses notifications list and computes unread count', () {
      final json = {
        'unreadCount': 2,
        'notifications': [
          {
            'id': 'n1',
            'title': 'Notice 1',
            'body': 'Dept notice',
            'notificationType': 'NOTICE',
            'isRead': false,
            'createdAt': '2026-10-20T08:00:00Z',
          },
          {
            'id': 'n2',
            'title': 'Notice 2',
            'body': 'Exam schedule',
            'notificationType': 'SEMESTER_DECISION',
            'route': '/profile',
            'isRead': true,
            'createdAt': '2026-10-19T08:00:00Z',
          },
        ],
      };

      final feed = NotificationFeedModel.fromJson(json);
      expect(feed.notifications.length, 2);
      expect(feed.unreadCount, 2);
      expect(feed.notifications.first.id, 'n1');
      expect(feed.notifications.last.route, '/profile');
    });
  });

  group('STAGE 27: Push Notification Deep Linking & Resolver Tests', () {
    test('3. resolveDeepLinkRoute correctly maps explicit route from payload', () {
      final route = PushNotificationServiceImpl.resolveDeepLinkRoute({
        'route': '/admin/users',
        'notificationType': 'GENERAL',
      });
      expect(route, '/admin/users');
    });

    test('4. resolveDeepLinkRoute correctly maps event notification types to routes', () {
      // Counseling
      expect(
        PushNotificationServiceImpl.resolveDeepLinkRoute({'notificationType': 'COUNSELING_STATUS'}),
        '/counseling',
      );
      expect(
        PushNotificationServiceImpl.resolveDeepLinkRoute({'notificationType': 'COUNSELING_APPROVED'}),
        '/counseling',
      );

      // Feedback
      expect(
        PushNotificationServiceImpl.resolveDeepLinkRoute({'notificationType': 'FEEDBACK_REPLY'}),
        '/feedback',
      );
      expect(
        PushNotificationServiceImpl.resolveDeepLinkRoute({'notificationType': 'FEEDBACK_SUBMISSION'}),
        '/teacher/feedback',
      );

      // Semester
      expect(
        PushNotificationServiceImpl.resolveDeepLinkRoute({'notificationType': 'SEMESTER_DECISION'}),
        '/profile',
      );
      expect(
        PushNotificationServiceImpl.resolveDeepLinkRoute({'notificationType': 'SEMESTER_UPGRADE'}),
        '/profile',
      );

      // Attendance
      expect(
        PushNotificationServiceImpl.resolveDeepLinkRoute({'notificationType': 'ATTENDANCE_VERIFIED'}),
        '/attendance',
      );

      // Signup Decision
      expect(
        PushNotificationServiceImpl.resolveDeepLinkRoute({'notificationType': 'SIGNUP_DECISION'}),
        '/dashboard/student',
      );

      // Default
      expect(
        PushNotificationServiceImpl.resolveDeepLinkRoute({'notificationType': 'NOTICE'}),
        '/notifications',
      );
    });
  });

  group('STAGE 27: Device Token Registration & Logout Unregistration Tests', () {
    late MockNotificationRepository mockRepo;

    setUp(() {
      mockRepo = MockNotificationRepository();
    });

    test('5. RegisterDeviceTokenUseCase delegates to repository', () async {
      when(() => mockRepo.registerDeviceToken('token_abc1234567'))
          .thenAnswer((_) async {});

      final useCase = RegisterDeviceTokenUseCase(mockRepo);
      await useCase.execute('token_abc1234567');

      verify(() => mockRepo.registerDeviceToken('token_abc1234567')).called(1);
    });

    test('6. UnregisterDeviceTokenUseCase delegates to repository on logout', () async {
      when(() => mockRepo.unregisterDeviceToken('token_to_remove'))
          .thenAnswer((_) async {});

      final useCase = UnregisterDeviceTokenUseCase(mockRepo);
      await useCase.execute('token_to_remove');

      verify(() => mockRepo.unregisterDeviceToken('token_to_remove')).called(1);
    });
  });

  group('STAGE 27: NotificationController State & Actions Tests', () {
    late MockGetNotificationsUseCase mockGetNotifs;
    late MockMarkNotificationReadUseCase mockMarkRead;
    late MockMarkAllNotificationsReadUseCase mockMarkAllRead;
    late NotificationController controller;

    final testFeed = NotificationFeed(
      unreadCount: 1,
      notifications: [
        AppNotification(
          id: 'notif_1',
          title: 'Feedback Response Received',
          body: 'Teacher replied to your feedback.',
          notificationType: 'FEEDBACK_REPLY',
          route: '/feedback',
          isRead: false,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ],
    );

    setUp(() {
      mockGetNotifs = MockGetNotificationsUseCase();
      mockMarkRead = MockMarkNotificationReadUseCase();
      mockMarkAllRead = MockMarkAllNotificationsReadUseCase();

      controller = NotificationController(
        getNotificationsUseCase: mockGetNotifs,
        markNotificationReadUseCase: mockMarkRead,
        markAllNotificationsReadUseCase: mockMarkAllRead,
      );
    });

    test('7. fetchNotifications loads feed and transitions to NotificationLoaded', () async {
      when(() => mockGetNotifs.execute()).thenAnswer((_) async => testFeed);

      expect(controller.state, isA<NotificationInitial>());
      await controller.fetchNotifications();

      expect(controller.state, isA<NotificationLoaded>());
      final loaded = controller.state as NotificationLoaded;
      expect(loaded.feed.notifications.length, 1);
      expect(loaded.feed.unreadCount, 1);
    });

    test('8. markAsRead calls useCase and triggers re-fetch', () async {
      when(() => mockMarkRead.execute('notif_1')).thenAnswer((_) async {});
      when(() => mockGetNotifs.execute()).thenAnswer((_) async => testFeed);

      await controller.markAsRead('notif_1');

      verify(() => mockMarkRead.execute('notif_1')).called(1);
      verify(() => mockGetNotifs.execute()).called(1);
    });

    test('9. markAllAsRead calls useCase and triggers re-fetch', () async {
      when(() => mockMarkAllRead.execute()).thenAnswer((_) async {});
      when(() => mockGetNotifs.execute()).thenAnswer((_) async => testFeed);

      await controller.markAllAsRead();

      verify(() => mockMarkAllRead.execute()).called(1);
      verify(() => mockGetNotifs.execute()).called(1);
    });
  });

  group('STAGE 27: NotificationListScreen Presentation & Tap Navigation Tests', () {
    late MockGetNotificationsUseCase mockGetNotifs;
    late MockMarkNotificationReadUseCase mockMarkRead;
    late MockMarkAllNotificationsReadUseCase mockMarkAllRead;
    late NotificationController controller;

    setUp(() {
      mockGetNotifs = MockGetNotificationsUseCase();
      mockMarkRead = MockMarkNotificationReadUseCase();
      mockMarkAllRead = MockMarkAllNotificationsReadUseCase();

      controller = NotificationController(
        getNotificationsUseCase: mockGetNotifs,
        markNotificationReadUseCase: mockMarkRead,
        markAllNotificationsReadUseCase: mockMarkAllRead,
      );

      if (di.sl.isRegistered<NotificationController>()) {
        di.sl.unregister<NotificationController>();
      }
      di.sl.registerFactory<NotificationController>(() => controller);
    });

    testWidgets('10. Renders notification list with unread indicator and category chip', (tester) async {
      final feed = NotificationFeed(
        unreadCount: 1,
        notifications: [
          AppNotification(
            id: 'n_counsel',
            title: 'Counseling Approved',
            body: 'Dr. Layek confirmed your slot.',
            notificationType: 'COUNSELING_STATUS',
            route: '/counseling',
            isRead: false,
            createdAt: '2026-10-20',
          ),
          AppNotification(
            id: 'n_read',
            title: 'Welcome to EduPortal',
            body: 'Your account is active.',
            notificationType: 'SIGNUP_DECISION',
            route: '/profile',
            isRead: true,
            createdAt: '2026-10-18',
          ),
        ],
      );

      when(() => mockGetNotifs.execute()).thenAnswer((_) async => feed);

      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Counseling Approved'), findsOneWidget);
      expect(find.text('Welcome to EduPortal'), findsOneWidget);
      expect(find.text('Dr. Layek confirmed your slot.'), findsOneWidget);
    });

    testWidgets('11. Tapping unread notification marks it as read', (tester) async {
      final feed = NotificationFeed(
        unreadCount: 1,
        notifications: [
          AppNotification(
            id: 'notif_tap_test',
            title: 'New Feedback',
            body: 'Faculty responded to feedback.',
            notificationType: 'FEEDBACK_REPLY',
            route: '/feedback',
            isRead: false,
            createdAt: '2026-10-20',
          ),
        ],
      );

      when(() => mockGetNotifs.execute()).thenAnswer((_) async => feed);
      when(() => mockMarkRead.execute('notif_tap_test')).thenAnswer((_) async {});

      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Feedback'));
      await tester.pump();

      verify(() => mockMarkRead.execute('notif_tap_test')).called(1);
    });

    testWidgets('12. Tapping notification with GoRouter navigates to deep link route', (tester) async {
      final feed = NotificationFeed(
        unreadCount: 1,
        notifications: [
          AppNotification(
            id: 'notif_nav_test',
            title: 'Counseling Approved',
            body: 'Go to counseling.',
            notificationType: 'COUNSELING_STATUS',
            route: '/counseling',
            isRead: false,
            createdAt: '2026-10-20',
          ),
        ],
      );

      when(() => mockGetNotifs.execute()).thenAnswer((_) async => feed);
      when(() => mockMarkRead.execute('notif_nav_test')).thenAnswer((_) async {});

      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationListScreen(),
          ),
          GoRoute(
            path: '/counseling',
            builder: (context, state) => const Scaffold(
              body: Text('Counseling Screen Destination'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Counseling Approved'), findsOneWidget);

      await tester.tap(find.text('Counseling Approved'));
      await tester.pumpAndSettle();

      expect(find.text('Counseling Screen Destination'), findsOneWidget);
    });
  });
}
