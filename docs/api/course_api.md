# Courses & Semester Progression API Specification

This document details the endpoints for **Course Curriculum Catalogs**, **Student Course Enrollments**, and the **Semester Lifecycle State Machine**.

---

## 1. `GET /api/v1/courses`

### Overview
Retrieves the departmental curriculum catalog, filterable by year, semester, and course type.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/courses`
* **Authentication**: Required (`Bearer <token>`)
* **Required Role**: All Authenticated Roles
* **Query Parameters**:
  - `year`: Academic year (`1`, `2`, `3`, `4`).
  - `semester`: Academic term (`1`, `2`).
  - `type`: Course type (`THEORY`, `LAB`, `PROJECT`, `THESIS`).
  - `search`: Search code or title.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
        "code": "CSE-3101",
        "title": "Operating Systems",
        "credit": 3.0,
        "year": 3,
        "semester": 1,
        "courseType": "THEORY",
        "description": "Processes, threads, CPU scheduling, memory management, and file systems.",
        "assignedTeachers": [
          {
            "id": "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
            "fullName": "Prof. Dr. Rahman",
            "isCoordinator": true
          }
        ]
      }
    ],
    "message": "Curriculum courses retrieved."
  }
  ```

---

## 2. `GET /api/v1/courses/my-enrolled`

### Overview
Fetches the active courses enrolled by the authenticated student based on their current Year & Semester, enriched with live attendance percentage metrics.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/courses/my-enrolled`
* **Authentication**: Required
* **Required Role**: `STUDENT`, `CR`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "courseId": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
        "code": "CSE-3101",
        "title": "Operating Systems",
        "credit": 3.0,
        "courseType": "THEORY",
        "attendancePercentage": 92.5,
        "totalSessions": 12,
        "presentCount": 11,
        "instructors": ["Prof. Dr. Rahman"]
      },
      {
        "courseId": "c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a34",
        "code": "CSE-3103",
        "title": "Database Systems",
        "credit": 3.0,
        "courseType": "THEORY",
        "attendancePercentage": 85.0,
        "totalSessions": 10,
        "presentCount": 8,
        "instructors": ["Dr. Farhana"]
      }
    ],
    "message": "Enrolled courses retrieved."
  }
  ```

---

## 3. `GET /api/v1/courses/my-assigned`

### Overview
Fetches courses assigned to the authenticated professor.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/courses/my-assigned`
* **Authentication**: Required
* **Required Role**: `TEACHER`
* **Success Response (`200 OK`)**: Returns array of assigned courses with target batch year/semester metadata.

---

## 4. `POST /api/v1/semesters/upgrade-request`

### Overview
Submits a student petition to advance to the next academic semester.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/semesters/upgrade-request`
* **Authentication**: Required
* **Required Role**: `STUDENT`, `CR`
* **Request Body**:
  ```json
  {
    "requestedYear": 3,
    "requestedSemester": 2
  }
  ```
* **Validation Rules**:
  - `requestedYear`: 1 to 4.
  - `requestedSemester`: 1 to 2.
  - Cannot be equal to student's current active year/semester.
* **Success Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "data": {
      "requestId": "f1eebc99-9c0b-4ef8-bb6d-6bb9bd380a66",
      "requestedYear": 3,
      "requestedSemester": 2,
      "status": "PENDING"
    },
    "message": "Semester upgrade request submitted for admin review."
  }
  ```
* **Possible Errors**:
  - `409 Conflict`: `PENDING_SEMESTER_EXISTS` ("You already have a pending semester change request in review.")
  - `422 Unprocessable Entity`: `VALIDATION_FAILED` ("Invalid year or semester requested.")

---

## 5. `GET /api/v1/semesters/upgrade-status`

### Overview
Checks the status of the authenticated student's semester progression request.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/semesters/upgrade-status`
* **Authentication**: Required
* **Required Role**: `STUDENT`, `CR`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "hasPendingRequest": true,
      "currentYear": 3,
      "currentSemester": 1,
      "requestedYear": 3,
      "requestedSemester": 2,
      "status": "PENDING",
      "rejectionReason": null,
      "submittedAt": "2026-08-27T14:00:00.000Z"
    },
    "message": "Semester status retrieved."
  }
  ```
