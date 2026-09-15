# Project Proposal: CSE JnU EduPortal
## A Role-Based Academic Management & Real-Time Engagement Mobile Ecosystem
**Department of Computer Science & Engineering, Jagannath University (JnU)**

---

## Document Metadata

| Attribute | Details |
|:---|:---|
| **Project Title** | CSE JnU EduPortal |
| **Institution** | Department of Computer Science & Engineering, Jagannath University (JnU), Dhaka, Bangladesh |
| **Document Type** | Formal Academic & Engineering Project Proposal |
| **Duration** | 14-Week Agile Development & Delivery Cycle |
| **Architecture** | Feature-Driven Clean Architecture (Flutter Mobile Client + Firebase Serverless Cloud Engine) |
| **Design System** | Emerald Scholar System (Material 3 + Obsidian Dynamic Terminal Canvas) |
| **Target Platforms** | Android, iOS, and Administrative Web Console |
| **Prepared For** | Department Chairman, Faculty Evaluation Board, and Academic Supervisors |
| **Date** | September 2026 |
| **Version** | 2.0.0 (Production Firebase-First Edition) |

---

## 1. Executive Summary

The **Department of Computer Science & Engineering at Jagannath University (JnU)** operates a rigorous 4-year undergraduate B.Sc. (Engineering) curriculum across 8 academic semesters alongside M.Sc. postgraduate programs. Currently, day-to-day departmental operations, student-faculty communication, and academic tracking suffer from severe procedural fragmentation:
* Paper-based attendance rolls consume 7–12 minutes of every lecture, are susceptible to physical damage or proxy attendance, and require hours of manual calculation at the end of the term to determine exam eligibility.
* Class routine adjustments, exam notifications, and room allocations are disseminated haphazardly across informal social media groups where announcements are easily buried.
* Faculty office hours for academic counseling lack structured booking, causing students to wander departmental hallways while professors face unscheduled walk-ins during critical research hours.
* Students lack a secure, confidential feedback mechanism to communicate concerns regarding course pacing, lab hardware, or curriculum comprehension without fear of academic retribution.

**CSE JnU EduPortal** is an end-to-end, role-based academic mobile ecosystem engineered from ground zero to digitize, unify, and automate departmental operations. Built strictly adhering to **Feature-Driven Clean Architecture**, the ecosystem unites a cross-platform **Flutter** mobile client with the **Firebase Serverless Cloud Engine** (Cloud Firestore, Firebase Authentication, Cloud Functions Gen 2, Cloud Storage, and Firebase Cloud Messaging).

The platform serves four primary departmental stakeholders:

1. **Students (General Learners)**:
   - Submit live 6-digit attendance codes in under five seconds during lecture sessions.
   - Track real-time attendance compliance with Collegiate (≥75%), Non-Collegiate (60–74%), and Discollegiate (<60%) exam eligibility badges.
   - Access time-aware daily class timetables, lecture room alerts, exam schedules, and countdown badges.
   - Book 15-minute faculty counseling slots and submit 100% cryptographically anonymous course appraisals without retribution fears.

2. **Class Representatives (CRs) (Student Coordinators)**:
   - Retain full standard student capabilities while serving as the primary digital coordinator for their academic batch.
   - Adjust and update tomorrow's class schedule (room swaps, time changes) under a strict "tomorrow-only" security lock.
   - Generate cleanly formatted WhatsApp daily routine broadcasts with a single tap for instant sharing in batch groups.
   - Monitor batch-wide attendance trends to alert peers who are at risk of falling below the 75% examination eligibility threshold.

3. **Faculty / Professors (Instructors & Counselors)**:
   - Launch live dynamic 6-digit attendance code terminals on mobile or projector with customizable 30s/60s/90s countdown timers.
   - Monitor incoming student submissions on a real-time live roster and apply manual attendance overrides (Present/Absent/Late).
   - Publish weekly office hour consultation blocks and seamlessly accept, decline, or reschedule student appointment requests.
   - Review aggregated anonymous student course evaluations and publish official threaded replies to clarify coursework or pacing.

4. **Department Administrators (Chairman & Department Staff)**:
   - Enforce tri-state account verification (`PENDING` ➔ `ACTIVE`/`REJECTED`) to authenticate student rolls and faculty designations.
   - Execute automated batch semester promotions at the end of each term to advance cohorts from 1st through 8th semester.
   - Manage the departmental curriculum catalog, configure course credit hours, and assign specific courses to faculty members.
   - Export formatted, official attendance spreadsheets (`.xlsx`) for the University Exam Controller Office and oversee the user directory.

