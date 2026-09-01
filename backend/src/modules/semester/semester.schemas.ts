import { z } from 'zod';
import { RequestValidationSchema } from '../../common/middlewares/validate';

export const semesterRequestBodySchema = z.object({
  requestedYear: z.number({ required_error: 'Requested year is required.' }).min(1).max(4),
  requestedSemester: z.number({ required_error: 'Requested semester is required.' }).min(1).max(2),
});

export const semesterRequestSchema: RequestValidationSchema = {
  body: semesterRequestBodySchema,
};
