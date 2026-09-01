import dotenv from 'dotenv';
import path from 'path';
import { z } from 'zod';

// Load .env file from root of backend
dotenv.config({ path: path.resolve(process.cwd(), '.env') });

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z
    .string()
    .default('5000')
    .transform((val) => parseInt(val, 10))
    .refine((val) => val > 0 && val < 65536, {
      message: 'PORT must be a valid port number between 1 and 65535',
    }),
  API_PREFIX: z.string().default('/api/v1'),
  CORS_ORIGIN: z.string().default('*'),

  // PostgreSQL Connection Configuration
  DATABASE_URL: z
    .string()
    .optional()
    .default('postgresql://postgres:postgres@localhost:5432/cse_jnu_eduportal'),
  DB_HOST: z.string().default('localhost'),
  DB_PORT: z
    .string()
    .default('5432')
    .transform((val) => parseInt(val, 10)),
  DB_USER: z.string().default('postgres'),
  DB_PASSWORD: z.string().default('postgres'),
  DB_NAME: z.string().default('cse_jnu_eduportal'),
  DB_SSL: z
    .string()
    .default('false')
    .transform((val) => val === 'true'),
  DB_POOL_MIN: z
    .string()
    .default('2')
    .transform((val) => parseInt(val, 10)),
  DB_POOL_MAX: z
    .string()
    .default('20')
    .transform((val) => parseInt(val, 10)),

  // JWT Security
  JWT_ACCESS_SECRET: z
    .string()
    .min(16, 'JWT_ACCESS_SECRET must be at least 16 characters long')
    .default('cse_jnu_eduportal_super_secret_access_jwt_key_2026'),
  JWT_REFRESH_SECRET: z
    .string()
    .min(16, 'JWT_REFRESH_SECRET must be at least 16 characters long')
    .default('cse_jnu_eduportal_super_secret_refresh_jwt_key_2026'),
  JWT_ACCESS_EXPIRES_IN: z.string().default('15m'),
  JWT_REFRESH_EXPIRES_IN: z.string().default('7d'),

  // Logging
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
});

export type EnvConfig = z.infer<typeof envSchema>;

function validateEnv(): EnvConfig {
  const result = envSchema.safeParse(process.env);

  if (!result.success) {
    const errorDetails = result.error.issues
      .map((issue) => ` - ${issue.path.join('.')}: ${issue.message}`)
      .join('\n');
    console.error(`[CONFIG ERROR] Invalid environment configuration:\n${errorDetails}`);
    process.exit(1);
  }

  return result.data;
}

export const env = validateEnv();
