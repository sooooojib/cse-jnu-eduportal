# Database Constraints, Race Condition Prevention & Indexing Strategy

This document details the database-level constraints, atomic concurrency safeguards, race condition preventions, and indexing strategies for **CSE JnU EduPortal**.

---

## 1. Concurrency Safeguards & Race Condition Elimination

### 1.1 In-Class Attendance Verification Spikes
* **Race Condition**: 50–100 students in a lecture hall enter the 6-character dynamic code simultaneously within a 10-second window.
* **Integrity Threats**: Duplicate attendance records for the same student, lock contention on database rows.
* **Database-Level Safeguards**:
  1. **Strict Compound Unique Constraint**:
     ```sql
     ALTER TABLE attendance_records 
     ADD CONSTRAINT uq_attendance_session_student 
     UNIQUE (session_id, student_id);
     ```
  2. **Atomic Verification Query**:
     The insert operation executes with conflict protection:
     ```sql
     INSERT INTO attendance_records (session_id, student_id, status, verified_at)
     VALUES ($sessionId, $studentId, 'PRESENT', NOW())
     ON CONFLICT (session_id, student_id) DO NOTHING;
     ```
  3. If no row is inserted (conflict hit), backend returns `409 Conflict` ("Attendance already recorded").

---

### 1.2 Counseling Slot Double-Booking (Mutual-Exclusion Engine)
* **Race Condition**: Multiple students submit booking requests for the same open slot; professor attempts to approve one candidate while another student is submitting a request or the slot is being modified.
* **Integrity Threats**: Two students approved for the same office hour slot.
* **Database-Level Safeguards**:
  1. **Unique Student Request Constraint**:
     ```sql
     ALTER TABLE counseling_requests 
     ADD CONSTRAINT uq_counseling_slot_student 
     UNIQUE (slot_id, student_id);
     ```
  2. **Row-Level Locking on Approval Transaction**:
     ```sql
     BEGIN;
     -- Lock the slot row against concurrent approvals
     SELECT id, status FROM counseling_slots 
     WHERE id = $slotId AND status = 'AVAILABLE' 
     FOR UPDATE;

     -- Step 1: Mark slot as BOOKED
     UPDATE counseling_slots 
     SET status = 'BOOKED', booked_student_id = $studentId, updated_at = NOW() 
     WHERE id = $slotId;

     -- Step 2: Approve the winning request
     UPDATE counseling_requests 
     SET status = 'APPROVED', reviewed_at = NOW(), updated_at = NOW() 
     WHERE id = $requestId;

     -- Step 3: Atomic Batch-Rejection of all competing pending requests
     UPDATE counseling_requests 
     SET status = 'REJECTED', reviewed_at = NOW(), updated_at = NOW() 
     WHERE slot_id = $slotId AND id != $requestId AND status = 'PENDING';

     COMMIT;
     ```

---

### 1.3 Conflicting Schedule Allocations (Classroom, Teacher & Batch Collisions)
* **Race Condition**: Two CRs or admins concurrently book the same classroom or same professor for overlapping time slots.
* **Integrity Threats**: Two classes scheduled in Room 402 at 09:00 AM on Monday, or Dr. Rahman scheduled for two different courses at the same hour.
* **Database-Level Safeguards**:
  1. **Exclusion Constraint / Overlap Verification**:
     ```sql
     -- Room exclusivity per day and time
     CREATE UNIQUE INDEX uq_schedule_room_time 
     ON schedule_slots (room, day_of_week, start_time, end_time);

     -- Teacher exclusivity per day and time
     CREATE UNIQUE INDEX uq_schedule_teacher_time 
     ON schedule_slots (teacher_id, day_of_week, start_time, end_time);

     -- Student Batch exclusivity per day and time
     CREATE UNIQUE INDEX uq_schedule_batch_time 
     ON schedule_slots (target_year, target_semester, day_of_week, start_time, end_time);
     ```

---

### 1.4 Dynamic Attendance Code Exclusivity
* **Race Condition**: A teacher opens multiple active attendance sessions for the same course simultaneously.
* **Database-Level Safeguard**:
  ```sql
  -- Guarantees at most ONE ACTIVE attendance session per course
  CREATE UNIQUE INDEX uq_active_attendance_session_per_course 
  ON attendance_sessions (course_id) 
  WHERE status = 'ACTIVE';
  ```

---

### 1.5 Duplicate Pending Signup Requests
* **Race Condition**: A student double-clicks or re-submits registration before the first is reviewed.
* **Database-Level Safeguards**:
  ```sql
  CREATE UNIQUE INDEX uq_pending_signup_email 
  ON signup_requests (email) 
  WHERE status = 'PENDING';

  CREATE UNIQUE INDEX uq_pending_signup_student_id 
  ON signup_requests (student_id) 
  WHERE status = 'PENDING' AND student_id IS NOT NULL;
  ```

---

### 1.6 Duplicate Pending Semester Upgrade Petitions
* **Race Condition**: A student spams semester advancement petitions while one is already pending.
* **Database-Level Safeguard**:
  ```sql
  CREATE UNIQUE INDEX uq_pending_semester_request_per_student 
  ON semester_requests (student_id) 
  WHERE status = 'PENDING';
  ```

