process.env.NODE_ENV = 'test';
process.env.PORT = '5001';
process.env.JWT_ACCESS_SECRET = 'test_super_secret_access_jwt_key_at_least_32_characters';
process.env.JWT_REFRESH_SECRET = 'test_super_secret_refresh_jwt_key_at_least_32_characters';

import { closeDatabasePool } from '../src/config/database';

afterAll(async () => {
  await closeDatabasePool();
});
