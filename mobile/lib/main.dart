import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/theme/theme_controller.dart';
import 'core/config/firebase_options.dart';
import 'core/di/injection_container.dart';
import 'core/logging/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    AppLogger.i('Initializing Firebase Core...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.i('Firebase Core initialized successfully.');

    // Configure Cloud Firestore settings (offline persistence)
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      AppLogger.i('Firestore offline persistence enabled.');
    } catch (e) {
      AppLogger.w('Firestore offline settings note: $e');
    }

    AppLogger.i('Bootstrapping CSE JnU EduPortal dependency container...');
    await initDependencies();
    AppLogger.i('Core dependencies initialized successfully.');
  } catch (e, stack) {
    AppLogger.e('Firebase / Bootstrap initialization note: $e', e, stack);
  }

  // Handle uncaught Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.e('Uncaught Flutter Error', details.exception, details.stack);
  };

  // Handle uncaught asynchronous platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Uncaught Asynchronous Error', error, stack);
    return true;
  };

  final themeController = sl<ThemeController>();

  runApp(CSEEduPortalApp(themeModeNotifier: themeController));
}
