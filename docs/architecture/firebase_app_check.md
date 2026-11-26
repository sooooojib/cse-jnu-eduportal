# Firebase App Check Architecture & Enforcement Specification
## CSE JnU EduPortal — Stage 32

---

## 1. Executive Summary & Security Model

Firebase App Check provides device and application attestation for **CSE JnU EduPortal**. It validates that incoming requests originate exclusively from authentic, untampered builds of the EduPortal application on genuine hardware, effectively neutralizing:
- Automated API scraping and bots
- Unauthorized SDK clients accessing Firestore or Cloud Storage directly
- Direct replay or script-based abuse of Cloud Functions
- Credential stuffing and distributed brute-force attacks

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Zero-Trust Defense-in-Depth Layering                 │
├───────────────────┬────────────────────────────────────────────────────┤
│ Layer 1: Attest   │ Firebase App Check (Play Integrity / App Attest)   │
│ Layer 2: Identity │ Firebase Authentication (JWT + Session UID)        │
│ Layer 3: Perimeter│ Cloud Firestore & Cloud Storage Security Rules     │
│ Layer 4: Compute  │ Cloud Functions Authoritative Server-Side Logic    │
│ Layer 5: Data     │ RBAC Custom Claims & Immutable Audit Logs          │
└───────────────────┴────────────────────────────────────────────────────┘
```

> **CRITICAL SECURITY INVARIANT**:
> App Check attests **authenticity of the client binary**, NOT user identity or authorization. App Check **never** replaces Firebase Authentication, Firestore Security Rules, Storage Security Rules, or server-side validation. Even if an attacker passes App Check from a genuine device, they remain strictly constrained by RBAC and Security Rules.

---

## 2. Platform Provider Configuration

The EduPortal client dynamically configures production and development attestation providers through `AppCheckService` (`mobile/lib/core/config/app_check_service.dart`):

| Platform | Production Provider | Development / Testing Provider | Official Provider Enum |
|:---|:---|:---|:---|
| **Android** | **Google Play Integrity API** | Debug Provider (`AndroidProvider.debug`) | `AndroidProvider.playIntegrity` |
| **iOS / iPadOS** | **App Attest with DeviceCheck Fallback** (iOS 14+) | Debug Provider (`AppleProvider.debug`) | `AppleProvider.appAttestWithDeviceCheckFallback` |
| **macOS** | **App Attest** (macOS 14+) | Debug Provider (`AppleProvider.debug`) | `AppleProvider.appAttestWithDeviceCheckFallback` |
| **Web** | **reCAPTCHA Enterprise / v3** | Web Debug Provider | `ReCaptchaEnterpriseProvider` |

### 2.1 Android Play Integrity
- SafetyNet is permanently deprecated and discontinued by Google.
- Google Play Integrity API is configured in Google Cloud Console and linked to Firebase App Check.
- Play Integrity performs:
  1. **App Licensing**: Verifies app was installed via Google Play.
  2. **App Integrity**: Verifies APK/AAB signature matches the Google Play signed key (SHA-256 fingerprint: `FB:7D:6B:42:01:E2:03:E5:A2:18:61:94:42:0F:7B:A8:D5:70:E5:4B:90:54:FB:0B:45:90:48:CE:B0:1A:E7:58`).
  3. **Device Integrity**: Verifies hardware integrity (uncertified/rooted devices fail device integrity).

### 2.2 Apple App Attest & DeviceCheck
- Uses Apple DCAppAttestService on iOS 14.0+ hardware.
- Automatically falls back to DeviceCheck on devices or iOS versions where App Attest is unsupported.
- Team ID and App ID registered in Apple Developer Portal and configured in Firebase Console.

### 2.3 Token Auto-Refresh
App Check tokens expire every **60 minutes**. The mobile client enables automatic token refresh:
```dart
await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
```
Tokens are refreshed silently in the background 5 to 10 minutes prior to expiration, guaranteeing uninterrupted user sessions.

---

## 3. Development, Debug & Emulator Workflow

### 3.1 Strict Separation of Environments
- **Production Builds (`--release`)**:
  - `AndroidProvider.playIntegrity` / `AppleProvider.appAttestWithDeviceCheckFallback`.
  - Debug provider credentials are NEVER compiled or bundled into production binaries.
- **Development & Staging Builds (`--debug`, `--profile`)**:
  - `AndroidProvider.debug` / `AppleProvider.debug`.
  - When the debug provider initializes, it outputs a uniquely generated secret debug token to the console / `adb logcat`:
    ```
    D/FirebaseAppCheck: Enter this debug secret into the allow list in
    the Firebase Console for your project: 12345678-ABCD-EF01-2345-6789ABCDEF01
    ```

### 3.2 Registering Debug Tokens
1. Open [Firebase Console](https://console.firebase.google.com/) > **App Check**.
2. Navigate to **Apps** > select **CSE JnU EduPortal Android** (or iOS).
3. Click the overflow menu (⋮) > **Manage debug tokens**.
4. Click **Add debug token**, assign a developer name (e.g. `Developer Device - vivo V2430` or `CI/CD Emulator`), and save.

### 3.3 Firebase Emulator Suite Integration
- Cloud Functions check `process.env.FUNCTIONS_EMULATOR === "true"`.
- In local emulator test environments, unverified requests are permitted with a development notice, preventing development workflow lockouts.

---

## 4. Production Protection Across Firebase Services

```
                                  ┌───────────────────────────────┐
                                  │      EduPortal Client         │
                                  │ (AppCheckService initialized) │
                                  └──────────────┬────────────────┘
                                                 │
                                                 │ Passes X-Firebase-AppCheck
                         ┌───────────────────────┼────────────────────────┐
                         │                       │                        │
                         ▼                       ▼                        ▼
                ┌─────────────────┐     ┌─────────────────┐      ┌─────────────────┐
                │ Cloud Firestore │     │  Cloud Storage  │      │ Cloud Functions │
                │                 │     │                 │      │                 │
                │ App Check Gate  │     │ App Check Gate  │      │ verifyAppCheck  │
                │ (Enforced in    │     │ (Enforced in    │      │ (enforceAppCheck│
                │  Console)       │     │  Console)       │      │  middleware)    │
                └─────────────────┘     └─────────────────┘      └─────────────────┘
