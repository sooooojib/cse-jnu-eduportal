import { Router } from 'express';
import { curriculumController } from './curriculum.controller';
import { authenticate } from '../../common/middlewares/auth';
import { validate } from '../../common/middlewares/validate';
import { getScheduleSchema, getExamsSchema } from './curriculum.schemas';

const router = Router();

router.use(authenticate);

router.get('/courses/my-courses', (req, res, next) => curriculumController.getMyCourses(req, res, next));
router.get('/schedule', validate(getScheduleSchema), (req, res, next) => curriculumController.getSchedule(req, res, next));
router.get('/exams', validate(getExamsSchema), (req, res, next) => curriculumController.getExams(req, res, next));

export default router;
