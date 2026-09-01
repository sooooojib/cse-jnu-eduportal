import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase({required this.repository});

  Future<User> execute({required String email, required String password}) {
    return repository.login(email: email, password: password);
  }
}
