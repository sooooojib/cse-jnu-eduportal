import request from 'supertest';
import { app } from '../../src/app';

describe('Health Check API', () => {
  it('GET /health should return 200 and standard envelope', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toBeDefined();
    expect(res.body.data.status).toMatch(/healthy|degraded/);
    expect(res.body.data.uptime).toBeDefined();
    expect(res.body.data.version).toBe('1.0.0');
    expect(res.body.meta.timestamp).toBeDefined();
  });

  it('GET /api/v1/health should return 200 with operational status', async () => {
    const res = await request(app).get('/api/v1/health');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.database).toBeDefined();
    expect(res.body.data.environment).toBe('test');
  });
});
