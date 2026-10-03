# Cloud Firestore Data Model & Schema Specification
## CSE JnU EduPortal — Stage 11 NoSQL Architecture

---

## 1. Design Principles for Firestore

1. **Denormalization for Zero-Join Reads**: In Firestore, multi-table SQL JOINs are not supported. Read-heavy attributes (e.g., `teacherName`, `courseTitle`, `courseCode`) are safely denormalized into related child documents (`schedules`, `attendance`, `counselingBookings`) to allow single-document read efficiency and instant offline rendering.
2. **Deterministic Document IDs for Uniqueness**: Where relational databases use partial unique indexes (e.g., `@@unique([sessionId, studentId])`), Firestore uses composite document IDs: `docId = "${sessionId}_${studentId}"`. This prevents duplicate writes via standard `doc().set()` operations without race conditions.
3. **Embedded Arrays for Small Bounded Collections**: Threaded replies on feedback cards and small attachment metadata are stored directly within parent documents as embedded arrays of Maps, eliminating unnecessary subcollection round-trips.
4. **Native Timestamps**: All temporal fields utilize `FieldValue.serverTimestamp()` on creation/update, converted to `Timestamp` instances and formatted for Flutter consumption.

---

## 2. Comprehensive Collection Inventory

```
Cloud Firestore Root
├── /users/{uid}                           [User Profiles & Roles]
├── /signupRequests/{requestId}            [Public Registration Queue]
├── /courses/{courseId}                    [Curriculum Catalog]
├── /courseAssignments/{assignmentId}      [Teacher Course Allocations]
├── /enrollments/{enrollmentId}            [Batch Student Course Enrollments]
├── /schedules/{slotId}                    [Class Timetables & Routine]
├── /exams/{examId}                        [Midterm & Final Exam Dates]
├── /attendanceSessions/{sessionId}        [Live Faculty Terminal Sessions]
├── /attendance/{recordId}                 [Student Verification Records]
├── /counselingSlots/{slotId}              [Faculty Office Hour Blocks]
├── /counselingBookings/{bookingId}        [Student Appointment Petitions]
├── /feedback/{feedbackId}                 [Course & Lecture Reviews]
├── /semesterUpgradeRequests/{requestId}   [Semester State Machine Petitions]
└── /notifications/{notificationId}        [In-App Alerts & Push Logs]
```

---

## 3. Detailed Document Schemas

### 3.1 `users` Collection
* **Document ID**: Firebase Auth `uid` (28 characters).
```json
{
  "email": "student@cse.jnu.ac.bd",
  "fullName": "Sajib Ahmed",
  "role": "STUDENT",
  "studentId": "2020CSE042",
  "phone": "+8801700000000",
  "avatarUrl": "https://firebasestorage.googleapis.com/.../avatars/uid.webp",
  "year": 3,
  "semester": 1,
  "assignedCourseIds": [],
  "fcmTokens": ["token_android_xyz", "token_ios_abc"],
  "isActive": true,
  "createdAt": "Timestamp(2026-08-01 00:00:00 UTC)",
  "updatedAt": "Timestamp(2026-08-31 22:00:00 UTC)"
}
```

### 3.2 `signupRequests` Collection
* **Document ID**: Auto-generated UUID.
```json
{
  "email": "applicant@cse.jnu.ac.bd",
  "fullName": "Tahmid Rahman",
  "role": "STUDENT",
  "studentId": "2024CSE015",
  "phone": "+8801800000000",
  "status": "PENDING",
  "rejectionReason": null,
  "reviewedBy": null,
  "createdAt": "Timestamp"
}
```

### 3.3 `courses` Collection
* **Document ID**: Course Code (e.g., `CSE-3101`) or Auto-generated UUID.
```json
{
  "code": "CSE-3101",
  "title": "Operating Systems",
  "credit": 3.0,
  "year": 3,
  "semester": 1,
  "courseType": "THEORY",
  "description": "Processes, Threads, CPU Scheduling, Memory Management, File Systems.",
  "teacherId": "uid_teacher_1",
  "teacherName": "Dr. Md. Abu Layek",
  "coordinatorId": "uid_teacher_1",
  "createdAt": "Timestamp"
}
```

### 3.4 `schedules` Collection
* **Document ID**: Auto-generated UUID.
```json
{
  "courseId": "CSE-3101",
  "courseCode": "CSE-3101",
  "courseTitle": "Operating Systems",
  "teacherId": "uid_teacher_1",
  "teacherName": "Dr. Md. Abu Layek",
  "dayOfWeek": "SUNDAY",
  "startTime": "09:00",
  "endTime": "10:30",
  "room": "Room 402",
  "targetYear": 3,
  "targetSemester": 1,
  "isExtraClass": false,
  "scheduledDate": "2026-09-01",
  "createdById": "uid_cr_1",
  "createdAt": "Timestamp"
}
```

