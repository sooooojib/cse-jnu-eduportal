import '../entities/user.dart';

abstract class AuthRepository {
  Future<User> login({required String email, required String password});
  Future<User> getCurrentUser();
  Future<void> logout();
  Future<bool> hasValidSession();
  Stream<User?> authStateChanges();
  Future<void> sendPasswordResetEmail(String email);
  Future<String> submitSignupRequest({
    required String fullName,
    required String email,
    required String role,
    String? studentId,
    String? phone,
  });
}
