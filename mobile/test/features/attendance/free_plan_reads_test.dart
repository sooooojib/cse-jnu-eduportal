import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/core/utils/class_time.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/services/class_attendance_service.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';

class _Auth extends Mock implements fb.FirebaseAuth {}

class _User extends Mock implements fb.User {}

/// S2-11 (free plan): the summary comes from small records, not from every
/// session and mark; writers keep those records in step.
void main() {
  late FakeFirebaseFirestore db;

  ClassAttendanceServiceImpl as(String uid) {
    final auth = _Auth();
    final user = _User();
    when(() => user.uid).thenReturn(uid);
    when(() => auth.currentUser).thenReturn(user);
    return ClassAttendanceServiceImpl(firestore: db, auth: auth);
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('users/stu').set({'role': 'STUDENT', 'year': 3, 'semester': 1, 'fullName': 'S', 'studentId': '01'});
    await db.doc('users/t').set({'role': 'TEACHER', 'assignedCourseIds': ['C1']});
    await db.doc('courses/C1').set({'code': 'CSE-3101', 'title': 'OS', 'year': 3, 'semester': 1, 'teacherId': 't'});
    await db.doc('courses/C2').set({'code': 'CSE-3102', 'title': 'DB', 'year': 3, 'semester': 1, 'teacherId': 't2'});
  });

  test('with summary records, sessions and marks are not scanned', () async {
    // 500 sessions that would give a very different answer if they were read.
    for (var i = 0; i < 500; i++) {
      await db.collection('attendanceSessions').add({
        'courseId': 'C1', 'sessionDate': '2026-0${1 + i % 9}-1${i % 9}', 'totalPresentCount': 9, 'targetYear': 3, 'targetSemester': 1,
      });
    }
    await db.doc('courseStats/C1').set({'heldDates': ['2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04']});
    await db.doc('courseStats/C2').set({'heldDates': <String>[]});
    await db.doc('studentStats/stu').set({
      'present': {'C1': ['2026-11-01', '2026-11-02', '2026-11-03']},
      'complete': true,
    });
    final s = await as('stu').mySummary();
    final os = s.courseSummaries.single; // C2 had no class yet
    expect((os.courseCode, os.attendedClasses, os.totalClasses), ('CSE-3101', 3, 4));
    expect(os.absentDates, ['2026-11-04']);
  });

  test('a course without a summary record falls back to its sessions', () async {
    await db.collection('attendanceSessions').add({'courseId': 'C2', 'sessionDate': '2026-11-05', 'totalPresentCount': 2});
    await db.collection('attendanceSessions').add({'courseId': 'C2', 'sessionDate': '2026-11-06', 'totalPresentCount': 0});
    await db.doc('studentStats/stu').set({'present': <String, dynamic>{}, 'complete': true});
    final s = await as('stu').mySummary();
    final db2 = s.courseSummaries.single;
    expect((db2.courseCode, db2.totalClasses, db2.attendedClasses), ('CSE-3102', 1, 0));
  });

  test('a missing student record is rebuilt once from their marks', () async {
    await db.doc('attendance/x_stu').set({'studentId': 'stu', 'courseId': 'C1', 'status': 'PRESENT', 'date': '2026-11-01'});
    await db.doc('attendance/y_stu').set({'studentId': 'stu', 'courseId': 'C1', 'status': 'ABSENT', 'date': '2026-11-02'});
    await db.doc('courseStats/C1').set({'heldDates': ['2026-11-01', '2026-11-02']});
    final s = await as('stu').mySummary();
    expect(s.courseSummaries.firstWhere((c) => c.courseId == 'C1').attendedClasses, 1);
    final saved = (await db.doc('studentStats/stu').get()).data()!;
    expect(saved['complete'], isTrue);
    expect(saved['present'], {'C1': ['2026-11-01']});
  });

  test('marking with the code adds the day to the student\'s record', () async {
    final today = ClassTime.todayKey();
    await db.doc('attendanceSessions/s1').set({
      'courseId': 'C1', 'courseCode': 'CSE-3101', 'courseTitle': 'OS', 'teacherId': 't', 'mode': 'CODE',
      'isActive': true, 'status': 'ACTIVE', 'sessionDate': today, 'targetYear': 3, 'targetSemester': 1,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))), 'totalPresentCount': 0,
    });
    await as('stu').markWithCode('ABC234', sessionId: 's1');
    final stats = (await db.doc('studentStats/stu').get()).data()!;
    expect(stats['present'], {'C1': [today]});
    expect((await db.doc('attendanceSessions/s1').get()).data()!['totalPresentCount'], 1);
  });

  test('teacher marks update the records; "classes held" is rebuilt', () async {
    await db.doc('attendanceSessions/s1').set({
      'courseId': 'C1', 'courseCode': 'CSE-3101', 'courseTitle': 'OS', 'teacherId': 't', 'sessionDate': '2026-11-10', 'totalPresentCount': 0,
    });
    await db.doc('studentStats/b').set({'present': {'C1': ['2026-11-10']}, 'complete': true});
    AttendanceRosterItem item(String id, String status, {String? by}) =>
        AttendanceRosterItem(studentId: id, studentRoll: id, studentName: id, status: status, markedBy: by);
    await as('t').saveMarks(sessionId: 's1', items: [
      item('a', 'PRESENT'),
      item('b', 'ABSENT', by: 'SELF'), // corrected from present
      item('c', 'ABSENT'), // never marked: no write needed
    ]);
    expect((await db.doc('studentStats/a').get()).data()!['present'], {'C1': ['2026-11-10']});
    expect((await db.doc('studentStats/b').get()).data()!['present'], {'C1': <String>[]});
    expect((await db.doc('studentStats/c').get()).exists, isFalse);
    expect((await db.doc('courseStats/C1').get()).data()!['heldDates'], ['2026-11-10']);
  });
}
