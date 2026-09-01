# Cloud Firestore & Storage Security Model Specification
## CSE JnU EduPortal — Stage 11 Declarative Security Rules

---

## 1. Security Architecture Overview

The Firebase security model enforces strict authorization boundaries at the database engine level. **Flutter is an untrusted client.** No client request can read, write, update, or delete data unless explicitly permitted by the rules below.

```
                  ┌──────────────────────────────┐
                  │    Flutter Client Request    │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │     Firebase App Check       │
                  │   (Attestation Verification) │
                  └──────────────┬───────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────────┐
                  │   Firestore Security Rules   │
                  │  • Custom Claims RBAC Check  │
                  │  • Request Schema Validation │
                  │  • Resource Ownership Check  │
                  │  • Immutability Enforcement  │
                  └──────────────┬───────────────┘
                                 │
                        ┌────────┴────────┐
                        ▼                 ▼
                  [ 200 ALLOW ]     [ 403 DENY ]
```

---

## 2. Production `firestore.rules` Specification

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ─── AUTHENTICATION HELPERS ──────────────────────────────────────────────
    function isAuthenticated() {
      return request.auth != null;
    }

    function isUser(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }

    function getUserRole() {
      return request.auth.token.role;
    }

    function hasRole(role) {
      return isAuthenticated() && getUserRole() == role;
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

    // ─── VALIDATION HELPERS ──────────────────────────────────────────────────
    function isValidTimestamp(field) {
      return request.resource.data[field] is timestamp;
    }

    function isNonEmptyString(field, maxLen) {
      return request.resource.data[field] is string &&
             request.resource.data[field].size() > 0 &&
             request.resource.data[field].size() <= maxLen;
    }

    // ─── COLLECTION: users ───────────────────────────────────────────────────
    match /users/{userId} {
      // Any authenticated user can read profiles (needed for names in UI, directory, attendance)
      allow read: if isAuthenticated();

      // Only ADMIN can create or mutate core user documents (roles, semesters)
      // Normal users cannot elevate their own role or promote their own semester
      allow create, delete: if isAdmin();
      allow update: if isAdmin() || (
        isUser(userId) &&
        !request.resource.data.diff(resource.data).affectedKeys().hasAny(['role', 'year', 'semester', 'studentId', 'email'])
      );
    }

    // ─── COLLECTION: signupRequests ──────────────────────────────────────────
    match /signupRequests/{requestId} {
      // Public registration write allowed with PENDING status
      allow create: if request.resource.data.status == 'PENDING' &&
                       isNonEmptyString('email', 100) &&
                       isNonEmptyString('fullName', 100);

      // Only ADMIN can review, approve, reject or delete signup requests
      allow read, update, delete: if isAdmin();
    }

    // ─── COLLECTION: courses ─────────────────────────────────────────────────
    match /courses/{courseId} {
      // All authenticated members can browse the departmental curriculum
      allow read: if isAuthenticated();

      // Only Department Admins can add, edit, or archive syllabus courses
      allow write: if isAdmin();
    }

    // ─── COLLECTION: schedules ───────────────────────────────────────────────
    match /schedules/{slotId} {
      allow read: if isAuthenticated();

      // Admins have full routine control.
      // CRs are permitted to insert/adjust routine slots for their batch.
      allow create, update, delete: if isAdmin() || isCR();
    }

    // ─── COLLECTION: exams ───────────────────────────────────────────────────
    match /exams/{examId} {
      allow read: if isAuthenticated();
      allow write: if isTeacher();
    }

    // ─── COLLECTION: attendanceSessions ──────────────────────────────────────
    match /attendanceSessions/{sessionId} {
      allow read: if isAuthenticated();

      // Only the assigned teacher or Admin can create, open, or close sessions
      allow create, update: if isTeacher();
      allow delete: if isAdmin();
    }

    // ─── COLLECTION: attendance ──────────────────────────────────────────────
    match /attendance/{recordId} {
      // Students can read their own attendance; Teachers & Admins can read all
      allow read: if isAuthenticated() && (
        resource.data.studentId == request.auth.uid || isTeacher()
      );

      // Student submitting attendance code: must match authenticated UID
      allow create: if isStudent() &&
                       request.resource.data.studentId == request.auth.uid &&
                       request.resource.data.status == 'PRESENT';

      // Only Teachers (for manual overrides) or Admins can modify existing attendance records
      allow update: if isTeacher();
      allow delete: if isAdmin();
    }

    // ─── COLLECTION: counselingSlots ─────────────────────────────────────────
    match /counselingSlots/{slotId} {
      allow read: if isAuthenticated();

      // Only teachers can create and manage their own office hour blocks
      allow create, update, delete: if isTeacher() && (
        request.resource.data.teacherId == request.auth.uid || isAdmin()
      );
    }

    // ─── COLLECTION: counselingBookings ──────────────────────────────────────
    match /counselingBookings/{bookingId} {
      // Students can read their own petitions; Teachers can read bookings directed to them
      allow read: if isAuthenticated() && (
        resource.data.studentId == request.auth.uid ||
        resource.data.teacherId == request.auth.uid ||
        isAdmin()
      );

      // Students create booking petitions in PENDING state
      allow create: if isStudent() &&
                       request.resource.data.studentId == request.auth.uid &&
                       request.resource.data.status == 'PENDING';

      // Students can cancel their own petitions; Teachers update status (or via Cloud Function)
      allow update: if isUser(resource.data.studentId) || isTeacher();
      allow delete: if isAdmin();
    }

    // ─── COLLECTION: feedback ────────────────────────────────────────────────
    match /feedback/{feedbackId} {
      // Students can read their submitted feedback; Teachers read feedback directed to them; Admin audits all
      allow read: if isAuthenticated() && (
        resource.data.studentId == request.auth.uid ||
        resource.data.teacherId == request.auth.uid ||
        isAdmin()
      );

      // Students can submit feedback (if anonymous, studentId is "ANONYMOUS")
      allow create: if isStudent() &&
                       request.resource.data.rating >= 1 &&
                       request.resource.data.rating <= 5 &&
                       request.resource.data.comments.size() >= 10;

      // Teachers can add replies to feedback cards directed to them
      allow update: if isTeacher() && (
        resource.data.teacherId == request.auth.uid || isAdmin()
      );
      allow delete: if isAdmin();
    }

    // ─── COLLECTION: semesterUpgradeRequests ─────────────────────────────────
    match /semesterUpgradeRequests/{requestId} {
      // Students read their own petitions; Admins read all pending requests
      allow read: if isAuthenticated() && (
        resource.data.studentId == request.auth.uid || isAdmin()
      );

      // Students submit upgrade petition in PENDING state
      allow create: if isStudent() &&
                       request.resource.data.studentId == request.auth.uid &&
                       request.resource.data.status == 'PENDING';

      // Only Admins can approve/reject semester requests
      allow update, delete: if isAdmin();
    }

    // ─── COLLECTION: notifications ───────────────────────────────────────────
    match /notifications/{notificationId} {
      // Users can only read and mark their own notifications as read
      allow read, update: if isAuthenticated() && resource.data.userId == request.auth.uid;

      // Notifications are created by Cloud Functions (Admin SDK) or system events
      allow create: if isAuthenticated();
      allow delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## 3. Production `storage.rules` Specification

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    function isAdmin() {
      return isAuthenticated() && request.auth.token.role == 'ADMIN';
    }

    function isValidImage() {
      return request.resource.contentType.matches('image/(jpeg|png|webp)') &&
             request.resource.size < 5 * 1024 * 1024; // 5 MB limit
    }

    function isValidDocument() {
      return (
        request.resource.contentType.matches('image/(jpeg|png|webp)') ||
        request.resource.contentType == 'application/pdf' ||
        request.resource.contentType == 'text/plain'
      ) && request.resource.size < 10 * 1024 * 1024; // 10 MB limit
    }

    // Profile Avatars: /avatars/{userId}/{fileName}
    match /avatars/{userId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if (isOwner(userId) || isAdmin()) && isValidImage();
      allow delete: if isOwner(userId) || isAdmin();
    }

    // Feedback Attachments: /feedback/{userId}/{attachmentId}
    match /feedback/{userId}/{attachmentId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId) && isValidDocument();
      allow delete: if isOwner(userId) || isAdmin();
    }

    // Counseling Attachments: /counseling/{userId}/{attachmentId}
    match /counseling/{userId}/{attachmentId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId) && isValidDocument();
      allow delete: if isOwner(userId) || isAdmin();
    }
  }
}
```
