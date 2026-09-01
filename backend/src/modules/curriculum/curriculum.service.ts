import { query } from '../../config/database';

export interface CourseDto {
  id: string;
  code: string;
  title: string;
  credit: number;
  year: number;
  semester: number;
  courseType: string;
  description: string | null;
  teacherName?: string | null;
  teacherId?: string | null;
}

export interface ScheduleSlotDto {
  id: string;
  courseId: string;
  courseCode: string;
  courseTitle: string;
  teacherId: string;
  teacherName: string;
  dayOfWeek: string;
  startTime: string;
  endTime: string;
  room: string;
  targetYear: number;
  targetSemester: number;
}

export interface ExamDto {
  id: string;
  courseId: string;
  courseCode: string;
  courseTitle: string;
  title: string;
  examDate: string;
  startTime: string;
  endTime: string;
  room: string;
  year: number;
  semester: number;
}

export class CurriculumService {
  async getMyCourses(year?: number | null, semester?: number | null): Promise<CourseDto[]> {
    const targetYear = year ?? 3;
    const targetSemester = semester ?? 1;

    const sql = `
      SELECT 
        c.id,
        c.code,
        c.title,
        c.credit,
        c.year,
        c.semester,
        c.course_type AS "courseType",
        c.description,
        u.id AS "teacherId",
        u.full_name AS "teacherName"
      FROM courses c
      LEFT JOIN course_teachers ct ON ct.course_id = c.id
      LEFT JOIN users u ON u.id = ct.teacher_id
      WHERE c.year = $1 AND c.semester = $2 AND c.is_active = true
      ORDER BY c.code ASC;
    `;

    const result = await query<CourseDto>(sql, [targetYear, targetSemester]);
    return result.rows;
  }

  async getSchedule(year?: number | null, semester?: number | null, day?: string): Promise<ScheduleSlotDto[]> {
    const targetYear = year ?? 3;
    const targetSemester = semester ?? 1;

    let sql = `
      SELECT 
        s.id,
        s.course_id AS "courseId",
        c.code AS "courseCode",
        c.title AS "courseTitle",
        s.teacher_id AS "teacherId",
        u.full_name AS "teacherName",
        s.day_of_week AS "dayOfWeek",
        s.start_time AS "startTime",
        s.end_time AS "endTime",
        s.room,
        s.target_year AS "targetYear",
        s.target_semester AS "targetSemester"
      FROM schedule_slots s
      JOIN courses c ON c.id = s.course_id
      JOIN users u ON u.id = s.teacher_id
      WHERE s.target_year = $1 AND s.target_semester = $2
    `;

    const params: any[] = [targetYear, targetSemester];

    if (day) {
      params.push(day);
      sql += ` AND s.day_of_week = $${params.length}`;
    }

    sql += ` ORDER BY CASE s.day_of_week 
      WHEN 'SUNDAY' THEN 1 
      WHEN 'MONDAY' THEN 2 
      WHEN 'TUESDAY' THEN 3 
      WHEN 'WEDNESDAY' THEN 4 
      WHEN 'THURSDAY' THEN 5 
      ELSE 6 END, s.start_time ASC;`;

    const result = await query<ScheduleSlotDto>(sql, params);
    return result.rows;
  }

  async getExams(year?: number | null, semester?: number | null): Promise<ExamDto[]> {
    const targetYear = year ?? 3;
    const targetSemester = semester ?? 1;

    const sql = `
      SELECT 
        e.id,
        e.course_id AS "courseId",
        c.code AS "courseCode",
        c.title AS "courseTitle",
        e.title,
        e.exam_date::TEXT AS "examDate",
        e.start_time AS "startTime",
        e.end_time AS "endTime",
        e.room,
        e.year,
        e.semester
      FROM exams e
      JOIN courses c ON c.id = e.course_id
      WHERE e.year = $1 AND e.semester = $2
      ORDER BY e.exam_date ASC, e.start_time ASC;
    `;

    const result = await query<ExamDto>(sql, [targetYear, targetSemester]);
    return result.rows;
  }
}

export const curriculumService = new CurriculumService();
