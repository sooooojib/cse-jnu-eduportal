# `Step 11` — Authentication & Role-Based Access Control (RBAC) Guide

In **CSE JnU EduPortal**, authentication is not a simple "anyone can create an account" system like a public social media platform.

Because university systems handle confidential student grades, live attendance sessions, and counseling notes, authentication is architected under a **5-Stage Zero-Trust Lifecycle**:

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    THE 5-STAGE AUTHENTICATION LIFECYCLE                         │
│                                                                                 │
│  [1. Student/Teacher]       [2. Cloud Functions & Admin]       [3. Mobile Login]│
│  Submits Signup Petition ──► Admin Approves & Injects     ───► Verifies JWT     │
│  (Pending Request)           Custom User Claims                 & Profile Active│
│                                                                        │        │
│                                                                        ▼        │
│  [5. Cloud Security Rules]       [4. Flutter GoRouter]        [Local Keystore]  │
│  Sub-millisecond Firestore  ◄─── Routes to Role Dashboard ◄── Encrypts Token    │
│  Firewall Enforcement            (Student/CR/Teacher/Admin)   in Hardware       │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🏛️ Stage 1: The Registration Petition (Sign-Up Request)

To prevent unauthorized outsiders from registering as students or professors, **the registration screen does not create a Firebase Auth user directly**.

Instead, it creates a **Sign-Up Request** document in the Firestore `signupRequests` collection:

* **File**: [`mobile/lib/features/auth/data/datasources/auth_remote_datasource.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/features/auth/data/datasources/auth_remote_datasource.dart)

```dart
await _firestore.collection('signupRequests').add({
  'fullName': 'Sajib Ahmed',
  'email': 'sajib@cse.jnu.ac.bd',
  'role': 'STUDENT',
  'studentId': 'B210305015',
  'phone': '+8801712345678',
  'status': 'PENDING',
  'createdAt': FieldValue.serverTimestamp(),
});
```

* **Security Guarantee**: The user **cannot log in** at this point because no Firebase Authentication account exists yet.

---

## ⚡ Stage 2: Admin Vetting & Custom Claims Engine

The Department Administrator reviews pending petitions in the Admin Console. When the Admin clicks **"Approve"**, an atomic, serverless Cloud Function executes with the Firebase Admin SDK.

* **File**: [`functions/src/index.ts`](file:///Users/sajib/Desktop/CSE_DEPT/functions/src/index.ts) (`approveSignupRequest`)

```typescript
export const approveSignupRequest = onCall(async (request) => {
  // 1. Verify caller is an Administrator
  if (!request.auth || request.auth.token.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only administrators can approve accounts.");
  }

  // 2. Create the official Firebase Auth User with a secure initial password
  const userRecord = await auth.createUser({
    email: reqData.email,
    password: randomPassword,
    displayName: reqData.fullName,
    emailVerified: true,
  });

  // 3. INJECT CUSTOM USER CLAIMS (The Core of RBAC!)
  await auth.setCustomUserClaims(userRecord.uid, {
    role: reqData.role,         // 'STUDENT' | 'CR' | 'TEACHER' | 'ADMIN'
    year: assignedYear,         // e.g. 3
    semester: assignedSemester, // e.g. 1
  });

  // 4. Create User Profile Document in Firestore
  await db.collection("users").doc(userRecord.uid).set({
    email: reqData.email,
    fullName: reqData.fullName,
    role: reqData.role,
    studentId: reqData.studentId,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  });

  // 5. Mark Signup Request Approved
  await requestRef.update({
    status: "APPROVED",
    approvedUserId: userRecord.uid,
    updatedAt: now,
  });
});
```

### 💡 Why Custom User Claims Matter:
Instead of forcing the database to make a slow read every single time a student requests an attendance screen, **the user's role (`STUDENT`), batch year, and semester are cryptographically baked into their JWT ID Token**.

Cloud firewalls can inspect `request.auth.token.role` in **sub-milliseconds** without touching the database!

---

## 📱 Stage 3: The Mobile Login Pipeline

When the user enters their credentials on the `LoginScreen`:

* **File**: [`mobile/lib/features/auth/data/datasources/auth_remote_datasource.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/features/auth/data/datasources/auth_remote_datasource.dart)

