import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/utils/refresh_on_reopen.dart';
import 'package:cse_jnu_eduportal/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/services/teacher_monitoring_calculator.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/models/attendance_models.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/services/class_attendance_service.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/services/class_keys.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';

class _Auth extends Mock implements fb.FirebaseAuth {}

class _User extends Mock implements fb.User {}

class _Functions extends Mock implements FirebaseFunctions {}

/// S2-13: double periods, rejection notices, refresh on reopen.
void main() {
  group('class keys', () {
    test('two slots on one day are two classes; a plain session joins them', () {
      expect(ClassKeys.normalize({'2026-11-03#a', '2026-11-03#b', '2026-11-03', '2026-11-04'}),
          {'2026-11-03#a', '2026-11-03#b', '2026-11-04'});
    });

    test('an old mark with only the day counts for one class that day', () {
      final (went, extra) = ClassKeys.match({'2026-11-03#a', '2026-11-03#b'}, {'2026-11-03', '2026-11-05'});
      expect(went, {'2026-11-03#a'});
      expect(extra, {'2026-11-05'});
    });

    test('column labels number a day that had two classes', () {
      expect(ClassKeys.labels(['2026-11-03#a', '2026-11-03#b', '2026-11-04'], (d) => d.substring(8)), ['03 (1)', '03 (2)', '04']);
    });
  });

  group('double period counted on every screen', () {
    late FakeFirebaseFirestore db;
    setUp(() async {
      db = FakeFirebaseFirestore();
      await db.doc('users/stu').set({'role': 'STUDENT', 'year': 3, 'semester': 1, 'fullName': 'S', 'studentId': '01'});
      await db.doc('courses/C1').set({'code': 'CSE-3101', 'title': 'OS', 'year': 3, 'semester': 1, 'teacherId': 't'});
      // Monday double period: slot A and slot B, the student came to A only.
      for (final (id, slot, present) in [('s1', 'A', 3), ('s2', 'B', 2)]) {
        await db.doc('attendanceSessions/$id').set({
          'courseId': 'C1', 'courseCode': 'CSE-3101', 'courseTitle': 'OS', 'teacherId': 't', 'sessionDate': '2026-11-02',
          'slotId': slot, 'totalPresentCount': present, 'targetYear': 3, 'targetSemester': 1,
        });
      }
      await db.doc('attendance/s1_stu').set({'sessionId': 's1', 'studentId': 'stu', 'courseId': 'C1', 'status': 'PRESENT', 'date': '2026-11-02', 'slotId': 'A'});
      await db.doc('attendance/s2_stu').set({'sessionId': 's2', 'studentId': 'stu', 'courseId': 'C1', 'status': 'ABSENT', 'date': '2026-11-02', 'slotId': 'B'});
    });

    ClassAttendanceServiceImpl as(String uid) {
      final auth = _Auth();
      final user = _User();
      when(() => user.uid).thenReturn(uid);
      when(() => auth.currentUser).thenReturn(user);
      return ClassAttendanceServiceImpl(firestore: db, auth: auth);
    }

    test('student summary, course report and Monitoring all see 2 classes', () async {
      final os = (await as('stu').mySummary()).courseSummaries.single;
      expect((os.attendedClasses, os.totalClasses), (1, 2));

      final report = await as('t').courseReport('C1');
      expect(report.classDates, hasLength(2));
      expect(report.rows.single.attended, 1);
      expect(report.toCsv(), contains('2.11.26 (1)'));

      final sessions = (await db.collection('attendanceSessions').get()).docs.map(AttendanceSessionModel.fromFirestore).toList();
      final m = TeacherMonitoringCalculator.build(
        users: const [User(id: 't', email: 't@x', fullName: 'T', role: UserRole.teacher)],
        courses: const [Course(id: 'C1', code: 'CSE-3101', title: 'OS', credit: 3, year: 3, semester: 1, courseType: 'THEORY', teacherId: 't')],
        assignments: const [],
        sessions: sessions,
        routineSlots: const [],
        now: DateTime(2026, 11, 5),
      );
      expect(m.teachers.single.courses.single.classesConducted, 2);
    });
  });

  test('rejecting a semester request notifies the student', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('semesterUpgradeRequests/r1').set({'studentId': 'stu', 'status': 'PENDING', 'requestedYear': 3, 'requestedSemester': 2});
    await AdminRemoteDataSourceImpl(firestore: db, functions: _Functions()).rejectSemesterUpgrade(requestId: 'r1', reason: 'Results not published yet');
    final notes = (await db.collection('notifications').get()).docs.map((d) => d.data()).toList();
    expect(notes.single['userId'], 'stu');
    expect(notes.single['body'], 'Results not published yet');
    expect(notes.single['referenceType'], 'SEMESTER_REQUEST');
  });

  testWidgets('a reopened screen reloads, but not right after its own load', (tester) async {
    var loads = 0;
    // Just loaded (default 60 s gap): a ping is ignored.
    await tester.pumpWidget(MaterialApp(home: _Probe(gap: const Duration(seconds: 60), onLoad: () => loads++)));
    RefreshBus.ping();
    await tester.pump();
    expect(loads, 0);
    // Data older than the gap: a ping reloads.
    await tester.pumpWidget(MaterialApp(home: _Probe(key: const ValueKey('old'), gap: Duration.zero, onLoad: () => loads++)));
    RefreshBus.ping();
    await tester.pump();
    expect(loads, 1);
  });
}

class _Probe extends StatefulWidget {
  final VoidCallback onLoad;
  final Duration gap;
  const _Probe({super.key, required this.onLoad, required this.gap});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with RefreshOnReopen {
  @override
  Duration get minGap => widget.gap;
  @override
  void onReopened() => widget.onLoad();
  @override
  Widget build(BuildContext context) => const SizedBox();
}
