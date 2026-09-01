# Firebase Service Mapping Architecture
## CSE JnU EduPortal — Stage 11 Legacy Component Transition

---

## 1. System Component Transition Matrix

This document maps every component from the previous **Node.js + PostgreSQL + REST API** architecture to its direct replacement in the **Firebase Platform Architecture**.

| Legacy Architecture Component | Previous Implementation | Firebase Modern Equivalent | Rationale & Architectural Benefit |
|:---|:---|:---|:---|
| **Identity & Authentication** | Custom bcrypt/Argon2 hashing + Express `/auth/login` endpoint | **Firebase Authentication** | Eliminates manual credential hashing, secure token storage, and custom refresh token rotation. |
| **Token Issuance & Refresh** | Custom 15-min JWT access token + 7-day refresh token | **Firebase ID Tokens & Refresh Tokens** | Native SDK handles token refreshing transparently with zero network interceptor boilerplate. |
| **Database Storage** | PostgreSQL 16 Relational Engine | **Cloud Firestore** | Serverless NoSQL document database with built-in real-time document listeners, offline persistence, and horizontal auto-scaling. |
| **Data Access Layer** | Custom SQL / Prisma ORM Repository Pattern | **Cloud Firestore Client SDK + Security Rules** | Direct client querying from Flutter with database-level security enforcement; removes REST controllers. |
| **Role-Based Access Control** | Express RBAC Middleware (`authorize(['ADMIN'])`) | **Firestore Security Rules + Firebase Auth Custom Claims** | Declarative, sub-millisecond permission checks evaluated at the edge without server cold-starts. |
| **Account Provisioning** | Express `/admin/signup-requests/:id/approve` + SQL transaction | **Cloud Function `approveSignupRequest` (onCall)** | Uses Firebase Admin SDK to provision Auth users, write Firestore profiles, and issue welcome emails atomically. |
| **Counseling Booking Mutual-Exclusion** | Serializable SQL transaction with row-level locks (`SELECT FOR UPDATE`) | **Cloud Function `approveCounselingBooking` (onCall / Firestore Transaction)** | Executes atomic Firestore multi-document transaction to lock the slot and reject competing requests without deadlocks. |
| **Live Attendance Verification** | Node.js Express polling / WebSocket server | **Cloud Firestore Real-time Snapshot Listeners (`collection().snapshots()`)** | Real-time live attendance terminal updates as students verify codes, with sub-100ms latency and no custom socket management. |
| **Push Notifications** | Custom Node.js APNs / FCM dispatch daemon | **Firebase Cloud Messaging (FCM) + Cloud Function Trigger (`onWrite`)** | Event-driven notification pipeline automatically triggered by changes to the `/notifications` collection. |
| **File Storage** | Local disk / custom AWS S3 `multipart/form-data` upload route | **Cloud Storage for Firebase** | Direct-to-bucket client uploads with fine-grained Storage Security Rules and automatic CDN edge caching. |
| **Transactional Email** | Nodemailer with SMTP server configuration | **Cloud Functions + SendGrid / Resend API Extension** | Serverless background email execution decoupled from user-facing Flutter requests. |
| **Data Export (.xlsx)** | Node.js ExcelJS stream generator | **Cloud Function `exportAttendanceExcel` (HTTP)** | Serverless compute on-demand generates formatted Excel spreadsheets and streams `.xlsx` back to the mobile client. |
| **App Security & Anti-Bot** | Express rate-limit middleware | **Firebase App Check (Play Integrity / DeviceCheck)** | Device attestation guarantees requests only originate from authentic mobile app binaries. |
| **Error Diagnostics & Logging** | Custom Winston / Morgan logger to file | **Firebase Crashlytics + Google Cloud Logging** | Real-time mobile crash monitoring and centralized serverless function log analytics. |

---

## 2. Deep Dive: Feature-by-Feature Service Architecture

### 2.1 Authentication & Signup Feature
- **Previous**:
  - `POST /auth/signup-request` ➔ Insert `SignupRequest` row in PostgreSQL.
  - `POST /admin/signup-requests/:id/approve` ➔ Bcrypt hash password, insert `User` row, update `SignupRequest`, send SMTP email.
  - `POST /auth/login` ➔ Query user, compare hash, sign JWT access/refresh tokens.
