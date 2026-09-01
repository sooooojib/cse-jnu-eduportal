import { Request, Response, NextFunction } from 'express';
import { AppError } from '../errors';
import { HttpStatus } from '../constants/http-status';
import { ErrorCode } from '../constants/error-codes';
import { logger } from '../utils/logger';
import { ApiResponse } from '../types';

export function errorHandler(
  err: Error | AppError,
  req: Request,
  res: Response,
  _next: NextFunction
): Response {
  const timestamp = new Date().toISOString();

  // 1. Known AppError instances
  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error({ err, path: req.path, method: req.method }, 'Internal server error occurred');
    } else {
      logger.warn({ err: err.message, code: err.code, path: req.path, method: req.method }, 'Client request rejected');
    }

    const payload: ApiResponse = {
      success: false,
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
      },
      meta: { timestamp },
    };
    return res.status(err.statusCode).json(payload);
  }

  // 2. Body Parser JSON Syntax Error
  if (err instanceof SyntaxError && 'body' in err) {
    const payload: ApiResponse = {
      success: false,
      error: {
        code: ErrorCode.BAD_REQUEST,
        message: 'Malformed JSON payload in request body.',
        details: null,
      },
      meta: { timestamp },
    };
    return res.status(HttpStatus.BAD_REQUEST).json(payload);
  }

  // 3. PostgreSQL Database Driver Errors (pg error codes)
  const pgError = (err as unknown) as Record<string, unknown>;
  if (typeof pgError.code === 'string') {
    // 23505: unique_violation
    if (pgError.code === '23505') {
      const payload: ApiResponse = {
        success: false,
        error: {
          code: ErrorCode.DATABASE_ERROR,
          message: 'A record with these unique details already exists.',
          details: null,
        },
        meta: { timestamp },
      };
      return res.status(HttpStatus.CONFLICT).json(payload);
    }

    // 23503: foreign_key_violation
    if (pgError.code === '23503') {
      const payload: ApiResponse = {
        success: false,
        error: {
          code: ErrorCode.BAD_REQUEST,
          message: 'Referenced relational record was not found or has dependent constraints.',
          details: null,
        },
        meta: { timestamp },
      };
      return res.status(HttpStatus.BAD_REQUEST).json(payload);
    }

    // 23514: check_violation
    if (pgError.code === '23514') {
      const payload: ApiResponse = {
        success: false,
        error: {
          code: ErrorCode.BAD_REQUEST,
          message: 'Supplied data violates database domain constraints.',
          details: null,
        },
        meta: { timestamp },
      };
      return res.status(HttpStatus.BAD_REQUEST).json(payload);
    }
  }

  // 4. Uncaught Unexpected Errors
  logger.error({ err, path: req.path, method: req.method }, 'Uncaught unexpected server exception');

  const payload: ApiResponse = {
    success: false,
    error: {
      code: ErrorCode.INTERNAL_SERVER_ERROR,
      message: 'An internal server error occurred. Please try again later.',
      details: null,
    },
    meta: { timestamp },
  };
  return res.status(HttpStatus.INTERNAL_SERVER_ERROR).json(payload);
}