This proposal provides a comprehensive blueprint for the project across 5 foundational sections:
1. **Executive Summary**
2. **Problem Statement & Motivation**
3. **Technical Specifications**
4. **Development Plan: 14-Week Cycle** (highlighting **Weeks 1–2** dedicated to the complete Multi-Role Authentication, Login, Signup & Verification Engine)
5. **Cost Analysis & Budget in Free Tier in Bangladeshi Taka (৳ BDT)**, including **Table 2: Optional: Google Play Store Listing Costs**.

---

## 2. Problem Statement & Motivation

### 2.1 Current Departmental Challenges

| Traditional Problem Area | Operational Bottleneck & Failure Mode | CSE JnU EduPortal Solution |
|:---|:---|:---|
| **Manual Paper Attendance Registers** | Traditional roll calls consume 15% of lecture time. Physical attendance registers are vulnerable to tears, moisture, and proxy signatures. Manual calculation of semester percentages across 50+ students per batch takes days. | **Dynamic 6-Digit Code Terminal** with an animated countdown timer (30s/60s/90s), instant client verification (<200ms), automated real-time compliance calculation, and 1-click Excel (`.xlsx`) export for exam committees. |
| **Fragmented Routine Dissemination** | Class changes, rescheduled lab slots, and room relocations are posted across informal WhatsApp/Facebook groups, leading to missed classes and communication chaos. | **Centralized Timetable Matrix** with automated day-highlighting, CR "Tomorrow-Only" edit lock, and a **Single-Tap WhatsApp Broadcast Generator** that formats routine messages instantly. |
| **Unstructured Academic Counseling** | Students struggle to find available faculty for thesis guidance and academic doubts, leading to unscheduled office interruptions during research hours. | **Faculty Office Hours Reservation System** allowing professors to publish weekly availability blocks and students to reserve 15-minute slots with categorical reasons and mutual-exclusion booking locks. |
| **Absence of Candid Academic Feedback** | Students hesitate to provide honest feedback regarding teaching pace or lab equipment due to retribution fears. Faculty receive zero structured mid-semester signals. | **Cryptographically Anonymized Feedback Pipeline** with 1–5 star ratings and detached user IDs, allowing students to submit candid course appraisals and professors to post public threaded replies. |
| **Unverified Digital Identities & Access** | Public social groups lack identity verification, allowing external or unapproved accounts into sensitive departmental communication channels. | **Tri-State Institutional Registration Gate** (`PENDING` ➔ `ACTIVE` / `REJECTED`) where student roll numbers and faculty profiles must be authenticated by Department Administrators before access is granted. |

### 2.2 Project Motivation & Vision
The motivation behind CSE JnU EduPortal is to establish Jagannath University’s Department of CSE as a pioneer in institutional digital governance. By consolidating attendance, schedules, counseling, feedback, and academic directories into a single mobile instrument, the department enhances operational productivity, strengthens student-teacher engagement, and guarantees 100% data integrity with zero paper waste.

---

## 3. Technical Specifications

The solution is architected around strict separation of concerns, ensuring high maintainability, testability, offline resilience, and enterprise-grade security.

### 3.1 High-Level Architecture Diagram

