import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cse_jnu_eduportal/core/constants/app_constants.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/error/exceptions.dart';
import 'package:cse_jnu_eduportal/core/error/failures.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';
import 'package:cse_jnu_eduportal/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/auth_response_model.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/user_model.dart';
import 'package:cse_jnu_eduportal/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockFbUser extends Mock implements fb.User {}
class MockIdTokenResult extends Mock implements fb.IdTokenResult {}

void main() {
  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockLocalStorageService mockLocalStorage;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockUsersCollection;
  late MockDocumentReference mockUserDoc;
  late MockDocumentSnapshot mockDocSnapshot;
  late AuthRepositoryImpl repository;

  const testUserModel = UserModel(
    id: 'uid_test_123',
    email: 'student@cse.jnu.ac.bd',
    fullName: 'Sajib Ahmed',
    role: UserRole.student,
    studentId: '2020CSE042',
    year: 3,
    semester: 1,
    isActive: true,
  );

  const testAuthResponse = AuthResponseModel(
    accessToken: 'test_token',
    refreshToken: 'test_refresh_token',
    user: testUserModel,
  );

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockLocalStorage = MockLocalStorageService();
    mockFirestore = MockFirebaseFirestore();
    mockUsersCollection = MockCollectionReference();
    mockUserDoc = MockDocumentReference();
    mockDocSnapshot = MockDocumentSnapshot();

    when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
    when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDoc);

    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localStorage: mockLocalStorage,
      firestore: mockFirestore,
    );
  });

  group('AuthRepositoryImpl Tests', () {
    test('login successfully returns User and writes to local cache', () async {
      when(() => mockRemoteDataSource.login(
            email: 'student@cse.jnu.ac.bd',
            password: 'Password123!',
          )).thenAnswer((_) async => testAuthResponse);

      when(() => mockLocalStorage.setString(AppConstants.keyUserData, any()))
          .thenAnswer((_) async => true);

      final result = await repository.login(
        email: 'student@cse.jnu.ac.bd',
        password: 'Password123!',
      );

      expect(result.id, 'uid_test_123');
      expect(result.role, UserRole.student);
      verify(() => mockRemoteDataSource.login(
            email: 'student@cse.jnu.ac.bd',
            password: 'Password123!',
          )).called(1);
      verify(() => mockLocalStorage.setString(AppConstants.keyUserData, any())).called(1);
    });

    test('login throws Failure on invalid credentials', () async {
      when(() => mockRemoteDataSource.login(
            email: 'wrong@cse.jnu.ac.bd',
            password: 'WrongPassword',
          )).thenThrow(const ServerException(message: 'Invalid email or password.'));

      expect(
        () => repository.login(
          email: 'wrong@cse.jnu.ac.bd',
          password: 'WrongPassword',
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('login throws Failure with disabled message when account is deactivated', () async {
      when(() => mockRemoteDataSource.login(
            email: 'disabled@cse.jnu.ac.bd',
            password: 'Password123!',
          )).thenThrow(const ServerException(
        message: 'Your account has been deactivated. Please contact CSE administration.',
      ));

      expect(
        () => repository.login(
          email: 'disabled@cse.jnu.ac.bd',
          password: 'Password123!',
        ),
        throwsA(predicate<Failure>(
          (f) => f.message.contains('deactivated'),
        )),
      );
    });

    test('getCurrentUser returns User and refreshes local cache on valid session', () async {
      when(() => mockRemoteDataSource.getMe()).thenAnswer((_) async => testUserModel);
      when(() => mockLocalStorage.setString(AppConstants.keyUserData, any()))
          .thenAnswer((_) async => true);

      final result = await repository.getCurrentUser();

      expect(result.fullName, 'Sajib Ahmed');
      verify(() => mockRemoteDataSource.getMe()).called(1);
      verify(() => mockLocalStorage.setString(AppConstants.keyUserData, any())).called(1);
    });

    test('getCurrentUser throws Failure when session expired or profile deleted', () async {
      when(() => mockRemoteDataSource.getMe())
          .thenThrow(const ServerException(message: 'User profile not found. Please log in again.'));

      expect(() => repository.getCurrentUser(), throwsA(isA<Failure>()));
    });

    test('logout calls remoteDataSource.logout and removes local cache', () async {
      when(() => mockRemoteDataSource.logout()).thenAnswer((_) async {});
      when(() => mockLocalStorage.remove(AppConstants.keyUserData))
          .thenAnswer((_) async => true);

      await repository.logout();

      verify(() => mockRemoteDataSource.logout()).called(1);
      verify(() => mockLocalStorage.remove(AppConstants.keyUserData)).called(1);
    });

    test('sendPasswordResetEmail forwards call to remoteDataSource', () async {
      when(() => mockRemoteDataSource.sendPasswordResetEmail('student@cse.jnu.ac.bd'))
          .thenAnswer((_) async {});

      await repository.sendPasswordResetEmail('student@cse.jnu.ac.bd');

      verify(() => mockRemoteDataSource.sendPasswordResetEmail('student@cse.jnu.ac.bd')).called(1);
    });

    test('submitSignupRequest submits petition and returns requestId', () async {
      when(() => mockRemoteDataSource.submitSignupRequest(
            fullName: 'Tahmid Rahman',
            email: 'tahmid@cse.jnu.ac.bd',
            role: 'STUDENT',
            studentId: '2024CSE015',
            phone: '+8801800000000',
          )).thenAnswer((_) async => 'req_generated_123');

      final reqId = await repository.submitSignupRequest(
        fullName: 'Tahmid Rahman',
        email: 'tahmid@cse.jnu.ac.bd',
        role: 'STUDENT',
        studentId: '2024CSE015',
        phone: '+8801800000000',
      );

      expect(reqId, 'req_generated_123');
    });

    test('authStateChanges streams null when Firebase Auth user is null', () async {
      when(() => mockRemoteDataSource.authStateChanges())
          .thenAnswer((_) => Stream.value(null));

      final stream = repository.authStateChanges();
      final emitted = await stream.first;

      expect(emitted, isNull);
    });

    test('authStateChanges streams UserModel with custom claim role when user is active', () async {
      final mockFbUser = MockFbUser();
      final mockTokenResult = MockIdTokenResult();

      when(() => mockFbUser.uid).thenReturn('uid_test_123');
      when(() => mockFbUser.getIdTokenResult()).thenAnswer((_) async => mockTokenResult);
      when(() => mockTokenResult.claims).thenReturn({'role': 'CR'});

      when(() => mockRemoteDataSource.authStateChanges())
          .thenAnswer((_) => Stream.value(mockFbUser));

      when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn('uid_test_123');
      when(() => mockDocSnapshot.data()).thenReturn({
        'email': 'cr@cse.jnu.ac.bd',
        'fullName': 'Batch CR',
        'role': 'STUDENT', // Firestore says STUDENT, but Custom Claim says CR!
        'isActive': true,
      });

      final stream = repository.authStateChanges();
      final user = await stream.first;

      expect(user, isNotNull);
      expect(user?.role, UserRole.cr); // Custom claim took precedence!
    });

    test('authStateChanges returns null if account was deactivated in Firestore', () async {
      final mockFbUser = MockFbUser();
      when(() => mockFbUser.uid).thenReturn('uid_disabled_user');
      when(() => mockRemoteDataSource.authStateChanges())
          .thenAnswer((_) => Stream.value(mockFbUser));

      when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.data()).thenReturn({
        'email': 'disabled@cse.jnu.ac.bd',
        'fullName': 'Disabled User',
        'isActive': false,
      });

      final stream = repository.authStateChanges();
      final user = await stream.first;

      expect(user, isNull);
    });

    test('authStateChanges returns null if user document was deleted (deleted user)', () async {
      final mockFbUser = MockFbUser();
      when(() => mockFbUser.uid).thenReturn('uid_deleted_user');
      when(() => mockRemoteDataSource.authStateChanges())
          .thenAnswer((_) => Stream.value(mockFbUser));

      when(() => mockUserDoc.get()).thenAnswer((_) async => mockDocSnapshot);
      when(() => mockDocSnapshot.exists).thenReturn(false);

      final stream = repository.authStateChanges();
      final user = await stream.first;

      expect(user, isNull);
    });
  });
}