### 3.5 `exams` Collection
* **Document ID**: Auto-generated UUID.
```json
{
  "courseId": "CSE-3101",
  "courseCode": "CSE-3101",
  "courseTitle": "Operating Systems",
  "title": "Midterm Assessment 1",
  "examDate": "2026-09-15",
  "startTime": "10:00",
  "endTime": "11:30",
  "room": "Lab 2 / Room 402",
  "year": 3,
  "semester": 1,
  "createdAt": "Timestamp"
}
```

### 3.6 `attendanceSessions` Collection
* **Document ID**: Auto-generated UUID.
```json
{
  "courseId": "CSE-3101",
  "courseCode": "CSE-3101",
  "courseTitle": "Operating Systems",
  "teacherId": "uid_teacher_1",
  "teacherName": "Dr. Md. Abu Layek",
  "code": "7K9P2X",
  "isActive": true,
  "status": "ACTIVE",
  "sessionDate": "2026-08-31",
  "expiresAt": "Timestamp(2026-08-31 10:15:00 UTC)",
  "totalPresentCount": 42,
  "createdAt": "Timestamp"
}
```

### 3.7 `attendance` Collection
* **Document ID**: Composite `${sessionId}_${studentId}` (Enforces unique submission invariant).
```json
{
  "sessionId": "session_uuid_123",
  "studentId": "uid_student_42",
  "studentName": "Sajib Ahmed",
  "studentRoll": "2020CSE042",
  "courseId": "CSE-3101",
  "courseCode": "CSE-3101",
  "courseTitle": "Operating Systems",
  "status": "PRESENT",
  "isManualOverride": false,
  "date": "2026-08-31",
  "verifiedAt": "Timestamp(2026-08-31 09:05:22 UTC)"
}
```

### 3.8 `counselingSlots` Collection
* **Document ID**: Auto-generated UUID.
```json
{
  "teacherId": "uid_teacher_1",
  "teacherName": "Dr. Md. Abu Layek",
  "teacherEmail": "layek@cse.jnu.ac.bd",
  "slotDate": "2026-09-02",
  "startTime": "11:00",
  "endTime": "12:00",
  "isBooked": false,
  "status": "AVAILABLE",
  "bookedStudentId": null,
  "notes": "Office Room 501, 5th Floor, Department of CSE",
  "createdAt": "Timestamp"
}
```

### 3.9 `counselingBookings` Collection
* **Document ID**: Auto-generated UUID.
```json
{
  "slotId": "slot_uuid_999",
  "studentId": "uid_student_42",
  "studentName": "Sajib Ahmed",
  "teacherId": "uid_teacher_1",
  "teacherName": "Dr. Md. Abu Layek",
  "slotDate": "2026-09-02",
  "startTime": "11:00",
  "endTime": "12:00",
  "category": "ACADEMIC_ADVISING",
  "notes": "Queries regarding Deadlock avoidance Banker's algorithm and Lab 3.",
  "status": "PENDING",
  "reviewedAt": null,
  "createdAt": "Timestamp"
}
```

### 3.10 `feedback` Collection
* **Document ID**: Auto-generated UUID.
```json
{
  "studentId": "ANONYMOUS",
  "realStudentIdHash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "teacherId": "uid_teacher_1",
  "teacherName": "Dr. Md. Abu Layek",
  "courseId": "CSE-3101",
  "courseCode": "CSE-3101",
  "courseTitle": "Operating Systems",
  "rating": 5,
  "comments": "The visual explanation of Virtual Memory paging was exceptionally clear and helpful.",
  "isAnonymous": true,
  "attachments": [
    {
      "id": "att_1",
      "fileName": "lecture_slide_note.png",
      "fileUrl": "https://firebasestorage.googleapis.com/.../slide.png",
      "mimeType": "image/png",
      "fileSize": 245000
    }
  ],
  "replies": [
    {
      "id": "reply_1",
      "teacherName": "Dr. Md. Abu Layek",
      "replyText": "Thank you! We will cover page replacement algorithms in the next lecture.",
      "createdAt": "2026-09-01T10:00:00Z"
    }
  ],
  "createdAt": "Timestamp"
}
```

