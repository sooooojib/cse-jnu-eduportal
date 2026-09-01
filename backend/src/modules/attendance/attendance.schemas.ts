import { z } from 'zod';
import { RequestValidationSchema } from '../../common/middlewares/validate';

export const verifyAttendanceBodySchema = z.object({
  code: z
    .string({ required_error: 'Verification code is required.' })
    .length(6, 'Verification code must be exactly 6 characters.'),
  courseId: z.string().uuid().optional(),
});

export const verifyAttendanceSchema: RequestValidationSchema = {
  body: verifyAttendanceBodySchema,
};
