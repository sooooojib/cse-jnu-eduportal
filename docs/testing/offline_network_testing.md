# STAGE 31 — Offline & Network Resilience Verification

## 1. Overview & Architecture

The **CSE JnU EduPortal** platform implements an enterprise-grade offline and network-resilience architecture. It couples Google Cloud Firestore's native client-side SQLite/IndexedDB caching with an **Authoritative Server Guard** and **Safe Exponential Backoff Retry Policy** to deliver zero-lag local read performance without compromising security or data integrity.

```
                      ┌──────────────────────────────────────┐
                      │          Flutter UI Layer            │
                      │  (Offline Banner, CachedDataBadge)   │
                      └──────────────────┬───────────────────┘
                                         │
                      ┌──────────────────▼───────────────────┐
                      │         NetworkInfo Service          │
                      │ (Status: Online, Offline, Slow, ...) │
                      └───────┬──────────────────────┬───────┘
                              │                      │
            ┌─────────────────▼────────┐   ┌─────────▼──────────────────┐
            │   AuthoritativeGuard     │   │     SafeRetryPolicy        │
            │ (Blocks offline writes   │   │ (Exponential backoff &     │
            │  on sensitive actions)   │   │  idempotency deduplication)│
            └─────────────────┬────────┘   └─────────┬──────────────────┘
                              │                      │
                      ┌───────▼──────────────────────▼───────┐
                      │    Repositories & DataSources        │
                      │  - Reads: Server-first with Cache    │
                      │  - Sensitive Writes: Online-only     │
                      └──────────────────┬───────────────────┘
                                         │
                      ┌──────────────────▼───────────────────┐
                      │   Firebase Firestore & Cloud Funcs   │
                      └──────────────────────────────────────┘
```

---

## 2. Feature Connectivity & Offline Capability Matrix

| Feature | Offline Read Capability | Offline Write Capability | Authoritative Server Required | Rationale / Guard Strategy |
| :--- | :---: | :---: | :---: | :--- |
| **Student Dashboard** | ✅ Full Cache | ❌ Disabled | No for read / Yes for actions | Fast-boot from SQLite cache with `CachedDataBadge` indicator. |
| **Teacher Dashboard** | ✅ Full Cache | ❌ Disabled | No for read / Yes for actions | Faculty routine and metrics rendered from cache. |
| **CR Dashboard** | ✅ Full Cache | ❌ Disabled | No for read / Yes for actions | Class schedule & course progress available offline. |
| **Admin Dashboard** | ✅ Full Cache | ❌ Disabled | No for read / Yes for actions | Overview stats & directory loaded from local cache. |
| **Timetable Routine** | ✅ Full Cache | ❌ Disabled | Yes for edits/creations | Class routine read-only offline; modifications require online sync. |
| **Exam Schedule** | ✅ Full Cache | ❌ Disabled | Yes for edits/creations | Midterm/Final schedules viewable offline with cached badge. |
| **Attendance History** | ✅ Full Cache | ❌ Disabled | No for read / Yes for session | Prior attendance summaries and records viewable offline. |
| **Attendance Code Verification** | ❌ Blocked | ❌ Blocked | **YES (Strict)** | `AuthoritativeGuard` prevents offline submission or false success. |
| **Attendance Session Launch** | ❌ Blocked | ❌ Blocked | **YES (Strict)** | Faculty cannot open a terminal session offline. |
| **Attendance Roster Override** | ❌ Blocked | ❌ Blocked | **YES (Strict)** | Manual presence/absence adjustments require server validation. |
| **Counseling Booking Request** | ❌ Blocked | ❌ Blocked | **YES (Strict)** | Prevents phantom requests on already-booked faculty slots. |
| **Counseling Approval** | ❌ Blocked | ❌ Blocked | **YES (Strict)** | Faculty slot locking requires authoritative transaction. |
| **Signup Petition Approval** | ❌ Blocked | ❌ Blocked | **YES (Strict)** | Account provisioning requires Cloud Function execution. |
| **Semester Upgrade Approval** | ❌ Blocked | ❌ Blocked | **YES (Strict)** | Academic progression requires database-level validation. |
| **User Role / Status Management** | ❌ Blocked | ❌ Blocked | **YES (Strict)** | User activation, deactivation, and deletion require live connection. |
| **Broadcast Notice Dispatch** | ❌ Blocked | ❌ Blocked | **YES (Strict)** | Push notifications and inbox distribution require server. |

---

## 3. Resilience Engine Components

### 3.1 NetworkInfo (`core/network/network_info.dart`)
- Actively checks actual DNS / host reachability (`google.com`, `firestore.googleapis.com`) rather than relying solely on network adapter state.
- Emits real-time reactive states via `Stream<NetworkStatus>` and `ValueNotifier<NetworkStatus>`:
  - `NetworkStatus.online`
  - `NetworkStatus.offline`
  - `NetworkStatus.slow` (latency > 2500ms)
  - `NetworkStatus.reconnecting`
  - `NetworkStatus.reconnected` (settles to online after 3 seconds)

