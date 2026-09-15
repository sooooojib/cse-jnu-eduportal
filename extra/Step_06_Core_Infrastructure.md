# `Step 06` — Deep Dive: `mobile/lib/core/` (Foundational Infrastructure)

In Flutter Clean Architecture, the **`mobile/lib/core/`** directory ([`mobile/lib/core/`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core)) is the **lowest and most fundamental layer of the application**.

While `features/` handles specific business domains (like *Attendance* or *Counseling*) and `app/` handles the outer shell (root widget & router), **`core/` provides the non-negotiable plumbing and services that every feature relies upon**.

```text
┌────────────────────────────────────────────────────────┐
│                      mobile/lib/                       │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ app/      (Root Shell, GoRouter Guards, Theme)   │  │
│  └─────────────────────────┬────────────────────────┘  │
│                            ▼                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ features/ (Auth, Attendance, Schedule, etc.)     │  │
│  └─────────────────────────┬────────────────────────┘  │
│                            ▼                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ core/     (DI, Keystore, Errors, Constants, Etc) │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

### 🏛️ The Golden Clean Architecture Rule of `core/`:
1. **Zero Downward Dependencies**: `core/` contains no knowledge of specific screen layouts or feature-specific logic.
2. **Reusability & Inversion**: All features import `core/`, but `core/` remains completely generic (with the single exception of `injection_container.dart`, which acts as the composition root that glues everything together).

---

## 📁 Full File Tree of `mobile/lib/core/`

```text
mobile/lib/core/
├── di/
│   └── injection_container.dart      # 1. Dependency Injection Service Locator (GetIt)
├── config/
│   ├── env_config.dart               # 2. Environment Variables & App Config
│   └── firebase_options.dart         # 3. Platform Credentials
├── constants/
│   ├── role_constants.dart           # 4. UserRole Enum (STUDENT, CR, TEACHER, ADMIN)
│   └── app_constants.dart            # 5. Storage Keys, Timeouts & Defaults
├── storage/
│   ├── secure_storage_service.dart   # 6. Hardware Keystore/Keychain Encrypted Storage
│   └── local_storage_service.dart    # 7. Fast SharedPreferences Key-Value Storage
├── error/
│   ├── failures.dart                 # 8. Pure Domain Failures (Equatable)
│   ├── exceptions.dart               # 9. Data-Layer Exceptions
│   └── error_handler.dart            # 10. Exception-to-Failure Translation Engine
├── logging/
│   └── app_logger.dart               # 11. Structured Production & Console Logger
└── utils/
    ├── validators.dart               # 12. University Regexes (JnU ID, BD Phone, Passwords)
    ├── formatters.dart               # 13. Academic & Date Formatters
    └── context_extensions.dart       # 14. BuildContext Helper Extensions
```

---

## 1. 💉 Dependency Injection (`core/di/injection_container.dart`)

The dependency injection container is the **Composition Root** of the app. It uses **`GetIt`** (`sl` = Service Locator) to build the entire dependency graph at startup.

### Why `registerLazySingleton` vs `registerFactory`?
* **`registerLazySingleton`**: Instantiates the class **only once** the very first time it is requested, and reuses that identical instance everywhere. This saves memory and maintains state (e.g. `SharedPreferences`, `FirebaseAuth`, `AuthController`).
* **`registerFactory`**: Creates a **fresh, new instance** every time it is requested (used for short-lived controllers or transient form handlers).

### The 7-Phase Registration Order:
Inside [`initDependencies()`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core/di/injection_container.dart#L57):

```dart
Future<void> initDependencies() async {
  // Phase 1: Native Platform Storage Singletons
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  // Phase 2: Firebase Cloud Singletons
  sl.registerLazySingleton<fb.FirebaseAuth>(() => fb.FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  sl.registerLazySingleton<FirebaseMessaging>(() => FirebaseMessaging.instance);
  sl.registerLazySingleton<FirebaseFunctions>(() => FirebaseFunctions.instance);

  // Phase 3: Core Storage & Theme Services
  sl.registerLazySingleton<LocalStorageService>(() => LocalStorageServiceImpl(prefs: sl()));
  sl.registerLazySingleton<ThemeController>(() => ThemeController(localStorageService: sl()));

  // Phase 4: Feature DataSources (e.g., AuthRemoteDataSource)
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(auth: sl(), firestore: sl()),
  );

  // Phase 5: Feature Repositories (implements Domain contract)
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), localStorage: sl()),
  );

  // Phase 6: Domain Use Cases (Single responsibility business actions)
  sl.registerLazySingleton<LoginUseCase>(() => LoginUseCase(repository: sl()));
  sl.registerLazySingleton<GetCurrentUserUseCase>(() => GetCurrentUserUseCase(repository: sl()));
  sl.registerLazySingleton<LogoutUseCase>(() => LogoutUseCase(repository: sl()));

  // Phase 7: Presentation State Controllers
  sl.registerLazySingleton<AuthController>(
    () => AuthController(
      loginUseCase: sl(),
      getCurrentUserUseCase: sl(),
      logoutUseCase: sl(),
      resetPasswordUseCase: sl(),
    ),
  );
}
```

#### 💡 The Magic of Constructor Injection (`sl()`):
Notice `AuthRepositoryImpl(remoteDataSource: sl(), localStorage: sl())`. When `GetIt` sees `sl()`, it looks up its registered catalog, finds `AuthRemoteDataSource` and `LocalStorageService`, and injects them automatically!

---

## 2. 🔐 Dual-Tier Storage Layer (`core/storage/`)

A university mobile app handles both **highly sensitive session tokens** and **non-sensitive UI preferences**. EduPortal cleanly segregates them into two tiers:

```text
               STORAGE LAYER
                     │
      ┌──────────────┴──────────────┐
      ▼                             ▼
