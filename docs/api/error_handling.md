# Standardized API Error Handling & Error Codes

This document defines the canonical error response envelopes, HTTP status code mappings, and machine-readable error codes for **CSE JnU EduPortal**.

---

## 1. Canonical Error Envelope Schema

All API errors return a uniform, predictable JSON envelope:

```json
{
  "success": false,
  "error": {
    "code": "MACHINE_READABLE_ERROR_CODE",
    "message": "Human-readable explanation of the error.",
    "details": null
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

---

## 2. Standardized Error Response Archetypes

### 2.1 General Client Error (`400 Bad Request`)
Returned when the request violates business constraints or provides invalid parameters.
```json
{
  "success": false,
  "error": {
    "code": "INVALID_VERIFICATION_CODE",
    "message": "The 6-character attendance code is invalid or has expired.",
    "details": null
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

### 2.2 Validation Error Response (`422 Unprocessable Entity`)
Returned when schema or field-level validation fails.
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "One or more fields failed validation checks.",
    "details": [
      {
        "field": "rating",
        "message": "Rating must be an integer between 1 and 5."
      },
      {
        "field": "comments",
        "message": "Comments must be at least 10 characters in length."
      }
    ]
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

### 2.3 Authentication Error (`401 Unauthorized`)
Returned when the JWT token is missing, expired, blacklisted, or possesses an invalid cryptographic signature.
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHENTICATED",
    "message": "Authentication token is missing, invalid, or expired.",
    "details": null
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

### 2.4 Authorization Error (`403 Forbidden`)
Returned when an authenticated user attempts to access an endpoint outside their assigned role permissions.
```json
{
  "success": false,
  "error": {
    "code": "FORBIDDEN_RESOURCE",
    "message": "You do not have permission to perform this action.",
    "details": null
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

### 2.5 Not-Found Error (`404 Not Found`)
Returned when the requested resource ID does not exist in the database.
```json
{
  "success": false,
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "The requested course, user, or session was not found.",
    "details": null
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

### 2.6 Conflict Error (`409 Conflict`)
Returned when an action violates state invariants, uniqueness constraints, or concurrency locks.
```json
{
  "success": false,
  "error": {
    "code": "DUPLICATE_ATTENDANCE",
    "message": "Attendance has already been recorded for this session.",
    "details": null
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

### 2.7 Internal Server Error (`500 Internal Server Error`)
Returned when an unexpected runtime exception occurs on the backend.
```json
{
  "success": false,
  "error": {
    "code": "INTERNAL_SERVER_ERROR",
    "message": "An internal server error occurred. Please try again later.",
    "details": null
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

---

## 3. Comprehensive Error Code Catalog

| Error Code | HTTP Status | Trigger Condition |
| :--- | :---: | :--- |
| `INVALID_CREDENTIALS` | `401` | Incorrect email or password on login. |
| `TOKEN_EXPIRED` | `401` | Access token lifetime elapsed. |
| `REFRESH_TOKEN_INVALID`| `401` | Refresh token expired or rotated out. |
| `FORBIDDEN_RESOURCE` | `403` | User role lacks permission for target endpoint. |
| `VALIDATION_FAILED` | `422` | Request body failed input validation schema. |
| `RESOURCE_NOT_FOUND` | `404` | Entity ID does not exist. |
| `INVALID_VERIFICATION_CODE`| `400`| Dynamic attendance code is wrong or session closed. |
| `DUPLICATE_ATTENDANCE`| `409` | Student already verified for this session. |
| `SESSION_ALREADY_ACTIVE`| `409` | Active session already exists for this course. |
| `SLOT_NOT_AVAILABLE` | `409` | Counseling slot is no longer in `AVAILABLE` status. |
| `DUPLICATE_BOOKING_REQUEST`| `409`| Student already submitted a petition for this slot. |
| `CR_DATE_LOCKED` | `400` | CR attempted to schedule slot outside of tomorrow. |
| `SCHEDULE_COLLISION` | `409` | Overlapping room, teacher, or batch schedule detected. |
| `PENDING_SIGNUP_EXISTS`| `409` | Registration email or student ID already in pending queue. |
| `PENDING_SEMESTER_EXISTS`| `409`| Student already has a pending semester change request. |
| `FILE_TOO_LARGE` | `413` | Uploaded attachment exceeds 10 MB limit. |
| `UNSUPPORTED_MEDIA_TYPE`| `415`| Uploaded MIME type not permitted. |
| `RATE_LIMIT_EXCEEDED` | `429` | IP or user exceeded request rate quota. |
| `INTERNAL_SERVER_ERROR`| `500` | Uncaught server exception. |
