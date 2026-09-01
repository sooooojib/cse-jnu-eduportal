import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import { env } from './env';
import { logger } from '../common/utils/logger';

let pool: Pool | null = null;

export function getDatabasePool(): Pool {
  if (!pool) {
    const config = env.DATABASE_URL
      ? {
          connectionString: env.DATABASE_URL,
          ssl: env.DB_SSL ? { rejectUnauthorized: false } : false,
          min: env.DB_POOL_MIN,
          max: env.DB_POOL_MAX,
        }
      : {
          host: env.DB_HOST,
          port: env.DB_PORT,
          user: env.DB_USER,
          password: env.DB_PASSWORD,
          database: env.DB_NAME,
          ssl: env.DB_SSL ? { rejectUnauthorized: false } : false,
          min: env.DB_POOL_MIN,
          max: env.DB_POOL_MAX,
        };

    pool = new Pool(config);

    pool.on('error', (err) => {
      logger.error({ err }, 'Unexpected error on idle database client');
    });
  }

  return pool;
}

/**
 * Executes a parameterized SQL query against the database pool.
 */
export async function query<R extends QueryResultRow = QueryResultRow>(
  text: string,
  params?: unknown[]
): Promise<QueryResult<R>> {
  const currentPool = getDatabasePool();
  const start = Date.now();
  try {
    const result = await currentPool.query<R>(text, params);
    const duration = Date.now() - start;
    logger.debug({ text, duration, rows: result.rowCount }, 'Executed SQL query');
    return result;
  } catch (error) {
    logger.error({ text, params, error }, 'SQL query execution failed');
    throw error;
  }
}

/**
 * Runs a set of operations inside an isolated, atomic database transaction.
 * Automatically performs COMMIT on success or ROLLBACK on any thrown error.
 */
export async function withTransaction<T>(
  callback: (client: PoolClient) => Promise<T>
): Promise<T> {
  const currentPool = getDatabasePool();
  const client = await currentPool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Probes the database connection status and measures latency.
 */
export async function checkDatabaseHealth(): Promise<{
  connected: boolean;
  latencyMs: number;
  error?: string;
}> {
  const start = Date.now();
  try {
    await query('SELECT 1 AS health_check');
    return {
      connected: true,
      latencyMs: Date.now() - start,
    };
  } catch (err: unknown) {
    return {
      connected: false,
      latencyMs: Date.now() - start,
      error: err instanceof Error ? err.message : 'Database connection failed',
    };
  }
}

/**
 * Closes the database pool gracefully.
 */
export async function closeDatabasePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
    logger.info('Database connection pool closed.');
  }
}
