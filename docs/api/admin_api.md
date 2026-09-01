# Admin Management & Directory API Specification

This document details the administrative control endpoints for **Onboarding Signup Moderation**, **Semester Upgrade Review**, **User Directory Management**, and **Teacher Course Assignments**.

---

## 1. `GET /api/v1/admin/signup-requests`

### Overview
Retrieves the moderation queue of incoming registration requests.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/admin/signup-requests`
* **Authentication**: Required (`Bearer <token>`)
* **Required Role**: `ADMIN`
* **Query Parameters**:
  - `status`: `PENDING` (default) | `APPROVED` | `REJECTED` | `ALL`.
  - `role`: Filter by requested role (`STUDENT`, `CR`, `TEACHER`).
  - `page` & `limit`: Pagination parameters.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "requestId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
        "fullName": "Tanvir Ahmed",
        "email": "tanvir@cse.jnu.ac.bd",
        "role": "STUDENT",
        "studentId": "2023CSE012",
        "phone": null,
        "status": "PENDING",
        "createdAt": "2026-08-28T09:00:00.000Z"
      }
    ],
    "message": "Signup requests retrieved.",
    "meta": { "page": 1, "limit": 20, "total": 12, "pendingCount": 12 }
  }
  ```

---

## 2. `POST /api/v1/admin/signup-requests/:id/approve`

### Overview
Approves a pending registration request, provisions the `User` account, generates a secure random password, and dispatches the welcome onboarding email.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/admin/signup-requests/:id/approve`
* **Authentication**: Required
* **Required Role**: `ADMIN`
* **Request Body**:
  ```json
  {
    "assignedYear": 1,
    "assignedSemester": 1
  }
  ```
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "userId": "u1eebc99-9c0b-4ef8-bb6d-6bb9bd380a01",
      "email": "tanvir@cse.jnu.ac.bd",
      "role": "STUDENT",
      "status": "APPROVED"
    },
    "message": "User account created and credentials dispatched via email."
  }
  ```

---

## 3. `POST /api/v1/admin/signup-requests/:id/reject`

### Overview
Rejects a registration request with an explanation.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/admin/signup-requests/:id/reject`
* **Authentication**: Required
* **Required Role**: `ADMIN`
* **Request Body**:
  ```json
  {
    "reason": "Student ID does not match department admission records."
  }
  ```
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Signup request rejected." }`

---

## 4. `GET /api/v1/admin/semester-requests`

### Overview
Retrieves student petitions to advance to the next semester.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/admin/semester-requests`
* **Authentication**: Required
* **Required Role**: `ADMIN`
* **Query Parameters**:
  - `status`: `PENDING` (default) | `APPROVED` | `REJECTED`.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "requestId": "f1eebc99-9c0b-4ef8-bb6d-6bb9bd380a66",
        "studentId": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
        "studentName": "Sajib Ahmed",
        "registrationNumber": "2020CSE001",
        "currentYear": 3,
        "currentSemester": 1,
        "requestedYear": 3,
        "requestedSemester": 2,
        "status": "PENDING",
        "submittedAt": "2026-08-27T14:00:00.000Z"
      }
    ],
    "message": "Semester upgrade petitions retrieved."
  }
  ```

---

## 5. `POST /api/v1/admin/semester-requests/:id/approve`

### Overview
Approves a student's semester promotion, updating their active enrolled batch.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/admin/semester-requests/:id/approve`
* **Authentication**: Required
* **Required Role**: `ADMIN`
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Semester promotion approved successfully." }`

---

## 6. `POST /api/v1/admin/semester-requests/:id/reject`

### Overview
Declines a student's semester promotion request with an audit explanation.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/admin/semester-requests/:id/reject`
* **Authentication**: Required
* **Required Role**: `ADMIN`
* **Request Body**: `{ "reason": "Outstanding semester clearance requirements." }`
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Semester request rejected." }`

---

## 7. `GET /api/v1/admin/users`

### Overview
Searches and browses the departmental user directory.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/admin/users`
* **Authentication**: Required
* **Required Role**: `ADMIN`
* **Query Parameters**:
  - `role`: Filter by `STUDENT`, `CR`, `TEACHER`, or `ADMIN`.
  - `search`: Search name, email, student ID, or phone.
  - `page` & `limit`: Pagination parameters.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
        "fullName": "Prof. Dr. Rahman",
        "email": "rahman@cse.jnu.ac.bd",
        "role": "TEACHER",
        "assignedCoursesCount": 3,
        "isActive": true,
        "createdAt": "2026-01-10T08:00:00.000Z"
      }
    ],
    "message": "User directory retrieved.",
    "meta": { "page": 1, "limit": 20, "total": 240 }
  }
  ```

---

## 8. `POST /api/v1/admin/users`

### Overview
Direct administrator provisioning of a new user account with custom credentials.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/admin/users`
* **Authentication**: Required
* **Required Role**: `ADMIN`
* **Request Body**:
  ```json
  {
    "fullName": "Dr. Kamal Hossain",
    "email": "kamal@cse.jnu.ac.bd",
    "role": "TEACHER",
    "phone": "+8801711998877",
    "initialPassword": "CustomPassword123!"
  }
  ```
* **Success Response (`201 Created`)**: `{ "success": true, "message": "User provisioned successfully." }`

---

## 9. `POST /api/v1/admin/users/:teacherId/courses`

### Overview
Assigns or unassigns departmental courses to a faculty member via a course ID array.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/admin/users/:teacherId/courses`
* **Authentication**: Required
* **Required Role**: `ADMIN`
* **Request Body**:
  ```json
  {
    "courseIds": [
      "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
      "c2eebc99-9c0b-4ef8-bb6d-6bb9bd380a34"
    ]
  }
  ```
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Teacher course assignments updated." }`

---

## 10. `GET /api/v1/admin/feedback-audit`

### Overview
Administrative compliance view displaying all feedback entries across all faculty members with full unmasked student identities.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/admin/feedback-audit`
* **Authentication**: Required
* **Required Role**: `ADMIN`
* **Success Response (`200 OK`)**: Returns complete audit trail of student evaluations.
