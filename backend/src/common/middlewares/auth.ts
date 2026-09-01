import { Response, NextFunction } from 'express';
import { UserRole } from '../constants/roles';
import { UnauthorizedError, ForbiddenError } from '../errors';
import { verifyAccessToken } from '../utils/token';
import { AuthenticatedRequest, AuthUserPayload } from '../types';
import { query } from '../../config/database';
import { UserEntity } from '../../storage/database/entities';

/**
 * Authentication Middleware:
 * Inspects 'Authorization: Bearer <token>' header, validates JWT signature and expiration,
 * queries the database to verify active account status, and injects authoritative user context into req.user.
 */
export async function authenticate(
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader) {
      throw new UnauthorizedError('Authentication token is missing. Please provide Bearer token in Authorization header.');
    }

    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      throw new UnauthorizedError('Invalid Authorization header format. Expected "Bearer <token>".');
    }

    const token = parts[1];
    const payload = verifyAccessToken(token);

    // Verify user in database for authoritative active status and up-to-date role
    const userRes = await query<UserEntity>(
      `SELECT id, email, full_name, role, student_id, phone, year, semester, semester_status, is_active
       FROM users WHERE id = $1 LIMIT 1`,
      [payload.userId]
    );

    const user = userRes.rows[0];
    if (!user) {
      throw new UnauthorizedError('User account associated with this token no longer exists.');
    }

    if (!user.is_active) {
      throw new UnauthorizedError('User account is deactivated. Please contact the department administrator.');
    }

    // Inject authoritative session payload into request context
    const userPayload: AuthUserPayload = {
      id: user.id,
      email: user.email,
      fullName: user.full_name,
      role: user.role,
      studentId: user.student_id,
      phone: user.phone,
      year: user.year,
      semester: user.semester,
      semesterStatus: user.semester_status,
    };

    req.user = userPayload;
    next();
  } catch (err) {
    next(err);
  }
}

/**
 * Role-Based Access Control (RBAC) Guard:
 * Asserts that the authenticated user possesses at least one of the permitted roles.
 * Returns 403 FORBIDDEN_RESOURCE if unauthorized.
 */
export function authorize(...permittedRoles: UserRole[]) {
  return (req: AuthenticatedRequest, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      throw new UnauthorizedError('Authentication required to access this resource.');
    }

    if (!permittedRoles.includes(req.user.role)) {
      throw new ForbiddenError(
        `Access denied. Role '${req.user.role}' is not authorized for this resource. Permitted roles: [${permittedRoles.join(', ')}]`
      );
    }

    next();
  };
}
