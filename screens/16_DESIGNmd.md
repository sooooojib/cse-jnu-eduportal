Viewed README.md:1-37
Viewed Lab_Assessment_Submission.md:1-100
Viewed schema.prisma:1-150
Viewed schema.prisma:151-203
Viewed migrate.js:1-74
Listed directory scripts
Viewed route.ts:1-54
# CSE JnU EduPortal — Complete Technical Design & UI/UX Specification
> **Source of Truth:** Grounded directly in `prisma/schema.prisma`, `DOCUMENTATION.md`, `Lab_Assessment_Submission.md`, `app/globals.css`, and all Next.js App Router route implementations.  
> **Institution:** Department of Computer Science & Engineering, Jagannath University (JnU)  
> **Production Target:** [`https://department-project-beta.vercel.app`](https://department-project-beta.vercel.app)
---
## 🎯 1. Codebase Purpose, Native Shapes & Core Goals
### 1.1 Core Mission & Purpose
**EduPortal** is a centralized, role-based departmental operating platform engineered to eliminate manual paper ledgers, fragmented WhatsApp/Facebook communication threads, and disjointed scheduling routines in university academic life. It unites **Students, Class Representatives (CRs), Professors (Teachers), and Department Administrators** into a singular, real-time reactive interface.
### 1.2 The Native Product Shapes
Rather than fitting generic SaaS templates, every page design is derived directly from the mathematical and relational models in `prisma/schema.prisma`:
1. **The Daily Dispatch Timeline:** `ScheduleSlot` & `Exam` — A time-aware chronological feed that locks CR allocations to tomorrow, cleans up outdated future entries automatically, and toggles professor views between *Today (05:00–17:00)* and *Tomorrow (after 17:00)*.
2. **The Dynamic Verification Terminal:** `AttendanceSession` & `Attendance` — A real-time 6-character alphanumeric verification session (`@@unique([sessionId, studentId])`) rendered in an Obsidian terminal with 7xl monospace font.
3. **The Mutual-Exclusion Slot Graph:** `CounselingSlot` & `CounselingRequest` — A one-to-many booking engine where approving a single student request automatically locks the slot (`status: BOOKED`) and batch-rejects competing student requests.
4. **The Two-Way Quality Pipeline:** `Feedback` — 1-to-5 star rating system with cryptographic identity detachment (`isAnonymous: true`), `/api/upload` file attachment attachments, and threaded teacher replies.
5. **The Semester Lifecycle Pipeline:** `User` (`year`, `semester`, `requestedYear`, `requestedSemester`, `semesterStatus`) — 4-Year × 2-Semester state machine with administrative review and rejection dismissal.
6. **The Automated Credential Gate:** `SignupRequest` — Tri-state approval pipeline with automated 8-character cryptographic password generation and Nodemailer HTML dispatch via Gmail SMTP.
---
## 🏗️ 2. Critical Files & System Architecture
```
/Users/sajib/Desktop/department-project/
├── prisma/schema.prisma              # Database schema (PostgreSQL, 9 Models, 5 Enums)
├── middleware.ts                     # NextAuth withAuth RBAC route guard & path rewrite
├── lib/
│   ├── authOptions.ts                # NextAuth CredentialsProvider & JWT session callbacks
│   ├── fetcher.ts                    # SWR fetcher with auto 401/403 session redirection
│   ├── excel.ts                      # ExcelJS multi-sheet departmental attendance generator
│   └── mailer.ts                     # Nodemailer SMTP credential dispatch engine
├── components/
│   ├── Sidebar.tsx                   # Collapsible floating island with SWR preload on hover
│   ├── SemesterSelector.tsx          # Tri-state semester promotion & change request widget
│   ├── AttendanceTable.tsx           # Live 7xl terminal generator & interactive roster table
│   ├── WhatsAppNotifier.tsx          # CR automated WhatsApp routine broadcaster
│   ├── FeedbackCard.tsx              # Threaded feedback review, filter & inline reply card
│   ├── Calendar.tsx                  # Interactive month/week counseling slot calendar
│   ├── PendingSignupsWidget.tsx      # Admin real-time registration approval queue
│   └── SemesterRequestsWidget.tsx    # Admin student semester promotion queue
└── app/
    ├── layout.tsx & globals.css      # Root font injection & Tailwind CSS v4 design tokens
    ├── (app)/
    │   ├── layout.tsx                # Authenticated App Shell with dynamic responsive sidebar
    │   ├── dashboard/
    │   │   ├── student/page.tsx      # React 19 Suspense streaming student metrics & courses
    │   │   ├── teacher/page.tsx      # Time-aware class routine & course portfolio
    │   │   ├── cr/page.tsx           # Hybrid personal stats + class scheduling bridge
    │   │   └── admin/page.tsx        # System administration, user directory & assignments
    │   ├── attendance/page.tsx       # Live code terminal, student code entry & CR downloads
    │   ├── schedule/page.tsx         # Weekly timetable matrix, CR scheduler & exam manager
    │   ├── counseling/page.tsx       # Slot creation, category booking & mutual exclusion
    │   └── feedback/page.tsx         # Rating submission, anonymous toggle & teacher inbox
    ├── login/page.tsx                # Split-panel login with custom gradient styling
    └── signup/page.tsx               # Role-based onboarding request portal
```
---
## 🎨 3. Exact Visual Design Tokens (Inherited from Codebase)
### 3.1 Design System Color Variables
- **App Canvas:** Slate-50 (`#f8fafc`) / App Light Canvas (`#f4f7f6`)
- **Card Background:** Pure White (`#ffffff`)
- **Primary Brand (Emerald):**
  - Main Action: Emerald-600 (`#059669`)
  - Hover Action: Emerald-700 (`#047857`)
  - Light Surface / Active Nav: Emerald-50 (`#ecfdf5`)
  - Active Outlines / Borders: Emerald-200 (`#a7f3d0`)
  - Glow & Shadows: `rgba(16, 185, 129, 0.3)`
- **Auth Shell Gradient:** `linear-gradient(135deg, #f1f2f1 0%, #f6f5ea 50%, #f0dfa1 100%)` on `#A4ADB4` canvas.
- **Attendance Terminal Canvas:** Obsidian Zinc-900 (`#18181b`) with Emerald-950/50 (`rgba(2, 44, 34, 0.5)`) pod and `#34d399` glowing text.
### 3.2 Role Accent Identifiers
| Role Key | Name in Code | Badge Classes (`Tailwind`) | Associated Lucide Icon |
| :--- | :--- | :--- | :--- |
| **`STUDENT`** | Student | `bg-emerald-50 text-emerald-700 border-emerald-200` | `<GraduationCap />` |
| **`TEACHER`** | Professor | `bg-blue-50 text-blue-700 border-blue-200` | `<UserCircle />` |
| **`CR`** | Class Representative | `bg-orange-50 text-orange-700 border-orange-200` | `<Users />` |
| **`ADMIN`** | Admin Manager | `bg-purple-50 text-purple-700 border-purple-200` | `<Shield />` |
---
## 📱 4. Detailed UI Design & Architecture for Every Page
---
### Page 1: Root / Landing Gateway (`app/page.tsx`)
- **Route:** `/`
- **Native Logic:** Invokes Next.js `redirect('/login')` or forwards authenticated JWT tokens directly to `/dashboard/${role.toLowerCase()}` via `middleware.ts`.
---
### Page 2: Authentication Login Page (`app/login/page.tsx`)
```
+-----------------------------------------------------------------------------------+
| Background: Steel Slate (#A4ADB4) | Font: Plus Jakarta Sans                       |
|                                                                                   |
|        +----------------- Card Box: max-w-[900px], rounded-[2.5rem] ------------+|
|        | [LEFT: Form Column - 50%]              | [RIGHT: Illustration - 50%]   ||
|        |                                        |                               ||
|        | (🛡️) EduPortal (Pill Outline)          | Modern Academic Desk          ||
|        |                                        | Illustration Artwork          ||
|        | Heading: "Log in to Portal"            | (desk_illustration.png)       ||
|        | Subhead: "Welcome back! Enter details" |                               ||
|        |                                        | "Department of Computer       ||
|        | [ Error: "Fields are required" ]       |  Science and Engineering,     ||
|        |                                        |  Jagannath University"        ||
|        | Email Address:                         |                               ||
|        | [ Enter your email                   ] | Subtle Warm Yellow Glow       ||
|        |                                        | Background Accent             ||
|        | Password:                              |                               ||
|        | [ •••••••• (tracking-widest)         ] |                               ||
|        |                                        |                               ||
|        | [ Sign In Button (Pill, h-12)        ] |                               ||
|        |                                        |                               ||
|        | Link: "Don't have an account? Sign up" |                               ||
|        +------------------------------------------------------------------------+|
+-----------------------------------------------------------------------------------+
```
#### Grounded UI Specifications:
- **Inputs:** `height: 52px`, `rounded-full`, `backgroundColor: rgba(255, 255, 255, 0.7)`, `border: 1px solid white`, focus ring `border-gray-400`.
- **Form States:**
  - `loading === true`: Disables inputs, renders spinning SVG indicator in CTA button.
  - `error`: Displays red banner (`bg-red-50 border-red-100 text-red-600 text-xs font-medium`).
- **Target Route:** On `res.ok`, routes to NextAuth callback URL or `/dashboard`.
---
### Page 3: Signup & Account Request Page (`app/signup/page.tsx`)
```
+-----------------------------------------------------------------------------------+
|        +----------------- Card Box: max-w-[900px], rounded-[2.5rem] ------------+|
|        | [LEFT: Registration Form - 50%]        | [RIGHT: Graphic Asset - 50%]  ||
|        |                                        |                               ||
|        | (🛡️) EduPortal                         | Department Illustration       ||
|        | Heading: "Create an account"           | (new_desk_illustration.png)   ||
|        | Subhead: "Get started today."          |                               ||
|        |                                        | Feature Badges:               ||
|        | Account Type:                          | • Dynamic Attendance Codes    ||
|        | [ Dropdown: Student / Teacher / CR   ] | • WhatsApp Routine Broadcasts ||
|        |                                        | • Direct Faculty Counseling   ||
|        | Full Name:                             |                               ||
|        | [ e.g. Sajib Ahmed                   ] |                               ||
|        |                                        |                               ||
|        | Student ID / Phone:                    |                               ||
|        | [ e.g. 2020CSE001 (Dynamic Label)    ] |                               ||
|        |                                        |                               ||
|        | Email Address:                         |                               ||
|        | [ name@domain.com                    ] |                               ||
|        |                                        |                               ||
|        | [ Submit Request Button              ] |                               ||
|        |                                        |                               ||
|        | Link: "Already have an account? Log in"|                               ||
|        +------------------------------------------------------------------------+|
+-----------------------------------------------------------------------------------+
```
#### Grounded UI Specifications:
- **Dynamic Field Labels:**
  - If `role === 'STUDENT' || role === 'CR'`: Label reads `Student ID`, placeholder `e.g. 2020CSE001`.
  - If `role === 'TEACHER'`: Label reads `Phone Number`, placeholder `e.g. 01700000000`.
- **Success Banner Text:** *"Your request has been sent to the admin for approval. You will receive an email with your credentials once approved."* (`bg-emerald-50 border-emerald-100 text-emerald-600`).
---
### Page 4: Student Dashboard (`app/(app)/dashboard/student/page.tsx`)
```
+-----------------------------------------------------------------------------------+
|  Student Dashboard                           [ Current Status: Year 3 Sem 1 ]     |
|                                                                                   |
|  [=== SemesterSelector: Active (Year 3 · Semester 1) [ Request Change ] =========]  |
|                                                                                   |
|  +-- React 19 Suspense Stream: Metrics Grid (5 Columns) -----------------------+  |
|  | [ Average Attendance ] [ Counseling ] [ Feedback Req ] [ Upcoming Exams ]   |  |
|  | [      88.5%         ] [  2 Active  ] [  1 Pending   ] [    3 Exams     ]   |  |
|  | [ Calculated over    ] [ Submitted  ] [ In Review    ] [ Next: Nov 15   ]   |  |
|  | [ active courses     ] [ by user    ] [ by faculty   ] [ Midterm Lab    ]   |  |
|  |-----------------------------------------------------------------------------|  |
|  | [ + Book Counseling Quick Action (Dashed Outline Card linking /counseling)]  |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-- Classes & Exams Feed (66%) -------------+ +-- Enrolled Courses (33%) --------+ |
|  | [ Today's Schedule | Upcoming Exams Tabs ] | | [ CSE-3101: Operating Systems ] | |
|  | • 09:00 AM - CSE-3101 (Room 402)           | |   Attendance: 92% [=======--]   | |
|  |   Prof. Dr. Rahman                         | | [ CSE-3103: Database Systems ]  | |
|  | • 11:30 AM - CSE-3103 (Lab 3)              | |   Attendance: 85% [======---]   | |
|  |   Dr. Farhana                              | | [ CSE-3105: Software Engg. ]   | |
|  |--------------------------------------------| |   Attendance: 78% [=====----]   | |
|  | • Midterm Exam: Nov 15, 2026 (Room 301)   | |                                 | |
|  +--------------------------------------------+ +---------------------------------+ |
+-----------------------------------------------------------------------------------+
```
#### Grounded UI Specifications:
- **React 19 Streaming Architecture:** Uses 3 independent `<Suspense>` boundaries (`MetricsSkeleton`, `ClassesSkeleton`, `CoursesSkeleton`).
- **Dynamic Semester Banner (`SemesterSelector.tsx`):**
  - Displays Roman-formatted labels: `"1st Year · 1st Semester"`, `"3rd Year · 2nd Semester"`.
  - Amber state if `semesterStatus === 'PENDING'`.
  - Red alert if `semesterStatus === 'REJECTED'` with re-application dropdowns.
- **Course Progress Bars:** Calculated in real-time from `Attendance` where `session.courseId === course.id`.
---
### Page 5: Teacher (Professor) Dashboard (`app/(app)/dashboard/teacher/page.tsx`)
```
+-----------------------------------------------------------------------------------+
|  Professor Dashboard                              [ Time period: This Month ▾ ]   |
|                                                                                   |
|  +-- Metric Cards (3 Columns) -------------------------------------------------+  |
|  | [ Pending Counseling ]    [ Feedback Received ]     [ Classes Taught ]      |  |
|  | [         4          ]    [        18         ]     [       12       ]      |  |
|  | [ Requires action    ]    [ ★ 4.8 Rating Avg  ]     [ This Semester  ]      |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-- Time-Aware Class Schedule (66%) --------+ +-- Courses Assigned (33%) --------+ |
|  | Title: "Today's Classes" (05:00 - 17:00)   | | [ CSE-3101: Operating Systems ] | |
|  | Flips to "Tomorrow's Classes" at Night!   | |   Credit: 3.0 · Year 3 Sem 1    | |
|  | • 10:00 AM - 11:30 AM                     | |   Type: Major Theory            | |
|  |   Operating Systems (Room A - 204)        | |                                 | |
|  | • 02:00 PM - 03:30 PM                     | | [ CSE-4107: Distributed Systems]| |
|  |   System Design (Science Complex - 302)   | |   Credit: 3.0 · Year 4 Sem 1    | |
|  |--------------------------------------------| |   Type: Major Theory            | |
|  | [ Upcoming Department Exams ]              | |                                 | |
|  | • Final Lab Assessment — Dec 02            | | [ + Assigned Course Indicator ] | |
|  +--------------------------------------------+ +---------------------------------+ |
+-----------------------------------------------------------------------------------+
```
#### Grounded UI Specifications:
- **Time-Aware Algorithm:** Uses `now.getHours()`: If between `5` and `17`, queries `startOfToday()` to `endOfToday()`; otherwise queries `startOfTomorrow()` to `endOfTomorrow()`.
- **Room Allocation Algorithm:** Deterministic hash `hash = id.split('').reduce(...)` generating realistic rooms: `Building [A, B, C, Science Complex, Main Hall] - Room ${(hash % 400) + 101}`.
- **Assigned Course Card:** `border-t-4 border-t-emerald-500 rounded-xl bg-slate-50 hover:bg-white`.
---
### Page 6: Class Representative (CR) Dashboard (`app/(app)/dashboard/cr/page.tsx`)
```
+-----------------------------------------------------------------------------------+
|  Class Representative Dashboard              [ Current Status: Year 2 Sem 2 ]     |
|                                                                                   |
|  [=== SemesterSelector: Active (Year 2 · Semester 2) [ Request Change ] =========]  |
|                                                                                   |
|  +-- Hybrid Metric Cards (5 Columns) ------------------------------------------+  |
|  | [ My Attendance ] [ Classes Today ] [ Counseling Slots ] [ Upcoming Exams ]  |  |
|  | [     94.2%     ] [    3 Slots    ] [   5 Available    ] [    2 Exams   ]  |  |
|  | [ Personal Stat ] [ Active Today  ] [ Across Dept      ] [ This Term    ]  |  |
|  |-----------------------------------------------------------------------------|  |
|  | [ 📅 Manage Tomorrow's Schedule (Direct CR Quick Action to /schedule)     ] |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-- CR Class Schedule & Routine (66%) ------+ +-- Semester Courses (33%) --------+ |
|  | • Booked routine timetable with rooms     | | • List of Semester Courses       | |
|  | • Direct "Broadcast on WhatsApp" Action   | | • Personal Attendance Progress   | |
|  | • Scheduled Exam Notifications            | | • Download Attendance Summary    | |
|  +--------------------------------------------+ +---------------------------------+ |
+-----------------------------------------------------------------------------------+
```
#### Grounded UI Specifications:
- Combines individual student learning progress with administrative shortcuts for daily class management.
- Quick navigation button directly links to `/schedule` with CR allocation privileges enabled.
---
### Page 7: Admin Dashboard & System Administration (`app/(app)/dashboard/admin/page.tsx`)
```
+-----------------------------------------------------------------------------------+
|  Admin Dashboard & Control Center                       [ + Create New User ]     |
|                                                                                   |
|  +-- Pending Approvals Matrix (2 Split Columns) -------------------------------+  |
|  | [ Pending Signup Requests (New User Registrations) ]                        |  |
|  | • Tanvir Ahmed (2023CSE012) -> [ Approve (Generates Pass & Emails) ] [Reject] |
|  | • Dr. Kamal Hossain (Teacher)-> [ Approve (Generates Pass & Emails) ] [Reject] |
|  |-----------------------------------------------------------------------------|  |
|  | [ Pending Semester Upgrade Requests ]                                       |  |
|  | • Nusrat Jahan (2021CSE045) -> Request: Year 3 Sem 1  [ Approve ] [ Reject ]|  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-- Department User Management Directory ------------------------------------+  |
|  | [ Filter Tabs: Teachers | Students | Class Representatives ]  [ Search... ] |
|  |-----------------------------------------------------------------------------|  |
|  | User / Identifer    | Role Badge | Assigned Courses   | Created  | Actions  |  |
|  |--------------------|------------|--------------------|----------|----------|  |
|  | Prof. Dr. Rahman   | TEACHER    | 3 Courses [Manage] | Jan 2026 | [Trash]  |  |
|  | Sajib Ahmed        | CR         | Year 3 · Sem 1     | Feb 2026 | [Trash]  |  |
|  | Ayesha Siddiqua    | STUDENT    | Year 2 · Sem 2     | Mar 2026 | [Trash]  |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```
#### Integrated Admin Modals:
1. **Teacher Course Assignment Modal (`openCourseModal`):**
   - Displays all courses grouped by `Year X - Semester Y`.
   - Checkbox matrix for assigning/unassigning courses via `POST /api/admin/users/{userId}/courses`.
2. **Direct User Creation Modal (`handleCreateUser`):**
   - Direct provisioning for any role (`STUDENT`, `TEACHER`, `CR`, `ADMIN`) with custom password.
---
### Page 8: Attendance Management Page (`app/(app)/attendance/page.tsx`)
#### A. Student & CR Code Entry View:
```
+-----------------------------------------------------------------------------------+
|  Course Attendance Verification                                                   |
|                                                                                   |
|  +-- Verification Container (max-w-xl mx-auto) --------------------------------+  |
|  | Select Course: [ CSE-3101: Operating Systems ▾ ]                            |  |
|  |                                                                             |  |
|  | Enter 6-Digit Active Verification Code:                                     |  |
|  | [   K   ] [   7   ] [   X   ] [   9   ] [   2   ] [   M   ]                   |  |
|  |                                                                             |  |
|  | [ Submit Attendance Verification (Emerald Button) ]                         |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-- Course Attendance History Grid -------------------------------------------+  |
|  | CSE-3101: 94% Present  |  CSE-3103: 88% Present  |  CSE-3105: 100% Present   |  |
|  | History: Dec 10 (PRESENT) · Dec 08 (PRESENT) · Dec 05 (ABSENT)              |  |
|  +-----------------------------------------------------------------------------+  |
|  +-- CR Exclusive Widget: [ 📥 Export Class Attendance (ExcelJS) ] ------------+  |
+-----------------------------------------------------------------------------------+
```
#### B. Teacher & Admin Live Terminal & Roster View:
```
+-----------------------------------------------------------------------------------+
|  Course Administration & Live Attendance Terminal                                 |
|  Select Course: [ CSE-3101: Operating Systems ▾ ]                                 |
|                                                                                   |
|  +-- Dynamic Terminal Pod (Obsidian Zinc-900 Canvas) --------------------------+  |
|  |                                                                             |  |
|  |    ACTIVE VERIFICATION CODE                                                 |  |
|  |    +------------------------------------------------------------------+     |  |
|  |    |                     K 7 X 9 2 M                                  |     |  |
|  |    +------------------------------------------------------------------+     |  |
|  |    (Emerald 400, 7xl font, letter-spacing 0.25em, font-mono)                |  |
|  |                                                                             |  |
|  |    [ Deactivate Code ]    [ Regenerate Code ]    [ 📥 Export Excel Report ]  |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-- Live Roster Table & Bulk Toggles -----------------------------------------+  |
|  | [ Mark All Present ]  [ Mark All Absent ]  [ Search Student Name / ID ]     |  |
|  |-----------------------------------------------------------------------------|  |
|  | Student ID   | Student Name         | Status Badge        | Action Toggle   |  |
|  |--------------|----------------------|---------------------|-----------------|  |
|  | 2022CSE001   | Farhan Tanvir        | [ PRESENT (Green) ] | [ Toggle Status]|  |
|  | 2022CSE002   | Sadia Islam          | [ ABSENT (Red) ]    | [ Toggle Status]|  |
|  |-----------------------------------------------------------------------------|  |
|  | [ Save Attendance Session (Persists Roster & Schedule Slot) ]               |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```
---
### Page 9: Academic Schedule & Routine Page (`app/(app)/schedule/page.client.tsx`)
```
+-----------------------------------------------------------------------------------+
|  Academic Schedule & Routine Hub                  [ + Schedule Class (CR Only) ]  |
|                                                   [ 📲 Broadcast on WhatsApp ]    |
|                                                                                   |
|  +-- Navigation Tabs: [ Weekly Routine Grid ]  [ Upcoming Exams ]  [ Past Exams ] +
|                                                                                   |
|  +-- Weekly Schedule Matrix ---------------------------------------------------+  |
|  | Time Slot    | Sunday    | Monday    | Tuesday   | Wednesday | Thursday    |  |
|  |--------------|-----------|-----------|-----------|-----------|-------------|  |
|  | 09:00-10:30  | CSE-3101  | CSE-3103  | CSE-3101  | CSE-3105  | Lab Session |  |
|  |              | Room 402  | Lab 2     | Room 402  | Room 301  | Lab 1       |  |
|  | 10:45-12:15  | CSE-3107  | CSE-3101  | Break     | CSE-3103  | CSE-3107    |  |
|  | 01:30-03:00  | Seminar   | Project   | Counseling| Open Slot | Dept Meet   |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-- Exam Routine Manager -----------------------------------------------------+  |
|  | • Midterm Assessment: Operating Systems — Dec 12, 2026 @ 10:00 AM (Room 402)|  |
|  | • Term Final: Database Systems — Jan 05, 2027 @ 02:00 PM (Science Complex) |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```
#### Grounded Protocol & Engine Rules:
1. **CR Tomorrow-Only Restriction:** Date input locked with `min={startOfTomorrow()}` and `max={endOfTomorrow()}`.
2. **Auto-Cleanup Engine:** Cleans up future booked slots past tomorrow on mount to avoid stale schedules.
3. **Automated WhatsApp Routine Formatter (`WhatsAppNotifier.tsx`):**
   - Formats message:
     ```
     📚 *CSE Department Class Routine for Tomorrow*
     📅 Date: DD/MM/YYYY
     
     1️⃣ *CSE-3101: Operating Systems*
     ⏰ Time: 09:00 AM - 10:30 AM
     👨‍🏫 Teacher: Prof. Dr. Rahman
     📍 Room: Room 402
     ```
   - Automatically invokes `window.open('https://api.whatsapp.com/send?text=...')`.
---
### Page 10: Teacher-Student Counseling & Office Hours Page (`app/(app)/counseling/page.tsx`)
```
+-----------------------------------------------------------------------------------+
|  Faculty Office Hours & Counseling Appointments      [ + Open New Slot (Teacher)] |
|                                                                                   |
|  +-- Visual Interactive Slot Calendar (`components/Calendar.tsx`) -------------+  |
|  | [ Month / Week View ]   < November 2026 >                                  |  |
|  | Sun        Mon        Tue        Wed        Thu        Fri        Sat      |  |
|  | 15         16         17         18         19         20         21       |  |
|  |            [10:00 AM] [02:00 PM] [11:30 AM]                                |  |
|  |            Prof Rahman Dr Farhana Open Slot                                |  |
|  |            (Available)(Booked)   (2 Pending)                               |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-- Student Booking Modal (Active upon slot click) ---------------------------+  |
|  | Slot: Nov 18, 2026 (11:30 AM - 12:30 PM) · Prof. Dr. Rahman                |  |
|  | Select Reason Category:                                                     |  |
|  | (•) Academic Advising   ( ) Research Discussion   ( ) Mental Pressure       |  |
|  | ( ) Class Issue         ( ) Career Guidance       ( ) Other                 |  |
|  |                                                                             |  |
|  | Specific Note: [ Detailed discussion points...                            ] |  |
|  | [ Confirm Appointment Request (Emerald CTA) ]                               |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```
#### Grounded Mutual-Exclusion Engine:
- **Teacher Approval (`manageRequest(requestId, 'APPROVED')`):** Approving one request updates `slot.status = 'BOOKED'` and changes all other student requests for that slot to `'REJECTED'`.
---
### Page 11: Feedback, Rating & Teacher Reply System (`app/(app)/feedback/page.tsx`)
```
+-----------------------------------------------------------------------------------+
|  Department Feedback & Quality Assurance                                          |
|  Confidential feedback system for continuous academic improvement.                |
|                                                                                   |
|  +-- Student Feedback Submission Form (Student/CR View) -----------------------+  |
|  | Select Teacher: [ Prof. Dr. Rahman ▾ ]   Rating: [ ★★★★★ (5 Stars) ▾ ]     |  |
|  |                                                                             |  |
|  | Comments:                                                                   |  |
|  | [ Write constructive feedback regarding lectures or course content...     ] |  |
|  |                                                                             |  |
|  | [✓] Submit Anonymously (Hide my identity from the teacher)                   |  |
|  | [📎 Attach Document / Screenshot (/api/upload)]                             |  |
|  |                                                                             |  |
|  | [ Submit Feedback (Emerald Button) ]                                        |  |
|  +-----------------------------------------------------------------------------+  |
|                                                                                   |
|  +-- Feedbacks Stream & Teacher Reply Cards (`components/FeedbackCard.tsx`) ---+  |
|  | Filter Tabs: [ All Feedbacks (18) ]  [ Replied (14) ]  [ Not Replied (4) ]  |  |
|  |-----------------------------------------------------------------------------|  |
|  | [ Card 1: ★★★★★ by Anonymous Student · 2 days ago ]                         |  |
|  | "The database indexing lecture was very helpful. Could we have more labs?"  |  |
|  |                                                                             |  |
|  |    ↳ [ Professor's Reply - Dr. Rahman ] (Indigo Bordered Box)               |  |
|  |      "Thank you! We will allocate 2 additional hands-on query lab sessions."|  |
|  |      [ Edit Reply ]                                                         |  |
|  +-----------------------------------------------------------------------------+  |
+-----------------------------------------------------------------------------------+
```
#### Grounded Anonymity & Moderation Architecture:
- **Student Privacy:** If `isAnonymous === true`, `FeedbackCard.tsx` renders `"Anonymous Student"` on Teacher views.
- **Admin Visibility:** Administrators retain full identity audit rights to ensure departmental accountability.
- **Two-Way File Attachments:** Supports PDFs, code snippets, and screenshots on both original feedback and faculty replies.
---
## 📊 5. Complete Application Route & Component Directory
| Route URI | Server / Client Entry File | Access Role(s) | Primary Purpose |
| :--- | :--- | :--- | :--- |
| **`/`** | [app/page.tsx](file:///Users/sajib/Desktop/department-project/app/page.tsx) | Public | Redirect gateway |
| **`/login`** | [app/login/page.tsx](file:///Users/sajib/Desktop/department-project/app/login/page.tsx) | Unauthenticated | NextAuth Credentials login |
| **`/signup`** | [app/signup/page.tsx](file:///Users/sajib/Desktop/department-project/app/signup/page.tsx) | Unauthenticated | Role-based signup request submission |
| **`/dashboard/student`** | [app/(app)/dashboard/student/page.tsx](file:///Users/sajib/Desktop/department-project/app/%28app%29/dashboard/student/page.tsx) | `STUDENT` | Streaming metrics, schedule & courses |
| **`/dashboard/teacher`** | [app/(app)/dashboard/teacher/page.tsx](file:///Users/sajib/Desktop/department-project/app/%28app%29/dashboard/teacher/page.tsx) | `TEACHER` | Time-aware routine & assigned courses |
| **`/dashboard/cr`** | [app/(app)/dashboard/cr/page.tsx](file:///Users/sajib/Desktop/department-project/app/%28app%29/dashboard/cr/page.tsx) | `CR` | Hybrid student metrics & CR routine controls |
| **`/dashboard/admin`** | [app/(app)/dashboard/admin/page.tsx](file:///Users/sajib/Desktop/department-project/app/%28app%29/dashboard/admin/page.tsx) | `ADMIN` | Signups queue, promotions & user directory |
| **`/attendance`** | [app/(app)/attendance/page.tsx](file:///Users/sajib/Desktop/department-project/app/%28app%29/attendance/page.tsx) | `ALL ROLES` | Live 6-digit code generator & student entry |
| **`/schedule`** | [app/(app)/schedule/page.tsx](file:///Users/sajib/Desktop/department-project/app/%28app%29/schedule/page.tsx) | `ALL ROLES` | Routine matrix, CR scheduler & WhatsApp notifier |
| **`/counseling`** | [app/(app)/counseling/page.tsx](file:///Users/sajib/Desktop/department-project/app/%28app%29/counseling/page.tsx) | `ALL ROLES` | Interactive calendar, bookings & mutual exclusion |
| **`/feedback`** | [app/(app)/feedback/page.tsx](file:///Users/sajib/Desktop/department-project/app/%28app%29/feedback/page.tsx) | `ALL ROLES` | 1-5 star ratings, anonymous reviews & teacher replies |