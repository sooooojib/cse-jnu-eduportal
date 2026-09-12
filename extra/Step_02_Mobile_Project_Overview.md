# Flutter Mobile Client (`mobile/`) — Architecture & Folder Guide

The **`mobile/`** directory contains the complete **Flutter mobile client application** (`cse_jnu_eduportal`) for the Department of Computer Science & Engineering, Jagannath University. It is cross-platform (supporting iOS and Android) and is architected using **Feature-Driven Clean Architecture**.

---

## 📁 High-Level Structure of `mobile/`

```text
mobile/
├── android/              # Native Android project (Gradle, manifests, permissions)
├── ios/                  # Native iOS project (Xcode workspace, Podfile, Info.plist)
├── assets/               # Static assets (images, branding, department logos)
│   └── images/
├── lib/                  # All Dart source code (Clean Architecture)
├── test/                 # Automated unit, widget, and mock repository tests
├── pubspec.yaml          # Project dependencies, assets, and Flutter SDK constraints
└── analysis_options.yaml   # Strict linting, formatting, and static analysis rules
```

---

## 1. ⚙️ Platform & Build Runners

* **`mobile/android/`**: Native Android engine configurations:
  * `app/src/main/AndroidManifest.xml`: System permissions (Internet, Network State, Push Notifications, Camera/Biometrics).
  * `build.gradle` & `app/build.gradle`: Android SDK versions, Gradle dependencies, and signing configurations.
* **`mobile/ios/`**: Native iOS engine configurations:
  * `Runner/Info.plist`: Privacy permissions and platform metadata.
  * `Podfile`: CocoaPods dependencies for Firebase iOS frameworks and secure storage.
* **`mobile/pubspec.yaml`**: The dependency and environment manifest:
  * **Firebase Ecosystem**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`, `firebase_storage`, `cloud_functions`, `firebase_app_check`, `firebase_crashlytics`.
  * **Routing & Architecture**: `go_router` (declarative routing with auth/RBAC guards), `get_it` (dependency injection), `equatable` (immutable value comparisons).
  * **Storage**: `flutter_secure_storage` (hardware keychain / keystore encryption), `shared_preferences` (fast key-value cache).
  * **UI & Typography**: `google_fonts` (Plus Jakarta Sans & JetBrains Mono), `cupertino_icons`, `intl`.

---

## 2. 🧠 Inside `mobile/lib/` (The Application Core)

The Dart source code inside `mobile/lib/` is organized into four distinct layers:

```text
mobile/lib/
├── app/                  # 1. App Shell (Wiring, Routing & Theming)
├── core/                 # 2. Cross-Cutting Utilities & Infrastructure
├── shared/               # 3. Reusable UI Widgets & Components
├── features/             # 4. Business Domain Modules (The Core Logic)
├── firebase_options.dart # Generated Firebase configuration keys per platform
└── main.dart             # App startup, DI bootstrap & root initialization
```

---

### Layer 1: App Shell (`mobile/lib/app/`)
Acts as the root coordinator:
* **`app.dart`**: Builds the root `MaterialApp.router` widget, binds the dynamic light/dark theme switcher, and configures global tap behaviors (e.g., keyboard dismissal).
* **`router/`**:
  * `route_names.dart`: Registry of all named path strings (e.g., `/login`, `/dashboard/student`, `/attendance`).
  * `app_router.dart`: Powered by `GoRouter`. Contains **Role-Based Access Control (RBAC) guards** ensuring students cannot access faculty terminals or admin consoles.
* **`theme/`**: The **Emerald Scholar** design system implementation:
  * `app_colors.dart`: Color tokens (Deep Emerald `#006948`, Obsidian `#18181B`, surfaces, accents).
  * `app_typography.dart`: Plus Jakarta Sans for UI and JetBrains Mono for terminals/codes.
  * `app_theme.dart`: Material 3 light and dark theme data definitions.
  * `role_colors.dart`: Persona-specific accent colors and badges (Student, CR, Teacher, Admin).

---

### Layer 2: Core Infrastructure (`mobile/lib/core/`)
Cross-cutting utilities that contain no specific business feature logic:
* **`di/`** (`injection_container.dart`): Service locator registration with `GetIt` for use cases, repositories, and datasources.
* **`network/`**: HTTP clients, auth token injection interceptors, and error interceptors.
* **`storage/`**: Encrypted hardware keystore storage for JWTs and local fast-boot cache.
* **`error/`**: Typed domain failure objects (`ServerFailure`, `AuthFailure`, `NetworkFailure`).
* **`constants/`**: App-wide constants, collection names, and user roles (`STUDENT`, `CR`, `TEACHER`, `ADMIN`).
* **`logging/`**: Structured runtime logging utilities.
* **`utils/`**: String formatters, date utilities, and input validators.

---

### Layer 3: Shared UI Components (`mobile/lib/shared/`)
Reusable, theme-aware UI elements used across multiple features:
* **`widgets/buttons/`**: Pill-shaped primary buttons, secondary outline buttons, and icon buttons.
* **`widgets/inputs/`**: Styled input fields and 6-digit PIN code boxes.
* **`widgets/cards/`**: Metric cards, timetable routine cards, and elevated cards.
* **`widgets/states/`**: Standard loading spinners, empty state illustrations, and error retry views.
* **`widgets/dialogs/`**: Confirmation dialogs and action modals.

---

### Layer 4: Feature Modules (`mobile/lib/features/`)
Every business domain is encapsulated in its own feature directory following **Clean Architecture**:

```text
features/<feature_name>/
├── data/
│   ├── datasources/       # Remote Firebase / REST API sources & local cache
│   ├── models/            # Data Transfer Objects (DTOs) with JSON serialization
│   └── repositories/      # Concrete repository implementations
├── domain/
│   ├── entities/          # Pure immutable Dart business models
│   ├── repositories/      # Abstract repository interfaces (contracts)
│   └── usecases/          # Single-responsibility business use cases
└── presentation/
    ├── controllers/       # State controllers / Notifiers (State management)
    ├── screens/           # Page-level widget compositions
    └── widgets/           # Feature-specific sub-widgets
```

#### Feature Breakdown:

1. **`auth/`**:
   * Login screen, sign-up petition form, session persistence, and logout lifecycle.
2. **`dashboard/`**:
   * 4 distinct scaffolds tailored per user role: Student Dashboard, CR Dashboard, Teacher Dashboard, Admin Dashboard.
3. **`attendance/`**:
   * Obsidian live 6-digit PIN attendance terminal for professors, PIN entry for students, and roster export for CRs.
4. **`schedule/`**:
   * Weekly class timetable, routine update announcements, and exam date schedules.
5. **`counseling/`**:
   * Faculty office hour slot management, appointment booking engine, and approval/rejection workflows.
6. **`feedback/`**:
   * Completely anonymous departmental course reviews, star ratings, and teacher reply threads.
7. **`notifications/`**:
   * Push notification listeners, badge counts, and categorized notification inbox.
8. **`profile/`**:
   * Student and faculty academic profiles, registration credentials, and semester badges.
9. **`curriculum/`**:
   * Course catalog, theoretical vs. lab credit breakdowns, and syllabus outlines.

---

## 3. 🧪 Testing (`mobile/test/`)

Mirrors the `lib/` directory structure for automated quality assurance:
* **`test/features/`**: Unit tests for business use cases, repository implementations with mocks (`mocktail`), and controller state flows.
* **`test/core/`**: Security tests for encrypted storage, token parsing, and network interceptors.
* **`test/widget_test.dart`**: Widget rendering, theme switching, and interaction tests.
