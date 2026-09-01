# CSE JnU EduPortal — Master Documentation Index

Welcome to the central engineering and architecture documentation for **CSE JnU EduPortal**, the next-generation role-based academic mobile ecosystem for the Department of Computer Science & Engineering, Jagannath University (JnU).

---

## 🏛️ Project Vision & System Scope

**EduPortal** is engineered to eliminate paper ledgers, fragmented social media communication groups, and disjointed departmental workflows. It provides a real-time, unified mobile platform serving four primary stakeholders:

1. **Students** — Access personal attendance metrics, course timetables, exam alerts, direct faculty counseling bookings, and anonymous departmental feedback.
2. **Class Representatives (CRs)** — Manage and publish daily class schedules, broadcast automated WhatsApp routine alerts, view class rosters, and export departmental attendance summaries.
3. **Professors / Faculty** — Host dynamic live 6-digit attendance code terminals, toggle manual student rosters, manage academic counseling office hours, review anonymous feedback, and view assigned course routines.
4. **Department Administrators** — Moderate new student and faculty account requests, review semester promotion petitions, assign courses to professors, and oversee departmental user directories.

---

## 📐 High-Level Technology Blueprint

The new CSE JnU EduPortal is designed **100% from ground zero** under a strict mobile-first Clean Architecture paradigm:

```
+-------------------------------------------------------------+
|                     Flutter Mobile App                      |
| (Presentation Layer • Domain Use Cases • Data Repositories) |
+-------------------------------------------------------------+
                              │
                    HTTPS / REST API (JSON)
                      JWT Bearer Tokens
                              ▼
+-------------------------------------------------------------+
|                    Dedicated Backend API                    |
| (Controllers • Service Business Logic • Auth & RBAC Guards) |
+-------------------------------------------------------------+
                              │
                    Database Driver / ORM
                              ▼
+-------------------------------------------------------------+
|                     Relational Database                     |
|  (Clean ground-zero schema, strict foreign keys & indexes)  |
+-------------------------------------------------------------+
```

### Architectural Principles:
- **Clean Architecture & Separation of Concerns**: Strict boundary between presentation, domain logic, data sources, and network layers.
- **Backend as Single Source of Truth**: Flutter *never* communicates directly with the database. The backend enforces authentication, authorization, validation, state machines, and relational integrity.
- **Predictable State Management**: Immutable states, reactive streams, and structured dependency injection.
- **Emerald Scholar Design System**: Premium academic styling, light/dark themes, custom tokens, and obsidian dynamic terminals.

---

## 📚 Documentation Structure

Navigate through the architectural and implementation guides below:

| Directory | Topic | Description |
| :--- | :--- | :--- |
| [`docs/requirements/`](requirements/README.md) | **Requirements & Business Rules** | Core functional scope, role constraints, and domain state machines. |
| [`docs/architecture/`](architecture/README.md) | **System Architecture** | Flutter mobile architecture, backend layers, security, and communication. |
| [`docs/database/`](database/README.md) | **Database Design** | Ground-zero entity models, relational mappings, and indexing strategies. |
| [`docs/api/`](api/README.md) | **API Specifications** | RESTful endpoint catalog, payload structures, auth headers, and status codes. |
| [`docs/features/`](features/README.md) | **Feature Matrix** | Detailed feature specifications and role-based permissions matrix. |
| [`docs/ui/`](ui/README.md) | **UI/UX & Design System** | Emerald Scholar design system, tokens, typography, and screen catalog. |
| [`docs/testing/`](testing/README.md) | **Testing & QA Strategy** | Testing protocols for mobile frontend, backend logic, and API endpoints. |

---

## 🛡️ Development & Governance Rules

1. **Ground-Zero Implementation**: Never port or reuse old web code, legacy schemas, or obsolete dependencies.
2. **Phase-Gated Development**: Understand requirements ➔ Design ➔ Architectural validation ➔ Implementation ➔ Verification.
3. **No Unstated Inventions**: Every feature and field maps directly to verified academic requirements and business rules.