---

## 2. Check Constraints (`CHECK`)

| Table Name | Constraint Name | SQL Check Condition | Purpose |
| :--- | :--- | :--- | :--- |
| `users` | `chk_user_role` | `role IN ('STUDENT', 'CR', 'TEACHER', 'ADMIN')` | Enforces valid role enum. |
| `users` | `chk_user_year` | `year IS NULL OR (year >= 1 AND year <= 4)` | Restricts academic year to 1–4. |
| `users` | `chk_user_semester`| `semester IS NULL OR (semester >= 1 AND semester <= 2)` | Restricts academic semester to 1–2. |
| `users` | `chk_user_sem_status`| `semester_status IN ('NONE', 'PENDING', 'APPROVED', 'REJECTED')` | Enforces semester state machine. |
| `signup_requests`| `chk_signup_role` | `role IN ('STUDENT', 'CR', 'TEACHER')` | Excludes ADMIN from public signups. |
| `signup_requests`| `chk_signup_status`| `status IN ('PENDING', 'APPROVED', 'REJECTED')` | Enforces tri-state review. |
| `courses` | `chk_course_credit`| `credit > 0.0 AND credit <= 6.0` | Valid university credit range. |
| `courses` | `chk_course_year` | `year >= 1 AND year <= 4` | Valid academic year. |
| `courses` | `chk_course_sem` | `semester >= 1 AND semester <= 2` | Valid academic semester. |
| `courses` | `chk_course_type` | `course_type IN ('THEORY', 'LAB', 'PROJECT', 'THESIS')` | Enforces course types. |
| `schedule_slots` | `chk_slot_day` | `day_of_week IN ('SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY')` | Enforces university class days. |
| `schedule_slots` | `chk_slot_times` | `start_time < end_time` | Guarantees valid time interval. |
| `attendance_sessions`| `chk_att_code_len` | `LENGTH(code) = 6` | Strict 6-character code length. |
| `attendance_sessions`| `chk_att_status` | `status IN ('ACTIVE', 'EXPIRED', 'CLOSED')` | Enforces session lifecycle. |
| `attendance_records` | `chk_record_status`| `status IN ('PRESENT', 'ABSENT', 'EXCUSED')` | Enforces verification status. |
| `counseling_slots` | `chk_counsel_status`| `status IN ('AVAILABLE', 'BOOKED', 'COMPLETED', 'CANCELLED')` | Enforces office hour slot lifecycle. |
| `counseling_requests`| `chk_counsel_cat`| `category IN ('ACADEMIC_ADVISING', 'RESEARCH_DISCUSSION', 'MENTAL_PRESSURE', 'CLASS_ISSUE', 'CAREER_GUIDANCE', 'OTHER')` | Enforces standardized categories. |
| `counseling_requests`| `chk_counsel_status`| `status IN ('PENDING', 'APPROVED', 'REJECTED')` | Enforces petition status. |
| `feedbacks` | `chk_feedback_rating`| `rating >= 1 AND rating <= 5` | Enforces 1–5 star integer rating. |
| `attachments` | `chk_attachment_size`| `file_size_bytes > 0 AND file_size_bytes <= 10485760` | Maximum 10MB file size limit. |

---

## 3. High-Performance Indexing Strategy

```sql
-- Identity & Users Lookups
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_student_id ON users(student_id) WHERE student_id IS NOT NULL;
CREATE INDEX idx_users_batch ON users(year, semester) WHERE year IS NOT NULL AND semester IS NOT NULL;

-- Course Queries
CREATE INDEX idx_courses_batch ON courses(year, semester);
CREATE INDEX idx_course_teachers_lookup ON course_teachers(course_id, teacher_id);
CREATE INDEX idx_course_teachers_teacher ON course_teachers(teacher_id);

-- Schedule Timetables
CREATE INDEX idx_schedule_batch ON schedule_slots(target_year, target_semester, day_of_week);
CREATE INDEX idx_schedule_teacher ON schedule_slots(teacher_id, day_of_week);
CREATE INDEX idx_exams_batch ON exams(year, semester, exam_date);

-- Attendance High-Speed Lookups
CREATE INDEX idx_attendance_sessions_course ON attendance_sessions(course_id, status);
CREATE INDEX idx_attendance_sessions_code ON attendance_sessions(code) WHERE status = 'ACTIVE';
CREATE INDEX idx_attendance_records_session ON attendance_records(session_id);
CREATE INDEX idx_attendance_records_student ON attendance_records(student_id);

-- Counseling Calendars
CREATE INDEX idx_counseling_slots_teacher_date ON counseling_slots(teacher_id, slot_date);
CREATE INDEX idx_counseling_slots_status ON counseling_slots(status, slot_date);
CREATE INDEX idx_counseling_requests_slot ON counseling_requests(slot_id, status);
CREATE INDEX idx_counseling_requests_student ON counseling_requests(student_id);

-- Feedback Queries
CREATE INDEX idx_feedbacks_teacher ON feedbacks(teacher_id, created_at DESC);
CREATE INDEX idx_feedbacks_student ON feedbacks(student_id);
CREATE INDEX idx_feedback_replies_feedback ON feedback_replies(feedback_id);

-- Notifications
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read, created_at DESC);
```