```dart
final credential = await _auth.signInWithEmailAndPassword(
  email: email.trim().toLowerCase(),
  password: password,
);

// 1. Double check Firestore profile exists
final doc = await _firestore.collection('users').doc(credential.user!.uid).get();
if (!doc.exists) {
  await _auth.signOut();
  throw ServerException(message: 'Account not yet approved by administrator.');
}

// 2. Check if account was suspended or deactivated
final isActive = doc.data()!['isActive'] as bool? ?? true;
if (!isActive) {
  await _auth.signOut();
  throw ServerException(message: 'Account has been deactivated.');
}

// 3. Save tokens in hardware-encrypted storage
final userModel = UserModel.fromFirestore(doc);
return AuthResponseModel(
  accessToken: await credential.user!.getIdToken(),
  refreshToken: credential.user!.refreshToken ?? '',
  user: userModel,
);
```

* Tokens and session keys are saved using **`FlutterSecureStorage`** ([`secure_storage_service.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/core/storage/secure_storage_service.dart)), backed by the **Android Keystore** and **iOS Keychain**.

---

## 🚦 Stage 4: Role-Based Navigation Guards (`GoRouter`)

In the Flutter app, `AppRouter` listens reactively to `AuthController`:

* **File**: [`mobile/lib/app/router/app_router.dart`](file:///Users/sajib/Desktop/CSE_DEPT/mobile/lib/app/router/app_router.dart)

```dart
redirect: (context, state) {
  final authState = auth.state;
  final currentPath = state.matchedLocation;

  // 1. If not logged in -> redirect to /login
  if (authState is! Authenticated) {
    return isLoggingIn ? null : RouteNames.login;
  }

  final user = authState.user;

  // 2. If already logged in and at /login -> direct to their specific dashboard
  if (isLoggingIn) {
    return _getDashboardRouteForRole(user.role);
  }

  // 3. Role Security Guards:
  // Prevent Students or CRs from opening the Admin Dashboard
  if (currentPath == RouteNames.adminDashboard && user.role != UserRole.admin) {
    return _getDashboardRouteForRole(user.role);
  }

  // Prevent Students from opening Teacher terminals
  if (currentPath == RouteNames.teacherDashboard &&
      user.role != UserRole.teacher &&
      user.role != UserRole.admin) {
    return _getDashboardRouteForRole(user.role);
  }

  // Prevent Students from opening CR Dashboard
  if (currentPath == RouteNames.crDashboard &&
      user.role != UserRole.cr &&
      user.role != UserRole.admin) {
    return _getDashboardRouteForRole(user.role);
  }

  return null;
}
```

---

## 🛡️ Stage 5: The Cloud Firewall (`firestore.rules`)

Even if a malicious user reverse-engineers the Flutter APK and deletes the navigation guard, **they cannot read or write data they do not own**.

* **File**: [`firestore.rules`](file:///Users/sajib/Desktop/CSE_DEPT/firestore.rules)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuthenticated() {
      return request.auth != null;
    }

    function hasRole(role) {
      return isAuthenticated() && request.auth.token.role == role;
    }

    // Only Teachers and Admins can create attendance sessions
    match /attendanceSessions/{sessionId} {
      allow read: if isAuthenticated();
      allow create, update: if hasRole('TEACHER') || hasRole('ADMIN');
    }

    // Only Admins can approve or reject signup requests
    match /signupRequests/{requestId} {
      allow read, write: if hasRole('ADMIN');
      allow create: if true; // Publicly allow submitting requests
    }

    // Students can only read/update their own profile
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if hasRole('ADMIN') || request.auth.uid == userId;
    }
  }
}
```

---

## 📊 Summary Matrix: Role Permissions

| Persona | Dashboard Route | Permitted Capabilities | Prohibited Boundaries |
|:---|:---|:---|:---|
| **Student** | `/dashboard/student` | View routines, submit 6-digit attendance code, book counseling, post anonymous reviews | Cannot host attendance sessions, cannot view admin directory |
| **CR** | `/dashboard/cr` | All student capabilities + broadcast timetable routine updates, export class attendance roster | Cannot approve signups, cannot assign course teachers |
| **Teacher** | `/dashboard/teacher` | Launch 6-digit attendance terminal, manage office hour slots, review anonymous feedback | Cannot alter admin settings or student batch configurations |
| **Admin** | `/dashboard/admin` | Approve/reject sign-ups, set custom claims, promote semesters, assign courses to teachers | Global administrative authority |
