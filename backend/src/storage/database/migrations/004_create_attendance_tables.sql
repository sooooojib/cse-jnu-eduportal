-- Migration: 004_create_attendance_tables.sql
-- Description: Creates attendance_sessions and attendance_records tables

CREATE TABLE IF NOT EXISTS attendance_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  schedule_slot_id UUID REFERENCES schedule_slots(id) ON DELETE SET NULL ON UPDATE CASCADE,
  code VARCHAR(6) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_att_code_len CHECK (LENGTH(code) = 6),
  CONSTRAINT chk_att_status CHECK (status IN ('ACTIVE', 'EXPIRED', 'CLOSED'))
);

CREATE TABLE IF NOT EXISTS attendance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE ON UPDATE CASCADE,
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  status VARCHAR(20) NOT NULL DEFAULT 'PRESENT',
  verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_manual_override BOOLEAN NOT NULL DEFAULT FALSE,
  override_by_id UUID REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  notes VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_record_status CHECK (status IN ('PRESENT', 'ABSENT', 'EXCUSED')),
  CONSTRAINT uq_attendance_session_student UNIQUE (session_id, student_id)
);
