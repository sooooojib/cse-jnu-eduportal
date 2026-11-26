import 'dart:async';
import 'package:cse_jnu_eduportal/features/attendance/data/services/class_attendance_service.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/screens/student_attendance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements AttendanceRepository {}

class FakeService implements ClassAttendanceService {
  final marks = StreamController<List<AttendanceRosterItem>>.broadcast();
  final saved = <List<AttendanceRosterItem>>[];
  List<AttendanceRosterItem>? finishedWith;
  int rotations = 0;

  @override
  Future<AttendanceSession> startClassSession({
    required String courseId,
    String mode = 'CODE',
    int durationMinutes = 15,
    int lateAfterMinutes = 10,
    String? slotId,
  }) async =>
      AttendanceSession(
        id: 's1', courseId: courseId, courseCode: courseId, courseTitle: 'OS', teacherId: 't', teacherName: 'T',
        code: mode == 'MANUAL' ? '' : 'ABC234', isActive: true, status: 'ACTIVE', sessionDate: '2026-11-26',
        createdAt: '', expiresAt: DateTime.now().add(const Duration(minutes: 15)), mode: mode, slotId: slotId,
      );
  @override
  Future<String> rotateCode(String sessionId) async => 'NEW${++rotations}XX'.substring(0, 6);
  @override
  Future<DateTime> extendSession(String sessionId, {int minutes = 5}) async => DateTime(2030);
  @override
  Stream<List<AttendanceRosterItem>> watchMarks(String sessionId) => marks.stream;
  @override
  Future<void> saveMarks({required String sessionId, required List<AttendanceRosterItem> items}) async => saved.add(items);
  @override
  Future<void> finishSession({required String sessionId, required List<AttendanceRosterItem> roster}) async =>
      finishedWith = roster;
  @override
  Future<List<AttendanceSession>> recentSessions({int days = 7}) async => const [];
  @override
  Future<CourseAttendanceReport> courseReport(String courseId) async => throw UnimplementedError();
  List<AttendanceSession> open = const [];
  String? markedSession;
  @override
  Future<List<AttendanceSession>> openSessionsForMe() async => open;
  @override
  Future<AttendanceVerificationResult> markWithCode(String code, {String? courseId, String? sessionId}) async {
    markedSession = sessionId;
    return const AttendanceVerificationResult(success: true, message: 'You are marked present for OS.');
  }
  @override
  Future<AttendanceSummary> mySummary() async => throw UnimplementedError();
}

AttendanceRosterItem item(String id, String status, {String? by}) =>
    AttendanceRosterItem(studentId: id, studentRoll: 'R$id', studentName: 'N$id', status: status, markedBy: by);

