import { Request, Response } from 'express';
import { AuthService } from './auth.service';
import { sendSuccess, sendCreated } from '../../common/utils/response';
import { AuthenticatedRequest } from '../../common/types';
import { UnauthorizedError } from '../../common/errors';

export class AuthController {
  public static async login(req: Request, res: Response): Promise<Response> {
    const result = await AuthService.login(req.body);
    return sendSuccess(res, result, 'Authentication successful.');
  }

  public static async signupRequest(req: Request, res: Response): Promise<Response> {
    const result = await AuthService.submitSignupRequest(req.body);
    return sendCreated(
      res,
      result,
      'Your registration request has been submitted for admin approval. You will receive an email with your credentials once approved.'
    );
  }

  public static async refreshToken(req: Request, res: Response): Promise<Response> {
    const result = await AuthService.refreshToken(req.body);
    return sendSuccess(res, result, 'Token refreshed successfully.');
  }

  public static async getMe(req: AuthenticatedRequest, res: Response): Promise<Response> {
    if (!req.user?.id) {
      throw new UnauthorizedError();
    }
    const result = await AuthService.getMe(req.user.id);
    return sendSuccess(res, result, 'User profile retrieved.');
  }

  public static async changePassword(req: AuthenticatedRequest, res: Response): Promise<Response> {
    if (!req.user?.id) {
      throw new UnauthorizedError();
    }
    await AuthService.changePassword(req.user.id, req.body);
    return sendSuccess(res, null, 'Password changed successfully.');
  }

  public static async logout(req: AuthenticatedRequest, res: Response): Promise<Response> {
    if (!req.user?.id) {
      throw new UnauthorizedError();
    }
    const refreshToken = req.body?.refreshToken as string | undefined;
    await AuthService.logout(req.user.id, refreshToken);
    return sendSuccess(res, null, 'Logged out successfully.');
  }
}
