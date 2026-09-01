import { Router } from 'express';
import { counselingController } from './counseling.controller';
import { authenticate } from '../../common/middlewares/auth';
import { validate } from '../../common/middlewares/validate';
import { requestBookingSchema } from './counseling.schemas';

const router = Router();

router.use(authenticate);

router.get('/slots', (req, res, next) => counselingController.getAvailableSlots(req, res, next));
router.post('/slots/:id/request', validate(requestBookingSchema), (req, res, next) => counselingController.requestBooking(req, res, next));
router.get('/my-bookings', (req, res, next) => counselingController.getMyBookings(req, res, next));
router.patch('/requests/:id/cancel', (req, res, next) => counselingController.cancelBooking(req, res, next));

export default router;
