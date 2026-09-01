import { Router } from 'express';
import { feedbackController } from './feedback.controller';
import { authenticate } from '../../common/middlewares/auth';
import { validate } from '../../common/middlewares/validate';
import { submitFeedbackSchema } from './feedback.schemas';

const router = Router();

router.use(authenticate);

router.post('/', validate(submitFeedbackSchema), (req, res, next) => feedbackController.submitFeedback(req, res, next));
router.get('/my-submissions', (req, res, next) => feedbackController.getMySubmissions(req, res, next));

export default router;
