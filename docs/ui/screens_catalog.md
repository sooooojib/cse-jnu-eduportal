# Mobile Screen Catalog & Interaction Matrix

This document maps all 17 mobile screen specifications in the **CSE JnU EduPortal** design system, including target roles, primary interactions, and layout structures.

---

## 1. Authentication & Onboarding Screens

### Screen 06: Login Portal (`LoginScreen`)
- **Target Role**: Public / Unauthenticated
- **Visuals**: Split-card aesthetic with soft warm glow accent, pill inputs (52px), password reveal toggle.
- **Interactions**:
  - Validates email and password format.
  - Dispatches `login` intent to Auth Bloc/Notifier.
  - Navigates to role-specific dashboard on success.
  - Link to Signup Request screen.

### Screen 11: Signup Request Portal (`SignupScreen`)
- **Target Role**: Public / Unauthenticated
- **Visuals**: Role selector dropdown (Student, Teacher, CR), dynamic input labels (`Student ID` vs `Phone Number`), confirmation alert.
- **Interactions**:
  - Submits registration request to backend queue.
  - Displays persistent confirmation alert advising the user that administrative approval and credential generation are underway.

---

## 2. Role Dashboards

### Screen 15: Student Dashboard (`StudentDashboardScreen`)
- **Target Role**: `STUDENT`
- **Visuals**: Active semester indicator pill, 4-metric statistics grid (Average Attendance %, Counseling Active, Feedback In Review, Upcoming Exams), class schedule feed, enrolled courses with progress indicators.
- **Interactions**:
  - Tap semester banner to launch `SemesterChangeBottomSheet`.
  - Tap "Book Counseling" quick-action to jump to `/counseling`.
  - Tap course card to view detailed attendance history.

### Screen 14: CR Dashboard (`CRDashboardScreen`)
- **Target Role**: `CR`
- **Visuals**: Hybrid student metrics + class management hub, "Manage Tomorrow's Schedule" hero quick-action, today's schedule feed with one-tap WhatsApp broadcaster.
- **Interactions**:
  - Direct shortcut to CR schedule manager (`/schedule/cr-manage`).
  - WhatsApp broadcast button formatting tomorrow's routine.

### Screen 01: Professor Dashboard (`ProfessorDashboardScreen`)
- **Target Role**: `TEACHER`
- **Visuals**: Time-aware schedule card (Today's classes 05:00-17:00 / Tomorrow's classes post 17:00), 3-column metric cards (Pending Counseling, Feedback Received, Classes Taught), assigned course portfolio.
- **Interactions**:
  - Tap class card to immediately launch dynamic attendance terminal for that course.
  - Review pending counseling counter to open counseling approvals.

### Screen 13: Admin Dashboard (`AdminDashboardScreen`)
- **Target Role**: `ADMIN`
- **Visuals**: Dual-column pending approval matrices (Pending Signups & Pending Semester Upgrades), quick user creation action button, system metrics.
- **Interactions**:
  - One-tap approve/reject on signup requests (triggers automated credential generation).
  - One-tap approve/reject on semester upgrade petitions.

---

## 3. Attendance Management Screens

### Screen 04: Professor Attendance Terminal (`ProfessorAttendanceScreen`)
- **Target Role**: `TEACHER`, `ADMIN`
- **Visuals**: Obsidian Zinc-900 canvas, prominent 6-character verification code in glowing JetBrains Mono font (7xl), session timer, live student roster table with bulk and individual toggle switches.
- **Interactions**:
  - "Deactivate Code" and "Regenerate Code" actions.
  - Real-time roster updates as students verify.
  - Manual toggle between `PRESENT` and `ABSENT`.
  - "Export Excel Report" binary download.

### Screen 05: Student Attendance Portal (`StudentAttendanceScreen`)
- **Target Role**: `STUDENT`
- **Visuals**: 6-box OTP-style alphanumeric code entry field, course selector dropdown, course-by-course percentage progress bars and historical verification logs.
- **Interactions**:
  - Auto-submits on 6th character entry.
  - Shows animated success state and refreshes course attendance percentage.

### Screen 07: CR Attendance Hub (`CRAttendanceScreen`)
- **Target Role**: `CR`
- **Visuals**: Personal verification code entry panel + class-wide attendance summary metrics + "Export Class Attendance (Excel)" action.

---

## 4. Timetable, Routine & Exams

### Screen 10: Student Schedule Hub (`StudentScheduleScreen`)
- **Target Role**: `STUDENT`
- **Visuals**: Weekly routine timetable matrix (Sunday–Thursday), Room identifiers, upcoming exam countdown cards.

### Screen 12: CR Schedule Manager (`CRScheduleScreen`)
- **Target Role**: `CR`
- **Visuals**: Tomorrow-locked date selector, course and professor selector, room picker, "Broadcast on WhatsApp" floating button.
- **Interactions**:
  - Adds routine slots strictly for tomorrow.
  - Automatically sanitizes and syncs with backend schedule.

### Screen 17: Professor Schedule Hub (`ProfessorScheduleScreen`)
- **Target Role**: `TEACHER`
- **Visuals**: Course-wise weekly timetable, room allocation tags, upcoming departmental examination supervisor schedules.

---

## 5. Counseling Office Hours

### Screen 03: Student Counseling Portal (`StudentCounselingScreen`)
- **Target Role**: `STUDENT`, `CR`
- **Visuals**: Interactive calendar month/week picker, availability slot tags (Available, Booked, Pending), booking reason category modal (Academic Advising, Research, Career, Class Issue, Other).
- **Interactions**:
  - Tap open slot to submit appointment petition with category and notes.
  - View status of submitted petitions (`PENDING`, `APPROVED`, `REJECTED`).

---

## 6. Feedback & Reviews

### Screen 02: Student Feedback Portal (`StudentFeedbackScreen`)
- **Target Role**: `STUDENT`, `CR`
- **Visuals**: Teacher selector, 5-star interactive rating widget, constructive text input, "Submit Anonymously" toggle switch, file attachment picker.
- **Interactions**:
  - Validates rating and character minimum.
  - Uploads attachments and dispatches review.

### Screen 09: Professor Feedback Inbox (`ProfessorFeedbackScreen`)
- **Target Role**: `TEACHER`
- **Visuals**: Average star rating summary, filter tabs (All, Replied, Not Replied), feedback cards (with `"Anonymous Student"` identity masking), threaded reply interface.
- **Interactions**:
  - Post official faculty replies to student reviews.

---

## 7. Administration & Directory

### Screen 08: Admin Directory Portal (`AdminDirectoryScreen`)
- **Target Role**: `ADMIN`
- **Visuals**: Role filter tabs (Teachers, Students, CRs), live search bar, user cards with assigned courses and role badges, delete action, "Assign Courses" modal.
- **Interactions**:
  - Manage course-to-teacher assignments via multi-select modal.
  - Provision or deactivate users.
