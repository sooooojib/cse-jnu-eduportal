# System Architecture Overview

## 1. Architectural Philosophy

The **CSE JnU EduPortal** follows a strict, layered Clean Architecture designed for high maintainability, robust testability, security, and responsive mobile performance. The architecture pairs a **Flutter Mobile Client** with a **Firebase Serverless Engine** (Cloud Firestore, Firebase Authentication, Cloud Functions Gen 2, and Cloud Storage).

```
┌────────────────────────────────────────────────────────┐
│                  FLUTTER MOBILE CLIENT                 │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Presentation Layer (Widgets, Screens, Notifiers) │  │
│  └─────────────────────────┬────────────────────────┘  │
│                            ▼                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Domain Layer (Entities, Use Cases, Repositories) │  │
│  └─────────────────────────┬────────────────────────┘  │
│                            ▼                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Data Layer (DTOs, Remote DataSources, LocalStore)│  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────┬───────────────────────────┘
                             │
            Official Firebase SDK (Client-Side)
            Declarative Security Rules Enforcement
                             ▼
┌────────────────────────────────────────────────────────┐
│               FIREBASE SERVERLESS ENGINE               │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Cloud Firestore (Sub-ms NoSQL, Offline Cache)    │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Firebase Authentication (Custom Claims RBAC)     │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Cloud Functions (Privileged Admin & Triggers)    │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Cloud Storage (Media, Avatars, Attachments)      │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

---

## 2. Core Separation of Concerns

### Rule 1: Declarative Security Rules & Schema Isolation
- Direct Flutter-to-Firestore operations are guarded by **declarative sub-millisecond security rules** (`firestore.rules`).
- Access rules strictly inspect custom claims (`request.auth.token.role`) and document fields before allowing any read or write.

### Rule 2: Serverless Cloud Functions Authority
- Privileged operations that cannot be entrusted to the client are isolated in **Firebase Cloud Functions**:
  - Sign-up request approval & account provisioning (`approveSignupRequest`).
  - Custom claims injection (`role`, `year`, `semester`).
  - Automated transactional events and FCM push notification dispatches.

### Rule 3: Client Autonomy & Offline-First UX
- The Flutter client manages:
  - Local state, responsive UI rendering, and user interactions.
  - Secure hardware keystores (e.g., Flutter Secure Storage / Keychain) for local device credentials.
  - Built-in Firestore offline disk caching for seamless access without network connectivity.
  - Optimistic UI updates with graceful error fallbacks via typed `Failure` models.

---

## 3. Subsystem Breakdown

- **[Flutter Architecture Blueprint](flutter_architecture.md)** — Presentation, Domain, Data layers, State Management, and Design System integration.
- **[Firebase Architecture Blueprint](firebase_architecture.md)** — Cloud Firestore, Firebase Auth, Cloud Functions, and mobile SDK integration.
- **[Firebase Security & Access Control](firebase_security.md)** — Declarative `firestore.rules`, `storage.rules`, App Check, and custom claims.
- **[Firebase Service Mapping](firebase_service_mapping.md)** — Component-by-component migration mapping from legacy REST/SQL to Firebase.
- **[Firebase Setup Guide](firebase_setup.md)** — Emulator setup, environment configuration, and deployment guidelines.
- **[Legacy Backend Architecture (Archived)](backend_architecture.md)** — *Historical reference for the initial Node/Express/PostgreSQL prototype (now removed).*
