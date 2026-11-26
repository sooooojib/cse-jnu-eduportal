import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/admin/data/repositories/teacher_monitoring_repository_impl.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/repositories/curriculum_repository_impl.dart';

class _Auth extends Mock implements fb.FirebaseAuth {}

class _User extends Mock implements fb.User {}

class _Functions extends Mock implements FirebaseFunctions {}

/// S2-06: retake courses show in Schedule → Exams and count in Monitoring.
void main() {
  late FakeFirebaseFirestore db;

  Map<String, dynamic> exam(String course, int y, int s) => {
        'courseId': course, 'courseCode': course, 'courseTitle': course, 'title': 'Mid', 'examDate': '2026-12-10',
        'startTime': '10:00 AM', 'endTime': '11:00 AM', 'room': '401', 'year': y, 'semester': s, 'type': 'MID_TERM',
        'status': 'SCHEDULED', 'createdBy': 'x',
      };

  setUp(() async {
    db = FakeFirebaseFirestore();
    // 'senior' is in 4-1 and retakes C31 (a 3-1 course); 'reg' is a regular 3-1 student.
    await db.collection('users').doc('senior').set({'role': 'STUDENT', 'year': 4, 'semester': 1, 'isActive': true, 'fullName': 'Sen'});
    await db.collection('users').doc('reg').set({'role': 'STUDENT', 'year': 3, 'semester': 1, 'isActive': true, 'fullName': 'Reg'});
    await db.collection('users').doc('t1').set({'role': 'TEACHER', 'isActive': true, 'fullName': 'T'});
    await db.collection('courses').doc('C31').set({'code': 'CSE-3101', 'title': 'OS', 'year': 3, 'semester': 1, 'teacherId': 't1'});
    await db.collection('enrollments').doc('C31_senior').set({'courseId': 'C31', 'studentId': 'senior', 'type': 'RETAKE'});
    await db.collection('exams').doc('own').set(exam('C41', 4, 1));
    await db.collection('exams').doc('retake').set(exam('C31', 3, 1));
    await db.collection('exams').doc('other').set(exam('C21', 2, 1));
  });

  CurriculumRemoteDataSourceImpl asUser(String uid) {
    final auth = _Auth();
    final user = _User();
    when(() => user.uid).thenReturn(uid);
    when(() => auth.currentUser).thenReturn(user);
    return CurriculumRemoteDataSourceImpl(firestore: db, auth: auth, functions: _Functions());
  }

  test('a retaking student sees their retake exam in the Exam tab', () async {
    final exams = await asUser('senior').getExams();
    expect(exams.map((e) => e.id).toSet(), {'own', 'retake'});
  });

  test('a regular student sees only their semester', () async {
    final exams = await asUser('reg').getExams();
    expect(exams.map((e) => e.id).toSet(), {'retake'});
  });

  test('looking at another semester does not add retakes', () async {
    final exams = await asUser('senior').getExams(year: 2, semester: 1);
    expect(exams.map((e) => e.id).toSet(), {'other'});
  });

  test('Monitoring class size counts retake students', () async {
    final report = await TeacherMonitoringRepositoryImpl(firestore: db).loadReport();
    final os = report.teachers.firstWhere((t) => t.teacherId == 't1').courses.single;
    expect(os.cohortSize, 2); // 1 regular + 1 retaking senior
  });
}