```text
┌───────────────────────────────────────────────────────────────────────────┐
│                           FLUTTER MOBILE CLIENT                           │
│                                                                           │
│   ┌───────────────────────────────────────────────────────────────────┐   │
│   │        Presentation Layer (Screens, Controllers, Notifiers)       │   │
│   │        Emerald Scholar Design System (Obsidian & Deep Emerald)    │   │
│   └─────────────────────────────────┬─────────────────────────────────┘   │
│                                     ▼                                     │
│   ┌───────────────────────────────────────────────────────────────────┐   │
│   │        Domain Layer (Pure Dart Entities, Use Cases, Contracts)    │   │
│   └─────────────────────────────────┬─────────────────────────────────┘   │
│                                     ▼                                     │
│   ┌───────────────────────────────────────────────────────────────────┐   │
│   │        Data Layer (DTO Models, Repositories, Remote DataSources)  │   │
│   │        Local Storage (FlutterSecureStorage, SharedPreferences)   │   │
│   └─────────────────────────────────┬─────────────────────────────────┘   │
└─────────────────────────────────────┼─────────────────────────────────────┘
                                      │
              Official Firebase SDK (Client-Side Connection)
              Sub-Millisecond Declarative Security Rules Enforcement
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                        FIREBASE SERVERLESS ENGINE                         │
│                                                                           │
│   ┌───────────────────────────────────────────────────────────────────┐   │
│   │   Cloud Firestore (NoSQL Document Database, Built-in Offline)     │   │
│   │   12 Collections: users, schedules, attendance, counseling, etc.  │   │
│   └─────────────────────────────────┬─────────────────────────────────┘   │
│   ┌─────────────────────────────────┴─────────────────────────────────┐   │
│   │   Firebase Authentication (Email/Password, Custom Claims RBAC)    │   │
│   └─────────────────────────────────┬─────────────────────────────────┘   │
│   ┌─────────────────────────────────┴─────────────────────────────────┐   │
│   │   Firebase Cloud Functions Gen 2 (Node.js/TypeScript Admin Engine)│   │
│   │   approveSignupRequest, rejectSignupRequest, automated triggers   │   │
│   └─────────────────────────────────┬─────────────────────────────────┘   │
│   ┌─────────────────────────────────┴─────────────────────────────────┐   │
│   │   Cloud Storage & Messaging (FCM Push Alerts, Encrypted Avatars)  │   │
│   └───────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Technology Stack Breakdown

| Component | Technology | Version / Spec | Justification & Architectural Role |
|:---|:---|:---|:---|
| **Mobile Client Framework** | **Flutter** | `3.29.x` (Dart `3.7.x`) | Cross-platform single codebase delivering 60fps native performance on Android & iOS devices. |
| **Architecture Pattern** | **Feature-Driven Clean Architecture** | Clean Architecture | Strict separation of UI (`presentation`), business logic (`domain`), and external services (`data`). |
| **State Management & DI** | **ChangeNotifier & GetIt** | `get_it: ^8.0.3` | Lightweight, highly testable dependency injection container and predictable reactive UI state emission. |
| **Design System** | **Emerald Scholar** | Custom Tokens | Material 3 foundation with bespoke academic tokens: Deep Emerald (`#006948`), Light Canvas (`#F8F9FF`), Obsidian (`#18181B`), and Terminal Green (`#34D399`). |
| **Typography** | **Google Fonts** | `google_fonts: ^6.2.1` | **Plus Jakarta Sans** for clear academic reading; **JetBrains Mono** for attendance codes and terminals. |
| **Authentication Engine** | **Firebase Authentication** | `firebase_auth: ^5.5.1` | Secure identity management with automated JWT token handling and cryptographically signed Custom Claims. |
| **Production Database** | **Cloud Firestore** | `cloud_firestore: ^5.6.5` | Distributed NoSQL database featuring live sub-second listeners, automatic offline disk persistence, and ACID transactions. |
| **Serverless Admin Engine** | **Firebase Cloud Functions** | Gen 2 (Node.js 22 LTS, TypeScript) | Trusted server environment for administrative operations (`approveSignupRequest`, `rejectSignupRequest`, role claims injection). |
| **Cloud File Storage** | **Firebase Storage** | `firebase_storage: ^12.4.4` | Secure object storage for profile avatars and feedback attachments governed by `storage.rules`. |
| **Push Notifications** | **Firebase Cloud Messaging** | `firebase_messaging: ^15.2.4` | Battery-efficient real-time push alerts for routine changes, exam schedules, and counseling responses. |
| **Local Hardware Storage** | **Flutter Secure Storage** | `flutter_secure_storage: ^9.2.4` | Encrypted storage leveraging Android Keystore and iOS Keychain for session caching. |

### 3.3 Security & Role-Based Access Control (RBAC)

1. **Declarative Database Firewall (`firestore.rules`)**:
   - Sub-millisecond evaluation at the database engine level.
   - Access decisions rely on cryptographically verified JWT custom claims: `request.auth.token.role`.
   - Prevents unauthorized writes regardless of client modifications or network proxies.
2. **Four Distinct Institutional Roles**:
   - `STUDENT`: Read curriculum, submit 6-digit attendance code, view personal records, book counseling, post anonymous feedback.
   - `CR`: Student privileges + edit tomorrow's class schedule + generate formatted WhatsApp routine announcements.
   - `TEACHER`: Launch live attendance terminal, override student marks, set office hours slots, reply to feedback, view assigned courses.
   - `ADMIN`: Approve/reject new account requests, promote batches across semesters, assign course instructors, manage user directory.
3. **Client-Side Route Guards (`GoRouter`)**:
   - Declarative route redirection based on authentication state and user role.
   - Unauthorized navigation attempts automatically redirect to the user's authorized role shell.

---

## 4. Development Plan: 14-Week Cycle

