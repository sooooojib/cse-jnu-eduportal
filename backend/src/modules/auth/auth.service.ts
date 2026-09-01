import { query } from '../../config/database';
import { UserEntity, SignupRequestEntity, RefreshTokenEntity } from '../../storage/database/entities';
import { LoginInput, SignupRequestInput, RefreshTokenInput, ChangePasswordInput } from './auth.schemas';
import { comparePassword, hashPassword } from '../../common/utils/password';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  getTokenExpirationDate,
} from '../../common/utils/token';
import { UnauthorizedError, ConflictError, NotFoundError, BadRequestError } from '../../common/errors';
import { ErrorCode } from '../../common/constants/error-codes';
import { RequestStatus } from '../../common/constants/enums';

export class AuthService {
  /**
   * Authenticates user via email and password, creates session in refresh_tokens table,
   * and returns access + refresh JWT tokens.
   */
  public static async login(input: LoginInput) {
    const userRes = await query<UserEntity>(
      `SELECT * FROM users WHERE email = $1 LIMIT 1`,
      [input.email.toLowerCase().trim()]
    );

    const user = userRes.rows[0];
    if (!user) {
      throw new UnauthorizedError('Invalid email or password.', ErrorCode.INVALID_CREDENTIALS);
    }

    if (!user.is_active) {
      throw new UnauthorizedError('Account is deactivated. Please contact the department administrator.', ErrorCode.UNAUTHENTICATED);
    }

    const isMatch = await comparePassword(input.password, user.password_hash);
    if (!isMatch) {
      throw new UnauthorizedError('Invalid email or password.', ErrorCode.INVALID_CREDENTIALS);
    }

    const tokenPayload = {
      userId: user.id,
      email: user.email,
      role: user.role,
      year: user.year,
      semester: user.semester,
    };

    const accessToken = signAccessToken(tokenPayload);
    const refreshToken = signRefreshToken({ userId: user.id });
    const expiresAt = getTokenExpirationDate(refreshToken);

    // Persist refresh token session in database
    await query(
      `INSERT INTO refresh_tokens (user_id, token, is_revoked, expires_at, created_at, updated_at)
       VALUES ($1, $2, FALSE, $3, NOW(), NOW())`,
      [user.id, refreshToken, expiresAt]
    );

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: 900,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        role: user.role,
        studentId: user.student_id,
        phone: user.phone,
        avatarUrl: user.avatar_url,
        year: user.year,
        semester: user.semester,
        semesterStatus: user.semester_status,
      },
    };
  }

  /**
   * Submits a public account registration request into the moderation queue
   */
  public static async submitSignupRequest(input: SignupRequestInput) {
    const normalizedEmail = input.email.toLowerCase().trim();

    // Check if active user already exists with email or studentId
    const existingUser = await query<UserEntity>(
      `SELECT id FROM users WHERE email = $1 OR (student_id IS NOT NULL AND student_id = $2) LIMIT 1`,
      [normalizedEmail, input.studentId || null]
    );

    if (existingUser.rows.length > 0) {
      throw new ConflictError(
        'An account with this email or student ID already exists.',
        ErrorCode.PENDING_SIGNUP_EXISTS
      );
    }

    // Check if pending request exists
    const existingReq = await query<SignupRequestEntity>(
      `SELECT id FROM signup_requests WHERE status = 'PENDING' AND (email = $1 OR (student_id IS NOT NULL AND student_id = $2)) LIMIT 1`,
      [normalizedEmail, input.studentId || null]
    );

    if (existingReq.rows.length > 0) {
      throw new ConflictError(
        'A registration request with this email or student ID is already pending administrative review.',
        ErrorCode.PENDING_SIGNUP_EXISTS
      );
    }

    const insertRes = await query<SignupRequestEntity>(
      `INSERT INTO signup_requests (email, full_name, role, student_id, phone, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
       RETURNING id, status`,
      [
        normalizedEmail,
        input.fullName.trim(),
        input.role,
        input.studentId ? input.studentId.trim() : null,
        input.phone ? input.phone.trim() : null,
        RequestStatus.PENDING,
      ]
    );

    const created = insertRes.rows[0];

    return {
      requestId: created.id,
      status: created.status,
    };
  }

  /**
   * Exchanges a valid, unrevoked refresh token for a newly minted access token
   */
  public static async refreshToken(input: RefreshTokenInput) {
    const decoded = verifyRefreshToken(input.refreshToken);

    // Verify token validity and non-revocation status in database
    const tokenRes = await query<RefreshTokenEntity>(
      `SELECT id, user_id, is_revoked, expires_at FROM refresh_tokens WHERE token = $1 LIMIT 1`,
      [input.refreshToken]
    );

    const session = tokenRes.rows[0];
    if (!session || session.is_revoked || new Date(session.expires_at) < new Date()) {
      throw new UnauthorizedError(
        'Refresh token is invalid, expired, or revoked.',
        ErrorCode.REFRESH_TOKEN_INVALID
      );
    }

    // Verify user exists and is active
    const userRes = await query<UserEntity>(
      `SELECT id, email, role, year, semester, is_active FROM users WHERE id = $1 LIMIT 1`,
      [decoded.userId]
    );

    const user = userRes.rows[0];
    if (!user || !user.is_active) {
      throw new UnauthorizedError(
        'User account associated with this session is deactivated or no longer exists.',
        ErrorCode.REFRESH_TOKEN_INVALID
      );
    }

    const tokenPayload = {
      userId: user.id,
      email: user.email,
      role: user.role,
      year: user.year,
      semester: user.semester,
    };

    const accessToken = signAccessToken(tokenPayload);

    return {
      accessToken,
      tokenType: 'Bearer',
      expiresIn: 900,
    };
  }

  /**
   * Revokes refresh token session on user logout
   */
  public static async logout(userId: string, refreshToken?: string) {
    if (refreshToken) {
      await query(
        `UPDATE refresh_tokens SET is_revoked = TRUE, updated_at = NOW() WHERE token = $1 AND user_id = $2`,
        [refreshToken, userId]
      );
    } else {
      await query(
        `UPDATE refresh_tokens SET is_revoked = TRUE, updated_at = NOW() WHERE user_id = $1`,
        [userId]
      );
    }

    return {
      message: 'Logged out successfully.',
    };
  }

  /**
   * Retrieves profile details for the authenticated user
   */
  public static async getMe(userId: string) {
    const userRes = await query<UserEntity>(
      `SELECT id, email, full_name, role, student_id, phone, avatar_url, year, semester, semester_status, created_at
       FROM users WHERE id = $1 LIMIT 1`,
      [userId]
    );

    const user = userRes.rows[0];
    if (!user) {
      throw new NotFoundError('User profile not found.');
    }

    return {
      id: user.id,
      email: user.email,
      fullName: user.full_name,
      role: user.role,
      studentId: user.student_id,
      phone: user.phone,
      avatarUrl: user.avatar_url,
      year: user.year,
      semester: user.semester,
      semesterStatus: user.semester_status,
      createdAt: user.created_at,
    };
  }

  /**
   * Updates user password after validating current password, and revokes active refresh tokens
   */
  public static async changePassword(userId: string, input: ChangePasswordInput) {
    const userRes = await query<UserEntity>(
      `SELECT id, password_hash FROM users WHERE id = $1 LIMIT 1`,
      [userId]
    );

    const user = userRes.rows[0];
    if (!user) {
      throw new NotFoundError('User not found.');
    }

    const isMatch = await comparePassword(input.currentPassword, user.password_hash);
    if (!isMatch) {
      throw new BadRequestError('Current password does not match.', ErrorCode.INVALID_CREDENTIALS);
    }

    const newHash = await hashPassword(input.newPassword);

    await query(
      `UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`,
      [newHash, userId]
    );

    // Invalidate all active sessions for this user to enforce security
    await query(
      `UPDATE refresh_tokens SET is_revoked = TRUE, updated_at = NOW() WHERE user_id = $1`,
      [userId]
    );

    return {
      message: 'Password changed successfully.',
    };
  }
}
