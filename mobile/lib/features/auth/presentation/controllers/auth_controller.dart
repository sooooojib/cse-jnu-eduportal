import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/utils/server_clock.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/monitoring/crashlytics_service.dart';
import 'auth_state.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

class AuthController extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final LogoutUseCase logoutUseCase;
  final ResetPasswordUseCase? resetPasswordUseCase;
  final AuthRepository? authRepository;
  final PushNotificationService? pushNotificationService;
  final CrashlyticsService? crashlyticsService;

  AuthState _state = const AuthInitial();
  StreamSubscription<User?>? _authSubscription;

  AuthController({
    required this.loginUseCase,
    required this.getCurrentUserUseCase,
    required this.logoutUseCase,
    this.resetPasswordUseCase,
    this.authRepository,
    this.pushNotificationService,
    this.crashlyticsService,
  });

  void startAuthListener() {
    if (authRepository == null) return;
    _authSubscription?.cancel();
    _authSubscription = authRepository!.authStateChanges().listen(
      (user) {
        if (user != null) {
          if (!user.isActive) {
            _setState(const AuthAccountDisabled(
              message: 'Your account has been deactivated. Please contact CSE administration.',
            ));
          } else {
            _setState(Authenticated(user: user));
            pushNotificationService?.registerCurrentToken();
            unawaited(crashlyticsService?.setSafeUserContext(
              uid: user.id,
              role: user.role.name,
              year: user.year,
              semester: user.semester,
            ));
          }
        } else {
          if (_state is Authenticated) {
            _setState(const Unauthenticated(reason: 'Session ended or user profile removed.'));
            unawaited(crashlyticsService?.clearUserContext());
          }
        }
      },
      onError: (e) {
        _setState(AuthError(message: friendlyError(e)));
      },
    );
  }

  AuthState get state => _state;

  User? get currentUser => _state is Authenticated ? (_state as Authenticated).user : null;

  bool get isAuthenticated => _state is Authenticated;

  void updateUserProfile(User updatedUser) {
    if (_state is Authenticated) {
      _setState(Authenticated(user: updatedUser));
    }
  }

  /// Re-reads the signed-in user's profile (e.g. after a CR hand-over changed
  /// their role) without showing a loading screen. Failures keep the current
  /// state.
  Future<void> refreshCurrentUser() async {
    if (_state is! Authenticated) return;
    try {
      final user = await getCurrentUserUseCase.execute();
      _setState(Authenticated(user: user));
    } catch (_) {}
  }

  void _setState(AuthState newState) {
    final wasSignedIn = _state is Authenticated;
    _state = newState;
    notifyListeners();
    // S2-10: learn the server clock once per sign-in (for Bangladesh "today").
    if (newState is Authenticated && !wasSignedIn && syncServerClock) {
      final uid = newState.user.id;
      unawaited(() async {
        try {
          await ServerClock.sync(firestore: FirebaseFirestore.instance, uid: uid);
        } catch (_) {}
      }());
    }
  }

  /// Off in tests (no Firebase).
  static bool syncServerClock = true;

  Future<void> checkAuthStatus() async {
    _setState(const AuthLoading(message: 'Checking session...'));

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
    _setState(const AuthLoading(message: 'Signing in...'));

    try {
      final user = await loginUseCase.execute(email: email, password: password);
      _setState(Authenticated(user: user));
      unawaited(pushNotificationService?.registerCurrentToken());
      unawaited(crashlyticsService?.setSafeUserContext(
        uid: user.id,
        role: user.role.name,
        year: user.year,
        semester: user.semester,
      ));
      return true;
    } catch (failure) {
      if (failure is Failure) {
        if (failure.message.contains('deactivated') || failure.message.contains('disabled')) {
          _setState(AuthAccountDisabled(message: failure.message));
        } else {
          _setState(AuthError(message: failure.message, code: failure.code));
        }
      } else {
        _setState(AuthError(message: friendlyError(failure)));
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
        _setState(AuthError(message: friendlyError(failure)));
      }
      return false;
    }
  }

  Future<void> logout() async {
    _setState(const AuthLoading(message: 'Signing out...'));
    try {
      try {
        await pushNotificationService?.unregisterCurrentToken();
      } catch (e) {
        debugPrint('Logout push token removal error: $e');
      }
      await logoutUseCase.execute();
    } finally {
      unawaited(crashlyticsService?.clearUserContext());
      _setState(const Unauthenticated());
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
