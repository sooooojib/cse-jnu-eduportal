# Role-Permission & Capability Matrix

This document outlines the exact permissions, data boundaries, and interface access granted to each role in the **CSE JnU EduPortal**.

---

## 1. Role Definitions

| Role Code | Display Title | Scope & Responsibility |
| :--- | :--- | :--- |
| **`STUDENT`** | Student | Enrolled undergraduate student in a specific Year/Semester and academic Session (e.g. `2021-2022`). |
| **`CR`** | Class Representative | Undergraduate student with delegated class management and WhatsApp broadcasting privileges. |
| **`TEACHER`** | Professor / Faculty | Departmental instructor managing courses, attendance, counseling, and feedback. |
| **`TEACHER` + `isAdminDelegate`** | Faculty (Signup Committee) | Faculty member granted a limited Admin View to review **Student / CR** signup requests only. Granted per person by the Admin or Chairman. |
| **`CHAIRMAN`** | Chairman of the Department | A faculty member who is also the executive head of the department. Holds every faculty capability **and** departmental admin capability, plus exclusive teacher class-delivery monitoring. |
| **`ADMIN`** | System Administrator | System moderator. Full control, including security roles and the de-anonymised feedback audit. |

Two boundaries keep the Chairman below the system Admin:
- The Chairman **cannot create, delete, edit, or promote `ADMIN` accounts**, and cannot change anyone's role (role changes are `ADMIN`-only via the `updateUserRole` Cloud Function).
- The Chairman **never sees who wrote anonymous feedback**. They teach the same students, so `feedbackIdentities` stays visible to `ADMIN` only.

---

## 2. Comprehensive Capability Matrix

Legend: **Committee** = `TEACHER` with `isAdminDelegate: true`.

| Capability / Action | `STUDENT` | `CR` | `TEACHER` | Committee | `CHAIRMAN` | `ADMIN` |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Account & Authentication** | | | | | | |
| Submit Signup Request (Students/CRs must give a Session) | ✅ | ✅ | ✅ | N/A | N/A | N/A |
| Review & Approve Student / CR Signups | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| Review & Approve Faculty Signups | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Manage User Directory & Delete (non-admin accounts) | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Create / Delete / Edit `ADMIN` accounts | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Change User Role (e.g. promote Teacher → Chairman) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Grant / Revoke Signup Committee Access | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Set a Student's Academic Session | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Dashboard** | | | | | | |
| Faculty / Admin View Switcher | ❌ | ❌ | ❌ | ✅ (Signup Committee) | ✅ (Department Admin) | ❌ (Admin Console) |
| **Semester Progression** | | | | | | |
| View Active Semester | ✅ | ✅ | N/A | N/A | N/A | N/A |
| Petition Semester Upgrade | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Approve / Reject Semester Petition | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Routine & Scheduling** | | | | | | |
| View Daily / Weekly Routine | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Edit Weekly Routine | ❌ | ❌ | ✅ (own courses) | ✅ (own courses) | ✅ | ✅ |
| One-day Class Change: extra / cancel / move (today + next 7 days) | ❌ | ✅ (own batch) | ✅ (own courses) | ✅ (own courses) | ✅ | ✅ |
| See Class Changes This Week | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Delete / Modify Any Routine Slot | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Broadcast Routine to WhatsApp | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| View Class List with roles (same semester + session) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Offer CR Role to a Classmate (takes effect on their acceptance) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Accept / Decline an Offered CR Role | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Manage Department Exams | ❌ | ✅ (own cohort) | ✅ (own courses) | ✅ (own courses) | ✅ | ✅ |
| **Attendance Verification** | | | | | | |
| Launch Dynamic Terminal (Code Gen) | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Submit 6-Char Verification Code | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| View Live Roster & Manual Toggle | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| View Personal Attendance Stats | ✅ | ✅ | N/A | N/A | N/A | N/A |
| Export Excel Attendance Sheets | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Teacher Class-Delivery Monitoring** | | | | | | |
| See every teacher's classes held per course, syllabus progress, student turnout, and estimated missed routine classes | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Counseling Office Hours** | | | | | | |
| Create & Manage Availability Slots | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| Request Appointment Slot | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Approve / Reject Booking (Mutual Lock) | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| View Personal Counseling History | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Feedback & Reviews** | | | | | | |
| Submit Rating & Feedback (1-5★) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Toggle Cryptographic Anonymity | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Read Own Received Reviews & Post Reply | ❌ | ❌ | ✅ (Anonymized) | ✅ (Anonymized) | ✅ (Anonymized) | N/A |
| Department Feedback Moderation | ❌ | ❌ | ❌ | ❌ | ✅ (Anonymized) | ✅ (Full Audit) |
| **Courses & Curriculum** | | | | | | |
| View Enrolled Courses | ✅ | ✅ | N/A | N/A | N/A | N/A |
| View Assigned Courses | N/A | N/A | ✅ | ✅ | ✅ | ✅ |
| Manage Courses (incl. target class count) | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Assign Courses to Faculty (incl. the Chairman) | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Notices** | | | | | | |
| Broadcast Departmental Notices | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Test Email Transport | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

See [chairman_and_department_oversight.md](chairman_and_department_oversight.md) for the implementation details.
