import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/entities/department_notice.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/repositories/admin_repository.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/screens/admin_notification_hub_screen.dart';

class MockAdminRepository extends Mock implements AdminRepository {}

void main() {
  late MockAdminRepository mockAdminRepo;

  final sampleNotice1 = DepartmentNotice(
    id: 'notice_1',
    title: 'Semester Final Examination Routine - Spring 2026',
    message: 'Official semester final examination routine and hall allocation for all batches.',
    noticeType: 'SEMESTER_EXAM',
    targetAudience: 'ALL',
    attachmentUrl: 'https://cse.jnu.ac.bd/notices/exam-routine-spring-2026.pdf',
    attachmentType: 'PDF',
    priority: 'HIGH',
    syncedToPublicRoutines: true,
    sentBy: 'Department Administration',
    createdAt: '2026-03-01T10:00:00Z',
  );

  final sampleNotice2 = DepartmentNotice(
    id: 'notice_2',
    title: 'Central Master Class Routine & Laboratory Slots',
    message: 'Departmental master timetable for all theoretical & practical courses.',
    noticeType: 'CENTRAL_ROUTINE',
    targetAudience: 'STUDENTS',
    attachmentUrl: 'https://cse.jnu.ac.bd/routines/central-master-routine.jpg',
    attachmentType: 'IMAGE',
    priority: 'NORMAL',
    syncedToPublicRoutines: true,
    sentBy: 'Department Administration',
    createdAt: '2026-03-02T12:00:00Z',
  );

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  setUp(() {
    mockAdminRepo = MockAdminRepository();
  });

  group('Admin Notification & Notice Broadcast Hub Tests', () {
    testWidgets('1. Displays overview metrics and list of notices', (tester) async {
      when(() => mockAdminRepo.getAllNotices()).thenAnswer((_) async => [sampleNotice1, sampleNotice2]);

      await tester.pumpWidget(buildTestableWidget(
        AdminNotificationHubScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Notice & Alerts Hub'), findsOneWidget);
      expect(find.text('2 Total Notices'), findsOneWidget);
      expect(find.text('1 Exam Circulars'), findsOneWidget);
      expect(find.text('1 Routine Notices'), findsOneWidget);
      expect(find.text('2 Public Synced'), findsOneWidget);

      expect(find.text('Semester Final Examination Routine - Spring 2026'), findsOneWidget);
      expect(find.text('Central Master Class Routine & Laboratory Slots'), findsOneWidget);
      expect(find.text('Official PDF Notice Document'), findsOneWidget);
      expect(find.text('Notice Board Photo / Routine Scan'), findsOneWidget);
    });

    testWidgets('2. Filters notices by category tabs', (tester) async {
      when(() => mockAdminRepo.getAllNotices()).thenAnswer((_) async => [sampleNotice1, sampleNotice2]);

      await tester.pumpWidget(buildTestableWidget(
        AdminNotificationHubScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      // Tap 'Semester Exams' filter
      await tester.tap(find.text('Semester Exams'));
      await tester.pumpAndSettle();

      expect(find.text('Semester Final Examination Routine - Spring 2026'), findsOneWidget);
      expect(find.text('Central Master Class Routine & Laboratory Slots'), findsNothing);

      // Tap 'Central Routines' filter
      await tester.tap(find.text('Central Routines'));
      await tester.pumpAndSettle();

      expect(find.text('Semester Final Examination Routine - Spring 2026'), findsNothing);
      expect(find.text('Central Master Class Routine & Laboratory Slots'), findsOneWidget);
    });

    testWidgets('3. Opens Compose Notice sheet and validates required title', (tester) async {
      when(() => mockAdminRepo.getAllNotices()).thenAnswer((_) async => [sampleNotice1]);

      await tester.pumpWidget(buildTestableWidget(
        AdminNotificationHubScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      // Tap Broadcast Notice FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Broadcast Notice & Notification'), findsOneWidget);
      expect(find.text('Notice Category:'), findsOneWidget);
      expect(find.text('Notice Title:'), findsOneWidget);

      // Tap Broadcast Notice without filling title
      await tester.tap(find.widgetWithText(ElevatedButton, 'Broadcast Notice'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a notice title.'), findsOneWidget);
    });

    testWidgets('4. Successfully broadcasts notice with photo/PDF attachment and public sync', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      when(() => mockAdminRepo.getAllNotices()).thenAnswer((_) async => []);
      when(() => mockAdminRepo.sendBroadcastNotice(
            title: any(named: 'title'),
            message: any(named: 'message'),
            noticeType: any(named: 'noticeType'),
            targetAudience: any(named: 'targetAudience'),
            attachmentUrl: any(named: 'attachmentUrl'),
            attachmentType: any(named: 'attachmentType'),
            priority: any(named: 'priority'),
            syncToPublicRoutines: any(named: 'syncToPublicRoutines'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminNotificationHubScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Enter notice title
      await tester.enterText(find.byType(TextField).first, 'Semester Final Examination Routine - Spring 2026');
      await tester.pumpAndSettle();

      // Tap Broadcast Notice button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Broadcast Notice'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.sendBroadcastNotice(
            title: any(named: 'title'),
            message: any(named: 'message'),
            noticeType: any(named: 'noticeType'),
            targetAudience: any(named: 'targetAudience'),
            attachmentUrl: any(named: 'attachmentUrl'),
            attachmentType: any(named: 'attachmentType'),
            priority: any(named: 'priority'),
            syncToPublicRoutines: true,
          )).called(1);
    });

    testWidgets('5. Recalls and deletes notice with confirmation dialog', (tester) async {
      when(() => mockAdminRepo.getAllNotices()).thenAnswer((_) async => [sampleNotice1]);
      when(() => mockAdminRepo.deleteNotice('notice_1')).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        AdminNotificationHubScreen(repository: mockAdminRepo),
      ));
      await tester.pumpAndSettle();

      // Tap delete icon
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Recall Broadcast Notice?'), findsOneWidget);

      await tester.tap(find.text('Recall & Delete'));
      await tester.pumpAndSettle();

      verify(() => mockAdminRepo.deleteNotice('notice_1')).called(1);
    });
  });
}