The project is structured into an intensive, phased **14-Week Delivery Roadmap**. In accordance with departmental review requirements, **Weeks 1–2 are dedicated entirely to building, verifying, and demonstrating the complete Authentication, Login, and Multi-Role Registration Engine**.

### 4.1 Master 14-Week Timeline Overview

```text
Week 01 ──► Mobile Scaffold, Emerald Scholar UI, Login & Signup Screens, Form Validation
Week 02 ──► Multi-Role Signup Petitions, Tri-State Verification Queue, Cloud Functions RBAC (Milestone M1: Faculty Demo)
Week 03 ──► Academic Curriculum Catalog, Semester Models (1–8), Credit Hours & Teacher Mapping
Week 04 ──► Admin Moderation Console, Batch Semester Promotions, Department User Directory (Milestone M2)
Week 05 ──► Live 6-Digit Attendance Terminal (Obsidian UI), Dynamic Countdown Timer, Student Verification Modal
Week 06 ──► Manual Roster Overrides, Attendance Compliance Engine (75%/60%), Excel (.xlsx) Report Exporter (Milestone M3)
Week 07 ──► Dynamic Weekly Timetable Grid (Sun–Thu), CR "Tomorrow-Only" Lock Engine
Week 08 ──► Exam Schedules, Countdown Timer Cards, Single-Tap WhatsApp Broadcast Generator (Milestone M4)
Week 09 ──► Faculty Office Hours Creation, Student Counseling Appointment Booking, Mutual Exclusion Locks
Week 10 ──► Faculty Counseling Inbox (Accept/Decline/Reschedule), FCM Push Notifications (Milestone M5)
Week 11 ──► Cryptographically Detached Anonymous Course Feedback Pipeline (1–5 Star Ratings)
Week 12 ──► Faculty Public Clarifications, Threaded Feedback Replies, Quality Metrics Dashboard (Milestone M6)
Week 13 ──► Stress Testing, Concurrency Verification, Offline Disk Persistence, Security Audits
```

#### Master 14-Week Development Schedule Table

| Week # | Phase / Domain | Primary Engineering Deliverables & Features | Target Milestone / Deliverable | Status |
|:---:|:---|:---|:---|:---:|
| **Week 1** | **Identity & Mobile Scaffolding** | Clean Architecture folder layout, Emerald Scholar design tokens, Login Screen (06), Multi-Role Signup Screen (11), Form validators (JnU Roll, Email), Firebase Auth initialization | **UI & Client Foundations** | 🟢 **In Progress** |
| **Week 2** | **Auth Engine, Gating & RBAC** | Signup petition queue in Firestore, `approveSignupRequest` & `rejectSignupRequest` Cloud Functions, Custom Claims injection, GoRouter RBAC guards, device demo | **M1: Working Auth Demo for Professor** | 🟡 **Active Sprint** |
| **Week 3** | **Curriculum & Semester Data** | 8 undergraduate semesters schema, course models (credit hours, theory vs lab), syllabus info, faculty-to-course allocation service | **Course & Semester Catalog** | ⚪ Planned |
| **Week 4** | **Admin Console & Rosters** | Tri-state approval dashboard, batch semester promotion state machine, CR appointment, Department User Directory with role filters | **M2: Admin Moderation Operational** | ⚪ Planned |
| **Week 5** | **Live Attendance Terminal** | Obsidian theme faculty terminal (04), dynamic 6-digit random code generation (TTL 30s/60s/90s), Student 6-cell PIN entry modal (05), sub-200ms verification | **Dynamic Terminal Functional** | ⚪ Planned |
| **Week 6** | **Roster Overrides & Excel Exporter** | Live attendee roster updates, manual faculty toggles (PRESENT/ABSENT/LATE), attendance percentage calculator (75%/60%), automated Excel (.xlsx) export | **M3: Attendance Engine Complete** | ⚪ Planned |
| **Week 7** | **Dynamic Timetable Engine** | Weekly schedule matrix (Sun–Thu), time-aware lecture highlights, room conflict validation, CR "Tomorrow-Only" schedule lock | **Routine System Functional** | ⚪ Planned |
| **Week 8** | **Exams & WhatsApp Automation** | Midterm & final exam countdown cards, Single-Tap WhatsApp broadcast message generator with auto-formatted markdown routine | **M4: Routine & WhatsApp Live** | ⚪ Planned |
| **Week 9** | **Faculty Counseling Engine** | Faculty office hours creator, student appointment reservation pipeline with reason categories, transactional mutual exclusion locks | **Counseling Booking Live** | ⚪ Planned |
| **Week 10** | **Counseling Inbox & Notifications** | Professor inbox (ACCEPT/DECLINE/RESCHEDULE), student consultation notes, Firebase Cloud Messaging (FCM) push notifications | **M5: Counseling & Alerts Live** | ⚪ Planned |
| **Week 11** | **Anonymized Feedback Pipeline** | Cryptographically detached student course feedback (1–5 star ratings, qualitative remarks, attachment uploads, zero user IDs stored) | **Anonymous Feedback Active** | ⚪ Planned |
| **Week 12** | **Faculty Feedback Clarifications** | Teacher feedback dashboard, public threaded batch responses, departmental academic quality metric aggregates | **M6: Feedback Loop Complete** | ⚪ Planned |
| **Week 13** | **Stress Testing & Security Audits** | 500-user concurrent attendance simulation, Firestore security rules audit, offline local disk persistence & airplane mode sync tests | **Security & Load Hardened** | ⚪ Planned |
| **Week 14** | **Pilot UAT & Production Handover** | Departmental pilot UAT with faculty and students, release signing (Signed APK), final project documentation, academic evaluation defense | **M7: Production Launch & Defense** | ⚪ Planned |

