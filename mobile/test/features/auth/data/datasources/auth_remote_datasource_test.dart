import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/error/exceptions.dart';
import 'package:cse_jnu_eduportal/features/auth/data/datasources/auth_remote_datasource.dart';

class MockFirebaseAuth extends Mock implements fb.FirebaseAuth {}
class MockUserCredential extends Mock implements fb.UserCredential {}
class MockUser extends Mock implements fb.User {}
class MockIdTokenResult extends Mock implements fb.IdTokenResult {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUserCredential mockCredential;
  late MockUser mockUser;
  late MockIdTokenResult mockIdTokenResult;
  late MockCollectionReference mockUsersCollection;
  late MockCollectionReference mockSignupCollection;
  late MockDocumentReference mockUserDoc;
  late MockDocumentReference mockSignupDoc;
  late MockDocumentSnapshot mockDocSnapshot;
  late AuthRemoteDataSourceImpl dataSource;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockCredential = MockUserCredential();
    mockUser = MockUser();
    mockIdTokenResult = MockIdTokenResult();
    mockUsersCollection = MockCollectionReference();
    mockSignupCollection = MockCollectionReference();
    mockUserDoc = MockDocumentReference();
    mockSignupDoc = MockDocumentReference();
    mockDocSnapshot = MockDocumentSnapshot();

    when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
    when(() => mockFirestore.collection('signupRequests')).thenReturn(mockSignupCollection);
    when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);

    dataSource = AuthRemoteDataSourceImpl(
      auth: mockAuth,
      firestore: mockFirestore,
    );
  });

  group('AuthRemoteDataSourceImpl Tests', () {
    test('login succeeds and extracts authoritative custom claim role', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'teacher@cse.jnu.ac.bd',
            password: 'Password123!',
          )).thenAnswer((_) async => mockCredential);

      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('uid_teacher_1');
      when(() => mockUser.getIdTokenResult(any())).thenAnswer((_) async => mockIdTokenResult);
      when(() => mockIdTokenResult.claims).thenReturn({'role': 'TEACHER'});
      when(() => mockIdTokenResult.token).thenReturn('jwt_token_123');
      when(() => mockUser.refreshToken).thenReturn('refresh_token_123');

      when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn('uid_teacher_1');
      when(() => mockDocSnapshot.data()).thenReturn({
        'email': 'teacher@cse.jnu.ac.bd',
        'fullName': 'Dr. Mohammad Shafiul Alam',
        'role': 'STUDENT', // Firestore says student, but custom claim says TEACHER!
        'isActive': true,
      });

      final response = await dataSource.login(
        email: 'teacher@cse.jnu.ac.bd',
        password: 'Password123!',
      );

      expect(response.user.id, 'uid_teacher_1');
      expect(response.user.role, UserRole.teacher); // Custom claim is authoritative!
      expect(response.accessToken, 'jwt_token_123');
    });

    test('login signs out and throws ServerException if user profile not found (deleted/unapproved user)', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'unapproved@cse.jnu.ac.bd',
            password: 'Password123!',
          )).thenAnswer((_) async => mockCredential);

      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('uid_unapproved');
      when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await expectLater(
        dataSource.login(
          email: 'unapproved@cse.jnu.ac.bd',
          password: 'Password123!',
        ),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('not yet approved'),
        )),
      );

      verify(() => mockAuth.signOut()).called(1);
    });

    test('login signs out and throws ServerException if account is deactivated', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'deactivated@cse.jnu.ac.bd',
            password: 'Password123!',
          )).thenAnswer((_) async => mockCredential);

      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('uid_deactivated');
      when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.data()).thenReturn({
        'email': 'deactivated@cse.jnu.ac.bd',
        'fullName': 'Deactivated User',
        'isActive': false,
      });
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await expectLater(
        dataSource.login(
          email: 'deactivated@cse.jnu.ac.bd',
          password: 'Password123!',
        ),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('deactivated'),
        )),
      );

      verify(() => mockAuth.signOut()).called(1);
    });

    test('login maps FirebaseAuthException invalid-credential to friendly error', () async {
      when(() => mockAuth.signInWithEmailAndPassword(
            email: 'wrong@cse.jnu.ac.bd',
            password: 'WrongPassword',
          )).thenThrow(fb.FirebaseAuthException(code: 'invalid-credential'));

      await expectLater(
        dataSource.login(
          email: 'wrong@cse.jnu.ac.bd',
          password: 'WrongPassword',
        ),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Invalid email or password.',
        )),
      );
    });

    test('getMe returns current user profile when session active', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('uid_student_1');
      when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn('uid_student_1');
      when(() => mockDocSnapshot.data()).thenReturn({
        'email': 'student@cse.jnu.ac.bd',
        'fullName': 'Sajib Ahmed',
        'role': 'STUDENT',
        'isActive': true,
      });
      when(() => mockUser.getIdTokenResult()).thenAnswer((_) async => mockIdTokenResult);
      when(() => mockIdTokenResult.claims).thenReturn({'role': 'STUDENT'});

      final user = await dataSource.getMe();

      expect(user.fullName, 'Sajib Ahmed');
      expect(user.role, UserRole.student);
    });

    test('getMe throws ServerException if currentUser is null (expired session)', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(
        () => dataSource.getMe(),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          'Not authenticated.',
        )),
      );
    });

    test('sendPasswordResetEmail invokes FirebaseAuth reset', () async {
      when(() => mockAuth.sendPasswordResetEmail(email: 'student@cse.jnu.ac.bd'))
          .thenAnswer((_) async {});

      await dataSource.sendPasswordResetEmail('student@cse.jnu.ac.bd');

      verify(() => mockAuth.sendPasswordResetEmail(email: 'student@cse.jnu.ac.bd')).called(1);
    });

    test('logout invokes FirebaseAuth signOut', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await dataSource.logout();

      verify(() => mockAuth.signOut()).called(1);
    });

    test('submitSignupRequest writes to signupRequests queue without elevating role', () async {
      when(() => mockSignupCollection.add(any())).thenAnswer((_) async => mockSignupDoc);
      when(() => mockSignupDoc.id).thenReturn('req_new_789');

      final result = await dataSource.submitSignupRequest(
        fullName: 'Applicant One',
        email: 'applicant@cse.jnu.ac.bd',
        role: 'STUDENT',
        studentId: '2024CSE099',
        phone: '+8801900000000',
      );

      expect(result, 'req_new_789');
      final captured = verify(() => mockSignupCollection.add(captureAny())).captured;
      final payload = captured.first as Map<String, dynamic>;

      expect(payload['status'], 'PENDING');
      expect(payload['fullName'], 'Applicant One');
      expect(payload['email'], 'applicant@cse.jnu.ac.bd');
      expect(payload['role'], 'STUDENT');
    });
  });
}
