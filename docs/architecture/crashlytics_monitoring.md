# Firebase Crashlytics & Production Monitoring Architecture
## CSE JnU EduPortal — Stage 33

---

## 1. System Overview

Production monitoring for **CSE JnU EduPortal** provides real-time visibility into runtime stability, fatal and non-fatal exceptions, framework layout errors, and Cloud Functions execution telemetry.

```
┌────────────────────────────────────────────────────────────────────────┐
│                    EduPortal Observability Pipeline                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Client Framework Errors: FlutterError.onError ──► Crashlytics Fatal │
│ 2. Uncaught Async Errors: PlatformDispatcher.onError ──► Crashlytics   │
│ 3. Repositories / Domain Failures: AppLogger.e ──► Crashlytics Non-Fatal│
│ 4. User Presentation: ErrorHandler ──► Sanitized friendly message     │
│ 5. Backend Server Errors: StructuredLogger ──► Google Cloud Logging    │
│ 6. Critical System Actions: StructuredLogger.audit ──► Audit Trail     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Client-Side Error Reporting (Flutter)

The mobile client encapsulates error reporting within `CrashlyticsService` (`mobile/lib/core/monitoring/crashlytics_service.dart`), wired into dependency injection and application bootstrap.

### 2.1 Error Ingestion Points

1. **Flutter Framework Errors (`FlutterError.onError`)**:
   - Catches rendering exceptions, widget lifecycle issues, and assertion failures in production builds.
   - Forwards to `sl<CrashlyticsService>().recordFlutterError(details, fatal: true)`.
2. **Uncaught Asynchronous Errors (`PlatformDispatcher.instance.onError`)**:
   - Catches unawaited future rejections, isolate errors, and native platform channel failures.
   - Forwards to `sl<CrashlyticsService>().recordError(error, stack, fatal: true, reason: 'Uncaught platform asynchronous error')`.
3. **Controlled Non-Fatal Errors (`AppLogger.e`)**:
   - When any repository or controller logs an error via `AppLogger.e(msg, error, stack)`, it automatically dispatches a non-fatal event to Crashlytics with sanitized reason and stack trace.
4. **User-Facing Sanitization (`ErrorHandler.handleException`)**:
   - Technical Dart internal errors (`FormatException`, `RangeError`, `NoSuchMethodError`, `TypeError`) are sanitized to friendly user strings (`"An unexpected error occurred. Please try again."`), preventing raw exception text or memory addresses from leaking to the UI.

---

## 3. Diagnostic Context & Zero-Leakage Privacy Policy

### 3.1 Strict Privacy Invariants
Under no circumstances are the following logged or transmitted to Crashlytics or Cloud Logging:
- **Zero Secrets**: Passwords, plain credentials, private keys, API secrets.
- **Zero Auth Tokens**: JWT ID tokens, refresh tokens, access tokens, `Bearer` authorization headers.
- **Zero Unnecessary PII**: Student phone numbers, email addresses, national IDs, or true student names in anonymous feedback workflows.
- **Zero Private Feedback Content**: Confidential comments submitted to faculty members.

### 3.2 Automated Context Sanitization
The `CrashlyticsContextSanitizer` automatically intercepts all diagnostic keys and strings before transmission:
- Any key matching `/(password|token|secret|key|auth|credential|pin|otp|phone|email|comment|feedback)/i` is redacted to `[REDACTED]`.
- String messages matching JWT patterns (`ey...`) or `Bearer <token>` headers are replaced with `Bearer [REDACTED]` and `[REDACTED_JWT]`.

### 3.3 Safe Diagnostic Metadata
Only non-sensitive operational telemetry is attached to Crashlytics sessions:
- `user_role`: `"STUDENT" | "CR" | "TEACHER" | "ADMIN"`
- `user_year`: `1..4`
- `user_semester`: `1..2`
- `platform`: `"android" | "ios" | "macos"`
- `build_mode`: `"release" | "debug" | "profile"`
- `screen`: e.g. `"StudentAttendanceScreen"`
- `operation`: e.g. `"submitAttendanceCode"`

On user sign-in, `AuthController` synchronizes safe claims via `setSafeUserContext()`. On user sign-out, `clearUserContext()` resets the session to anonymous.

---

## 4. Server-Side Monitoring & Cloud Functions Telemetry

Server-side operations in Cloud Functions utilize `StructuredLogger` (`functions/src/monitoring.ts`) to produce JSON logs ingested by **Google Cloud Logging** and **Cloud Monitoring**.

### 4.1 Failure Categorization
Errors are mapped to explicit operational categories:

| Category | Description | HTTP Code Equivalent | Example Scenario |
|:---|:---|:---:|:---|
| **`AUTH`** | Missing or invalid user identity | `401 Unauthorized` | Missing Firebase Auth JWT |
| **`AUTHORIZATION`** | Insufficient role or mismatched cohort | `403 Forbidden` | Student trying to start attendance |
| **`VALIDATION`** | Parameter schema or date constraints | `400 Bad Request` | 5-char code instead of 6-char |
| **`CONCURRENCY`** | Race condition or conflicting booking | `409 Conflict` | Competing counseling booking |
| **`NOT_FOUND`** | Requested resource does not exist | `404 Not Found` | Non-existent course ID |
| **`COMMUNICATION`** | External email or SMS transport issue | `502 Bad Gateway` | SMTP server connection failure |
| **`STORAGE`** | Bucket upload policy or MIME violation | `400 Bad Request` | Disallowed file extension |
| **`SYSTEM_ERROR`** | Unexpected internal database error | `500 Internal Error`| Firestore transaction abort |

### 4.2 Security Audit Trail
Critical administrative actions emit structured `NOTICE` audit entries:
```json
{
  "severity": "NOTICE",
  "type": "SECURITY_AUDIT",
  "operation": "approveSignupRequest",
  "actorUid": "admin_uid_xyz",
  "decision": "APPROVED",
  "targetEntity": "signupRequest",
  "targetId": "req_12345",
  "details": { "assignedRole": "STUDENT", "year": 3, "semester": 1 }
}
```

---

## 5. Build & Release Configuration

### 5.1 Android Setup
- `mobile/android/build.gradle.kts`:
  - `classpath("com.google.firebase:firebase-crashlytics-gradle:3.0.2")`
- `mobile/android/app/build.gradle.kts`:
  - `id("com.google.firebase.crashlytics")`
- In release builds, `setCrashlyticsCollectionEnabled(true)` is activated automatically.
- In debug builds, collection is disabled by default to avoid cluttering production incident metrics during daily development.

### 5.2 Controlled Developer Testing
A non-fatal diagnostic report can be safely dispatched without crashing the application:
```dart
await sl<CrashlyticsService>().sendTestReport();
```
This triggers a controlled `StateError('CSE JnU EduPortal Controlled Crashlytics Verification Event')` with sanitized test tags.
