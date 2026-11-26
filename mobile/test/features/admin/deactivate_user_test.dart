import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/admin/data/datasources/admin_remote_datasource.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

/// S2-07: deactivate instead of delete.
void main() {
  late FakeFirebaseFirestore db;
  late AdminRemoteDataSourceImpl ds;
  Future<Map<String, dynamic>> doc(String path) async => (await db.doc(path).get()).data()!;

  setUp(() async {
    db = FakeFirebaseFirestore();
    ds = AdminRemoteDataSourceImpl(firestore: db, functions: _MockFunctions());
    await db.collection('users').doc('t').set({'role': 'TEACHER', 'isActive': true, 'assignedCourseIds': ['C1']});
    await db.collection('users').doc('cr').set({'role': 'CR', 'isActive': true, 'year': 3, 'semester': 1});
    await db.collection('courses').doc('C1').set({'code': 'CSE-1', 'teacherId': 't', 'teacherName': 'T'});
    await db.collection('courseAssignments').doc('a1').set({'courseId': 'C1', 'teacherId': 't'});
    await db.collection('schedules').doc('w1').set({'courseId': 'C1', 'teacherId': 't', 'teacherName': 'T', 'dayOfWeek': 'SUNDAY'});
    await db.collection('schedules').doc('lab').set({'courseId': 'C1', 'teacherId': 'x', 'teacherName': 'X', 'dayOfWeek': 'MONDAY'});
    await db.collection('crTransfers').doc('cr').set({'fromUid': 'cr', 'toUid': 's', 'status': 'PENDING'});
  });

  test('deactivating a teacher keeps the profile and unassigns their courses', () async {
    expect(await ds.teacherCourseIds('t'), ['C1']);
    await ds.toggleUserActiveStatus(userId: 't', isActive: false);
    final t = await doc('users/t');
    expect(t['isActive'], isFalse);
    expect(t['assignedCourseIds'], isEmpty);
    expect((await doc('courses/C1'))['teacherId'], isNull);
    expect((await db.doc('courseAssignments/a1').get()).exists, isFalse);
    expect((await doc('schedules/w1'))['teacherId'], '');
    expect((await doc('schedules/lab'))['teacherId'], 'x');
  });

  test('deactivating a CR drops the CR role and cancels their offer', () async {
    await ds.toggleUserActiveStatus(userId: 'cr', isActive: false);
    final cr = await doc('users/cr');
    expect((cr['isActive'], cr['role']), (false, 'STUDENT'));
    expect((await doc('crTransfers/cr'))['status'], 'CANCELLED');
  });

  test('reactivating only turns the account back on', () async {
    await ds.toggleUserActiveStatus(userId: 't', isActive: false);
    await ds.toggleUserActiveStatus(userId: 't', isActive: true);
    expect((await doc('users/t'))['isActive'], isTrue);
    expect((await doc('courses/C1'))['teacherId'], isNull); // reassign by hand
  });
}
