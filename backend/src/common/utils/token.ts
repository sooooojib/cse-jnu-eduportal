import jwt, { SignOptions, Secret } from 'jsonwebtoken';
import crypto from 'crypto';
import { env } from '../../config/env';
import { JwtTokenPayload } from '../types';
import { UnauthorizedError } from '../errors';
import { ErrorCode } from '../constants/error-codes';

export interface DecodedRefreshToken {
  userId: string;
  jti: string;
  exp?: number;
  iat?: number;
}

/**
 * Signs a short-lived access JWT token (default: 15 minutes)
 */
export function signAccessToken(payload: JwtTokenPayload, expiresIn?: string | number): string {
  const secret: Secret = env.JWT_ACCESS_SECRET;
  const options: SignOptions = {
    expiresIn: (expiresIn || env.JWT_ACCESS_EXPIRES_IN) as SignOptions['expiresIn'],
    algorithm: 'HS256',
  };
  return jwt.sign(payload, secret, options);
}

/**
 * Signs a long-lived refresh JWT token (default: 7 days) with unique jti
 */
export function signRefreshToken(
  payload: { userId: string },
  expiresIn?: string | number
): string {
  const secret: Secret = env.JWT_REFRESH_SECRET;
  const options: SignOptions = {
    expiresIn: (expiresIn || env.JWT_REFRESH_EXPIRES_IN) as SignOptions['expiresIn'],
    algorithm: 'HS256',
    jwtid: crypto.randomUUID(),
  };
  return jwt.sign(payload, secret, options);
}

/**
 * Verifies an access token and returns decoded payload
 */
export function verifyAccessToken(token: string): JwtTokenPayload {
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as JwtTokenPayload;
    return decoded;
  } catch (err: unknown) {
    if (err instanceof jwt.TokenExpiredError) {
      throw new UnauthorizedError('Access token has expired.', ErrorCode.TOKEN_EXPIRED);
    }
    throw new UnauthorizedError('Invalid access token.', ErrorCode.UNAUTHENTICATED);
  }
}

/**
 * Verifies a refresh token and returns decoded payload
 */
export function verifyRefreshToken(token: string): DecodedRefreshToken {
  try {
    const decoded = jwt.verify(token, env.JWT_REFRESH_SECRET) as DecodedRefreshToken;
    return decoded;
  } catch (err: unknown) {
    if (err instanceof jwt.TokenExpiredError) {
      throw new UnauthorizedError('Refresh token has expired.', ErrorCode.REFRESH_TOKEN_INVALID);
    }
    throw new UnauthorizedError('Invalid refresh token.', ErrorCode.REFRESH_TOKEN_INVALID);
  }
}

/**
 * Extracts expiration timestamp as a Date object from a decoded JWT
 */
export function getTokenExpirationDate(token: string): Date {
  const decoded = jwt.decode(token) as { exp?: number } | null;
  if (decoded && decoded.exp) {
    return new Date(decoded.exp * 1000);
  }
  // Default to 7 days from now if not present in token
  return new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
}
