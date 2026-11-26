import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/utils/academic_session.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/services/teacher_monitoring_calculator.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/utils/request_ordering.dart';
import 'package:cse_jnu_eduportal/features/admin/presentation/widgets/signup_approval_dialog.dart';
import 'package:cse_jnu_eduportal/features/profile/domain/entities/semester_status.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/signup_request_model.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/user_model.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/signup_request.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/models/curriculum_models.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/class_change.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/dashboard/presentation/widgets/dashboard_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

User _user(String id, UserRole role, {int? year, int? semester, bool active = true, String name = ''}) =>
    User(
      id: id,
      email: '$id@jnu.ac.bd',
      fullName: name.isEmpty ? id : name,
      role: role,
      year: year,
      semester: semester,
      isActive: active,
    );

AttendanceSession _session(String id, String teacherId, String courseId, String date, int present) =>
    AttendanceSession(
      id: id,
      courseId: courseId,
      courseCode: courseId,
      courseTitle: '',
      teacherId: teacherId,
      teacherName: '',
      code: 'ABC123',
      isActive: false,
      status: 'COMPLETED',
      sessionDate: date,
      totalPresentCount: present,
      createdAt: '${date}T09:00:00Z',
    );

ScheduleSlot _slot(String id, String teacherId, String courseId, String day, {bool extra = false, String? date}) =>
    ScheduleSlot(
      id: id,
      courseId: courseId,
      courseCode: courseId,
      courseTitle: '',
      teacherId: teacherId,
      teacherName: '',
      dayOfWeek: day,
      startTime: '09:00',
      endTime: '10:00',
      room: '301',
      targetYear: 3,
      targetSemester: 1,
      isExtraClass: extra,
      date: date,
    );

