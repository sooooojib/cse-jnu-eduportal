import { query, withTransaction } from '../../config/database';
import { ConflictError, NotFoundError } from '../../common/errors';

export interface SemesterStatusDto {
  currentYear: number | null;
  currentSemester: number | null;
  requestedYear: number | null;
  requestedSemester: number | null;
  semesterStatus: string;
  rejectionReason?: string | null;
  updatedAt?: string | null;
}

export class SemesterService {
  async getStatus(userId: string): Promise<SemesterStatusDto> {
    const userRes = await query<{
      year: number | null;
      semester: number | null;
      requested_year: number | null;
      requested_semester: number | null;
      semester_status: string;
      updated_at: Date;
    }>(
      `SELECT year, semester, requested_year, requested_semester, semester_status, updated_at FROM users WHERE id = $1`,
      [userId]
    );

    if (userRes.rows.length === 0) {
      throw new NotFoundError('User profile not found.');
    }

    const user = userRes.rows[0];

    // Check latest request rejection reason if REJECTED
    let rejectionReason: string | null = null;
    if (user.semester_status === 'REJECTED') {
      const reqRes = await query<{ rejection_reason: string | null }>(
        `SELECT rejection_reason FROM semester_requests WHERE student_id = $1 ORDER BY created_at DESC LIMIT 1`,
        [userId]
      );
      if (reqRes.rows.length > 0) {
        rejectionReason = reqRes.rows[0].rejection_reason;
      }
    }

    return {
      currentYear: user.year,
      currentSemester: user.semester,
      requestedYear: user.requested_year,
      requestedSemester: user.requested_semester,
      semesterStatus: user.semester_status,
      rejectionReason,
      updatedAt: user.updated_at ? user.updated_at.toISOString() : null,
    };
  }

  async requestUpgrade(userId: string, requestedYear: number, requestedSemester: number): Promise<SemesterStatusDto> {
    const userRes = await query<{
      year: number;
      semester: number;
      semester_status: string;
    }>(`SELECT year, semester, semester_status FROM users WHERE id = $1`, [userId]);

    if (userRes.rows.length === 0) {
      throw new NotFoundError('User profile not found.');
    }

    const user = userRes.rows[0];

    if (user.semester_status === 'PENDING') {
      throw new ConflictError('A semester upgrade request is already pending review.');
    }

    await withTransaction(async (client) => {
      // Insert into semester_requests
      await client.query(
        `INSERT INTO semester_requests (student_id, current_year, current_semester, requested_year, requested_semester, status)
         VALUES ($1, $2, $3, $4, $5, 'PENDING')`,
        [userId, user.year ?? 1, user.semester ?? 1, requestedYear, requestedSemester]
      );

      // Update user state
      await client.query(
        `UPDATE users 
         SET requested_year = $1, requested_semester = $2, semester_status = 'PENDING', updated_at = NOW() 
         WHERE id = $3`,
        [requestedYear, requestedSemester, userId]
      );
    });

    return this.getStatus(userId);
  }
}

export const semesterService = new SemesterService();
