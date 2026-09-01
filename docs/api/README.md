# CSE JnU EduPortal — REST API Specifications

This directory contains the complete API specifications, protocol conventions, error handling architectures, and resource endpoint catalogs for the new **CSE JnU EduPortal** backend.

---

## 📚 API Specifications Index

| Document | Topic | Description |
| :--- | :--- | :--- |
| [`api_overview.md`](api_overview.md) | **API Architecture & Overview** | Base URL, security layers, JWT authentication headers, and Flutter client guidelines. |
| [`api_conventions.md`](api_conventions.md) | **Conventions & Standards** | RESTful URI conventions, standard success/paginated response envelopes, query parameters. |
| [`error_handling.md`](error_handling.md) | **Error Handling & Codes** | Standard error envelopes, validation errors, HTTP status code mappings, and error code catalog. |
| [`authentication_api.md`](authentication_api.md) | **Authentication & Onboarding** | Login, signup requests, token refresh, password changes, and `/me` session profile. |
| [`user_api.md`](user_api.md) | **Users, Profiles & Notifications**| Profile updates, custom avatar uploads, faculty directory, and in-app notifications. |
| [`course_api.md`](course_api.md) | **Courses & Semesters** | Curriculum catalog, enrolled courses with attendance metrics, and semester upgrade petitions. |
| [`attendance_api.md`](attendance_api.md) | **Attendance & Verification Terminal** | 6-char live terminal code generator, student code entry, roster overrides, and Excel exports. |
| [`schedule_api.md`](schedule_api.md) | **Schedule & Routine** | Weekly timetable matrix, time-aware daily schedule, CR tomorrow-only lock, and WhatsApp broadcaster. |
| [`exam_api.md`](exam_api.md) | **Exams & Assessments** | Midterm, lab, and final exam scheduling with classroom assignments and countdowns. |
| [`counseling_api.md`](counseling_api.md) | **Faculty Counseling** | Availability slots, student booking petitions with reason categories, and mutual-exclusion locking. |
| [`feedback_api.md`](feedback_api.md) | **Feedback & Attachments** | 1–5 star ratings, anonymity detachment, threaded teacher replies, and 10MB multi-format uploads. |
| [`admin_api.md`](admin_api.md) | **Admin Control & Directory** | Onboarding approvals, semester petitions, user directory management, and course assignment matrix. |
