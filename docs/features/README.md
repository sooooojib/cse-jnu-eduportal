# Feature Specifications

## 1. Feature Map & Epics

The **CSE JnU EduPortal** comprises 8 core feature epics (F08, Chairman & Department Oversight, is listed below the map):

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CSE JnU EduPortal Epics                         │
├─────────────────┬─────────────────┬──────────────────┬─────────────────┤
│ F01: AUTH &     │ F02: SEMESTER   │ F03: SCHEDULE &  │ F04: DYNAMIC    │
│ ONBOARDING      │ PROGRESSION     │ ROUTINE DISPATCH │ ATTENDANCE      │
├─────────────────┼─────────────────┼──────────────────┼─────────────────┤
│ F05: COUNSELING │ F06: FEEDBACK & │ F07: ADMIN &     │                 │
│ OFFICE HOURS    │ REVIEWS         │ COURSE DIRECTORY │                 │
└─────────────────┴─────────────────┴──────────────────┴─────────────────┘
```

---

## 2. Feature Epics & User Stories

### Epic F01: Authentication & Onboarding
- **US-01**: As a Student or CR, I want to request a portal account by providing my Name, Email, and Student ID so that the administration can verify and approve my enrollment.
- **US-02**: As a Professor, I want to request access using my Name, Email, and Phone Number.
- **US-03**: As an Administrator, I want a dedicated moderation queue to approve signups, which automatically creates accounts, generates initial credentials, and emails the user.
- **US-04**: As an Authenticated User, I want to sign in with my credentials and securely maintain session state via JWT tokens.

### Epic F02: Semester Lifecycle Management
- **US-05**: As a Student, I want to see my active Year and Semester (e.g. 3rd Year · 1st Semester) across all dashboard metrics.
- **US-06**: As a Student, I want to submit a semester upgrade request when advancing to the next term.
- **US-07**: As an Administrator, I want to review, approve, or reject student semester petitions with audit feedback.

### Epic F03: Daily Schedule & Routine Dispatch
- **US-08**: As a Student, I want to view today's class timetable and upcoming exam dates.
- **US-09**: As a CR, I want to schedule class slots for tomorrow for my batch and broadcast a formatted summary to WhatsApp in one tap.
- **US-10**: As a Professor, I want my dashboard to automatically highlight Today's schedule during working hours and Tomorrow's schedule in the evening.

### Epic F04: Dynamic Attendance Terminal
- **US-11**: As a Professor, I want to open an attendance session that generates a large 6-character verification code in an Obsidian Terminal.
- **US-12**: As a Student, I want to enter the 6-character code in my app to record my attendance instantly.
- **US-13**: As a Professor, I want to view the live roster and manually toggle individual student statuses.
- **US-14**: As a CR / Teacher, I want to export departmental Excel attendance sheets.

### Epic F05: Faculty Counseling & Office Hours
- **US-15**: As a Professor, I want to declare office hour slots with date and time ranges.
- **US-16**: As a Student, I want to browse open slots and request an appointment by selecting a reason category (e.g., Academic Advising, Career Guidance, Thesis).
- **US-17**: As a Professor, I want to approve a student's request, which automatically confirms the slot and politely declines other competing requests.

### Epic F06: Confidential Feedback & Quality Assurance
- **US-18**: As a Student, I want to submit 1-5 star ratings and written reviews for my course teachers with the option to remain completely anonymous.
- **US-19**: As a Professor, I want to read constructive feedback from students (with identities protected when anonymous) and post threaded responses.

### Epic F07: Admin Control & Course Directory
- **US-20**: As an Administrator, I want to search and manage departmental user records across all 4 roles.
- **US-21**: As an Administrator, I want to assign courses to faculty members.

### Epic F08: Chairman & Department Oversight
- **US-22**: As a Student or CR, I want to select my academic Session (e.g. 2021-2022) when requesting an account so my batch is clear to the approver.
- **US-23**: As an approver, I want to see the applicant's Session (fixed as chosen at signup) and pick their current semester myself. Nothing is guessed, because of session jams and students who take longer. A wrong session is corrected later from the User Directory.
- **US-24**: As the Chairman, I want every faculty capability (classes, attendance, counseling, feedback) and departmental admin capability in one account.
- **US-25**: As the Chairman, I want a Faculty View / Department Admin switch directly under my dashboard welcome header.
- **US-26**: As the Chairman, I want to see how many classes each teacher has held per course, their syllabus progress, student turnout, and estimated missed routine classes.
- **US-27**: As the Chairman or Admin, I want to grant individual faculty members signup committee access so they can review Student / CR registrations.
- Details: [chairman_and_department_oversight.md](chairman_and_department_oversight.md) · Permissions: [role_matrices.md](role_matrices.md)

---

## 3. Offline & Connectivity Profiles by Feature (Stage 31)

| Feature Epic | Offline Read Capability | Offline Write / Mutation | Authoritative Live Server Requirement |
| :--- | :---: | :---: | :--- |
| **F01: Auth & Onboarding** | ⚠️ Session restore from secure storage | ❌ Disabled | **Required** for login, signup request submission, and credential provisioning. |
| **F02: Semester Progression** | ✅ View current status & past petitions | ❌ Disabled | **Required** for submitting or approving semester upgrade petitions. |
| **F03: Schedule & Exams** | ✅ Full offline access to routines & exams | ❌ Disabled | **Required** for creating or updating class slots or exam dates. |
| **F04: Dynamic Attendance** | ✅ View attendance summary & history | ❌ Disabled | **Strictly Required** for code verification, session start, and roster overrides. |
| **F05: Counseling Hours** | ✅ View previously loaded slots & appointments | ❌ Disabled | **Strictly Required** for booking requests, slot creation, and faculty approvals. |
| **F06: Feedback & Reviews** | ✅ View previously loaded feedback & replies | ❌ Disabled | **Required** for submitting evaluations and posting faculty replies. |
| **F07: Admin & Directory** | ✅ View cached statistics, courses & users | ❌ Disabled | **Strictly Required** for user provisioning, course assignment, and notice broadcast. |

---

## 4. App Attestation & Security Gating (Stage 32)

Every production client request to Cloud Firestore, Cloud Storage, and Cloud Functions is attested by **Firebase App Check**:
- **Android**: Google Play Integrity API (`AndroidProvider.playIntegrity`).
- **iOS / macOS**: Apple App Attest with DeviceCheck Fallback (`AppleProvider.appAttestWithDeviceCheckFallback`).
- **Development / Debug**: Debug tokens registered in Firebase Console (`AndroidProvider.debug`).
- **Backend Protection**: Cloud Functions verify `request.app.appId` with staged enforcement (`verifyAppCheck` in `functions/src/appcheck.ts`).
- **Architecture Documentation**: [docs/architecture/firebase_app_check.md](../architecture/firebase_app_check.md).
- **Verification Testing Protocol**: [docs/testing/app_check_testing.md](../testing/app_check_testing.md).

---

## 5. Production Observability & Crash Monitoring (Stage 33)

Production health and diagnostic telemetry are monitored across client and server:
- **Mobile Client**: **Firebase Crashlytics** (`CrashlyticsService` in `mobile/lib/core/monitoring/crashlytics_service.dart`).
- **Error Pipeline**: Captures Flutter framework layout errors (`FlutterError.onError`), unhandled asynchronous errors (`PlatformDispatcher.onError`), and non-fatal exceptions (`AppLogger.e`).
- **Privacy Compliance**: Strict zero-leakage automated sanitization via `CrashlyticsContextSanitizer` (redacting passwords, tokens, API keys, phone numbers, emails, and feedback comments).
- **Cloud Functions**: Structured JSON telemetry via `StructuredLogger` (`functions/src/monitoring.ts`) with failure categorization and security audit logging.
- **Architecture Documentation**: [docs/architecture/crashlytics_monitoring.md](../architecture/crashlytics_monitoring.md).
- **Verification Testing Protocol**: [docs/testing/crashlytics_testing.md](../testing/crashlytics_testing.md).

---

## 6. Comprehensive Security Posture (Stage 34)

Full zero-trust security audit and adversarial penetration testing:
- **Zero-Trust Client Boundary**: The Flutter application is treated as completely untrusted; all authorization, cohort isolation, and field immutability are enforced by Cloud Firestore Security Rules, Cloud Storage Security Rules, and Cloud Functions transactions.
- **Vulnerabilities Fixed**:
  - Direct attendance manipulation locked down (students cannot update records or alter attendance status).
  - User profile update whitelisted (prevents privilege escalation to CR or modification of active/enrollment claims).
  - Schedule spoofing eliminated (`creatorRole` client spoofing removed).
  - Counseling self-approval prevented (students restricted to cancellation only).
  - Anonymous feedback privacy preserved (student UIDs masked to `ANONYMOUS` in teacher queries and storage metadata).
- **Security Audit Documentation**: [docs/testing/security_audit.md](../testing/security_audit.md).




