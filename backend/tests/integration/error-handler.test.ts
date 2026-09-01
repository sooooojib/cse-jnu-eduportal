import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';
import { errorHandler } from '../../src/common/middlewares/error-handler';
import { notFoundHandler } from '../../src/common/middlewares/not-found';
import {
  BadRequestError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
  ValidationError,
} from '../../src/common/errors';
import { ErrorCode } from '../../src/common/constants/error-codes';

describe('Centralized Error Handler', () => {
  const errorApp = express();
  errorApp.use(express.json());

  errorApp.get('/throw-bad-request', () => {
    throw new BadRequestError('Custom bad request', ErrorCode.INVALID_VERIFICATION_CODE);
  });

  errorApp.get('/throw-unauthorized', () => {
    throw new UnauthorizedError('Token is expired', ErrorCode.TOKEN_EXPIRED);
  });

  errorApp.get('/throw-forbidden', () => {
    throw new ForbiddenError('Forbidden action', ErrorCode.FORBIDDEN_RESOURCE);
  });

  errorApp.get('/throw-not-found', () => {
    throw new NotFoundError('Course with this ID not found');
  });

  errorApp.get('/throw-conflict', () => {
    throw new ConflictError('Attendance already submitted', ErrorCode.DUPLICATE_ATTENDANCE);
  });

  errorApp.get('/throw-validation', () => {
    throw new ValidationError('Validation error', [
      { field: 'email', message: 'Invalid email' },
    ]);
  });

  errorApp.get('/throw-db-unique-conflict', (_req: Request, _res: Response, next: NextFunction) => {
    const err = new Error('duplicate key value violates unique constraint');
    (err as any).code = '23505';
    next(err);
  });

  errorApp.get('/throw-db-foreign-key', (_req: Request, _res: Response, next: NextFunction) => {
    const err = new Error('violates foreign key constraint');
    (err as any).code = '23503';
    next(err);
  });

  errorApp.get('/throw-unexpected', () => {
    throw new Error('Unexpected crash simulation');
  });

  errorApp.use(notFoundHandler);
  errorApp.use(errorHandler);

  it('should format 400 Bad Request envelope', async () => {
    const res = await request(errorApp).get('/throw-bad-request');
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe(ErrorCode.INVALID_VERIFICATION_CODE);
    expect(res.body.meta.timestamp).toBeDefined();
  });

  it('should format 401 Unauthorized envelope', async () => {
    const res = await request(errorApp).get('/throw-unauthorized');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe(ErrorCode.TOKEN_EXPIRED);
  });

  it('should format 403 Forbidden envelope', async () => {
    const res = await request(errorApp).get('/throw-forbidden');
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe(ErrorCode.FORBIDDEN_RESOURCE);
  });

  it('should format 404 Not Found envelope', async () => {
    const res = await request(errorApp).get('/throw-not-found');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe(ErrorCode.RESOURCE_NOT_FOUND);
  });

  it('should format 409 Conflict envelope', async () => {
    const res = await request(errorApp).get('/throw-conflict');
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe(ErrorCode.DUPLICATE_ATTENDANCE);
  });

  it('should format 422 Validation Error envelope with details', async () => {
    const res = await request(errorApp).get('/throw-validation');
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe(ErrorCode.VALIDATION_FAILED);
    expect(res.body.error.details).toEqual([{ field: 'email', message: 'Invalid email' }]);
  });

  it('should handle PostgreSQL unique violation (23505) as 409 Conflict', async () => {
    const res = await request(errorApp).get('/throw-db-unique-conflict');
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe(ErrorCode.DATABASE_ERROR);
  });

  it('should handle PostgreSQL FK violation (23503) as 400 Bad Request', async () => {
    const res = await request(errorApp).get('/throw-db-foreign-key');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe(ErrorCode.BAD_REQUEST);
  });

  it('should catch unhandled exceptions and return 500 without leaking stack traces', async () => {
    const res = await request(errorApp).get('/throw-unexpected');
    expect(res.status).toBe(500);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe(ErrorCode.INTERNAL_SERVER_ERROR);
    expect(res.body.error.details).toBeNull();
  });

  it('should handle unmatched routes with 404 RESOURCE_NOT_FOUND', async () => {
    const res = await request(errorApp).get('/unmatched-nonexistent-endpoint');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe(ErrorCode.RESOURCE_NOT_FOUND);
  });
});
