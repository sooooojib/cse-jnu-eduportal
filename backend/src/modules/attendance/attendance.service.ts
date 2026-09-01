import { query } from '../../config/database';
import { BadRequestError, ConflictError } from '../../common/errors';

export interface CourseAttendanceSummaryDto {
  courseId: string;
  courseCode: string;
  courseTitle: string;
  attendedClasses: number;
  totalClasses: number;
  percentage: number;
  isEligible: boolean;
}

export interface AttendanceRecordDto {
  id: string;
  courseCode: string;
  courseTitle: string;
  status: string;
  verifiedAt: string;
}

export interface StudentAttendanceSummaryDto {
  overallPercentage: number;
  totalAttended: number;
  totalSessions: number;
  courseSummaries: CourseAttendanceSummaryDto[];
  recentRecords: AttendanceRecordDto[];
}

export class AttendanceService {
  async getMySummary(studentId: string, year?: number | null, semester?: number | null): Promise<StudentAttendanceSummaryDto> {
    const targetYear = year ?? 3;
    const targetSemester = semester ?? 1;

    // Get courses for student's year/semester
    const coursesRes = await query<{ id: string; code: string; title: string }>(
      `SELECT id, code, title FROM courses WHERE year = $1 AND semester = $2 AND is_active = true ORDER BY code ASC`,
      [targetYear, targetSemester]
    );

    const courseSummaries: CourseAttendanceSummaryDto[] = [];
    let totalAttendedAll = 0;
    let totalSessionsAll = 0;

    for (const course of coursesRes.rows) {
      // Total sessions held for this course
      const sessionCountRes = await query<{ count: string }>(
        `SELECT COUNT(*) as count FROM attendance_sessions WHERE course_id = $1`,
        [course.id]
      );
      const totalClasses = parseInt(sessionCountRes.rows[0].count, 10);

      // Total attended by student for this course
      const attendedRes = await query<{ count: string }>(
        `SELECT COUNT(*) as count 
         FROM attendance_records ar
         JOIN attendance_sessions s ON s.id = ar.session_id
         WHERE s.course_id = $1 AND ar.student_id = $2 AND ar.status = 'PRESENT'`,
        [course.id, studentId]
      );
      const attendedClasses = parseInt(attendedRes.rows[0].count, 10);

      const percentage = totalClasses > 0 ? Number(((attendedClasses / totalClasses) * 100).toFixed(1)) : 100.0;
      const isEligible = percentage >= 75.0;

      courseSummaries.push({
        courseId: course.id,
        courseCode: course.code,
        courseTitle: course.title,
        attendedClasses,
        totalClasses,
        percentage,
        isEligible,
      });

      totalAttendedAll += attendedClasses;
      totalSessionsAll += totalClasses;
    }

    const overallPercentage = totalSessionsAll > 0
      ? Number(((totalAttendedAll / totalSessionsAll) * 100).toFixed(1))
      : 100.0;

    // Recent attendance records
    const recentRes = await query<{
      id: string;
      course_code: string;
      course_title: string;
      status: string;
      verified_at: Date;
    }>(
      `SELECT 
        ar.id,
        c.code AS course_code,
        c.title AS course_title,
        ar.status,
        ar.verified_at
       FROM attendance_records ar
       JOIN attendance_sessions s ON s.id = ar.session_id
       JOIN courses c ON c.id = s.course_id
       WHERE ar.student_id = $1
       ORDER BY ar.verified_at DESC
       LIMIT 15`,
      [studentId]
    );

    const recentRecords: AttendanceRecordDto[] = recentRes.rows.map((r) => ({
      id: r.id,
      courseCode: r.course_code,
      courseTitle: r.course_title,
      status: r.status,
      verifiedAt: r.verified_at.toISOString(),
    }));

    return {
      overallPercentage,
      totalAttended: totalAttendedAll,
      totalSessions: totalSessionsAll,
      courseSummaries,
      recentRecords,
    };
  }

  async verifyCode(studentId: string, code: string, courseId?: string): Promise<{ success: boolean; courseTitle: string; verifiedAt: string }> {
    let sql = `
      SELECT s.id, s.course_id, c.title as course_title, s.status, s.expires_at 
      FROM attendance_sessions s
      JOIN courses c ON c.id = s.course_id
      WHERE s.code = $1 AND s.status = 'ACTIVE' AND (s.expires_at IS NULL OR s.expires_at > NOW())
    `;
    const params: any[] = [code.toUpperCase().trim()];

    if (courseId) {
      params.push(courseId);
      sql += ` AND s.course_id = $2`;
    }

    const sessionRes = await query<{
      id: string;
      course_id: string;
      course_title: string;
      status: string;
      expires_at: Date | null;
    }>(sql, params);

    if (sessionRes.rows.length === 0) {
      throw new BadRequestError('Invalid or expired attendance verification code.');
    }

    const session = sessionRes.rows[0];

    // Check if student already marked present
    const existingRes = await query(
      `SELECT id FROM attendance_records WHERE session_id = $1 AND student_id = $2`,
      [session.id, studentId]
    );

    if (existingRes.rows.length > 0) {
      throw new ConflictError('Attendance already submitted for this session.');
    }

    const insertRes = await query<{ verified_at: Date }>(
      `INSERT INTO attendance_records (session_id, student_id, status, verified_at)
       VALUES ($1, $2, 'PRESENT', NOW())
       RETURNING verified_at`,
      [session.id, studentId]
    );

    return {
      success: true,
      courseTitle: session.course_title,
      verifiedAt: insertRes.rows[0].verified_at.toISOString(),
    };
  }
}

export const attendanceService = new AttendanceService();
