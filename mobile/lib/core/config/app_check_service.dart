import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';
import 'env_config.dart';

/// Contract for managing Firebase App Check attestation and lifecycle.
abstract class AppCheckService {
  Future<void> activate({bool? isDebug});
  Future<String?> getToken({bool forceRefresh = false});
  Future<String?> getLimitedUseToken();
  Future<void> setAutoRefreshEnabled(bool enabled);
  Stream<String?> get onTokenChange;
  bool get isActivated;
  String get activeProviderName;
}

/// Production implementation of [AppCheckService].
///
/// Follows modern Firebase App Check practices:
/// - Android: [AndroidProvider.playIntegrity] for production; [AndroidProvider.debug] for development.
///   (Note: SafetyNet is permanently deprecated by Google).
/// - iOS/macOS: [AppleProvider.appAttestWithDeviceCheckFallback] for production; [AppleProvider.debug] for development.
/// - Web: ReCaptcha v3 or debug token.
/// - Development debug tokens are output in debug mode and must never ship to production.
class AppCheckServiceImpl implements AppCheckService {
  final FirebaseAppCheck _appCheck;
  bool _isActivated = false;
  String _activeProviderName = 'uninitialized';

  AppCheckServiceImpl({FirebaseAppCheck? appCheck})
      : _appCheck = appCheck ?? FirebaseAppCheck.instance;

  @override
  bool get isActivated => _isActivated;

  @override
  String get activeProviderName => _activeProviderName;

  @override
  Stream<String?> get onTokenChange => _appCheck.onTokenChange;

  @override
  Future<void> activate({bool? isDebug}) async {
    final useDebug = isDebug ?? (kDebugMode || EnvConfig.current.environment != Environment.production);

    try {
      if (kIsWeb) {
        _activeProviderName = useDebug ? 'WebDebugProvider' : 'ReCaptchaV3';
        AppLogger.i('Activating Firebase App Check (Web): $_activeProviderName');
      } else {
        final androidProvider = useDebug ? AndroidProvider.debug : AndroidProvider.playIntegrity;
        final appleProvider = useDebug ? AppleProvider.debug : AppleProvider.appAttestWithDeviceCheckFallback;

        _activeProviderName = defaultTargetPlatform == TargetPlatform.android
            ? (useDebug ? 'AndroidProvider.debug' : 'AndroidProvider.playIntegrity')
            : (useDebug ? 'AppleProvider.debug' : 'AppleProvider.appAttestWithDeviceCheckFallback');

        AppLogger.i(
          'Activating Firebase App Check for $defaultTargetPlatform using $_activeProviderName (useDebug=$useDebug)',
        );

        await _appCheck.activate(
          androidProvider: androidProvider,
          appleProvider: appleProvider,
        );

        await _appCheck.setTokenAutoRefreshEnabled(true);
        _isActivated = true;
        AppLogger.i('Firebase App Check successfully activated ($_activeProviderName).');

        if (useDebug) {
          AppLogger.i(
            'App Check Debug Provider Active: To authorize this development device or emulator, '
            'copy the debug secret printed to adb logcat/console and register it in '
            'Firebase Console > App Check > Apps > Manage debug tokens.',
          );
        }
      }
    } catch (e, st) {
      _isActivated = false;
      _activeProviderName = 'activation_failed';
      AppLogger.w('Firebase App Check activation failed gracefully: $e', e, st);
    }
  }

  @override
  Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      return await _appCheck.getToken(forceRefresh);
    } catch (e) {
      AppLogger.w('Failed to retrieve App Check token: $e');
      return null;
    }
  }

  @override
  Future<String?> getLimitedUseToken() async {
    try {
      return await _appCheck.getLimitedUseToken();
    } catch (e) {
      AppLogger.w('Failed to retrieve limited-use App Check token: $e');
      return null;
    }
  }

  @override
  Future<void> setAutoRefreshEnabled(bool enabled) async {
    try {
      await _appCheck.setTokenAutoRefreshEnabled(enabled);
      AppLogger.i('App Check token auto-refresh set to: $enabled');
    } catch (e) {
      AppLogger.w('Failed to set App Check token auto-refresh: $e');
    }
  }
}
