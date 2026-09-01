import express, { Request, Response } from 'express';
import request from 'supertest';
import { z } from 'zod';
import { validate } from '../../src/common/middlewares/validate';
import { errorHandler } from '../../src/common/middlewares/error-handler';

describe('Validation Middleware', () => {
  const testSchema = {
    body: z.object({
      name: z.string().min(3, 'Name must be at least 3 characters'),
      rating: z.number().int().min(1).max(5),
    }),
  };

  const app = express();
  app.use(express.json());
  app.post('/test-validate', validate(testSchema), (_req: Request, res: Response) => {
    res.status(200).json({ success: true });
  });
  app.use(errorHandler);

  it('should accept valid request payload', async () => {
    const res = await request(app)
      .post('/test-validate')
      .send({ name: 'Valid Name', rating: 4 });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  it('should reject invalid payload with 422 and structured details', async () => {
    const res = await request(app)
      .post('/test-validate')
      .send({ name: 'ab', rating: 10 });

    expect(res.status).toBe(422);
    expect(res.body.success).toBe(false);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(Array.isArray(res.body.error.details)).toBe(true);
    expect(res.body.error.details.length).toBe(2);
    expect(res.body.error.details[0].field).toBe('name');
    expect(res.body.error.details[1].field).toBe('rating');
  });
});
