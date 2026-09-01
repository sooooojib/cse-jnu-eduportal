import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with `Firebase.initializeApp()`.
///
/// Generated and configured for project: `sajib-73b14`
class DefaultFirebaseOptions {
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'production',
  );

  static bool get isProduction => environment == 'production';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB4jae-WiPeCGo6zYQ1b6IQDKTyHZYgZ6Q',
    appId: '1:685171866402:web:9c97e6831a32a9642d037b',
    messagingSenderId: '685171866402',
    projectId: 'sajib-73b14',
    authDomain: 'sajib-73b14.firebaseapp.com',
    storageBucket: 'sajib-73b14.firebasestorage.app',
    measurementId: 'G-87X20PFQF7',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBLIjwgv-TBkSghNH7wwBXq72G_gk-dvj0',
    appId: '1:685171866402:android:2bf560d9bc8b3d582d037b',
    messagingSenderId: '685171866402',
    projectId: 'sajib-73b14',
    storageBucket: 'sajib-73b14.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBLIjwgv-TBkSghNH7wwBXq72G_gk-dvj0',
    appId: '1:685171866402:ios:2bf560d9bc8b3d582d037b',
    messagingSenderId: '685171866402',
    projectId: 'sajib-73b14',
    storageBucket: 'sajib-73b14.firebasestorage.app',
    iosClientId: '685171866402-client.apps.googleusercontent.com',
    iosBundleId: 'bd.ac.jnu.cse.cseJnuEduportal',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBLIjwgv-TBkSghNH7wwBXq72G_gk-dvj0',
    appId: '1:685171866402:ios:2bf560d9bc8b3d582d037b',
    messagingSenderId: '685171866402',
    projectId: 'sajib-73b14',
    storageBucket: 'sajib-73b14.firebasestorage.app',
    iosClientId: '685171866402-client.apps.googleusercontent.com',
    iosBundleId: 'bd.ac.jnu.cse.cseJnuEduportal',
  );
}
