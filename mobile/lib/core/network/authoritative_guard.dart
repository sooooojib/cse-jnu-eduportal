import '../error/failures.dart';
import '../logging/app_logger.dart';
import 'network_info.dart';

class AuthoritativeGuard {
  final NetworkInfo networkInfo;

  AuthoritativeGuard({required this.networkInfo});

  /// Validates that an authoritative live connection to the backend exists
  /// before proceeding with security-sensitive mutations.
  /// Throws [NetworkFailure] if the client is offline or Firebase is unreachable.
  Future<void> ensureAuthoritativeServer({
    required String operationName,
  }) async {
    final status = networkInfo.currentStatus;
    if (status == NetworkStatus.offline) {
      AppLogger.w('Blocked offline execution of security-sensitive operation: $operationName');
      throw NetworkFailure(
        message: '$operationName requires an active internet connection for authoritative verification. Please connect and try again.',
      );
    }

    // Verify actual connectivity
    final isOnline = await networkInfo.isConnected;
    if (!isOnline) {
      AppLogger.w('Blocked offline execution (connectivity probe failed) for: $operationName');
      throw NetworkFailure(
        message: '$operationName cannot be performed offline. Please check your internet connection.',
      );
    }
  }
}
