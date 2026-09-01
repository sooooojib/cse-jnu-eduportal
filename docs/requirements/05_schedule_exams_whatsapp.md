# Functional Requirements: Schedules, Exams & WhatsApp Broadcasting

This document details the functional specifications for **Schedule & Routine Management**, **Departmental Exam Tracking**, and **Automated WhatsApp Broadcasting**.

---

## 1. Feature: Academic Timetable & Daily Routine

### Overview
A time-aware departmental routine matrix organizing class slots across Sunday through Thursday for all 4 academic years.

### Feature Specification
* **Who can use it**:
  - `STUDENT`, `CR`: View timetable for their active Year and Semester.
  - `TEACHER`: View personal teaching timetable across all assigned courses and years.
  - `ADMIN`: View and manage timetables across all years.
* **Timetable Structure**:
  - Days: Sunday, Monday, Tuesday, Wednesday, Thursday (Friday/Saturday are university weekends).
  - Time Slots: Standard 90-minute blocks (e.g. 09:00–10:30, 10:45–12:15, 01:30–03:00, 03:15–04:45).
  - Slot Attributes: Course Code, Course Title, Teacher Name, Room Identifier (e.g. `Room 402`, `Lab 2`, `Science Complex 302`).
* **Time-Aware Display Logic**:
  - Student / CR views highlight the next upcoming class of the day.
  - Teacher views automatically toggle between **Today's Classes** (05:00–16:59) and **Tomorrow's Classes** (17:00–04:59).

---

## 2. Feature: Class Representative (CR) Tomorrow-Only Scheduling

### Overview
Delegated scheduling tool allowing Class Representatives to allocate or adjust class slots for their batch for the next day.

### Feature Specification
* **Who can use it**: `CR`, `ADMIN`.
* **What the user can do**:
  1. Open the CR Schedule Manager interface.
  2. Select course from the batch's enrolled courses.
  3. Select assigned faculty member.
  4. Select start time, end time, and classroom.
  5. Save routine slot.
* **Required Inputs**:
  - `courseId`: UUID of target course.
  - `teacherId`: UUID of instructor.
  - `dayOfWeek`: Day corresponding to tomorrow.
  - `startTime`: Time string (`HH:MM`).
  - `endTime`: Time string (`HH:MM`).
  - `room`: Classroom/Lab string (e.g. `Room 402`).
* **Validation Rules**:
  - **Tomorrow-Only Lock**: CRs can **only** submit or modify slots whose target date is the immediate next day (`startOfTomorrow()` to `endOfTomorrow()`). Date picker input is locked.
  - `startTime` must precede `endTime`.
  - No overlapping room bookings for the same time slot in the department.
* **Authorization Requirements**: Protected by `CR` and `ADMIN` RBAC guards.
* **Important Business Rules**:
  - **Stale Slot Sanitization Engine**: When schedule is retrieved or mounted, slots with dates in the past are archived; invalid future slots beyond tomorrow created accidentally are automatically sanitized.
* **Edge Cases**:
  - Scheduling on Thursday for Sunday: System maps "Tomorrow" for weekend transitions (Thursday creates Sunday slot if weekend skips).
* **Dependencies**: Course Catalog, User Repository, Schedule Service.

---

## 3. Feature: Automated WhatsApp Routine Broadcaster

### Overview
A single-tap routine formatting and sharing engine enabling CRs to broadcast structured daily timetables directly to official class WhatsApp groups.

### Feature Specification
* **Who can use it**: `CR`.
* **What the user can do**: Tap "Broadcast on WhatsApp" on the dashboard or schedule hub to generate a structured markdown schedule message for tomorrow and open the device WhatsApp application with pre-filled text.
* **Required Inputs**: Target schedule date (Tomorrow).
* **Output Format**:
  ```markdown
  📚 *CSE Department Class Routine for Tomorrow*
  📅 Date: DD/MM/YYYY
  🏛️ Year: 3rd Year · Semester: 1st Semester

  1️⃣ *CSE-3101: Operating Systems*
  ⏰ Time: 09:00 AM - 10:30 AM
  👨‍🏫 Teacher: Prof. Dr. Rahman
  📍 Room: Room 402

  2️⃣ *CSE-3103: Database Systems Lab*
  ⏰ Time: 11:30 AM - 01:00 PM
  👩‍🏫 Teacher: Dr. Farhana
  📍 Room: Lab 3

  _Sent via CSE JnU EduPortal_
  ```
* **Execution Flow**:
  1. Flutter app queries tomorrow's schedule slots for the CR's batch.
  2. Compiles formatted URI-encoded string.
  3. Launches native WhatsApp intent (`whatsapp://send?text=...`) with web URL fallback (`https://api.whatsapp.com/send?text=...`).
* **Validation Rules**: If tomorrow has no scheduled classes, prompts the CR with: *"No classes scheduled for tomorrow. Do you want to broadcast a 'No Class' notice?"*

---

## 4. Feature: Departmental Examination Management

### Overview
Tracking of Midterm Assessments, Lab Assessments, and Term Final Examinations.

### Feature Specification
* **Who can use it**:
  - `TEACHER`, `ADMIN`: Create and publish exam routines.
  - `STUDENT`, `CR`: View exam routines and countdowns.
* **Required Inputs (Creation)**:
  - `courseId`: UUID of course.
  - `title`: Exam title (e.g. `Midterm Assessment`, `Term Final`).
  - `examDate`: Calendar date of exam.
  - `startTime` & `endTime`: Time window.
  - `room`: Exam hall / lab (e.g. `Room 301`, `Science Complex Hall`).
* **Expected Outputs**: Chronological list of upcoming and completed exams displayed on Student, CR, and Teacher dashboards.
* **Validation Rules**: `examDate` must be a valid future date.
* **Authorization Requirements**: Creation restricted to `TEACHER` and `ADMIN`.
