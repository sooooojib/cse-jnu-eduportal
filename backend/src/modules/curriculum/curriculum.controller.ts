import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../common/types';
import { curriculumService } from './curriculum.service';
import { sendSuccess } from '../../common/utils/response';

export class CurriculumController {
  async getMyCourses(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const year = req.user?.year;
      const semester = req.user?.semester;
      const courses = await curriculumService.getMyCourses(year, semester);
      sendSuccess(res, courses);
    } catch (err) {
      next(err);
    }
  }

  async getSchedule(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const year = req.query.year ? Number(req.query.year) : req.user?.year;
      const semester = req.query.semester ? Number(req.query.semester) : req.user?.semester;
      const day = req.query.day as string | undefined;

      const schedule = await curriculumService.getSchedule(year, semester, day);
      sendSuccess(res, schedule);
    } catch (err) {
      next(err);
    }
  }

  async getExams(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const year = req.query.year ? Number(req.query.year) : req.user?.year;
      const semester = req.query.semester ? Number(req.query.semester) : req.user?.semester;

      const exams = await curriculumService.getExams(year, semester);
      sendSuccess(res, exams);
    } catch (err) {
      next(err);
    }
  }
}

export const curriculumController = new CurriculumController();
