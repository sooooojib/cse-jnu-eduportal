import { Response } from 'express';
import { HttpStatus, HttpStatusCode } from '../constants/http-status';
import { ApiResponse, ApiResponseMeta } from '../types';

/**
 * Sends a standardized success JSON response (200 OK by default)
 */
export function sendSuccess<T>(
  res: Response,
  data: T,
  message: string = 'Operation completed successfully.',
  statusCode: HttpStatusCode = HttpStatus.OK,
  extraMeta?: Partial<ApiResponseMeta>
): Response {
  const responsePayload: ApiResponse<T> = {
    success: true,
    data,
    message,
    meta: {
      timestamp: new Date().toISOString(),
      ...extraMeta,
    },
  };
  return res.status(statusCode).json(responsePayload);
}

/**
 * Sends a standardized 201 Created response
 */
export function sendCreated<T>(
  res: Response,
  data: T,
  message: string = 'Resource created successfully.'
): Response {
  return sendSuccess(res, data, message, HttpStatus.CREATED);
}

/**
 * Sends a standardized paginated list response
 */
export function sendPaginated<T>(
  res: Response,
  data: T[],
  pagination: {
    page: number;
    limit: number;
    total: number;
  },
  message: string = 'Resources retrieved successfully.'
): Response {
  const totalPages = Math.ceil(pagination.total / pagination.limit) || 1;
  const hasNextPage = pagination.page < totalPages;
  const hasPrevPage = pagination.page > 1;

  const responsePayload: ApiResponse<T[]> = {
    success: true,
    data,
    message,
    meta: {
      page: pagination.page,
      limit: pagination.limit,
      total: pagination.total,
      totalPages,
      hasNextPage,
      hasPrevPage,
      timestamp: new Date().toISOString(),
    },
  };
  return res.status(HttpStatus.OK).json(responsePayload);
}
