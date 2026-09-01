# Functional Requirements: Academic Curriculum & Semester Management

This document details the functional specifications for **Course Management** and **Semester Lifecycle Management**.

---

## 1. Feature: Course Catalog & Curriculum Management

### Overview
Centralized directory of all academic courses offered by the Department of Computer Science & Engineering, Jagannath University across the 4-year undergraduate degree.

### Feature Specification
* **Who can use it**:
  - `ADMIN`: Full CRUD capabilities (Create, Read, Update, Delete) and assigning teachers to courses.
  - `TEACHER`: Read access to assigned courses and departmental course catalog.
  - `STUDENT`, `CR`: Read access to courses matching their active `(year, semester)`.
* **Required Inputs (for Course Creation/Update)**:
  - `code`: Course Code (string, e.g. `CSE-3101`, unique).
  - `title`: Course Title (string, e.g. `Operating Systems`, 3–150 characters).
  - `credit`: Credit points (decimal, e.g. `3.0`, `1.5`, `0.75`).
  - `year`: Academic year (`1`, `2`, `3`, `4`).
  - `semester`: Academic term (`1`, `2`).
  - `type`: Course type (`THEORY`, `LAB`, `PROJECT`, `THESIS`).
  - `description`: Optional overview / syllabus text.
* **Expected Outputs**:
  - Course entities returned in lists, grouped by Year/Semester or filtered by teacher assignment.
* **Validation Rules**:
  - `code` must follow standard department format (`CSE-YYYY` or `CSE-YYYZ`).
  - `credit` must be positive (> 0.0 and <= 6.0).
  - `(code)` must be unique across the entire curriculum.
* **Authorization Requirements**:
  - Mutation endpoints (`POST /courses`, `PUT /courses/:id`, `DELETE /courses/:id`, `POST /admin/users/:teacherId/courses`) restricted to `ADMIN`.
* **Important Business Rules**:
  - A course can be assigned to multiple teachers (e.g. course coordinator and co-teachers).
  - Students are automatically enrolled in all courses matching their active `(year, semester)`.
* **Edge Cases**:
  - Deleting a course with existing attendance sessions or schedule slots: Backend prevents hard delete or cascades soft-delete with warning.
* **Dependencies**: User Management, CourseTeacher Join Model.

---

## 2. Feature: Semester Lifecycle & State Machine

### Overview
A formal 4-Year × 2-Semester state machine governing student academic progression, promotion requests, and administrative verification.

### Curriculum Structure
- **Year 1**: 1st Year · 1st Semester | 1st Year · 2nd Semester
- **Year 2**: 2nd Year · 1st Semester | 2nd Year · 2nd Semester
- **Year 3**: 3rd Year · 1st Semester | 3rd Year · 2nd Semester
- **Year 4**: 4th Year · 1st Semester | 4th Year · 2nd Semester

### State Machine Definition

```
                        [ State: NONE ]
                     (Normal Active State)
                               │
                               │ Student submits upgrade petition
                               │ (requestedYear, requestedSemester)
                               ▼
                      [ State: PENDING ]
                               │
                ┌──────────────┴──────────────┐
                │                             │
    Admin Approves Petition        Admin Rejects Petition
                │                             │
                ▼                             ▼
       [ State: APPROVED ]           [ State: REJECTED ]
                │                             │
   • Updates user year & sem.        • Displays rejection reason.
   • Clears requested fields.        • Student can re-apply or
   • Resets state to NONE.             dismiss banner.
```

### Feature Specification
* **Who can use it**:
  - `STUDENT`, `CR`: View active semester, submit upgrade petition.
  - `ADMIN`: View pending petitions queue, approve or reject petitions.
* **Required Inputs**:
  - For Student Request: `requestedYear` (1–4), `requestedSemester` (1–2).
  - For Admin Action: `requestId`, `action` (`APPROVE` | `REJECT`), optional `rejectionReason`.
* **Expected Outputs**:
  - Updated `User` model with updated `year` and `semester` upon approval.
  - Notification banner on Student Dashboard indicating request state.
* **Validation Rules**:
  - `requestedYear` and `requestedSemester` must represent a valid combination.
  - Student cannot submit a new petition while a previous petition is still `PENDING`.
  - Target semester cannot be identical to the student's current active semester.
* **Authorization Requirements**:
  - Student endpoints (`POST /semester/request`, `GET /semester/status`): `STUDENT`, `CR`.
  - Admin endpoints (`GET /admin/semester-requests`, `POST /admin/semester-requests/:id/approve`, `POST /admin/semester-requests/:id/reject`): `ADMIN`.
* **Important Business Rules**:
  - When approved, the student's enrolled courses instantly update to the new semester's curriculum.
  - Past attendance records from previous semesters remain archived and intact.
* **Edge Cases**:
  - Student submits request for previous semester (e.g. readmission or retake): Allowed, but requires Admin verification.
  - Student graduates (completes Year 4 Sem 2): System sets alumni status or caps progression.
* **Ambiguities**:
  - **AMBIGUOUS — REQUIRES DECISION**: Should CR role be bound to a specific batch/semester (so that advancing semesters transfers CR privileges or requires re-assignment)? (Recommended: CR keeps role until manually updated by Admin).
