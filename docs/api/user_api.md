# Users, Profiles & Notifications API Specification

This document specifies the endpoints for **User Profiles**, **Faculty Directory Lookups**, and **Mobile Notification Feeds**.

---

## 1. `GET /api/v1/users/me`

### Overview
Fetches the full profile of the authenticated user.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/users/me`
* **Authentication**: Required (`Bearer <token>`)
* **Required Role**: All Authenticated Roles
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
      "email": "teacher@cse.jnu.ac.bd",
      "fullName": "Prof. Dr. Rahman",
      "role": "TEACHER",
      "phone": "+8801711223344",
      "avatarUrl": "https://storage.cse.jnu.ac.bd/avatars/rahman.jpg",
      "studentId": null,
      "year": null,
      "semester": null,
      "semesterStatus": "NONE"
    },
    "message": "User profile retrieved.",
    "meta": {
      "timestamp": "2026-08-28T12:00:00.000Z"
    }
  }
  ```

---

## 2. `PATCH /api/v1/users/me`

### Overview
Updates allowed profile attributes (phone number, display preferences).

* **HTTP Method**: `PATCH`
* **Endpoint**: `/api/v1/users/me`
* **Authentication**: Required
* **Required Role**: All Authenticated Roles
* **Request Body**:
  ```json
  {
    "phone": "+8801700112233"
  }
  ```
* **Validation Rules**: `phone` must match valid format if provided.
* **Success Response (`200 OK`)**: Returns updated profile object.

---

## 3. `POST /api/v1/users/me/avatar`

### Overview
Uploads and attaches a custom profile picture asset.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/users/me/avatar`
* **Authentication**: Required
* **Content-Type**: `multipart/form-data`
* **Request Body**: `file` (Image binary: PNG, JPEG, WebP, max 5MB).
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "avatarUrl": "https://storage.cse.jnu.ac.bd/avatars/a0eebc99.jpg"
    },
    "message": "Avatar updated successfully."
  }
  ```
* **Possible Errors**:
  - `413 Payload Too Large`: `FILE_TOO_LARGE` ("Avatar must not exceed 5MB.")
  - `415 Unsupported Media Type`: `UNSUPPORTED_MEDIA_TYPE` ("Only PNG, JPEG, and WebP images are supported.")

---

## 4. `GET /api/v1/users/teachers`

### Overview
Retrieves the list of active faculty members (used by students to populate counseling booking and feedback dropdowns).

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/users/teachers`
* **Authentication**: Required
* **Required Role**: All Authenticated Roles
* **Query Parameters**:
  - `search`: Search teacher name (e.g. `search=Rahman`).
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
        "fullName": "Prof. Dr. Rahman",
        "email": "rahman@cse.jnu.ac.bd",
        "avatarUrl": "https://storage.cse.jnu.ac.bd/avatars/rahman.jpg",
        "assignedCourses": [
          {
            "id": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
            "code": "CSE-3101",
            "title": "Operating Systems"
          }
        ]
      }
    ],
    "message": "Faculty directory retrieved."
  }
  ```

---

## 5. `GET /api/v1/users/notifications`

### Overview
Fetches the authenticated user's notification feed.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/users/notifications`
* **Authentication**: Required
* **Required Role**: All Authenticated Roles
* **Query Parameters**:
  - `isRead`: Filter by read status (`true` | `false`).
  - `page`: Page number (default: `1`).
  - `limit`: Limit per page (default: `20`).
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "d1eebc99-9c0b-4ef8-bb6d-6bb9bd380a44",
        "title": "Counseling Request Approved",
        "body": "Prof. Dr. Rahman has approved your counseling appointment for Nov 18 at 10:00 AM.",
        "notificationType": "COUNSELING",
        "referenceType": "counseling_slots",
        "referenceId": "e1eebc99-9c0b-4ef8-bb6d-6bb9bd380a55",
        "isRead": false,
        "createdAt": "2026-08-28T10:15:00.000Z"
      }
    ],
    "message": "Notifications retrieved.",
    "meta": {
      "page": 1,
      "limit": 20,
      "total": 5,
      "unreadCount": 2
    }
  }
  ```

---

## 6. `PATCH /api/v1/users/notifications/:id/read`

### Overview
Marks an individual notification as read.

* **HTTP Method**: `PATCH`
* **Endpoint**: `/api/v1/users/notifications/:id/read`
* **Authentication**: Required
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Notification marked as read." }`

---

## 7. `PATCH /api/v1/users/notifications/read-all`

### Overview
Marks all notifications for the authenticated user as read.

* **HTTP Method**: `PATCH`
* **Endpoint**: `/api/v1/users/notifications/read-all`
* **Authentication**: Required
* **Success Response (`200 OK`)**: `{ "success": true, "message": "All notifications marked as read." }`
