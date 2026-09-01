# CSE JnU EduPortal — API Architecture & Overview

This document provides the high-level architecture, protocol standards, master endpoint routing, and security conventions for the **CSE JnU EduPortal** RESTful API.

---

## 1. System Architecture & Protocols

The API is built as a stateless, high-throughput REST API serving the Flutter mobile client over secure HTTPS.

```
┌────────────────────────────────────────────────────────┐
│                  FLUTTER MOBILE CLIENT                 │
└───────────────────────────┬────────────────────────────┘
                            │ HTTPS / TLS 1.3
                            │ Authorization: Bearer <JWT>
                            ▼
┌────────────────────────────────────────────────────────┐
│                   API GATEWAY / ROUTER                 │
│                   Base URL: /api/v1                    │
├────────────────────────────────────────────────────────┤
│ • Rate Limiter & IP Throttling                         │
│ • CORS Whitelist Guard                                 │
│ • JWT Session Verification                             │
│ • RBAC Role Guards (STUDENT, CR, TEACHER, ADMIN)       │
│ • Request Validation Middleware                        │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│                   BUSINESS CONTROLLERS                 │
└────────────────────────────────────────────────────────┘
```

### General Specifications:
- **Base URL**: `https://api.cse.jnu.ac.bd/api/v1` (or relative `/api/v1`)
- **Transport**: Encrypted over HTTPS / TLS 1.3
- **Payload Format**: `application/json; charset=utf-8` (or `multipart/form-data` for file uploads)
- **Authentication**: Standard HTTP `Authorization: Bearer <access_token>` header
- **Date & Time Standard**: ISO 8601 Extended Format in UTC (`YYYY-MM-DDTHH:mm:ss.sssZ`)

---

## 2. Master API Endpoint Index

| API Group | Documentation File | Description |
| :--- | :--- | :--- |
| **API Conventions** | [`api_conventions.md`](api_conventions.md) | Standard envelopes, pagination, sorting, filtering, and parameter conventions. |
| **Error Handling** | [`error_handling.md`](error_handling.md) | Standardized error envelopes, status codes, and machine-readable error codes. |
| **Authentication** | [`authentication_api.md`](authentication_api.md) | Login, token refresh, public signup requests, password management, and session retrieval. |
| **Users & Profiles** | [`user_api.md`](user_api.md) | User profiles, avatar uploads, faculty directory, and in-app notifications. |
| **Courses & Semesters** | [`course_api.md`](course_api.md) | Curriculum catalog, course enrollment, and semester upgrade state machine. |
| **Attendance Terminal** | [`attendance_api.md`](attendance_api.md) | 6-char live terminal code generator, student verification, live roster, and Excel export. |
| **Schedules & Routine** | [`schedule_api.md`](schedule_api.md) | Weekly timetable grid, CR tomorrow-only scheduling, and WhatsApp routine broadcast. |
| **Exams & Tests** | [`exam_api.md`](exam_api.md) | Midterms, lab assessments, and term final exam schedules with room allocations. |
| **Faculty Counseling** | [`counseling_api.md`](counseling_api.md) | Office hours calendar, student booking petitions, and mutual-exclusion atomic locking. |
| **Feedback & Reviews** | [`feedback_api.md`](feedback_api.md) | 1–5 star ratings, anonymity detachment, threaded teacher replies, and file uploads. |
| **Admin Control** | [`admin_api.md`](admin_api.md) | Signup approval queue, semester petitions, user directory, course assignments, and audits. |

---

## 3. Flutter Integration Guidelines

To guarantee high mobile performance, minimal battery consumption, and type-safe data deserialization in Flutter:

1. **Uniform Response Envelopes**: All successful responses return a predictable `{ success: true, data: T, message: string, meta?: object }` structure, simplifying generic Dart mapping (`ApiResponse<T>`).
2. **Deterministic Error Handling**: Errors return a standardized `{ success: false, error: { code, message, details } }` format that maps cleanly to typed domain `Failure` classes.
3. **Idempotent Requests**: High-frequency actions (such as attendance code verification) support idempotent retries without creating duplicated records.
4. **Header Interceptors**: Mobile HTTP client automatically attaches the active access token and refreshes transparently on `401 Unauthorized`.
