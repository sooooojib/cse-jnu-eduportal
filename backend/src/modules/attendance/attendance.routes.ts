import { Router } from 'express';
import { attendanceController } from './attendance.controller';
import { authenticate } from '../../common/middlewares/auth';
import { validate } from '../../common/middlewares/validate';
import { verifyAttendanceSchema } from './attendance.schemas';

const router = Router();

router.use(authenticate);

router.get('/my-summary', (req, res, next) => attendanceController.getMySummary(req, res, next));
router.post('/verify', validate(verifyAttendanceSchema), (req, res, next) => attendanceController.verifyCode(req, res, next));

export default router;
