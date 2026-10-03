import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/error/failures.dart';
import 'package:cse_jnu_eduportal/features/auth/data/repositories/user_repository_impl.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockUsersCollection;
  late MockDocumentReference mockUserDoc;
  late MockDocumentSnapshot mockDocSnapshot;
  late UserRepositoryImpl repository;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockUsersCollection = MockCollectionReference();
    mockUserDoc = MockDocumentReference();
    mockDocSnapshot = MockDocumentSnapshot();

    when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);

    repository = UserRepositoryImpl(firestore: mockFirestore);
  });

  group('UserRepositoryImpl Tests', () {
    test('getUserById returns strongly typed User when document exists', () async {
      when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn('uid_student_1');
      when(() => mockDocSnapshot.data()).thenReturn({
        'email': 'student@cse.jnu.ac.bd',
        'fullName': 'Sajib Ahmed',
        'role': 'STUDENT',
        'studentId': '2020CSE042',
        'year': 3,
        'semester': 1,
        'isActive': true,
      });

      final user = await repository.getUserById('uid_student_1');

      expect(user.id, 'uid_student_1');
      expect(user.fullName, 'Sajib Ahmed');
      expect(user.role, UserRole.student);
      expect(user.year, 3);
    });

    test('getUserById throws Failure when document does not exist', () async {
      when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);

      expect(() => repository.getUserById('uid_missing'), throwsA(isA<Failure>()));
    });

    test('getUsersByRole filters by role and active status', () async {
      final mockQuery1 = MockQuery();
      final mockQuery2 = MockQuery();
      final mockQuerySnapshot = MockQuerySnapshot();
      final mockDoc1 = MockQueryDocumentSnapshot();

      when(() => mockUsersCollection.where('role', isEqualTo: 'TEACHER')).thenReturn(mockQuery1);
      when(() => mockQuery1.where('isActive', isEqualTo: true)).thenReturn(mockQuery2);
      when(() => mockQuery2.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1]);

      when(() => mockDoc1.id).thenReturn('uid_teacher_1');
      when(() => mockDoc1.data()).thenReturn({
        'email': 'teacher@cse.jnu.ac.bd',
        'fullName': 'Dr. Mohammad Shafiul Alam',
        'role': 'TEACHER',
        'isActive': true,
      });

      final teachers = await repository.getUsersByRole(UserRole.teacher);

      expect(teachers.length, 1);
      expect(teachers.first.id, 'uid_teacher_1');
      expect(teachers.first.role, UserRole.teacher);
    });

    test('updateProfile only updates allowed profile fields (phone, avatarUrl)', () async {
      when(() => mockUserDoc.update(any())).thenAnswer((_) async {});

      await repository.updateProfile(
        uid: 'uid_student_1',
        phone: '+8801711111111',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      final captured = verify(() => mockUserDoc.update(captureAny())).captured;
      final updateMap = captured.first as Map<dynamic, dynamic>;

      expect(updateMap['phone'], '+8801711111111');
      expect(updateMap['avatarUrl'], 'https://example.com/avatar.jpg');
      expect(updateMap.containsKey('role'), false); // Cannot update role!
      expect(updateMap.containsKey('year'), false); // Cannot self-promote year!
      expect(updateMap.containsKey('updatedAt'), true);
    });

    test('assignCoursesToTeacher writes assignedCourseIds to faculty profile', () async {
      when(() => mockUserDoc.update(any())).thenAnswer((_) async {});

      await repository.assignCoursesToTeacher(
        teacherId: 'uid_teacher_1',
        courseIds: ['CSE-3101', 'CSE-3102'],
      );

      final captured = verify(() => mockUserDoc.update(captureAny())).captured;
      final updateMap = captured.first as Map<dynamic, dynamic>;

      expect(updateMap['assignedCourseIds'], ['CSE-3101', 'CSE-3102']);
      expect(updateMap.containsKey('updatedAt'), true);
    });
  });
}