[Tier 1: Hardware Keystore]   [Tier 2: Fast Preferences]
SecureStorageService          LocalStorageService
(JWTs, User IDs, Roles)       (Theme Mode, Active Semester)
```

### Tier 1: Hardware-Encrypted Storage ([`secure_storage_service.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core/storage/secure_storage_service.dart))
Uses `FlutterSecureStorage` to store data in the mobile device's cryptographic hardware:
* **Android**: Uses **Android Keystore** with `EncryptedSharedPreferences: true` (AES-256 GCM encryption).
* **iOS**: Uses the **Apple Keychain** with `KeychainAccessibility.first_unlock` (hardware enclave protection).

```dart
// Saving sensitive session credentials
await _storage.write(key: AppConstants.keyAccessToken, value: token);
await _storage.write(key: AppConstants.keyUserId, value: userId);
await _storage.write(key: AppConstants.keyUserRole, value: role);
```

### Tier 2: Fast Local Storage ([`local_storage_service.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core/storage/local_storage_service.dart))
Uses `SharedPreferences` for fast, non-sensitive local caching:
* `setThemeMode('light' | 'dark' | 'system')` / `getThemeMode()`
* `setActiveSemester(year, semester)` / `getActiveSemester()` (returns a Dart record: `(int year, int semester)?`)
* Fast-boot routine caching.

---

## 3. ⚠️ Error & Failure Architecture (`core/error/`)

In amateur Flutter apps, exceptions are thrown directly to the UI, causing red error screens or crashes. 

In Clean Architecture, **errors are modeled as typed data values**:

```text
Data Layer (Throws Exceptions)
       │
       ▼
core/error/error_handler.dart (Translates to Failures)
       │
       ▼
Domain Layer (Returns Failures to Presentation)
```

### 1. `exceptions.dart` (Data Layer)
Thrown when low-level network, database, or device operations fail:
* `ServerException`, `AuthException`, `ValidationException`, `ForbiddenException`, `NetworkException`, `CacheException`.

### 2. `failures.dart` (Domain Layer)
Pure immutable Dart objects extending `Equatable` that use cases and controllers pass safely:
```dart
abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final int? statusCode;
  ...
}

class AuthFailure extends Failure { ... }       // 401 Unauthorized
class ForbiddenFailure extends Failure { ... }  // 403 Role Forbidden
class ValidationFailure extends Failure { ... } // 422 Invalid Form Input
class ServerFailure extends Failure { ... }     // 500 Backend / Cloud Error
class NetworkFailure extends Failure { ... }    // No Internet Connection
```

### 3. `error_handler.dart` (The Translator)
Translates complex Google Firebase errors into user-friendly messages:
```dart
static Failure _handleFirebaseAuthError(fb.FirebaseAuthException e) {
  switch (e.code) {
    case "user-not-found":
    case "wrong-password":
    case "invalid-credential":
      return const AuthFailure(message: "Invalid email or password.");
    case "user-disabled":
      return const AuthFailure(message: "Your account has been disabled by administration.");
    case "too-many-requests":
      return const AuthFailure(message: "Too many failed attempts. Please wait 5 minutes.");
    default:
      return AuthFailure(message: e.message ?? "Authentication failed.");
  }
}
```

---

## 4. 🏷️ Constants & Domain Roles (`core/constants/`)

### [`role_constants.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core/constants/role_constants.dart)
Defines the authoritative `UserRole` enum used across the entire ecosystem:
```dart
enum UserRole {
  student('STUDENT', 'Student'),
  cr('CR', 'Class Representative'),
  teacher('TEACHER', 'Professor / Faculty'),
  admin('ADMIN', 'Administrator');

  final String value;
  final String label;
  const UserRole(this.value, this.label);

  static UserRole fromString(String role) { ... }

  // Boolean helper shortcuts used in UI and Route Guards
  bool get isStudent => this == UserRole.student;
  bool get isCr => this == UserRole.cr;
  bool get isTeacher => this == UserRole.teacher;
  bool get isAdmin => this == UserRole.admin;
}
```

