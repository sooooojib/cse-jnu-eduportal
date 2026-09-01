import fs from 'fs';
import path from 'path';
import { getDatabasePool, withTransaction, closeDatabasePool } from '../../config/database';
import { logger } from '../../common/utils/logger';

const MIGRATIONS_DIR = path.resolve(__dirname, 'migrations');
const SEEDS_DIR = path.resolve(__dirname, 'seeds');

export async function initMigrationTable(): Promise<void> {
  const pool = getDatabasePool();
  await pool.query(`
    CREATE TABLE IF NOT EXISTS _schema_migrations (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255) NOT NULL UNIQUE,
      executed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
}

export async function getExecutedMigrations(): Promise<string[]> {
  const pool = getDatabasePool();
  const res = await pool.query<{ name: string }>(
    'SELECT name FROM _schema_migrations ORDER BY id ASC'
  );
  return res.rows.map((row) => row.name);
}

export async function runMigrations(): Promise<string[]> {
  await initMigrationTable();
  const executed = await getExecutedMigrations();

  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((file) => file.endsWith('.sql'))
    .sort();

  const applied: string[] = [];

  for (const file of files) {
    if (!executed.includes(file)) {
      const filePath = path.join(MIGRATIONS_DIR, file);
      const sql = fs.readFileSync(filePath, 'utf-8');

      logger.info({ file }, 'Applying migration...');
      await withTransaction(async (client) => {
        await client.query(sql);
        await client.query(
          'INSERT INTO _schema_migrations (name) VALUES ($1)',
          [file]
        );
      });
      applied.push(file);
      logger.info({ file }, 'Migration applied successfully.');
    }
  }

  return applied;
}

export async function runSeeds(): Promise<string[]> {
  if (!fs.existsSync(SEEDS_DIR)) return [];

  const files = fs
    .readdirSync(SEEDS_DIR)
    .filter((file) => file.endsWith('.sql'))
    .sort();

  const applied: string[] = [];

  for (const file of files) {
    const filePath = path.join(SEEDS_DIR, file);
    const sql = fs.readFileSync(filePath, 'utf-8');

    logger.info({ file }, 'Executing seed script...');
    await withTransaction(async (client) => {
      await client.query(sql);
    });
    applied.push(file);
    logger.info({ file }, 'Seed script executed successfully.');
  }

  return applied;
}

export async function showStatus(): Promise<void> {
  await initMigrationTable();
  const executed = await getExecutedMigrations();
  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((file) => file.endsWith('.sql'))
    .sort();

  console.log('\n=== Database Migration Status ===');
  for (const file of files) {
    const isExecuted = executed.includes(file);
    console.log(` [${isExecuted ? 'X' : ' '}] ${file}`);
  }
  console.log('=================================\n');
}

// CLI execution
if (require.main === module) {
  const command = process.argv[2] || 'up';

  (async () => {
    try {
      if (command === 'up') {
        const applied = await runMigrations();
        console.log(`Migrations complete. ${applied.length} new migration(s) applied.`);
      } else if (command === 'status') {
        await showStatus();
      } else if (command === 'seed') {
        const applied = await runSeeds();
        console.log(`Seeds complete. ${applied.length} seed file(s) executed.`);
      } else {
        console.error(`Unknown command: ${command}. Use 'up', 'status', or 'seed'.`);
        process.exit(1);
      }
    } catch (err) {
      console.error('Migration execution failed:', err);
      process.exit(1);
    } finally {
      await closeDatabasePool();
    }
  })();
}
