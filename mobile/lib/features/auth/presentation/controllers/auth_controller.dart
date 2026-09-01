import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../../../core/error/failures.dart';
import 'auth_state.dart';

class AuthController extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final LogoutUseCase logoutUseCase;
  final ResetPasswordUseCase? resetPasswordUseCase;

  AuthState _state = const AuthInitial();
  StreamSubscription<User?>? _authSubscription;

  AuthController({
    required this.loginUseCase,
    required this.getCurrentUserUseCase,
    required this.logoutUseCase,
    this.resetPasswordUseCase,
  });

  AuthState get state => _state;

  User? get currentUser => _state is Authenticated ? (_state as Authenticated).user : null;

  bool get isAuthenticated => _state is Authenticated;

  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _setState(const AuthLoading());

    final hasSession = await getCurrentUserUseCase.hasValidSession();
    if (!hasSession) {
      _setState(const Unauthenticated());
      return;
    }

    try {
      final user = await getCurrentUserUseCase.execute();
      _setState(Authenticated(user: user));
    } catch (failure) {
      if (failure is Failure) {
        if (failure.message.contains('deactivated') || failure.message.contains('disabled')) {
          _setState(AuthAccountDisabled(message: failure.message));
        } else {
          _setState(Unauthenticated(reason: failure.message));
        }
      } else {
        _setState(const Unauthenticated(reason: 'Session expired. Please log in again.'));
      }
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setState(const AuthLoading());

    try {
      final user = await loginUseCase.execute(email: email, password: password);
      _setState(Authenticated(user: user));
      return true;
    } catch (failure) {
      if (failure is Failure) {
        if (failure.message.contains('deactivated') || failure.message.contains('disabled')) {
          _setState(AuthAccountDisabled(message: failure.message));
        } else {
          _setState(AuthError(message: failure.message, code: failure.code));
        }
      } else {
        _setState(AuthError(message: failure.toString()));
      }
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    if (resetPasswordUseCase == null) return false;
    try {
      await resetPasswordUseCase!.execute(email);
      return true;
    } catch (failure) {
      if (failure is Failure) {
        _setState(AuthError(message: failure.message, code: failure.code));
      } else {
        _setState(AuthError(message: failure.toString()));
      }
      return false;
    }
  }

  Future<void> logout() async {
    _setState(const AuthLoading());
    try {
      await logoutUseCase.execute();
    } finally {
      _setState(const Unauthenticated());
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
