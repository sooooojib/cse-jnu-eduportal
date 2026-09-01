import {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  getTokenExpirationDate,
} from '../../src/common/utils/token';
import { UserRole } from '../../src/common/constants/roles';

describe('Session & Token Utilities', () => {
  const userId = '11111111-2222-3333-4444-555555555555';

  it('should generate distinct refresh tokens with unique JTIs for the same user', () => {
    const token1 = signRefreshToken({ userId });
    const token2 = signRefreshToken({ userId });

    expect(token1).not.toBe(token2);

    const decoded1 = verifyRefreshToken(token1);
    const decoded2 = verifyRefreshToken(token2);

    expect(decoded1.userId).toBe(userId);
    expect(decoded2.userId).toBe(userId);
    expect(decoded1.jti).toBeDefined();
    expect(decoded2.jti).toBeDefined();
    expect(decoded1.jti).not.toBe(decoded2.jti);
  });

  it('should extract valid expiration date from token', () => {
    const token = signAccessToken({
      userId,
      email: 'student@cse.jnu.ac.bd',
      role: UserRole.STUDENT,
      year: 3,
      semester: 1,
    });

    const expDate = getTokenExpirationDate(token);
    expect(expDate instanceof Date).toBe(true);
    expect(expDate.getTime()).toBeGreaterThan(Date.now());
  });

  it('should verify access token claims and role correctly', () => {
    const token = signAccessToken({
      userId,
      email: 'admin@cse.jnu.ac.bd',
      role: UserRole.ADMIN,
      year: null,
      semester: null,
    });

    const decoded = verifyAccessToken(token);
    expect(decoded.role).toBe(UserRole.ADMIN);
    expect(decoded.email).toBe('admin@cse.jnu.ac.bd');
  });
});
