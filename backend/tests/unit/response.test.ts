import express, { Request, Response } from 'express';
import request from 'supertest';
import { sendPaginated, sendSuccess, sendCreated } from '../../src/common/utils/response';

describe('Response Utility', () => {
  const app = express();
  app.get('/test-paginated', (_req: Request, res: Response) => {
    return sendPaginated(
      res,
      [{ id: '1', name: 'Course 1' }],
      { page: 2, limit: 10, total: 25 },
      'Courses list'
    );
  });

  app.post('/test-created', (_req: Request, res: Response) => {
    return sendCreated(res, { id: 'new-id' }, 'Item created');
  });

  app.get('/test-success', (_req: Request, res: Response) => {
    return sendSuccess(res, { key: 'value' });
  });

  it('should format paginated response envelope with pagination metadata', async () => {
    const res = await request(app).get('/test-paginated');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.meta.page).toBe(2);
    expect(res.body.meta.limit).toBe(10);
    expect(res.body.meta.total).toBe(25);
    expect(res.body.meta.totalPages).toBe(3);
    expect(res.body.meta.hasNextPage).toBe(true);
    expect(res.body.meta.hasPrevPage).toBe(true);
  });

  it('should format 201 created response', async () => {
    const res = await request(app).post('/test-created');

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.id).toBe('new-id');
  });

  it('should format 200 success response', async () => {
    const res = await request(app).get('/test-success');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.key).toBe('value');
  });
});
