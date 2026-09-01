import { z } from 'zod';
import { RequestValidationSchema } from '../../common/middlewares/validate';

export const submitFeedbackBodySchema = z.object({
  teacherId: z.string({ required_error: 'Teacher is required.' }).uuid('Invalid teacher ID.'),
  courseId: z.string().uuid('Invalid course ID.').optional().nullable(),
  rating: z
    .number({ required_error: 'Rating is required.' })
    .int()
    .min(1, 'Rating must be at least 1 star.')
    .max(5, 'Rating cannot exceed 5 stars.'),
  comments: z
    .string({ required_error: 'Feedback comment is required.' })
    .min(10, 'Comment must be at least 10 characters long.')
    .max(2000, 'Comment cannot exceed 2000 characters.'),
  isAnonymous: z.boolean().default(false),
});

export const submitFeedbackSchema: RequestValidationSchema = {
  body: submitFeedbackBodySchema,
};
