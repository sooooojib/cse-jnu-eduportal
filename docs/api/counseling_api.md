# Faculty Counseling & Office Hours API Specification

This document details the endpoints for **Faculty Office Hours**, **Student Booking Petitions**, and the **Mutual-Exclusion Approval Engine**.

---

## 1. `GET /api/v1/counseling/slots`

### Overview
Retrieves faculty counseling availability slots for a specific month or week.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/counseling/slots`
* **Authentication**: Required (`Bearer <token>`)
* **Required Role**: All Authenticated Roles
* **Query Parameters**:
  - `teacherId`: Filter by instructor.
  - `month`: Month string (e.g. `2026-11`).
  - `status`: Slot status (`AVAILABLE`, `BOOKED`, `COMPLETED`).
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "slotId": "cs1eebc9-9c0b-4ef8-bb6d-6bb9bd380a01",
        "teacherId": "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
        "teacherName": "Prof. Dr. Rahman",
        "teacherAvatar": "https://storage.cse.jnu.ac.bd/avatars/rahman.jpg",
        "slotDate": "2026-11-18",
        "startTime": "10:00",
        "endTime": "11:00",
        "status": "AVAILABLE",
        "notes": "Office Room 410 - Thesis & Advising",
        "pendingRequestsCount": 2,
        "isMyRequestPending": false
      }
    ],
    "message": "Counseling slots retrieved."
  }
  ```

---

## 2. `POST /api/v1/counseling/slots`

### Overview
Creates a new faculty office hours availability slot.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/counseling/slots`
* **Authentication**: Required
* **Required Role**: `TEACHER`
* **Request Body**:
  ```json
  {
    "slotDate": "2026-11-18",
    "startTime": "10:00",
    "endTime": "11:00",
    "notes": "Office Room 410"
  }
  ```
* **Validation Rules**:
  - `slotDate` must be >= today.
  - `startTime` must precede `endTime`.
* **Success Response (`201 Created`)**: `{ "success": true, "data": { "slotId": "cs1eebc9..." }, "message": "Counseling slot opened." }`

---

## 3. `DELETE /api/v1/counseling/slots/:id`

### Overview
Cancels an unbooked office hour slot.

* **HTTP Method**: `DELETE`
* **Endpoint**: `/api/v1/counseling/slots/:id`
* **Authentication**: Required
* **Required Role**: `TEACHER`
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Counseling slot cancelled." }`

---

## 4. `POST /api/v1/counseling/slots/:id/requests`

### Overview
Submits a student appointment booking petition with a reason category.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/counseling/slots/:id/requests`
* **Authentication**: Required
* **Required Role**: `STUDENT`, `CR`
* **Request Body**:
  ```json
  {
    "category": "ACADEMIC_ADVISING",
    "notes": "Need guidance regarding course selection and thesis prerequisite requirements."
  }
  ```
* **Validation Rules**:
  - `category`: Must be one of `ACADEMIC_ADVISING`, `RESEARCH_DISCUSSION`, `MENTAL_PRESSURE`, `CLASS_ISSUE`, `CAREER_GUIDANCE`, `OTHER`.
  - `notes`: Min 5 characters, max 1000 characters.
* **Success Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "data": {
      "requestId": "cr1eebc9-9c0b-4ef8-bb6d-6bb9bd380a02",
      "status": "PENDING"
    },
    "message": "Appointment request submitted."
  }
  ```
* **Possible Errors**:
  - `409 Conflict`: `SLOT_NOT_AVAILABLE` ("This counseling slot is no longer available.")
  - `409 Conflict`: `DUPLICATE_BOOKING_REQUEST` ("You have already submitted a request for this slot.")

---

## 5. `GET /api/v1/counseling/requests/my`

### Overview
Fetches the student's personal counseling booking history.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/counseling/requests/my`
* **Authentication**: Required
* **Required Role**: `STUDENT`, `CR`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "requestId": "cr1eebc9-9c0b-4ef8-bb6d-6bb9bd380a02",
        "slotDate": "2026-11-18",
        "startTime": "10:00",
        "endTime": "11:00",
        "teacherName": "Prof. Dr. Rahman",
        "category": "ACADEMIC_ADVISING",
        "notes": "Need guidance regarding thesis.",
        "status": "PENDING",
        "submittedAt": "2026-08-28T11:00:00.000Z"
      }
    ],
    "message": "My counseling requests retrieved."
  }
  ```

---

## 6. `GET /api/v1/counseling/slots/:id/requests`

### Overview
Retrieves all student applicants for a specific office hour slot.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/counseling/slots/:id/requests`
* **Authentication**: Required
* **Required Role**: `TEACHER`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "requestId": "cr1eebc9-9c0b-4ef8-bb6d-6bb9bd380a02",
        "studentId": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
        "studentName": "Sajib Ahmed",
        "registrationNumber": "2020CSE001",
        "category": "ACADEMIC_ADVISING",
        "notes": "Need guidance regarding thesis prerequisites.",
        "status": "PENDING",
        "submittedAt": "2026-08-28T11:00:00.000Z"
      }
    ],
    "message": "Slot applicants retrieved."
  }
  ```

---

## 7. `POST /api/v1/counseling/requests/:id/action`

### Overview
Approves or rejects a student booking petition. Approving one request executes the atomic **Mutual-Exclusion Lock**, updating the slot to `BOOKED` and rejecting all competing requests for the slot.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/counseling/requests/:id/action`
* **Authentication**: Required
* **Required Role**: `TEACHER`
* **Request Body**:
  ```json
  {
    "action": "APPROVE"
  }
  ```
* **Validation Rules**: `action` must be `'APPROVE'` or `'REJECT'`.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "requestId": "cr1eebc9-9c0b-4ef8-bb6d-6bb9bd380a02",
      "status": "APPROVED",
      "slotStatus": "BOOKED"
    },
    "message": "Appointment approved. Competing requests have been declined."
  }
  ```