### `app_constants.dart`
Centralizes key strings to prevent typos across teams:
* Storage keys: `keyAccessToken`, `keyRefreshToken`, `keyUserId`, `keyUserRole`, `keyThemeMode`, `keyActiveSemester`.
* Network timeouts: `connectionTimeout = 30000` (30 seconds).

---

## 5. 🛠️ Utilities & Helpers (`core/utils/`)

### [`validators.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core/utils/validators.dart) (Academic Regex Engine)
Provides strict form validation for Jagannath University:
```dart
// 1. Jagannath University Student ID: 'B' followed by 9 digits
static final RegExp _studentIdRegex = RegExp(r'^[Bb]\d{9}$'); // e.g. B210305015

// 2. Bangladesh Mobile Phone format: +8801...
static final RegExp _phoneRegex = RegExp(r'^(\+88)?01[3-9]\d{8}$');

// 3. Strong Password Enforcement:
// Must have 8+ characters, uppercase, lowercase, number, and special character
static String? password(String? value) { ... }
```

### [`context_extensions.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core/utils/context_extensions.dart)
Saves hundreds of lines of boilerplate by adding syntax shortcuts to `BuildContext`:
```dart
extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  bool get isDarkMode => theme.brightness == Brightness.dark;

  // Custom Floating SnackBar
  void showSnackBar(String message, {bool isError = false}) {
    ...
  }
}

// In any screen, you can simply write:
context.showSnackBar('Attendance code verified!');
```

---

## 6. 📝 Logging System (`core/logging/app_logger.dart`)

Wraps the `logger` package to provide styled console outputs with visual emoji indicators:
* 💡 `AppLogger.i('...')`: Information / lifecycle milestones.
* ⚠️ `AppLogger.w('...')`: Warnings and fallback events.
* ❌ `AppLogger.e('...', error, stackTrace)`: Critical errors with stack trace capture.

---

## 7. 🌐 Network & Cloud Infrastructure: Firebase-Native Architecture

Previously, the app planned a legacy REST networking layer (`mobile/lib/core/network/` with `api_client.dart`, `auth_interceptor.dart`, `network_info.dart`, and `api_endpoints.dart`).

### Why Were They Removed?
The project has fully migrated to a **Firebase-First Architecture** (`firebase_core`, `cloud_firestore`, `cloud_functions`, `firebase_auth`, `firebase_storage`). Consequently, all legacy REST network stubs and endpoint constants have been cleanly removed:

1. **Native WebSocket Connection Management**: The official Firebase SDK automatically manages WebSocket connections, streaming multiplexing, and TLS handshakes.
2. **Built-in Offline Persistence**: Cloud Firestore provides automatic local disk caching, offline read/write queues, and sub-millisecond local snapshot listeners without custom HTTP caching layers.
3. **Automated Token Management**: Firebase Auth manages automatic JWT token refreshes silently in the background, eliminating the need for Dio interceptors or manual 401 refresh retry loops.
4. **Declarative Security**: Access control and authorization are enforced at sub-millisecond speeds by `firestore.rules` and `storage.rules`, backed by custom token claims injected via Firebase Cloud Functions.

---

## 🔄 Lifecycle Example: How a Feature Uses `core/`

Here is what happens behind the scenes when a student taps **"Login"**:

```text
1. [features/auth/presentation/screens/login_screen.dart]
   Uses: core/utils/validators.dart -> Validates email & password format.
   Uses: core/utils/context_extensions.dart -> Reads theme & colors.
        │
        ▼
2. [features/auth/presentation/controllers/auth_controller.dart]
   Uses: core/di/injection_container.dart -> Resolved via sl<AuthController>().
   Calls: LoginUseCase.
        │
        ▼
3. [features/auth/data/datasources/auth_remote_datasource.dart]
   Executes Firebase Auth signIn.
   Catches: FirebaseAuthException.
   Uses: core/error/error_handler.dart -> Maps error code to AuthFailure.
        │
        ▼
4. [features/auth/data/repositories/auth_repository_impl.dart]
   Uses: core/storage/secure_storage_service.dart -> Saves JWT in hardware Keystore.
   Uses: core/logging/app_logger.dart -> Logs "User session established".
        │
        ▼
5. [app/router/app_router.dart]
   Uses: core/constants/role_constants.dart -> Reads user.role.isStudent
   Routes student to /dashboard/student!
```

---

### Summary
`mobile/lib/core/` is the **rock-solid engine room** of the entire Flutter project. By centralizing dependency injection, hardware-backed storage, typed error translation, and academic validation, it guarantees that every feature is built upon a secure, consistent, and testable foundation.
