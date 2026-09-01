import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/user_model.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/auth_response_model.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';

void main() {
  group('UserModel & AuthResponseModel', () {
    const testJson = {
      'id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      'email': 'student@cse.jnu.ac.bd',
      'fullName': 'Sajib Hossain',
      'role': 'STUDENT',
      'studentId': 'B210305015',
      'phone': null,
      'avatarUrl': null,
      'year': 3,
      'semester': 1,
      'semesterStatus': 'NONE',
    };

    test('should parse UserModel from JSON correctly', () {
      final user = UserModel.fromJson(testJson);

      expect(user.id, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
      expect(user.email, 'student@cse.jnu.ac.bd');
      expect(user.fullName, 'Sajib Hossain');
      expect(user.role, UserRole.student);
      expect(user.studentId, 'B210305015');
      expect(user.year, 3);
      expect(user.semester, 1);
    });

    test('should convert UserModel to JSON correctly', () {
      final user = UserModel.fromJson(testJson);
      final json = user.toJson();

      expect(json['email'], 'student@cse.jnu.ac.bd');
      expect(json['role'], 'STUDENT');
    });

    test('should parse AuthResponseModel with tokens and user', () {
      final authJson = {
        'accessToken': 'jwt_access_token',
        'refreshToken': 'jwt_refresh_token',
        'tokenType': 'Bearer',
        'expiresIn': 900,
        'user': testJson,
      };

      final authResponse = AuthResponseModel.fromJson(authJson);

      expect(authResponse.accessToken, 'jwt_access_token');
      expect(authResponse.refreshToken, 'jwt_refresh_token');
      expect(authResponse.user.role, UserRole.student);
    });
  });
}
