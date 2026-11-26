import 'package:cse_jnu_eduportal/core/monitoring/crashlytics_service.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FlutterErrorDetails(exception: Exception()));
  });

  group('STAGE 33: Crashlytics Context Sanitizer Tests', () {
    test('1. sanitizeMap redacts disallowed keys while preserving safe diagnostic keys', () {
      final input = {
        'user_role': 'STUDENT',
        'screen': 'StudentAttendanceScreen',
        'password': 'PlainTextPassword!',
        'auth_token': 'secret-auth-token-123',
        'apiKey': 'AIzaSyFakeKey',
        'user_phone': '01711000000',
        'feedback_comment': 'Secret text',
      };

      final sanitized = CrashlyticsContextSanitizer.sanitizeMap(input);

      expect(sanitized['user_role'], 'STUDENT');
      expect(sanitized['screen'], 'StudentAttendanceScreen');
      expect(sanitized['password'], '[REDACTED]');
      expect(sanitized['auth_token'], '[REDACTED]');
      expect(sanitized['apiKey'], '[REDACTED]');
      expect(sanitized['user_phone'], '[REDACTED]');
      expect(sanitized['feedback_comment'], '[REDACTED]');
    });

    test('2. sanitizeString strips Bearer tokens and JWTs', () {
      const rawMsg =
          'Network request failed with header Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.doNotLeak';
      final sanitized = CrashlyticsContextSanitizer.sanitizeString(rawMsg);

      expect(sanitized, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(sanitized, contains('[REDACTED]'));
    });
  });

  group('STAGE 33: Crashlytics Service Production Implementation Tests', () {
    late MockFirebaseCrashlytics mockCrashlytics;
    late CrashlyticsServiceImpl service;

    setUp(() {
      mockCrashlytics = MockFirebaseCrashlytics();
      service = CrashlyticsServiceImpl(crashlytics: mockCrashlytics);

      when(() => mockCrashlytics.setCrashlyticsCollectionEnabled(any()))
          .thenAnswer((_) async {});
      when(() => mockCrashlytics.setCustomKey(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockCrashlytics.setUserIdentifier(any()))
          .thenAnswer((_) async {});
      when(() => mockCrashlytics.log(any())).thenAnswer((_) async {});
      when(() => mockCrashlytics.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
            fatal: any(named: 'fatal'),
            information: any(named: 'information'),
            printDetails: any(named: 'printDetails'),
          )).thenAnswer((_) async {});
      when(() => mockCrashlytics.recordFlutterError(any(),
              fatal: any(named: 'fatal')))
          .thenAnswer((_) async {});
    });

    test('1. initialize configures metadata and sets collection state', () async {
      await service.initialize();

      verify(() => mockCrashlytics.setCustomKey('platform', any())).called(1);
      verify(() => mockCrashlytics.setCustomKey('build_mode', any())).called(1);
      verify(() => mockCrashlytics.setCrashlyticsCollectionEnabled(any())).called(1);
    });

    test('2. setCustomKey blocks sensitive keys from being registered', () async {
      await service.setCustomKey('password', '123456');
      await service.setCustomKey('authToken', 'token-abc');
      await service.setCustomKey('safe_screen', 'HomeScreen');

      verifyNever(() => mockCrashlytics.setCustomKey('password', any()));
      verifyNever(() => mockCrashlytics.setCustomKey('authToken', any()));
      verify(() => mockCrashlytics.setCustomKey('safe_screen', 'HomeScreen')).called(1);
    });

    test('3. setSafeUserContext sets opaque UID and academic claims without PII', () async {
      await service.setSafeUserContext(
        uid: 'user_xyz_789',
        role: 'TEACHER',
        year: 3,
        semester: 1,
      );

      verify(() => mockCrashlytics.setUserIdentifier('user_xyz_789')).called(1);
      verify(() => mockCrashlytics.setCustomKey('user_role', 'TEACHER')).called(1);
      verify(() => mockCrashlytics.setCustomKey('user_year', 3)).called(1);
      verify(() => mockCrashlytics.setCustomKey('user_semester', 1)).called(1);
    });

    test('4. clearUserContext resets identifier and academic claims', () async {
      await service.clearUserContext();

      verify(() => mockCrashlytics.setUserIdentifier('')).called(1);
      verify(() => mockCrashlytics.setCustomKey('user_role', 'ANONYMOUS')).called(1);
      verify(() => mockCrashlytics.setCustomKey('user_year', 0)).called(1);
      verify(() => mockCrashlytics.setCustomKey('user_semester', 0)).called(1);
    });

    test('5. recordError sanitizes extraContext and records non-fatal exception', () async {
      final testError = StateError('Controlled test error');
      final testStack = StackTrace.current;

      await service.recordError(
        testError,
        testStack,
        reason: 'Testing diagnostic pipeline with Bearer secretToken',
        fatal: false,
        extraContext: {
          'feature': 'Attendance',
          'auth_token': 'secret-token',
        },
      );

      verify(() => mockCrashlytics.setCustomKey('feature', 'Attendance')).called(1);
      verify(() => mockCrashlytics.setCustomKey('auth_token', '[REDACTED]')).called(1);
      verify(() => mockCrashlytics.recordError(
            testError,
            testStack,
            reason: any(named: 'reason', that: isNot(contains('secretToken'))),
            fatal: false,
          )).called(1);
    });

    test('6. recordFlutterError forwards framework error details', () async {
      final details = FlutterErrorDetails(
        exception: Exception('Framework rendering error'),
      );

      await service.recordFlutterError(details, fatal: true);

      verify(() => mockCrashlytics.recordFlutterError(details, fatal: true)).called(1);
    });

    test('7. log sanitizes messages before logging', () async {
      await service.log('User signed in with Bearer rawAccessToken123');

      verify(() => mockCrashlytics.log('User signed in with Bearer [REDACTED]')).called(1);
    });

    test('8. sendTestReport dispatches controlled non-fatal event', () async {
      await service.sendTestReport();

      verify(() => mockCrashlytics.recordError(
            any(that: isA<StateError>()),
            any(),
            reason: any(named: 'reason'),
            fatal: false,
          )).called(1);
    });
  });
}
