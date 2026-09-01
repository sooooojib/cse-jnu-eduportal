# Examination Schedule API Specification

This document details the endpoints for **Departmental Examinations**, **Midterm Assessments**, and **Lab Assessments**.

---

## 1. `GET /api/v1/exams`

### Overview
Fetches upcoming and completed examinations for the authenticated user's batch or department curriculum.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/exams`
* **Authentication**: Required (`Bearer <token>`)
* **Required Role**: All Authenticated Roles
* **Query Parameters**:
  - `timeFilter`: `upcoming` (default) or `past` or `all`.
  - `year`: Filter by academic year.
  - `semester`: Filter by academic semester.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "x1eebc99-9c0b-4ef8-bb6d-6bb9bd380a01",
        "courseCode": "CSE-3101",
        "courseTitle": "Operating Systems",
        "title": "Midterm Examination",
        "examDate": "2026-11-15",
        "startTime": "10:00",
        "endTime": "12:00",
        "room": "Room 301",
        "daysRemaining": 78
      }
    ],
    "message": "Exams retrieved."
  }
  ```

---

## 2. `POST /api/v1/exams`

### Overview
Schedules a new departmental exam.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/exams`
* **Authentication**: Required
* **Required Role**: `TEACHER`, `ADMIN`
* **Request Body**:
  ```json
  {
    "courseId": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
    "title": "Final Lab Assessment",
    "examDate": "2026-12-02",
    "startTime": "09:30",
    "endTime": "12:30",
    "room": "Lab 3",
    "year": 3,
    "semester": 1
  }
  ```
* **Success Response (`201 Created`)**: `{ "success": true, "data": { "id": "x2eebc99..." }, "message": "Exam scheduled successfully." }`

---

## 3. `PATCH /api/v1/exams/:id`

### Overview
Updates room or timing for an existing exam.

* **HTTP Method**: `PATCH`
* **Endpoint**: `/api/v1/exams/:id`
* **Authentication**: Required
* **Required Role**: `TEACHER`, `ADMIN`
* **Request Body**:
  ```json
  {
    "room": "Science Complex Hall 2"
  }
  ```
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Exam schedule updated." }`

---

## 4. `DELETE /api/v1/exams/:id`

### Overview
Cancels an examination.

* **HTTP Method**: `DELETE`
* **Endpoint**: `/api/v1/exams/:id`
* **Authentication**: Required
* **Required Role**: `TEACHER`, `ADMIN`
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Exam schedule cancelled." }`
