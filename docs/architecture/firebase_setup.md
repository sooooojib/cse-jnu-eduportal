# Firebase Project Setup & Platform Integration
## CSE JnU EduPortal — Stage 12 Implementation Guide

---

## 1. Executive Summary

This document specifies the concrete implementation, configuration steps, platform integration, and environment management for the **CSE JnU EduPortal** Firebase-backed architecture.

---

## 2. Configured Firebase Packages

The Flutter application incorporates the full suite of modern FlutterFire plugins (configured in `mobile/pubspec.yaml`):

| Package | Version | Architectural Responsibility |
|:---|:---|:---|
| `firebase_core` | `^3.6.0` | Core SDK initialization and multi-platform options bootstrapping. |
| `firebase_auth` | `^5.3.1` | User authentication, session persistence, and ID token rotation. |
| `cloud_firestore` | `^5.4.3` | Real-time NoSQL database with global offline cache persistence. |
| `firebase_storage` | `^12.3.2` | Object storage for profile avatars and feedback attachments. |
| `cloud_functions` | `^5.1.4` | Client bridge to invoke trusted serverless Gen 2 backend functions. |
| `firebase_messaging` | `^15.1.3` | APNs and FCM mobile push notification token registration. |
| `firebase_app_check` | `^0.3.1+4` | Device attestation (Play Integrity / DeviceCheck / App Attest). |
| `firebase_crashlytics` | `^4.1.4` | Native and Dart exception crash diagnostics and breadcrumb logging. |

---

## 3. Multi-Platform Setup

### 3.1 Android Configuration
1. **Top-Level Build Script** (`mobile/android/build.gradle.kts`):
   ```kotlin
   buildscript {
       repositories {
           google()
           mavenCentral()
       }
       dependencies {
           classpath("com.google.gms:google-services:4.4.2")
       }
   }
   ```
2. **App-Level Module Script** (`mobile/android/app/build.gradle.kts`):
   ```kotlin
   plugins {
       id("com.android.application")
       id("com.google.gms.google-services")
       id("dev.flutter.flutter-gradle-plugin")
   }

   android {
       namespace = "bd.ac.jnu.cse.cse_jnu_eduportal"
       defaultConfig {
           applicationId = "bd.ac.jnu.cse.cse_jnu_eduportal"
           minSdk = 23 // Required for modern Firebase Auth & Storage
           targetSdk = flutter.targetSdkVersion
           versionCode = flutter.versionCode
           versionName = flutter.versionName
       }
   }
   ```
3. **Google Services Descriptor**: Downloaded from the Firebase Console and placed at `mobile/android/app/google-services.json`.

### 3.2 iOS & macOS Configuration
- **Bundle Identifier**: `bd.ac.jnu.cse.cseJnuEduportal`
- **Configuration File**: `mobile/ios/Runner/GoogleService-Info.plist` (iOS) and `mobile/macos/Runner/GoogleService-Info.plist` (macOS).

---

## 4. FlutterFire CLI Workflow

To link a new developer workstation or production deployment directly to the cloud project:

```bash
# 1. Install / Update FlutterFire CLI
dart pub global activate flutterfire_cli

# 2. Run interactive or automated configuration
cd mobile
flutterfire configure \
  --project=cse-jnu-eduportal \
  --out=lib/core/config/firebase_options.dart \
  --platforms=android,ios,macos,web \
  --android-package-name=bd.ac.jnu.cse.cse_jnu_eduportal \
  --ios-bundle-id=bd.ac.jnu.cse.cseJnuEduportal
```

---

## 5. Environment & Secret Management

### 5.1 Environment Separation
- **Development Environment (`development`)**: Connected to `cse-jnu-eduportal-dev` or the local Firebase Emulator Suite.
- **Production Environment (`production`)**: Connected to `cse-jnu-eduportal` with strict security rules, App Check enforcement, and Crashlytics reporting.

### 5.2 Build-Time Parameter Injection
Secrets and project credentials are parameterized via `--dart-define`:

```bash
# Running in Development (Default)
flutter run -d 10EF7402L40011J

# Running in Production
flutter run --profile -d 10EF7402L40011J \
  --dart-define=ENV=production \
  --dart-define=FIREBASE_PROJECT_ID=cse-jnu-eduportal \
  --dart-define=FIREBASE_ANDROID_API_KEY=AIzaSy... \
  --dart-define=FIREBASE_ANDROID_APP_ID=1:123456789:android:abcdef
```

### 5.3 Zero Hardcoded Secrets Policy
- Private service account keys (`service-account.json`) are **never committed to source control** (enforced in `.gitignore`).
- Client API keys in Firebase are identifiers, not secrets; real data access is strictly governed by `firestore.rules` and `storage.rules`.

---

## 6. Root Firebase Infrastructure Artifacts

The project repository includes the complete serverless backend configuration:

| File | Purpose |
|:---|:---|
| [`firebase.json`](file:///Users/sajib/Desktop/CSE_DEPT/firebase.json) | Root Firebase CLI project descriptor declaring rules paths and local emulator ports. |
| [`firestore.rules`](file:///Users/sajib/Desktop/CSE_DEPT/firestore.rules) | Production declarative security rules covering all 12 collections with Custom Claims RBAC. |
| [`firestore.indexes.json`](file:///Users/sajib/Desktop/CSE_DEPT/firestore.indexes.json) | Production composite index definitions for sorted and multi-field queries. |
| [`storage.rules`](file:///Users/sajib/Desktop/CSE_DEPT/storage.rules) | Object storage access rules with MIME type and file size validations. |
| [`functions/src/index.ts`](file:///Users/sajib/Desktop/CSE_DEPT/functions/src/index.ts) | Gen 2 TypeScript Cloud Functions (`approveSignupRequest`, `approveSemesterUpgrade`, `approveCounselingBooking`, `onNotificationCreated`). |

---

## 7. Local Emulator Suite Setup

For fully isolated, zero-cost offline development and automated CI testing:

```bash
# Start all local Firebase emulators (Auth, Firestore, Storage, Functions, UI)
firebase emulators:start
```

- **Auth Emulator**: `http://localhost:9099`
- **Firestore Emulator**: `http://localhost:8080`
- **Storage Emulator**: `http://localhost:9199`
- **Functions Emulator**: `http://localhost:5001`
- **Emulator UI Hub**: `http://localhost:4000`

---

## 8. Verification & Validation Checklist

| Verification Check | Target Status | Verification Result |
|:---|:---:|:---|
| **Flutter Application Boots** | ✅ Pass | `main.dart` bootstraps `WidgetsFlutterBinding` and renders `CSEEduPortalApp`. |
| **Firebase Core Initialization** | ✅ Pass | `Firebase.initializeApp()` successfully links with platform options. |
| **Firestore Initialization** | ✅ Pass | Offline persistence enabled with `Settings(persistenceEnabled: true)`. |
| **Auth Service Initialization** | ✅ Pass | `FirebaseAuth.instance` registered in GetIt container and wired to `AuthRemoteDataSource`. |
| **Cloud Storage Initialization** | ✅ Pass | `FirebaseStorage.instance` registered in GetIt container. |
| **Cloud Functions Initialization** | ✅ Pass | `FirebaseFunctions.instance` registered in GetIt container. |
| **Cloud Messaging Initialization** | ✅ Pass | `FirebaseMessaging.instance` registered in GetIt container. |
| **Dart Static Analysis** | ✅ Pass | **0 errors**, **0 warnings** across entire `mobile/lib` and `mobile/test`. |
| **Automated Test Suite** | ✅ Pass | **53/53 tests passing** (`flutter test`). |
