import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/core/error/failures.dart';
import 'package:cse_jnu_eduportal/core/error/exceptions.dart';
import 'package:cse_jnu_eduportal/core/error/error_handler.dart';

void main() {
  group('Failures and ErrorHandler', () {
    test('should map AuthException to AuthFailure with 401 status', () {
      const exception = AuthException(message: 'Invalid email or password.');
      final failure = ErrorHandler.handleException(exception);

      expect(failure, isA<AuthFailure>());
      expect(failure.message, 'Invalid email or password.');
      expect(failure.statusCode, 401);
    });

    test('should map ForbiddenException to ForbiddenFailure with 403 status', () {
      const exception = ForbiddenException(message: 'Access denied.');
      final failure = ErrorHandler.handleException(exception);

      expect(failure, isA<ForbiddenFailure>());
      expect(failure.statusCode, 403);
    });

    test('should map ValidationException to ValidationFailure with details', () {
      final exception = ValidationException(
        message: 'Validation failed.',
        validationErrors: [
          const ValidationErrorItem(field: 'email', message: 'Email is required'),
        ],
      );
      final failure = ErrorHandler.handleException(exception);

      expect(failure, isA<ValidationFailure>());
      final valFailure = failure as ValidationFailure;
      expect(valFailure.validationErrors.length, 1);
      expect(valFailure.validationErrors.first.field, 'email');
    });

    test('should map NetworkException to NetworkFailure', () {
      const exception = NetworkException();
      final failure = ErrorHandler.handleException(exception);

      expect(failure, isA<NetworkFailure>());
    });
  });
}
