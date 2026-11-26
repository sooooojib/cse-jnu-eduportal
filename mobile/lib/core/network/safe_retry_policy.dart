import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../error/exceptions.dart';
import '../error/failures.dart';
import '../logging/app_logger.dart';

class SafeRetryPolicy {
  static final Set<String> _inFlightOperations = <String>{};

  /// Executes an asynchronous operation with exponential backoff and timeout protection.
  /// If [idempotencyKey] is provided, concurrent duplicate submissions with the same key
  /// will be blocked to avoid duplicate record creation.
  static Future<T> execute<T>({
    required Future<T> Function() action,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 5),
    Duration timeoutDuration = const Duration(seconds: 10),
    String? idempotencyKey,
    String? operationName,
  }) async {
    final name = operationName ?? 'Operation';

    // Prevent duplicate in-flight requests for the same idempotency key
    if (idempotencyKey != null) {
      if (_inFlightOperations.contains(idempotencyKey)) {
        AppLogger.w('Duplicate submission blocked for key: $idempotencyKey');
        throw const ValidationException(
          message: 'This request is already being processed. Please wait.',
          validationErrors: [],
        );
      }
      _inFlightOperations.add(idempotencyKey);
    }

    int attempt = 0;
    Duration currentDelay = initialDelay;
    final random = Random();

    try {
      while (attempt < maxAttempts) {
        attempt++;
        try {
          return await action().timeout(
            timeoutDuration,
            onTimeout: () {
              throw TimeoutException(
                '$name timed out after ${timeoutDuration.inSeconds} seconds.',
              );
            },
          );
        } catch (e) {
          final isRetryable = _isErrorRetryable(e);
          final hasRemainingAttempts = attempt < maxAttempts;

          if (!isRetryable || !hasRemainingAttempts) {
            AppLogger.e('$name failed at attempt $attempt/$maxAttempts (retryable: $isRetryable): $e');
            rethrow;
          }

          // Add jitter to avoid thundering herd problem
          final jitterMs = random.nextInt(150);
          final delayWithJitter = currentDelay + Duration(milliseconds: jitterMs);

          AppLogger.w(
            '$name failed at attempt $attempt/$maxAttempts ($e). Retrying in ${delayWithJitter.inMilliseconds}ms...',
          );

          await Future.delayed(delayWithJitter);

          final nextDelayMs = (currentDelay.inMilliseconds * backoffMultiplier).toInt();
          currentDelay = Duration(
            milliseconds: min(nextDelayMs, maxDelay.inMilliseconds),
          );
        }
      }

      throw const NetworkException(
        message: 'Request failed after maximum retry attempts. Please check your connection.',
      );
    } finally {
      if (idempotencyKey != null) {
        _inFlightOperations.remove(idempotencyKey);
      }
    }
  }

  /// Determines whether an error is transient and safe to retry.
  static bool _isErrorRetryable(Object error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is NetworkException || error is NetworkFailure) return true;

    if (error is FirebaseFunctionsException) {
      final code = error.code.toLowerCase();
      // Retry transient network or temporary server availability errors
      return code == 'unavailable' || code == 'deadline-exceeded';
    }

    if (error is FirebaseException) {
      final code = error.code.toLowerCase();
      return code == 'unavailable' ||
          code == 'deadline-exceeded' ||
          code == 'resource-exhausted';
    }

    // Never retry client validation, authorization, or business logic conflicts
    if (error is ValidationException ||
        error is AuthException ||
        error is ForbiddenException ||
        error is ValidationFailure ||
        error is AuthFailure ||
        error is ForbiddenFailure) {
      return false;
    }

    final str = error.toString().toLowerCase();
    if (str.contains('network') ||
        str.contains('connection') ||
        str.contains('timeout') ||
        str.contains('timed out') ||
        str.contains('unavailable')) {
      return true;
    }

    return false;
  }
}
