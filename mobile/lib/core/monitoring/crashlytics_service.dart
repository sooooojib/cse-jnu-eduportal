import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../logging/app_logger.dart';

/// Contract for managing application crash reporting and diagnostics.
abstract class CrashlyticsService {
  Future<void> initialize();
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    bool fatal = false,
    Map<String, Object>? extraContext,
  });
  Future<void> recordFlutterError(FlutterErrorDetails details, {bool fatal = false});
  Future<void> setCustomKey(String key, Object value);
  Future<void> setSafeUserContext({
    required String uid,
    required String role,
    int? year,
    int? semester,
  });
  Future<void> clearUserContext();
  Future<void> log(String message);
  Future<void> sendTestReport();
  Future<void> setCollectionEnabled(bool enabled);
  bool get isCollectionEnabled;
}

/// Sanitizer that guarantees privacy compliance by filtering sensitive tokens,
/// credentials, and unnecessary PII from diagnostics before sending to Firebase.
class CrashlyticsContextSanitizer {
  static final RegExp _disallowedKeyPattern = RegExp(
    r'(password|token|secret|key|auth|credential|pin|otp|phone|email|comment|feedback)',
    caseSensitive: false,
  );

  static final RegExp _jwtPattern = RegExp(r'ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}');
  static final RegExp _bearerPattern = RegExp(r'Bearer\s+[A-Za-z0-9._-]+', caseSensitive: false);

  /// Sanitizes key-value maps to prevent logging sensitive information.
  static Map<String, Object> sanitizeMap(Map<String, Object>? input) {
    if (input == null || input.isEmpty) return {};

    final sanitized = <String, Object>{};
    for (final entry in input.entries) {
      if (_disallowedKeyPattern.hasMatch(entry.key)) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        final valStr = entry.value.toString();
        sanitized[entry.key] = sanitizeString(valStr);
      }
    }
    return sanitized;
  }

  /// Sanitizes string logs and messages to strip credentials and tokens.
  static String sanitizeString(String message) {
    var result = message;
    if (_bearerPattern.hasMatch(result)) {
      result = result.replaceAll(_bearerPattern, 'Bearer [REDACTED]');
    }
    if (_jwtPattern.hasMatch(result)) {
      result = result.replaceAll(_jwtPattern, '[REDACTED_JWT]');
    }
    return result;
  }
}

/// Production implementation of [CrashlyticsService] backed by Firebase Crashlytics.
class CrashlyticsServiceImpl implements CrashlyticsService {
  final FirebaseCrashlytics _crashlytics;
  bool _isCollectionEnabled = false;

  CrashlyticsServiceImpl({FirebaseCrashlytics? crashlytics})
      : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  @override
  bool get isCollectionEnabled => _isCollectionEnabled;

  @override
  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        // Crashlytics is not currently supported on web; no-op safely
        _isCollectionEnabled = false;
        AppLogger.i('Firebase Crashlytics not active on web platform.');
        return;
      }

      // In production release builds, collection is always enabled.
      // In debug/profile builds, disabled by default unless explicitly toggled for development tests.
      final shouldEnable = !kDebugMode;
      await _crashlytics.setCrashlyticsCollectionEnabled(shouldEnable);
      _isCollectionEnabled = shouldEnable;

      // Set standard non-sensitive application metadata
      await _crashlytics.setCustomKey('platform', defaultTargetPlatform.name);
      await _crashlytics.setCustomKey('build_mode', kDebugMode ? 'debug' : (kReleaseMode ? 'release' : 'profile'));

      AppLogger.i('Firebase Crashlytics initialized (collectionEnabled: $_isCollectionEnabled).');
    } catch (e, st) {
      _isCollectionEnabled = false;
      AppLogger.w('Failed to initialize Firebase Crashlytics gracefully: $e', e, st);
    }
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    bool fatal = false,
    Map<String, Object>? extraContext,
  }) async {
    try {
      if (extraContext != null && extraContext.isNotEmpty) {
        final sanitizedContext = CrashlyticsContextSanitizer.sanitizeMap(extraContext);
        for (final entry in sanitizedContext.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value);
        }
      }

      final sanitizedReason = reason != null
          ? CrashlyticsContextSanitizer.sanitizeString(reason.toString())
          : null;

      await _crashlytics.recordError(
        exception,
        stack,
        reason: sanitizedReason,
        fatal: fatal,
      );
    } catch (e) {
      AppLogger.w('Crashlytics recordError failed: $e');
    }
  }

  @override
  Future<void> recordFlutterError(FlutterErrorDetails details, {bool fatal = false}) async {
    try {
      await _crashlytics.recordFlutterError(details, fatal: fatal);
    } catch (e) {
      AppLogger.w('Crashlytics recordFlutterError failed: $e');
    }
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    try {
      if (CrashlyticsContextSanitizer._disallowedKeyPattern.hasMatch(key)) {
        AppLogger.w('Refusing to set sensitive key in Crashlytics: $key');
        return;
      }

      final sanitizedValue = CrashlyticsContextSanitizer.sanitizeString(value.toString());
      await _crashlytics.setCustomKey(key, sanitizedValue);
    } catch (e) {
      AppLogger.w('Crashlytics setCustomKey failed: $e');
    }
  }

  @override
  Future<void> setSafeUserContext({
    required String uid,
    required String role,
    int? year,
    int? semester,
  }) async {
    try {
      // 1. Set opaque user UID (no names, emails, or personal identifiers)
      await _crashlytics.setUserIdentifier(uid);

      // 2. Set safe role and academic status
      await _crashlytics.setCustomKey('user_role', role);
      if (year != null) await _crashlytics.setCustomKey('user_year', year);
      if (semester != null) await _crashlytics.setCustomKey('user_semester', semester);

      AppLogger.i('Crashlytics user context safely registered (role: $role).');
    } catch (e) {
      AppLogger.w('Failed to set Crashlytics user context: $e');
    }
  }

  @override
  Future<void> clearUserContext() async {
    try {
      await _crashlytics.setUserIdentifier('');
      await _crashlytics.setCustomKey('user_role', 'ANONYMOUS');
      await _crashlytics.setCustomKey('user_year', 0);
      await _crashlytics.setCustomKey('user_semester', 0);
      AppLogger.i('Crashlytics user context cleared.');
    } catch (e) {
      AppLogger.w('Failed to clear Crashlytics user context: $e');
    }
  }

  @override
  Future<void> log(String message) async {
    try {
      final sanitized = CrashlyticsContextSanitizer.sanitizeString(message);
      await _crashlytics.log(sanitized);
    } catch (e) {
      AppLogger.w('Crashlytics log failed: $e');
    }
  }

  @override
  Future<void> sendTestReport() async {
    try {
      AppLogger.i('Dispatching controlled Firebase Crashlytics test diagnostic event...');
      await recordError(
        StateError('CSE JnU EduPortal Controlled Crashlytics Verification Event'),
        StackTrace.current,
        reason: 'Manual Developer Diagnostics Verification',
        fatal: false,
        extraContext: {
          'test_event': 'true',
          'diagnostics': 'verified',
        },
      );
      AppLogger.i('Controlled Crashlytics test event dispatched successfully.');
    } catch (e) {
      AppLogger.w('Failed to send Crashlytics test report: $e');
    }
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
      _isCollectionEnabled = enabled;
      AppLogger.i('Crashlytics collection enabled set to: $enabled');
    } catch (e) {
      AppLogger.w('Failed to set Crashlytics collection state: $e');
    }
  }
}
