# Database Architecture & Ground-Zero Design

This document details the architectural foundation and relational modeling for the new **CSE JnU EduPortal** database. Designed from ground zero, the database enforces relational integrity, atomic concurrency, data isolation, and auditability across all departmental operations.

---

## 1. Design Principles & Tenets

### 1.1 Ground-Zero Derivation
Every table, attribute, relationship, and constraint is derived directly from the verified functional requirements of the Department of Computer Science & Engineering, Jagannath University. No legacy ORM artifacts or obsolete web schemas have been copied or preserved.

### 1.2 Strict Relational Integrity
- **Foreign Keys with Purposeful Cascades**: Delete and update rules (`CASCADE`, `RESTRICT`, `SET NULL`) are explicitly configured to prevent orphaned data while safeguarding critical academic audits.
- **Database-Level Check Constraints (`CHECK`)**: Domain values (e.g., rating `1..5`, year `1..4`, semester `1..2`, credit `> 0`) are validated at the database engine level, preventing corrupt data insertion regardless of client bugs.

### 1.3 Concurrency & Race Condition Elimination
- **Partial Unique Indexes**: Used to enforce invariants such as "Only one pending signup per student ID", "Only one active attendance session per course", and "Only one pending semester request per student".
- **Serializable Locking Paths**: Atomic transaction sequences defined for high-concurrency flows (e.g., in-class attendance verification spikes, mutual-exclusion counseling bookings).

### 1.4 Privacy & Anonymity by Architecture
- Feedback records store internal student identifiers for institutional safety, but the relational boundary allows the API serializer to execute complete cryptographic detachment for professor views.

---

## 2. Comprehensive Entity Inventory

The database schema comprises **15 core entities**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CSE JnU EduPortal Entities                       │
├──────────────────────┬──────────────────────┬───────────────────────────────┤
│ Identity & Access    │ Academic Curriculum  │ Operations & Tracking         │
│ • users              │ • courses            │ • attendance_sessions         │
│ • signup_requests    │ • course_teachers    │ • attendance_records          │
│ • semester_requests  │ • schedule_slots     │ • counseling_slots            │
│                      │ • exams              │ • counseling_requests         │
│                      │                      │ • feedbacks                   │
│                      │                      │ • feedback_replies            │
│                      │                      │ • attachments                 │
│                      │                      │ • notifications               │
└──────────────────────┴──────────────────────┴───────────────────────────────┘
```

---

## 3. Entity Classification & Domain Boundaries

### 3.1 Identity & Access Boundary
1. **`users`**: Central account record for Students, CRs, Teachers, and Admins.
2. **`signup_requests`**: Public onboarding registration queue awaiting administrative verification and automated password generation.
3. **`semester_requests`**: 4-Year × 2-Semester state machine governing student progression petitions.

### 3.2 Academic Curriculum & Scheduling Boundary
4. **`courses`**: Official department syllabus and curriculum units with credit weighting and course type.
5. **`course_teachers`**: Explicit junction mapping faculty members to assigned courses.
6. **`schedule_slots`**: Weekly class routine grid and room allocations (restricted to tomorrow for CR modifications).
7. **`exams`**: Midterm assessments, lab tests, and term final exam schedules with room allocations.

### 3.3 Attendance & Live Terminal Boundary
8. **`attendance_sessions`**: Live faculty verification sessions with 6-character dynamic codes and expiration timestamps.
9. **`attendance_records`**: Immutable student verification logs with timestamp, status (`PRESENT`, `ABSENT`, `EXCUSED`), and manual override audit trails.

### 3.4 Counseling & Office Hours Boundary
10. **`counseling_slots`**: Faculty office hour availability blocks (`AVAILABLE`, `BOOKED`, `COMPLETED`, `CANCELLED`).
11. **`counseling_requests`**: Student booking petitions with standardized reason categories, managed under an atomic mutual-exclusion graph.

### 3.5 Departmental Feedback & Quality Assurance Boundary
12. **`feedbacks`**: 1-to-5 star ratings and reviews with optional anonymous masking.
13. **`feedback_replies`**: Official threaded responses authored by faculty members.
14. **`attachments`**: Multi-format uploaded assets (images, PDFs, code files) linked polymorphically to feedback, replies, or counseling.
15. **`notifications`**: Real-time event notifications for student and teacher mobile devices.

---

## 4. Standard Field Conventions

All tables in the new database schema adhere to consistent naming and type standards:

| Convention | Standard | Example |
| :--- | :--- | :--- |
| **Primary Keys** | `UUIDv4` (128-bit random) | `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` |
| **Foreign Keys** | `<referenced_table_singular>_id` | `course_id`, `teacher_id`, `student_id` |
| **Timestamps** | UTC timestamp with time zone | `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` |
| **Booleans** | Prefixed with `is_` or `has_` | `is_anonymous`, `is_active`, `is_coordinator` |
| **Enums** | Uppercase string enums | `role VARCHAR(20) CHECK (role IN ('STUDENT', ...))` |
| **Naming Style** | `snake_case` for tables and columns | `schedule_slots`, `signup_requests` |

---

## 5. Next Specifications

- For relational cardinalities, cascade behaviors, and the Mermaid ER diagram, see [Entity Relationships](entity_relationships.md).
- For race condition analysis, check constraints, and indexing strategy, see [Constraints & Indexes](constraints_and_indexes.md).
- For the complete table-by-table schema reference, see [Data Dictionary](data_dictionary.md).
