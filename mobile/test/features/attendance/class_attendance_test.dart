import 'dart:async';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/services/attendance_excel_exporter.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/services/class_attendance_service.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/controllers/attendance_controller.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/screens/student_attendance_screen.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/screens/teacher_attendance_terminal_screen.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/repositories/class_change_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/repositories/holiday_repository.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepo extends Mock implements AttendanceRepository {}
class MockClassChangeRepo extends Mock implements ClassChangeRepository {}
class MockHolidayRepo extends Mock implements HolidayRepository {}

class FakeService implements ClassAttendanceService {
  final marks = StreamController<List<AttendanceRosterItem>>.broadcast();
  final saved = <List<AttendanceRosterItem>>[];
  final syncedCounts = <int>[];
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
  Future<void> updateSessionPresentCount(String sessionId, int presentCount) async =>
      syncedCounts.add(presentCount);
  @override
  Future<void> finishSession({required String sessionId, required List<AttendanceRosterItem> roster}) async {
    finishedWith = roster;
    finishedIds.add(sessionId);
  }

  final finishedIds = <String>[];
  List<AttendanceSession> recent = const [];
  @override
  Future<List<AttendanceSession>> recentSessions({int days = 7}) async => recent;
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
  Future<AttendanceSummary> mySummary({int? year, int? semester}) async => throw UnimplementedError();
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
    c.setStudentStatus('b', 'PRESENT');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(svc.saved.single.map((r) => r.studentId), ['b']);
    expect(svc.saved.single.single.status, 'PRESENT');
    expect(c.hasUnsavedChanges, isFalse);
    expect(c.presentCount, 1);
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

  StudentAttendanceRow row(String id, String roll, String name, int attended, int held, Set<String> present) =>
      StudentAttendanceRow(studentId: id, studentRoll: roll, studentName: name, attended: attended, late: 0, held: held, presentDates: present);

  CourseAttendanceReport report0({List<StudentAttendanceRow>? rows, List<String>? dates}) => CourseAttendanceReport(
        courseId: 'CSE-3101',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        teacherName: 'Dr. Md. Abu Layek',
        classDates: dates ?? const ['2026-11-25', '2026-01-26'],
        year: 3,
        semester: 1,
        session: '2021-22',
        generatedOn: '2026-11-27',
        rows: rows ??
            [
              row('b', 'B220305005', 'Karim Hasan', 1, 2, {'2026-01-26'}),
              row('a', 'B220305004', 'Rahim, Uddin', 2, 2, {'2026-01-26', '2026-11-25'}),
            ],
      );

  test('course report: below 75% and CSV with details, eligibility and totals', () {
    final r = report0();
    expect(r.below75.single.studentId, 'b');
    final csv = r.toCsv().trim().split('\n');
    expect(csv[0], 'Jagannath University — Department of Computer Science & Engineering');
    expect(csv[1], 'Course: CSE-3101 - Operating Systems');
    // Quoted because of the comma in "Year 3, Semester 1" (valid CSV).
    expect(csv[2], '"Teacher: Dr. Md. Abu Layek   ·   Year 3, Semester 1   ·   Session 2021-22   ·   Classes held: 2"');
    expect(csv[3], 'Generated on 27 Nov 2026');
    expect(csv[4], 'Sl,Roll,Name,26.1.26,25.11.26,Present,Absent,%,Eligible (75%)');
    expect(csv[5], '1,B220305004,"Rahim, Uddin",P,P,2,0,100.0%,Yes');
    expect(csv[6], '2,B220305005,Karim Hasan,P,A,1,1,50.0%,No');
    expect(csv[7], 'Students: 2   ·   Class average: 75.0%   ·   Below 75%: 1');
  });

  test('no class held yet: % and eligibility show "—", not 0', () {
    final r = report0(dates: const [], rows: [row('a', 'B1', 'Rahim', 0, 0, const {})]);
    final csv = r.toCsv().trim().split('\n');
    expect(csv.firstWhere((l) => l.startsWith('1,')), '1,B1,Rahim,0,0,—,—');
    expect(csv.last, 'Students: 1   ·   Class average: —   ·   Below 75%: 0');
  });

