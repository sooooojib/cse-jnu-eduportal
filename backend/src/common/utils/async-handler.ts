import { Request, Response, NextFunction, RequestHandler } from 'express';

/**
 * Wraps asynchronous Express route handlers to automatically forward thrown errors/rejections to next(err).
 */
export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<unknown>
): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
