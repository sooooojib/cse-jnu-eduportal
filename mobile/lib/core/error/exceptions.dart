class AppException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic details;

  const AppException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => 'AppException(message: $message, code: $code, statusCode: $statusCode)';
}

class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.code,
    super.statusCode,
    super.details,
  });
}

class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.statusCode = 401,
  });
}

class ForbiddenException extends AppException {
  const ForbiddenException({
    required super.message,
    super.code,
    super.statusCode = 403,
  });
}

class ValidationException extends AppException {
  final List<ValidationErrorItem> validationErrors;

  const ValidationException({
    required super.message,
    required this.validationErrors,
    super.code = 'VALIDATION_FAILED',
    super.statusCode = 422,
  });
}

class ValidationErrorItem {
  final String field;
  final String message;

  const ValidationErrorItem({
    required this.field,
    required this.message,
  });

  factory ValidationErrorItem.fromJson(Map<String, dynamic> json) {
    return ValidationErrorItem(
      field: json['field'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Network connection failed. Please check your internet connection.',
  });
}

class CacheException extends AppException {
  const CacheException({
    required super.message,
  });
}
