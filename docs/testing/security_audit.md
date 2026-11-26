# Comprehensive Security Audit Report
## CSE JnU EduPortal — Stage 34

---

## 1. Executive Summary & Threat Model

This comprehensive security audit assesses the security posture of **CSE JnU EduPortal** under an adversarial threat model where the Flutter mobile client is **completely untrusted**:
- Attackers can reverse-engineer or recompile the APK
- Attackers can inspect, replay, or forge network traffic
- Attackers can invoke Firebase APIs and Cloud Functions directly via SDKs/REST
- Attackers can manipulate client-side identifiers, headers, and request bodies
- Attackers can attempt privilege escalation across all roles (**STUDENT**, **CR**, **TEACHER**, **ADMIN**)

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Zero-Trust Security Matrix                      │
├───────────────────────┬────────────────────────────────────────────────┤
│ Perimeter Firewall    │ Firebase App Check (Google Play Integrity)     │
│ Identity Gateway      │ Firebase Auth (UID & RBAC Custom Claims)       │
│ Data Security Rules   │ Cloud Firestore & Cloud Storage Security Rules │
│ Server Execution Core │ 2nd Gen Cloud Functions (Atomic Transactions)  │
│ Privacy Guard         │ Feedback Anonymity & PII Diagnostic Redaction  │
└───────────────────────┴────────────────────────────────────────────────┘
```

---

## 2. Discovered Vulnerabilities & Remediations Applied

| Vuln ID | Severity | Affected Feature | Attack Vector & Evidence | Remediation Applied | Status |
|:---|:---:|:---|:---|:---|:---:|
| **VULN-01** | **CRITICAL** | Dynamic Attendance | `firestore.rules` allowed students with `resource.data.studentId == request.auth.uid` to directly update `/attendance/{recordId}`, enabling students marked `ABSENT` to override their status to `PRESENT`. Direct creates also lacked session existence checks. | Completely removed student update permissions (`allow update: if isTeacher()`). Locked direct creates to canonical docId `${sessionId}_${uid}` with active, non-expired session checks. | **VERIFIED & FIXED** |
| **VULN-02** | **HIGH** | User Profiles & RBAC | Blacklist in `users/{userId}` update rule (`!affectedKeys().hasAny(...)`) omitted `isCR`, `isActive`, and `assignedCourseIds`, allowing students to escalate privileges to CR or modify course claims. | Replaced blacklist with a strict whitelist (`affectedKeys().hasOnly(['fullName', 'phone', 'avatarUrl', 'fcmTokens', 'updatedAt', 'bio', 'officeRoom'])`). | **VERIFIED & FIXED** |
| **VULN-03** | **HIGH** | Daily Schedules | `firestore.rules` allowed creation if `request.resource.data.creatorRole == 'CR'`, enabling any student to spoof CR privileges and modify schedules by injecting `creatorRole: 'CR'`. | Removed client-supplied role check. Required authoritative role evaluation (`isAdmin() \|\| isTeacher() \|\| isCR()`). | **VERIFIED & FIXED** |
| **VULN-04** | **HIGH** | Attendance Sessions | `firestore.rules` permitted create if `request.resource.data.teacherId == request.auth.uid` and update if `isActive == false`, allowing students to forge sessions or close professor sessions. | Restricted create to `isTeacher() \|\| isAdmin()`. Restricted updates to session owners or increment-only during active sessions. | **VERIFIED & FIXED** |
| **VULN-05** | **MEDIUM** | Faculty Counseling | `counselingBookings` update rule lacked field constraints for students, allowing students to set `status: 'APPROVED'` on their own appointment petitions. | Restricted student updates strictly to `status: 'CANCELLED'`. Approvals require assigned teacher or admin. | **VERIFIED & FIXED** |
| **VULN-06** | **MEDIUM** | In-App Notifications | `notifications/{id}` allowed `create: if isAuthenticated()`, allowing any user to broadcast arbitrary or phishing notifications to other students or faculty. | Restricted notification creation to `isAdmin()`, authorized teachers, or server-side Cloud Functions Admin SDK. | **VERIFIED & FIXED** |
| **VULN-07** | **LOW** | Storage & Feedback Privacy | Storage rule for feedback attachments required `uploadedBy == request.auth.uid`, exposing student UIDs in metadata for anonymous evaluations. | Permitted `metadata.uploadedBy == 'ANONYMOUS'` for feedback attachments. | **VERIFIED & FIXED** |

---

## 3. Detailed Audit by Category

### 3.1 Authentication & Session Security
- **Identity Lifecycle**: Accounts are issued exclusively by Administrators via `approveSignupRequest` or `createAdminUser`. Public signups write to `signupRequests` (pending review) with zero access to Firebase Auth.
- **Deactivated Accounts**: When an admin disables a user (`isActive: false`), Cloud Functions and client guards (`AuthoritativeGuard`) block access immediately.
- **Session Tokens**: JWT ID tokens expire in 60 minutes and cannot be forged. Custom claims (`role`, `year`, `semester`) are cryptographically signed by Google.
- **Password Reset**: Executed via Firebase Auth with official email action links; no plain passwords stored in Firestore.

### 3.2 Role-Based Access Control (RBAC)
- **Matrix Validation**:
  - `STUDENT`: Read self profile, read enrolled batch schedules/courses, submit attendance via valid 6-char code, request counseling, submit feedback. Cannot modify directory, schedules, or session rosters.
  - `CR`: Extends Student with permission to declare tomorrow's schedule slots and broadcast routines. Cannot alter attendance or approve upgrades.
  - `TEACHER`: Manages assigned courses, creates attendance sessions, executes overrides on session rosters, manages counseling slots, replies to student feedback.
  - `ADMIN`: Full administrative sovereignty over user provisioning, role assignments, semester progression, course creation, and audit logs.

### 3.3 Dynamic Attendance Verification Engine
- **Attack Simulation (Code Forgery & Brute Force)**:
  - Verification codes use a 30-character unambiguous charset (`23456789ABCDEFGHJKLMNPQRSTUVWXYZ`), yielding $30^6 \approx 729,000,000$ combinations.
  - Codes are valid for a default 15-minute window.
  - Submissions are executed inside atomic Firestore transactions with composite locking key `${sessionId}_${studentUid}`.
  - Duplicate submissions and expired/inactive submissions are strictly blocked.

### 3.4 Anonymous Feedback Privacy Architecture
- **Zero-Knowledge Guarantee**:
  - In `feedback/{feedbackId}`, when `isAnonymous == true`, `studentId` is literally `"ANONYMOUS"`, `studentName` is `"Anonymous Student"`, and `studentEmail` is `null`.
  - True student identity is partitioned into `feedbackIdentities/{feedbackId}`.
  - Security Rules strictly block teachers from reading `feedbackIdentities` (`allow read: if resource.data.studentId == request.auth.uid || isAdmin()`).
  - Storage attachments allow `uploadedBy: 'ANONYMOUS'` to eliminate metadata leakage.

### 3.5 Cloud Storage Security Rules
- **Path Traversal Protection**: Paths outside `/notices/`, `/avatars/`, `/feedback/`, and `/counseling/` are denied by default (`match /{allPaths=**} { allow read, write: if false; }`).
- **File Validation**:
  - Avatars: Images only (`image/(jpeg|png|webp)`), max size $\le 5\text{MB}$.
  - Documents: PDF, Plain Text, Word documents, max size $\le 10\text{MB}$.
  - Executable scripts (`.exe`, `.sh`, `.apk`, `.js`) are strictly denied at the storage boundary.

### 3.6 Data Leakage & Telemetry Sanitization
- Both client ([CrashlyticsContextSanitizer](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core/monitoring/crashlytics_service.dart)) and server ([DiagnosticSanitizer](file:///Users/sajib/Desktop/CSE_DEPT/functions/src/monitoring.ts)) purge:
  - Passwords and plain credentials
  - Bearer tokens and JWTs
  - Student phone numbers and unmasked emails
  - Student comments in feedback evaluations

---

## 4. Retest & Verification Results

### Backend Functions & Adversarial Test Suite
```bash
cd functions && npm test
```
- **140 / 140 backend tests passed** (including 5 adversarial attack tests in `security_audit.test.ts`).

### Mobile Client Test Suite
```bash
cd mobile && flutter test
```
- **371 / 371 Flutter tests passed** (0 regressions).

---

## 5. Unresolved Residual Risks

1. **Physical Device Tampering in Exam Rooms**: If a student in a lecture hall shares the 6-character code via text to absent peers outside the room within the 15-minute window, the absent student could record attendance.
   - *Mitigation*: The professor terminal displays live attendance headcount in real time and provides one-tap **Mark All Absent** and individual roster overrides to audit the room against the roster count.
2. **App Check Play Integrity Enrollment**: Full hardware-level enforcement requires registering the production SHA-256 fingerprint in the Google Play Console prior to toggling strict enforcement. Currently in Audit/Monitor mode.
