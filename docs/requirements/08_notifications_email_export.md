# Functional Requirements: Notifications, Email & Data Export

This document details the functional specifications for **In-App & Push Notifications**, **Automated Email Dispatch**, and **Departmental Data Export**.

---

## 1. Feature: In-App & Push Notification System

### Overview
Real-time event notification pipeline keeping students and faculty informed of critical academic updates, counseling confirmations, schedule modifications, and attendance notices.

### Feature Specification
* **Who can use it**: All Authenticated Roles (`STUDENT`, `CR`, `TEACHER`, `ADMIN`).
* **Trigger Events & Target Audiences**:
  1. **Counseling Request Actioned**:
     - *Trigger*: Teacher approves or rejects a counseling appointment.
     - *Recipient*: Applicant Student.
     - *Payload*: Slot date, time, instructor name, approval/rejection status.
  2. **Semester Upgrade Petition Actioned**:
     - *Trigger*: Admin approves or rejects semester upgrade.
     - *Recipient*: Applicant Student / CR.
     - *Payload*: New semester assignment or rejection reason.
  3. **Feedback Response Posted**:
     - *Trigger*: Teacher replies to feedback.
     - *Recipient*: Author Student (delivered silently without exposing author identity).
  4. **Emergency Routine Change**:
     - *Trigger*: CR or Admin adds/adjusts a class slot for tomorrow.
     - *Recipient*: All enrolled batch students.
  5. **Attendance Session Started**:
     - *Trigger*: Teacher launches dynamic code terminal.
     - *Recipient*: Students enrolled in the active course.
* **Notification Channels**:
  - In-App Notification Center (badge counter + chronological feed).
  - Native Mobile Push Notifications (FCM / APNs).
* **Expected Outputs**: Timely alerts displayed in system status bar and in-app bell drawer.

---

## 2. Feature: Automated Email Dispatch Service

### Overview
Asynchronous transactional email pipeline for account provisioning, security alerts, and credential delivery.

### Feature Specification
* **Who can use it**: Backend System Workers.
* **Core Email Workflows**:

#### 2.1 Onboarding Credential Email (Welcome Dispatch)
- **Trigger**: Administrator approves a `SignupRequest`.
- **Recipient**: Approved user's email address.
- **Template Content**:
  - Department Header: Department of Computer Science & Engineering, Jagannath University.
  - Welcome greeting with user name.
  - Assigned Portal Role (`Student`, `Teacher`, `Class Representative`).
  - Temporary Auto-Generated Password (in bold monospace).
  - Link to Mobile App Download / Sign In Portal.
  - Security advice recommending immediate password change on first login.

#### 2.2 Rejection Notification Email
- **Trigger**: Administrator rejects a `SignupRequest` or `SemesterRequest`.
- **Recipient**: Applicant's email.
- **Template Content**: Formal departmental notice with recorded explanation.

### Technical & Business Constraints:
- Email generation runs in background worker/queue to ensure non-blocking API response times.
- Templating engine generates responsive, accessible HTML with plain-text fallback.
- Retries with exponential backoff on SMTP failure.

---

## 3. Feature: Departmental Excel & Data Export

### Overview
Automated generation and download of formatted multi-sheet Excel (.xlsx) attendance ledgers and academic summaries.

### Feature Specification
* **Who can use it**: `TEACHER`, `CR`, `ADMIN`.
* **What the user can do**: Export comprehensive course attendance sheets containing individual dates, session timestamps, student registration IDs, student names, individual session statuses, and calculated total percentage statistics.
* **Spreadsheet Structure & Layout**:
  - **Header Block**:
    - Department of Computer Science & Engineering, Jagannath University
    - Course Code & Title (e.g., `CSE-3101: Operating Systems`)
    - Academic Year & Semester (e.g., `3rd Year · 1st Semester`)
    - Instructor Name(s) & Generation Date
  - **Data Matrix**:
    - Columns: `Student ID`, `Student Name`, `Session 1 (Date)`, `Session 2 (Date)`, ..., `Total Present`, `Total Absent`, `Attendance %`, `Eligibility Status (Eligible / Non-Collegiate / Discollegiate)`.
  - **Summary Block**: Total enrolled students, average class attendance percentage.
* **Output Format**: Native binary `.xlsx` stream.
* **Execution Flow**:
  1. Client sends `GET /api/v1/attendance/course/:courseId/export`.
  2. Backend aggregates all sessions and records for the course.
  3. Builds formatted workbook with styling and formulas.
  4. Returns `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`.
* **Authorization Requirements**:
  - `TEACHER`: Can export courses they teach.
  - `CR`: Can export courses in their active batch.
  - `ADMIN`: Can export any course across the department.
