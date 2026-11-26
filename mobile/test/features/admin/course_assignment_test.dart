import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/admin/data/datasources/admin_remote_datasource.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

void main() {
  late FakeFirebaseFirestore db;
  late AdminRemoteDataSourceImpl ds;

  Future<List<String>> courseIdsOf(String uid) async =>
      List<String>.from((await db.collection('users').doc(uid).get()).data()!['assignedCourseIds'] ?? []);
  Future<List<String>> assignmentTeachers(String courseId) async =>
      (await db.collection('courseAssignments').where('courseId', isEqualTo: courseId).get())
          .docs
          .map((d) => d.data()['teacherId'] as String)
          .toList();

  setUp(() async {
    db = FakeFirebaseFirestore();
    ds = AdminRemoteDataSourceImpl(firestore: db, functions: _MockFunctions());
    await db.collection('users').doc('old').set({'role': 'TEACHER', 'fullName': 'Old T', 'assignedCourseIds': ['C1', 'C2']});
    await db.collection('users').doc('new').set({'role': 'TEACHER', 'fullName': 'New T', 'assignedCourseIds': <String>[]});
    await db.collection('users').doc('student').set({'role': 'STUDENT', 'fullName': 'S'});
    await db.collection('courses').doc('C1').set({'code': 'CSE-1', 'title': 'One', 'teacherId': 'old', 'teacherName': 'Old T'});
    await db.collection('courses').doc('C2').set({'code': 'CSE-2', 'title': 'Two', 'teacherId': 'old', 'teacherName': 'Old T'});
    await db.collection('courseAssignments').doc('a1').set({'courseId': 'C1', 'teacherId': 'old'});
    await db.collection('courseAssignments').doc('a2').set({'courseId': 'C2', 'teacherId': 'old'});
    // Routine of C1: two weekly slots held by 'old', a lab given to 'lab',
    // a past and a future dated class held by 'old'.
    await db.collection('schedules').doc('w1').set({'courseId': 'C1', 'teacherId': 'old', 'teacherName': 'Old T', 'dayOfWeek': 'SUNDAY'});
    await db.collection('schedules').doc('w2').set({'courseId': 'C1', 'teacherId': '', 'teacherName': '', 'dayOfWeek': 'MONDAY'});
    await db.collection('schedules').doc('lab').set({'courseId': 'C1', 'teacherId': 'lab', 'teacherName': 'Lab T', 'dayOfWeek': 'TUESDAY'});
    await db.collection('schedules').doc('past').set({'courseId': 'C1', 'teacherId': 'old', 'teacherName': 'Old T', 'date': '2020-01-01'});
    await db.collection('schedules').doc('future').set({'courseId': 'C1', 'teacherId': 'old', 'teacherName': 'Old T', 'date': '2999-01-01'});
    await db.collection('schedules').doc('other').set({'courseId': 'C2', 'teacherId': 'old', 'teacherName': 'Old T', 'dayOfWeek': 'SUNDAY'});
  });

  Future<String> slotTeacher(String id) async =>
      (await db.collection('schedules').doc(id).get()).data()!['teacherId'] as String;

  test('reassigning replaces the old teacher everywhere', () async {
    await ds.assignCourseToTeacher(courseId: 'C1', teacherId: 'new');

    final course = (await db.collection('courses').doc('C1').get()).data()!;
    expect(course['teacherId'], 'new');
    expect(course['teacherName'], 'New T');
    expect(await assignmentTeachers('C1'), ['new']);
    expect(await courseIdsOf('new'), ['C1']);
    expect(await courseIdsOf('old'), ['C2']); // only C1 removed
    expect(await assignmentTeachers('C2'), ['old']); // other courses untouched
  });

  test('the routine follows the new teacher (S2-02)', () async {
    await ds.assignCourseToTeacher(courseId: 'C1', teacherId: 'new');
    expect(await slotTeacher('w1'), 'new');
    expect((await db.collection('schedules').doc('w1').get()).data()!['teacherName'], 'New T');
    expect(await slotTeacher('w2'), 'new'); // had no teacher
    expect(await slotTeacher('future'), 'new');
    expect(await slotTeacher('lab'), 'lab'); // deliberately another teacher
    expect(await slotTeacher('past'), 'old'); // history kept
    expect(await slotTeacher('other'), 'old'); // other course
  });

  test('assigning the same teacher again is refused', () async {
    expect(() => ds.assignCourseToTeacher(courseId: 'C1', teacherId: 'old'), throwsA(anything));
  });

  test('a student cannot be assigned', () async {
    expect(() => ds.assignCourseToTeacher(courseId: 'C1', teacherId: 'student'), throwsA(anything));
    expect((await db.collection('courses').doc('C1').get()).data()!['teacherId'], 'old');
  });

  test('removing the current teacher clears the course', () async {
    await ds.removeCourseAssignment(assignmentId: 'a1', courseId: 'C1', teacherId: 'old');
    final course = (await db.collection('courses').doc('C1').get()).data()!;
    expect(course['teacherId'], isNull);
    expect(await courseIdsOf('old'), ['C2']);
    expect(await assignmentTeachers('C1'), isEmpty);
    expect(await slotTeacher('w1'), '');
    expect(await slotTeacher('lab'), 'lab');
    expect(await slotTeacher('past'), 'old');
  });

  test('removing a stale assignment does not clear the current teacher', () async {
    await db.collection('courseAssignments').doc('stale').set({'courseId': 'C2', 'teacherId': 'new'});
    await ds.removeCourseAssignment(assignmentId: 'stale', courseId: 'C2', teacherId: 'new');
    final course = (await db.collection('courses').doc('C2').get()).data()!;
    expect(course['teacherId'], 'old');
  });
}
