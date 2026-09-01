import { Router } from 'express';
import { AuthController } from './auth.controller';
import { validate } from '../../common/middlewares/validate';
import { authenticate } from '../../common/middlewares/auth';
import { asyncHandler } from '../../common/utils/async-handler';
import {
  loginSchema,
  signupRequestSchema,
  refreshTokenSchema,
  changePasswordSchema,
} from './auth.schemas';

const router = Router();

// Public routes
router.post('/login', validate(loginSchema), asyncHandler(AuthController.login));
router.post('/signup-request', validate(signupRequestSchema), asyncHandler(AuthController.signupRequest));
router.post('/refresh-token', validate(refreshTokenSchema), asyncHandler(AuthController.refreshToken));

// Protected routes
router.get('/me', authenticate, asyncHandler(AuthController.getMe));
router.post('/change-password', authenticate, validate(changePasswordSchema), asyncHandler(AuthController.changePassword));
router.post('/logout', authenticate, asyncHandler(AuthController.logout));

export default router;
