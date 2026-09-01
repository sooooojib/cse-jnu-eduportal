# Functional Requirements: Attendance & Live Verification Terminal

This document details the functional specifications for **Attendance Tracking**, the **Live Verification Terminal**, and **Dynamic Code Verification**.

---

## 1. Feature: Live Attendance Verification Terminal (Faculty Side)

### Overview
A real-time, high-contrast dynamic verification interface (rendered in an Obsidian Terminal aesthetic) launched by professors during class to verify student presence.

### Feature Specification
* **Who can use it**: `TEACHER`, `ADMIN`.
* **What the user can do**:
  1. Select an assigned course from a dropdown.
  2. Launch an attendance session that generates a **6-character alphanumeric verification code**.
  3. Display the 6-character code in prominent monospace font (`JetBrains Mono`, 7xl glowing green) for in-class projection or mobile viewing.
  4. View a live updating student roster table showing who has submitted the code in real time.
  5. Deactivate the active code to prevent late entries.
  6. Regenerate a new code if the existing code is compromised.
  7. Manually toggle individual student statuses (`PRESENT` / `ABSENT` / `EXCUSED`).
  8. Use bulk actions ("Mark All Present", "Mark All Absent").
  9. Export attendance records to a formatted Excel report.
* **Required Inputs**:
  - `courseId`: Target Course UUID.
  - `scheduleSlotId`: Optional associated schedule slot UUID.
* **Expected Outputs**:
  - Created `AttendanceSession` record with a unique 6-character uppercase code.
  - Real-time stream / polling roster list containing student names, IDs, verification timestamps, and statuses.
* **Validation Rules**:
  - Teacher must be assigned to the selected course (or have `ADMIN` role).
  - Code generation algorithm must produce 6 uppercase alphanumeric characters excluding easily confused characters:
    $$\text{Charset} = \{A..Z, 0..9\} \setminus \{0, O, 1, I\}$$
* **Authorization Requirements**: Protected by `TEACHER` and `ADMIN` RBAC guards.
* **Important Business Rules**:
  - Only one active attendance session can exist per course at any given timestamp.
  - Manual overrides by the teacher set `isManualOverride = true` for auditability.
* **Edge Cases**:
  - Teacher leaves the screen or loses internet connection: The session remains active on the backend until explicitly deactivated or timed out.
  - Teacher regenerates code while students are typing: Old code becomes invalid immediately; new code is displayed.
* **Ambiguities**:
  - **AMBIGUOUS — REQUIRES DECISION**: Default session auto-expiration timeout (e.g., automatically expire after 15 minutes or remain open until manual closure).

---

## 2. Feature: Dynamic Attendance Code Entry (Student Side)

### Overview
A mobile-optimized OTP-style code entry interface where students enter the 6-character code announced or projected by their teacher.

### Feature Specification
* **Who can use it**: `STUDENT`, `CR`.
* **What the user can do**:
  1. Select the relevant course from enrolled semester courses.
  2. Enter the 6-character code into an OTP-style 6-box input field.
  3. Receive immediate visual confirmation (success checkmark or vibration feedback).
  4. View refreshed course attendance percentage and date log.
* **Required Inputs**:
  - `courseId`: UUID of the course.
  - `code`: 6-character string.
* **Expected Outputs**:
  - `200 OK` on success with message: *"Attendance marked successfully."*
  - Persisted `AttendanceRecord` linking `sessionId`, `studentId`, status `PRESENT`, and server timestamp.
* **Validation Rules**:
  - Code must match the active `AttendanceSession.code` for the specified `courseId`.
  - Student must be currently enrolled in the course's `(year, semester)`.
  - Session must be in status `ACTIVE` and not expired.
* **Authorization Requirements**: Authenticated `STUDENT` or `CR`.
* **Important Business Rules**:
  - **Idempotency & Uniqueness**: A student can record attendance for a session **at most once**:
    $$\text{UniqueConstraint}(\text{sessionId}, \text{studentId})$$
  - Submitting duplicate code returns `409 Conflict` ("Attendance already recorded for this session.").
  - Submitting invalid code returns `400 Bad Request` ("Invalid or expired verification code.").
* **Edge Cases**:
  - Student enters code right at the millisecond of deactivation: Handled gracefully via atomic backend verification.
  - Case sensitivity: Input automatically converts to uppercase on client and backend.
* **Dependencies**: User Session, Course Enrollment, Attendance Session Engine.

---

## 3. Feature: Attendance Metrics & Historical Analytics

### Overview
Calculated statistics showing course attendance compliance and date-by-date verification history.

### Feature Specification
* **Who can use it**: `STUDENT`, `CR` (for own stats), `TEACHER`, `ADMIN` (for class stats).
* **Formula & Calculations**:
  $$\text{Course Attendance \%} = \left(\frac{\text{Count of PRESENT / EXCUSED sessions}}{\text{Total completed sessions for course}}\right) \times 100$$
* **Expected Outputs**:
  - Percentage value (e.g. `88.5%`).
  - Color-coded indicator (Green: >= 75%, Amber: 60–74%, Red: < 60% — meeting standard university eligibility thresholds).
  - Date-by-date historical log with attendance status badges.
