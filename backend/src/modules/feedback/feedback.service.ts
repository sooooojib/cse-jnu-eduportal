import { query } from '../../config/database';
import { NotFoundError } from '../../common/errors';

export interface FeedbackReplyDto {
  id: string;
  teacherName: string;
  replyText: string;
  createdAt: string;
}

export interface FeedbackSubmissionDto {
  id: string;
  teacherId: string;
  teacherName: string;
  courseId: string | null;
  courseCode: string | null;
  courseTitle: string | null;
  rating: number;
  comments: string;
  isAnonymous: boolean;
  replies: FeedbackReplyDto[];
  createdAt: string;
}

export class FeedbackService {
  async submitFeedback(
    studentId: string,
    teacherId: string,
    courseId: string | null | undefined,
    rating: number,
    comments: string,
    isAnonymous: boolean
  ): Promise<FeedbackSubmissionDto> {
    // Verify teacher exists
    const teacherRes = await query<{ id: string; full_name: string }>(
      `SELECT id, full_name FROM users WHERE id = $1 AND role = 'TEACHER'`,
      [teacherId]
    );

    if (teacherRes.rows.length === 0) {
      throw new NotFoundError('Teacher not found.');
    }

    const insertRes = await query<{ id: string }>(
      `INSERT INTO feedbacks (teacher_id, student_id, course_id, rating, comments, is_anonymous)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id`,
      [teacherId, studentId, courseId || null, rating, comments, isAnonymous]
    );

    const feedbackId = insertRes.rows[0].id;

    // Create a notification for the teacher
    await query(
      `INSERT INTO notifications (user_id, title, body, notification_type, reference_type, reference_id)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        teacherId,
        'New Student Feedback Received',
        isAnonymous
          ? `An anonymous student submitted a ${rating}-star review.`
          : `A student submitted a ${rating}-star review.`,
        'FEEDBACK_RECEIVED',
        'FEEDBACK',
        feedbackId,
      ]
    );

    const feedback = await this.getFeedbackById(feedbackId);
    return feedback!;
  }

  async getMySubmissions(studentId: string): Promise<FeedbackSubmissionDto[]> {
    const sql = `
      SELECT 
        f.id,
        f.teacher_id AS "teacherId",
        u.full_name AS "teacherName",
        f.course_id AS "courseId",
        c.code AS "courseCode",
        c.title AS "courseTitle",
        f.rating,
        f.comments,
        f.is_anonymous AS "isAnonymous",
        f.created_at AS "createdAt"
      FROM feedbacks f
      JOIN users u ON u.id = f.teacher_id
      LEFT JOIN courses c ON c.id = f.course_id
      WHERE f.student_id = $1
      ORDER BY f.created_at DESC;
    `;

    const result = await query<Omit<FeedbackSubmissionDto, 'replies'>>(sql, [studentId]);
    const submissions: FeedbackSubmissionDto[] = [];

    for (const row of result.rows) {
      const repliesRes = await query<{
        id: string;
        teacher_name: string;
        reply_text: string;
        created_at: Date;
      }>(
        `SELECT 
          fr.id,
          u.full_name AS teacher_name,
          fr.reply_text,
          fr.created_at
         FROM feedback_replies fr
         JOIN users u ON u.id = fr.teacher_id
         WHERE fr.feedback_id = $1
         ORDER BY fr.created_at ASC`,
        [row.id]
      );

      submissions.push({
        ...row,
        replies: repliesRes.rows.map((r) => ({
          id: r.id,
          teacherName: r.teacher_name,
          replyText: r.reply_text,
          createdAt: r.created_at.toISOString(),
        })),
      });
    }

    return submissions;
  }

  private async getFeedbackById(feedbackId: string): Promise<FeedbackSubmissionDto | null> {
    const sql = `
      SELECT 
        f.id,
        f.teacher_id AS "teacherId",
        u.full_name AS "teacherName",
        f.course_id AS "courseId",
        c.code AS "courseCode",
        c.title AS "courseTitle",
        f.rating,
        f.comments,
        f.is_anonymous AS "isAnonymous",
        f.created_at AS "createdAt"
      FROM feedbacks f
      JOIN users u ON u.id = f.teacher_id
      LEFT JOIN courses c ON c.id = f.course_id
      WHERE f.id = $1;
    `;
    const res = await query<Omit<FeedbackSubmissionDto, 'replies'>>(sql, [feedbackId]);
    if (res.rows.length === 0) return null;

    return {
      ...res.rows[0],
      replies: [],
    };
  }
}

export const feedbackService = new FeedbackService();
