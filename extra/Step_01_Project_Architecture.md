# CSE JnU EduPortal — Complete System Architecture & Folder Guide

The **CSE JnU EduPortal** is an academic mobile platform designed for the Department of Computer Science & Engineering at Jagannath University (JnU). It unites four key academic roles: **Students**, **Class Representatives (CRs)**, **Professors / Faculty**, and **Department Administrators**.

The repository is organized as a monorepo adhering strictly to **Feature-Driven Clean Architecture** on the Flutter mobile client and **Firebase Cloud Infrastructure** (Cloud Firestore, Firebase Authentication, Cloud Functions, and Storage) for serverless operations, security rules, and live data.

---

## 🗺️ High-Level Directory Overview

```text
CSE_DEPT/
├── mobile/             # Flutter Mobile Client (Clean Architecture)
├── functions/          # Firebase Cloud Functions (Gen 2 Serverless Engine)
├── screens/            # 17 High-Fidelity HTML/CSS UI Screen Prototypes
├── docs/               # System documentation, specifications & blueprints
├── basic/              # Foundational learning guides (Widgets, Firebase, etc.)
├── extra/              # Step-by-step master architecture roadmap
├── firestore.rules     # Declarative sub-millisecond database security rules
├── storage.rules       # Cloud Storage security policies (avatars, attachments)
├── DESIGN.md           # "Emerald Scholar" Design System token specifications
└── firebase.json       # Firebase project emulation & deployment configuration
```

---

## 1. 📱 Frontend: `mobile/` (Flutter Mobile Application)

The mobile client is built with Flutter and adheres strictly to **Feature-Driven Clean Architecture**. Business logic is decoupled from UI rendering and network protocols.

```text
mobile/lib/
├── app/                # App-level entry, navigation & theme wiring
├── core/               # Shared cross-cutting infrastructure & utilities
├── features/           # Self-contained business modules (data/domain/presentation)
├── shared/             # Reusable global UI widgets & components
├── firebase_options.dart # Firebase client connection credentials
└── main.dart           # App startup, DI bootstrap & root initialization
```

### Key Folders & Responsibilities:

* **`mobile/lib/main.dart`**: The app entry point; initializes Firebase, configures the service locator (DI), and boots the app.
* **`mobile/lib/app/`**:
  * `app.dart`: Root `MaterialApp` widget, theme integration, and global route delegates.
  * `router/`: Declarative routing with role-based navigation guards (preventing students from navigating to admin/faculty screens).
  * `theme/`: The **Emerald Scholar** design theme (Material 3, light/dark mode color tokens, custom typography).
* **`mobile/lib/core/`**: Cross-cutting utilities:
  * `di/`: Service locator configuration using `GetIt` for dependency injection.
  * `storage/`: Secure hardware keystore storage (iOS Keychain / Android Keystore) for JWTs and local cache.
  * `error/`: Domain `Failure` and `Exception` types.
  * `constants/`: University academic roles, asset paths, and Firestore collection names.
* **`mobile/lib/features/`**: Every feature contains three isolated sub-layers:
  * `data/`: Remote datasources (Cloud Firestore), local cache, DTOs (`*Model`), and repository implementations.
  * `domain/`: Pure Dart entities, abstract repository contracts (`*Repository`), and single-responsibility use cases.
  * `presentation/`: State management controllers / Notifiers, screens, and feature-specific widgets.
  * **Feature Modules**:
    * `auth/`: Login, signup request workflow, session restoration.
    * `dashboard/`: Role-specific dashboards for Student, CR, Teacher, and Admin.
    * `attendance/`: Dynamic 6-digit PIN terminal, student verification, manual roster toggles.
    * `schedule/`: Routine timetable, exam schedules, schedule updates.
    * `counseling/`: Faculty office hour slots, appointment booking, slot locking.
    * `feedback/`: Anonymous departmental reviews, star ratings, faculty replies.
    * `notifications/`: Push alert display and notification inbox.
    * `profile/`: Student and faculty profile cards, credentials, semester details.
    * `curriculum/`: Course catalog, credit assignments, syllabus info.

---

## 2. ⚡ Cloud Functions: `functions/` (Firebase Serverless Engine)

Provides server-side trusted operations that require the Firebase Admin SDK and cannot be entrusted to client devices.

