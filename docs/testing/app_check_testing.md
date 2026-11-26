# Firebase App Check Verification & Testing Protocol
## CSE JnU EduPortal — Stage 32

---

## 1. Test Overview & Objectives

This protocol verifies that Firebase App Check functions correctly across all deployment environments (development, staging, local emulators, and physical production Android/iOS devices) without locking out legitimate users or bypassing server authorization.

---

## 2. Test Execution Matrix

| Test ID | Test Category | Target Component | Success Criteria | Automated Test File |
|:---|:---|:---|:---|:---|
| **AC-TEST-01** | Development Attestation | `AppCheckService` (Flutter) | Configures `AndroidProvider.debug` & `AppleProvider.debug` in debug mode | `mobile/test/core/config/app_check_service_test.dart` (Test 2) |
| **AC-TEST-02** | Production Attestation | `AppCheckService` (Flutter) | Configures `AndroidProvider.playIntegrity` & App Attest in release mode | `mobile/test/core/config/app_check_service_test.dart` (Test 3) |
| **AC-TEST-03** | Resilience & Fault Tolerance | `AppCheckService` (Flutter) | Gracefully handles activation failure without crashing app | `mobile/test/core/config/app_check_service_test.dart` (Test 4) |
| **AC-TEST-04** | Token Retrieval & Refresh | `AppCheckService` (Flutter) | Fetches token, handles errors, and propagates rotation stream | `mobile/test/core/config/app_check_service_test.dart` (Tests 5–10) |
| **AC-TEST-05** | Backend Valid Attestation | `verifyAppCheck` (Cloud Functions) | Validates authentic `request.app.appId` and returns verified status | `functions/src/appcheck.test.ts` (Test 1 & 4) |
| **AC-TEST-06** | Backend Monitor/Audit Mode | `verifyAppCheck` (Cloud Functions) | Unverified request in audit mode logs warning but allows execution | `functions/src/appcheck.test.ts` (Test 2) |
| **AC-TEST-07** | Backend Strict Enforcement | `verifyAppCheck` (Cloud Functions) | Unverified request under `ENFORCE_APP_CHECK=true` throws `unauthenticated` | `functions/src/appcheck.test.ts` (Test 3) |
| **AC-TEST-08** | Replay Protection | `verifyAppCheck` (Cloud Functions) | Consumed token with replay protection throws `permission-denied` | `functions/src/appcheck.test.ts` (Test 5) |
| **AC-TEST-09** | Emulator Bypass | `verifyAppCheck` (Cloud Functions) | `FUNCTIONS_EMULATOR=true` permits requests during local development | `functions/src/appcheck.test.ts` (Test 6) |

---

## 3. Manual Device Verification Steps

### 3.1 Android Debug Device Registration (vivo V2430)
1. Connect device via USB / wireless debugging:
   ```bash
   adb devices
   # Output: 10EF7402L40011J device
   ```
2. Launch Flutter app in debug mode:
   ```bash
   cd mobile && flutter run -d 10EF7402L40011J
   ```
3. Inspect `adb logcat` for the App Check debug secret token:
   ```bash
   adb logcat | grep -i "FirebaseAppCheck"
   ```
4. Copy the UUID printed (e.g. `12345678-ABCD-EF01-2345-6789ABCDEF01`).
5. Open [Firebase Console](https://console.firebase.google.com/) > **App Check** > **Apps** > **Android** > **Manage debug tokens**.
6. Register the token with label `vivo V2430 Debug Device`.
7. Verify that subsequent Firestore reads and Cloud Function calls succeed with `[AppCheck:VERIFIED]` entries in cloud logs.

### 3.2 Production Attestation Verification (Play Integrity)
1. Build signed release APK/AAB:
   ```bash
   cd mobile && flutter build appbundle --release
   ```
2. Verify that `kDebugMode` is `false` and `AndroidProvider.playIntegrity` is activated.
3. Install release build on an enrolled device:
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```
4. Open the app, navigate through Student/Teacher dashboards, and trigger an authoritative action (e.g., fetch schedule, load attendance roster).
5. Verify in Firebase Console > **App Check** that **Play Integrity** requests count increases under **Verified requests**.

### 3.3 Invalid Attestation Simulation (Attacker Emulation)
To simulate an attacker attempting to bypass the app using raw HTTP or un-attested scripts:
1. Trigger a Cloud Function call without passing `X-Firebase-AppCheck` header:
   ```bash
   curl -X POST https://us-central1-cse-jnu-eduportal.cloudfunctions.net/startAttendanceSession \
     -H "Content-Type: application/json" \
     -d '{"data": {"courseId": "CSE-3101"}}'
   ```
2. **Audit Mode Result**: Returns `401 Unauthorized` for missing user JWT, and logs:
   `[AppCheck:AUDIT] startAttendanceSession accepted unverified request (no App Check token).`
3. **Enforced Mode Result**: Cloud Function rejects immediately:
   `{"error": {"status": "UNAUTHENTICATED", "message": "Firebase App Check verification failed."}}`

---

## 4. Unsupported Device & Resilience Testing

### 4.1 Missing Google Play Services
- On devices without Google Play Services (e.g. custom AOSP ROMs or certain virtual test devices), `FirebaseAppCheck.instance.activate` may throw an exception.
- **Resilience Verification**: `AppCheckServiceImpl` intercepts platform exceptions, logs a structured warning (`Firebase App Check activation failed gracefully`), and allows the Flutter application to continue running without crashing.

### 4.2 Network Offline During App Launch
- If the device boots without internet connectivity, the App Check SDK caches the last acquired valid token.
- If no token has ever been acquired, local Firestore operations continue using offline disk cache. Authoritative online operations (guarded by `AuthoritativeGuard`) properly prompt the user to restore network connectivity.

---

## 5. Automated Test Execution Commands

To execute all App Check automated tests:

### 1. Flutter Unit Tests:
```bash
cd mobile
flutter test test/core/config/app_check_service_test.dart
```
**Result**: 10 tests passing.

### 2. Full Mobile Test Suite:
```bash
cd mobile
flutter test
```
**Result**: 361 tests passing.

### 3. Cloud Functions App Check Tests:
```bash
cd functions
npm run build && node --test lib/appcheck.test.js
```
**Result**: 6 tests passing.

### 4. Full Backend Functions Test Suite:
```bash
cd functions
npm test
```
**Result**: 130 tests passing.
