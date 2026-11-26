import 'dart:async';
import 'package:cse_jnu_eduportal/core/config/app_check_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAppCheck extends Mock implements FirebaseAppCheck {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(AndroidProvider.playIntegrity);
    registerFallbackValue(AppleProvider.appAttestWithDeviceCheckFallback);
  });

  group('STAGE 32: Firebase App Check Service Tests', () {
    late MockFirebaseAppCheck mockAppCheck;
    late AppCheckServiceImpl service;

    setUp(() {
      mockAppCheck = MockFirebaseAppCheck();
      service = AppCheckServiceImpl(appCheck: mockAppCheck);
    });

    test('1. Initial state is uninitialized and inactive', () {
      expect(service.isActivated, isFalse);
      expect(service.activeProviderName, 'uninitialized');
    });

    test('2. activate(isDebug: true) configures Debug providers and enables auto-refresh', () async {
      when(() => mockAppCheck.activate(
            androidProvider: any(named: 'androidProvider'),
            appleProvider: any(named: 'appleProvider'),
          )).thenAnswer((_) async {});
      when(() => mockAppCheck.setTokenAutoRefreshEnabled(any()))
          .thenAnswer((_) async {});

      await service.activate(isDebug: true);

      expect(service.isActivated, isTrue);
      expect(service.activeProviderName, contains('debug'));
      verify(() => mockAppCheck.activate(
            androidProvider: AndroidProvider.debug,
            appleProvider: AppleProvider.debug,
          )).called(1);
      verify(() => mockAppCheck.setTokenAutoRefreshEnabled(true)).called(1);
    });

    test('3. activate(isDebug: false) configures Production Play Integrity and App Attest', () async {
      when(() => mockAppCheck.activate(
            androidProvider: any(named: 'androidProvider'),
            appleProvider: any(named: 'appleProvider'),
          )).thenAnswer((_) async {});
      when(() => mockAppCheck.setTokenAutoRefreshEnabled(any()))
          .thenAnswer((_) async {});

      await service.activate(isDebug: false);

      expect(service.isActivated, isTrue);
      expect(service.activeProviderName, anyOf(contains('playIntegrity'), contains('PlayIntegrity'), contains('AppAttest')));
      verify(() => mockAppCheck.activate(
            androidProvider: AndroidProvider.playIntegrity,
            appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
          )).called(1);
      verify(() => mockAppCheck.setTokenAutoRefreshEnabled(true)).called(1);
    });

    test('4. Gracefully catches exceptions during activate without throwing', () async {
      when(() => mockAppCheck.activate(
            androidProvider: any(named: 'androidProvider'),
            appleProvider: any(named: 'appleProvider'),
          )).thenThrow(Exception('Google Play services unavailable'));

      await service.activate(isDebug: false);

      expect(service.isActivated, isFalse);
      expect(service.activeProviderName, 'activation_failed');
    });

    test('5. getToken delegates to FirebaseAppCheck and returns attestation token', () async {
      when(() => mockAppCheck.getToken(any()))
          .thenAnswer((_) async => 'valid-app-check-token-xyz');

      final token = await service.getToken(forceRefresh: true);

      expect(token, 'valid-app-check-token-xyz');
      verify(() => mockAppCheck.getToken(true)).called(1);
    });

    test('6. getToken gracefully handles platform errors and returns null', () async {
      when(() => mockAppCheck.getToken(any()))
          .thenThrow(Exception('Attestation server unreachable'));

      final token = await service.getToken();

      expect(token, isNull);
    });

    test('7. getLimitedUseToken retrieves single-use token', () async {
      when(() => mockAppCheck.getLimitedUseToken())
          .thenAnswer((_) async => 'limited-use-token-123');

      final token = await service.getLimitedUseToken();

      expect(token, 'limited-use-token-123');
      verify(() => mockAppCheck.getLimitedUseToken()).called(1);
    });

    test('8. getLimitedUseToken returns null on failure without throwing', () async {
      when(() => mockAppCheck.getLimitedUseToken())
          .thenThrow(Exception('Network timeout'));

      final token = await service.getLimitedUseToken();

      expect(token, isNull);
    });

    test('9. setAutoRefreshEnabled delegates to underlying client', () async {
      when(() => mockAppCheck.setTokenAutoRefreshEnabled(any()))
          .thenAnswer((_) async {});

      await service.setAutoRefreshEnabled(false);

      verify(() => mockAppCheck.setTokenAutoRefreshEnabled(false)).called(1);
    });

    test('10. onTokenChange stream exposes token rotation events', () async {
      final controller = StreamController<String?>();
      when(() => mockAppCheck.onTokenChange)
          .thenAnswer((_) => controller.stream);

      final emissions = <String?>[];
      final sub = service.onTokenChange.listen(emissions.add);

      controller.add('initial-token');
      controller.add('rotated-token');
      await Future.delayed(const Duration(milliseconds: 10));

      expect(emissions, ['initial-token', 'rotated-token']);
      await sub.cancel();
      await controller.close();
    });
  });
}
