# Attendance & Live Verification Terminal API Specification

This document details the endpoints for **Dynamic Live Attendance Verification**, **Terminal Controls**, **Manual Roster Management**, and **Excel Data Export**.

---

## 1. `POST /api/v1/attendance-sessions/start`

### Overview
Initiates a dynamic 6-character code verification session for an assigned course.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/attendance-sessions/start`
* **Authentication**: Required (`Bearer <token>`)
* **Required Role**: `TEACHER`, `ADMIN`
* **Request Body**:
  ```json
  {
    "courseId": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
    "scheduleSlotId": "s1eebc99-9c0b-4ef8-bb6d-6bb9bd380a77"
  }
  ```
* **Validation Rules**:
  - `courseId`: Required UUID. Teacher must be assigned to this course.
  - Generates 6-char alphanumeric code excluding `0, O, 1, I`.
* **Success Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "data": {
      "sessionId": "a1eebc99-9c0b-4ef8-bb6d-6bb9bd380a88",
      "courseId": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
      "code": "K7X92M",
      "status": "ACTIVE",
      "expiresAt": "2026-08-28T13:30:00.000Z",
      "createdAt": "2026-08-28T12:00:00.000Z"
    },
    "message": "Live attendance terminal launched."
  }
  ```
* **Possible Errors**:
  - `403 Forbidden`: `FORBIDDEN_RESOURCE` ("You are not assigned as instructor for this course.")
  - `409 Conflict`: `SESSION_ALREADY_ACTIVE` ("An active attendance session is already open for this course. Close it first.")

---

## 2. `POST /api/v1/attendance-sessions/:id/deactivate`

### Overview
Closes the active verification session, locking further student code submissions.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/attendance-sessions/:id/deactivate`
* **Authentication**: Required
* **Required Role**: `TEACHER`, `ADMIN`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "sessionId": "a1eebc99-9c0b-4ef8-bb6d-6bb9bd380a88",
      "status": "CLOSED"
    },
    "message": "Attendance session closed successfully."
  }
  ```

---

## 3. `POST /api/v1/attendance-sessions/:id/regenerate-code`

### Overview
Invalidates the existing 6-character code and issues a new code for the active session.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/attendance-sessions/:id/regenerate-code`
* **Authentication**: Required
* **Required Role**: `TEACHER`, `ADMIN`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "sessionId": "a1eebc99-9c0b-4ef8-bb6d-6bb9bd380a88",
      "code": "P4W89Y",
      "status": "ACTIVE"
    },
    "message": "New verification code generated."
  }
  ```

---

## 4. `GET /api/v1/attendance-sessions/:id/roster`

### Overview
Retrieves the live attendance roster for an active or completed session.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/attendance-sessions/:id/roster`
* **Authentication**: Required
* **Required Role**: `TEACHER`, `ADMIN`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "sessionId": "a1eebc99-9c0b-4ef8-bb6d-6bb9bd380a88",
      "totalEnrolled": 45,
      "presentCount": 42,
      "absentCount": 3,
      "roster": [
        {
          "studentId": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
          "registrationNumber": "2020CSE001",
          "fullName": "Sajib Ahmed",
          "status": "PRESENT",
          "verifiedAt": "2026-08-28T12:02:14.000Z",
          "isManualOverride": false
        },
        {
          "studentId": "a2eebc99-9c0b-4ef8-bb6d-6bb9bd380a12",
          "registrationNumber": "2020CSE002",
          "fullName": "Sadia Islam",
          "status": "ABSENT",
          "verifiedAt": null,
          "isManualOverride": false
        }
      ]
    },
    "message": "Session roster retrieved."
  }
  ```

---

## 5. `PATCH /api/v1/attendance-sessions/:id/roster/:studentId`

### Overview
Allows faculty to manually override a student's verification status.

* **HTTP Method**: `PATCH`
* **Endpoint**: `/api/v1/attendance-sessions/:id/roster/:studentId`
* **Authentication**: Required
* **Required Role**: `TEACHER`, `ADMIN`
* **Request Body**:
  ```json
  {
    "status": "PRESENT",
    "notes": "Late arrival excused"
  }
  ```
* **Validation Rules**: `status` must be `'PRESENT'`, `'ABSENT'`, or `'EXCUSED'`.
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Student attendance status updated." }`

---

## 6. `POST /api/v1/attendance-sessions/:id/bulk-toggle`

### Overview
Executes bulk roster status updates (e.g., "Mark All Present" or "Mark All Absent").

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/attendance-sessions/:id/bulk-toggle`
* **Authentication**: Required
* **Required Role**: `TEACHER`, `ADMIN`
* **Request Body**: `{ "targetStatus": "PRESENT" }`
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Bulk status update applied." }`

---

## 7. `POST /api/v1/attendance/verify`

### Overview
Endpoint where students submit the 6-character dynamic code announced by their professor.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/attendance/verify`
* **Authentication**: Required (`Bearer <token>`)
* **Required Role**: `STUDENT`, `CR`
* **Request Body**:
  ```json
  {
    "courseId": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
    "code": "K7X92M"
  }
  ```
* **Validation Rules**:
  - `code`: Exactly 6 alphanumeric characters (case-insensitive, parsed uppercase).
  - `courseId`: UUID matching an enrolled course in the student's active batch.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "recordId": "r1eebc99-9c0b-4ef8-bb6d-6bb9bd380a99",
      "courseCode": "CSE-3101",
      "status": "PRESENT",
      "verifiedAt": "2026-08-28T12:02:14.000Z"
    },
    "message": "Attendance marked successfully."
  }
  ```
* **Possible Errors**:
  - `400 Bad Request`: `INVALID_VERIFICATION_CODE` ("Invalid or expired attendance verification code.")
  - `409 Conflict`: `DUPLICATE_ATTENDANCE` ("You have already recorded attendance for this session.")

---

## 8. `GET /api/v1/attendance/my-summary`

### Overview
Retrieves the student's overall and course-by-course attendance analytics and date logs.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/attendance/my-summary`
* **Authentication**: Required
* **Required Role**: `STUDENT`, `CR`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "overallAttendancePercentage": 88.5,
      "courses": [
        {
          "courseId": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
          "code": "CSE-3101",
          "title": "Operating Systems",
          "attendancePercentage": 92.0,
          "totalHeld": 12,
          "presentCount": 11,
          "absentCount": 1,
          "history": [
            { "date": "2026-08-28", "status": "PRESENT" },
            { "date": "2026-08-26", "status": "PRESENT" },
            { "date": "2026-08-24", "status": "ABSENT" }
          ]
        }
      ]
    },
    "message": "Attendance summary retrieved."
  }
  ```

---

## 9. `GET /api/v1/attendance/courses/:courseId/export`

### Overview
Generates and downloads a multi-sheet Excel (.xlsx) departmental attendance sheet.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/attendance/courses/:courseId/export`
* **Authentication**: Required
* **Required Role**: `TEACHER`, `CR`, `ADMIN`
* **Response Headers**:
  - `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
  - `Content-Disposition: attachment; filename="CSE3101_Attendance_Report.xlsx"`
* **Success Response (`200 OK`)**: Binary `.xlsx` file stream.
