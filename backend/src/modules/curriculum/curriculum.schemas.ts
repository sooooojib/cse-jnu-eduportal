import { z } from 'zod';
import { RequestValidationSchema } from '../../common/middlewares/validate';

export const getScheduleQuerySchema = z.object({
  day: z.enum(['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY']).optional(),
  year: z.coerce.number().min(1).max(4).optional(),
  semester: z.coerce.number().min(1).max(2).optional(),
});

export const getExamsQuerySchema = z.object({
  year: z.coerce.number().min(1).max(4).optional(),
  semester: z.coerce.number().min(1).max(2).optional(),
});

export const getScheduleSchema: RequestValidationSchema = {
  query: getScheduleQuerySchema,
};

export const getExamsSchema: RequestValidationSchema = {
  query: getExamsQuerySchema,
};
