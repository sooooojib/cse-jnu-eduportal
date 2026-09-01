import { Router } from 'express';
import { semesterController } from './semester.controller';
import { authenticate } from '../../common/middlewares/auth';
import { validate } from '../../common/middlewares/validate';
import { semesterRequestSchema } from './semester.schemas';

const router = Router();

router.use(authenticate);

router.get('/status', (req, res, next) => semesterController.getStatus(req, res, next));
router.post('/request', validate(semesterRequestSchema), (req, res, next) => semesterController.requestUpgrade(req, res, next));

export default router;