### 3.2 AuthoritativeGuard (`core/network/authoritative_guard.dart`)
- Guards all 9 security-sensitive operations.
- Intercepts offline executions before network calls or local cache commits take place.
- Throws typed `NetworkFailure` with context-specific messages (e.g. `"Attendance verification requires an active internet connection for authoritative verification."`).
- Guarantees **zero false success** in offline environments.

### 3.3 SafeRetryPolicy (`core/network/safe_retry_policy.dart`)
- **Exponential Backoff**: Initial delay 500ms $\rightarrow$ 1000ms $\rightarrow$ 2000ms with jitter to prevent server thundering herds.
- **Selective Retry**: Retries only transient infrastructure failures (`SocketException`, `TimeoutException`, Firestore `unavailable`, `deadline-exceeded`).
- **Never Retries Non-Idempotent / Business Errors**: Rejections, `ValidationException`, `AuthException`, `ForbiddenException`, and `DUPLICATE_ATTENDANCE` halt immediately.
- **In-Flight Idempotency Guard**: Tracks active submission keys (e.g. `verify_code_${uid}_$code`), blocking accidental double-taps and concurrent duplicate submissions.

---

## 4. UI Indicators & User Feedback

1. **Global Offline / Reconnection Banner (`OfflineConnectivityBanner`)**:
   - Integrated into `AuthenticatedAppShell` across all roles (Student, Teacher, CR, Admin) and in `LoginScreen`.
   - **Offline State**: Amber background, `Icons.wifi_off_rounded`, `"Offline Mode — Showing cached data. Server actions disabled."` with an instant `"Retry"` button.
   - **Reconnecting State**: Blue background, `Icons.sync_rounded`, `"Connecting to JnU EduPortal server..."`.
   - **Reconnected State**: Emerald background, `Icons.check_circle_rounded`, `"Back online · Reconnected to server."` (auto-dismisses after 3s).
   - **Slow Network State**: Amber-orange warning, `Icons.speed_rounded`, `"Slow or unstable network connection detected."`.

2. **Cached & Stale Data Badging (`CachedDataBadge`)**:
   - Distinctive badge rendered on cached lists (Dashboards, Routine, Attendance standing).
   - Shows `[Icons.offline_pin_outlined] Showing cached data (Offline)` with tap-to-refresh icon.

3. **Intelligent Error View (`AppErrorStateView`)**:
   - Automatically detects network errors from error messages or exception types.
   - Dynamically swaps default error icon to `Icons.wifi_off_rounded` with `"Connection Error"` title and primary `"Try Again"` action button.

---

## 5. Verification Protocols & Test Suite

The test suite in `mobile/test/core/network/network_resilience_test.dart` verifies all offline resilience invariants:

1. **Application Startup Without Internet**:
   - `NetworkInfo` successfully initialises in offline mode without crashing or hanging.
2. **Accessing Cached Screens Offline**:
   - Verifies that cached records populate UI with `CachedDataBadge` indicators.
3. **Restoring Connection**:
   - Transition sequence `offline` $\rightarrow$ `reconnected` $\rightarrow$ `online` verified.
4. **Transient Network Timeout & Safe Retry**:
   - `SafeRetryPolicy` retries transient timeout errors up to 3 times with exponential backoff and succeeds on connection recovery.
5. **Non-Retryable Logic Protection**:
   - Client validation, authentication, and conflict errors do not trigger redundant retries.
6. **Concurrent Duplicate Submission Prevention**:
   - Identical idempotency keys prevent duplicate records from being submitted simultaneously.
7. **Security-Sensitive Operations Rejection**:
   - Attendance verification offline throws `NetworkFailure`.
   - Attendance session creation offline throws `NetworkFailure`.
   - Attendance roster updates offline throw `NetworkFailure`.
   - Admin user deletion offline throws `NetworkFailure`.
   - Admin signup approval offline throws `NetworkFailure`.
   - Faculty counseling approval offline throws `NetworkFailure`.
8. **UI Presentation Widgets**:
   - `OfflineConnectivityBanner` renders amber offline bar with Retry button when disconnected.
   - `OfflineConnectivityBanner` hides when online.
   - `CachedDataBadge` renders subtle notification when data is from cache and stays hidden when fresh.
   - `AppErrorStateView` auto-detects network failure and presents `wifi_off` icon.

---

## 6. Execution Status
- **Mobile Test Suite**: All 351 unit, widget, and integration tests passing (`+351: All tests passed!`).
- **Flutter Build**: Clean compilation without errors or warnings.
