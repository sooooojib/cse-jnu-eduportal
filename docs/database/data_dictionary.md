# Database Data Dictionary

This document serves as the exhaustive data dictionary for all tables, columns, data types, nullabilities, default values, foreign keys, and validation rules in the **CSE JnU EduPortal** database.

---

## 1. Table: `users`
Central user identity and authentication record.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique user account identifier. |
| `email` | `VARCHAR(255)` | NO | None | `UNIQUE` | User email address. |
| `password_hash` | `VARCHAR(255)` | NO | None | None | Argon2id / bcrypt salted hash. |
| `full_name` | `VARCHAR(100)` | NO | None | None | Full institutional name. |
| `role` | `VARCHAR(20)` | NO | None | `CHECK (role IN ('STUDENT', 'CR', 'TEACHER', 'ADMIN'))` | Primary system role. |
| `student_id` | `VARCHAR(30)` | YES | `NULL` | `UNIQUE` | Department student ID (for `STUDENT` and `CR`). |
| `phone` | `VARCHAR(20)` | YES | `NULL` | None | Contact number (primarily for `TEACHER`). |
| `avatar_url` | `VARCHAR(512)` | YES | `NULL` | None | Profile picture asset URL. |
| `year` | `INT` | YES | `NULL` | `CHECK (year >= 1 AND year <= 4)` | Active undergraduate year. |
| `semester` | `INT` | YES | `NULL` | `CHECK (semester >= 1 AND semester <= 2)` | Active undergraduate semester. |
| `requested_year` | `INT` | YES | `NULL` | None | Pending semester upgrade target year. |
| `requested_semester`| `INT` | YES | `NULL` | None | Pending semester upgrade target term. |
| `semester_status` | `VARCHAR(20)` | NO | `'NONE'` | `CHECK (semester_status IN ('NONE', 'PENDING', 'APPROVED', 'REJECTED'))` | Semester state machine status. |
| `is_active` | `BOOLEAN` | NO | `TRUE` | None | Account active status. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Account creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Record update timestamp. |

---

## 2. Table: `signup_requests`
Public onboarding registration queue.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique request identifier. |
| `email` | `VARCHAR(255)` | NO | None | None | Applicant email address. |
| `full_name` | `VARCHAR(100)` | NO | None | None | Applicant full name. |
| `role` | `VARCHAR(20)` | NO | None | `CHECK (role IN ('STUDENT', 'CR', 'TEACHER'))` | Requested account role. |
| `student_id` | `VARCHAR(30)` | YES | `NULL` | None | Student ID (if student/CR). |
| `phone` | `VARCHAR(20)` | YES | `NULL` | None | Phone number (if teacher). |
| `status` | `VARCHAR(20)` | NO | `'PENDING'` | `CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))` | Moderation queue status. |
| `rejection_reason`| `TEXT` | YES | `NULL` | None | Reason note if rejected. |
| `reviewed_by_id` | `UUID` | YES | `NULL` | `FK -> users(id)` | Admin reviewer UUID. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Submission timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Moderation timestamp. |

---

## 3. Table: `semester_requests`
Student semester progression petitions.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique petition identifier. |
| `student_id` | `UUID` | NO | None | `FK -> users(id)` | Target student account UUID. |
| `current_year` | `INT` | NO | None | None | Student year at time of petition. |
| `current_semester`| `INT` | NO | None | None | Student semester at time of petition. |
| `requested_year` | `INT` | NO | None | `CHECK (requested_year >= 1 AND requested_year <= 4)` | Target advancement year. |
| `requested_semester`| `INT` | NO | None | `CHECK (requested_semester >= 1 AND requested_semester <= 2)` | Target advancement term. |
| `status` | `VARCHAR(20)` | NO | `'PENDING'` | `CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))` | Petition status. |
| `rejection_reason`| `TEXT` | YES | `NULL` | None | Administrative rejection explanation. |
| `reviewed_by_id` | `UUID` | YES | `NULL` | `FK -> users(id)` | Admin reviewer UUID. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Petition submission timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Review timestamp. |

---

## 4. Table: `courses`
Departmental course curriculum catalog.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique course identifier. |
| `code` | `VARCHAR(20)` | NO | None | `UNIQUE` | Course code (e.g. `CSE-3101`). |
| `title` | `VARCHAR(150)` | NO | None | None | Course title. |
| `credit` | `DECIMAL(3,2)` | NO | None | `CHECK (credit > 0.0 AND credit <= 6.0)` | Academic credit weight. |
| `year` | `INT` | NO | None | `CHECK (year >= 1 AND year <= 4)` | Curriculum year. |
| `semester` | `INT` | NO | None | `CHECK (semester >= 1 AND semester <= 2)` | Curriculum term. |
| `course_type` | `VARCHAR(20)` | NO | `'THEORY'` | `CHECK (course_type IN ('THEORY', 'LAB', 'PROJECT', 'THESIS'))` | Course classification. |
| `description` | `TEXT` | YES | `NULL` | None | Course syllabus / description. |
| `is_active` | `BOOLEAN` | NO | `TRUE` | None | Course offering status. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Modification timestamp. |

