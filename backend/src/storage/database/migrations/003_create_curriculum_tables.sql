-- Migration: 003_create_curriculum_tables.sql
-- Description: Creates courses, course_teachers, schedule_slots, and exams tables

CREATE TABLE IF NOT EXISTS courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(20) NOT NULL UNIQUE,
  title VARCHAR(150) NOT NULL,
  credit DECIMAL(3,2) NOT NULL,
  year INT NOT NULL,
  semester INT NOT NULL,
  course_type VARCHAR(20) NOT NULL DEFAULT 'THEORY',
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_course_credit CHECK (credit > 0.0 AND credit <= 6.0),
  CONSTRAINT chk_course_year CHECK (year >= 1 AND year <= 4),
  CONSTRAINT chk_course_sem CHECK (semester >= 1 AND semester <= 2),
  CONSTRAINT chk_course_type CHECK (course_type IN ('THEORY', 'LAB', 'PROJECT', 'THESIS'))
);

CREATE TABLE IF NOT EXISTS course_teachers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE ON UPDATE CASCADE,
  teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  is_coordinator BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_course_teacher UNIQUE (course_id, teacher_id)
);

CREATE TABLE IF NOT EXISTS schedule_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  day_of_week VARCHAR(15) NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  room VARCHAR(50) NOT NULL,
  target_year INT NOT NULL,
  target_semester INT NOT NULL,
  created_by_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_slot_day CHECK (day_of_week IN ('SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY')),
  CONSTRAINT chk_slot_times CHECK (start_time < end_time),
  CONSTRAINT chk_slot_year CHECK (target_year >= 1 AND target_year <= 4),
  CONSTRAINT chk_slot_sem CHECK (target_semester >= 1 AND target_semester <= 2)
);

CREATE TABLE IF NOT EXISTS exams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  title VARCHAR(150) NOT NULL,
  exam_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  room VARCHAR(50) NOT NULL,
  year INT NOT NULL,
  semester INT NOT NULL,
  created_by_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_exam_year CHECK (year >= 1 AND year <= 4),
  CONSTRAINT chk_exam_sem CHECK (semester >= 1 AND semester <= 2)
);
