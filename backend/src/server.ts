import { app } from './app';
import { env } from './config/env';
import { checkDatabaseHealth, closeDatabasePool } from './config/database';
import { logger } from './common/utils/logger';

async function bootstrap() {
  logger.info({ environment: env.NODE_ENV, port: env.PORT }, 'Starting CSE JnU EduPortal Backend...');

  // Diagnostic database connection check
  const dbHealth = await checkDatabaseHealth();
  if (dbHealth.connected) {
    logger.info({ latencyMs: dbHealth.latencyMs }, 'PostgreSQL database connection verified.');
  } else {
    logger.warn({ error: dbHealth.error }, 'Database connection not immediately available. Server starting with fallback diagnostics.');
  }

  const server = app.listen(env.PORT, () => {
    logger.info(`Server running on http://localhost:${env.PORT}${env.API_PREFIX}`);
    logger.info(`Health check available at http://localhost:${env.PORT}/health and ${env.API_PREFIX}/health`);
  });

  // Graceful shutdown handling
  const shutdown = async (signal: string) => {
    logger.info(`Received ${signal}. Gracefully terminating backend server...`);
    server.close(async () => {
      logger.info('HTTP server closed.');
      await closeDatabasePool();
      process.exit(0);
    });

    // Force terminate after 10s if hanging
    setTimeout(() => {
      logger.error('Could not close connections in time, forcefully shutting down');
      process.exit(1);
    }, 10000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  process.on('uncaughtException', (err) => {
    logger.error({ err }, 'Uncaught Exception detected');
  });

  process.on('unhandledRejection', (reason) => {
    logger.error({ reason }, 'Unhandled Rejection detected');
  });
}

if (require.main === module) {
  bootstrap().catch((err) => {
    logger.error({ err }, 'Bootstrap failure: Unable to start server');
    process.exit(1);
  });
}
