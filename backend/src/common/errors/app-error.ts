import { HttpStatus, HttpStatusCode } from '../constants/http-status';
import { ErrorCode, ErrorCodeType } from '../constants/error-codes';

export interface ValidationErrorDetail {
  field: string;
  message: string;
}

export class AppError extends Error {
  public readonly statusCode: HttpStatusCode;
  public readonly code: ErrorCodeType;
  public readonly details: ValidationErrorDetail[] | null;
  public readonly isOperational: boolean;

  constructor(
    message: string,
    statusCode: HttpStatusCode = HttpStatus.INTERNAL_SERVER_ERROR,
    code: ErrorCodeType = ErrorCode.INTERNAL_SERVER_ERROR,
    details: ValidationErrorDetail[] | null = null,
    isOperational: boolean = true
  ) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = isOperational;

    Object.setPrototypeOf(this, new.target.prototype);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class BadRequestError extends AppError {
  constructor(message: string, code: ErrorCodeType = ErrorCode.BAD_REQUEST, details: ValidationErrorDetail[] | null = null) {
    super(message, HttpStatus.BAD_REQUEST, code, details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Authentication token is missing, invalid, or expired.', code: ErrorCodeType = ErrorCode.UNAUTHENTICATED) {
    super(message, HttpStatus.UNAUTHORIZED, code);
  }
}

export class ForbiddenError extends AppError {
  constructor(message: string = 'You do not have permission to perform this action.', code: ErrorCodeType = ErrorCode.FORBIDDEN_RESOURCE) {
    super(message, HttpStatus.FORBIDDEN, code);
  }
}

export class NotFoundError extends AppError {
  constructor(message: string = 'The requested resource was not found.', code: ErrorCodeType = ErrorCode.RESOURCE_NOT_FOUND) {
    super(message, HttpStatus.NOT_FOUND, code);
  }
}

export class ConflictError extends AppError {
  constructor(message: string, code: ErrorCodeType = ErrorCode.DATABASE_ERROR) {
    super(message, HttpStatus.CONFLICT, code);
  }
}

export class ValidationError extends AppError {
  constructor(message: string = 'One or more fields failed validation checks.', details: ValidationErrorDetail[]) {
    super(message, HttpStatus.UNPROCESSABLE_ENTITY, ErrorCode.VALIDATION_FAILED, details);
  }
}

export class InternalServerError extends AppError {
  constructor(message: string = 'An internal server error occurred. Please try again later.', code: ErrorCodeType = ErrorCode.INTERNAL_SERVER_ERROR) {
    super(message, HttpStatus.INTERNAL_SERVER_ERROR, code, null, false);
  }
}
