# Firebase Architecture — CSE JnU EduPortal
## Stage 11: Full Firebase Migration

---

## 1. Architectural Principle

```
┌─────────────────────────────────────────────────────────────────┐
│                    CSE JnU EduPortal                            │
│                                                                 │
│   ┌──────────────────────────┐   ┌───────────────────────────┐  │
│   │   Flutter Mobile Client  │   │   Firebase Backend         │ │
│   │                          │   │   Platform                 │ │
│   │  • Presentation Layer    │◄─►│  • Firebase Auth           │ │
│   │  • Domain Logic          │   │  • Cloud Firestore         │ │
│   │  • State Management      │   │  • Cloud Storage           │ │
│   │  • Offline Cache         │   │  • Cloud Functions         │ │
│   │  • GetIt DI              │   │  • FCM Push                │ │
│   │                          │   │  • App Check               │ │
│   │                          │   │  • Crashlytics             │ │
│   └──────────────────────────┘   └───────────────────────────┘  │
│                                                                 │
│   PRINCIPLE: Flutter is the client. Firebase IS the backend.    │
│   Security Rules + Cloud Functions enforce all authorization.   │
│   Flutter is NEVER trusted for security-sensitive decisions.    │
└─────────────────────────────────────────────────────────────────┘
```

The golden rule: Flutter renders UI and manages local state. Firebase stores all data and enforces all security. Cloud Functions execute all server-side trusted operations. Security Rules are the last wall and cannot be bypassed by any client.

---

## 2. Firebase Services

| Firebase Service | Role in EduPortal | Priority |
|:---|:---|:---:|
| **Firebase Authentication** | User identity, session management, UID issuance | Critical |
| **Cloud Firestore** | Primary database for all application data | Critical |
| **Cloud Storage** | File uploads: feedback attachments, profile avatars | High |
| **Cloud Functions (Gen 2)** | Trusted server-side operations requiring atomicity or Admin SDK | High |
| **Firebase Cloud Messaging** | Push notifications to student/teacher devices | High |
| **Firebase App Check** | Client attestation to reject non-genuine app requests | Medium |
| **Firebase Crashlytics** | Production crash reporting and diagnostics | Medium |
| **Firebase Remote Config** | Feature flags and environment-specific configuration | Low |

---

## 3. System Layer Diagram

```
                    ┌──────────────────────┐
                    │   Flutter App        │
                    │                      │
                    │  Presentation        │
                    │  Controllers (GetIt) │
                    │  Domain Use Cases    │
                    │  Repository Impls    │
                    └──────────┬───────────┘
                               │ Firebase SDK calls
             ┌─────────────────┼──────────────────────┐
             │                 │                      │
             ▼                 ▼                      ▼
    ┌─────────────┐   ┌───────────────┐   ┌─────────────────┐
    │  Firebase   │   │  Cloud        │   │  Cloud          │
    │  Auth       │   │  Firestore    │   │  Storage        │
    │             │   │               │   │                 │
    │  - Sign In  │   │  - users/     │   │  - avatars/     │
    │  - Sign Out │   │  - courses/   │   │  - attachments/ │
    │  - UID      │   │  - schedules/ │   │                 │
    │  - Token    │   │  - attendance/│   └─────────────────┘
    └─────────────┘   │  - counseling/│
                      │  - feedback/  │
                      │  - notifs/    │
                      └───────┬───────┘
                              │ Firestore triggers / onCall
                              ▼
                    ┌─────────────────────┐
                    │  Cloud Functions    │
                    │  (Trusted Layer)    │
                    │                    │
                    │  - Account Approval│
                    │  - Booking Engine  │
                    │  - Email Dispatch  │
                    │  - FCM Dispatch    │
                    │  - Attendance Lock │
                    └─────────────────────┘
```

---

## 4. Authentication Architecture

### 4.1 Login Flow

```
[Flutter: Login Screen]
        │
        │ FirebaseAuth.signInWithEmailAndPassword()
        ▼
[Firebase Auth Service]
        │ Returns Firebase User (UID, email, refreshToken)
        ▼
[Flutter: Fetches Firestore /users/{uid}]
        │ Gets role, year, semester, name, studentId
        ▼
[AuthController: Stores UserModel in memory + SharedPreferences]
        │
        ▼
[GoRouter: Navigates to role-based dashboard]
```

### 4.2 Session Management

- Firebase Auth manages **persistent sessions** automatically on-device.
- ID tokens auto-refresh every 60 minutes — no manual interceptor needed.
- `FirebaseAuth.authStateChanges()` stream drives GoRouter navigation guards.
- `hasValidSession()` checks `FirebaseAuth.instance.currentUser != null`.
- No JWT tokens stored in SecureStorage — Firebase SDK handles everything.

### 4.3 Signup Pipeline (Admin-Gated)

```
[Flutter: SignupRequest Form (public)]
        │
        │ Firestore.collection('signupRequests').add({...})
        │ No Firebase Auth account created yet
        ▼
[Firestore: /signupRequests/{reqId}  status: PENDING]
        │
        │ Admin sees pending queue in Admin Dashboard
        │ Admin taps "Approve"
        ▼
[Cloud Function: approveSignupRequest (onCall, ADMIN only)]
        │ Uses Firebase Admin SDK — bypasses Security Rules
        ├── Creates Firebase Auth user (email + auto-generated password)
        ├── Sets Custom Claims: { role, year, semester }
        ├── Creates /users/{uid} Firestore document
        ├── Updates /signupRequests/{reqId} → status: APPROVED
        └── Sends welcome email with credentials via SendGrid/Nodemailer
```

