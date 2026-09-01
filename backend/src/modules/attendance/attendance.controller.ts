import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../common/types';
import { attendanceService } from './attendance.service';
import { sendSuccess } from '../../common/utils/response';

export class AttendanceController {
  async getMySummary(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const summary = await attendanceService.getMySummary(
        req.user!.id,
        req.user?.year,
        req.user?.semester
      );
      sendSuccess(res, summary);
    } catch (err) {
      next(err);
    }
  }

  async verifyCode(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { code, courseId } = req.body;
      const result = await attendanceService.verifyCode(req.user!.id, code, courseId);
      sendSuccess(res, result, 'Attendance marked successfully.', 200);
    } catch (err) {
      next(err);
    }
  }
}

export const attendanceController = new AttendanceController();
