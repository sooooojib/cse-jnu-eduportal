# Role-Permission & Capability Matrix

This document outlines the exact permissions, data boundaries, and interface access granted to each role in the **CSE JnU EduPortal**.

---

## 1. Role Definitions

| Role Code | Display Title | Scope & Responsibility |
| :--- | :--- | :--- |
| **`STUDENT`** | Student | Enrolled undergraduate student in a specific Year/Semester. |
| **`CR`** | Class Representative | Undergraduate student with delegated class management and WhatsApp broadcasting privileges. |
| **`TEACHER`** | Professor / Faculty | Departmental instructor managing courses, attendance, counseling, and feedback. |
| **`ADMIN`** | Department Administrator | System moderator managing accounts, courses, and semester approvals. |

---

## 2. Comprehensive Capability Matrix

| Capability / Action | `STUDENT` | `CR` | `TEACHER` | `ADMIN` |
| :--- | :---: | :---: | :---: | :---: |
| **Account & Authentication** | | | | |
| Submit Signup Request | ✅ | ✅ | ✅ | N/A |
| Review & Approve Signups | ❌ | ❌ | ❌ | ✅ |
| Manage User Directory & Delete | ❌ | ❌ | ❌ | ✅ |
| **Semester Progression** | | | | |
| View Active Semester | ✅ | ✅ | N/A | N/A |
| Petition Semester Upgrade | ✅ | ✅ | ❌ | ❌ |
| Approve / Reject Semester Petition | ❌ | ❌ | ❌ | ✅ |
| **Routine & Scheduling** | | | | |
| View Daily / Weekly Routine | ✅ | ✅ | ✅ | ✅ |
| Add Class Slot for Tomorrow | ❌ | ✅ | ❌ | ✅ |
| Delete / Modify Routine Slot | ❌ | ❌ | ❌ | ✅ |
| Broadcast Routine to WhatsApp | ❌ | ✅ | ❌ | ❌ |
| Manage Department Exams | ❌ | ❌ | ✅ | ✅ |
| **Attendance Verification** | | | | |
| Launch Dynamic Terminal (Code Gen) | ❌ | ❌ | ✅ | ✅ |
| Submit 6-Char Verification Code | ✅ | ✅ | ❌ | ❌ |
| View Live Roster & Manual Toggle | ❌ | ❌ | ✅ | ✅ |
| View Personal Attendance Stats | ✅ | ✅ | N/A | N/A |
| Export Excel Attendance Sheets | ❌ | ✅ | ✅ | ✅ |
| **Counseling Office Hours** | | | | |
| Create & Manage Availability Slots | ❌ | ❌ | ✅ | ❌ |
| Request Appointment Slot | ✅ | ✅ | ❌ | ❌ |
| Approve / Reject Booking (Mutual Lock)| ❌ | ❌ | ✅ | ❌ |
| View Personal Counseling History | ✅ | ✅ | ✅ | ✅ |
| **Feedback & Reviews** | | | | |
| Submit Rating & Feedback (1-5★) | ✅ | ✅ | ❌ | ❌ |
| Toggle Cryptographic Anonymity | ✅ | ✅ | ❌ | ❌ |
| Read Received Reviews & Post Reply | ❌ | ❌ | ✅ (Anonymized) | ✅ (Full Audit) |
| **Courses & Curriculum** | | | | |
| View Enrolled Courses | ✅ | ✅ | N/A | N/A |
| View Assigned Courses | N/A | N/A | ✅ | ✅ |
| Assign Courses to Faculty | ❌ | ❌ | ❌ | ✅ |
