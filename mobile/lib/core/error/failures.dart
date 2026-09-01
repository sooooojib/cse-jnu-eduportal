import 'package:equatable/equatable.dart';
import 'exceptions.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final int? statusCode;

  const Failure({
    required this.message,
    this.code,
    this.statusCode,
  });

  @override
  List<Object?> get props => [message, code, statusCode];
}

class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.code,
    super.statusCode,
  });
}

class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code = 'UNAUTHENTICATED',
    super.statusCode = 401,
  });
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure({
    required super.message,
    super.code = 'FORBIDDEN_RESOURCE',
    super.statusCode = 403,
  });
}

class ValidationFailure extends Failure {
  final List<ValidationErrorItem> validationErrors;

  const ValidationFailure({
    required super.message,
    required this.validationErrors,
    super.code = 'VALIDATION_FAILED',
    super.statusCode = 422,
  });

  @override
  List<Object?> get props => [message, code, statusCode, validationErrors];
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Network connection failed. Please check your internet connection.',
  });
}

class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
  });
}
