import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../common/types';
import { counselingService } from './counseling.service';
import { sendSuccess } from '../../common/utils/response';

export class CounselingController {
  async getAvailableSlots(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const teacherId = req.query.teacherId as string | undefined;
      const slots = await counselingService.getAvailableSlots(teacherId);
      sendSuccess(res, slots);
    } catch (err) {
      next(err);
    }
  }

  async requestBooking(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const slotId = req.params.id;
      const { category, notes } = req.body;
      const booking = await counselingService.requestBooking(req.user!.id, slotId, category, notes);
      sendSuccess(res, booking, 'Counseling appointment request submitted.', 201);
    } catch (err) {
      next(err);
    }
  }

  async getMyBookings(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const bookings = await counselingService.getMyBookings(req.user!.id);
      sendSuccess(res, bookings);
    } catch (err) {
      next(err);
    }
  }

  async cancelBooking(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const requestId = req.params.id;
      const result = await counselingService.cancelBooking(req.user!.id, requestId);
      sendSuccess(res, result);
    } catch (err) {
      next(err);
    }
  }
}

export const counselingController = new CounselingController();
