# Backend Application Architecture

## 1. Architectural Model

The **CSE JnU EduPortal Backend** serves as the authoritative core of the system. It handles business logic, security policies, role-based authorization, state transitions, and persistent storage.

```
src/
├── app.ts                         # Server entry point & global middlewares
├── config/                        # Environment variables & database connection
├── common/
│   ├── constants/                 # Enums, roles, status constants
│   ├── errors/                    # Custom AppError classes & error handler
│   ├── middlewares/               # Auth, RBAC guards, rate limiters, logger
│   └── utils/                     # Password hashing, token signers, response wrappers
├── modules/
│   ├── auth/                      # Login, token refresh, signup requests
│   ├── users/                     # User management, profile & roles
│   ├── semester-requests/         # Semester upgrade state machine
│   ├── courses/                   # Course catalog & faculty assignments
│   ├── schedule/                  # Class timetables, routine & exams
│   ├── attendance/                # Dynamic terminal & code verification
│   ├── counseling/                # Office hour slots & booking engine
│   └── feedback/                  # Anonymized reviews & replies
└── storage/
    └── database/                  # Schema migrations, seeders, queries
```

---

## 2. Layered Responsibilities

```
[ Incoming Request ]
        │
        ▼
┌────────────────────────────────────────────────────────┐
│ 1. Routing & Middleware Layer                          │
│    • Rate Limiting & CORS                              │
│    • JWT Verification & Session Context Injection      │
│    • Role-Based Access Control (RBAC Guard)            │
│    • Request Payload Validation (DTO Schema Validator) │
└───────────────────────┬────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│ 2. Controller Layer                                    │
│    • Extracts validated params, body, and auth context │
│    • Delegates execution to appropriate Service        │
│    • Returns uniform JSON response envelope            │
└───────────────────────┬────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│ 3. Service / Domain Layer                              │
│    • Enforces business rules and state machines        │
│    • Orchestrates atomic transactions                  │
│    • Sanitizes sensitive data (e.g., student identity) │
└───────────────────────┬────────────────────────────────┘
                        │
                        ▼
┌────────────────────────────────────────────────────────┐
│ 4. Repository & Persistence Layer                      │
│    • Executes parameterized queries / ORM operations   │
│    • Enforces relational integrity and index lookups   │
└────────────────────────────────────────────────────────┘
```

---

## 3. Authentication, Security & RBAC Guards

### 3.1 Token Strategy
- **Access Tokens**: Short-lived JWTs (15 minutes) signed with HMAC-SHA256 / RSA containing `userId`, `role`, `year`, and `semester`.
- **Refresh Tokens**: Long-lived secure tokens (7 days) stored securely to allow seamless session rotation.
- **Password Security**: Cryptographically salted and hashed using modern algorithms (Argon2id / bcrypt with strong work factor).

### 3.2 Role Guard Architecture
Endpoints are protected by declarative role guards:
```typescript
// Conceptual RBAC Guard:
authorize(['ADMIN'])
authorize(['TEACHER', 'ADMIN'])
authorize(['STUDENT', 'CR'])
```

---

## 4. Transactional Integrity & Concurrency

The backend guarantees atomicity for critical multi-step operations:

1. **Counseling Booking Mutual Exclusion**:
   - Approving a booking updates the slot status to `BOOKED`, flags the winning request as `APPROVED`, and updates all competing requests for the same slot to `REJECTED` in an **atomic database transaction**.
2. **Account Provisioning**:
   - Approving a `SignupRequest` creates the `User` record, assigns default semester parameters, marks the request as `APPROVED`, and dispatches the welcome email.
3. **Attendance Verification**:
   - Enforces unique combination of `(sessionId, studentId)` to prevent duplicate or race-condition submissions.

---

## 5. Standard API Response Protocol

All endpoints return a uniform response envelope:

### Success Response (`200 OK`, `201 Created`):
```json
{
  "success": true,
  "data": {
    "id": "uuid-v4",
    "title": "Operating Systems"
  },
  "message": "Resource retrieved successfully",
  "meta": {
    "timestamp": "2026-08-28T12:00:00Z"
  }
}
```

### Error Response (`400`, `401`, `403`, `404`, `422`, `500`):
```json
{
  "success": false,
  "error": {
    "code": "INVALID_VERIFICATION_CODE",
    "message": "The 6-character attendance code provided is invalid or has expired.",
    "details": null
  },
  "meta": {
    "timestamp": "2026-08-28T12:00:00Z"
  }
}
```
