import { query, withTransaction } from '../../config/database';
import { BadRequestError, ConflictError, NotFoundError } from '../../common/errors';

export interface AvailableSlotDto {
  id: string;
  teacherId: string;
  teacherName: string;
  teacherEmail: string;
  slotDate: string;
  startTime: string;
  endTime: string;
  status: string;
  notes: string | null;
}

export interface CounselingBookingDto {
  id: string;
  slotId: string;
  teacherId: string;
  teacherName: string;
  slotDate: string;
  startTime: string;
  endTime: string;
  category: string;
  notes: string;
  status: string;
  reviewedAt: string | null;
  createdAt: string;
}

export class CounselingService {
  async getAvailableSlots(teacherId?: string): Promise<AvailableSlotDto[]> {
    let sql = `
      SELECT 
        cs.id,
        cs.teacher_id AS "teacherId",
        u.full_name AS "teacherName",
        u.email AS "teacherEmail",
        cs.slot_date::TEXT AS "slotDate",
        cs.start_time AS "startTime",
        cs.end_time AS "endTime",
        cs.status,
        cs.notes
      FROM counseling_slots cs
      JOIN users u ON u.id = cs.teacher_id
      WHERE cs.status = 'AVAILABLE' AND cs.slot_date >= CURRENT_DATE
    `;

    const params: any[] = [];
    if (teacherId) {
      params.push(teacherId);
      sql += ` AND cs.teacher_id = $${params.length}`;
    }

    sql += ` ORDER BY cs.slot_date ASC, cs.start_time ASC;`;

    const result = await query<AvailableSlotDto>(sql, params);
    return result.rows;
  }

  async requestBooking(
    studentId: string,
    slotId: string,
    category: string,
    notes: string
  ): Promise<CounselingBookingDto> {
    const slotRes = await query<{ id: string; status: string }>(
      `SELECT id, status FROM counseling_slots WHERE id = $1`,
      [slotId]
    );

    if (slotRes.rows.length === 0) {
      throw new NotFoundError('Counseling slot not found.');
    }

    if (slotRes.rows[0].status !== 'AVAILABLE') {
      throw new BadRequestError('This counseling slot is no longer available.');
    }

    // Check if student already submitted a request for this slot
    const existingRes = await query(
      `SELECT id FROM counseling_requests WHERE slot_id = $1 AND student_id = $2`,
      [slotId, studentId]
    );

    if (existingRes.rows.length > 0) {
      throw new ConflictError('You have already submitted a booking request for this slot.');
    }

    const insertRes = await query<{ id: string; created_at: Date }>(
      `INSERT INTO counseling_requests (slot_id, student_id, category, notes, status)
       VALUES ($1, $2, $3, $4, 'PENDING')
       RETURNING id, created_at`,
      [slotId, studentId, category, notes]
    );

    const bookingRes = await this.getBookingById(insertRes.rows[0].id);
    return bookingRes!;
  }

  async getMyBookings(studentId: string): Promise<CounselingBookingDto[]> {
    const sql = `
      SELECT 
        cr.id,
        cr.slot_id AS "slotId",
        cs.teacher_id AS "teacherId",
        u.full_name AS "teacherName",
        cs.slot_date::TEXT AS "slotDate",
        cs.start_time AS "startTime",
        cs.end_time AS "endTime",
        cr.category,
        cr.notes,
        cr.status,
        cr.reviewed_at AS "reviewedAt",
        cr.created_at AS "createdAt"
      FROM counseling_requests cr
      JOIN counseling_slots cs ON cs.id = cr.slot_id
      JOIN users u ON u.id = cs.teacher_id
      WHERE cr.student_id = $1
      ORDER BY cs.slot_date DESC, cs.start_time DESC;
    `;

    const result = await query<CounselingBookingDto>(sql, [studentId]);
    return result.rows;
  }

  async cancelBooking(studentId: string, requestId: string): Promise<{ success: boolean; message: string }> {
    return withTransaction(async (client) => {
      const reqRes = await client.query<{ id: string; slot_id: string; status: string }>(
        `SELECT id, slot_id, status FROM counseling_requests WHERE id = $1 AND student_id = $2`,
        [requestId, studentId]
      );

      if (reqRes.rows.length === 0) {
        throw new NotFoundError('Counseling request not found.');
      }

      const req = reqRes.rows[0];

      if (req.status === 'REJECTED') {
        throw new BadRequestError('Cannot cancel a rejected request.');
      }

      // If approved, free the slot back to AVAILABLE
      if (req.status === 'APPROVED') {
        await client.query(
          `UPDATE counseling_slots SET status = 'AVAILABLE', booked_student_id = NULL, updated_at = NOW() WHERE id = $1`,
          [req.slot_id]
        );
      }

      await client.query(`DELETE FROM counseling_requests WHERE id = $1`, [requestId]);

      return { success: true, message: 'Appointment request cancelled successfully.' };
    });
  }

  private async getBookingById(requestId: string): Promise<CounselingBookingDto | null> {
    const sql = `
      SELECT 
        cr.id,
        cr.slot_id AS "slotId",
        cs.teacher_id AS "teacherId",
        u.full_name AS "teacherName",
        cs.slot_date::TEXT AS "slotDate",
        cs.start_time AS "startTime",
        cs.end_time AS "endTime",
        cr.category,
        cr.notes,
        cr.status,
        cr.reviewed_at AS "reviewedAt",
        cr.created_at AS "createdAt"
      FROM counseling_requests cr
      JOIN counseling_slots cs ON cs.id = cr.slot_id
      JOIN users u ON u.id = cs.teacher_id
      WHERE cr.id = $1;
    `;
    const res = await query<CounselingBookingDto>(sql, [requestId]);
    return res.rows[0] ?? null;
  }
}

export const counselingService = new CounselingService();
