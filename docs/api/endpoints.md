# API Endpoint Catalog

This document lists all REST API endpoints for **CSE JnU EduPortal**, including required roles, request payloads, and response structures.

---

## 1. Authentication & Onboarding (`/api/v1/auth`)

### 1.1 `POST /auth/login`
- **Access**: Public
- **Body**:
  ```json
  {
    "email": "student@cse.jnu.ac.bd",
    "password": "SecurePassword123!"
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "data": {
      "accessToken": "eyJhbGci...",
      "refreshToken": "d8a1c9...",
      "user": {
        "id": "uuid-v4",
        "name": "Sajib Ahmed",
        "email": "student@cse.jnu.ac.bd",
        "role": "STUDENT",
        "studentId": "2020CSE001",
        "year": 3,
        "semester": 1
      }
    }
  }
  ```

### 1.2 `POST /auth/signup-request`
- **Access**: Public
- **Body**:
  ```json
  {
    "name": "Farhan Tanvir",
    "email": "farhan@cse.jnu.ac.bd",
    "role": "STUDENT",
    "studentId": "2022CSE015",
    "phone": null
  }
  ```
- **Response `201 Created`**:
  ```json
  {
    "success": true,
    "message": "Your registration request has been submitted for admin approval."
  }
  ```

### 1.3 `POST /auth/refresh`
- **Access**: Public
- **Body**: `{ "refreshToken": "d8a1c9..." }`
- **Response `200 OK`**: `{ "success": true, "data": { "accessToken": "eyJ..." } }`

### 1.4 `GET /auth/me`
- **Access**: Authenticated (`STUDENT`, `CR`, `TEACHER`, `ADMIN`)
- **Response `200 OK`**: Returns current authenticated user profile and permissions.

---

## 2. Semester Lifecycle Management (`/api/v1/semester`)

### 2.1 `POST /semester/request`
- **Access**: `STUDENT`, `CR`
- **Body**: `{ "requestedYear": 3, "requestedSemester": 2 }`
- **Response `201 Created`**: `{ "success": true, "message": "Semester upgrade request submitted." }`

### 2.2 `GET /semester/status`
- **Access**: `STUDENT`, `CR`
- **Response `200 OK`**: Current status (`NONE`, `PENDING`, `APPROVED`, `REJECTED`).

---

## 3. Class Routine & Schedule (`/api/v1/schedule`)

### 3.1 `GET /schedule`
- **Access**: All Roles
- **Query Params**: `?year=3&semester=1` (or derived automatically from role)
- **Response `200 OK`**: Returns weekly schedule matrix and time-aware daily classes.

### 3.2 `POST /schedule/slot`
- **Access**: `CR`, `ADMIN`
- **Body**:
  ```json
  {
    "courseId": "uuid-course",
    "teacherId": "uuid-teacher",
    "dayOfWeek": "MONDAY",
    "startTime": "09:00",
    "endTime": "10:30",
    "room": "Room 402",
    "targetYear": 3,
    "targetSemester": 1
  }
  ```
- **Response `201 Created`**

### 3.3 `GET /schedule/exams`
- **Access**: All Roles
- **Response `200 OK`**: List of upcoming and past exam schedules.

---

## 4. Attendance Terminal & Verification (`/api/v1/attendance`)

### 4.1 `POST /attendance/session/start`
- **Access**: `TEACHER`, `ADMIN`
- **Body**: `{ "courseId": "uuid-course", "scheduleSlotId": "uuid-slot" }`
- **Response `201 Created`**:
  ```json
  {
    "success": true,
    "data": {
      "sessionId": "uuid-session",
      "code": "K7X92M",
      "status": "ACTIVE",
      "expiresAt": "2026-08-28T13:00:00Z"
    }
  }
  ```

### 4.2 `POST /attendance/session/:id/deactivate`
- **Access**: `TEACHER`, `ADMIN`
- **Response `200 OK`**: Closes active verification session.

### 4.3 `POST /attendance/session/:id/regenerate`
- **Access**: `TEACHER`, `ADMIN`
- **Response `200 OK`**: Returns a new 6-character code.

