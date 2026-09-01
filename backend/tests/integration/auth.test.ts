import request from 'supertest';
import express, { Response } from 'express';
import { app } from '../../src/app';
import * as db from '../../src/config/database';
import { hashPassword } from '../../src/common/utils/password';
import { signAccessToken, signRefreshToken } from '../../src/common/utils/token';
import { UserRole } from '../../src/common/constants/roles';
import { authenticate, authorize } from '../../src/common/middlewares/auth';
import { errorHandler } from '../../src/common/middlewares/error-handler';
import { AuthenticatedRequest } from '../../src/common/types';
import { SemesterStatus } from '../../src/common/constants/enums';

describe('Complete Authentication & Authorization Security System', () => {
  // Test protected RBAC route
  const testRbacApp = express();
  testRbacApp.use(express.json());
  testRbacApp.get(
    '/admin-only',
    authenticate,
    authorize(UserRole.ADMIN),
    (_req: AuthenticatedRequest, res: Response) => {
      res.status(200).json({ success: true, message: 'Admin access granted' });
    }
  );
  testRbacApp.get(
    '/teacher-or-cr',
    authenticate,
    authorize(UserRole.TEACHER, UserRole.CR),
    (_req: AuthenticatedRequest, res: Response) => {
      res.status(200).json({ success: true, message: 'Teacher/CR access granted' });
    }
  );
  testRbacApp.get(
    '/student-dashboard',
    authenticate,
    authorize(UserRole.STUDENT, UserRole.CR),
    (_req: AuthenticatedRequest, res: Response) => {
      res.status(200).json({ success: true, message: 'Student access granted' });
    }
  );
  testRbacApp.use(errorHandler);

  // Helper mock user
  const createMockUser = (role: UserRole = UserRole.STUDENT, isActive: boolean = true) => ({
    id: '11111111-1111-1111-1111-111111111111',
    email: 'student@cse.jnu.ac.bd',
    password_hash: '',
    full_name: 'Sajib Hossain',
    role,
    student_id: 'B210305015',
    phone: null,
    avatar_url: null,
    year: 3,
    semester: 1,
    semester_status: SemesterStatus.NONE,
    is_active: isActive,
    created_at: new Date(),
    updated_at: new Date(),
  });

  describe('1. Registration / Signup Request Pipeline', () => {
    it('should reject signup request without studentId for STUDENT role', async () => {
      const res = await request(app)
        .post('/api/v1/auth/signup-request')
        .send({
          fullName: 'Farhan Tanvir',
          email: 'farhan@cse.jnu.ac.bd',
          role: 'STUDENT',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
      expect(res.body.error.details.some((d: { field: string }) => d.field === 'studentId')).toBe(true);
    });

    it('should reject signup request without phone for TEACHER role', async () => {
      const res = await request(app)
        .post('/api/v1/auth/signup-request')
        .send({
          fullName: 'Dr. Hasan Rahman',
          email: 'hasan@cse.jnu.ac.bd',
          role: 'TEACHER',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
      expect(res.body.error.details.some((d: { field: string }) => d.field === 'phone')).toBe(true);
    });

    it('should submit valid student registration request', async () => {
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('SELECT id FROM users')) {
          return { rows: [], rowCount: 0 } as any;
        }
        if (text.includes('SELECT id FROM signup_requests')) {
          return { rows: [], rowCount: 0 } as any;
        }
        if (text.includes('INSERT INTO signup_requests')) {
          return {
            rows: [{ id: '99999999-9999-9999-9999-999999999999', status: 'PENDING' }],
            rowCount: 1,
          } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/signup-request')
        .send({
          fullName: 'Farhan Tanvir',
          email: 'farhan@cse.jnu.ac.bd',
          role: 'STUDENT',
          studentId: 'B210305015',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.requestId).toBe('99999999-9999-9999-9999-999999999999');
      expect(res.body.data.status).toBe('PENDING');

      querySpy.mockRestore();
    });

    it('should reject signup when email or studentId is already in pending queue', async () => {
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('SELECT id FROM users')) {
          return { rows: [], rowCount: 0 } as any;
        }
        if (text.includes('SELECT id FROM signup_requests')) {
          return { rows: [{ id: 'existing-request-id' }], rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/signup-request')
        .send({
          fullName: 'Farhan Tanvir',
          email: 'duplicate@cse.jnu.ac.bd',
          role: 'STUDENT',
          studentId: 'B210305015',
        });

      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('PENDING_SIGNUP_EXISTS');

      querySpy.mockRestore();
    });
  });

  describe('2. User Login & Credential Verification', () => {
    it('should reject login when user email does not exist', async () => {
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'nonexistent@cse.jnu.ac.bd',
          password: 'Password123!',
        });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('INVALID_CREDENTIALS');

      querySpy.mockRestore();
    });

    it('should reject login when account is deactivated (is_active = false)', async () => {
      const mockUser = createMockUser(UserRole.STUDENT, false);
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [mockUser], rowCount: 1 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'student@cse.jnu.ac.bd',
          password: 'Password123!',
        });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
      expect(res.body.error.message).toMatch(/deactivated/i);

      querySpy.mockRestore();
    });

    it('should reject login when password is incorrect', async () => {
      const hashed = await hashPassword('CorrectPassword123!');
      const mockUser = createMockUser();
      mockUser.password_hash = hashed;

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [mockUser], rowCount: 1 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'student@cse.jnu.ac.bd',
          password: 'WrongPassword456!',
        });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('INVALID_CREDENTIALS');

      querySpy.mockRestore();
    });

    it('should succeed with valid credentials, issuing tokens and storing session', async () => {
      const hashed = await hashPassword('CorrectPassword123!');
      const mockUser = createMockUser();
      mockUser.password_hash = hashed;

      let sessionStored = false;
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('SELECT * FROM users')) {
          return { rows: [mockUser], rowCount: 1 } as any;
        }
        if (text.includes('INSERT INTO refresh_tokens')) {
          sessionStored = true;
          return { rows: [], rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'student@cse.jnu.ac.bd',
          password: 'CorrectPassword123!',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
      expect(res.body.data.tokenType).toBe('Bearer');
      expect(res.body.data.user.email).toBe('student@cse.jnu.ac.bd');
      expect(res.body.data.user.role).toBe(UserRole.STUDENT);
      expect(sessionStored).toBe(true);

      querySpy.mockRestore();
    });
  });

  describe('3. Refresh Token Lifecycle & Revocation', () => {
    it('should rotate/issue new access token with valid active refresh token', async () => {
      const validRefreshToken = signRefreshToken({ userId: '11111111-1111-1111-1111-111111111111' });
      const mockUser = createMockUser();

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('SELECT id, user_id, is_revoked, expires_at FROM refresh_tokens')) {
          return {
            rows: [
              {
                id: 'session-id-1',
                user_id: mockUser.id,
                is_revoked: false,
                expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
              },
            ],
            rowCount: 1,
          } as any;
        }
        if (text.includes('SELECT id, email, role, year, semester, is_active FROM users')) {
          return { rows: [mockUser], rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/refresh-token')
        .send({ refreshToken: validRefreshToken });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.accessToken).toBeDefined();

      querySpy.mockRestore();
    });

    it('should reject refresh token when token has been revoked in database', async () => {
      const validRefreshToken = signRefreshToken({ userId: '11111111-1111-1111-1111-111111111111' });

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('SELECT id, user_id, is_revoked, expires_at FROM refresh_tokens')) {
          return {
            rows: [
              {
                id: 'session-id-1',
                user_id: '11111111-1111-1111-1111-111111111111',
                is_revoked: true, // Revoked!
                expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
              },
            ],
            rowCount: 1,
          } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/refresh-token')
        .send({ refreshToken: validRefreshToken });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('REFRESH_TOKEN_INVALID');

      querySpy.mockRestore();
    });

    it('should reject refresh token if associated user was deactivated', async () => {
      const validRefreshToken = signRefreshToken({ userId: '11111111-1111-1111-1111-111111111111' });
      const deactivatedUser = createMockUser(UserRole.STUDENT, false);

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('SELECT id, user_id, is_revoked, expires_at FROM refresh_tokens')) {
          return {
            rows: [
              {
                id: 'session-id-1',
                user_id: deactivatedUser.id,
                is_revoked: false,
                expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
              },
            ],
            rowCount: 1,
          } as any;
        }
        if (text.includes('SELECT id, email, role, year, semester, is_active FROM users')) {
          return { rows: [deactivatedUser], rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/refresh-token')
        .send({ refreshToken: validRefreshToken });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('REFRESH_TOKEN_INVALID');

      querySpy.mockRestore();
    });
  });

  describe('4. Logout & Session Invalidation', () => {
    it('should revoke user refresh token session on logout', async () => {
      const mockUser = createMockUser();
      const token = signAccessToken({
        userId: mockUser.id,
        email: mockUser.email,
        role: mockUser.role,
        year: mockUser.year,
        semester: mockUser.semester,
      });

      let tokenRevoked = false;
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('SELECT id, email, full_name, role')) {
          return { rows: [mockUser], rowCount: 1 } as any;
        }
        if (text.includes('UPDATE refresh_tokens SET is_revoked = TRUE')) {
          tokenRevoked = true;
          return { rows: [], rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${token}`)
        .send({ refreshToken: 'some-refresh-token' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(tokenRevoked).toBe(true);

      querySpy.mockRestore();
    });
  });

  describe('5. Password Modification & Session Termination', () => {
    it('should reject password change when new password violates complexity', async () => {
      const mockUser = createMockUser();
      const token = signAccessToken({
        userId: mockUser.id,
        email: mockUser.email,
        role: mockUser.role,
        year: mockUser.year,
        semester: mockUser.semester,
      });

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [mockUser], rowCount: 1 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/change-password')
        .set('Authorization', `Bearer ${token}`)
        .send({
          currentPassword: 'OldPassword123!',
          newPassword: 'simple', // Weak password failing regex and length
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');

      querySpy.mockRestore();
    });

    it('should update password and revoke all active sessions on password change', async () => {
      const oldHash = await hashPassword('OldPassword123!');
      const mockUser = createMockUser();
      mockUser.password_hash = oldHash;

      const token = signAccessToken({
        userId: mockUser.id,
        email: mockUser.email,
        role: mockUser.role,
        year: mockUser.year,
        semester: mockUser.semester,
      });

      let allSessionsRevoked = false;
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('SELECT id, email, full_name, role')) {
          return { rows: [mockUser], rowCount: 1 } as any;
        }
        if (text.includes('SELECT id, password_hash FROM users')) {
          return { rows: [mockUser], rowCount: 1 } as any;
        }
        if (text.includes('UPDATE users SET password_hash')) {
          return { rows: [], rowCount: 1 } as any;
        }
        if (text.includes('UPDATE refresh_tokens SET is_revoked = TRUE')) {
          allSessionsRevoked = true;
          return { rows: [], rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/auth/change-password')
        .set('Authorization', `Bearer ${token}`)
        .send({
          currentPassword: 'OldPassword123!',
          newPassword: 'NewSecurePassword456#',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(allSessionsRevoked).toBe(true);

      querySpy.mockRestore();
    });
  });

  describe('6. Protected Profile & Account Status Verification', () => {
    it('should reject /me request without Authorization header', async () => {
      const res = await request(app).get('/api/v1/auth/me');

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('should reject /me request if user was deactivated after token generation', async () => {
      const deactivatedUser = createMockUser(UserRole.STUDENT, false);
      const token = signAccessToken({
        userId: deactivatedUser.id,
        email: deactivatedUser.email,
        role: deactivatedUser.role,
        year: 3,
        semester: 1,
      });

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [deactivatedUser], rowCount: 1 } as any;
      });

      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');

      querySpy.mockRestore();
    });

    it('should return sanitized profile for active user', async () => {
      const activeUser = createMockUser();
      const token = signAccessToken({
        userId: activeUser.id,
        email: activeUser.email,
        role: activeUser.role,
        year: 3,
        semester: 1,
      });

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [activeUser], rowCount: 1 } as any;
      });

      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.email).toBe('student@cse.jnu.ac.bd');
      expect(res.body.data.fullName).toBe('Sajib Hossain');
      expect(res.body.data.password_hash).toBeUndefined();

      querySpy.mockRestore();
    });
  });

  describe('7. Authoritative RBAC Enforcement & Role Isolation', () => {
    it('should enforce role hierarchy and deny STUDENT from accessing ADMIN route', async () => {
      const studentUser = createMockUser(UserRole.STUDENT);
      const studentToken = signAccessToken({
        userId: studentUser.id,
        email: studentUser.email,
        role: UserRole.STUDENT,
        year: 3,
        semester: 1,
      });

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [studentUser], rowCount: 1 } as any;
      });

      const res = await request(testRbacApp)
        .get('/admin-only')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('FORBIDDEN_RESOURCE');

      querySpy.mockRestore();
    });

    it('should allow ADMIN to access ADMIN route', async () => {
      const adminUser = createMockUser(UserRole.ADMIN);
      const adminToken = signAccessToken({
        userId: adminUser.id,
        email: adminUser.email,
        role: UserRole.ADMIN,
        year: null,
        semester: null,
      });

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [adminUser], rowCount: 1 } as any;
      });

      const res = await request(testRbacApp)
        .get('/admin-only')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Admin access granted');

      querySpy.mockRestore();
    });

    it('should allow TEACHER and CR to access teacher-or-cr route', async () => {
      const teacherUser = createMockUser(UserRole.TEACHER);
      const teacherToken = signAccessToken({
        userId: teacherUser.id,
        email: teacherUser.email,
        role: UserRole.TEACHER,
        year: null,
        semester: null,
      });

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [teacherUser], rowCount: 1 } as any;
      });

      const res = await request(testRbacApp)
        .get('/teacher-or-cr')
        .set('Authorization', `Bearer ${teacherToken}`);

      expect(res.status).toBe(200);

      querySpy.mockRestore();
    });

    it('should allow CR to access student-dashboard route', async () => {
      const crUser = createMockUser(UserRole.CR);
      const crToken = signAccessToken({
        userId: crUser.id,
        email: crUser.email,
        role: UserRole.CR,
        year: 3,
        semester: 1,
      });

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async () => {
        return { rows: [crUser], rowCount: 1 } as any;
      });

      const res = await request(testRbacApp)
        .get('/student-dashboard')
        .set('Authorization', `Bearer ${crToken}`);

      expect(res.status).toBe(200);

      querySpy.mockRestore();
    });
  });
});
