# Database Entities & Data Models

This document defines the ground-zero database entity models, attributes, enums, relations, and unique constraints for **CSE JnU EduPortal**.

---

## 1. Enumerations

```typescript
enum UserRole {
  STUDENT
  CR
  TEACHER
  ADMIN
}

enum RequestStatus {
  PENDING
  APPROVED
  REJECTED
}

enum SemesterStatus {
  NONE
  PENDING
  APPROVED
  REJECTED
}

enum CourseType {
  THEORY
  LAB
  PROJECT
  THESIS
}

enum DayOfWeek {
  SUNDAY
  MONDAY
  TUESDAY
  WEDNESDAY
  THURSDAY
  FRIDAY
  SATURDAY
}

enum AttendanceStatus {
  PRESENT
  ABSENT
  EXCUSED
}

enum SessionStatus {
  ACTIVE
  EXPIRED
  CLOSED
}

enum SlotStatus {
  AVAILABLE
  BOOKED
  COMPLETED
  CANCELLED
}

enum CounselingCategory {
  ACADEMIC_ADVISING
  RESEARCH_DISCUSSION
  MENTAL_PRESSURE
  CLASS_ISSUE
  CAREER_GUIDANCE
  OTHER
}
```

---

## 2. Entity Schemas

### 2.1 `User`
Primary user account entity representing all departmental members.
- `id`: `UUID` (Primary Key)
- `email`: `String` (Unique, Indexed)
- `passwordHash`: `String`
- `name`: `String`
- `role`: `UserRole` (Indexed)
- `studentId`: `String?` (Unique, Sparse Index — for `STUDENT` & `CR`)
- `phone`: `String?` (for `TEACHER`)
- `avatarUrl`: `String?`
- `year`: `Int?` (1 to 4)
- `semester`: `Int?` (1 to 2)
- `requestedYear`: `Int?`
- `requestedSemester`: `Int?`
- `semesterStatus`: `SemesterStatus` (Default: `NONE`)
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.2 `SignupRequest`
Public registration petitions awaiting administrative review.
- `id`: `UUID` (Primary Key)
- `email`: `String` (Indexed)
- `name`: `String`
- `role`: `UserRole` (`STUDENT`, `CR`, or `TEACHER`)
- `studentId`: `String?`
- `phone`: `String?`
- `status`: `RequestStatus` (Default: `PENDING`, Indexed)
- `rejectionReason`: `String?`
- `reviewedById`: `UUID?` (FK -> `User.id`)
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.3 `Course`
Departmental curriculum catalog.
- `id`: `UUID` (Primary Key)
- `code`: `String` (Unique, Indexed, e.g. `CSE-3101`)
- `title`: `String` (e.g. `Operating Systems`)
- `credit`: `Decimal` (e.g. `3.0`)
- `year`: `Int` (1 to 4, Indexed)
- `semester`: `Int` (1 to 2, Indexed)
- `type`: `CourseType` (Default: `THEORY`)
- `description`: `String?`
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.4 `CourseTeacher`
Join table mapping professors to courses.
- `id`: `UUID` (Primary Key)
- `courseId`: `UUID` (FK -> `Course.id`, Indexed)
- `teacherId`: `UUID` (FK -> `User.id`, Indexed)
- `isCoordinator`: `Boolean` (Default: `false`)
- `createdAt`: `Timestamp`
- **Unique Constraint**: `(courseId, teacherId)`