### 4.4 `POST /attendance/verify`
- **Access**: `STUDENT`, `CR`
- **Body**: `{ "code": "K7X92M", "courseId": "uuid-course" }`
- **Response `200 OK`**: `{ "success": true, "message": "Attendance marked successfully." }`

### 4.5 `GET /attendance/session/:id/roster`
- **Access**: `TEACHER`, `ADMIN`
- **Response `200 OK`**: Complete student list with current statuses (`PRESENT` / `ABSENT`).

### 4.6 `PATCH /attendance/session/:id/roster/:studentId`
- **Access**: `TEACHER`, `ADMIN`
- **Body**: `{ "status": "PRESENT" }`
- **Response `200 OK`**

### 4.7 `GET /attendance/my-summary`
- **Access**: `STUDENT`, `CR`
- **Response `200 OK`**: Course-by-course attendance percentages and date logs.

### 4.8 `GET /attendance/course/:courseId/export`
- **Access**: `TEACHER`, `CR`, `ADMIN`
- **Response `200 OK`**: Binary Excel (.xlsx) departmental attendance sheet.

---

## 5. Faculty Counseling Office Hours (`/api/v1/counseling`)

### 5.1 `GET /counseling/slots`
- **Access**: All Roles
- **Query Params**: `?teacherId=uuid&month=2026-11`
- **Response `200 OK`**: List of slots with status (`AVAILABLE`, `BOOKED`, etc.).

### 5.2 `POST /counseling/slots`
- **Access**: `TEACHER`
- **Body**:
  ```json
  {
    "slotDate": "2026-11-18",
    "startTime": "10:00",
    "endTime": "11:00",
    "notes": "Office Room 410"
  }
  ```
- **Response `201 Created`**

### 5.3 `POST /counseling/slots/:id/request`
- **Access**: `STUDENT`, `CR`
- **Body**:
  ```json
  {
    "category": "ACADEMIC_ADVISING",
    "notes": "Discussion regarding final year thesis topic selection."
  }
  ```
- **Response `201 Created`**

### 5.4 `POST /counseling/requests/:requestId/manage`
- **Access**: `TEACHER`
- **Body**: `{ "status": "APPROVED" }` (or `"REJECTED"`)
- **Response `200 OK`**: Executes atomic mutual-exclusion lock.

---

## 6. Feedback & Reviews (`/api/v1/feedback`)

### 6.1 `POST /feedback`
- **Access**: `STUDENT`, `CR`
- **Body**:
  ```json
  {
    "teacherId": "uuid-teacher",
    "rating": 5,
    "comments": "Excellent lecture on query optimization.",
    "isAnonymous": true,
    "attachmentIds": ["uuid-file"]
  }
  ```
- **Response `201 Created`**

### 6.2 `GET /feedback/teacher/:teacherId`
- **Access**: `TEACHER` (sees own, anonymized if requested), `ADMIN` (sees all)
- **Response `200 OK`**: List of reviews and threaded replies.

### 6.3 `POST /feedback/:id/reply`
- **Access**: `TEACHER`
- **Body**: `{ "replyText": "Thank you! We will add more practical exercises." }`
- **Response `201 Created`**

---

## 7. Admin Control & Directory (`/api/v1/admin`)

### 7.1 `GET /admin/signup-requests`
- **Access**: `ADMIN`
- **Response `200 OK`**: List of pending onboarding registrations.

### 7.2 `POST /admin/signup-requests/:id/approve`
- **Access**: `ADMIN`
- **Response `200 OK`**: Provisions user, generates credentials, and sends email.

### 7.3 `POST /admin/signup-requests/:id/reject`
- **Access**: `ADMIN`
- **Body**: `{ "reason": "Invalid student ID." }`
- **Response `200 OK`**

### 7.4 `GET /admin/users`
- **Access**: `ADMIN`
- **Query Params**: `?role=TEACHER&search=Rahman`
- **Response `200 OK`**: Departmental user list.

### 7.5 `POST /admin/users/:teacherId/courses`
- **Access**: `ADMIN`
- **Body**: `{ "courseIds": ["uuid-course-1", "uuid-course-2"] }`
- **Response `200 OK`**
