# Firebase Security Architecture & Threat Model
## CSE JnU EduPortal — Stage 11 Security Specification

---

## 1. Core Security Tenets

The **CSE JnU EduPortal** adheres to a strict **Zero-Trust Client** security model:

1. **The Client is Untrusted**: Flutter client code runs on user-controlled hardware. Any client-side check can be modified or bypassed. Therefore, **zero authorization logic relies exclusively on Flutter**.
2. **Security Rules as the Primary Perimeter**: Cloud Firestore and Cloud Storage Security Rules form the authoritative gatekeeper for all direct read and write operations.
3. **Cloud Functions as the Trusted Broker**: Any operation that requires multi-document transactional integrity, elevated privileges (e.g., Firebase Admin SDK), or cryptographic detachment (e.g., anonymous feedback queries) MUST be executed within a trusted Cloud Function.
4. **App Attestation via App Check**: Protects Firebase backend resources from abuse, bots, and unauthorized scripts by verifying that incoming traffic originates from the authentic, unmodified mobile binary.

---

## 2. Authentication & Identity Management

### 2.1 Identity Lifecycle
- **Identity Provider**: Firebase Authentication (Email/Password provider).
- **UID Authority**: Every verified account receives an immutable 28-character Firebase UID (`request.auth.uid`).
- **Account Creation**: Strictly gated behind Admin approval. The public registration flow writes to a staging collection (`signupRequests`) without issuing an active Firebase Auth account. Only the `approveSignupRequest` Cloud Function invokes `admin.auth().createUser()`.
- **Session Tokens**: Handled automatically by the Firebase Auth SDK. ID tokens (JWTs) have a 1-hour validity and are silently rotated using persistent refresh tokens managed securely on the device.

### 2.2 Role-Based Access Control (RBAC) Architecture
Roles are declared in two synchronized locations:
1. **Firestore User Document**: `/users/{uid}.role` (Primary data store for UI consumption).
2. **Firebase Auth Custom Claims**: `{ "role": "STUDENT" | "CR" | "TEACHER" | "ADMIN", "year": 3, "semester": 1 }` (Embedded in ID tokens for zero-cost Security Rules checks).

```
┌────────────────────────────────────────────────────────────────────────┐
│                        RBAC Permission Matrix                          │
├───────────────────┬──────────────┬──────────────┬──────────────┬───────┤
│ Resource / Scope  │ STUDENT      │ CR           │ TEACHER      │ ADMIN │
├───────────────────┼──────────────┼──────────────┼──────────────┼───────┤
│ User Directory    │ Self Profile │ Self Profile │ Department   │ Full  │
│ Signup Requests   │ Create Only  │ Create Only  │ None         │ Full  │
│ Courses (Catalog) │ Read (Batch) │ Read (Batch) │ Read (All)   │ Full  │
│ Schedule Slots    │ Read (Batch) │ Write (Tmrw) │ Read (Taught)│ Full  │
│ Attendance Session│ None         │ None         │ Manage (Own) │ Full  │
│ Attendance Record │ Verify (Self)│ Verify (Self)│ Overrides    │ Full  │
│ Counseling Slots  │ Read         │ Read         │ Manage (Own) │ Full  │
│ Counseling Booking│ Petitions    │ Petitions    │ Approve/Deny │ Full  │
│ Feedback Review   │ Submit (Own) │ Submit (Own) │ Read/Reply   │ Audit │
│ Semester Upgrade  │ Petition     │ Petition     │ None         │ Full  │
│ Storage: Avatars  │ Write (Own)  │ Write (Own)  │ Write (Own)  │ Full  │
│ Storage: Feedback │ Write (Own)  │ Write (Own)  │ Write (Reply)│ Full  │
└───────────────────┴──────────────┴──────────────┴──────────────┴───────┘
```

---

## 3. Cloud Firestore Security Rules Structure

Security Rules enforce data isolation, immutability, and schema constraints.

