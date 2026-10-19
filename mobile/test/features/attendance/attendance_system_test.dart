import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/screens/student_attendance_screen.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/screens/teacher_attendance_terminal_screen.dart';

// Mocks
class MockAttendanceRepository extends Mock implements AttendanceRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockAttendanceRepository mockRepo;
  late GetAttendanceSummaryUseCase getSummaryUseCase;
  late VerifyAttendanceCodeUseCase verifyCodeUseCase;
  late StartAttendanceSessionUseCase startSessionUseCase;
  late DeactivateAttendanceSessionUseCase deactivateSessionUseCase;
  late GetActiveAttendanceSessionUseCase getActiveSessionUseCase;
  late GetSessionRosterUseCase getSessionRosterUseCase;
  late UpdateAttendanceRosterUseCase updateRosterUseCase;

  const sampleSummary = AttendanceSummary(
    overallPercentage: 85.0,
    totalAttended: 17,
    totalSessions: 20,
    courseSummaries: [
      CourseAttendance(
        courseId: 'CSE-3101',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        attendedClasses: 17,
        totalClasses: 20,
        percentage: 85.0,
        isEligible: true,
      ),
    ],
    recentRecords: [
      AttendanceRecord(
        id: 'rec_1',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        status: 'PRESENT',
        verifiedAt: '2026-10-19T10:00:00Z',
      ),
    ],
  );

  final sampleActiveSession = AttendanceSession(
    id: 'sess_os_101',
    courseId: 'CSE-3101',
    courseCode: 'CSE-3101',
    courseTitle: 'Operating Systems',
    teacherId: 'teacher_layek',
    teacherName: 'Dr. Md. Abu Layek',
    code: 'K9X2P4',
    isActive: true,
    status: 'ACTIVE',
    sessionDate: '2026-10-19',
    totalPresentCount: 1,
    createdAt: '2026-10-19T10:00:00Z',
    expiresAt: DateTime.now().add(const Duration(minutes: 15)),
  );

  const sampleRoster = SessionRoster(
    sessionId: 'sess_os_101',
    courseCode: 'CSE-3101',
    courseTitle: 'Operating Systems',
    sessionDate: '2026-10-19',
    code: 'K9X2P4',
    isActive: true,
    totalEnrolled: 3,
    totalPresent: 1,
    roster: [
      AttendanceRosterItem(
        studentId: 'stud_1',
        studentName: 'Rahim Khan',
        studentRoll: 'B200101001',
        status: 'PRESENT',
        verifiedAt: '2026-10-19T10:05:00Z',
      ),
      AttendanceRosterItem(
        studentId: 'stud_2',
        studentName: 'Karim Ahmed',
        studentRoll: 'B200101002',
        status: 'ABSENT',
      ),
      AttendanceRosterItem(
        studentId: 'stud_3',
        studentName: 'Nusrat Jahan',
        studentRoll: 'B200101003',
        status: 'ABSENT',
      ),
    ],
  );

  setUp(() {
    mockRepo = MockAttendanceRepository();
    getSummaryUseCase = GetAttendanceSummaryUseCase(mockRepo);
    verifyCodeUseCase = VerifyAttendanceCodeUseCase(mockRepo);
    startSessionUseCase = StartAttendanceSessionUseCase(mockRepo);
    deactivateSessionUseCase = DeactivateAttendanceSessionUseCase(mockRepo);
    getActiveSessionUseCase = GetActiveAttendanceSessionUseCase(mockRepo);
    getSessionRosterUseCase = GetSessionRosterUseCase(mockRepo);
    updateRosterUseCase = UpdateAttendanceRosterUseCase(mockRepo);

    when(() => mockRepo.getMySummary()).thenAnswer((_) async => sampleSummary);
    when(() => mockRepo.getActiveSession(courseId: any(named: 'courseId')))
        .thenAnswer((_) async => sampleActiveSession);
    when(() => mockRepo.getSessionRoster(sessionId: any(named: 'sessionId')))
        .thenAnswer((_) async => sampleRoster);
  });

  AttendanceController createController() {
    return AttendanceController(
      getAttendanceSummaryUseCase: getSummaryUseCase,
      verifyAttendanceCodeUseCase: verifyCodeUseCase,
      startAttendanceSessionUseCase: startSessionUseCase,
      deactivateAttendanceSessionUseCase: deactivateSessionUseCase,
      getActiveAttendanceSessionUseCase: getActiveSessionUseCase,
      getSessionRosterUseCase: getSessionRosterUseCase,
      updateAttendanceRosterUseCase: updateRosterUseCase,
    );
  }

  group('AttendanceController Unit Tests', () {
    test('fetchSummary populates state with AttendanceLoaded', () async {
      final controller = createController();
      expect(controller.state, isA<AttendanceInitial>());

      await controller.fetchSummary();

      expect(controller.state, isA<AttendanceLoaded>());
      final loadedState = controller.state as AttendanceLoaded;
      expect(loadedState.summary.overallPercentage, 85.0);
      expect(loadedState.summary.totalAttended, 17);
    });

    test('submitVerificationCode calls verifyCode and refreshes summary', () async {
      when(() => mockRepo.verifyCode('K9X2P4', courseId: any(named: 'courseId'))).thenAnswer(
        (_) async => const AttendanceVerificationResult(
          success: true,
          message: 'Attendance recorded successfully!',
          courseTitle: 'Operating Systems',
        ),
      );

      final controller = createController();
      final success = await controller.submitVerificationCode('K9X2P4');

      expect(success, true);
      verify(() => mockRepo.verifyCode('K9X2P4', courseId: any(named: 'courseId'))).called(1);
      verify(() => mockRepo.getMySummary()).called(1);
      expect(controller.state, isA<AttendanceLoaded>());
    });

    test('submitVerificationCode propagates failure on invalid/expired code', () async {
      when(() => mockRepo.verifyCode('EXPD42', courseId: any(named: 'courseId'))).thenThrow(
        Exception('This attendance session has already expired.'),
      );

      final controller = createController();
      expect(
        () async => await controller.submitVerificationCode('EXPD42'),
        throwsA(isA<Exception>()),
      );
    });

    test('startSession launches session and populates active session and roster', () async {
      when(() => mockRepo.startSession(courseId: 'CSE-3101', durationMinutes: 15))
          .thenAnswer((_) async => sampleActiveSession);

      final controller = createController();
      final session = await controller.startSession(courseId: 'CSE-3101', durationMinutes: 15);

      expect(session.code, 'K9X2P4');
      expect(controller.activeSession?.code, 'K9X2P4');
      expect(controller.editableRoster.length, 3);
      expect(controller.presentCount, 1);
      expect(controller.absentCount, 2);
    });

    test('deactivateSession terminates session and clears active session', () async {
      when(() => mockRepo.deactivateSession(sessionId: any(named: 'sessionId')))
          .thenAnswer((_) async {});

      final controller = createController();
      await controller.loadActiveSession('CSE-3101');
      expect(controller.activeSession, isNotNull);

      await controller.deactivateSession('sess_os_101');
      verify(() => mockRepo.deactivateSession(sessionId: 'sess_os_101')).called(1);
      expect(controller.activeSession, isNull);
    });

    test('manual roster overrides: mark all present, mark all absent, toggle individual, save', () async {
      when(() => mockRepo.updateRoster(
            sessionId: any(named: 'sessionId'),
            updates: any(named: 'updates'),
          )).thenAnswer((_) async {});

      final controller = createController();
      await controller.loadActiveSession('CSE-3101');
      expect(controller.editableRoster.length, 3);

      // Mark all present
      controller.markAll('PRESENT');
      expect(controller.presentCount, 3);
      expect(controller.absentCount, 0);

      // Toggle student 1 to ABSENT
      controller.toggleStudentStatus('stud_1');
      expect(controller.editableRoster.firstWhere((r) => r.studentId == 'stud_1').status, 'ABSENT');
      expect(controller.presentCount, 2);

      // Mark all absent
      controller.markAll('ABSENT');
      expect(controller.presentCount, 0);
      expect(controller.absentCount, 3);

      // Save roster
      await controller.saveRoster();
      verify(() => mockRepo.updateRoster(sessionId: 'sess_os_101', updates: any(named: 'updates'))).called(1);
    });
  });

  group('StudentAttendanceScreen Widget Tests', () {
    testWidgets('Renders verification card with input field and Verify button', (tester) async {
      final controller = createController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentAttendanceScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Attendance Terminal'), findsOneWidget);
      expect(find.text('Verify & Record Presence'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Shows orange SnackBar when code length != 6', (tester) async {
      final controller = createController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentAttendanceScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ABC4');
      await tester.tap(find.text('Verify & Record Presence'));
      await tester.pump();

      expect(find.text('Please enter the complete 6-character verification code.'), findsOneWidget);
      verifyNever(() => mockRepo.verifyCode(any(), courseId: any(named: 'courseId')));
    });

    testWidgets('Submitting 6-character code calls submitVerificationCode and displays green SnackBar on success', (tester) async {
      when(() => mockRepo.verifyCode('ABC234', courseId: any(named: 'courseId'))).thenAnswer(
        (_) async => const AttendanceVerificationResult(
          success: true,
          message: 'Attendance recorded successfully!',
          courseTitle: 'Operating Systems',
        ),
      );

      final controller = createController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentAttendanceScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ABC234');
      await tester.tap(find.text('Verify & Record Presence'));
      await tester.pumpAndSettle();

      expect(find.text('Attendance marked successfully!'), findsOneWidget);
      verify(() => mockRepo.verifyCode('ABC234', courseId: any(named: 'courseId'))).called(1);
    });

    testWidgets('Submitting invalid code displays red SnackBar with server error message', (tester) async {
      when(() => mockRepo.verifyCode('BAD123', courseId: any(named: 'courseId'))).thenThrow(
        Exception('Invalid verification code. Please check and retry.'),
      );

      final controller = createController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentAttendanceScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'BAD123');
      await tester.tap(find.text('Verify & Record Presence'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid verification code. Please check and retry.'), findsOneWidget);
    });
  });

  group('TeacherAttendanceTerminalScreen Widget Tests', () {
    testWidgets('Renders course selector, active session code, countdown timer, and roster', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = createController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeacherAttendanceTerminalScreen(
              assignedCourseIds: const ['CSE-3101'],
              preselectedCourseId: 'CSE-3101',
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check course pill
      expect(find.text('CSE-3101'), findsWidgets);

      // Check active code banner with 6-char code (rendered with spaced letters)
      expect(find.text('K 9 X 2 P 4'), findsOneWidget);
      expect(find.textContaining('SESSION ACTIVE'), findsOneWidget);
      expect(find.text('Deactivate Attendance Session'), findsOneWidget);

      // Check roster section
      expect(find.textContaining('Enrolled Student Roster'), findsOneWidget);
      expect(find.text('Rahim Khan'), findsOneWidget);
      expect(find.text('B200101001'), findsOneWidget);
      expect(find.text('Karim Ahmed'), findsOneWidget);
      expect(find.text('Nusrat Jahan'), findsOneWidget);

      // Check bulk action buttons
      expect(find.text('Mark All Present'), findsOneWidget);
      expect(find.text('Mark All Absent'), findsOneWidget);
    });

    testWidgets('Tapping Mark All Present marks all students present and displays Save Attendance bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = createController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeacherAttendanceTerminalScreen(
              assignedCourseIds: const ['CSE-3101'],
              preselectedCourseId: 'CSE-3101',
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final markAllBtn = find.text('Mark All Present');
      await tester.ensureVisible(markAllBtn);
      await tester.tap(markAllBtn);
      await tester.pumpAndSettle();

      // Sticky Save Bar should appear
      expect(find.textContaining('Save Attendance'), findsOneWidget);
    });

    testWidgets('Tapping student status chip toggles between PRESENT and ABSENT', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = createController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeacherAttendanceTerminalScreen(
              assignedCourseIds: const ['CSE-3101'],
              preselectedCourseId: 'CSE-3101',
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: Karim Ahmed is ABSENT
      expect(controller.editableRoster.firstWhere((r) => r.studentId == 'stud_2').status, 'ABSENT');

      // Tap Karim Ahmed's status chip
      final absentChips = find.widgetWithText(GestureDetector, 'ABSENT');
      expect(absentChips, findsWidgets);
      await tester.ensureVisible(absentChips.first);
      await tester.tap(absentChips.first);
      await tester.pumpAndSettle();

      // Should now be PRESENT
      expect(controller.editableRoster.firstWhere((r) => r.studentId == 'stud_2').status, 'PRESENT');
      expect(find.textContaining('Save Attendance'), findsOneWidget);
    });

    testWidgets('Tapping Deactivate triggers confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      when(() => mockRepo.deactivateSession(sessionId: any(named: 'sessionId')))
          .thenAnswer((_) async {});

      final controller = createController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeacherAttendanceTerminalScreen(
              assignedCourseIds: const ['CSE-3101'],
              preselectedCourseId: 'CSE-3101',
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deactivateBtn = find.text('Deactivate Attendance Session');
      await tester.ensureVisible(deactivateBtn);
      await tester.tap(deactivateBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Deactivate Session?'), findsOneWidget);
      expect(find.textContaining('Students will no longer be able to submit attendance'), findsOneWidget);

      // Confirm deactivation
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.deactivateSession(sessionId: 'sess_os_101')).called(1);
    });

    testWidgets('When no active session exists, displays Start Attendance Session UI', (tester) async {
      when(() => mockRepo.getActiveSession(courseId: any(named: 'courseId')))
          .thenAnswer((_) async => null);

      final controller = createController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeacherAttendanceTerminalScreen(
              assignedCourseIds: const ['CSE-3101'],
              preselectedCourseId: 'CSE-3101',
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Launch Live Attendance'), findsOneWidget);
      expect(find.text('Start Attendance Session'), findsOneWidget);
      expect(find.text('15 Minutes'), findsOneWidget);
    });
  });
}
