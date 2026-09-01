import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository repository;

  const ResetPasswordUseCase({required this.repository});

  Future<void> execute(String email) async {
    return repository.sendPasswordResetEmail(email);
  }
}