---

## 5. Table: `course_teachers`
Junction table mapping faculty members to assigned courses.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Junction record ID. |
| `course_id` | `UUID` | NO | None | `FK -> courses(id) ON DELETE CASCADE` | Assigned course UUID. |
| `teacher_id` | `UUID` | NO | None | `FK -> users(id) ON DELETE CASCADE` | Assigned faculty UUID. |
| `is_coordinator`| `BOOLEAN`| NO | `FALSE`| None | Course coordinator flag. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Assignment timestamp. |

---

## 6. Table: `schedule_slots`
Weekly class routine slots and room allocations.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique routine slot ID. |
| `course_id` | `UUID` | NO | None | `FK -> courses(id) ON DELETE RESTRICT` | Course UUID. |
| `teacher_id` | `UUID` | NO | None | `FK -> users(id) ON DELETE RESTRICT` | Instructor faculty UUID. |
| `day_of_week` | `VARCHAR(15)` | NO | None | `CHECK (day_of_week IN ('SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY'))` | Day of week. |
| `start_time` | `TIME` | NO | None | None | Slot start time (e.g. `09:00:00`). |
| `end_time` | `TIME` | NO | None | None | Slot end time (e.g. `10:30:00`). |
| `room` | `VARCHAR(50)` | NO | None | None | Classroom / Lab identifier. |
| `target_year` | `INT` | NO | None | `CHECK (target_year >= 1 AND target_year <= 4)` | Target batch year. |
| `target_semester`| `INT` | NO | None | `CHECK (target_semester >= 1 AND target_semester <= 2)` | Target batch semester. |
| `created_by_id` | `UUID` | NO | None | `FK -> users(id)` | Author (CR or Admin). |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Last modified timestamp. |

---

## 7. Table: `exams`
Departmental examination schedules.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique exam identifier. |
| `course_id` | `UUID` | NO | None | `FK -> courses(id) ON DELETE RESTRICT` | Course UUID. |
| `title` | `VARCHAR(150)` | NO | None | None | Exam title (e.g. Midterm). |
| `exam_date` | `DATE` | NO | None | None | Scheduled exam date. |
| `start_time` | `TIME` | NO | None | None | Exam start time. |
| `end_time` | `TIME` | NO | None | None | Exam end time. |
| `room` | `VARCHAR(50)` | NO | None | None | Examination hall / room. |
| `year` | `INT` | NO | None | None | Academic year. |
| `semester` | `INT` | NO | None | None | Academic term. |
| `created_by_id` | `UUID` | NO | None | `FK -> users(id)` | Teacher or Admin author. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Modification timestamp. |

---

## 8. Table: `attendance_sessions`
Live dynamic code verification sessions.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique session ID. |
| `course_id` | `UUID` | NO | None | `FK -> courses(id) ON DELETE RESTRICT` | Course UUID. |
| `teacher_id` | `UUID` | NO | None | `FK -> users(id) ON DELETE RESTRICT` | Faculty host UUID. |
| `schedule_slot_id`| `UUID`| YES | `NULL` | `FK -> schedule_slots(id) ON DELETE SET NULL` | Optional routine slot link. |
| `code` | `VARCHAR(6)` | NO | None | `CHECK (LENGTH(code) = 6)` | 6-char alphanumeric code. |
| `status` | `VARCHAR(20)` | NO | `'ACTIVE'` | `CHECK (status IN ('ACTIVE', 'EXPIRED', 'CLOSED'))` | Verification session state. |
| `expires_at` | `TIMESTAMPTZ` | YES | `NULL` | None | Session expiration timestamp. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Session launch timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Status change timestamp. |

---