- **Firebase Equivalent**:
  - **Signup Request**: Flutter writes document directly to Firestore `signupRequests` collection.
  - **Admin Approval**: Admin taps Approve ➔ Calls `approveSignupRequest` Cloud Function ➔ Creates Firebase Auth record with random password ➔ Creates `/users/{uid}` doc ➔ Sets Custom Claims ➔ Sends email.
  - **Login**: Flutter calls `FirebaseAuth.signInWithEmailAndPassword()` ➔ Fetches `/users/{uid}` ➔ Reads Custom Claims.

### 2.2 Attendance Terminal & Code Verification
- **Previous**:
  - Teacher: `POST /attendance/session/start` ➔ Generated 6-char code in DB.
  - Student: `POST /attendance/verify` ➔ Looked up active session, checked duplicate row in `attendance_records`.
  - Polling/Socket: Teacher polled `/attendance/session/:id/roster` every 2s.
- **Firebase Equivalent**:
  - Teacher: Creates doc in `attendanceSessions` collection with 6-character code.
  - Student: Runs Firestore write to `/attendance` collection (or calls `verifyAttendanceCode` Cloud Function). Security Rules prevent duplicate entries for `(sessionId, studentId)`.
  - Terminal Display: Teacher's Flutter app uses `FirebaseFirestore.instance.collection('attendance').where('sessionId', isEqualTo: activeSessionId).snapshots()` for real-time live roster updates.

### 2.3 Counseling & Office Hours Engine
- **Previous**:
  - `POST /counseling/slots` ➔ Insert `CounselingSlot`.
  - `POST /counseling/requests` ➔ Insert `CounselingRequest`.
  - `POST /counseling/requests/:id/approve` ➔ Multi-step SQL transaction locking rows, updating slot to `BOOKED`, updating winning request to `APPROVED`, and batch-updating other requests to `REJECTED`.
- **Firebase Equivalent**:
  - Teacher creates slot doc in `counselingSlots`.
  - Student creates booking doc in `counselingBookings` with `status: "PENDING"`.
  - Teacher taps Approve ➔ Calls `approveCounselingBooking` Cloud Function ➔ Uses `db.runTransaction()` to atomically mutate the slot and all related booking documents.

### 2.4 Curriculum, Schedules & Exams
- **Previous**:
  - `GET /courses/my-courses`, `GET /schedule`, `GET /exams` ➔ Node.js SQL queries with JOINs on `course_teachers`, `schedule_slots`, `exams`.
- **Firebase Equivalent**:
  - Flutter queries Firestore collections directly:
    - `/courses` where `year == user.year && semester == user.semester`
    - `/schedules` where `targetYear == user.year && targetSemester == user.semester`
    - `/exams` where `year == user.year && semester == user.semester`
  - Zero server endpoints required. Firestore offline cache delivers instantaneous local results.

### 2.5 Feedback & Cryptographic Anonymity
- **Previous**:
  - `POST /feedback` ➔ Insert row with `student_id`.
  - `GET /feedback/teacher` ➔ Node.js serializer stripped `student_id` if `is_anonymous === true`.
- **Firebase Equivalent**:
  - If `isAnonymous == true`: Flutter writes document with `studentId: "ANONYMOUS"` and client-side omission of user metadata.
  - Teacher reads from `/feedback` where `teacherId == user.uid`. Anonymity is preserved at the database layer.

### 2.6 Semester Lifecycle Management
- **Previous**:
  - `POST /semester/request` ➔ Insert row in `semester_requests`.
  - `POST /admin/semester-requests/:id/approve` ➔ Update `User` row `(year, semester)`.
- **Firebase Equivalent**:
  - Student writes doc to `semesterUpgradeRequests`.
  - Admin calls `approveSemesterUpgrade` Cloud Function ➔ Updates `/users/{uid}` doc + updates Firebase Auth Custom Claims `(year, semester)`.

---

## 3. Client Architecture Simplification

| Legacy Client Layer | Firebase Client Layer | Difference |
|:---|:---|:---|
| `ApiClient` (Dio HTTP Client) | **Firebase SDK instances** (`FirebaseAuth.instance`, `FirebaseFirestore.instance`) | Removed 500+ lines of HTTP configuration and error wrapping. |
| `AuthInterceptor` | **None** (Native SDK managed) | Removed manual token headers and retry handlers. |
| `SecureStorageService` | **None** (Native SDK managed) | Hardware keychain management is delegated to Firebase. |
| `NetworkInfo` & Connectivity checks | **Firestore Offline Persistence** | Firestore manages offline queues and synchronization automatically. |
| Remote DataSources | **Firestore DataSources** | Cleanly reads/writes collection references and real-time streams. |
| Domain Entities & Use Cases | **Unchanged** | 100% preservation of clean architecture domain layer. |
