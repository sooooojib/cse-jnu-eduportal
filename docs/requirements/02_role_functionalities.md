# Functional Requirements: Role-Specific Functionalities

This document details the dedicated functionality and user flows provided for **Students**, **Teachers**, **Class Representatives (CRs)**, and **Administrators**.

---

## 1. Student Functionality

### 1.1 Student Dashboard & Academic Summary
* **Who can use it**: `STUDENT`.
* **What the user can do**: View a unified academic dashboard containing:
  - Active semester banner (e.g. `3rd Year · 1st Semester`) with status indicator and change request action.
  - Metrics cards: Overall Average Attendance (%), Active Counseling Requests count, Submitted Feedback count, Upcoming Exams count.
  - Quick action to book counseling appointments.
  - Real-time Daily Class Schedule feed and Upcoming Exam reminders.
  - Enrolled courses list with individual course attendance progress bars.
* **Required Inputs**: Authenticated user session.
* **Expected Outputs**: Streaming / aggregated academic metrics and real-time feeds.
* **Validation Rules**: Data scoped strictly to the student's active `(year, semester)`.
* **Dependencies**: Semester state machine, Course catalog, Schedule engine, Attendance tracking.

### 1.2 Student Attendance Verification & History
* **Who can use it**: `STUDENT`.
* **What the user can do**: Select an active course, enter a 6-character dynamic attendance code, receive instant verification feedback, and view date-by-date attendance records.
* **Required Inputs**: `courseId`, `code` (6 alphanumeric characters).
* **Expected Outputs**: Confirmation of attendance marked `PRESENT`, updated course percentage.
* **Validation & Business Rules**: Code must be active for that course. Student can only submit once per session (`@@unique([sessionId, studentId])`).

### 1.3 Student Counseling Appointment Booking
* **Who can use it**: `STUDENT`.
* **What the user can do**: Browse available faculty office hour slots on an interactive calendar, select an open slot, select a reason category (`ACADEMIC_ADVISING`, `RESEARCH_DISCUSSION`, `MENTAL_PRESSURE`, `CLASS_ISSUE`, `CAREER_GUIDANCE`, `OTHER`), write discussion notes, and submit a booking request.
* **Required Inputs**: `slotId`, `category`, `notes` (min 5 characters).
* **Expected Outputs**: Slot status displays `PENDING` request; status updates to `APPROVED` or `REJECTED` when actioned by teacher.

### 1.4 Student Course Feedback Submission
* **Who can use it**: `STUDENT`.
* **What the user can do**: Rate a course professor (1 to 5 stars), write constructive feedback, optionally toggle "Submit Anonymously", attach screenshots or documents, and view faculty replies.
* **Required Inputs**: `teacherId`, `rating` (1–5), `comments` (min 10 chars), `isAnonymous` (boolean), optional `attachmentIds`.
* **Expected Outputs**: Stored feedback record, visible in student's history and teacher's inbox.

---

## 2. Teacher (Professor) Functionality

### 2.1 Teacher Dashboard & Course Routine
* **Who can use it**: `TEACHER`.
* **What the user can do**: View teaching overview metrics (Pending Counseling requests, Feedback count & average rating, Classes taught this semester), time-aware class routine, and assigned course catalog.
* **Time-Aware Behavior**:
  - **05:00 to 16:59**: Displays **Today's Classes** with quick-launch buttons for live attendance.
  - **17:00 to 04:59**: Displays **Tomorrow's Classes** to facilitate next-day preparation.
* **Required Inputs**: Authenticated teacher session.
* **Expected Outputs**: Tailored schedule, assigned course cards with credit/year/semester tags, pending request alerts.

### 2.2 Live Attendance Terminal & Roster Management
* **Who can use it**: `TEACHER`.
* **What the user can do**:
  - Launch a live 6-character code verification session for an assigned course.
  - Display dynamic code in high-contrast Obsidian Terminal with glowing green JetBrains Mono font.
  - Deactivate or regenerate the 6-character code.
  - View real-time student attendance roster as students enter codes.
  - Manually toggle any student's status between `PRESENT` and `ABSENT` (or "Mark All Present" / "Mark All Absent").
  - Export attendance logs to an Excel spreadsheet.
