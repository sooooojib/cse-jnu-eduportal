# Functional Requirements: Faculty Counseling & Office Hours

This document details the functional specifications for **Faculty Office Hours**, **Student Counseling Requests**, and the **Mutual-Exclusion Booking Engine**.

---

## 1. System Overview & Problem Statement

Academic counseling between students and faculty often suffers from schedule collisions, unstructured requests, and double-booking. The EduPortal Counseling module implements an interactive slot calendar with a **Mutual-Exclusion Slot Graph** to ensure streamlined, collision-free appointment management.

---

## 2. Feature: Faculty Slot Management

### Feature Specification
* **Who can use it**: `TEACHER`.
* **What the user can do**: Create availability slots for office hours, specify time ranges and meeting locations, view all student booking requests for each slot, and cancel unfilled slots.
* **Required Inputs**:
  - `slotDate`: Date of office hour (YYYY-MM-DD).
  - `startTime`: Slot start time (`HH:MM`, e.g. `10:00`).
  - `endTime`: Slot end time (`HH:MM`, e.g. `11:00`).
  - `notes`: Meeting location or discussion topics (e.g. `Office Room 410`, max 255 chars).
* **Expected Outputs**: Created `CounselingSlot` with status `AVAILABLE`.
* **Validation Rules**:
  - `slotDate` must be today or in the future.
  - `startTime` must precede `endTime`.
  - Faculty cannot create overlapping slots for themselves.
* **Authorization Requirements**: Restricted to `TEACHER` RBAC guard.

---

## 3. Feature: Student Appointment Petition & Reason Categorization

### Feature Specification
* **Who can use it**: `STUDENT`, `CR`.
* **What the user can do**: Browse open counseling slots across all departmental faculty, view faculty notes and available times, select an `AVAILABLE` slot, pick a standardized reason category, provide context notes, and submit a booking request.
* **Standardized Reason Categories**:
  1. `ACADEMIC_ADVISING` — Course advising, syllabus clarification, grade queries.
  2. `RESEARCH_DISCUSSION` — Thesis topics, paper reviews, lab project guidance.
  3. `MENTAL_PRESSURE` — Academic stress, workload counseling, well-being support.
  4. `CLASS_ISSUE` — Group dynamics, lecture comprehension, scheduling conflicts.
  5. `CAREER_GUIDANCE` — Internships, job market prep, higher education advice.
  6. `OTHER` — General inquiries.
* **Required Inputs**:
  - `slotId`: Target `CounselingSlot` UUID.
  - `category`: One of the 6 `CounselingCategory` enums.
  - `notes`: Student discussion context (string, 5–1000 characters).
* **Expected Outputs**: `CounselingRequest` record created with status `PENDING`.
* **Validation Rules**:
  - Target slot must be in status `AVAILABLE`.
  - Student cannot submit multiple pending requests for the same slot.
* **Authorization Requirements**: `STUDENT`, `CR`.

---

## 4. Feature: Mutual-Exclusion Booking Engine (BR-COUN)

### Algorithmic Logic
Multiple students are permitted to submit appointment petitions for an `AVAILABLE` slot. When the professor reviews the petitions and approves **one** student:

```
                      CounselingSlot (AVAILABLE)
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
 Request 1 (Student A)     Request 2 (Student B)     Request 3 (Student C)
    status: PENDING           status: PENDING           status: PENDING
                                   │
                        Teacher APPROVES Request 2
                                   │
                                   ▼
                      [ ATOMIC DATABASE TRANSACTION ]
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
 CounselingSlot: BOOKED    Request 2: APPROVED       Request 1: REJECTED
 (bookedStudent: Student B)                          Request 3: REJECTED
```

### Feature Specification
* **Who can use it**: `TEACHER`.
* **What the user can do**: View list of students who applied for a specific slot, review their reason categories and notes, and select **one** student to approve (or reject individual requests).
* **Required Inputs**:
  - `requestId`: Target `CounselingRequest` UUID.
  - `action`: `APPROVE` or `REJECT`.
* **Expected Outputs**:
  - If `APPROVE`:
    - Winning `CounselingRequest.status` becomes `APPROVED`.
    - Parent `CounselingSlot.status` becomes `BOOKED` with `bookedStudentId` set.
    - All other competing `CounselingRequest` records for that slot atomically transition to `REJECTED`.
  - If `REJECT`:
    - Target `CounselingRequest.status` becomes `REJECTED`.
    - `CounselingSlot` remains `AVAILABLE` for other candidates.
* **Validation Rules**: Target request must be `PENDING`; parent slot must be `AVAILABLE`.
* **Authorization Requirements**: Professor must be the owner (`teacherId`) of the counseling slot.
* **Transactional Integrity**: Must execute inside a serializable/isolated database transaction.
