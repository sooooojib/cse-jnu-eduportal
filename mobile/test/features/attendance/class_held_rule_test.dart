import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/features/admin/domain/services/teacher_monitoring_calculator.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/models/attendance_models.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/services/class_attendance_service.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';

class _Auth extends Mock implements fb.FirebaseAuth {}

class _User extends Mock implements fb.User {}

/// S2-03 "done when": the teacher's app was killed mid-session. Student,
/// course report and Monitoring must all agree on which days were held.
void main() {
  late FakeFirebaseFirestore db;
  late ClassAttendanceServiceImpl service;

  Map<String, dynamic> session(String date, int present) => {
        'courseId': 'C1', 'courseCode': 'CSE-3101', 'courseTitle': 'OS', 'teacherId': 't1', 'mode': 'CODE',
        'isActive': false, 'status': 'ACTIVE', 'sessionDate': date, 'targetYear': 3, 'targetSemester': 1,
        'totalPresentCount': present, 'createdAt': '${date}T10:00:00',
      };
  Map<String, dynamic> record(String sid, String date, String status) => {
        'id': '${sid}_stu', 'sessionId': sid, 'studentId': 'stu', 'studentName': 'S', 'studentRoll': '1',
        'courseId': 'C1', 'courseCode': 'CSE-3101', 'courseTitle': 'OS', 'status': status, 'date': date,
      };

  setUp(() async {
    db = FakeFirebaseFirestore();
    final auth = _Auth();
    final user = _User();
    when(() => user.uid).thenReturn('stu');
    when(() => auth.currentUser).thenReturn(user);
    service = ClassAttendanceServiceImpl(firestore: db, auth: auth);

    await db.collection('users').doc('stu').set({'role': 'STUDENT', 'year': 3, 'semester': 1, 'fullName': 'S'});
    await db.collection('courses').doc('C1').set({'code': 'CSE-3101', 'title': 'OS', 'year': 3, 'semester': 1, 'teacherId': 't1'});
    // Nov 20: the teacher's app died; the student's own mark raised the count to 1.
    await db.collection('attendanceSessions').doc('s1').set(session('2026-11-20', 1));
    await db.collection('attendance').doc('s1_stu').set(record('s1', '2026-11-20', 'PRESENT'));
    // Nov 21: nobody came; the teacher marked everyone absent. Not a class.
    await db.collection('attendanceSessions').doc('s2').set(session('2026-11-21', 0));
    await db.collection('attendance').doc('s2_stu').set(record('s2', '2026-11-21', 'ABSENT'));
  });

  test('student summary, course report and Monitoring agree', () async {
    final summary = await service.mySummary();
    final os = summary.courseSummaries.single;
    expect(os.totalClasses, 1);
    expect(os.attendedClasses, 1);
    expect(os.absentDates, isEmpty); // the empty Nov 21 session is not a missed class

    final report = await service.courseReport('C1');
    expect(report.classDates, ['2026-11-20']);

    final sessions = (await db.collection('attendanceSessions').get()).docs.map(AttendanceSessionModel.fromFirestore).toList();
    final monitoring = TeacherMonitoringCalculator.build(
      users: const [User(id: 't1', email: 't@x.com', fullName: 'T', role: UserRole.teacher)],
      courses: const [Course(id: 'C1', code: 'CSE-3101', title: 'OS', credit: 3, year: 3, semester: 1, courseType: 'THEORY', teacherId: 't1')],
      assignments: const <CourseAssignment>[],
      sessions: sessions,
      routineSlots: const [],
      now: DateTime(2026, 11, 25),
    );
    final c = monitoring.teachers.single.courses.single;
    expect(c.classesConducted, 1);
    expect(c.history.map((h) => h.date), ['2026-11-20']);
  });
}
