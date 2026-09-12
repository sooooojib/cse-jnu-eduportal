# `mobile/lib/main.dart` — App Startup & Execution Guide

In Flutter, **[`mobile/lib/main.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/main.dart)** is the **ignition switch and bootstrapper** of the entire mobile application.

Before any pixel is rendered on the screen, `main.dart` executes critical asynchronous startup tasks: initializing native platform channels, establishing the Firebase backend connection, activating offline database caching, registering the dependency injection container, attaching crash shields, and mounting the root application widget.

---

## 📄 Complete Source Code Overview

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    AppLogger.i('Initializing Firebase Core...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.i('Firebase Core initialized successfully.');

    // Configure Cloud Firestore settings (offline persistence)
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      AppLogger.i('Firestore offline persistence enabled.');
    } catch (e) {
      AppLogger.w('Firestore offline settings note: $e');
    }

    AppLogger.i('Bootstrapping CSE JnU EduPortal dependency container...');
    await initDependencies();
    AppLogger.i('Core dependencies initialized successfully.');
  } catch (e, stack) {
    AppLogger.e('Firebase / Bootstrap initialization note: $e', e, stack);
  }

  // Handle uncaught Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.e('Uncaught Flutter Error', details.exception, details.stack);
  };

  // Handle uncaught asynchronous platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Uncaught Asynchronous Error', error, stack);
    return true;
  };

  final themeController = sl<ThemeController>();

  runApp(CSEEduPortalApp(themeModeNotifier: themeController));
}
```

---

## 🔍 Step-by-Step Execution Breakdown

### Step 1: Bind Flutter Engine to Native OS
```dart
WidgetsFlutterBinding.ensureInitialized();
```
* **Why it's needed:** In Flutter, Dart code communicates with native iOS/Android code via Platform Channels. Because the app calls asynchronous native plugins (`Firebase.initializeApp()`) *before* `runApp()`, the Flutter engine binary messenger must be initialized first. Calling native plugins before this binding is established throws a fatal runtime exception.

---

### Step 2: Initialize Firebase Core
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```
* Connects the mobile client to Google Firebase backend services (Auth, Firestore, Cloud Storage, Cloud Functions, and Cloud Messaging).
* `DefaultFirebaseOptions.currentPlatform` automatically provides the correct API keys and project configurations depending on whether the app runs on Android, iOS, or macOS.

---

### Step 3: Enable Firestore Offline Persistence
```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```
* **Why it matters:** On a university campus, Wi-Fi or mobile data may be unstable or unavailable in certain classrooms.
* Enabling disk persistence ensures that once a student or faculty member loads their **class routine**, **syllabus catalog**, or **profile**, Firestore caches that data on the device's local disk.
* On subsequent cold launches, the user can open the app and instantly review their class schedules and records without waiting for network connectivity.

---

### Step 4: Bootstrap Dependency Injection (`initDependencies`)
```dart
await initDependencies();
```
* Calls `initDependencies()` inside [`mobile/lib/core/di/injection_container.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core/di/injection_container.dart).
* Uses `GetIt` (`sl` = Service Locator) to register all application dependencies:
  * **External & Storage**: `SharedPreferences`, `FlutterSecureStorage`, network client.
  * **Data Layer**: `AuthRemoteDataSource`, `AttendanceRepositoryImpl`, `CurriculumRepositoryImpl`, `CounselingRepositoryImpl`, etc.
  * **Domain Layer (Business Rules)**: `LoginUseCase`, `SubmitAttendanceUseCase`, `SignupRequestUseCase`, `ResetPasswordUseCase`, etc.
  * **Presentation Controllers**: `AuthController`, `ScheduleController`, `AttendanceController`, `ThemeController`.

---

### Step 5: Attach Global Error Handlers (Crash Prevention Shield)
```dart
// 1. Catches Flutter framework & UI layout errors
FlutterError.onError = (FlutterErrorDetails details) {
  FlutterError.presentError(details);
  AppLogger.e('Uncaught Flutter Error', details.exception, details.stack);
};

// 2. Catches unhandled asynchronous platform/isolate errors
PlatformDispatcher.instance.onError = (error, stack) {
  AppLogger.e('Uncaught Asynchronous Error', error, stack);
  return true; // Prevents app from hard crashing to home screen
};
```
* **Why it's crucial:**
  1. `FlutterError.onError` catches UI-level issues (such as render overflows or layout assertion failures) and logs them cleanly without terminating the app.
  2. `PlatformDispatcher.instance.onError` catches unhandled asynchronous exceptions (such as network timeouts or background Future failures). Returning `true` tells Flutter that the error was handled, preventing a hard crash to the phone's home screen.

---

### Step 6: Resolve Saved Theme Mode
```dart
final themeController = sl<ThemeController>();
```
* Retrieves the registered `ThemeController` singleton from `GetIt`.
* The controller reads the user's saved preference (Light Mode, Dark Mode, or System Default) from local storage so the correct theme is applied immediately upon launch.

---

### Step 7: Launch the Application UI
```dart
runApp(CSEEduPortalApp(themeModeNotifier: themeController));
```
1. Mounts **`CSEEduPortalApp`** ([`mobile/lib/app/app.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/app/app.dart)) as the root widget.
2. Passes `themeController` as a reactive `ValueNotifier<ThemeMode>`.
3. Hands over execution to `GoRouter` ([`mobile/lib/app/router/app_router.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/app/router/app_router.dart)), which checks the user's authentication state and redirects to the Splash Screen, Login Screen, or permitted Role Dashboard.

---

## ⏱️ Visual Startup Timeline

```text
[ Cold Launch (User taps app icon) ]
             │
             ▼
1. WidgetsFlutterBinding.ensureInitialized()   -> Native binary bridge ready
             │
             ▼
2. Firebase.initializeApp()                    -> Auth & Firestore connected
             │
             ▼
3. FirebaseFirestore settings                  -> Unlimited offline disk cache enabled
             │
             ▼
4. initDependencies()                          -> Repositories, Use Cases & Controllers registered in GetIt
             │
             ▼
5. Global Error Listeners attached             -> Unhandled exceptions caught & logged
             │
             ▼
6. sl<ThemeController>()                       -> Reads saved theme (Light/Dark/System)
             │
             ▼
7. runApp(CSEEduPortalApp)                     -> Hands off to GoRouter & renders UI!
```
