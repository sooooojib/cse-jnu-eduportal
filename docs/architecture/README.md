# System Architecture Overview

## 1. Architectural Philosophy

The **CSE JnU EduPortal** follows a strict, layered Clean Architecture designed for high maintainability, robust testability, security, and responsive mobile performance.

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
                  HTTPS JSON REST API / JWT
                             ▼
┌────────────────────────────────────────────────────────┐
│                   BACKEND APPLICATION                  │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ API Routing & Middleware (Auth, RBAC, Validate)  │  │
│  └─────────────────────────┬────────────────────────┘  │
│                            ▼                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Controllers & Handlers                           │  │
│  └─────────────────────────┬────────────────────────┘  │
│                            ▼                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Services & Business Domain State Machines        │  │
│  └─────────────────────────┬────────────────────────┘  │
│                            ▼                           │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Data Repositories & Database Persistence Layer   │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────┬───────────────────────────┘
                             │
                    Database Driver / Pool
                             ▼
┌────────────────────────────────────────────────────────┐
│                 RELATIONAL DATABASE                    │
└────────────────────────────────────────────────────────┘
```

---

## 2. Core Separation of Concerns

### Rule 1: No Direct Database Access from Mobile
- The Flutter client has **zero direct access** to the database engine.
- All operations must pass through authenticated REST API endpoints over secure transport (HTTPS).

### Rule 2: Backend Authority
- The backend is the single source of truth for:
  - User authentication and authorization (RBAC)
  - Semester state transitions
  - Attendance session lifecycle and verification
  - Counseling slot locking and mutual-exclusion transactions
  - Identity stripping for anonymous reviews

### Rule 3: Client Autonomy & Responsive UX
- The Flutter client manages:
  - Local state, responsive UI rendering, and user interactions
  - Secure token storage in native hardware keystores (e.g., Flutter Secure Storage / Keychain)
  - Seamless caching for offline browsing (e.g., class timetable and routine caching)
  - Optimistic UI updates with graceful error fallbacks

---

## 3. Subsystem Breakdown

- **[Flutter Architecture Blueprint](flutter_architecture.md)** — Presentation, Domain, Data layers, State Management, and Design System integration.
- **[Backend Architecture Blueprint](backend_architecture.md)** — Routing, Controllers, Services, Security Guards, and Database Abstraction.
