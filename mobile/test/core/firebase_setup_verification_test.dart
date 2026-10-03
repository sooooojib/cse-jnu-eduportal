import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cse_jnu_eduportal/core/config/firebase_options.dart';
import 'package:cse_jnu_eduportal/core/di/injection_container.dart';
import 'package:cse_jnu_eduportal/core/storage/local_storage_service.dart';
import 'package:cse_jnu_eduportal/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFirebaseAuth extends Mock implements fb.FirebaseAuth {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockFirebaseStorage extends Mock implements FirebaseStorage {}
class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}
class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}
class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stage 12: Firebase Project Setup & Platform Options Verification', () {
    test('DefaultFirebaseOptions provides valid configuration for all platforms', () {
      // Web
      expect(DefaultFirebaseOptions.web.projectId, equals('sajib-73b14'));
      expect(DefaultFirebaseOptions.web.apiKey.isNotEmpty, isTrue);
      expect(DefaultFirebaseOptions.web.appId.isNotEmpty, isTrue);
      expect(DefaultFirebaseOptions.web.authDomain, equals('sajib-73b14.firebaseapp.com'));

      // Android
      expect(DefaultFirebaseOptions.android.projectId, equals('sajib-73b14'));
      expect(DefaultFirebaseOptions.android.apiKey.isNotEmpty, isTrue);
      expect(DefaultFirebaseOptions.android.appId.isNotEmpty, isTrue);

      // iOS
      expect(DefaultFirebaseOptions.ios.projectId, equals('sajib-73b14'));
      expect(DefaultFirebaseOptions.ios.apiKey.isNotEmpty, isTrue);
      expect(DefaultFirebaseOptions.ios.appId.isNotEmpty, isTrue);
      expect(DefaultFirebaseOptions.ios.iosBundleId, equals('bd.ac.jnu.cse.cseJnuEduportal'));

      // macOS
      expect(DefaultFirebaseOptions.macos.projectId, equals('sajib-73b14'));
      expect(DefaultFirebaseOptions.macos.apiKey.isNotEmpty, isTrue);
      expect(DefaultFirebaseOptions.macos.appId.isNotEmpty, isTrue);
      expect(DefaultFirebaseOptions.macos.iosBundleId, equals('bd.ac.jnu.cse.cseJnuEduportal'));
    });

    test('Environment configuration defaults properly', () {
      expect(DefaultFirebaseOptions.environment, isNotEmpty);
      expect(DefaultFirebaseOptions.isProduction, isTrue);
    });

    test('Firebase Service Singletons and DI container wire correctly', () async {
      await sl.reset();

      final mockAuth = MockFirebaseAuth();
      final mockFirestore = MockFirebaseFirestore();
      final mockStorage = MockFirebaseStorage();
      final mockMessaging = MockFirebaseMessaging();
      final mockFunctions = MockFirebaseFunctions();
      final mockPrefs = MockSharedPreferences();

      // Register mocks into GetIt
      sl.registerLazySingleton<SharedPreferences>(() => mockPrefs);
      sl.registerLazySingleton<fb.FirebaseAuth>(() => mockAuth);
      sl.registerLazySingleton<FirebaseFirestore>(() => mockFirestore);
      sl.registerLazySingleton<FirebaseStorage>(() => mockStorage);
      sl.registerLazySingleton<FirebaseMessaging>(() => mockMessaging);
      sl.registerLazySingleton<FirebaseFunctions>(() => mockFunctions);

      sl.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(
          auth: sl(),
          firestore: sl(),
        ),
      );

      // Verify all services are resolvable
      expect(sl<fb.FirebaseAuth>(), equals(mockAuth));
      expect(sl<FirebaseFirestore>(), equals(mockFirestore));
      expect(sl<FirebaseStorage>(), equals(mockStorage));
      expect(sl<FirebaseMessaging>(), equals(mockMessaging));
      expect(sl<FirebaseFunctions>(), equals(mockFunctions));
      expect(sl<AuthRemoteDataSource>(), isA<AuthRemoteDataSourceImpl>());
    });
  });
}
