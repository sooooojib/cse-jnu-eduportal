# CSE JnU EduPortal — Complete Requirements Specification

This directory contains the complete functional and non-functional requirements specification for the new **CSE JnU EduPortal** mobile application and backend ecosystem.

---

## 🧭 Requirements Navigation Index

The requirements are organized into modular, feature-oriented specifications covering all 25 system domains:

| # | Domain Topic | Primary Document | Key Capabilities / Rules |
| :---: | :--- | :--- | :--- |
| **1** | **System Overview** | [`README.md`](README.md) | High-level mission, departmental scope, and architecture principles. |
| **2** | **User Roles** | [`01_roles_auth_access.md`](01_roles_auth_access.md) | Role definitions for `STUDENT`, `CR`, `TEACHER`, and `ADMIN`. |
| **3** | **Authentication** | [`01_roles_auth_access.md`](01_roles_auth_access.md) | JWT token pairs, hardware secure storage, session management. |
| **4** | **Authorization** | [`01_roles_auth_access.md`](01_roles_auth_access.md) | Declarative RBAC guards and endpoint permission matrix. |
| **5** | **Student Functionality** | [`02_role_functionalities.md`](02_role_functionalities.md) | Enrolled courses, attendance history, routine, counseling & feedback. |
| **6** | **Teacher Functionality** | [`02_role_functionalities.md`](02_role_functionalities.md) | Live code terminal, roster toggles, counseling slots, feedback replies. |
| **7** | **CR Functionality** | [`02_role_functionalities.md`](02_role_functionalities.md) | Dual student/manager role, tomorrow-only scheduling, WhatsApp broadcast. |
| **8** | **Admin Functionality** | [`02_role_functionalities.md`](02_role_functionalities.md) | Signup queues, semester petitions, user directory, course assignments. |
| **9** | **Course Management** | [`03_academic_curriculum_semester.md`](03_academic_curriculum_semester.md) | Departmental curriculum catalog, credit weights, teacher assignments. |
| **10** | **Semester Management** | [`03_academic_curriculum_semester.md`](03_academic_curriculum_semester.md) | 4-Year × 2-Semester state machine and upgrade request pipeline. |
| **11** | **Attendance Tracking** | [`04_attendance_terminal.md`](04_attendance_terminal.md) | Course percentage formulas, historical date logs, eligibility flags. |
| **12** | **Live Attendance Verification** | [`04_attendance_terminal.md`](04_attendance_terminal.md) | Dynamic 6-char code terminal, live roster, student code entry. |
| **13** | **Schedule Management** | [`05_schedule_exams_whatsapp.md`](05_schedule_exams_whatsapp.md) | Weekly routine matrix, CR tomorrow lock, stale slot cleanup. |
| **14** | **Exam Management** | [`05_schedule_exams_whatsapp.md`](05_schedule_exams_whatsapp.md) | Midterm and term final routines, room allocations, countdowns. |
| **15** | **Faculty Counseling** | [`06_counseling_office_hours.md`](06_counseling_office_hours.md) | Office hours calendar, reason categories, mutual-exclusion locking. |
| **16** | **Feedback & Replies** | [`07_feedback_anonymity_replies.md`](07_feedback_anonymity_replies.md) | 1–5 star ratings, anonymity detachment, threaded teacher replies. |
| **17** | **Signup & Approval** | [`01_roles_auth_access.md`](01_roles_auth_access.md) | Tri-state registration gate, automated secure password dispatch. |
| **18** | **File Attachments** | [`07_feedback_anonymity_replies.md`](07_feedback_anonymity_replies.md) | Multi-format upload pipeline (10 MB cap, MIME validation). |
| **19** | **In-App Notifications** | [`08_notifications_email_export.md`](08_notifications_email_export.md) | Push & in-app alerts for counseling, schedules, semester actions. |
| **20** | **WhatsApp Broadcasting** | [`05_schedule_exams_whatsapp.md`](05_schedule_exams_whatsapp.md) | Single-tap markdown routine generator for class WhatsApp groups. |
| **21** | **Email Services** | [`08_notifications_email_export.md`](08_notifications_email_export.md) | Transactional welcome credentials dispatch and status alerts. |
| **22** | **Data Export** | [`08_notifications_email_export.md`](08_notifications_email_export.md) | Formatted Excel (.xlsx) departmental attendance report generation. |
| **23** | **Error Handling** | [`09_non_functional_requirements.md`](09_non_functional_requirements.md) | Canonical machine error codes, client retry, network resilience. |
| **24** | **Security Requirements** | [`09_non_functional_requirements.md`](09_non_functional_requirements.md) | Argon2id password hashing, JWT key rotation, rate limiting, zero DB exposure. |
| **25** | **Performance Benchmarks** | [`09_non_functional_requirements.md`](09_non_functional_requirements.md) | <200ms verification latency, 500 concurrent submissions, <1.5s cold boot. |

---

## 🏷️ Separation of Requirements

- **Functional Requirements (FRs)**: Documented in [`01_roles_auth_access.md`](01_roles_auth_access.md) through [`08_notifications_email_export.md`](08_notifications_email_export.md). These specify *what* behaviors, business rules, inputs, outputs, and workflows the system provides.
- **Non-Functional Requirements (NFRs)**: Documented in [`09_non_functional_requirements.md`](09_non_functional_requirements.md). These define performance benchmarks, security guarantees, error envelopes, and resilience protocols.

---

## ❓ Identified Ambiguities Requiring Decision

The following items from the functional domain analysis have been formally flagged for architectural alignment:

1. **Initial Year/Semester Selection on Signup**:
   - *Status*: `**AMBIGUOUS — REQUIRES DECISION**`
   - *Options*: (A) Default to Year 1 Sem 1, (B) Allow student to choose year/sem in registration form, (C) Set manually by Administrator upon approval.
2. **Password Self-Reset Flow**:
   - *Status*: `**AMBIGUOUS — REQUIRES DECISION**`
   - *Options*: (A) Standard email OTP reset flow, (B) Admin-mediated password reset.
3. **Attendance Session Default Expiry**:
   - *Status*: `**AMBIGUOUS — REQUIRES DECISION**`
   - *Options*: (A) Auto-expire after 15 minutes, (B) Persist until teacher manually presses "Deactivate Code".
4. **CR Role Tenure & Batch Advancement**:
   - *Status*: `**AMBIGUOUS — REQUIRES DECISION**`
   - *Options*: (A) CR role persists across semester advancements, (B) CR role requires term-by-term re-assignment by Admin.
