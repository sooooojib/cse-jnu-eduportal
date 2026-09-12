# `mobile/lib/core/` — Foundational Infrastructure & Core Utilities Guide

In Flutter Clean Architecture, the **`mobile/lib/core/`** directory ([`mobile/lib/core/`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core)) represents the **foundational bedrock and cross-cutting utility layer** of the mobile application.

### 🏛️ The Clean Architecture Rule for `core/`:
* Code in **`core/`** contains tools, network clients, storage services, error models, and constants that are shared across all 9 features.
* Individual features in `features/` depend heavily on `core/`.
* `core/` does **not** depend on specific feature business logic. It provides generic, robust building blocks.

---

## 📁 Directory Layout of `mobile/lib/core/`

```text
mobile/lib/core/
├── di/               # 1. Dependency Injection Container (GetIt)
├── config/           # 2. Environment & Runtime Configuration
├── constants/        # 3. University Roles, API Endpoints & Storage Keys
├── network/          # 4. HTTP Client, Connectivity & Interceptors
├── storage/          # 5. Encrypted Hardware Keystore & Local Preferences
├── error/            # 6. Domain Failures & Exception Translators
├── logging/          # 7. Structured Console & Production Logger
└── utils/            # 8. Validators (JnU ID, BD Phone), Formatters & Extensions
```

---

## 1. 💉 Dependency Injection (`core/di/`)

* **`injection_container.dart`**:
  * Uses **`GetIt`** (`sl` = Service Locator) to configure the entire app's dependency graph in one place.
  * Ensures loose coupling and testability by registering:
    1. **Platform singletons**: `SharedPreferences`, `FlutterSecureStorage`, `FirebaseAuth`, `FirebaseFirestore`.
    2. **Core services**: `ApiClient`, `SecureStorageService`, `LocalStorageService`.
    3. **Feature data sources & repositories**: `AuthRepositoryImpl`, `AttendanceRepositoryImpl`, etc.
    4. **Domain use cases**: `LoginUseCase`, `SubmitAttendanceUseCase`, etc.
    5. **Controllers / Notifiers**: `AuthController`, `ScheduleController`, `ThemeController`.

```dart
// Resolving any dependency anywhere in the app
final authController = sl<AuthController>();
```

---

## 2. ⚙️ Configuration (`core/config/`)

* **`env_config.dart`**: Manages environment variables (API base URLs, timeouts, production vs. staging flags).
* **`firebase_options.dart`**: Google Cloud & Firebase project parameters (`projectId: 'sajib-73b14'`) for all supported platforms.

---

## 3. 🏷️ Constants (`core/constants/`)

Centralizes all magic strings, enums, and static identifiers to prevent typo bugs:

* **`role_constants.dart`**:
  Defines the authoritative `UserRole` enum and role helper methods:
  ```dart
  enum UserRole {
    student('STUDENT', 'Student'),
    cr('CR', 'Class Representative'),
    teacher('TEACHER', 'Professor / Faculty'),
    admin('ADMIN', 'Administrator');

    bool get isStudent => this == UserRole.student;
    bool get isTeacher => this == UserRole.teacher;
    bool get isCr => this == UserRole.cr;
    bool get isAdmin => this == UserRole.admin;
  }
  ```
* **`app_constants.dart`**: Storage keys (`keyAccessToken`, `keyUserId`), timeout limits, and app metadata.
* **`api_endpoints.dart`**: URLs for backend endpoints (`/auth/login`, `/attendance/verify`, `/counseling/slots`).

---

## 4. 🌐 Network Layer (`core/network/`)

* **`api_client.dart`**: Centralized HTTP client wrapper. Standardizes `GET`, `POST`, `PUT`, `DELETE` requests, timeout handling, and JSON serialization.
* **`network_info.dart`**: Checks real-time device internet connectivity before dispatching requests.
* **`auth_interceptor.dart`**: Injects bearer tokens and handles token expiration hooks.

---

## 5. 🔐 Storage Layer (`core/storage/`)

Segregates data storage into **Encrypted Sensitive** vs. **Fast Non-Sensitive**:

* **`secure_storage_service.dart`**:
  * Wraps `FlutterSecureStorage`.
  * Encrypts tokens, user IDs, and session keys inside hardware-backed security modules:
    * **Android**: `EncryptedSharedPreferences` backed by the **Android Keystore**.
    * **iOS**: **Apple Keychain** with `KeychainAccessibility.first_unlock`.
* **`local_storage_service.dart`**:
  * Wraps `SharedPreferences` for fast, unencrypted local caching (active theme preference, offline routine cache).

---

## 6. ⚠️ Error & Failure Handling (`core/error/`)

In Clean Architecture, we do not let raw runtime crashes bubble up to the UI. The error layer converts them into typed, safe objects:

* **`failures.dart`**:
  Pure domain-level objects extending `Equatable`:
  * `ServerFailure`: 500 internal server errors.
  * `AuthFailure`: 401 unauthenticated errors.
  * `ForbiddenFailure`: 403 unauthorized role access attempts.
  * `ValidationFailure`: 422 invalid input submissions.
  * `NetworkFailure`: Device has no internet connection.
* **`exceptions.dart`**: Data-layer exceptions thrown during network or storage calls.
* **`error_handler.dart`**: Translates raw exceptions or HTTP status codes into typed `Failure` models that the UI controllers can easily display as snackbars or dialogs.

---

## 7. 📝 Logging (`core/logging/`)

* **`app_logger.dart`**: Structured logging wrapper around the `logger` package.
* Color-codes and tags logs for easy debugging during development:
  * 💡 `AppLogger.i('...')`: Informational events (e.g. "Firebase Core initialized").
  * ⚠️ `AppLogger.w('...')`: Warnings (e.g. "Offline cache fallback used").
  * ❌ `AppLogger.e('...', error, stack)`: Critical errors with stack traces.

---

## 8. 🛠️ Utilities & Helpers (`core/utils/`)

* **`validators.dart`**:
  University-specific regex validations:
  * **Jagannath University Student ID**: Must match `^[Bb]\d{9}$` (e.g. `B210305015`).
  * **Bangladesh Phone Number**: Must match `^(\+88)?01[3-9]\d{8}$`.
  * **Strong Password**: Requires 8+ chars, uppercase, lowercase, digit, and special character.
  * **Email**: Validates university or personal email formats.
* **`formatters.dart`**: Formats dates, class routine time slots (e.g. "09:00 AM - 10:30 AM"), and semester badges.
* **`context_extensions.dart`**: Convenient syntax shortcuts on `BuildContext`:
  * `context.theme` instead of `Theme.of(context)`
  * `context.colors` instead of `Theme.of(context).colorScheme`
  * `context.showSnackBar('Message')` instead of `ScaffoldMessenger.of(context).showSnackBar(...)`

---

### Summary
`core/` is the **engine room** of the app. It ensures that features don't have to re-invent network clients, storage security, role checks, or input validations—everything is unified, secure, and standardized.
