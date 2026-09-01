import { Router } from 'express';
import { HealthController } from './health.controller';
import { asyncHandler } from '../../common/utils/async-handler';

const router = Router();

// GET /api/v1/health & /health
router.get('/', asyncHandler(HealthController.getHealth));

export default router;
