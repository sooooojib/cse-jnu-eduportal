import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/features/admin/data/datasources/admin_remote_datasource.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

/// S2-04: "Change role" works on the free plan (no Cloud Function).
void main() {
  late FakeFirebaseFirestore db;
  late AdminRemoteDataSourceImpl ds;
  late _MockFunctions functions;

  Future<Map<String, dynamic>> user(String id) async => (await db.collection('users').doc(id).get()).data()!;

  setUp(() async {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    ds = AdminRemoteDataSourceImpl(firestore: db, functions: functions);
    await db.collection('users').doc('oldCr').set({'role': 'CR', 'year': 3, 'semester': 1});
    await db.collection('users').doc('flagCr').set({'role': 'STUDENT', 'isCR': true, 'year': 3, 'semester': 1});
    await db.collection('users').doc('s1').set({'role': 'STUDENT', 'year': 3, 'semester': 1});
    await db.collection('users').doc('otherBatchCr').set({'role': 'CR', 'year': 2, 'semester': 1});
    await db.collection('users').doc('t1').set({'role': 'TEACHER'});
    await db.collection('crTransfers').doc('oldCr').set({'fromUid': 'oldCr', 'status': 'PENDING'});
  });

  test('appointing a CR demotes the batch\'s previous CR(s) only', () async {
    await ds.updateUserRole(userId: 's1', role: UserRole.cr);
    expect((await user('s1'))['role'], 'CR');
    expect((await user('oldCr'))['role'], 'STUDENT');
    expect((await user('flagCr')).containsKey('isCR'), isFalse);
    expect((await user('otherBatchCr'))['role'], 'CR');
    expect((await db.collection('crTransfers').doc('oldCr').get()).exists, isFalse);
    verifyZeroInteractions(functions); // no Cloud Function on the free plan
  });

  test('staff roles change within staff', () async {
    await ds.updateUserRole(userId: 't1', role: UserRole.chairman);
    expect((await user('t1'))['role'], 'CHAIRMAN');
  });

  test('crossing groups is refused', () async {
    expect(() => ds.updateUserRole(userId: 's1', role: UserRole.teacher), throwsA(anything));
    expect(() => ds.updateUserRole(userId: 't1', role: UserRole.cr), throwsA(anything));
    expect((await user('t1'))['role'], 'TEACHER');
  });

  test('choices offered per group', () {
    expect(AdminRemoteDataSourceImpl.roleChoicesFor(UserRole.student), [UserRole.student, UserRole.cr]);
    expect(AdminRemoteDataSourceImpl.roleChoicesFor(UserRole.teacher), [UserRole.teacher, UserRole.chairman, UserRole.admin]);
  });
}