void main() {
  group('UserRole.chairman', () {
    test('parses CHAIRMAN and keeps unknown roles as student', () {
      expect(UserRole.fromString('CHAIRMAN'), UserRole.chairman);
      expect(UserRole.fromString('chairman'), UserRole.chairman);
      expect(UserRole.fromString('FACULTY'), UserRole.teacher);
      expect(UserRole.fromString('SOMETHING'), UserRole.student);
    });

    test('chairman has both teacher and admin access', () {
      expect(UserRole.chairman.hasTeacherAccess, isTrue);
      expect(UserRole.chairman.hasAdminAccess, isTrue);
      expect(UserRole.teacher.hasAdminAccess, isFalse);
      expect(UserRole.admin.hasTeacherAccess, isFalse);
      expect(UserRole.cr.isStudentSide, isTrue);
      expect(UserRole.chairman.isStudentSide, isFalse);
    });

    test('dashboard switcher availability', () {
      expect(_user('c', UserRole.chairman).canSwitchToAdminView, isTrue);
      expect(_user('t', UserRole.teacher).canSwitchToAdminView, isFalse);
      expect(_user('t', UserRole.teacher).copyWith(isAdminDelegate: true).canSwitchToAdminView, isTrue);
      expect(_user('a', UserRole.admin).copyWith(isAdminDelegate: true).canSwitchToAdminView, isFalse);
    });

    test('user and signup models round-trip session and delegation', () {
      final user = UserModel.fromJson({
        'id': 'u1',
        'email': 'a@b.c',
        'fullName': 'Sadia',
        'role': 'STUDENT',
        'session': '2021-2022',
        'isAdminDelegate': false,
      });
      expect(user.session, '2021-2022');
      expect(user.toJson()['session'], '2021-2022');

      final teacher = UserModel.fromJson({'id': 't', 'role': 'TEACHER', 'isAdminDelegate': true});
      expect(teacher.isAdminDelegate, isTrue);

      final req = SignupRequestModel.fromJson({'id': 'r', 'role': 'CR', 'session': '2022-2023'});
      expect(req.session, '2022-2023');
      expect(req.toJson()['session'], '2022-2023');
    });
  });

  group('AcademicSession', () {
    test('validates consecutive-year sessions', () {
      expect(AcademicSession.isValid('2021-2022'), isTrue);
      expect(AcademicSession.isValid('2021-2023'), isFalse);
      expect(AcademicSession.isValid('2021/2022'), isFalse);
      expect(AcademicSession.isValid(null), isFalse);
    });

    test('lists recent sessions newest first', () {
      final list = AcademicSession.availableSessions(now: DateTime(2026, 11, 25), count: 3);
      expect(list, ['2025-2026', '2024-2025', '2023-2024']);
    });
  });

  group('Course target class count', () {
    Course course({double credit = 3.0, String type = 'THEORY', int? target}) => Course(
          id: 'c',
          code: 'CSE-1',
          title: 't',
          credit: credit,
          year: 1,
          semester: 1,
          courseType: type,
          targetClassCount: target,
        );

    test('uses only the configured target, never a credit-based default', () {
      expect(course().targetClasses, isNull);
      expect(course(credit: 1.5, type: 'LAB').targetClasses, isNull);
      expect(course(target: 0).targetClasses, isNull);
      expect(course(target: 24).targetClasses, 24);
      expect(course(credit: 1.5, type: 'LAB', target: 12).targetClasses, 12);
    });

    test('course model persists targetClassCount', () {
      final m = CourseModel.fromJson({'id': 'x', 'code': 'X', 'credit': 3, 'targetClassCount': 28});
      expect(m.targetClassCount, 28);
      expect(m.toJson()['targetClassCount'], 28);
    });
  });

  group('TeacherMonitoringCalculator', () {
    final users = [
      _user('t1', UserRole.teacher, name: 'Dr. Anisur Rahman'),
      _user('c1', UserRole.chairman, name: 'Prof. Abu Bakar'),
      _user('t2', UserRole.teacher, name: 'Ms. New Faculty'),
      _user('s1', UserRole.student, year: 3, semester: 1),
      _user('s2', UserRole.student, year: 3, semester: 1),
      _user('s3', UserRole.student, year: 3, semester: 1),
      _user('cr1', UserRole.cr, year: 3, semester: 1),
      _user('s4', UserRole.student, year: 3, semester: 1, active: false),
    ];
    const courses = [
      Course(id: 'CSE-3101', code: 'CSE-3101', title: 'Operating Systems', credit: 3.0, year: 3, semester: 1, courseType: 'THEORY', teacherId: 't1'),
      Course(id: 'CSE-3102', code: 'CSE-3102', title: 'OS Lab', credit: 1.5, year: 3, semester: 1, courseType: 'LAB'),
      Course(id: 'CSE-4101', code: 'CSE-4101', title: 'Distributed Systems', credit: 3.0, year: 4, semester: 1, courseType: 'THEORY', teacherId: 'c1', targetClassCount: 20),
    ];
    const assignments = [
      CourseAssignment(id: 'a1', courseId: 'CSE-3102', courseCode: 'CSE-3102', courseTitle: 'OS Lab', teacherId: 't1', teacherName: 'Dr. Anisur Rahman'),
    ];
    final sessions = [
      _session('x0', 't1', 'CSE-3101', '2026-10-20', 4), // before period
      _session('x1', 't1', 'CSE-3101', '2026-11-02', 3),
      _session('x2', 't1', 'CSE-3101', '2026-11-02', 1), // same-day re-launch
      _session('x3', 't1', 'CSE-3101', '2026-11-09T08:00:00.000', 2), // ISO date
      _session('x4', 't1', 'CSE-3101', '2026-11-30', 4), // future: ignored
      _session('x5', 'c1', 'CSE-4101', '2026-11-10', 0),
    ];
    final slots = [
      _slot('r1', 't1', 'CSE-3101', 'SUNDAY'),
      _slot('r2', 't1', 'CSE-3101', 'TUESDAY'),
      _slot('r3', 't1', 'CSE-3101', 'THURSDAY', extra: true, date: '2026-11-05'), // one-off: ignored
    ];
    final now = DateTime(2026, 11, 25); // Wednesday

    test('merges same-day sessions, respects period, and estimates missed classes', () {
      final report = TeacherMonitoringCalculator.build(
        users: users,
        courses: courses,
        assignments: assignments,
        sessions: sessions,
        routineSlots: slots,
        periodStart: DateTime(2026, 11, 1), // Sunday
        now: now,
      );

      final t1 = report.teachers.firstWhere((t) => t.teacherId == 't1');
      expect(t1.teacherName, 'Dr. Anisur Rahman');
      expect(t1.courses.map((c) => c.courseCode), ['CSE-3101', 'CSE-3102']);

      final os = t1.courses.first;
      expect(os.classesConducted, 2);
      expect(os.sessionCount, 3);
      expect(os.targetClasses, isNull); // no target configured
      expect(os.progress, isNull);
      expect(os.cohortSize, 4); // inactive student excluded, CR included
      expect(os.averagePresent, 2.5); // max(3,1)=3 and 2
      expect(os.averageTurnout, closeTo(0.625, 1e-9));
      expect(os.weeklyRoutineSlots, 2);
      expect(os.expectedClassesSoFar, 8); // 4 Sundays + 4 Tuesdays in Nov 1-25
      expect(os.missedClassesEstimate, 6);
      expect(os.lastClassDate, '2026-11-09');
      expect(os.history.first.date, '2026-11-09');
      expect(os.history.last.sessionCount, 2);

      final lab = t1.courses[1];
      expect(lab.isLab, isTrue);
      expect(lab.targetClasses, isNull);
      expect(lab.classesConducted, 0);
      expect(lab.expectedClassesSoFar, isNull); // no routine slots
      expect(lab.averageTurnout, isNull);

      final chairman = report.teachers.firstWhere((t) => t.teacherId == 'c1');
      expect(chairman.role, 'CHAIRMAN');
      expect(chairman.courses.single.classesConducted, 1);
      expect(chairman.courses.single.targetClasses, 20);
      expect(chairman.courses.single.progress, closeTo(0.05, 1e-9));

      final newcomer = report.teachers.firstWhere((t) => t.teacherId == 't2');
      expect(newcomer.courses, isEmpty);

      expect(report.teachers.map((t) => t.teacherId), isNot(contains('s1')));
    });

    test('cancelled classes are not counted as missed; extra classes are expected', () {
      ClassChange ch(String id, ClassChangeType t, String date) => ClassChange(
            id: id, type: t, date: date, dayOfWeek: 'SUNDAY', courseId: 'CSE-3101', courseCode: 'CSE-3101',
            courseTitle: 'OS', teacherId: 't1', teacherName: 'T', targetYear: 3, targetSemester: 1,
            startTime: '09:00 AM', endTime: '10:30 AM', room: 'R', originalSlotId: 'r1',
            createdBy: 'cr', createdByName: 'CR', createdByRole: 'CR',
          );
      final report = TeacherMonitoringCalculator.build(
        users: users,
        courses: courses,
        assignments: assignments,
        sessions: sessions,
        routineSlots: slots,
        classChanges: [
          ch('c1', ClassChangeType.cancel, '2026-11-08'),
          ch('c2', ClassChangeType.cancel, '2026-11-15'),
          ch('e1', ClassChangeType.extra, '2026-11-20'),
          ch('late', ClassChangeType.cancel, '2026-11-30'), // after today: ignored
        ],
        periodStart: DateTime(2026, 11, 1),
        now: now,
      );
      final os = report.teachers.firstWhere((t) => t.teacherId == 't1').courses.first;
      expect(os.expectedClassesSoFar, 8 - 2 + 1);
      expect(os.missedClassesEstimate, 7 - 2);
    });

    test('not-taken reports stay expected, are counted, and appear in the class log', () {
      ClassChange ch(String id, ClassChangeType t, String date) => ClassChange(
            id: id, type: t, date: date, dayOfWeek: 'SUNDAY', courseId: 'CSE-3101', courseCode: 'CSE-3101',
            courseTitle: 'OS', teacherId: 't1', teacherName: 'T', targetYear: 3, targetSemester: 1,
            startTime: '09:00 AM', endTime: '10:30 AM', room: 'R', originalSlotId: 'r1',
            reason: 'Teacher did not come', createdBy: 'cr', createdByName: 'CR', createdByRole: 'CR',
          );
      final report = TeacherMonitoringCalculator.build(
        users: users,
        courses: courses,
        assignments: assignments,
        sessions: sessions,
        routineSlots: slots,
        classChanges: [
          ch('n1', ClassChangeType.notTaken, '2026-11-22'),
          ch('n2', ClassChangeType.notTaken, '2026-11-09'),
          ch('c1', ClassChangeType.cancel, '2026-11-15'),
          ch('old', ClassChangeType.notTaken, '2026-10-20'), // before the period: ignored
        ],
        periodStart: DateTime(2026, 11, 1),
        now: now,
      );
      final t1 = report.teachers.firstWhere((t) => t.teacherId == 't1');
      final os = t1.courses.first;
      expect(os.notTakenCount, 2);
      expect(os.cancelledCount, 1);
      expect(t1.totalNotTaken, 2);
      expect(os.expectedClassesSoFar, 8 - 1); // only the cancellation reduces it
      expect(os.changes.map((c) => c.id), ['n1', 'c1', 'n2']); // newest first
    });

    test('without a period start counts all past classes and gives no missed estimate', () {
      final report = TeacherMonitoringCalculator.build(
        users: users,
        courses: courses,
        assignments: assignments,
        sessions: sessions,
        routineSlots: slots,
        now: now,
      );
      final os = report.teachers.firstWhere((t) => t.teacherId == 't1').courses.first;
      expect(os.classesConducted, 3);
      expect(os.expectedClassesSoFar, isNull);
      expect(os.missedClassesEstimate, isNull);
      expect(report.periodStart, isNull);
    });
  });

  group('Dashboard mode selector', () {
    testWidgets('renders both segments and reports a mode change', (tester) async {
      DashboardMode? changed;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DashboardModeSelector(
            currentMode: DashboardMode.faculty,
            adminLabel: 'Department Admin',
            onModeChanged: (m) => changed = m,
          ),
        ),
      ));

      expect(find.text('Faculty View'), findsOneWidget);
      expect(find.text('Department Admin'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('dashboard_mode_admin')));
      await tester.pumpAndSettle();
      expect(changed, DashboardMode.admin);

      changed = null;
      await tester.tap(find.byKey(const ValueKey('dashboard_mode_faculty')));
      await tester.pumpAndSettle();
      expect(changed, isNull, reason: 'tapping the active segment is a no-op');
    });
  });

  group('Signup approval dialog', () {
    /// Pumps a button that opens the dialog; the decision lands in [out].
    Future<void> openDialog(WidgetTester tester, SignupRequest req, List<SignupApprovalDecision?> out) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => out.add(await SignupApprovalDialog.show(context, req)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the signup session read-only and requires the approver to pick the semester', (tester) async {
      const req = SignupRequest(
        id: 'r1',
        email: 'sadia@example.com',
        fullName: 'Sadia Islam',
        role: UserRole.student,
        studentId: 'B210305042',
        session: '2021-2022',
        status: 'PENDING',
        createdAt: '2024-03-01',
      );
      final out = <SignupApprovalDecision?>[];
      await openDialog(tester, req, out);

      // Session is displayed as text, not as an editable dropdown.
      expect(find.text('Session: 2021-2022'), findsOneWidget);
      expect(find.byKey(const ValueKey('approval_session_dropdown')), findsNothing);
      expect(find.byKey(const ValueKey('approval_year_dropdown')), findsNothing);

      // Approve is disabled until a semester is picked; nothing is pre-selected.
      final approve = find.widgetWithText(ElevatedButton, 'Approve & Provision');
      expect(tester.widget<ElevatedButton>(approve).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('approval_semester_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year 3 · Semester 2').last);
      await tester.pumpAndSettle();

      await tester.tap(approve);
      await tester.pumpAndSettle();
      final result = out.single;
      expect(result, isNotNull);
      expect(result!.year, 3);
      expect(result.semester, 2);
    });

    testWidgets('faculty requests need no semester', (tester) async {
      const req = SignupRequest(
        id: 'r2',
        email: 't@jnu.ac.bd',
        fullName: 'Dr. Teacher',
        role: UserRole.teacher,
        status: 'PENDING',
        createdAt: '2024-03-01',
      );
      await openDialog(tester, req, []);
      expect(find.text('Approve Faculty Signup?'), findsOneWidget);
      expect(find.byKey(const ValueKey('approval_semester_dropdown')), findsNothing);
    });
  });

  group('RequestOrdering', () {
    SignupRequest signup(String id, String? session, String createdAt, {UserRole role = UserRole.student}) =>
        SignupRequest(
          id: id,
          email: '$id@x.bd',
          fullName: id,
          role: role,
          session: session,
          status: 'PENDING',
          createdAt: createdAt,
        );

    SemesterUpgradeRequest promo(String id, int y, int s, String createdAt) => SemesterUpgradeRequest(
          id: id,
          studentId: id,
          studentName: id,
          studentRoll: id,
          currentYear: y,
          currentSemester: s,
          requestedYear: y,
          requestedSemester: s,
          status: 'PENDING',
          createdAt: createdAt,
        );

    test('signups: oldest session first, then students without session, then teachers', () {
      final sorted = RequestOrdering.sortSignupsBySession([
        signup('a', '2023-2024', '2026-11-01'),
        signup('t', null, '2026-11-05', role: UserRole.teacher),
        signup('n', null, '2026-11-04'),
        signup('b', '2021-2022', '2026-11-02'),
        signup('c', '2021-2022', '2026-11-03'),
        signup('d', '2019-2020', '2026-10-01'),
      ]);
      expect(sorted.map((r) => r.id), ['d', 'c', 'b', 'a', 'n', 't']);
    });

    test('signups: dropdown groups, labels and filtering', () {
      final list = [
        signup('a', '2023-2024', '1'),
        signup('b', '2021-2022', '2'),
        signup('n', null, '3'),
        signup('t', null, '4', role: UserRole.teacher),
      ];
      expect(RequestOrdering.signupGroupsIn(list), [
        '2021-2022',
        '2023-2024',
        RequestOrdering.noSessionGroup,
        RequestOrdering.teacherGroup,
      ]);
      expect(RequestOrdering.signupGroupLabel('2022-2023'), 'Session 2022-23');
      expect(RequestOrdering.signupGroupLabel(RequestOrdering.teacherGroup), 'Teachers');
      expect(list.where((r) => RequestOrdering.signupInGroup(r, '2021-2022')).map((r) => r.id), ['b']);
      expect(list.where((r) => RequestOrdering.signupInGroup(r, RequestOrdering.teacherGroup)).map((r) => r.id), ['t']);
      expect(list.where((r) => RequestOrdering.signupInGroup(r, RequestOrdering.noSessionGroup)).map((r) => r.id), ['n']);
      expect(list.where((r) => RequestOrdering.signupInGroup(r, null)).length, 4);
    });

    test('semester requests: ordered by requested level 1.1 ... 4.2, oldest first within a level', () {
      final sorted = RequestOrdering.sortSemesterRequestsByTarget([
        promo('x', 3, 1, '2026-11-02'),
        promo('y', 1, 2, '2026-11-05'),
        promo('z', 3, 1, '2026-11-01'),
        promo('w', 2, 1, '2026-11-03'),
      ]);
      expect(sorted.map((r) => r.id), ['y', 'w', 'z', 'x']);
    });

    test('directory level filter matches "year.semester"', () {
      final u = _user('s', UserRole.student, year: 3, semester: 1);
      expect(RequestOrdering.userMatchesLevel(u, '3.1'), isTrue);
      expect(RequestOrdering.userMatchesLevel(u, '3.2'), isFalse);
      expect(RequestOrdering.userMatchesLevel(u, null), isTrue);
      expect(RequestOrdering.userMatchesLevel(_user('n', UserRole.student), '1.1'), isFalse);
    });
  });
}
