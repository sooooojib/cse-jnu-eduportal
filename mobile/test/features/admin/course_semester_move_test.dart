import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

/// S2-08: changing a course's semester moves its routine and upcoming exams.
void main() {
  late FakeFirebaseFirestore db;
  late AdminRemoteDataSourceImpl ds;
  Future<Map<String, dynamic>> doc(String path) async => (await db.doc(path).get()).data()!;
  const moved = Course(id: 'C1', code: 'CSE-3101', title: 'OS', credit: 3, year: 3, semester: 2, courseType: 'THEORY');

  Map<String, dynamic> slot(String course, String day, String start, String end, {String? date, int y = 3, int s = 1}) => {
        'courseId': course, 'courseCode': course, 'dayOfWeek': day, 'startTime': start, 'endTime': end,
        'targetYear': y, 'targetSemester': s, if (date != null) 'date': date,
      };

  setUp(() async {
    db = FakeFirebaseFirestore();
    ds = AdminRemoteDataSourceImpl(firestore: db, functions: _MockFunctions());
    await db.doc('courses/C1').set({'code': 'CSE-3101', 'title': 'OS', 'year': 3, 'semester': 1, 'teacherId': 't'});
    await db.doc('schedules/weekly').set(slot('C1', 'SUNDAY', '10:00 AM', '11:00 AM'));
    await db.doc('schedules/past').set(slot('C1', 'MONDAY', '10:00 AM', '11:00 AM', date: '2020-01-01'));
    await db.doc('schedules/future').set(slot('C1', 'MONDAY', '12:00 PM', '1:00 PM', date: '2999-01-01'));
    await db.doc('exams/pastExam').set({'courseId': 'C1', 'examDate': '2020-01-10', 'year': 3, 'semester': 1});
    await db.doc('exams/nextExam').set({'courseId': 'C1', 'examDate': '2999-01-10', 'year': 3, 'semester': 1});
    await db.doc('attendanceSessions/s1').set({'courseId': 'C1', 'targetYear': 3, 'targetSemester': 1, 'sessionDate': '2020-01-05'});
  });

  test('routine and upcoming exams move; history stays', () async {
    await ds.updateCourse(moved);
    expect(((await doc('courses/C1'))['year'], (await doc('courses/C1'))['semester']), (3, 2));
    expect((await doc('schedules/weekly'))['targetSemester'], 2);
    expect((await doc('schedules/future'))['targetSemester'], 2);
    expect((await doc('schedules/past'))['targetSemester'], 1);
    expect((await doc('exams/nextExam'))['semester'], 2);
    expect((await doc('exams/pastExam'))['semester'], 1);
    expect((await doc('attendanceSessions/s1'))['targetSemester'], 1);
  });

  test('blocked when a routine class would clash in the new semester', () async {
    await db.doc('schedules/other').set(slot('C2', 'SUNDAY', '10:30 AM', '11:30 AM', y: 3, s: 2));
    await expectLater(ds.updateCourse(moved), throwsA(anything));
    expect((await doc('courses/C1'))['semester'], 1); // nothing changed
    expect((await doc('schedules/weekly'))['targetSemester'], 1);
  });

  test('blocked while upcoming class changes exist', () async {
    await db.doc('classChanges/x').set({'courseId': 'C1', 'date': '2999-02-01', 'targetYear': 3, 'targetSemester': 1});
    await expectLater(ds.updateCourse(moved), throwsA(anything));
    expect((await doc('courses/C1'))['semester'], 1);
  });

  test('editing other fields does not touch the routine', () async {
    await ds.updateCourse(const Course(id: 'C1', code: 'CSE-3101', title: 'Operating Systems', credit: 3, year: 3, semester: 1, courseType: 'THEORY'));
    expect((await doc('courses/C1'))['title'], 'Operating Systems');
    expect((await doc('schedules/weekly'))['targetSemester'], 1);
  });
}
