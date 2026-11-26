import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/teacher/data/datasources/teacher_remote_datasource.dart';

/// S2-02: a teacher's dashboard shows their classes by course / teacher ID,
/// never by name, and only their own exams for that day.
void main() {
  late FakeFirebaseFirestore db;
  final monday = DateTime(2026, 11, 30, 10); // a Monday morning

  const me = User(id: 'rahim1', email: 'a@x.com', fullName: 'Rahim Uddin', role: UserRole.teacher, assignedCourseIds: ['C1']);

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('users').doc('rahim1').set({'role': 'TEACHER', 'fullName': 'Rahim Uddin', 'assignedCourseIds': ['C1']});
    await db.collection('users').doc('rahim2').set({'role': 'TEACHER', 'fullName': 'Rahim Uddin', 'assignedCourseIds': ['C2']});
    await db.collection('courses').doc('C1').set({'code': 'CSE-1', 'title': 'Mine', 'year': 3, 'semester': 1, 'teacherId': 'rahim1', 'teacherName': 'Rahim Uddin'});
    await db.collection('courses').doc('C2').set({'code': 'CSE-2', 'title': 'Namesake', 'year': 3, 'semester': 1, 'teacherId': 'rahim2', 'teacherName': 'Rahim Uddin'});
    for (final (id, course, code, teacher) in [('s1', 'C1', 'CSE-1', 'rahim1'), ('s2', 'C2', 'CSE-2', 'rahim2')]) {
      await db.collection('schedules').doc(id).set({
        'courseId': course, 'courseCode': code, 'courseTitle': code, 'teacherId': teacher, 'teacherName': 'Rahim Uddin',
        'dayOfWeek': 'MONDAY', 'startTime': '10:00 AM', 'endTime': '11:00 AM', 'room': '401',
        'targetYear': 3, 'targetSemester': 1, 'classType': 'THEORY',
      });
    }
    Map<String, dynamic> exam(String course, String date) => {
          'courseId': course, 'courseCode': course, 'courseTitle': course, 'title': 'Mid', 'examDate': date,
          'startTime': '12:00 PM', 'endTime': '1:00 PM', 'room': '401', 'year': 3, 'semester': 1, 'type': 'MID_TERM',
          'status': 'SCHEDULED', 'createdBy': 'x',
        };
    await db.collection('exams').doc('mineToday').set(exam('C1', '2026-11-30'));
    await db.collection('exams').doc('mineLater').set(exam('C1', '2026-12-15'));
    await db.collection('exams').doc('othersToday').set(exam('C2', '2026-11-30'));
  });

  test('a namesake teacher\'s class is not shown', () async {
    final data = await TeacherRemoteDataSourceImpl(firestore: db).getTeacherDashboardData(teacher: me, currentTime: monday);
    expect(data.todayClasses.map((s) => s.courseId), ['C1']);
  });

  test('only my exams for that day are shown', () async {
    final data = await TeacherRemoteDataSourceImpl(firestore: db).getTeacherDashboardData(teacher: me, currentTime: monday);
    expect(data.todayExams.map((e) => e.id), ['mineToday']);
  });
}
