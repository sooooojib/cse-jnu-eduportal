# Non-Functional Requirements Specification

This document details the Non-Functional Requirements (NFRs) for the **CSE JnU EduPortal** system, covering **Error Handling Standards**, **Security Architecture**, and **Performance Benchmarks**.

---

## 1. Error Handling & Resilience (NFR-ERR)

### 1.1 Uniform Error Protocol
All backend services must return standardized, machine-parseable error responses using the canonical JSON error envelope:

```json
{
  "success": false,
  "error": {
    "code": "SPECIFIC_MACHINE_ERROR_CODE",
    "message": "User-friendly description of what went wrong.",
    "details": [
      {
        "field": "code",
        "message": "Field validation details if applicable."
      }
    ]
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

### 1.2 Canonical Error Code Catalog

| Error Code | HTTP Status | Trigger Condition |
| :--- | :---: | :--- |
| `UNAUTHENTICATED` | `401` | Missing, expired, or malformed JWT token. |
| `FORBIDDEN_RESOURCE` | `403` | User lacks required role permissions for the endpoint. |
| `VALIDATION_FAILED` | `422` | Request body failed schema validation. |
| `RESOURCE_NOT_FOUND` | `404` | Requested entity ID does not exist. |
| `INVALID_VERIFICATION_CODE` | `400` | Code does not match or session has expired. |
| `DUPLICATE_ATTENDANCE` | `409` | Student has already submitted attendance for the session. |
| `SLOT_NOT_AVAILABLE` | `409` | Counseling slot is already booked or cancelled. |
| `DUPLICATE_SIGNUP_REQUEST` | `409` | Email or Student ID already in pending queue or active. |
| `SEMESTER_PETITION_EXISTS` | `409` | Student already has a pending semester change request. |
| `INTERNAL_SERVER_ERROR` | `500` | Uncaught server exception (details hidden in production). |

### 1.3 Mobile Client Resilience
- **Offline / Network Loss Handling**: The Flutter client must detect offline connectivity and display non-intrusive snackbars / offline banners. Cached timetables and course summaries must remain viewable offline.
- **Auto Retry & Exponential Backoff**: Transient network timeouts on idempotent GET requests must retry up to 3 times with exponential backoff.
- **Graceful Form Validation**: Field errors must be rendered inline beneath corresponding input fields without clearing already typed user data.

---

## 2. Security Requirements (NFR-SEC)

### 2.1 Authentication & Credential Security
- **Password Storage**: Passwords must be hashed using **Argon2id** (memory cost 64MB, time cost 3 iterations) or **bcrypt** (work factor >= 12). Plain-text passwords must never be logged or stored.
- **Token Cryptography**: JWT tokens signed with asymmetric keys (RS256) or strong HMAC secrets (HS256 with 256+ bit random secret).
- **Token Expiry**:
  - Access Token: Maximum lifetime of **15 minutes**.
  - Refresh Token: Maximum lifetime of **7 days** with token rotation on use.
- **Mobile Hardware Storage**: JWT tokens stored exclusively in native hardware keystores via `FlutterSecureStorage` (Keychain on iOS, EncryptedSharedPreferences on Android).

### 2.2 Transport Security & Communication Boundaries
- **HTTPS Enforcement**: 100% of network communication over TLS 1.3.
- **CORS Configuration**: Explicit origin whitelist restricting API access.
- **Zero Direct Database Exposure**: Database listening ports are bound exclusively to internal private networks and never exposed to the public internet or mobile devices.

### 2.3 Data Privacy & Anonymity Safeguards
- **Cryptographic Anonymity**: When a feedback query is made by a teacher, the serializer must permanently strip `studentId`, `name`, `avatarUrl`, and `email` before transmitting JSON.
- **Rate Limiting & Anti-Abuse**:
  - Auth endpoints (`/auth/login`, `/auth/signup-request`): Maximum 5 requests per minute per IP.
  - Code verification (`/attendance/verify`): Maximum 10 attempts per minute to prevent brute-force guessing of the 6-character code.
  - General API: 100 requests per minute per authenticated user.

### 2.4 File Upload Security
- Strict MIME type verification checking magic bytes (not just file extension).
- Maximum file size cap of **10 MB**.
- Storage in isolated object storage with sanitized UUID filenames to prevent path traversal attacks.

---

## 3. Performance & Scalability Requirements (NFR-PERF)

### 3.1 Latency & Response Times
- **Critical Endpoint Response Time**:
  - `POST /attendance/verify` (Code Entry): < **200 ms** (95th percentile) under concurrent class load.
  - `POST /attendance/session/start` (Terminal Launch): < **150 ms**.
  - `GET /schedule` (Dashboard Timetable): < **100 ms** (via indexed queries & caching).
- **Mobile App Launch Time**:
  - Cold start to interactive dashboard: < **1.5 seconds** (utilizing local cached profile & timetable).
  - Screen transitions: Smooth 60/120 FPS rendering.

### 3.2 Concurrency & Peak Load Handling
- **Simultaneous Verification Surge**: Capable of handling **500 concurrent student code submissions within a 10-second window** at the beginning of lectures without degradation or database deadlocks.
- **Database Connection Pooling**: Connection pool configured with health checks and timeout limits.
- **Optimized Query Indexing**: All foreign keys and query paths indexed:
  - `User(email, role, studentId)`
  - `Course(year, semester)`
  - `ScheduleSlot(courseId, targetYear, targetSemester)`
  - `AttendanceSession(code, courseId, status)`
  - `AttendanceRecord(sessionId, studentId)`
  - `CounselingSlot(teacherId, slotDate, status)`

### 3.3 Accessibility & Mobile Experience
- Light & Dark theme support adhering to WCAG 2.1 Level AA color contrast standards.
- Minimum interactive touch target size of **48×48 dp**.
- Dynamic font scaling support for system accessibility text sizes.
