# Flutter Mobile Application Architecture

## 1. Architectural Model

The **CSE JnU EduPortal** Flutter application follows the **Feature-Driven Clean Architecture** pattern. This structure ensures high testability, modular scalability, and complete decoupling of UI components from business logic and network protocols.

```
lib/
├── app/
│   ├── app.dart                   # Main MaterialApp & theme configuration
│   ├── router/                    # Declarative routing & navigation guards
│   └── theme/                     # Emerald Scholar design tokens & themes
├── core/
│   ├── constants/                 # App constants & API endpoints
│   ├── error/                     # Failure & Exception classes
│   ├── network/                   # HTTP client, interceptors & connectivity
│   ├── storage/                   # Secure storage & local persistence
│   └── utils/                     # Formatters, validators, extensions
└── features/
    ├── auth/                      # Authentication & Signup request
    ├── dashboard/                 # Role-based dashboards (Student, CR, Teacher, Admin)
    ├── attendance/                # Terminal, Code entry & Roster management
    ├── schedule/                  # Timetable routine & Exam scheduling
    ├── counseling/                # Office hours, Slots & Appointment booking
    ├── feedback/                  # Anonymous feedback, Star ratings & Replies
    └── admin/                     # User management & Course assignment
```

---

## 2. Layered Responsibilities within Each Feature

Each feature directory is divided into three strictly isolated layers:

```
features/<feature_name>/
├── data/
│   ├── datasources/               # Remote API data sources & Local cache
│   ├── models/                    # Data Transfer Objects (DTOs) & JSON serialization
│   └── repositories/              # Repository implementations (maps DTOs to Entities)
├── domain/
│   ├── entities/                  # Pure immutable business models (Dart)
│   ├── repositories/              # Abstract repository contracts / interfaces
│   └── usecases/                  # Single-responsibility business use cases
└── presentation/
    ├── controllers/               # State management controllers (Riverpod / BLoC)
    ├── screens/                   # Page-level widget compositions
    └── widgets/                   # Reusable feature-specific UI components
```

---

## 3. State Management & Dependency Injection

- **Predictable State Model**: State is modeled as immutable classes (e.g., `AsyncValue` / `StateNotifier` / `BlocState`) representing `Initial`, `Loading`, `Success<T>`, and `Error`.
- **Dependency Injection**: Dependencies (HTTP client, DataSources, Repositories, Use Cases) are registered and resolved using a clean DI container (Riverpod Providers or GetIt).
- **Decoupled UI**: Presentation widgets only consume domain states and dispatch user intents; they contain zero raw networking or direct database operations.

---

## 4. Networking, Authentication & Interceptors

- **HTTP Client**: Built with an HTTP abstraction (e.g., `Dio`) configured with:
  - **Base URL**: Dynamically configured via environment configurations.
  - **Auth Interceptor**: Automatically injects `Authorization: Bearer <token>` from Secure Storage into all protected requests.
  - **Token Refresh & Expiry Interceptor**: Intercepts `401 Unauthorized` responses to attempt silent token refresh or trigger automatic logout and navigation to `/login`.
  - **Logging & Error Transformer**: Maps standard HTTP status codes (400, 401, 403, 404, 422, 500) to typed domain `Failure` objects (`ServerFailure`, `AuthFailure`, `NetworkFailure`).

---

## 5. UI/UX & Emerald Scholar Theme Engine

- **Material 3 Foundation**: Built upon Google Material 3 with full support for Light and Dark themes.
- **Emerald Scholar Color Palette**:
  - `primary`: `#006948` (Emerald 600)
  - `primaryContainer`: `#00855d`
  - `surface`: `#F8F9FF` (Light) / `#0B1C30` (Dark)
  - `authGradient`: Linear gradient for welcome/auth surfaces
  - `terminalCanvas`: `#18181B` (Obsidian) with `#34D399` glowing monospace display
- **Typography Hierarchy**:
  - Headings & Body: **Plus Jakarta Sans**
  - Terminal Display & Verification Codes: **JetBrains Mono**
- **Shape Language**:
  - Pill-shaped buttons (`rounded-full`, 52px height)
  - Rounded containers (`rounded-2xl` to `rounded-3xl`)
  - Elevated cards with soft ambient shadows

---

## 6. Offline Support & Local Caching

- **Encrypted Keystore**: JWT tokens and sensitive session metadata are stored in `FlutterSecureStorage` (iOS Keychain / Android Keystore).
- **Fast-Boot Cache**: Class routine, semester course list, and user profile data are cached locally to provide an instant, zero-lag experience on cold app launch.
