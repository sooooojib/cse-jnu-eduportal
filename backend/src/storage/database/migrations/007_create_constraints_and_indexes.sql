-- Migration: 007_create_constraints_and_indexes.sql
-- Description: Creates partial unique indexes, race-condition constraints, and performance indexes

-- 1. Partial Unique Indexes & Concurrency Guards
CREATE UNIQUE INDEX IF NOT EXISTS uq_pending_signup_email 
  ON signup_requests (email) 
  WHERE status = 'PENDING';

CREATE UNIQUE INDEX IF NOT EXISTS uq_pending_signup_student_id 
  ON signup_requests (student_id) 
  WHERE status = 'PENDING' AND student_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_pending_semester_request_per_student 
  ON semester_requests (student_id) 
  WHERE status = 'PENDING';

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_attendance_session_per_course 
  ON attendance_sessions (course_id) 
  WHERE status = 'ACTIVE';

CREATE UNIQUE INDEX IF NOT EXISTS uq_schedule_room_time 
  ON schedule_slots (room, day_of_week, start_time, end_time);

CREATE UNIQUE INDEX IF NOT EXISTS uq_schedule_teacher_time 
  ON schedule_slots (teacher_id, day_of_week, start_time, end_time);

CREATE UNIQUE INDEX IF NOT EXISTS uq_schedule_batch_time 
  ON schedule_slots (target_year, target_semester, day_of_week, start_time, end_time);

-- 2. Performance Indexes: Identity & Users
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_student_id ON users(student_id) WHERE student_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_batch ON users(year, semester) WHERE year IS NOT NULL AND semester IS NOT NULL;

-- 3. Performance Indexes: Courses & Faculty
CREATE INDEX IF NOT EXISTS idx_courses_batch ON courses(year, semester);
CREATE INDEX IF NOT EXISTS idx_course_teachers_lookup ON course_teachers(course_id, teacher_id);
CREATE INDEX IF NOT EXISTS idx_course_teachers_teacher ON course_teachers(teacher_id);

-- 4. Performance Indexes: Timetables & Exams
CREATE INDEX IF NOT EXISTS idx_schedule_batch ON schedule_slots(target_year, target_semester, day_of_week);
CREATE INDEX IF NOT EXISTS idx_schedule_teacher ON schedule_slots(teacher_id, day_of_week);
CREATE INDEX IF NOT EXISTS idx_exams_batch ON exams(year, semester, exam_date);

-- 5. Performance Indexes: Attendance Verification
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_course ON attendance_sessions(course_id, status);
CREATE INDEX IF NOT EXISTS idx_attendance_sessions_code ON attendance_sessions(code) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_attendance_records_session ON attendance_records(session_id);
CREATE INDEX IF NOT EXISTS idx_attendance_records_student ON attendance_records(student_id);

-- 6. Performance Indexes: Counseling Calendar
CREATE INDEX IF NOT EXISTS idx_counseling_slots_teacher_date ON counseling_slots(teacher_id, slot_date);
CREATE INDEX IF NOT EXISTS idx_counseling_slots_status ON counseling_slots(status, slot_date);
CREATE INDEX IF NOT EXISTS idx_counseling_requests_slot ON counseling_requests(slot_id, status);
CREATE INDEX IF NOT EXISTS idx_counseling_requests_student ON counseling_requests(student_id);

-- 7. Performance Indexes: Feedback & Replies
CREATE INDEX IF NOT EXISTS idx_feedbacks_teacher ON feedbacks(teacher_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedbacks_student ON feedbacks(student_id);
CREATE INDEX IF NOT EXISTS idx_feedback_replies_feedback ON feedback_replies(feedback_id);

-- 8. Performance Indexes: Push Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read, created_at DESC);
