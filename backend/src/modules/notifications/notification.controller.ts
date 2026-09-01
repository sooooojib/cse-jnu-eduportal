import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../common/types';
import { notificationService } from './notification.service';
import { sendSuccess } from '../../common/utils/response';

export class NotificationController {
  async getNotifications(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const feed = await notificationService.getNotifications(req.user!.id);
      sendSuccess(res, feed);
    } catch (err) {
      next(err);
    }
  }

  async markAsRead(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const notificationId = req.params.id;
      await notificationService.markAsRead(req.user!.id, notificationId);
      sendSuccess(res, null, 'Notification marked as read.');
    } catch (err) {
      next(err);
    }
  }

  async markAllAsRead(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      await notificationService.markAllAsRead(req.user!.id);
      sendSuccess(res, null, 'All notifications marked as read.');
    } catch (err) {
      next(err);
    }
  }
}

export const notificationController = new NotificationController();
