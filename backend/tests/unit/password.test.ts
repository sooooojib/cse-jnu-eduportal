import { hashPassword, comparePassword, generateSecurePassword } from '../../src/common/utils/password';

describe('Password Utility', () => {
  it('should hash and verify passwords accurately', async () => {
    const rawPassword = 'SecurePassword123!';
    const hash = await hashPassword(rawPassword);

    expect(hash).toBeDefined();
    expect(hash).not.toBe(rawPassword);

    const isMatch = await comparePassword(rawPassword, hash);
    expect(isMatch).toBe(true);

    const isWrongMatch = await comparePassword('WrongPassword', hash);
    expect(isWrongMatch).toBe(false);
  });

  it('should generate secure random passwords of requested length', () => {
    const pwd12 = generateSecurePassword(12);
    expect(pwd12.length).toBe(12);

    const pwd16 = generateSecurePassword(16);
    expect(pwd16.length).toBe(16);

    // Enforces at least 8 characters
    const pwdShort = generateSecurePassword(4);
    expect(pwdShort.length).toBe(8);

    // Verify it contains mixed characters
    expect(/[A-Z]/.test(pwd12)).toBe(true);
    expect(/[a-z]/.test(pwd12)).toBe(true);
    expect(/[0-9]/.test(pwd12)).toBe(true);
    expect(/[!@#$%&*]/.test(pwd12)).toBe(true);
  });
});