## 9. Table: `attendance_records`
Individual student verification entries.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique record ID. |
| `session_id` | `UUID` | NO | None | `FK -> attendance_sessions(id) ON DELETE CASCADE` | Parent session UUID. |
| `student_id` | `UUID` | NO | None | `FK -> users(id) ON DELETE RESTRICT` | Student account UUID. |
| `status` | `VARCHAR(20)` | NO | `'PRESENT'` | `CHECK (status IN ('PRESENT', 'ABSENT', 'EXCUSED'))` | Verification status. |
| `verified_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Verification timestamp. |
| `is_manual_override`| `BOOLEAN`| NO | `FALSE` | None | Manual teacher toggle flag. |
| `override_by_id` | `UUID` | YES | `NULL` | `FK -> users(id)` | Teacher who performed override. |
| `notes` | `VARCHAR(255)` | YES | `NULL` | None | Optional excuse/override note. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Insertion timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Update timestamp. |

---

## 10. Table: `counseling_slots`
Faculty office hour availability blocks.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique slot ID. |
| `teacher_id` | `UUID` | NO | None | `FK -> users(id) ON DELETE CASCADE` | Faculty UUID. |
| `slot_date` | `DATE` | NO | None | None | Availability date. |
| `start_time` | `TIME` | NO | None | None | Slot start time. |
| `end_time` | `TIME` | NO | None | None | Slot end time. |
| `status` | `VARCHAR(20)` | NO | `'AVAILABLE'` | `CHECK (status IN ('AVAILABLE', 'BOOKED', 'COMPLETED', 'CANCELLED'))` | Slot booking status. |
| `booked_student_id`| `UUID` | YES | `NULL` | `FK -> users(id) ON DELETE SET NULL` | Approved student UUID. |
| `notes` | `VARCHAR(255)` | YES | `NULL` | None | Office room / location note. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Status change timestamp. |

---

## 11. Table: `counseling_requests`
Student appointment petitions for counseling slots.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique request ID. |
| `slot_id` | `UUID` | NO | None | `FK -> counseling_slots(id) ON DELETE CASCADE` | Parent slot UUID. |
| `student_id` | `UUID` | NO | None | `FK -> users(id) ON DELETE CASCADE` | Applicant student UUID. |
| `category` | `VARCHAR(30)` | NO | None | `CHECK (category IN ('ACADEMIC_ADVISING', 'RESEARCH_DISCUSSION', 'MENTAL_PRESSURE', 'CLASS_ISSUE', 'CAREER_GUIDANCE', 'OTHER'))` | Reason category. |
| `notes` | `TEXT` | NO | None | None | Discussion context notes. |
| `status` | `VARCHAR(20)` | NO | `'PENDING'` | `CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED'))` | Petition status. |
| `reviewed_at` | `TIMESTAMPTZ` | YES | `NULL` | None | Teacher review timestamp. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Submission timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Update timestamp. |

---

## 12. Table: `feedbacks`
Confidential course and lecture ratings and reviews.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique feedback ID. |
| `teacher_id` | `UUID` | NO | None | `FK -> users(id) ON DELETE RESTRICT` | Target faculty UUID. |
| `student_id` | `UUID` | YES | `NULL` | `FK -> users(id) ON DELETE SET NULL` | Author student UUID. |
| `course_id` | `UUID` | YES | `NULL` | `FK -> courses(id) ON DELETE SET NULL` | Related course UUID. |
| `rating` | `INT` | NO | None | `CHECK (rating >= 1 AND rating <= 5)` | 1-to-5 star rating. |
| `comments` | `TEXT` | NO | None | None | Written feedback comments. |
| `is_anonymous` | `BOOLEAN` | NO | `FALSE` | None | Anonymity protection flag. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Submission timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Update timestamp. |

---

## 13. Table: `feedback_replies`
Official faculty responses to student feedback.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique reply ID. |
| `feedback_id` | `UUID` | NO | None | `FK -> feedbacks(id) ON DELETE CASCADE` | Parent feedback UUID. |
| `teacher_id` | `UUID` | NO | None | `FK -> users(id) ON DELETE RESTRICT` | Author faculty UUID. |
| `reply_text` | `TEXT` | NO | None | None | Written response text. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Reply creation timestamp. |
| `updated_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Reply update timestamp. |

---

## 14. Table: `attachments`
Multi-format file attachments for feedback, replies, and counseling.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique attachment ID. |
| `parent_type` | `VARCHAR(30)` | NO | None | `CHECK (parent_type IN ('FEEDBACK', 'FEEDBACK_REPLY', 'COUNSELING'))` | Polymorphic parent type. |
| `parent_id` | `UUID` | NO | None | None | Parent entity UUID. |
| `file_url` | `VARCHAR(512)` | NO | None | None | Accessible storage URL. |
| `file_name` | `VARCHAR(255)` | NO | None | None | Original uploaded filename. |
| `file_size_bytes`| `INT` | NO | None | `CHECK (file_size_bytes > 0 AND file_size_bytes <= 10485760)` | File size in bytes (max 10MB). |
| `mime_type` | `VARCHAR(100)` | NO | None | None | File MIME classification. |
| `uploaded_by_id`| `UUID` | NO | None | `FK -> users(id)` | Uploader user UUID. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Upload timestamp. |

---

## 15. Table: `notifications`
Real-time mobile push and in-app event notifications.

| Column Name | Data Type | Nullable | Default | Constraints / Keys | Description |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `id` | `UUID` | NO | `gen_random_uuid()` | `PRIMARY KEY` | Unique notification ID. |
| `user_id` | `UUID` | NO | None | `FK -> users(id) ON DELETE CASCADE` | Recipient user UUID. |
| `title` | `VARCHAR(150)` | NO | None | None | Short notification headline. |
| `body` | `TEXT` | NO | None | None | Notification description text. |
| `notification_type`| `VARCHAR(30)`| NO | None | None | Category (e.g. `COUNSELING`, `SEMESTER`, `ATTENDANCE`). |
| `reference_type`| `VARCHAR(30)`| YES | `NULL` | None | Related entity table name. |
| `reference_id` | `UUID` | YES | `NULL` | None | Related entity UUID. |
| `is_read` | `BOOLEAN` | NO | `FALSE` | None | Read / unread status flag. |
| `created_at` | `TIMESTAMPTZ` | NO | `NOW()` | None | Creation timestamp. |
