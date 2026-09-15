# `mobile/lib/features/` — Domain Feature Modules Guide

In Flutter Clean Architecture, the **`mobile/lib/features/`** directory ([`mobile/lib/features/`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/features)) represents the **core functional value of the application**.

Rather than organizing code horizontally by technical type (e.g. dumping all screens in one giant folder and all models in another), the application uses **Vertical Feature Slicing**. Every academic domain (such as *Attendance*, *Counseling*, or *Feedback*) is completely isolated into its own independent folder.

---

## 🏛️ The 3-Tier Layer Inside Every Feature

Every feature directory strictly follows the **Clean Architecture** separation of concerns:

```text
features/<feature_name>/
├── domain/         # 1. CORE BUSINESS RULES (Pure Dart, Zero Dependencies)
│   ├── entities/      # Business models (immutable data classes extending Equatable)
│   ├── repositories/  # Abstract contracts / interfaces
│   └── usecases/      # Single-responsibility business actions
│
├── data/           # 2. INFRASTRUCTURE & PERSISTENCE
│   ├── datasources/   # Direct Firebase SDK / REST API network calls
│   ├── models/        # DTOs with fromJson(), fromFirestore(), and toJson()
│   └── repositories/  # Concrete implementations of domain repository contracts
│
└── presentation/   # 3. USER INTERFACE & STATE
    ├── controllers/   # State management (Notifiers / Controllers emitting UI states)
    ├── screens/       # Full-page Flutter widgets (Scaffolds)
    └── widgets/       # Private UI sub-widgets used only in this feature
```

### 🔒 The Golden Dependency Rule:
* **`domain/`** depends on **nothing**. It is written in pure Dart and has no dependencies on Flutter UI or Firebase.
* **`presentation/`** depends only on **`domain/`** (calls Use Cases). It never touches raw network or databases.
* **`data/`** depends on **`domain/`** (implements the repository interfaces and maps raw JSON/Firestore snapshots to Domain Entities).

---

## 🧩 The 9 Feature Modules in EduPortal

```text
mobile/lib/features/
├── auth/           # 1. Identity, Login & Sign-Up Petitions
├── dashboard/      # 2. Role-Based Scaffolds (Student, CR, Teacher, Admin)
├── attendance/     # 3. Dynamic PIN Terminal & 75% Exam Eligibility
├── curriculum/     # 4. Syllabus, Theory & Lab Course Catalog
├── schedule/       # 5. Daily Class Routine & Exam Timetables
├── counseling/     # 6. Faculty Office Hours & Appointment Booking
├── feedback/       # 7. Anonymous Departmental Course Evaluations
├── notifications/  # 8. Push Alert History & In-App Feed
└── profile/        # 9. Student Profile & Semester Promotion Status
```

---

### 1. `auth/` (Authentication & Access Control)
* **What it does**: Handles user login, password resets, session persistence, and initial account sign-up petitions.
* **Key Components**:
  * `domain/entities/user.dart`: The core `User` entity containing `id`, `email`, `role`, `studentId`, `year`, `semester`.
  * `data/models/user_model.dart`: DTO that extends `User` and handles Firestore conversion:
    ```dart
    factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data() ?? {};
      return UserModel.fromJson({'id': doc.id, ...data});
    }
    ```
  * `domain/usecases/`: `LoginUseCase`, `LogoutUseCase`, `SignupRequestUseCase`, `GetCurrentUserUseCase`.
  * `presentation/controllers/auth_controller.dart`: Manages authentication states (`Authenticated`, `Unauthenticated`, `AuthLoading`).
  * `presentation/screens/`: `LoginScreen`, `SignupRequestScreen`, `SplashScreen`.

---

### 2. `dashboard/` (Role Shells & Navigation)
* **What it does**: Provides four distinct home dashboard experiences tailored to each user persona.
* **Key Components**:
  * `student_main_scaffold.dart`: Bottom-navigation shell for students with 5 persistent tabs (Overview, Attendance, Schedule, Counseling, Feedback).
  * `teacher_dashboard_shell.dart`: Faculty cockpit with quick actions to launch attendance terminals and review counseling requests.
  * `cr_dashboard_shell.dart`: Class Representative console for routine broadcasts and roster exports.
  * `admin_dashboard_shell.dart`: Administrative center for user management and account approvals.

---

