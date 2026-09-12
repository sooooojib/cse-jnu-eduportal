# `mobile/lib/app/` — Application Shell, Routing & Theming Guide

In Flutter Clean Architecture, the **`mobile/lib/app/`** directory ([`mobile/lib/app/`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/app)) acts as the **Application Shell and Master Orchestrator**.

While `features/` handles individual business screens and `core/` provides raw infrastructure, **`app/` defines how the app boots, how navigation and security guards work, and how the entire app looks and feels**.

---

## 📁 Directory Layout of `mobile/lib/app/`

```text
mobile/lib/app/
├── app.dart                   # 1. The Root Widget (MaterialApp.router)
│
├── router/                    # 2. Navigation & Role-Based Access Guards
│   ├── route_names.dart       # Constant route path strings
│   └── app_router.dart        # GoRouter definition with RBAC guards
│
└── theme/                     # 3. "Emerald Scholar" Design System Engine
    ├── app_colors.dart        # Palette tokens (Emerald, Obsidian, Surfaces)
    ├── app_typography.dart    # Plus Jakarta Sans & JetBrains Mono fonts
    ├── app_theme.dart         # Material 3 light & dark ThemeData
    ├── role_colors.dart       # Visual color badges for Student, CR, Teacher, Admin
    └── theme_controller.dart  # Reactive light/dark theme switcher & local persistence
```

---

## 🏛️ Pillar 1: The Root Application Widget (`app.dart`)

After `main.dart` initializes Firebase and dependencies, it calls:
```dart
runApp(CSEEduPortalApp(themeModeNotifier: themeController));
```

### What `app.dart` does:
1. **Constructs `MaterialApp.router`**: Wires the declarative router (`GoRouter`) and binds light/dark themes.
2. **Listens to Theme Changes**: Uses `ValueListenableBuilder<ThemeMode>` to smoothly animate between light and dark modes in 400ms (`Curves.easeInOutCubic`).
3. **Global Keyboard Dismissal**: Wraps the entire screen in a translucent `GestureDetector`:
   ```dart
   builder: (context, child) {
     return GestureDetector(
       behavior: HitTestBehavior.translucent,
       onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
       child: child,
     );
   }
   ```
   *Whenever a user taps anywhere outside a text field, the keyboard automatically collapses.*

---

## 🛡️ Pillar 2: Navigation & Role Guards (`app/router/`)

Because EduPortal is used by **Students**, **CRs**, **Teachers**, and **Admins**, navigation cannot be open. Students must never be able to access the admin panel or teacher terminals.

### 1. `route_names.dart`
Contains typed constant definitions for every URL route:
```dart
class RouteNames {
  static const String initial = '/';
  static const String login = '/login';
  static const String signupRequest = '/signup-request';
  static const String studentDashboard = '/dashboard/student';
  static const String teacherDashboard = '/dashboard/teacher';
  static const String crDashboard = '/dashboard/cr';
  static const String adminDashboard = '/dashboard/admin';
  static const String attendanceTerminal = '/attendance';
  static const String schedule = '/schedule';
  static const String counseling = '/counseling';
  static const String feedback = '/feedback';
  static const String studentProfile = '/profile';
  static const String notifications = '/notifications';
}
```

### 2. `app_router.dart` (The Security Shield)
Uses Flutter's `GoRouter`. It attaches a **`refreshListenable: auth`** listener: whenever a user logs in, logs out, or their token expires, the router automatically triggers re-evaluation:

```dart
redirect: (context, state) {
  final authState = auth.state;
  final currentPath = state.matchedLocation;

  // 1. If not authenticated, redirect all protected screens to /login
  if (authState is! Authenticated) {
    return isLoggingIn ? null : RouteNames.login;
  }

  // 2. Role-Based Access Control (RBAC) Guard
  final user = authState.user;

  // A student trying to navigate to /dashboard/admin gets redirected back!
  if (currentPath == RouteNames.adminDashboard && user.role != UserRole.admin) {
    return _getDashboardRouteForRole(user.role);
  }

  // A non-teacher trying to navigate to /dashboard/teacher gets kicked back!
  if (currentPath == RouteNames.teacherDashboard &&
      user.role != UserRole.teacher &&
      user.role != UserRole.admin) {
    return _getDashboardRouteForRole(user.role);
  }

  // A non-CR trying to navigate to /dashboard/cr gets kicked back!
  if (currentPath == RouteNames.crDashboard &&
      user.role != UserRole.cr &&
      user.role != UserRole.admin) {
    return _getDashboardRouteForRole(user.role);
  }

  return null; // Route permitted
}
```

---

## 🎨 Pillar 3: Design System & Theme Engine (`app/theme/`)

This package implements the **Emerald Scholar** design system so that no widget has to hardcode hex colors or font families.

### 1. `app_colors.dart`
The centralized color palette:
* **Primary**: Deep Emerald (`#006948`), Emerald Light (`#00855D`), Mint Container (`#85F8C4`).
* **Obsidian Terminal**: `#18181B` (Obsidian Canvas) + glowing `#34D399` text for live attendance sessions.
* **Surfaces**: Crisp light containers (`#F8F9FF`) and deep dark mode surfaces (`#0B1C30`).

### 2. `app_typography.dart`
Configures typography using Google Fonts:
* **Headings & Body**: *Plus Jakarta Sans* (modern, geometric academic feel).
* **Terminal & PIN codes**: *JetBrains Mono* (monospaced code precision).

### 3. `role_colors.dart`
Applies distinctive branding per role so users instantly recognize their context:
* 🟢 **Student**: Emerald Green
* 🟣 **CR**: Royal Violet / Purple
* 🔵 **Teacher**: Sapphire Blue
* 🔴 **Admin**: Crimson / Amber

### 4. `theme_controller.dart`
A `ValueNotifier<ThemeMode>` that manages theme changes and automatically saves the user's choice to local storage:
```dart
class ThemeController extends ValueNotifier<ThemeMode> {
  // Persists 'light', 'dark', or 'system' to SharedPreferences
  Future<void> setThemeMode(ThemeMode mode) async { ... }
  Future<void> toggleTheme(BuildContext context) async { ... }
}
```

### 5. `app_theme.dart`
Generates comprehensive Material 3 `ThemeData` objects for `lightTheme` and `darkTheme`:
* Configures pill-shaped buttons (`RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))`).
* Soft card corner radii (`20px - 28px`).
* Outlined text fields with focus states and error highlighting.

---

## 🔄 How `app/` Interacts With the Rest of the Project

```text
       main.dart (Bootstrapper)
             │
             ▼
    mobile/lib/app/app.dart (Root Widget)
     ├── Injects theme/ (Emerald Scholar Material 3 Theme)
     │       └── Driven by theme/theme_controller.dart
     │
     └── Injects router/ (GoRouter)
             ├── Reads AuthController from features/auth/
             ├── Checks UserRole from core/constants/
             └── Mounts appropriate Screen from features/<feature>/
```

### Summary
* Without **`app.dart`**, Flutter has no root widget to run.
* Without **`router/`**, screens cannot navigate safely and unauthorized users could view sensitive admin/faculty data.
* Without **`theme/`**, screens would have inconsistent colors, standard ugly defaults, and no dark mode support.
