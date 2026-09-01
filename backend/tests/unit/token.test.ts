import {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
} from '../../src/common/utils/token';
import { UserRole } from '../../src/common/constants/roles';
import { UnauthorizedError } from '../../src/common/errors';

describe('JWT Token Utility', () => {
  const samplePayload = {
    userId: '11111111-2222-3333-4444-555555555555',
    email: 'student@cse.jnu.ac.bd',
    role: UserRole.STUDENT,
    year: 3,
    semester: 1,
  };

  it('should sign and verify access token with correct claims', () => {
    const token = signAccessToken(samplePayload);
    expect(typeof token).toBe('string');

    const decoded = verifyAccessToken(token);
    expect(decoded.userId).toBe(samplePayload.userId);
    expect(decoded.email).toBe(samplePayload.email);
    expect(decoded.role).toBe(samplePayload.role);
    expect(decoded.year).toBe(samplePayload.year);
    expect(decoded.semester).toBe(samplePayload.semester);
  });

  it('should sign and verify refresh token', () => {
    const refreshToken = signRefreshToken({ userId: samplePayload.userId });
    expect(typeof refreshToken).toBe('string');

    const decoded = verifyRefreshToken(refreshToken);
    expect(decoded.userId).toBe(samplePayload.userId);
  });

  it('should throw UnauthorizedError for expired or malformed token', () => {
    expect(() => {
      verifyAccessToken('invalid.token.signature');
    }).toThrow(UnauthorizedError);

    // Fast-expiring token
    const expiredToken = signAccessToken(samplePayload, '1ms');
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        expect(() => {
          verifyAccessToken(expiredToken);
        }).toThrow(UnauthorizedError);
        resolve();
      }, 50);
    });
  });
});
