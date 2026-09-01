# Quality Assurance & Testing Strategy

## 1. Testing Pyramid & Philosophy

The **CSE JnU EduPortal** follows a strict, multi-tiered testing discipline to ensure high reliability, zero regression, and seamless mobile performance across diverse network conditions.

```
                  ┌──────────────────────┐
                  │   E2E Flow Tests     │  (Critical user journeys)
                  ├──────────────────────┤
                  │ Widget / API Tests   │  (Components & Endpoints)
                  ├──────────────────────┤
                  │   Unit Domain Tests  │  (Use cases, state machines)
                  └──────────────────────┘
```

---

## 2. Flutter Mobile Testing Protocol

### 2.1 Domain & State Management Unit Tests
- **Use Cases**: Test each domain use case in isolation by mocking data repositories (e.g. `VerifyAttendanceUseCase`, `SubmitCounselingRequestUseCase`).
- **State Notifiers / Blocs**: Verify state transitions:
  - `InitialState` ➔ `LoadingState` ➔ `SuccessState<T>`
  - `InitialState` ➔ `LoadingState` ➔ `ErrorState(Failure)`
- **Data Mappers**: Verify DTO-to-Entity conversions and null-safety edge cases.

### 2.2 Reusable Widget Tests
- **Verification Code Input Widget**: Test 6-box focus traversal, backspace handling, paste operations, and auto-submit callback.
- **Obsidian Terminal View**: Verify 6-digit code display, monospace font application, and action button callbacks.
- **Role Badge Component**: Verify correct color token and icon rendering for all 4 roles (`STUDENT`, `CR`, `TEACHER`, `ADMIN`).
- **Semester Selector Banner**: Test tri-state rendering (`NONE`, `PENDING`, `REJECTED`).

### 2.3 Integration Flow Tests
- **Authentication Flow**: Login ➔ Secure token storage ➔ Route redirection to role dashboard.
- **Attendance Verification Flow**: Student selects course ➔ enters 6-character code ➔ verifies optimistic UI update and attendance count refresh.
- **Counseling Booking Flow**: Student browses slots ➔ submits category and note ➔ validates pending status.

---

## 3. Backend Testing Protocol

### 3.1 Domain & Business Logic Unit Tests
- **BR-AUTH**: Password hashing, secure random credential generation, email dispatch payload format.
- **BR-SEM**: State machine transitions (`NONE` ➔ `PENDING` ➔ `APPROVED` / `REJECTED`).
- **BR-SCHED**: CR tomorrow-only date validation and cleanup of past slots.
- **BR-ATT**: 6-character code generation excluding ambiguous characters (`0, O, 1, I`), uniqueness constraint on `(sessionId, studentId)`.
- **BR-COUN**: Mutual-exclusion transaction: verify that approving 1 request atomically marks slot `BOOKED` and rejects all competing requests.
- **BR-FEED**: Anonymity detachment: verify student identity is stripped when `isAnonymous == true` for teacher queries, but preserved in admin audits.

### 3.2 API Integration & RBAC Guard Tests
- **Auth Guard Validation**: Verify that unauthenticated requests to protected endpoints return `401 Unauthorized`.
- **RBAC Matrix Verification**:
  - `STUDENT` attempting `POST /attendance/session/start` ➔ `403 Forbidden`.
  - `CR` attempting `POST /schedule/slot` for next week ➔ `400 Bad Request`.
  - `TEACHER` managing counseling requests ➔ `200 OK`.
  - `ADMIN` accessing user directory ➔ `200 OK`.

---

## 4. Test Automation & CI Validation Checklist

| Phase | Target | Execution Command (Conceptual) |
| :--- | :--- | :--- |
| **Mobile Lints** | Flutter codebase | `flutter analyze` |
| **Mobile Tests** | Flutter unit & widget tests | `flutter test --coverage` |
| **Backend Lints**| Backend codebase | `npm run lint` / `cargo check` / `go vet` |
| **Backend Tests**| Unit & integration tests | `npm test` / `cargo test` / `go test ./...` |
| **Contract Test**| API schema compatibility | Schema & endpoint contract validation |
