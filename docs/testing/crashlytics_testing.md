# Firebase Crashlytics & Monitoring Testing Protocol
## CSE JnU EduPortal — Stage 33

---

## 1. Test Overview & Objectives

This protocol verifies that runtime exceptions, framework rendering errors, asynchronous isolate errors, and Cloud Functions failures are captured accurately in Firebase Crashlytics and Google Cloud Logging without leaking sensitive credentials or PII.

---

## 2. Test Execution Matrix

| Test ID | Test Category | Target Component | Success Criteria | Automated Test Suite |
|:---|:---|:---|:---|:---|
| **CRASH-01** | Privacy & Sanitization | `CrashlyticsContextSanitizer` | Redacts `password`, `token`, `secret`, `apiKey`, `phone`, `email` | `mobile/test/core/monitoring/crashlytics_service_test.dart` (Test 1) |
| **CRASH-02** | Token Redaction | `CrashlyticsContextSanitizer` | Redacts raw JWTs and `Bearer` authentication headers | `mobile/test/core/monitoring/crashlytics_service_test.dart` (Test 2) |
| **CRASH-03** | Startup & Metadata | `CrashlyticsService` | Sets `platform`, `build_mode`, and respects release vs debug collection | `mobile/test/core/monitoring/crashlytics_service_test.dart` (Test 3) |
| **CRASH-04** | Sensitive Key Guard | `CrashlyticsService.setCustomKey` | Rejects attempts to store disallowed sensitive keys | `mobile/test/core/monitoring/crashlytics_service_test.dart` (Test 4) |
| **CRASH-05** | User Context Binding | `CrashlyticsService.setSafeUserContext` | Sets opaque `uid`, `user_role`, `user_year`, and `user_semester` without PII | `mobile/test/core/monitoring/crashlytics_service_test.dart` (Test 5) |
| **CRASH-06** | Session Clearance | `CrashlyticsService.clearUserContext` | Resets `uid` and marks role as `ANONYMOUS` upon logout | `mobile/test/core/monitoring/crashlytics_service_test.dart` (Test 6) |
| **CRASH-07** | Non-Fatal Diagnostics | `CrashlyticsService.recordError` | Ingests non-fatal error, sanitizes reason, sets custom tags | `mobile/test/core/monitoring/crashlytics_service_test.dart` (Test 7) |
| **CRASH-08** | Framework Rendering Errors | `CrashlyticsService.recordFlutterError` | Forwards `FlutterErrorDetails` with fatal flag | `mobile/test/core/monitoring/crashlytics_service_test.dart` (Test 8) |
| **CRASH-09** | Controlled Test Report | `CrashlyticsService.sendTestReport` | Dispatches controlled diagnostic event without crashing app | `mobile/test/core/monitoring/crashlytics_service_test.dart` (Test 10) |
| **CRASH-10** | Backend Sanitization | `DiagnosticSanitizer` (Cloud Functions) | Redacts secrets and masks emails (`s***@jnu.ac.bd`) | `functions/src/monitoring.test.ts` (Test 1 & 2) |
| **CRASH-11** | Backend Telemetry | `StructuredLogger` (Cloud Functions) | Extracts non-sensitive telemetry and formats failure categories | `functions/src/monitoring.test.ts` (Test 3 & 4) |
| **CRASH-12** | Backend Security Audit | `StructuredLogger.audit` | Emits structured `SECURITY_AUDIT` entries for critical ops | `functions/src/monitoring.test.ts` (Test 5) |

---

## 3. Controlled Development Verification (No App Crash)

To test Crashlytics delivery in a controlled manner without terminating the running application:

### Step 1: Temporarily Enable Collection in Debug
In your debug session, invoke the controlled test trigger:
```dart
final crashlytics = sl<CrashlyticsService>();
await crashlytics.setCollectionEnabled(true);
await crashlytics.sendTestReport();
```

### Step 2: Observe Logcat Output
```
D/FirebaseCrashlytics: Logging non-fatal event: CSE JnU EduPortal Controlled Crashlytics Verification Event
D/FirebaseCrashlytics: Tags recorded: test_event=true, diagnostics=verified
```

### Step 3: Verify in Firebase Console
1. Open [Firebase Console](https://console.firebase.google.com/) > **Crashlytics**.
2. Filter by **Event type: Non-fatals**.
3. Locate the event titled:
   `StateError: CSE JnU EduPortal Controlled Crashlytics Verification Event`
4. Verify attached keys:
   - `build_mode: debug`
   - `platform: android`
   - `diagnostics: verified`
5. Verify that **NO** user email, student name, password, or token appears in the logs or keys.

---

## 4. Google Cloud Functions Telemetry Inspection

To view structured diagnostics in Google Cloud Logging:
1. Open [Google Cloud Console](https://console.cloud.google.com/) > **Logging** > **Logs Explorer**.
2. Run query:
   ```
   resource.type="cloud_function"
   jsonPayload.severity=("ERROR" OR "WARNING" OR "NOTICE")
   ```
3. Verify structured JSON entries contain:
   - `operation`: e.g. `startAttendanceSession`
   - `category`: e.g. `AUTHORIZATION`
   - `errorCode`: e.g. `permission-denied`
   - `context.uid`: opaque UID (e.g. `teacher_123`)
   - `details.courseId`: e.g. `CSE-3101`
4. Confirm email masking: `s***@jnu.ac.bd`.

---

## 5. Automated Test Suite Execution

### Mobile Tests (Flutter):
```bash
cd mobile
flutter test test/core/monitoring/crashlytics_service_test.dart
```
**Result**: 10 tests passing.

```bash
cd mobile
flutter test
```
**Result**: 371 tests passing.

### Backend Tests (Node.js/TypeScript):
```bash
cd functions
npm run build && node --test lib/monitoring.test.js
```
**Result**: 5 tests passing.

```bash
cd functions
npm test
```
**Result**: 135 tests passing.