### 3.1 Helper Functions
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Authentication Checks
    function isAuthenticated() {
      return request.auth != null;
    }
    function isUser(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }
    
    // Role Checks via Custom Claims
    function hasRole(role) {
      return isAuthenticated() && request.auth.token.role == role;
    }
    function isAdmin() {
      return hasRole('ADMIN');
    }
    function isTeacher() {
      return hasRole('TEACHER') || isAdmin();
    }
    function isCR() {
      return hasRole('CR');
    }
    function isStudent() {
      return hasRole('STUDENT') || isCR();
    }

    // Batch validation
    function matchesStudentBatch(year, semester) {
      return isAuthenticated() && 
        request.auth.token.year == year && 
        request.auth.token.semester == semester;
    }
  }
}
```

### 3.2 Collection-by-Collection Security Rules Strategy
1. **`/users/{uid}`**:
   - `read`: Authenticated users can read their own profile; Teachers and Admins can read student profiles for directory and attendance roster purposes.
   - `write`: Only `ADMIN` or trusted Cloud Functions. Students cannot modify their assigned `role`, `year`, or `semester` directly.
2. **`/signupRequests/{requestId}`**:
   - `create`: Public unauthenticated write allowed with schema validation (must have `status == 'PENDING'`).
   - `read, update, delete`: Restricted to `ADMIN` only.
3. **`/courses/{courseId}`**:
   - `read`: Authenticated users.
   - `write`: `ADMIN` only.
4. **`/schedules/{slotId}`**:
   - `read`: Authenticated users.
   - `create, update, delete`: `ADMIN`, or `CR` specifically when modifying tomorrow's schedule slots.
5. **`/attendanceSessions/{sessionId}`**:
   - `read`: Authenticated users enrolled in the course or assigned teachers.
   - `write`: `TEACHER` assigned to the course, or `ADMIN`.
6. **`/attendance/{recordId}`**:
   - `read`: Student can read their own records (`resource.data.studentId == request.auth.uid`); Teachers can read records for sessions of courses they teach.
   - `create`: Student submitting attendance with matching `studentId == request.auth.uid` during an active session.
   - `update, delete`: `TEACHER` (manual override audit) or `ADMIN`.
7. **`/counselingSlots/{slotId}`**:
   - `read`: Authenticated users.
   - `write`: `TEACHER` owning the slot (`resource.data.teacherId == request.auth.uid`).
8. **`/counselingBookings/{bookingId}`**:
   - `read`: Applicant student (`studentId == request.auth.uid`) or target teacher (`teacherId == request.auth.uid`).
   - `create`: Authenticated student creating a petition with `status == 'PENDING'`.
   - `update`: Handled atomically via Cloud Function `approveCounselingBooking`.
9. **`/feedback/{feedbackId}`**:
   - `create`: Student submitting review with `studentId == request.auth.uid`.
   - `read`: Author student or target teacher (with anonymity enforcement) or Admin (audit).
10. **`/notifications/{notificationId}`**:
    - `read, update`: Target user (`resource.data.userId == request.auth.uid`).
    - `create`: Cloud Functions only.

---

## 4. Cloud Storage Security Rules

Storage buckets are strictly partitioned with MIME type validation, file size limits, and access controls.

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    function isAuthenticated() {
      return request.auth != null;
    }
    function isOwner(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }
    function isValidImage() {
      return request.resource.contentType.matches('image/(jpeg|png|webp)') &&
             request.resource.size < 5 * 1024 * 1024; // 5MB max
    }
    function isValidAttachment() {
      return (request.resource.contentType.matches('image/(jpeg|png|webp)') ||
              request.resource.contentType == 'application/pdf' ||
              request.resource.contentType == 'text/plain') &&
             request.resource.size < 10 * 1024 * 1024; // 10MB max
    }

    // User Profile Avatars
    match /avatars/{userId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId) && isValidImage();
    }

    // Feedback & Counseling Attachments
    match /attachments/{userId}/{attachmentId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId) && isValidAttachment();
    }
  }
}
```

---

## 5. Firebase App Check Protection

App Check attests that all API and Firestore traffic originates from an authentic build of the CSE JnU EduPortal mobile app, preventing scraped API calls, automated DDoS, or rogue SDK clients.

### 5.1 Attestation Providers
- **Android**: **Play Integrity API** (Production) / Debug Token (Development).
- **iOS**: **DeviceCheck** / **App Attest** (Production) / Debug Token (Development).
- **Web / Emulators**: **reCAPTCHA Enterprise** or Debug Provider.

### 5.2 Enforcement Boundaries
App Check is strictly enforced on:
1. Cloud Firestore
2. Cloud Storage
3. Cloud Functions (Callable endpoints reject requests without a valid App Check token)

---

## 6. Feedback Anonymity Architecture (BR-FEED in Firebase)

In a relational PostgreSQL architecture, a custom SQL query would strip `student_id` before transmitting JSON to professors. In Firebase:

```
[ Student Submits Feedback ]
        │
        ├── isAnonymous: true
        │
        ▼
[ Firestore: /feedback/{feedbackId} ]
        ├── studentId: "ANONYMOUS"  (Client write)
        ├── realStudentIdHash: "<HMAC-SHA256(uid, secret)>"  (For Admin audit only)
        ├── teacherId: "teacher_uid"
        ├── rating: 5
        └── comments: "Great lecture on Process Synchronization!"
```

1. **Professor View**: Security Rules and Firestore queries retrieve the document directly. Because `studentId` is literally stored as `"ANONYMOUS"`, there is zero risk of client inspection exposing the student's true UID.
2. **Admin Audit View**: In case of severe institutional policy violations, the `realStudentIdHash` can be resolved via an Admin-only Cloud Function that checks against the student audit registry.

---

## 7. Crash Reporting, Audit Logs & Monitoring

1. **Firebase Crashlytics**:
   - Real-time logging of uncaught Dart exceptions and native crash events.
   - Non-fatal errors logged via `FirebaseCrashlytics.instance.recordError()`.
   - Custom keys attached: `user_role`, `active_semester`, `app_version`.
   - Sensitive student identification (PII) is **never** sent to Crashlytics logs.
2. **Cloud Functions Security Audit Logging**:
   - Critical operations (`approveSignupRequest`, `approveSemesterUpgrade`, `approveCounselingBooking`, manual attendance overrides) write structured audit entries to Google Cloud Logging.
   - Retention policy configured for 365 days for university compliance.