---

### 4.2 Weeks 1–2 Deep-Dive: Authentication, Login & Multi-Role Signup System

> **Milestone Target**: 🟢 **M1: Comprehensive Authentication & Onboarding Demo for Faculty Evaluation**  
> **Core Objective**: Deliver a production-grade, highly responsive authentication engine supporting multi-role registration, administrative review gating, hardware token encryption, and role-based routing.

#### A. Week 1: Identity Foundations & Client Presentation
* **Day 1: Project Scaffolding & Design System Implementation**:
  * Establish Flutter project structure following Feature-Driven Clean Architecture (`core/`, `app/`, `features/`, `shared/`).
  * Implement the **Emerald Scholar** design tokens in `app_colors.dart`, `app_text_styles.dart`, and `app_theme.dart`.
  * Configure dependency injection container with `GetIt` (`injection_container.dart`).
* **Day 2: Firebase Connection & Hardware Keystore Setup**:
  * Integrate `firebase_core` and initialize via `firebase_options.dart`.
  * Implement `SecureStorageService` leveraging Android Keystore and iOS Keychain.
  * Setup `LocalStorageService` with `SharedPreferences` for user session caching.
* **Day 3: Screen 06 — Institutional Login Screen**:
  * Build the complete login interface ([Screen 06](file:///Users/sajib/Desktop/CSE_DEPT/screens/06_Login_-_EduPortal.html)) matching the high-fidelity design prototype.
  * Form inputs for Email / Student ID and Password with visibility toggles.
  * Field-level validation rules for Jagannath University institutional email patterns.
* **Day 4: Screen 11 — Multi-Role Dynamic Signup Screen**:
  * Build the registration interface ([Screen 11](file:///Users/sajib/Desktop/CSE_DEPT/screens/11_Sign_Up_-_EduPortal.html)).
  * Implement dynamic segmented role selection:
    * **Student**: Full Name, Student Roll, Batch (e.g. 14th), Current Semester (1st–8th), Email, Password.
    * **Class Representative (CR)**: Enrolls with standard student details plus automated CR election petition flag.
    * **Teacher / Faculty**: Full Name, Academic Designation (Lecturer, Assistant Professor, Professor), Email, Password.
    * **Admin**: Restricted departmental administrative registration channel.
* **Day 5: Client-Side Form Controllers & State Management**:
  * Wire `AuthController` and `AuthState` using `ChangeNotifier`.
  * Comprehensive input formatters and regex validators (`validators.dart`) for JnU Student ID and Bangladeshi phone numbers.
  * Test responsive layouts across phone screen sizes.

#### B. Week 2: Cloud Functions Gating, Tri-State Verification & RBAC
* **Day 6: Cloud Firestore Identity Schemas & Public Petitions Queue**:
  * Define Firestore data models for `/signupRequests/{requestId}` and `/users/{uid}`.
  * Establish `firestore.rules` allowing unauthenticated users to create pending registration requests with status restricted strictly to `PENDING`.
* **Day 7: Firebase Cloud Functions Implementation**:
  * Write and deploy `approveSignupRequest` in `functions/src/index.ts`:
    1. Authenticates that the calling user has `role === 'ADMIN'`.
    2. Provisions official Firebase Authentication account with random initial credentials or requested password.
    3. Injects custom claims (`role`, `year`, `semester`, `isCR`).
    4. Creates the permanent `/users/{uid}` profile document.
    5. Updates petition status to `APPROVED`.
  * Write and deploy `rejectSignupRequest` for handling unverified registrations.
* **Day 8: Tri-State Verification Status UI & User Feedback**:
  * Implement user-facing feedback dialogs:
    * `PENDING`: *"Your registration petition is awaiting Department Administrator approval. You will receive an alert once verified."*
    * `SUSPENDED`: *"Your account has been deactivated. Please contact the CSE Department Office."*
    * `ACTIVE`: Immediate token grant and session establishment.
* **Day 9: Declarative Route Protection (`GoRouter` RBAC Guards)**:
  * Configure `app_router.dart` with state-driven redirect logic.
  * Protect routes: `/dashboard/student`, `/dashboard/cr`, `/dashboard/teacher`, `/dashboard/admin`.
  * Enforce immediate route interception if an unauthenticated user attempts deep linking.
* **Day 10: End-to-End Testing & Faculty Demonstration Rehearsal**:
  * Execute end-to-end verification: registration of a sample student, CR, and professor account; admin login and 1-tap approval; student login and successful navigation to the dashboard shell.
  * Package release build APK for live physical device demonstration to the supervising professor.

---

### 4.3 Weeks 3–14 Implementation Breakdown

* **Week 3 — Academic Curriculum & Semester Models**:
  * Firestore collections for 8 undergraduate semesters, courses (credit hours, lab vs theory flags), syllabus outlines.
  * Admin interface for assigning faculty to courses.
* **Week 4 — Admin Moderation Console & Department Directories (Milestone M2)**:
  * Admin hub for reviewing pending signups with 1-tap approve/reject actions.
  * Batch semester progression state machine (promoting 3rd semester students to 4th semester).
  * Department user directories with search and role filtering.
* **Week 5 — Dynamic 6-Digit Attendance Terminal (Faculty)**:
  * Obsidian theme live terminal ([Screen 04](file:///Users/sajib/Desktop/CSE_DEPT/screens/04_Professors_Attendance_Terminal_-_EduPortal.html)) with 6-digit random code generation (excluding ambiguous characters like `0, O, 1, I`).
  * Circular visual countdown timer (30s / 60s / 90s TTL).
  * Student 6-cell PIN entry modal ([Screen 05](file:///Users/sajib/Desktop/CSE_DEPT/screens/05_Students_Attendance_-_EduPortal.html)) with sub-200ms verification.
* **Week 6 — Roster Overrides, Attendance Metrics & Excel Export (Milestone M3)**:
  * Live attendee roster showing students as they enter the code in real-time.
  * Faculty manual override toggles (`PRESENT`, `ABSENT`, `LATE`).
  * Student compliance calculator displaying color-coded status badges: Green (≥75%), Amber (60–74%), Red (<60%).
  * Automated departmental attendance sheet generator exporting formatted `.xlsx` files for exam boards.
* **Week 7 — Dynamic Weekly Timetable & Routine Engine**:
  * Interactive weekly schedule grid (Sunday to Thursday).
  * Time-aware daily schedule view highlighting current and upcoming lectures.
  * CR "Tomorrow-Only" security lock preventing unauthorized retrospective routine modifications.
* **Week 8 — Exam Schedules & WhatsApp Broadcast Generator (Milestone M4)**:
  * Exam schedule cards for Midterm, Lab, and Semester Final assessments with countdown badges.
  * Single-Tap WhatsApp Broadcast Generator: converts the next day's schedule into a cleanly formatted markdown text message ready to paste into batch groups with one tap.
* **Week 9 — Faculty Counseling & Office Hours Engine**:
  * Faculty office hours creation interface allowing professors to specify available time blocks.
  * Student appointment booking engine with reason categories (Thesis Guidance, Exam Clarification, Lab Support, Personal Doubt).
  * Mutual exclusion booking locking preventing double reservations.
* **Week 10 — Counseling Management & Push Notifications (Milestone M5)**:
  * Faculty counseling inbox with action buttons: `ACCEPT`, `DECLINE`, `RESCHEDULE`.
  * Integration of Firebase Cloud Messaging (FCM) to trigger background push notifications when appointment statuses change.
* **Week 11 — Cryptographically Anonymized Course Feedback Pipeline**:
  * Student course and teacher evaluation interface ([Screen 02](file:///Users/sajib/Desktop/CSE_DEPT/screens/02_Students_Feedback_-_EduPortal.html)).
  * 1–5 star ratings, qualitative remarks, and optional lab issue attachments.
  * Architectural decoupling: student user IDs are strictly omitted from feedback documents to guarantee 100% true anonymity.
* **Week 12 — Faculty Clarification Dialogues & Quality Dashboard (Milestone M6)**:
  * Faculty feedback view allowing teachers to read aggregated course ratings.
  * Public threaded responses allowing professors to post official batch clarifications.
  * Departmental academic quality metric summaries for the Department Chairman.
* **Week 13 — Stress Testing, Security Auditing & Offline Resilience**:
  * Load simulation verifying 500 simultaneous attendance code submissions within a 60-second window.
  * Comprehensive review of `firestore.rules` and `storage.rules` to eliminate security vulnerabilities.
  * Offline persistence validation: verifying routine browsing and cached attendance display in airplane mode.
* **Week 14 — Departmental Pilot, Production Handover & Defense (Milestone M7)**:
  * Pilot testing with selected CSE batches and faculty members.
  * Production release packaging (Signed Android APK).
  * Final project presentation and defense before the departmental evaluation committee.

---

### 4.4 Milestone Schedule & Key Deliverables

| Milestone | Target Week | Core Deliverable | Verification & Acceptance Criteria | Status |
|:---:|:---:|:---|:---|:---:|
| **M1** | **Week 2** | **Multi-Role Authentication & Onboarding Engine** | **Interactive live demo of Login, Signup, Admin Verification Gating, and Role-Based Routing.** | 🟢 **Primary Goal** |
| **M2** | **Week 4** | **Curriculum Catalog & Admin Moderation Hub** | Admin approves pending users; batches promoted; faculty assigned to courses. | ⚪ Planned |
| **M3** | **Week 6** | **Live Attendance Terminal & Excel Exporter** | Faculty launch 6-digit live countdown terminal; students verify codes; Excel export generated. | ⚪ Planned |
| **M4** | **Week 8** | **Timetable Matrix & WhatsApp Routine Generator** | Weekly schedule functional; CR tomorrow lock active; single-tap WhatsApp broadcast works. | ⚪ Planned |
| **M5** | **Week 10** | **Faculty Office Hours & Counseling Booking** | Students book office hour slots; faculty accept/decline; push notifications delivered. | ⚪ Planned |
| **M6** | **Week 12** | **Anonymized Feedback & Faculty Replies** | Detached anonymous reviews submitted; faculty reply publicly to batches. | ⚪ Planned |
| **M7** | **Week 14** | **Departmental Launch & Production Release** | 500-student load test green; signed APK distributed; academic evaluation defense passed. | ⚪ Planned |

---

## 5. Cost Analysis & Budget (Free Tier Model in Bangladeshi Taka)

A fundamental design priority of CSE JnU EduPortal is **zero financial burden** on the department. By architecting the system around the **Google Firebase Spark (Free Tier) Plan** and open-source tooling, the ongoing operational cost for the department is **exactly ৳0 Taka**.

### 5.1 Table 1: 100% Free Version Deployment (Zero-Cost / ৳0 BDT Model)

The table below outlines how every system component operates permanently within the free allowances of Google Cloud and open-source infrastructure:

| Component / Infrastructure | Service Provider | Free Tier Monthly Allowance | Departmental Academic Usage (500 Students + 30 Faculty) | Cost in Taka (৳ BDT) |
|:---|:---|:---|:---|:---:|
| **Database Storage & Queries** | **Google Cloud Firestore** (Spark Plan) | • **1 GiB** stored data<br>• **50,000 document reads / day**<br>• **20,000 document writes / day**<br>• **20,000 document deletes / day** | • Total departmental data: ~120 MB (12% of quota)<br>• Daily reads: ~15,000 (30% of quota)<br>• Daily writes: ~3,000 (15% of quota) | **৳0** / month |
| **Authentication & User Directory** | **Firebase Authentication** | • **50,000 Monthly Active Users (MAUs)** free forever | Entire department: ~550 accounts (1.1% of quota) | **৳0** / month |
| **Serverless Admin Functions** | **Firebase Cloud Functions** (Gen 2) | • **2,000,000 invocations / month**<br>• 400,000 GB-seconds computing time | Admin account approvals & triggers: ~800 invocations/month (<0.1% of quota) | **৳0** / month |
| **Media & File Storage** | **Firebase Cloud Storage** | • **5 GiB** storage capacity<br>• **1 GiB / day** download bandwidth | Compressed avatar images & feedback attachments: ~450 MB total | **৳0** / month |
| **Push Notification Service** | **Firebase Cloud Messaging (FCM)** | • **Unlimited push notifications**<br>• 100% free forever with no caps | Departmental alerts, routine reminders, counseling notices | **৳0** / month |
| **Mobile Client App Framework** | **Flutter / Dart SDK** | • 100% Open-Source under BSD-3 license | Compiles native Android & iOS binaries without licensing fees | **৳0** |
| **SSL / HTTPS Security** | **Google Cloud Managed TLS** | • Automated 2048-bit SSL/TLS certificate issuance and renewal | All communication strictly encrypted over HTTPS with zero certificate fees | **৳0** |
| **App Distribution (Android)** | **Direct APK / JnU Department Portal / GitHub Releases** | • Unlimited downloads hosted on departmental server or GitHub Releases | Students and faculty download the official departmental APK directly | **৳0** |
| **Total Monthly Operating Cost** | — | — | — | **৳0 / month** |
| **Total Annual Operating Cost** | — | — | — | **৳0 / year** |

---

### 5.2 Table 2: Optional: Google Play Store Listing Costs

If the Department of Computer Science & Engineering chooses to distribute the application via the official **Google Play Store** (for automatic background updates and simplified installation) instead of direct APK distribution:

| Item Description | Billing Frequency | Fee in US Dollars ($ USD) | Fee in Bangladeshi Taka (৳ BDT)* | Justification & Details |
|:---|:---:|:---:|:---:|:---|
| **Google Play Console Developer Account** | **One-Time Lifetime Fee** | **$25.00 USD** | **~৳3,050 BDT** | Required by Google to register an official organizational or developer publishing account. **Paid once; valid for lifetime with unlimited app publishing.** |
| **App Hosting & Global Download Bandwidth** | Monthly / Perpetual | $0.00 | **৳0 BDT** | Google hosts APKs/AABs and serves global download bandwidth completely free for published apps. |
| **Continuous App Updates & Patch Releases** | Per Release | $0.00 | **৳0 BDT** | Unlimited application updates, bug fixes, and version releases without any recurring charges. |
| **Google Play Integrity & App Signing** | Included | $0.00 | **৳0 BDT** | Built-in cryptographic APK signature protection and device verification. |
| **Total One-Time Deployment Cost** | **One-Time Payment** | **$25.00 USD** | **~৳3,050 BDT** | **Single one-time payment for perpetual departmental publishing.** |
| **Recurring Monthly Maintenance Cost** | **Monthly** | **$0.00** | **৳0 / month** | **Zero ongoing fees forever.** |

*\*Note: Converted at the standard commercial exchange rate of 1 USD ≈ 122 BDT (September 2026). This is a strictly optional expenditure; departmental distribution via direct APK download costs **৳0**.*

---

### 5.3 Comparative Deployment Models in Bangladeshi Taka (৳ BDT)

| Deployment Model | Initial Setup Cost | Monthly Maintenance | Annual Expenditure | Best Suited For |
|:---|:---:|:---:|:---:|:---|
| **Tier 1: 100% Free Version (Recommended)** | **৳0** | **৳0** | **৳0** | **Academic Evaluation, Departmental Rollout & Direct APK Distribution** |
| **Tier 2: Free Cloud + Google Play Store** | **~৳3,050 (One-Time)** | **৳0** | **৳0** | **Public distribution via official Google Play Store listing** |
| **Tier 3: Commercial Enterprise Hosting** | ~৳15,000 | ~৳6,000 / month | ~৳72,000 / year | University-wide deployment across 35+ departments with custom dedicated servers |

---

## 6. Conclusion & Recommendations

The **CSE JnU EduPortal** replaces outdated, error-prone paper registers and scattered social communication with a state-of-the-art, role-based academic mobile ecosystem. 

By executing this **14-Week Development Work Cycle**, the Department of Computer Science & Engineering will realize immediate benefits:
1. **Unrivaled Efficiency**: Lecture attendance duration slashed from 10 minutes to under 90 seconds.
2. **Institutional Transparency**: Real-time visibility into routines, exam dates, and attendance percentage compliance.
3. **Enhanced Collaboration**: Structured faculty counseling and candid, cryptographically anonymized student feedback.
4. **Absolute Fiscal Prudence**: 100% operational deployment on Google Firebase Spark Tier costing **৳0 Taka**, with an optional one-time listing fee of **~৳3,050 Taka** for Google Play Store publication.
5. **Demonstrable Progress**: Immediate proof-of-capability delivered in **Weeks 1–2** featuring a complete, working Multi-Role Login, Signup, and Admin Verification demonstration for faculty evaluation.

**Recommendation**: The Engineering Evaluation Board is formally recommended to approve this project proposal and authorize the commencement of the 14-Week Development Cycle.
