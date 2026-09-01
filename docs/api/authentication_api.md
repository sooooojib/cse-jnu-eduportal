# Authentication & Account API Specification

This document specifies the endpoints for **User Authentication**, **Session Management**, **Password Lifecycle**, and **Public Registration Requests**.

---

## 1. `POST /api/v1/auth/login`

### Overview
Authenticates existing departmental users via email and password, issuing access and refresh JWT tokens.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/auth/login`
* **Authentication**: None (Public)
* **Required Role**: None
* **Request Headers**: `Content-Type: application/json`
* **Request Body**:
  ```json
  {
    "email": "student@cse.jnu.ac.bd",
    "password": "SecurePassword123!"
  }
  ```
* **Validation Rules**:
  - `email`: Required, valid email format.
  - `password`: Required, non-empty string.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "accessToken": "eyJhbGciOiJSUzI1NiIs...",
      "refreshToken": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "tokenType": "Bearer",
      "expiresIn": 900,
      "user": {
        "id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
        "email": "student@cse.jnu.ac.bd",
        "fullName": "Sajib Ahmed",
        "role": "STUDENT",
        "studentId": "2020CSE001",
        "phone": null,
        "avatarUrl": null,
        "year": 3,
        "semester": 1,
        "semesterStatus": "NONE"
      }
    },
    "message": "Authentication successful.",
    "meta": {
      "timestamp": "2026-08-28T12:00:00.000Z"
    }
  }
  ```
* **Possible Errors**:
  - `401 Unauthorized`: `INVALID_CREDENTIALS` ("Invalid email or password.")
  - `422 Unprocessable Entity`: `VALIDATION_FAILED` ("Email and password are required.")
  - `429 Too Many Requests`: `RATE_LIMIT_EXCEEDED` ("Too many login attempts. Please wait 5 minutes.")

---

## 2. `POST /api/v1/auth/signup-request`

### Overview
Public gateway for prospective students, CRs, and teachers to submit account registration requests for administrative moderation.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/auth/signup-request`
* **Authentication**: None (Public)
* **Required Role**: None
* **Request Body**:
  ```json
  {
    "fullName": "Farhan Tanvir",
    "email": "farhan@cse.jnu.ac.bd",
    "role": "STUDENT",
    "studentId": "2022CSE015",
    "phone": null
  }
  ```
* **Validation Rules**:
  - `fullName`: String (2–100 chars).
  - `email`: Valid email format.
  - `role`: One of `'STUDENT'`, `'CR'`, `'TEACHER'`.
  - If `role` is `'STUDENT'` or `'CR'`: `studentId` is required (string, 5–30 chars).
  - If `role` is `'TEACHER'`: `phone` is required (valid phone string).
* **Success Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "data": {
      "requestId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
      "status": "PENDING"
    },
    "message": "Your registration request has been submitted for admin approval. You will receive an email with your credentials once approved.",
    "meta": {
      "timestamp": "2026-08-28T12:00:00.000Z"
    }
  }
  ```
* **Possible Errors**:
  - `409 Conflict`: `PENDING_SIGNUP_EXISTS` ("An account or pending request with this email or student ID already exists.")
  - `422 Unprocessable Entity`: `VALIDATION_FAILED` ("Invalid input fields.")

---

## 3. `POST /api/v1/auth/refresh-token`

### Overview
Exchanges a valid refresh token for a newly minted short-lived access token.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/auth/refresh-token`
* **Authentication**: None
* **Request Body**:
  ```json
  {
    "refreshToken": "7c9e6679-7425-40de-944b-e07fc1f90ae7"
  }
  ```
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "accessToken": "eyJhbGciOiJSUzI1NiIs...",
      "tokenType": "Bearer",
      "expiresIn": 900
    },
    "message": "Token refreshed successfully.",
    "meta": {
      "timestamp": "2026-08-28T12:00:00.000Z"
    }
  }
  ```
* **Possible Errors**:
  - `401 Unauthorized`: `REFRESH_TOKEN_INVALID` ("Refresh token is expired or revoked.")

---

## 4. `GET /api/v1/auth/me`

### Overview
Retrieves the currently authenticated user's profile, role permissions, and active semester metadata.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/auth/me`
* **Authentication**: Required (`Bearer <access_token>`)
* **Required Role**: All Authenticated Roles (`STUDENT`, `CR`, `TEACHER`, `ADMIN`)
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "id": "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
      "email": "student@cse.jnu.ac.bd",
      "fullName": "Sajib Ahmed",
      "role": "STUDENT",
      "studentId": "2020CSE001",
      "phone": null,
      "avatarUrl": "https://storage.cse.jnu.ac.bd/avatars/sajib.jpg",
      "year": 3,
      "semester": 1,
      "semesterStatus": "NONE",
      "createdAt": "2026-01-15T08:30:00.000Z"
    },
    "message": "User profile retrieved.",
    "meta": {
      "timestamp": "2026-08-28T12:00:00.000Z"
    }
  }
  ```
* **Possible Errors**:
  - `401 Unauthorized`: `UNAUTHENTICATED`

---

## 5. `POST /api/v1/auth/change-password`

### Overview
Allows authenticated users to update their platform password.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/auth/change-password`
* **Authentication**: Required
* **Required Role**: All Authenticated Roles
* **Request Body**:
  ```json
  {
    "currentPassword": "OldPassword123!",
    "newPassword": "NewStrongPassword456!"
  }
  ```
* **Validation Rules**:
  - `newPassword`: Min 8 characters, containing uppercase, lowercase, number, and special character.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Password changed successfully.",
    "meta": {
      "timestamp": "2026-08-28T12:00:00.000Z"
    }
  }
  ```
* **Possible Errors**:
  - `400 Bad Request`: `INVALID_CREDENTIALS` ("Current password does not match.")
  - `422 Unprocessable Entity`: `VALIDATION_FAILED` ("New password does not meet complexity requirements.")

---

## 6. `POST /api/v1/auth/logout`

### Overview
Revokes the active refresh token and terminates the user session.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/auth/logout`
* **Authentication**: Required
* **Request Body**:
  ```json
  {
    "refreshToken": "7c9e6679-7425-40de-944b-e07fc1f90ae7"
  }
  ```
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "message": "Logged out successfully.",
    "meta": {
      "timestamp": "2026-08-28T12:00:00.000Z"
    }
  }
  ```
