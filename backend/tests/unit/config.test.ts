import { env } from '../../src/config/env';

describe('Environment Configuration', () => {
  it('should load environment configuration with valid defaults', () => {
    expect(env).toBeDefined();
    expect(env.NODE_ENV).toBe('test');
    expect(env.PORT).toBe(5001);
    expect(env.API_PREFIX).toBe('/api/v1');
    expect(env.JWT_ACCESS_SECRET).toBeDefined();
    expect(env.JWT_REFRESH_SECRET).toBeDefined();
  });

  it('should have valid database connection parameters', () => {
    expect(env.DB_HOST).toBeDefined();
    expect(typeof env.DB_PORT).toBe('number');
    expect(env.DB_USER).toBeDefined();
    expect(env.DB_NAME).toBeDefined();
  });
});