### 3.11 `semesterUpgradeRequests` Collection
* **Document ID**: Auto-generated UUID.
```json
{
  "studentId": "uid_student_42",
  "studentName": "Sajib Ahmed",
  "studentRoll": "2020CSE042",
  "currentYear": 2,
  "currentSemester": 2,
  "requestedYear": 3,
  "requestedSemester": 1,
  "status": "PENDING",
  "rejectionReason": null,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

### 3.12 `notifications` Collection
* **Document ID**: Auto-generated UUID.
```json
{
  "userId": "uid_student_42",
  "title": "Counseling Appointment Approved",
  "body": "Dr. Md. Abu Layek approved your meeting for Sep 2 at 11:00 AM.",
  "notificationType": "COUNSELING",
  "referenceType": "COUNSELING_SLOT",
  "referenceId": "slot_uuid_999",
  "isRead": false,
  "createdAt": "Timestamp"
}
```

### 3.13 `courseAssignments` Collection
* **Document ID**: Auto-generated UUID or composite `${courseId}_${teacherId}_${section}`.
```json
{
  "courseId": "CSE-3101",
  "teacherId": "uid_teacher_1",
  "academicYear": "2025-2026",
  "semester": "1",
  "section": "A",
  "assignedRole": "LECTURER",
  "notes": "Coordinating theory classes and labs",
  "createdAt": "Timestamp"
}
```

### 3.14 `enrollments` Collection
* **Document ID**: Auto-generated UUID or composite `${courseId}_${studentId}`.
```json
{
  "courseId": "CSE-3101",
  "studentId": "uid_student_42",
  "academicYear": "2025-2026",
  "year": 3,
  "semester": 1,
  "status": "ACTIVE",
  "enrolledAt": "Timestamp"
}
```

---

## 4. Required Composite Indexes (`firestore.indexes.json`)

```json
{
  "indexes": [
    {
      "collectionGroup": "attendance",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "studentId", "order": "ASCENDING" },
        { "fieldPath": "date", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "counselingBookings",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "studentId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "feedback",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "teacherId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "schedules",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "targetYear", "order": "ASCENDING" },
        { "fieldPath": "targetSemester", "order": "ASCENDING" },
        { "fieldPath": "dayOfWeek", "order": "ASCENDING" }
      ]
    }
  ]
}
```

---

## 5. Document ID Strategy Matrix

| Collection | ID Format / Strategy | Example | Invariant & Uniqueness Guarantee |
|:---|:---|:---|:---|
| `/users` | Firebase Auth UID (28 chars) | `W8x2L9pQ1zM...` | 1-to-1 match with `request.auth.uid`. No orphan profiles. |
| `/signupRequests` | Auto-generated UUID | `req_9x2kLp...` | Public write; unique request queue tracking. |
| `/courses` | Standardized Course Code | `CSE-3101` | Unique course identity across academic sessions. |
| `/courseAssignments` | Auto-generated UUID or `${courseId}_${teacherId}_${section}` | `asgn_8a2d1f...` | Maps faculty members to teaching sections. |
| `/enrollments` | Auto-generated UUID or `${courseId}_${studentId}` | `enr_4f92c1...` | Maps individual students to course registrations. |
| `/schedules` | Auto-generated UUID | `slot_48f72a...` | Supports multiple slots per course across weekdays. |
| `/exams` | Auto-generated UUID | `exam_21e89b...` | Midterm & final exam scheduling. |
| `/attendanceSessions` | Auto-generated UUID | `sess_98a72b...` | One session per class meeting; 6-char verification code. |
| `/attendance` | Composite: `${sessionId}_${studentId}` | `sess_98a72b_uid_42` | **Critical Invariant**: Guarantees zero duplicate attendance per student per session at database engine level. |
| `/counselingSlots` | Auto-generated UUID | `cslot_55a29f...` | Single office hour block created by professor. |
| `/counselingBookings` | Auto-generated UUID | `cbook_77c12d...` | Multiple students can petition; winner locked via transaction. |
| `/feedback` | Auto-generated UUID | `fbk_33f91a...` | Allows anonymous student reviews with optional attachments. |
| `/semesterUpgradeRequests`| Auto-generated UUID | `sem_11b88e...` | State machine tracking for semester promotion. |
| `/notifications` | Auto-generated UUID | `notif_66d44a...` | Individual recipient notifications with unread tracking. |

---

## 6. Entity Relationships & Document References

```
  ┌─────────────────────────────────────────────────────────────┐
  │                    Entity Relationship Graph                │
  └─────────────────────────────────────────────────────────────┘

    users (TEACHER)                     users (STUDENT)
      │                                   │
      ├── creates ─── counselingSlots     ├── petitions ─── counselingBookings
      │                    │ (1)          │                       │ (M)
      │                    └──────────────┴───────────────────────┘
      │                           (Locked via Cloud Function Transaction)
      │
      ├── teaches ─── courseAssignments ── courses ──────────── enrollments (Student-level)
      │                                       │
      │                                       ├── schedules
      │                                       └── exams
      │
      └── opens ───── attendanceSessions
                             │ (1)
                             │
                             └── verifies (M) ── attendance [docId: ${sessionId}_${studentId}]
                                                      │
                                                      └── studentId reference
