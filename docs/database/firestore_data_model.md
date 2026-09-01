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
  "teacherName": "Dr. Mohammad Shafiul Alam",
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
  "teacherName": "Dr. Mohammad Shafiul Alam",
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
  "teacherName": "Dr. Mohammad Shafiul Alam",
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
  "teacherName": "Dr. Mohammad Shafiul Alam",
  "teacherEmail": "shafiul@cse.jnu.ac.bd",
  "slotDate": "2026-09-02",
  "startTime": "11:00",
  "endTime": "12:00",
  "isBooked": false,
  "status": "AVAILABLE",
  "bookedStudentId": null,
  "notes": "Office Room 410, Department of CSE",
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
  "teacherName": "Dr. Mohammad Shafiul Alam",
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
  "teacherName": "Dr. Mohammad Shafiul Alam",
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
      "teacherName": "Dr. Mohammad Shafiul Alam",
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
  "body": "Dr. Mohammad Shafiul Alam approved your meeting for Sep 2 at 11:00 AM.",
  "notificationType": "COUNSELING",
  "referenceType": "COUNSELING_SLOT",
  "referenceId": "slot_uuid_999",
  "isRead": false,
  "createdAt": "Timestamp"
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