### 3. `attendance/` (Attendance Management & Terminal)
* **What it does**: Powerhouse of the classroom experience:
  1. Teachers launch a live dynamic 6-digit PIN code terminal.
  2. Students enter the code to verify presence.
  3. Automatically calculates the **JnU 75% attendance threshold** (`isEligible`) for semester final exams.
* **Key Components**:
  * `domain/entities/attendance_entities.dart`: Models `AttendanceSession`, `CourseAttendance`, `AttendanceRecord`, `AttendanceSummary`.
  * `presentation/controllers/attendance_controller.dart`: Handles verification timers, code submissions, and eligibility calculations.
  * `presentation/screens/student_attendance_screen.dart`: Visual breakdown of attendance percentage per course.

---

### 4. `curriculum/` & `schedule/` (Timetable & Syllabus)
* **What it does**: Displays the official department syllabus, credit breakdown (theory vs. sessional lab), and weekly routine timetables.
* **Key Components**:
  * `domain/entities/curriculum_entities.dart`: Course definitions (code, credit, syllabus).
  * `presentation/controllers/schedule_controller.dart`: Daily class routine manager with offline caching.
  * `presentation/screens/student_schedule_screen.dart`: Tabbed routine view (Sunday through Thursday).

---

### 5. `counseling/` (Faculty Office Hours & Booking)
* **What it does**: Bridges students and professors for academic counseling:
  1. Teachers post available office hour slots.
  2. Students request an appointment with topic details.
  3. Teachers approve or decline with feedback notes.
* **Key Components**:
  * `domain/entities/counseling_entities.dart`: `CounselingSlot`, `CounselingBooking`.
  * `presentation/controllers/counseling_controller.dart`: Manages slot locking and state transitions (`PENDING` ➔ `APPROVED` / `REJECTED`).
  * `presentation/screens/student_counseling_screen.dart`: Interactive slot selection and booking interface.

---

### 6. `feedback/` (Anonymous Evaluations)
* **What it does**: Enables students to submit course and instructor reviews with 100% cryptographic anonymity.
  * Student IDs and personal metadata are stripped before saving to Firestore.
  * Teachers can view course ratings and post public clarification replies.
* **Key Components**:
  * `domain/entities/feedback_entities.dart`: `FeedbackSubmission`, `FeedbackRating`.
  * `presentation/controllers/feedback_controller.dart`: Anonymous submission pipeline.
  * `presentation/screens/student_feedback_screen.dart`: Star ratings and constructive comment forms.

---

### 7. `notifications/` (Alerts & Announcements)
* **What it does**: Receives Firebase Cloud Messaging (FCM) push alerts and maintains a categorized in-app notification center.
* **Key Components**:
  * `domain/entities/notification_entities.dart`: `NotificationItem`, category badges (Routine, Exam, Counseling).
  * `presentation/screens/notification_list_screen.dart`: Interactive inbox with read/unread indicators.

---

### 8. `profile/` (Academic Standing)
* **What it does**: Displays student ID badge, batch year, active semester status, and semester progression requests.
* **Key Components**:
  * `domain/entities/semester_status.dart`: Tracks active semester status (`ENROLLED`, `UPGRADE_PENDING`, `GRADUATED`).
  * `presentation/screens/student_profile_screen.dart`: Emerald academic profile card.

---

## 🔄 End-to-End Execution Trace Inside a Feature

When a student submits a 6-digit attendance code:

```text
1. [presentation/screens/student_attendance_screen.dart]
   User types "849201" into AppTextField and taps AppPrimaryButton.
   Calls: attendanceController.submitCode("849201")
             │
             ▼
2. [presentation/controllers/attendance_controller.dart]
   Emits: AttendanceLoadingState()
   Calls: submitAttendanceUseCase(code: "849201")
             │
             ▼
3. [domain/usecases/submit_attendance_usecase.dart]
   Validates code length & format.
   Calls: attendanceRepository.submitCode(code)
             │
             ▼
4. [data/repositories/attendance_repository_impl.dart]
   Calls: attendanceRemoteDataSource.verifyCode(code)
             │
             ▼
5. [data/datasources/attendance_remote_datasource.dart]
   Calls Cloud Firestore document / Cloud Function. Returns raw data Map.
             │
             ▼
6. [data/models/attendance_models.dart]
   AttendanceModel.fromJson(json) parses response into an AttendanceRecord entity.
             │
             ▼
7. [presentation/controllers/attendance_controller.dart]
   Receives AttendanceRecord entity. Emits AttendanceSuccessState(record).
   UI reactively re-renders with a green checkmark!
```
