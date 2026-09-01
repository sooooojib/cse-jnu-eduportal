import '../repositories/auth_repository.dart';

class SignupRequestUseCase {
  final AuthRepository repository;

  SignupRequestUseCase({required this.repository});

  Future<String> execute({
    required String fullName,
    required String email,
    required String role,
    String? studentId,
    String? phone,
  }) {
    return repository.submitSignupRequest(
      fullName: fullName,
      email: email,
      role: role,
      studentId: studentId,
      phone: phone,
    );
  }
}
