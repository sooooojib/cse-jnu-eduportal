import express, { Application } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { env } from './config/env';
import { requestLogger } from './common/middlewares/request-logger';
import { notFoundHandler } from './common/middlewares/not-found';
import { errorHandler } from './common/middlewares/error-handler';
import { asyncHandler } from './common/utils/async-handler';
import apiRouter from './modules';
import { HealthController } from './modules/health/health.controller';

export function createApp(): Application {
  const app = express();

  // 1. Security & Protection Middlewares
  app.use(helmet());
  app.use(
    cors({
      origin: env.CORS_ORIGIN === '*' ? '*' : env.CORS_ORIGIN.split(','),
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: [
        'Content-Type',
        'Authorization',
        'Accept',
        'X-Client-Platform',
        'X-App-Version',
      ],
    })
  );

  // 2. Request Body Parsers
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // 3. Request Logging (disable in test environment for clean logs)
  if (env.NODE_ENV !== 'test') {
    app.use(requestLogger);
  }

  // 4. Root Health Check (Convenience Endpoint)
  app.get('/health', asyncHandler(HealthController.getHealth));

  // 5. Modular API Routing (e.g. /api/v1)
  app.use(env.API_PREFIX, apiRouter);

  // 6. 404 Route Not Found Handling
  app.use(notFoundHandler);

  // 7. Centralized Error Handling Pipeline
  app.use(errorHandler);

  return app;
}

export const app = createApp();
