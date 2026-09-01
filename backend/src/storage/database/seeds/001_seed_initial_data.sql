-- Seed: 001_seed_initial_data.sql
-- Description: Seeds initial Administrator, Faculty, CR, Student, and core Courses

-- Passwords below are bcrypt hashed with 12 rounds for 'Admin@123456', 'Teacher@123456', 'Student@123456'
-- Admin: $2a$12$5WbY7N10W7EHzRjVfA2y5.253Zrqp1a4x6vKkFvI7rKkG3W1e0VGy

INSERT INTO users (id, email, password_hash, full_name, role, student_id, phone, is_active, created_at, updated_at)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'admin@cse.jnu.ac.bd',
  '$2b$10$DmBEbJA2Ea9I8f1ZCnL/meAkPQUxvtrZsIkQcGYlco41PlOBIzpNq',
  'Department Administrator',
  'ADMIN',
  NULL,
  '01700000000',
  TRUE,
  NOW(),
  NOW()
) ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash;

INSERT INTO users (id, email, password_hash, full_name, role, student_id, phone, is_active, created_at, updated_at)
VALUES (
  'a0000000-0000-0000-0000-000000000002',
  'teacher@cse.jnu.ac.bd',
  '$2b$10$2IV.lbUCNGxjD.ky5WVoYu8gsm4EfhvUBwdfZsN8g9zo9odPEBRDa',
  'Dr. Hasan Rahman',
  'TEACHER',
  NULL,
  '01711111111',
  TRUE,
  NOW(),
  NOW()
) ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash;

INSERT INTO users (id, email, password_hash, full_name, role, student_id, year, semester, is_active, created_at, updated_at)
VALUES (
  'a0000000-0000-0000-0000-000000000003',
  'cr@cse.jnu.ac.bd',
  '$2b$10$MXwVUzyImG/1xvd7aMvdSOdXRbuAg.8f2RPYPMxU7YTdcEhUnVKai',
  'Tanvir Ahmed (CR)',
  'CR',
  '2022CSE001',
  3,
  1,
  TRUE,
  NOW(),
  NOW()
) ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash;

INSERT INTO users (id, email, password_hash, full_name, role, student_id, year, semester, is_active, created_at, updated_at)
VALUES (
  'a0000000-0000-0000-0000-000000000004',
  'student@cse.jnu.ac.bd',
  '$2b$10$MXwVUzyImG/1xvd7aMvdSOdXRbuAg.8f2RPYPMxU7YTdcEhUnVKai',
  'Sajib Hossain',
  'STUDENT',
  '2022CSE015',
  3,
  1,
  TRUE,
  NOW(),
  NOW()
) ON CONFLICT (email) DO UPDATE SET password_hash = EXCLUDED.password_hash;

-- Seed Sample 3rd Year 1st Semester Courses
INSERT INTO courses (id, code, title, credit, year, semester, course_type, description, is_active, created_at, updated_at)
VALUES 
  ('c0000000-0000-0000-0000-000000000001', 'CSE-3101', 'Operating Systems', 3.0, 3, 1, 'THEORY', 'Core study of process management, virtualization, and concurrency.', TRUE, NOW(), NOW()),
  ('c0000000-0000-0000-0000-000000000002', 'CSE-3102', 'Operating Systems Lab', 1.5, 3, 1, 'LAB', 'Practical system programming and kernel simulation in C/C++.', TRUE, NOW(), NOW()),
  ('c0000000-0000-0000-0000-000000000003', 'CSE-3103', 'Software Engineering', 3.0, 3, 1, 'THEORY', 'Software development lifecycle, Clean Architecture, and Agile methodology.', TRUE, NOW(), NOW())
ON CONFLICT (code) DO NOTHING;

-- Assign Dr. Hasan Rahman to CSE-3101
INSERT INTO course_teachers (id, course_id, teacher_id, is_coordinator, created_at)
VALUES (
  'd0000000-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000002',
  TRUE,
  NOW()
) ON CONFLICT (course_id, teacher_id) DO NOTHING;
