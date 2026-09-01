import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/core/error/failures.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/usecases/login_usecase.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/usecases/logout_usecase.dart';
import 'package:cse_jnu_eduportal/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_controller.dart';
import 'package:cse_jnu_eduportal/features/auth/presentation/controllers/auth_state.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}
class MockGetCurrentUserUseCase extends Mock implements GetCurrentUserUseCase {}
class MockLogoutUseCase extends Mock implements LogoutUseCase {}
class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

void main() {
  late MockLoginUseCase mockLoginUseCase;
  late MockGetCurrentUserUseCase mockGetCurrentUserUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockResetPasswordUseCase mockResetPasswordUseCase;
  late AuthController controller;

  const testUser = User(
    id: 'uid_test_123',
    email: 'student@cse.jnu.ac.bd',
    fullName: 'Sajib Ahmed',
    role: UserRole.student,
    studentId: '2020CSE042',
    year: 3,
    semester: 1,
  );

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockGetCurrentUserUseCase = MockGetCurrentUserUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
    mockResetPasswordUseCase = MockResetPasswordUseCase();

    controller = AuthController(
      loginUseCase: mockLoginUseCase,
      getCurrentUserUseCase: mockGetCurrentUserUseCase,
      logoutUseCase: mockLogoutUseCase,
      resetPasswordUseCase: mockResetPasswordUseCase,
    );
  });

  group('Firebase AuthController & Role Lifecycle Tests', () {
    test('initial state is AuthInitial', () {
      expect(controller.state, const AuthInitial());
      expect(controller.currentUser, isNull);
      expect(controller.isAuthenticated, false);
    });

    test('login success sets Authenticated state with user and role', () async {
      when(() => mockLoginUseCase.execute(
            email: 'student@cse.jnu.ac.bd',
            password: 'Password123!',
          )).thenAnswer((_) async => testUser);

      final result = await controller.login(
        email: 'student@cse.jnu.ac.bd',
        password: 'Password123!',
      );

      expect(result, true);
      expect(controller.state, const Authenticated(user: testUser));
      expect(controller.currentUser?.role, UserRole.student);
      expect(controller.isAuthenticated, true);
    });

    test('login invalid credentials failure sets AuthError state', () async {
      when(() => mockLoginUseCase.execute(
            email: 'wrong@cse.jnu.ac.bd',
            password: 'WrongPassword',
          )).thenThrow(const AuthFailure(message: 'Invalid email or password.'));

      final result = await controller.login(
        email: 'wrong@cse.jnu.ac.bd',
        password: 'WrongPassword',
      );

      expect(result, false);
      expect(controller.state, const AuthError(message: 'Invalid email or password.', code: 'UNAUTHENTICATED'));
      expect(controller.isAuthenticated, false);
    });

    test('login with disabled account sets AuthAccountDisabled state', () async {
      when(() => mockLoginUseCase.execute(
            email: 'disabled@cse.jnu.ac.bd',
            password: 'Password123!',
          )).thenThrow(const AuthFailure(message: 'This account has been disabled by the administrator.'));

      final result = await controller.login(
        email: 'disabled@cse.jnu.ac.bd',
        password: 'Password123!',
      );

      expect(result, false);
      expect(controller.state, isA<AuthAccountDisabled>());
      expect((controller.state as AuthAccountDisabled).message, contains('disabled'));
    });

    test('checkAuthStatus restores session if active and valid', () async {
      when(() => mockGetCurrentUserUseCase.hasValidSession()).thenAnswer((_) async => true);
      when(() => mockGetCurrentUserUseCase.execute()).thenAnswer((_) async => testUser);

      await controller.checkAuthStatus();

      expect(controller.state, const Authenticated(user: testUser));
      expect(controller.currentUser?.fullName, 'Sajib Ahmed');
    });

    test('checkAuthStatus transitions to Unauthenticated when no active session', () async {
      when(() => mockGetCurrentUserUseCase.hasValidSession()).thenAnswer((_) async => false);

      await controller.checkAuthStatus();

      expect(controller.state, const Unauthenticated());
    });

    test('checkAuthStatus handles expired token failure and sets Unauthenticated', () async {
      when(() => mockGetCurrentUserUseCase.hasValidSession()).thenAnswer((_) async => true);
      when(() => mockGetCurrentUserUseCase.execute())
          .thenThrow(const AuthFailure(message: 'Session expired. Please log in again.'));

      await controller.checkAuthStatus();

      expect(controller.state, const Unauthenticated(reason: 'Session expired. Please log in again.'));
    });

    test('checkAuthStatus sets AuthAccountDisabled if user was deactivated during session', () async {
      when(() => mockGetCurrentUserUseCase.hasValidSession()).thenAnswer((_) async => true);
      when(() => mockGetCurrentUserUseCase.execute())
          .thenThrow(const AuthFailure(message: 'Account has been deactivated.'));

      await controller.checkAuthStatus();

      expect(controller.state, isA<AuthAccountDisabled>());
    });

    test('resetPassword sends email and returns true on success', () async {
      when(() => mockResetPasswordUseCase.execute('student@cse.jnu.ac.bd'))
          .thenAnswer((_) async {});

      final result = await controller.resetPassword('student@cse.jnu.ac.bd');

      expect(result, true);
      verify(() => mockResetPasswordUseCase.execute('student@cse.jnu.ac.bd')).called(1);
    });

    test('logout executes LogoutUseCase and sets Unauthenticated', () async {
      when(() => mockLogoutUseCase.execute()).thenAnswer((_) async {});

      await controller.logout();

      expect(controller.state, const Unauthenticated());
      expect(controller.currentUser, isNull);
    });
  });
}