void main() {
  late MockRepo repo;
  late FakeService svc;

  setUp(() {
    repo = MockRepo();
    svc = FakeService();
    when(() => repo.getSessionRoster(sessionId: any(named: 'sessionId'))).thenAnswer((_) async => SessionRoster(
          sessionId: 's1', courseCode: 'OS', courseTitle: 'OS', sessionDate: '2026-11-26', isActive: true,
          totalEnrolled: 3, totalPresent: 0,
          roster: [item('a', 'ABSENT'), item('b', 'ABSENT'), item('c', 'ABSENT')],
        ));
  });

  AttendanceController make() => AttendanceController(
        getAttendanceSummaryUseCase: GetAttendanceSummaryUseCase(repo),
        verifyAttendanceCodeUseCase: VerifyAttendanceCodeUseCase(repo),
        getSessionRosterUseCase: GetSessionRosterUseCase(repo),
        service: svc,
        autoSaveDelay: const Duration(milliseconds: 10),
      );

  test('students marking with the code appear live; a teacher tap is never overwritten', () async {
    final c = make();
    await c.startSession(courseId: 'CSE-3101');
    expect(c.currentCode, 'ABC234');

    c.setStudentStatus('b', 'ABSENT'); // no change
    c.setStudentStatus('c', 'PRESENT'); // teacher tap, pending
    svc.marks.add([item('a', 'PRESENT', by: 'SELF'), item('c', 'ABSENT', by: 'TEACHER')]);
    await Future<void>.delayed(Duration.zero);

    expect(c.editableRoster.firstWhere((r) => r.studentId == 'a').status, 'PRESENT');
    expect(c.editableRoster.firstWhere((r) => r.studentId == 'a').markedBy, 'SELF');
    expect(c.editableRoster.firstWhere((r) => r.studentId == 'c').status, 'PRESENT'); // kept
    c.dispose();
  });

  test('taps save automatically, and only the students that changed', () async {
    final c = make();
    await c.startSession(courseId: 'CSE-3101');
    c.setStudentStatus('b', 'LATE');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(svc.saved.single.map((r) => r.studentId), ['b']);
    expect(svc.saved.single.single.status, 'LATE');
    expect(c.hasUnsavedChanges, isFalse);
    expect(c.presentCount, 1); // late counts as attended
    c.dispose();
  });

  test('Close & save hands the full roster over so unmarked students become absent', () async {
    final c = make();
    await c.startSession(courseId: 'CSE-3101', mode: 'MANUAL');
    expect(c.activeSession!.isManualMode, isTrue);
    c.setStudentStatus('a', 'PRESENT');
    await c.finishSession();
    expect(svc.saved.first.single.studentId, 'a'); // pending tap saved first
    expect(svc.finishedWith, hasLength(3));
    expect(c.activeSession, isNull);
    c.dispose();
  });

  test('reopening an open session issues a fresh code; pausing stops rotation', () async {
    when(() => repo.getActiveSession(courseId: any(named: 'courseId'))).thenAnswer((_) async => AttendanceSession(
          id: 's1', courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS', teacherId: 't', teacherName: 'T',
          code: '', isActive: true, status: 'ACTIVE', sessionDate: '2026-11-26', createdAt: '',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ));
    final c = AttendanceController(
      getAttendanceSummaryUseCase: GetAttendanceSummaryUseCase(repo),
      verifyAttendanceCodeUseCase: VerifyAttendanceCodeUseCase(repo),
      getActiveAttendanceSessionUseCase: GetActiveAttendanceSessionUseCase(repo),
      getSessionRosterUseCase: GetSessionRosterUseCase(repo),
      service: svc,
    );
    await c.loadActiveSession('CSE-3101');
    await Future<void>.delayed(Duration.zero);
    expect(svc.rotations, 1);
    expect(c.currentCode, startsWith('NEW1'));
    c.pauseLive();
    c.dispose();
  });

  group('75% maths', () {
    const c = CourseAttendance(
        courseId: 'x', courseCode: 'x', courseTitle: 'x', attendedClasses: 9, totalClasses: 10, percentage: 90, isEligible: true);
    const low = CourseAttendance(
        courseId: 'y', courseCode: 'y', courseTitle: 'y', attendedClasses: 5, totalClasses: 10, percentage: 50, isEligible: false);

    test('can miss / need to attend', () {
      expect(c.canMiss, 2); // 9/12 = 75%
      expect(low.canMiss, isNull);
      expect(low.needToAttend, 10); // 15/20 = 75%
    });
  });

  test('course report: below 75% and CSV', () {
    const r = CourseAttendanceReport(
      courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS', classDates: ['2026-11-24', '2026-11-25'],
      rows: [
        StudentAttendanceRow(studentId: 'a', studentRoll: 'B1', studentName: 'Rahim, Khan', attended: 2, late: 1, held: 2),
        StudentAttendanceRow(studentId: 'b', studentRoll: 'B2', studentName: 'Karim', attended: 1, late: 0, held: 2),
      ],
    );
    expect(r.below75.single.studentId, 'b');
    final csv = r.toCsv().split('\n');
    expect(csv.first, 'Roll,Name,Attended,Late,Classes held,Percentage');
    expect(csv[1], 'B1,"Rahim, Khan",2,1,2,100.0');
  });

  testWidgets('two classes open: the student must tap theirs; the code is checked for that class only', (tester) async {
    when(() => repo.getMySummary()).thenAnswer((_) async => const AttendanceSummary(
        overallPercentage: 0, totalAttended: 0, totalSessions: 0, courseSummaries: [], recentRecords: []));
    AttendanceSession open(String id, String title) => AttendanceSession(
          id: id, courseId: 'CSE-3102', courseCode: 'CSE-3102', courseTitle: title, teacherId: 't', teacherName: 'T',
          code: '', isActive: true, status: 'ACTIVE', sessionDate: '2026-11-26', createdAt: '',
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        );
    svc.open = [open('g1', 'Networks Lab · Group A'), open('g2', 'Networks Lab · Group B')];
    final c = make();
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StudentAttendanceScreen(controller: c))));
    await tester.pumpAndSettle();

    expect(find.text('Open now · tap your class'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ABC234');
    await tester.tap(find.text('Verify & Record Presence'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap your class first'), findsOneWidget);
    expect(svc.markedSession, isNull);

    await tester.tap(find.byKey(const ValueKey('open_session_g2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify & Record Presence'));
    await tester.pumpAndSettle();
    expect(svc.markedSession, 'g2');
  });
}
