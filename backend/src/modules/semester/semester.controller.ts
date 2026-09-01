import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../common/types';
import { semesterService } from './semester.service';
import { sendSuccess } from '../../common/utils/response';

export class SemesterController {
  async getStatus(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const status = await semesterService.getStatus(req.user!.id);
      sendSuccess(res, status);
    } catch (err) {
      next(err);
    }
  }

  async requestUpgrade(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { requestedYear, requestedSemester } = req.body;
      const status = await semesterService.requestUpgrade(req.user!.id, requestedYear, requestedSemester);
      sendSuccess(res, status, 'Semester upgrade request submitted successfully.', 201);
    } catch (err) {
      next(err);
    }
  }
}

export const semesterController = new SemesterController();
