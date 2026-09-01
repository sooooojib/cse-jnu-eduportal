import '../entities/user.dart';
import '../../../../core/constants/role_constants.dart';

abstract class UserRepository {
  Future<User> getUserById(String uid);
  Stream<User?> streamUser(String uid);
  Future<List<User>> getUsersByRole(UserRole role);
  Future<void> updateProfile({required String uid, String? phone, String? avatarUrl});
  Future<void> assignCoursesToTeacher({required String teacherId, required List<String> courseIds});
}
