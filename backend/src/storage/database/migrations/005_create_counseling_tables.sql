-- Migration: 005_create_counseling_tables.sql
-- Description: Creates counseling_slots and counseling_requests tables

CREATE TABLE IF NOT EXISTS counseling_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  slot_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
  booked_student_id UUID REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  notes VARCHAR(255),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_counsel_status CHECK (status IN ('AVAILABLE', 'BOOKED', 'COMPLETED', 'CANCELLED'))
);

CREATE TABLE IF NOT EXISTS counseling_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id UUID NOT NULL REFERENCES counseling_slots(id) ON DELETE CASCADE ON UPDATE CASCADE,
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  category VARCHAR(30) NOT NULL,
  notes TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_counsel_cat CHECK (category IN ('ACADEMIC_ADVISING', 'RESEARCH_DISCUSSION', 'MENTAL_PRESSURE', 'CLASS_ISSUE', 'CAREER_GUIDANCE', 'OTHER')),
  CONSTRAINT chk_counsel_req_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
  CONSTRAINT uq_counseling_slot_student UNIQUE (slot_id, student_id)
);
