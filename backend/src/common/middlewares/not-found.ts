import { Request, Response, NextFunction } from 'express';
import { NotFoundError } from '../errors';

/**
 * 404 Route Not Found Handler
 */
export function notFoundHandler(req: Request, _res: Response, next: NextFunction): void {
  next(new NotFoundError(`Cannot ${req.method} ${req.originalUrl}`));
}