  test('course report Excel export: clean title box, real %, shaded below-75 rows, totals', () {
    final bytes = AttendanceExcelExporter.buildBytes(report0());
    expect(bytes.length, greaterThan(500));
    final sheet = Excel.decodeBytes(bytes)['Attendance'];

    // 5 title lines and the totals line, each merged across A..I (9 columns).
    expect(sheet.spannedItems, containsAll(['A1:I1', 'A2:I2', 'A3:I3', 'A4:I4', 'A5:I5', 'A9:I9']));

    Object? val(int col, int row) => sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value;
    String text(int col, int row) => (val(col, row) as TextCellValue).value.text!;
    double numVal(int col, int row) => switch (val(col, row)) {
          IntCellValue(:final value) => value.toDouble(),
          DoubleCellValue(:final value) => value,
          final other => throw StateError('Expected numeric cell, got $other'),
        };

    expect(text(0, 0), AttendanceExcelExporter.universityName);
    expect(text(0, 1), AttendanceExcelExporter.departmentName);
    expect(text(0, 2), 'Course: CSE-3101 - Operating Systems');
    expect(text(0, 3), contains('Year 3, Semester 1'));
    expect(text(0, 3), contains('Session 2021-22'));
    expect(text(0, 4), 'Generated on 27 Nov 2026');

    // Header right under the title box (no empty spacer row).
    expect([for (var c = 0; c < 9; c++) text(c, 5)],
        ['Sl', 'Roll', 'Name', '26.1.26', '25.11.26', 'Present', 'Absent', '%', 'Eligible']);

    // Row 7 (index 6): B220305004, 100 %, eligible.
    expect(text(1, 6), 'B220305004');
    expect([text(3, 6), text(4, 6)], ['P', 'P']);
    expect(numVal(7, 6), 1.0); // stored as a fraction, shown as 100.0%
    expect(text(8, 6), 'Yes');

    // Row 8 (index 7): B220305005, 50 %, not eligible, shaded.
    expect(text(1, 7), 'B220305005');
    expect(numVal(7, 7), 0.5);
    expect(text(8, 7), 'No');
    final shadedFill = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 7)).cellStyle!.backgroundColor.colorHex;
    final plainFill = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 6)).cellStyle!.backgroundColor.colorHex;
    expect(shadedFill, isNot(plainFill));

    expect(text(0, 8), 'Students: 2   ·   Class average: 75.0%   ·   Below 75%: 1');
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

  test('live student self-marks sync totalPresentCount to the session', () async {
    final c = make();
    await c.startSession(courseId: 'CSE-3101');
    svc.marks.add([item('a', 'PRESENT', by: 'SELF'), item('b', 'PRESENT', by: 'SELF')]);
    await Future<void>.delayed(Duration.zero);
    expect(svc.syncedCounts, [2]);
    c.dispose();
  });

  testWidgets('starting attendance with no scheduled class today prompts confirmation', (tester) async {
    final ccRepo = MockClassChangeRepo();
    final hRepo = MockHolidayRepo();
    when(() => ccRepo.routineForDay(any())).thenAnswer((_) async => const []);
    when(() => ccRepo.changesOn(any())).thenAnswer((_) async => const []);
    when(() => hRepo.holidayMap()).thenAnswer((_) async => const {});
    await sl.reset();
    sl.registerSingleton<ClassChangeRepository>(ccRepo);
    sl.registerSingleton<HolidayRepository>(hRepo);
    addTearDown(() => sl.reset());

    when(() => repo.getActiveSession(courseId: any(named: 'courseId')))
        .thenAnswer((_) async => null);

    final c = make();
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: TeacherAttendanceTerminalScreen(
          controller: c,
          assignedCourseIds: const ['CSE-3101'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('attendance_start')));
    await tester.pumpAndSettle();

    expect(find.text('No class scheduled today'), findsOneWidget);
    expect(c.activeSession, isNull);

    await tester.tap(find.text('Start Anyway'));
    await tester.pumpAndSettle();
    expect(c.activeSession, isNotNull);
    c.dispose();
  });

  test('an old session with no end time (demo / legacy data) is never treated as open', () async {
    when(() => repo.getActiveSession(courseId: any(named: 'courseId'))).thenAnswer((_) async => const AttendanceSession(
          id: 'legacy', courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS', teacherId: 'someone_else',
          teacherName: 'T', code: '849201', isActive: true, status: 'ACTIVE', sessionDate: '2026-10-26', createdAt: '',
        ));
    final c = AttendanceController(
      getAttendanceSummaryUseCase: GetAttendanceSummaryUseCase(repo),
      verifyAttendanceCodeUseCase: VerifyAttendanceCodeUseCase(repo),
      getActiveAttendanceSessionUseCase: GetActiveAttendanceSessionUseCase(repo),
      getSessionRosterUseCase: GetSessionRosterUseCase(repo),
      service: svc,
    );
    expect(await c.findOpenSession('CSE-3101'), isNull);
    await c.loadActiveSession('CSE-3101');
    expect(c.activeSession, isNull);
    expect(svc.rotations, 0); // never tries to rotate someone else's code
    c.dispose();
  });

  group('S2-09: sessions left open are closed', () {
    final now = DateTime(2026, 11, 27, 12);
    AttendanceSession sess(String id, {required bool active, String date = '2026-11-27', DateTime? expires}) => AttendanceSession(
          id: id, courseId: 'C', courseCode: 'C', courseTitle: 'OS', teacherId: 't', teacherName: 'T', code: '',
          isActive: active, status: active ? 'ACTIVE' : 'COMPLETED', sessionDate: date, createdAt: '', expiresAt: expires,
        );

    test('closes expired (15+ min) and earlier-day open sessions, with the full class list', () async {
      svc.recent = [
        sess('expiredLongAgo', active: true, expires: now.subtract(const Duration(minutes: 40))),
        sess('yesterday', active: true, date: '2026-11-26', expires: now.add(const Duration(hours: 1))),
        sess('justExpired', active: true, expires: now.subtract(const Duration(minutes: 5))), // can still Extend
        sess('running', active: true, expires: now.add(const Duration(minutes: 10))),
        sess('done', active: false, expires: now.subtract(const Duration(hours: 2))),
      ];
      final c = make();
      final closed = await c.closeStaleSessions(now: now);
      expect(closed, 2);
      expect(svc.finishedIds, ['expiredLongAgo', 'yesterday']);
      expect(svc.finishedWith, hasLength(3)); // unmarked students become absent
      c.dispose();
    });

    test('the class on screen is never auto-closed', () async {
      final c = make();
      await c.startSession(courseId: 'CSE-3101');
      final onScreen = sess(c.activeSession!.id, active: true, expires: now.subtract(const Duration(hours: 1)));
      expect(c.isStale(onScreen, now: now), isFalse);
      c.dispose();
    });
  });
}
