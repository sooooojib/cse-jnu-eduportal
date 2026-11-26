import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:cse_jnu_eduportal/features/admin/data/services/batch_promotion_service.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/services/class_attendance_service.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _Auth extends Mock implements fb.FirebaseAuth {}

class _User extends Mock implements fb.User {}

/// S2-05: semester promotion done right + "Promote batch".
void main() {
  late FakeFirebaseFirestore db;
  Future<Map<String, dynamic>> doc(String path) async => (await db.doc(path).get()).data()!;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('users').doc('cr').set({'role': 'CR', 'fullName': 'Cr', 'studentId': '01', 'year': 3, 'semester': 1, 'session': '2021-22'});
    await db.collection('users').doc('a').set({'role': 'STUDENT', 'fullName': 'A', 'studentId': '02', 'year': 3, 'semester': 1, 'session': '2021-22'});
    await db.collection('users').doc('b').set({'role': 'STUDENT', 'fullName': 'B', 'studentId': '03', 'year': 3, 'semester': 1, 'session': '2020-21'});
    await db.collection('users').doc('gone').set({'role': 'STUDENT', 'fullName': 'G', 'studentId': '04', 'year': 3, 'semester': 1, 'isActive': false});
    await db.collection('users').doc('t').set({'role': 'TEACHER', 'fullName': 'T', 'year': 3, 'semester': 1});
    await db.collection('semesterUpgradeRequests').doc('ra').set({'studentId': 'a', 'status': 'PENDING', 'requestedYear': 3, 'requestedSemester': 2});
    await db.collection('semesterUpgradeRequests').doc('rb').set({'studentId': 'b', 'status': 'PENDING', 'requestedYear': 4, 'requestedSemester': 1});
    await db.collection('semesterUpgradeRequests').doc('rcr').set({'studentId': 'cr', 'status': 'PENDING', 'requestedYear': 3, 'requestedSemester': 2});
    await db.collection('crTransfers').doc('cr').set({'fromUid': 'cr', 'toUid': 'a', 'status': 'PENDING'});
  });

  group('Promote batch', () {
    test('next semester, and nothing after 4-2', () {
      expect(BatchPromotionService.nextOf(3, 1), (3, 2));
      expect(BatchPromotionService.nextOf(3, 2), (4, 1));
      expect(BatchPromotionService.nextOf(4, 2), isNull);
    });

    test('preview lists active students and CRs, optionally one session', () async {
      final svc = BatchPromotionService(firestore: db);
      final all = await svc.preview(year: 3, semester: 1);
      expect(all.map((s) => s.id), ['cr', 'a', 'b']); // by roll; no teacher, no inactive
      expect(all.first.isCr, isTrue);
      final one = await svc.preview(year: 3, semester: 1, session: '2021-22');
      expect(one.map((s) => s.id), ['cr', 'a']);
    });

    test('moves everyone, the CR stays CR, pending requests are closed', () async {
      final moved = await BatchPromotionService(firestore: db)
          .promote(year: 3, semester: 1, studentIds: ['cr', 'a', 'b'], actorId: 'chair');
      expect(moved, 3);
      for (final id in ['cr', 'a', 'b']) {
        final u = await doc('users/$id');
        expect((u['year'], u['semester']), (3, 2));
      }
      expect((await doc('users/cr'))['role'], 'CR');
      expect((await doc('semesterUpgradeRequests/ra'))['status'], 'APPROVED'); // asked for 3-2
      expect((await doc('semesterUpgradeRequests/rb'))['status'], 'REJECTED'); // asked for 4-1
      expect((await db.collection('notifications').get()).docs.length, 3);
    });

    test('4-2 cannot be promoted', () async {
      expect(
        () => BatchPromotionService(firestore: db).promote(year: 4, semester: 2, studentIds: ['a'], actorId: 'x'),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('approving a CR\'s own request drops the CR role and cancels the open offer', () async {
    final ds = AdminRemoteDataSourceImpl(firestore: db, functions: _MockFunctions());
    await ds.approveSemesterUpgrade(requestId: 'rcr');
    final cr = await doc('users/cr');
    expect((cr['year'], cr['semester'], cr['role']), (3, 2, 'STUDENT'));
    expect((await doc('crTransfers/cr'))['status'], 'CANCELLED');
  });

  test('attendance of a past semester is still shown', () async {
    final auth = _Auth();
    final user = _User();
    when(() => user.uid).thenReturn('a');
    when(() => auth.currentUser).thenReturn(user);
    await db.collection('users').doc('a').update({'year': 3, 'semester': 2}); // promoted
    await db.collection('courses').doc('C31').set({'code': 'CSE-3101', 'title': 'OS', 'year': 3, 'semester': 1});
    await db.collection('attendanceSessions').doc('old').set({
      'courseId': 'C31', 'courseCode': 'CSE-3101', 'courseTitle': 'OS', 'sessionDate': '2026-01-10',
      'targetYear': 3, 'targetSemester': 1, 'totalPresentCount': 5,
    });
    await db.collection('attendance').doc('old_a').set({
      'sessionId': 'old', 'studentId': 'a', 'courseId': 'C31', 'status': 'PRESENT', 'date': '2026-01-10',
    });
    final svc = ClassAttendanceServiceImpl(firestore: db, auth: auth);
    expect((await svc.mySummary()).courseSummaries, isEmpty); // current semester: nothing yet
    final past = await svc.mySummary(year: 3, semester: 1);
    expect(past.courseSummaries.single.courseCode, 'CSE-3101');
    expect(past.courseSummaries.single.attendedClasses, 1);
  });
}