```

### Document References:
- **`teacherId`**: Stored in `courses`, `courseAssignments`, `schedules`, `attendanceSessions`, `counselingSlots`, `counselingBookings`, and `feedback`.
- **`studentId`**: Stored in `enrollments`, `attendance`, `counselingBookings`, `semesterUpgradeRequests`, `notifications`, and conditionally in `feedback` (`"ANONYMOUS"` if anonymous).
- **`courseId` / `courseCode`**: Stored in `courseAssignments`, `enrollments`, `schedules`, `exams`, `attendanceSessions`, and `attendance`.

---

## 7. Denormalization Catalog

| Target Collection | Denormalized Fields | Source Authority | Architectural Rationale |
|:---|:---|:---|:---|
| `/schedules` | `courseCode`, `courseTitle`, `teacherName` | `/courses`, `/users` | Eliminates joins when students render daily timetables. |
| `/attendance` | `studentName`, `studentRoll`, `courseCode`, `courseTitle` | `/users`, `/courses` | Allows teacher live terminal and PDF export without querying user profiles for every row. |
| `/counselingBookings` | `teacherName`, `studentName`, `slotDate`, `startTime`, `endTime` | `/counselingSlots`, `/users` | Allows student and teacher appointment lists to render instantly from cache. |
| `/feedback` | `teacherName`, `courseCode`, `courseTitle` | `/users`, `/courses` | Department audit and teacher inbox view require zero external lookups. |
| `/users` | `assignedCourseIds` | `/courses` | Instant permission verification for teacher course ownership. |

---

## 8. Query Patterns & Compound Index Alignment

| Use Case | Firestore Query | Required Index |
|:---|:---|:---|
| **Student Attendance History** | `.collection('attendance').where('studentId', '==', uid).orderBy('date', descending: true)` | `attendance: studentId ASC, date DESC` |
| **Teacher Live Attendance** | `.collection('attendance').where('sessionId', '==', activeSessionId)` | Single-field index on `sessionId` (Automatic) |
| **Student Daily Schedule** | `.collection('schedules').where('targetYear', '==', y).where('targetSemester', '==', s).where('dayOfWeek', '==', day)` | `schedules: targetYear ASC, targetSemester ASC, dayOfWeek ASC` |
| **Counseling Booking History**| `.collection('counselingBookings').where('studentId', '==', uid).orderBy('createdAt', descending: true)` | `counselingBookings: studentId ASC, createdAt DESC` |
| **Teacher Feedback Inbox** | `.collection('feedback').where('teacherId', '==', uid).orderBy('createdAt', descending: true)` | `feedback: teacherId ASC, createdAt DESC` |
| **User Notifications Feed** | `.collection('notifications').where('userId', '==', uid).orderBy('createdAt', descending: true).limit(50)` | `notifications: userId ASC, createdAt DESC` |
| **Teacher Course Allocations** | `.collection('courseAssignments').where('teacherId', '==', uid)` | Single-field index on `teacherId` (Automatic) |
| **Student Course Enrollments** | `.collection('enrollments').where('studentId', '==', uid)` | Single-field index on `studentId` (Automatic) |
| **Course Student Roster** | `.collection('enrollments').where('courseId', '==', courseId)` | Single-field index on `courseId` (Automatic) |

---

## 9. Transaction & Atomicity Requirements

| Business Workflow | Atomicity Strategy | Transaction Logic |
|:---|:---|:---|
| **Attendance Verification** | Deterministic Composite Document ID | `db.collection('attendance').doc('${sessionId}_${studentId}').set(...)`. Overwrites or conflicts are rejected deterministically by Security Rules without distributed lock overhead. |
| **Counseling Booking Mutual Exclusion** | Cloud Function (`runTransaction`) | Reads slot doc + booking doc. Sets slot `status: 'BOOKED'`, sets winning booking `status: 'APPROVED'`, queries and marks all other pending bookings for that slot as `REJECTED`. |
| **Admin Signup Approval** | Cloud Function (`approveSignupRequest`) | Invokes Firebase Admin Auth to create account + sets Custom Claims + creates `/users/{uid}` doc + updates `signupRequests/{id}` to `APPROVED` atomically. |
| **Semester Upgrade Promotion** | Cloud Function (`approveSemesterUpgrade`) | Updates `/users/{uid}` doc `(year, semester)` + updates Firebase Auth Custom Claims `(year, semester)` + marks petition `APPROVED` + writes notification. |

