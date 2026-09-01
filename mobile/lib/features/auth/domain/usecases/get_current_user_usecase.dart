import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUseCase {
  final AuthRepository repository;

  GetCurrentUserUseCase({required this.repository});

  Future<User> execute() {
    return repository.getCurrentUser();
  }

  Future<bool> hasValidSession() {
    return repository.hasValidSession();
  }
}
