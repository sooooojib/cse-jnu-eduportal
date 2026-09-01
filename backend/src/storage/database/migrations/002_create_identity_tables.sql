-- Migration: 002_create_identity_tables.sql
-- Description: Creates users, signup_requests, and semester_requests tables

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(100) NOT NULL,
  role VARCHAR(20) NOT NULL,
  student_id VARCHAR(30) UNIQUE,
  phone VARCHAR(20),
  avatar_url VARCHAR(512),
  year INT,
  semester INT,
  requested_year INT,
  requested_semester INT,
  semester_status VARCHAR(20) NOT NULL DEFAULT 'NONE',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_user_role CHECK (role IN ('STUDENT', 'CR', 'TEACHER', 'ADMIN')),
  CONSTRAINT chk_user_year CHECK (year IS NULL OR (year >= 1 AND year <= 4)),
  CONSTRAINT chk_user_semester CHECK (semester IS NULL OR (semester >= 1 AND semester <= 2)),
  CONSTRAINT chk_user_sem_status CHECK (semester_status IN ('NONE', 'PENDING', 'APPROVED', 'REJECTED'))
);

CREATE TABLE IF NOT EXISTS signup_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL,
  full_name VARCHAR(100) NOT NULL,
  role VARCHAR(20) NOT NULL,
  student_id VARCHAR(30),
  phone VARCHAR(20),
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  rejection_reason TEXT,
  reviewed_by_id UUID REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_signup_role CHECK (role IN ('STUDENT', 'CR', 'TEACHER')),
  CONSTRAINT chk_signup_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))
);

CREATE TABLE IF NOT EXISTS semester_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
  current_year INT NOT NULL,
  current_semester INT NOT NULL,
  requested_year INT NOT NULL,
  requested_semester INT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  rejection_reason TEXT,
  reviewed_by_id UUID REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_semester_req_year CHECK (requested_year >= 1 AND requested_year <= 4),
  CONSTRAINT chk_semester_req_sem CHECK (requested_semester >= 1 AND requested_semester <= 2),
  CONSTRAINT chk_semester_req_status CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))
);
