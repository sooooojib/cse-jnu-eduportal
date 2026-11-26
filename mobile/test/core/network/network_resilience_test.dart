import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cse_jnu_eduportal/core/error/exceptions.dart';
import 'package:cse_jnu_eduportal/core/error/failures.dart';
import 'package:cse_jnu_eduportal/core/network/authoritative_guard.dart';
import 'package:cse_jnu_eduportal/core/network/cache_metadata.dart';
import 'package:cse_jnu_eduportal/core/network/network_info.dart';
import 'package:cse_jnu_eduportal/core/network/safe_retry_policy.dart';
import 'package:cse_jnu_eduportal/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';
import 'package:cse_jnu_eduportal/features/counseling/data/repositories/counseling_repository_impl.dart';
import 'package:cse_jnu_eduportal/shared/widgets/states/app_error_state_view.dart';
import 'package:cse_jnu_eduportal/shared/widgets/states/cached_data_badge.dart';
import 'package:cse_jnu_eduportal/shared/widgets/states/offline_connectivity_banner.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockFirebaseAuth extends Mock implements fb.FirebaseAuth {}
class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}
class MockUser extends Mock implements fb.User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('STAGE 31: 1. Network Connectivity & Monitoring Tests', () {
    test('NetworkInfo reports online when host lookup succeeds', () async {
      final networkInfo = NetworkInfoImpl(
        hostLookup: (host) async => [InternetAddress('8.8.8.8')],
        startMonitoring: false,
      );

      final status = await networkInfo.checkConnectivity();
      expect(status, NetworkStatus.online);
      expect(await networkInfo.isConnected, isTrue);
      expect(await networkInfo.isServerReachable, isTrue);

      networkInfo.dispose();
    });

    test('NetworkInfo reports offline when host lookup throws SocketException', () async {
      final networkInfo = NetworkInfoImpl(
        hostLookup: (host) async => throw const SocketException('Network unreachable'),
        startMonitoring: false,
      );

      final status = await networkInfo.checkConnectivity();
      expect(status, NetworkStatus.offline);
      expect(await networkInfo.isConnected, isFalse);

      networkInfo.dispose();
    });

    test('NetworkInfo reports offline on timeout', () async {
      final networkInfo = NetworkInfoImpl(
        hostLookup: (host) async {
          await Future.delayed(const Duration(milliseconds: 100));
          throw TimeoutException('Timed out');
        },
        probeTimeout: const Duration(milliseconds: 50),
        startMonitoring: false,
      );

      final status = await networkInfo.checkConnectivity();
      expect(status, NetworkStatus.offline);
      expect(await networkInfo.isConnected, isFalse);

      networkInfo.dispose();
    });

    test('NetworkInfo emits reconnected then online on network restoration', () async {
      int callCount = 0;
      final networkInfo = NetworkInfoImpl(
        hostLookup: (host) async {
          callCount++;
          if (callCount == 1) throw const SocketException('No route');
          return [InternetAddress('8.8.8.8')];
        },
        startMonitoring: false,
      );

      // First check: offline
      final status1 = await networkInfo.checkConnectivity();
      expect(status1, NetworkStatus.offline);

      // Second check: connection restored
      final status2 = await networkInfo.checkConnectivity();
      expect(status2, NetworkStatus.reconnected);

      networkInfo.dispose();
    });
  });

  group('STAGE 31: 2. Safe Retry & Idempotency Tests', () {
    test('SafeRetryPolicy successfully retries transient timeout error', () async {
      int attempts = 0;
      final result = await SafeRetryPolicy.execute<String>(
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 10),
        action: () async {
          attempts++;
          if (attempts < 3) {
            throw TimeoutException('Connection timed out');
          }
          return 'SUCCESS_DATA';
        },
      );

      expect(result, 'SUCCESS_DATA');
      expect(attempts, 3);
    });

    test('SafeRetryPolicy does NOT retry non-retryable validation error', () async {
      int attempts = 0;
      expect(
        () => SafeRetryPolicy.execute<String>(
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 10),
          action: () async {
            attempts++;
            throw const ValidationException(
              message: 'Invalid input',
              validationErrors: [],
            );
          },
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(attempts, 1);
    });

    test('SafeRetryPolicy blocks concurrent duplicate requests with identical idempotency key', () async {
      final completer = Completer<String>();

      // Launch first long-running request
      final future1 = SafeRetryPolicy.execute<String>(
        idempotencyKey: 'idempotent_test_key_123',
        action: () => completer.future,
      );

      // Attempt second request with the same idempotency key concurrently
      expect(
        () => SafeRetryPolicy.execute<String>(
          idempotencyKey: 'idempotent_test_key_123',
          action: () async => 'DUPLICATE',
        ),
        throwsA(isA<ValidationException>()),
      );

      completer.complete('DONE_1');
      expect(await future1, 'DONE_1');
    });
  });

  group('STAGE 31: 3. Authoritative Server-Side Validation Tests', () {
    test('AuthoritativeGuard rejects offline sensitive operations with clear failure', () async {
      final offlineNetwork = NetworkInfoImpl(
        hostLookup: (host) async => throw const SocketException('No internet'),
        startMonitoring: false,
      );
      await offlineNetwork.checkConnectivity();

      final guard = AuthoritativeGuard(networkInfo: offlineNetwork);

      expect(
        () => guard.ensureAuthoritativeServer(operationName: 'Attendance verification'),
        throwsA(isA<NetworkFailure>().having(
          (f) => f.message,
          'message',
          contains('requires an active internet connection'),
        )),
      );

      offlineNetwork.dispose();
    });

    test('AuthoritativeGuard allows sensitive operations when connected', () async {
      final onlineNetwork = NetworkInfoImpl(
        hostLookup: (host) async => [InternetAddress('8.8.8.8')],
        startMonitoring: false,
      );
      await onlineNetwork.checkConnectivity();

      final guard = AuthoritativeGuard(networkInfo: onlineNetwork);

      await expectLater(
        guard.ensureAuthoritativeServer(operationName: 'Attendance verification'),
        completes,
      );

      onlineNetwork.dispose();
    });
  });

  group('STAGE 31: 4. Security-Sensitive Operations Offline Rejection Tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFunctions mockFunctions;
    late MockUser mockUser;
    late NetworkInfo offlineNetwork;
    late AuthoritativeGuard offlineGuard;

    setUp(() async {
      mockFirestore = MockFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockFunctions = MockFirebaseFunctions();
      mockUser = MockUser();

      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn('test_student_uid');

      offlineNetwork = NetworkInfoImpl(
        hostLookup: (host) async => throw const SocketException('Offline'),
        startMonitoring: false,
      );
      await offlineNetwork.checkConnectivity();
      offlineGuard = AuthoritativeGuard(networkInfo: offlineNetwork);
    });

    tearDown(() {
      offlineNetwork.dispose();
    });

    test('Attendance verification fails explicitly when offline without producing false success', () async {
      final dataSource = AttendanceRemoteDataSourceImpl(
        firestore: mockFirestore,
        auth: mockAuth,
        functions: mockFunctions,
        authoritativeGuard: offlineGuard,
      );

      expect(
        () => dataSource.verifyCode('ABC123'),
        throwsA(isA<NetworkFailure>().having(
          (f) => f.message,
          'message',
          contains('requires an active internet connection'),
        )),
      );
    });

    test('Attendance session creation fails explicitly when offline', () async {
      final dataSource = AttendanceRemoteDataSourceImpl(
        firestore: mockFirestore,
        auth: mockAuth,
        functions: mockFunctions,
        authoritativeGuard: offlineGuard,
      );

      expect(
        () => dataSource.startSession(courseId: 'CSE-1101'),
        throwsA(isA<NetworkFailure>().having(
          (f) => f.message,
          'message',
          contains('requires an active internet connection'),
        )),
      );
    });

    test('Attendance roster update fails explicitly when offline', () async {
      final dataSource = AttendanceRemoteDataSourceImpl(
        firestore: mockFirestore,
        auth: mockAuth,
        functions: mockFunctions,
        authoritativeGuard: offlineGuard,
      );

      expect(
        () => dataSource.updateRoster(sessionId: 'sess_1', updates: []),
        throwsA(isA<NetworkFailure>().having(
          (f) => f.message,
          'message',
          contains('requires an active internet connection'),
        )),
      );
    });

    test('Admin signup approval fails explicitly when offline', () async {
      final adminDataSource = AdminRemoteDataSourceImpl(
        firestore: mockFirestore,
        functions: mockFunctions,
        authoritativeGuard: offlineGuard,
      );

      expect(
        () => adminDataSource.approveSignup(requestId: 'req_123'),
        throwsA(isA<NetworkFailure>().having(
          (f) => f.message,
          'message',
          contains('requires an active internet connection'),
        )),
      );
    });

    test('Admin user deletion fails explicitly when offline', () async {
      final adminDataSource = AdminRemoteDataSourceImpl(
        firestore: mockFirestore,
        functions: mockFunctions,
        authoritativeGuard: offlineGuard,
      );

      expect(
        () => adminDataSource.deleteUser(userId: 'user_target_99'),
        throwsA(isA<NetworkFailure>().having(
          (f) => f.message,
          'message',
          contains('requires an active internet connection'),
        )),
      );
    });

    test('Counseling appointment approval fails explicitly when offline', () async {
      final counselingDataSource = CounselingRemoteDataSourceImpl(
        firestore: mockFirestore,
        auth: mockAuth,
        functions: mockFunctions,
        authoritativeGuard: offlineGuard,
      );

      expect(
        () => counselingDataSource.approveBooking('booking_id_55'),
        throwsA(isA<NetworkFailure>().having(
          (f) => f.message,
          'message',
          contains('requires an active internet connection'),
        )),
      );
    });
  });

  group('STAGE 31: 5. Offline & Network UI Presentation Widgets Tests', () {
    testWidgets('OfflineConnectivityBanner displays when offline with Retry button', (tester) async {
      final networkInfo = NetworkInfoImpl(
        hostLookup: (host) async => throw const SocketException('Offline'),
        startMonitoring: false,
      );
      await networkInfo.checkConnectivity();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OfflineConnectivityBanner(networkInfo: networkInfo),
                const Text('Main Screen Content'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline Mode'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      networkInfo.dispose();
    });

    testWidgets('OfflineConnectivityBanner disappears when online', (tester) async {
      final networkInfo = NetworkInfoImpl(
        hostLookup: (host) async => [InternetAddress('8.8.8.8')],
        startMonitoring: false,
      );
      await networkInfo.checkConnectivity();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineConnectivityBanner(networkInfo: networkInfo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline Mode'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);

      networkInfo.dispose();
    });

    testWidgets('CachedDataBadge renders subtle notification when data is from cache', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CachedDataBadge(
              metadata: CacheMetadata.cached(
                message: 'Viewing cached student dashboard',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Viewing cached student dashboard'), findsOneWidget);
      expect(find.byIcon(Icons.offline_pin_outlined), findsOneWidget);
    });

    testWidgets('CachedDataBadge renders nothing when data is fresh from server', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CachedDataBadge(
              metadata: CacheMetadata.fresh,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('cached'), findsNothing);
    });

    testWidgets('AppErrorStateView auto-detects network failure and shows wifi_off icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorStateView(
              message: 'No internet connection detected. Please check your network.',
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