```

### 4.1 Cloud Firestore
- **Enforcement Mechanism**: Cloud Console project-level firewall.
- **Client Behavior**: Firestore Flutter SDK automatically attaches the active App Check token (`X-Firebase-AppCheck`) to all WebSocket, gRPC, and REST channels.
- **Enforcement Status**: Monitoring (Audit) Mode until metrics confirm >99.5% legitimate attestation rate.

### 4.2 Cloud Storage
- **Enforcement Mechanism**: Cloud Console storage bucket rule check.
- **Client Behavior**: Storage Flutter SDK attaches the token to upload and download HTTP operations.
- **Limits Protected**: Prevents direct unauthorized avatar/attachment flooding.

### 4.3 Cloud Functions (2nd Gen `onCall`)
- **Backend Verification Helper**: `functions/src/appcheck.ts` provides `verifyAppCheck(request, functionName)`.
- **Request Metadata**:
  ```typescript
  request.app = {
    appId: string;       // e.g. "1:123456789:android:..."
    token: DecodedAppCheckToken;
    alreadyConsumed?: boolean; // For replay protection
  };
  ```
- **Staged Enforcement**:
  - When `ENFORCE_APP_CHECK !== "true"`: Functions record `[AppCheck:AUDIT]` or `[AppCheck:VERIFIED]` in Google Cloud Logging.
  - When `ENFORCE_APP_CHECK === "true"`: Functions reject unattested requests with `HttpsError("unauthenticated", ...)`.
  - Replay protection: Replayed single-use tokens are rejected with `HttpsError("permission-denied", ...)`.

### 4.4 Firebase Authentication Integration
- App Check for Firebase Authentication primarily protects phone number / SMS verification from bot draining and billing abuse (via Identity Platform).
- In EduPortal, account creation is Admin-gated via Cloud Functions (`approveSignupRequest`). Standard email/password signIn occurs via Firebase Auth SDK. App Check protects the downstream Firestore user profile fetches and role verification.

---

## 5. Staged Enforcement & Rollback / Recovery Procedure

To prevent accidental lockout of legitimate students, teachers, or CRs, enforcement MUST follow this 4-phase rollout plan:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Phase 1: Setup  │ ──► │ Phase 2: Monitor│ ──► │Phase 3: Triage  │ ──► │Phase 4: Enforce │
│ Register Keys & │     │ Collect metrics │     │ Analyze rejected│     │ Activate strict │
│ Deploy Providers│     │ (7-14 Days)     │     │ requests        │     │ enforcement     │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Phase 1: Key Registration & Provider Deployment
1. Register Android SHA-256 fingerprint in Google Play Console and Firebase Console.
2. Link Google Play Integrity API in Firebase App Check dashboard.
3. Deploy Flutter client containing `AppCheckServiceImpl` with `AndroidProvider.playIntegrity`.

### Phase 2: Monitoring & Metrics Audit (7–14 Days)
1. Monitor the **App Check Request Metrics** graph in Firebase Console.
2. Observe the ratio of:
   - **Verified**: Requests with valid Play Integrity / App Attest tokens.
   - **Unverified**: Requests without tokens or with invalid tokens.
   - **Outdated**: Requests from older app versions prior to App Check activation.
3. Target threshold: **Verified requests > 99.5%** before proceeding to Phase 4.

### Phase 3: Investigation of Legitimate Rejections
Common causes of unverified legitimate requests to resolve before enforcement:
- **Pending App Updates**: Users on legacy app builds not yet updated via Play Store.
- **Rooted / Modified Android ROMs**: Devices failing `MEETS_DEVICE_INTEGRITY`.
- **Custom Android Emulators**: Emulators running without Google Play Services.
- **Clock Drift**: Device local clock out of sync by >5 minutes (causes token signature validation failure).

### Phase 4: Strict Production Enforcement
1. In Firebase Console > **App Check**:
   - Cloud Firestore: Click **Enforce** > Confirm.
   - Cloud Storage: Click **Enforce** > Confirm.
2. In Google Cloud Functions environment:
   - Set environment variable `ENFORCE_APP_CHECK=true`.
   - Re-deploy Cloud Functions.

### Emergency Rollback & Recovery Procedure
If legitimate users report `UNAUTHENTICATED` errors or are locked out:
1. **Immediate Cloud Console Rollback (takes effect within 60 seconds)**:
   - Open Firebase Console > **App Check**.
   - Click **Cloud Firestore** > **Unenforce**.
   - Click **Cloud Storage** > **Unenforce**.
2. **Cloud Functions Rollback**:
   - Set `ENFORCE_APP_CHECK=false` in Cloud Functions environment or Google Cloud Secret Manager.
   - Redeploy or restart function instances.
3. **Investigation**:
   - Inspect Google Cloud Logging filtered by `jsonPayload.message =~ "^\\[AppCheck:BLOCKED\\]"`.
   - Identify the user UIDs, device models, and client version strings involved.

---

## 6. Implementation Summary

- **Flutter Client**:
  - `mobile/lib/core/config/app_check_service.dart` (`AppCheckService`, `AppCheckServiceImpl`).
  - Integrated into `mobile/lib/main.dart` and `mobile/lib/core/di/injection_container.dart`.
  - Comprehensive unit test coverage in `mobile/test/core/config/app_check_service_test.dart`.
- **Firebase Functions**:
  - `functions/src/appcheck.ts` (`verifyAppCheck` verification engine with replay protection).
  - Comprehensive test coverage in `functions/src/appcheck.test.ts`.
