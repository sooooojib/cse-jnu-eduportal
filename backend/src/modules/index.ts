import { Router } from 'express';
import healthRoutes from './health/health.routes';
import authRoutes from './auth/auth.routes';
import curriculumRoutes from './curriculum/curriculum.routes';
import semesterRoutes from './semester/semester.routes';
import attendanceRoutes from './attendance/attendance.routes';
import counselingRoutes from './counseling/counseling.routes';
import feedbackRoutes from './feedback/feedback.routes';
import notificationRoutes from './notifications/notification.routes';

const apiRouter = Router();

// Subsystem Routers
apiRouter.use('/health', healthRoutes);
apiRouter.use('/auth', authRoutes);
apiRouter.use('/curriculum', curriculumRoutes);
apiRouter.use('/semester', semesterRoutes);
apiRouter.use('/attendance', attendanceRoutes);
apiRouter.use('/counseling', counselingRoutes);
apiRouter.use('/feedback', feedbackRoutes);
apiRouter.use('/notifications', notificationRoutes);

export default apiRouter;
