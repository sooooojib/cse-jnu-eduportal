import { z } from 'zod';
import { RequestValidationSchema } from '../../common/middlewares/validate';

export const requestBookingBodySchema = z.object({
  category: z.enum(
    [
      'ACADEMIC_ADVISING',
      'RESEARCH_DISCUSSION',
      'MENTAL_PRESSURE',
      'CLASS_ISSUE',
      'CAREER_GUIDANCE',
      'OTHER',
    ],
    {
      required_error: 'Category is required.',
    }
  ),
  notes: z
    .string({ required_error: 'Notes are required.' })
    .min(5, 'Notes must be at least 5 characters.')
    .max(500, 'Notes cannot exceed 500 characters.'),
});

export const requestBookingSchema: RequestValidationSchema = {
  body: requestBookingBodySchema,
  params: z.object({
    id: z.string().uuid('Invalid slot ID.'),
  }),
};
