import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cse_jnu_eduportal/core/storage/secure_storage_service.dart';
import 'package:cse_jnu_eduportal/core/constants/app_constants.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late SecureStorageServiceImpl secureStorageService;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    secureStorageService = SecureStorageServiceImpl(storage: mockStorage);
  });

  group('SecureStorageService', () {
    const testToken = 'sample_access_token_jwt';
    const testRefreshToken = 'sample_refresh_token_jwt';
    const testUserId = '11111111-2222-3333-4444-555555555555';
    const testRole = 'STUDENT';

    test('should save and retrieve access token', () async {
      when(() => mockStorage.write(key: AppConstants.keyAccessToken, value: testToken))
          .thenAnswer((_) async {});
      when(() => mockStorage.read(key: AppConstants.keyAccessToken))
          .thenAnswer((_) async => testToken);

      await secureStorageService.setAccessToken(testToken);
      final result = await secureStorageService.getAccessToken();

      expect(result, testToken);
      verify(() => mockStorage.write(key: AppConstants.keyAccessToken, value: testToken)).called(1);
      verify(() => mockStorage.read(key: AppConstants.keyAccessToken)).called(1);
    });

    test('should save and retrieve refresh token', () async {
      when(() => mockStorage.write(key: AppConstants.keyRefreshToken, value: testRefreshToken))
          .thenAnswer((_) async {});
      when(() => mockStorage.read(key: AppConstants.keyRefreshToken))
          .thenAnswer((_) async => testRefreshToken);

      await secureStorageService.setRefreshToken(testRefreshToken);
      final result = await secureStorageService.getRefreshToken();

      expect(result, testRefreshToken);
    });

    test('should save and retrieve user id and role', () async {
      when(() => mockStorage.write(key: AppConstants.keyUserId, value: testUserId))
          .thenAnswer((_) async {});
      when(() => mockStorage.read(key: AppConstants.keyUserId))
          .thenAnswer((_) async => testUserId);
      when(() => mockStorage.write(key: AppConstants.keyUserRole, value: testRole))
          .thenAnswer((_) async {});
      when(() => mockStorage.read(key: AppConstants.keyUserRole))
          .thenAnswer((_) async => testRole);

      await secureStorageService.setUserId(testUserId);
      await secureStorageService.setUserRole(testRole);

      expect(await secureStorageService.getUserId(), testUserId);
      expect(await secureStorageService.getUserRole(), testRole);
    });

    test('should clear all session tokens on logout', () async {
      when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      await secureStorageService.clearSession();

      verify(() => mockStorage.delete(key: AppConstants.keyAccessToken)).called(1);
      verify(() => mockStorage.delete(key: AppConstants.keyRefreshToken)).called(1);
      verify(() => mockStorage.delete(key: AppConstants.keyUserId)).called(1);
      verify(() => mockStorage.delete(key: AppConstants.keyUserRole)).called(1);
    });
  });
}