### 4.4 Custom Claims for RBAC

Roles are stored in both Firestore (`/users/{uid}`) and Firebase Auth **Custom Claims**. Security Rules use Custom Claims to avoid paying for a Firestore read on every request:

```javascript
// Custom Claims set by Cloud Function at account creation / role change
{
  "role": "STUDENT",   // or CR, TEACHER, ADMIN
  "year": 3,
  "semester": 1
}
```

Custom Claims are updated whenever:
- A signup request is approved (initial assignment)
- An admin changes a user's role
- A semester upgrade petition is approved

---

## 5. Cloud Functions — Trusted Operations Inventory

These operations are executed by Cloud Functions (not Flutter) because they require the Admin SDK, atomicity across multiple documents, or privileged operations.

| Function | Trigger | Operation |
|:---|:---|:---|
| `approveSignupRequest` | `onCall` | Creates Auth user, Firestore profile, sends welcome email |
| `rejectSignupRequest` | `onCall` | Updates request status, sends rejection email |
| `approveSemesterUpgrade` | `onCall` | Updates user year/semester, updates custom claims, sends notification |
| `rejectSemesterUpgrade` | `onCall` | Updates request, sends rejection notification |
| `approveCounselingBooking` | `onCall` | Atomic: approves one request, rejects all others, marks slot BOOKED |
| `openAttendanceSession` | `onCall` | Validates teacher owns course, creates session with 6-char code |
| `closeAttendanceSession` | `onCall` | Sets session CLOSED, prevents further student submissions |
| `dispatchPushNotification` | Firestore `onWrite` on `/notifications/{id}` | Reads FCM token from user doc, sends FCM message |
| `exportAttendanceExcel` | `onCall` (HTTP response) | Aggregates records, builds and returns .xlsx binary |
| `sendWelcomeEmail` | Internal call from approveSignupRequest | HTML email with auto-generated credentials |

All `onCall` functions verify `context.auth.token.role` before executing.

---

## 6. Offline Behavior

Firestore offline persistence is enabled globally in `main.dart`:

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

| Feature | Online | Offline |
|:---|:---:|:---:|
| View class timetable | ✅ Live | ✅ From cache |
| View course list | ✅ Live | ✅ From cache |
| View user profile | ✅ Live | ✅ SharedPrefs cache |
| View exam schedule | ✅ Live | ✅ From cache |
| Submit attendance code | ✅ Live | ❌ Requires validation |
| Submit feedback | ✅ Live | ❌ Requires write |
| View notifications | ✅ Live | ✅ Cached list |
| View attendance history | ✅ Live | ✅ From cache |

---

## 7. Development vs Production Environments

| Concern | Development | Production |
|:---|:---|:---|
| Firebase Project | `cse-jnu-eduportal-dev` | `cse-jnu-eduportal` |
| Firestore Rules | Open (dev/test mode) | Full Security Rules |
| App Check | Debug provider | Play Integrity (Android) |
| Crashlytics | Disabled | Enabled |
| Firebase Emulator | Auth + Firestore + Functions | — |
| Cloud Functions | Emulator / functions:shell | Deployed Gen 2 |
| FCM | Test device tokens | Registered prod tokens |
| Environment flag | `ENV=development` | `ENV=production` |

Environment configuration is selected via `--dart-define=ENV=production` at build time, which loads the correct `FirebaseOptions` instance.

---

## 8. Flutter Clean Architecture — Layer Map After Migration

```
lib/features/<feature>/
├── data/
│   ├── datasources/         ← Firebase SDK calls (Firestore, Storage, Auth)
│   ├── models/              ← DTOs with Timestamp → String conversion
│   └── repositories/        ← Maps Firestore docs → Domain entities
├── domain/
│   ├── entities/            ← UNCHANGED: pure Dart models
│   ├── repositories/        ← UNCHANGED: abstract contracts
│   └── usecases/            ← UNCHANGED: business rules
└── presentation/
    ├── controllers/          ← UNCHANGED: GetIt state management
    ├── screens/              ← UNCHANGED: Flutter UI
    └── widgets/              ← UNCHANGED: Flutter components

lib/core/
├── config/
│   └── firebase_options.dart  ← NEW: FlutterFire config
├── di/
│   └── injection_container.dart ← UPDATED: wires Firebase singletons
├── error/
│   ├── error_handler.dart   ← UPDATED: handles FirebaseException
│   ├── exceptions.dart      ← UNCHANGED
│   └── failures.dart        ← UNCHANGED
└── storage/
    └── local_storage_service.dart ← UNCHANGED: SharedPrefs for user cache
```

**Removed from core/:**
- `network/api_client.dart` — no HTTP client needed
- `network/auth_interceptor.dart` — Firebase handles token refresh
- `network/network_info.dart` — Firestore handles connectivity internally
- `constants/api_endpoints.dart` — no REST endpoints
- `storage/secure_storage_service.dart` — no JWT tokens to store