* **`functions/src/index.ts`**:
  * `approveSignupRequest`: Admin-only callable function that creates Firebase Auth credentials, injects custom claims (`role`, `year`, `semester`), and initializes the user profile in Firestore.
  * `rejectSignupRequest`: Administrative rejection handler.
  * Firestore Event Triggers: Dispatches FCM push notifications when class routines or attendance sessions are scheduled.
* **`functions/src/seed.ts`**: Database seeding utilities for Firestore.


---

## 3. 🎨 Design & UI Prototypes: `screens/` & Root Design Specs

As defined in the project rules (`.agents/rules/ui.md`), all mobile screen implementations must directly mirror the HTML/CSS prototypes in `screens/`:

* **`screens/`**: Contains 17 full-fidelity reference prototypes:
  * `01_Professors_Dashboard_-_EduPortal.html`
  * `02_Students_Feedback_-_EduPortal.html`
  * `03_Students_Counseling_-_EduPortal.html`
  * `04_Professors_Attendance_Terminal_-_EduPortal.html` (Obsidian glowing live terminal)
  * `05_Students_Attendance_-_EduPortal.html`
  * `06_Login_-_EduPortal.html` & `11_Sign_Up_-_EduPortal.html`
  * `07_CRs_Attendance_-_EduPortal.html`, `12_CRs_Schedule_-_EduPortal.html`, `14_CRs_Dashboard_-_EduPortal.html`
  * `08_Admins_Directory_-_EduPortal.html`, `13_Admins_Dashboard_-_EduPortal.html`
  * `09_Professors_Inbox_-_EduPortal.html`, `10_Students_Schedule_-_EduPortal.html`, `15_Students_Dashboard_-_EduPortal.html`, `17_Professors_Schedule_-_EduPortal.html`
* **`DESIGN.md` & `design_tokens.json`**: The **Emerald Scholar** design system specifications:
  * Primary brand: Deep Emerald (`#006948`), Light surface (`#F8F9FF`), Dark surface (`#0B1C30`).
  * Terminal Canvas: Obsidian (`#18181B`) with glowing emerald monospace accents (`#34D399`).
  * Typography: **Plus Jakarta Sans** (headings/body) and **JetBrains Mono** (terminal digits/codes).

---

## 4. 🔒 Security & Rules: Root Files

* **`firestore.rules`**: Declarative database security rules inspecting token custom claims (`request.auth.token.role`) to strictly control read/write access per role.
* **`storage.rules`**: File upload access policies for feedback attachments and profile avatars.
* **`firebase.json` & `.firebaserc`**: Project configuration for Firebase Emulators (Firestore, Auth, Functions, Storage).

---

## 5. 📖 Documentation: `docs/`

Comprehensive system specifications located in `docs/`:
* **`docs/architecture/`**: In-depth blueprints for Flutter Architecture, Firebase Architecture, and Security Policies.
* **`docs/requirements/`**: Academic rules, semester transition state machines, and role privileges.
* **`docs/database/`**: Firestore collection schemas and entity data dictionary.
* **`docs/api/`**: Firebase operation mapping and specification catalogs.
* **`docs/features/`**: Functional requirement breakdown per role.
* **`docs/ui/`**: Screen specifications and component design patterns.

---

## 🔄 End-to-End Data Flow Summary

```text
User Interaction (Screen Widget)
       │
       ▼
Presentation Notifier / Controller (mobile/lib/features/<feat>/presentation)
       │  Dispatches Intent
       ▼
Domain Use Case (mobile/lib/features/<feat>/domain/usecases)
       │  Executes Business Logic
       ▼
Repository Contract (mobile/lib/features/<feat>/domain/repositories)
       │  Invoked
       ▼
Repository Implementation (mobile/lib/features/<feat>/data/repositories)
       │  Maps Entities <-> DTO Models
       ▼
Data Source (mobile/lib/features/<feat>/data/datasources)
       │
       ├───► Official Firebase SDK ─────► Cloud Firestore & Firebase Auth
       │                                     └── Enforced sub-ms by firestore.rules
       │
       └───► Firebase Functions SDK ───► Cloud Functions (functions/src/index.ts)
                                             └── Privileged Admin tasks (e.g. approveSignup)
```
