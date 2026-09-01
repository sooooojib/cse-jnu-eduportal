import { z } from 'zod';
import { UserRole } from '../../common/constants/roles';
import { RequestValidationSchema } from '../../common/middlewares/validate';

export const loginBodySchema = z.object({
  email: z.string({ required_error: 'Email is required.' }).email('Invalid email address format.'),
  password: z.string({ required_error: 'Password is required.' }).min(1, 'Password cannot be empty.'),
});

export const signupRequestBodySchema = z
  .object({
    fullName: z
      .string({ required_error: 'Full name is required.' })
      .min(2, 'Full name must be at least 2 characters.')
      .max(100, 'Full name cannot exceed 100 characters.'),
    email: z.string({ required_error: 'Email is required.' }).email('Invalid email address format.'),
    role: z.enum([UserRole.STUDENT, UserRole.CR, UserRole.TEACHER], {
      required_error: 'Role must be STUDENT, CR, or TEACHER.',
    }),
    studentId: z
      .string()
      .regex(/^[Bb]\d{9}$/, 'Student ID must start with B followed by 9 digits (total 10 characters, e.g. B210305015).')
      .optional()
      .nullable(),
    phone: z.string().max(20).optional().nullable(),
  })
  .superRefine((data, ctx) => {
    if ((data.role === UserRole.STUDENT || data.role === UserRole.CR) && !data.studentId) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['studentId'],
        message: 'Student ID is required for Student and CR accounts.',
      });
    }
    if (data.role === UserRole.TEACHER && !data.phone) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['phone'],
        message: 'Phone number is required for Teacher accounts.',
      });
    }
  });

export const refreshTokenBodySchema = z.object({
  refreshToken: z.string({ required_error: 'Refresh token is required.' }).min(1, 'Refresh token cannot be empty.'),
});

export const changePasswordBodySchema = z.object({
  currentPassword: z.string({ required_error: 'Current password is required.' }).min(1, 'Current password cannot be empty.'),
  newPassword: z
    .string({ required_error: 'New password is required.' })
    .min(8, 'New password must be at least 8 characters long.')
    .regex(/[A-Z]/, 'New password must contain at least one uppercase letter.')
    .regex(/[a-z]/, 'New password must contain at least one lowercase letter.')
    .regex(/[0-9]/, 'New password must contain at least one number.')
    .regex(/[^A-Za-z0-9]/, 'New password must contain at least one special character.'),
});

export const loginSchema: RequestValidationSchema = {
  body: loginBodySchema,
};

export const signupRequestSchema: RequestValidationSchema = {
  body: signupRequestBodySchema,
};

export const refreshTokenSchema: RequestValidationSchema = {
  body: refreshTokenBodySchema,
};

export const changePasswordSchema: RequestValidationSchema = {
  body: changePasswordBodySchema,
};

export type LoginInput = z.infer<typeof loginBodySchema>;
export type SignupRequestInput = z.infer<typeof signupRequestBodySchema>;
export type RefreshTokenInput = z.infer<typeof refreshTokenBodySchema>;
export type ChangePasswordInput = z.infer<typeof changePasswordBodySchema>;
