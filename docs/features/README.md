# Feature Specifications

## 1. Feature Map & Epics

The **CSE JnU EduPortal** comprises 7 core feature epics:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        CSE JnU EduPortal Epics                         │
├─────────────────┬─────────────────┬──────────────────┬─────────────────┤
│ F01: AUTH &     │ F02: SEMESTER   │ F03: SCHEDULE &  │ F04: DYNAMIC    │
│ ONBOARDING      │ PROGRESSION     │ ROUTINE DISPATCH │ ATTENDANCE      │
├─────────────────┼─────────────────┼──────────────────┼─────────────────┤
│ F05: COUNSELING │ F06: FEEDBACK & │ F07: ADMIN &     │                 │
│ OFFICE HOURS    │ REVIEWS         │ COURSE DIRECTORY │                 │
└─────────────────┴─────────────────┴──────────────────┴─────────────────┘
```

---

## 2. Feature Epics & User Stories

### Epic F01: Authentication & Onboarding
- **US-01**: As a Student or CR, I want to request a portal account by providing my Name, Email, and Student ID so that the administration can verify and approve my enrollment.
- **US-02**: As a Professor, I want to request access using my Name, Email, and Phone Number.
- **US-03**: As an Administrator, I want a dedicated moderation queue to approve signups, which automatically creates accounts, generates initial credentials, and emails the user.
- **US-04**: As an Authenticated User, I want to sign in with my credentials and securely maintain session state via JWT tokens.

### Epic F02: Semester Lifecycle Management
- **US-05**: As a Student, I want to see my active Year and Semester (e.g. 3rd Year · 1st Semester) across all dashboard metrics.
- **US-06**: As a Student, I want to submit a semester upgrade request when advancing to the next term.
- **US-07**: As an Administrator, I want to review, approve, or reject student semester petitions with audit feedback.

### Epic F03: Daily Schedule & Routine Dispatch
- **US-08**: As a Student, I want to view today's class timetable and upcoming exam dates.
- **US-09**: As a CR, I want to schedule class slots for tomorrow for my batch and broadcast a formatted summary to WhatsApp in one tap.
- **US-10**: As a Professor, I want my dashboard to automatically highlight Today's schedule during working hours and Tomorrow's schedule in the evening.

### Epic F04: Dynamic Attendance Terminal
- **US-11**: As a Professor, I want to open an attendance session that generates a large 6-character verification code in an Obsidian Terminal.
- **US-12**: As a Student, I want to enter the 6-character code in my app to record my attendance instantly.
- **US-13**: As a Professor, I want to view the live roster and manually toggle individual student statuses.
- **US-14**: As a CR / Teacher, I want to export departmental Excel attendance sheets.

### Epic F05: Faculty Counseling & Office Hours
- **US-15**: As a Professor, I want to declare office hour slots with date and time ranges.
- **US-16**: As a Student, I want to browse open slots and request an appointment by selecting a reason category (e.g., Academic Advising, Career Guidance, Thesis).
- **US-17**: As a Professor, I want to approve a student's request, which automatically confirms the slot and politely declines other competing requests.

### Epic F06: Confidential Feedback & Quality Assurance
- **US-18**: As a Student, I want to submit 1-5 star ratings and written reviews for my course teachers with the option to remain completely anonymous.
- **US-19**: As a Professor, I want to read constructive feedback from students (with identities protected when anonymous) and post threaded responses.

### Epic F07: Admin Control & Course Directory
- **US-20**: As an Administrator, I want to search and manage departmental user records across all 4 roles.
- **US-21**: As an Administrator, I want to assign courses to faculty members.
