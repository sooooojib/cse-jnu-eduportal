# Business Rules & Domain Logic

This document specifies the exact domain invariants, state machines, and business rules enforced by the **CSE JnU EduPortal** backend.

---

## 1. Authentication & Onboarding Gate (BR-AUTH)

### BR-AUTH-01: Tri-State Registration Pipeline
1. Public signups do **not** automatically create active sessions.
2. A signup submission registers a `SignupRequest` in status `PENDING`.
3. Required role-specific identity metadata:
   - For `STUDENT` and `CR`: Full Name, Email, and **Student ID** (e.g., `2020CSE001`).
   - For `TEACHER`: Full Name, Email, and **Contact Phone Number** (e.g., `01700000000`).
4. Upon Administrator review:
   - **`APPROVED`**: The backend automatically provisions the `User` account, assigns the designated role and initial year/semester, generates a secure random credential, and dispatches the onboarding email.
   - **`REJECTED`**: The request is flagged with an optional rejection reason; no active user record is created.

---

## 2. Semester Lifecycle & State Machine (BR-SEM)

### BR-SEM-01: Academic Range
The department supports an 8-semester curriculum across 4 years:
- **Year:** `1`, `2`, `3`, `4`
- **Semester:** `1`, `2`

### BR-SEM-02: Semester Change State Machine
Students and CRs can petition to upgrade or correct their active semester.

```
       [ Initial State: NONE ]
                  │
                  │ Student submits petition (requestedYear, requestedSemester)
                  ▼
         [ State: PENDING ]
          │              │
 Admin Approves          │ Admin Rejects
          │              │
          ▼              ▼
  [ State: APPROVED ]   [ State: REJECTED ]
          │                      │
          │ (Updates user        │ (Displays banner with
          │  year/sem,           │  reason; allows
          │  resets to NONE)     │  resubmission)
```

- When `semesterStatus == 'PENDING'`, the student UI displays an amber pending badge and disables duplicate requests.
- When approved, `user.year = user.requestedYear`, `user.semester = user.requestedSemester`, `user.requestedYear = null`, `user.requestedSemester = null`, and `semesterStatus = 'APPROVED'`.

---

## 3. Daily Routine & Schedule Rules (BR-SCHED)

### BR-SCHED-01: CR Tomorrow-Only Scheduling Lock
- Class Representatives are authorized to schedule routine slots **only for the immediate next calendar day** (`startOfTomorrow()` to `endOfTomorrow()`).
- Date picker constraints on CR devices are locked to `Tomorrow`.

### BR-SCHED-02: Stale Slot Cleanup Engine
- When fetching or updating schedules, any scheduled slots with dates strictly in the past are archived, and any erroneous future slots beyond tomorrow created by unauthorized operations are automatically purged or sanitized.

### BR-SCHED-03: Time-Aware Schedule Views for Faculty
- **05:00 to 16:59**: Professor dashboard schedule focuses on **Today's Classes**.
- **17:00 to 04:59**: Professor dashboard schedule automatically shifts to **Tomorrow's Classes** to facilitate next-day preparation.

### BR-SCHED-04: WhatsApp Broadcast Formatter
- CR routine broadcasts must generate a structured markdown text string with timestamps, course code, course title, teacher name, and assigned room for immediate forwarding to messaging groups.

---

## 4. Attendance Verification Terminal (BR-ATT)

### BR-ATT-01: 6-Character Dynamic Code Generation
- A professor or administrator initiates an attendance session for a specific course and schedule slot.
- The session generates a random **6-character alphanumeric uppercase code** (excluding ambiguous characters like `0`, `O`, `1`, `I`).
- Codes expire upon manual deactivation or session closure.

### BR-ATT-02: Verification Constraint & Idempotency
- Each student can record attendance for a session **at most once**:
  $$\text{UniqueConstraint}(\text{sessionId}, \text{studentId})$$
- Submitting an invalid or expired code returns a strict `400 Bad Request` with an appropriate error code.

### BR-ATT-03: Real-Time Roster & Manual Override
- Professors can view the live roster of present students.
- Professors have administrative authority to manually toggle any student's status between `PRESENT` and `ABSENT` (e.g., for late arrivals or excused absences).
- Bulk actions ("Mark All Present", "Mark All Absent") are supported.

---

## 5. Faculty Counseling Mutual-Exclusion Engine (BR-COUN)

### BR-COUN-01: Slot States
A counseling slot can be in one of the following states:
- `AVAILABLE`: Open for student booking requests.
- `BOOKED`: Confirmed with an approved student.
- `COMPLETED`: Session finished.
- `CANCELLED`: Withdrawn by faculty.

### BR-COUN-02: Mutual-Exclusion Booking Logic
Multiple students may submit appointment requests (`CounselingRequest`) for an `AVAILABLE` slot.

```
Slot: AVAILABLE (Prof. Dr. Rahman — Nov 18, 10:00 AM)
 ├── Request A (Student 1) ── [ PENDING ]
 ├── Request B (Student 2) ── [ PENDING ]
 └── Request C (Student 3) ── [ PENDING ]

Teacher Approves Request B ──►
 Slot State becomes [ BOOKED ] (Assigned to Student 2)
 Request B State becomes [ APPROVED ]
 Request A State automatically transitions to [ REJECTED ]
 Request C State automatically transitions to [ REJECTED ]
```

- When the professor approves **one** request, the system executes an atomic transaction that:
  1. Updates the target request status to `APPROVED`.
  2. Updates the `CounselingSlot` status to `BOOKED` and sets `bookedStudentId`.
  3. Updates all other pending requests for that specific slot to `REJECTED`.

---

## 6. Feedback & Anonymity Engine (BR-FEED)

### BR-FEED-01: Rating Scale & Feedback Scope
- Students can submit 1 to 5-star ratings and text feedback targeted to specific professors.

### BR-FEED-02: Cryptographic Anonymity Detachment
- If `isAnonymous == true`:
  - When professors query feedback, the API **completely detaches and sanitizes** student identity fields (`studentId`, `studentName`, `avatar` are stripped and returned as `"Anonymous Student"`).
  - Admin audit views retain identity visibility for institutional safety and compliance.

### BR-FEED-03: Two-Way Threaded Replies & Attachments
- Professors can post an official response to any feedback entry.
- File attachments (screenshots, PDF assignments, code snippets) are supported on both initial feedback and faculty replies with size and MIME type restrictions (max 10MB; PNG, JPEG, PDF).

---

## 7. Course Assignment Matrix (BR-CRS)

### BR-CRS-01: Course-to-Teacher Relation
- Courses are defined by Department Curriculum (`code`, `title`, `credit`, `year`, `semester`, `type` e.g., Theory, Sessional/Lab).
- An Administrator can assign one or multiple teachers to a course.
- Teachers can only initiate attendance sessions and manage counseling for courses and students within their authorized department scope.
