import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../common/types';
import { feedbackService } from './feedback.service';
import { sendSuccess } from '../../common/utils/response';

export class FeedbackController {
  async submitFeedback(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const { teacherId, courseId, rating, comments, isAnonymous } = req.body;
      const feedback = await feedbackService.submitFeedback(
        req.user!.id,
        teacherId,
        courseId,
        rating,
        comments,
        isAnonymous ?? false
      );
      sendSuccess(res, feedback, 'Feedback submitted successfully.', 201);
    } catch (err) {
      next(err);
    }
  }

  async getMySubmissions(req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> {
    try {
      const submissions = await feedbackService.getMySubmissions(req.user!.id);
      sendSuccess(res, submissions);
    } catch (err) {
      next(err);
    }
  }
}

export const feedbackController = new FeedbackController();
