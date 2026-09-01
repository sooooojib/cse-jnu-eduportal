import { Request, Response } from 'express';
import { checkDatabaseHealth } from '../../config/database';
import { sendSuccess } from '../../common/utils/response';
import { env } from '../../config/env';

export class HealthController {
  public static async getHealth(_req: Request, res: Response): Promise<Response> {
    const dbHealth = await checkDatabaseHealth();
    const isHealthy = dbHealth.connected;

    const healthData = {
      status: isHealthy ? 'healthy' : 'degraded',
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
      database: {
        status: dbHealth.connected ? 'connected' : 'disconnected',
        latencyMs: dbHealth.latencyMs,
        ...(dbHealth.error ? { error: dbHealth.error } : {}),
      },
      version: '1.0.0',
      environment: env.NODE_ENV,
    };

    return sendSuccess(
      res,
      healthData,
      isHealthy ? 'Service is operational.' : 'Service is operating in degraded mode.'
    );
  }
}