### 2.5 `ScheduleSlot`
Daily and weekly class timetable allocations.
- `id`: `UUID` (Primary Key)
- `courseId`: `UUID` (FK -> `Course.id`, Indexed)
- `teacherId`: `UUID` (FK -> `User.id`, Indexed)
- `dayOfWeek`: `DayOfWeek`
- `startTime`: `String` (e.g. `09:00`)
- `endTime`: `String` (e.g. `10:30`)
- `room`: `String` (e.g. `Room 402`)
- `targetYear`: `Int` (1 to 4)
- `targetSemester`: `Int` (1 to 2)
- `createdById`: `UUID` (FK -> `User.id`)
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.6 `Exam`
Upcoming midterm and semester final exam schedules.
- `id`: `UUID` (Primary Key)
- `courseId`: `UUID` (FK -> `Course.id`, Indexed)
- `title`: `String` (e.g. `Midterm Assessment`)
- `examDate`: `Date`
- `startTime`: `String` (e.g. `10:00`)
- `endTime`: `String` (e.g. `12:00`)
- `room`: `String` (e.g. `Room 301`)
- `year`: `Int`
- `semester`: `Int`
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.7 `AttendanceSession`
Live attendance terminal sessions launched by faculty.
- `id`: `UUID` (Primary Key)
- `courseId`: `UUID` (FK -> `Course.id`, Indexed)
- `teacherId`: `UUID` (FK -> `User.id`, Indexed)
- `scheduleSlotId`: `UUID?` (FK -> `ScheduleSlot.id`)
- `code`: `String` (Length 6, Uppercase, Indexed)
- `status`: `SessionStatus` (Default: `ACTIVE`)
- `expiresAt`: `Timestamp?`
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.8 `AttendanceRecord`
Individual student verification entries.
- `id`: `UUID` (Primary Key)
- `sessionId`: `UUID` (FK -> `AttendanceSession.id`, Indexed)
- `studentId`: `UUID` (FK -> `User.id`, Indexed)
- `status`: `AttendanceStatus` (Default: `PRESENT`)
- `verifiedAt`: `Timestamp`
- `isManualOverride`: `Boolean` (Default: `false`)
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`
- **Unique Constraint**: `(sessionId, studentId)`

### 2.9 `CounselingSlot`
Faculty office hour availability slots.
- `id`: `UUID` (Primary Key)
- `teacherId`: `UUID` (FK -> `User.id`, Indexed)
- `slotDate`: `Date` (Indexed)
- `startTime`: `String` (e.g. `10:00`)
- `endTime`: `String` (e.g. `11:00`)
- `status`: `SlotStatus` (Default: `AVAILABLE`, Indexed)
- `bookedStudentId`: `UUID?` (FK -> `User.id`)
- `notes`: `String?`
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.10 `CounselingRequest`
Student appointment petitions for a counseling slot.
- `id`: `UUID` (Primary Key)
- `slotId`: `UUID` (FK -> `CounselingSlot.id`, Indexed)
- `studentId`: `UUID` (FK -> `User.id`, Indexed)
- `category`: `CounselingCategory`
- `notes`: `String`
- `status`: `RequestStatus` (Default: `PENDING`)
- `reviewedAt`: `Timestamp?`
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.11 `Feedback`
Confidential course and lecture reviews.
- `id`: `UUID` (Primary Key)
- `teacherId`: `UUID` (FK -> `User.id`, Indexed)
- `studentId`: `UUID` (FK -> `User.id`, Indexed)
- `rating`: `Int` (1 to 5)
- `comments`: `String`
- `isAnonymous`: `Boolean` (Default: `false`)
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.12 `FeedbackReply`
Faculty responses to student feedback.
- `id`: `UUID` (Primary Key)
- `feedbackId`: `UUID` (FK -> `Feedback.id`, Indexed)
- `teacherId`: `UUID` (FK -> `User.id`)
- `replyText`: `String`
- `createdAt`: `Timestamp`
- `updatedAt`: `Timestamp`

### 2.13 `Attachment`
Multi-format file attachments for feedback, replies, and counseling.
- `id`: `UUID` (Primary Key)
- `parentType`: `String` (`FEEDBACK`, `FEEDBACK_REPLY`, `COUNSELING`)
- `parentId`: `UUID` (Indexed)
- `fileUrl`: `String`
- `fileName`: `String`
- `fileSize`: `Int`
- `mimeType`: `String`
- `createdAt`: `Timestamp`