* **Required Inputs**: `courseId`, optional `scheduleSlotId`.
* **Expected Outputs**: Active session token, live stream / updates of marked students.

### 2.3 Counseling Slot Creation & Mutual-Exclusion Management
* **Who can use it**: `TEACHER`.
* **What the user can do**: Create office hour availability slots (date, start time, end time, location/notes), view student booking requests with categories and notes, approve a single student request (which automatically locks the slot and batch-rejects competing requests), or reject requests.
* **Required Inputs**:
  - For Slot Creation: `slotDate`, `startTime`, `endTime`, `notes`.
  - For Managing Requests: `requestId`, `action` (`APPROVE` | `REJECT`).
* **Expected Outputs**: Updated slot status (`AVAILABLE` ➔ `BOOKED`), updated request statuses.

### 2.4 Feedback Review & Threaded Replies
* **Who can use it**: `TEACHER`.
* **What the user can do**: Browse received student reviews filtered by "All", "Replied", and "Not Replied". For anonymous reviews, author identity is displayed strictly as `"Anonymous Student"`. Write official threaded replies to feedback.
* **Required Inputs**: `feedbackId`, `replyText` (string, min 2 chars), optional `attachmentIds`.
* **Expected Outputs**: Saved reply displayed under feedback card.

---

## 3. Class Representative (CR) Functionality

### 3.1 Dual-Role Hybrid Capabilities
* **Who can use it**: `CR`.
* **What the user can do**:
  - Inherits all core **Student** features (personal attendance, viewing courses, booking counseling, submitting feedback).
  - Possesses delegated administrative scheduling tools for their batch.

### 3.2 Tomorrow's Class Routine Management
* **Who can use it**: `CR`.
* **What the user can do**: Add or adjust class slots **strictly for the immediate next calendar day** (`startOfTomorrow()` to `endOfTomorrow()`).
* **Required Inputs**: `courseId`, `teacherId`, `dayOfWeek`, `startTime`, `endTime`, `room`.
* **Validation Rules**: Date selection is locked strictly to Tomorrow. Slots for the current batch `(year, semester)` only.
* **Expected Outputs**: Persisted `ScheduleSlot`, updated routine grid for all students in the batch.

### 3.3 Automated WhatsApp Routine Broadcaster
* **Who can use it**: `CR`.
* **What the user can do**: Tap "Broadcast on WhatsApp" on the dashboard or schedule hub to generate a formatted markdown schedule message for tomorrow and open the device WhatsApp application with pre-filled text.
* **Required Inputs**: Target date (tomorrow).
* **Expected Outputs**: Formatted message containing date, ordered class list, times, course titles, teacher names, and room allocations.

### 3.4 Class Attendance Summary & Excel Export
* **Who can use it**: `CR`.
* **What the user can do**: View batch-wide attendance summaries for enrolled courses and export multi-sheet Excel attendance reports.

---

## 4. Admin Functionality

### 4.1 Admin Control Center & Pending Queues
* **Who can use it**: `ADMIN`.
* **What the user can do**:
  - View and moderate **Pending Signup Requests** queue (approve with automated password generation or reject with reasons).
  - View and moderate **Pending Semester Upgrade Requests** queue (approve or reject student advancement petitions).
  - View system summary metrics (total users, active sessions, courses, pending queues).

### 4.2 Department User Directory Management
* **Who can use it**: `ADMIN`.
* **What the user can do**:
  - Browse complete departmental user directory filtered by role tabs (`Teachers`, `Students`, `CRs`, `Admins`).
  - Search users by name, email, student ID, or phone.
  - Create new user accounts directly with custom initial credentials.
  - Delete or deactivate user accounts.

### 4.3 Teacher Course Assignment Matrix
* **Who can use it**: `ADMIN`.
* **What the user can do**: Open course assignment modal for any faculty member, view courses grouped by Year & Semester, and assign/unassign courses via a checkbox matrix.
* **Required Inputs**: `teacherId`, `courseIds` (array of course UUIDs).
* **Expected Outputs**: Updated `CourseTeacher` mappings.

### 4.4 Departmental Feedback Audit
* **Who can use it**: `ADMIN`.
* **What the user can do**: Audit all feedback entries across all faculty members with full unmasked identity trails to ensure institutional compliance and safety.
