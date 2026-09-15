# 🎓 CSE JnU EduPortal — Master Reading Roadmap

Follow these 11 guides in numerical order (**Step 01 ➔ Step 11**) to understand the full project architecture, code execution lifecycle, and Clean Architecture design patterns.

---

## 🧭 Step-by-Step Learning Path

```text
       LEVEL 1: THE BIG PICTURE
Step 01: Full Monorepo Architecture (Mobile + Cloud Functions + Firebase)
   │
   ▼
Step 02: Flutter Mobile App Project Layout (Android, iOS, pubspec.yaml)
   │
   ▼
Step 03: Source Code Map (mobile/lib/ Clean Architecture layers)

       LEVEL 2: BOOTSTRAPPING & CLOUD CONNECTION
Step 04: App Startup Lifecycle (main.dart line-by-line flow)
   │
   ▼
Step 05: Cloud Connection & Security (firebase_options.dart)

       LEVEL 3: FOUNDATIONAL BUILDING BLOCKS
Step 06: Core Infrastructure (mobile/lib/core: DI, Keystore Storage, Error Translation)
   │
   ▼
Step 07: Application Shell (mobile/lib/app: Root Widget, RBAC Routing Guards, Theme)
   │
   ▼
Step 08: Shared UI Design System (mobile/lib/shared: Buttons, Cards, Inputs, Modals)

       LEVEL 4: BUSINESS DOMAIN LOGIC
Step 09: Feature Modules (mobile/lib/features: The 9 Clean Architecture domains)
   │
   ▼
       LEVEL 5: CLOUD SECURITY & RULES
Step 10: Cloud Storage Firewall (storage.rules: Avatars, Attachments, File Validation)
   │
   ▼
       LEVEL 6: SECURITY & IDENTITY DEEP DIVE
Step 11: Authentication & RBAC (Signup Petitions, Custom Claims, Keystore, GoRouter Guards)
```

---

## 📖 Roadmap Table of Contents

| Order | File | What You Will Learn |
|:---:|:---|:---|
| **Step 01** | [`Step_01_Project_Architecture.md`](Step_01_Project_Architecture.md) | **Start Here.** The full bird's-eye view: how the Flutter client, Cloud Functions, and Firebase serverless services interact. |
| **Step 02** | [`Step_02_Mobile_Project_Overview.md`](Step_02_Mobile_Project_Overview.md) | The Flutter project container: native Android/iOS runners, assets, dependencies in `pubspec.yaml`, and testing. |
| **Step 03** | [`Step_03_Mobile_Lib_Architecture.md`](Step_03_Mobile_Lib_Architecture.md) | Overview of `mobile/lib/`: understand the 4 Clean Architecture layers before diving into specific code. |
| **Step 04** | [`Step_04_Main_Dart_Startup_Flow.md`](Step_04_Main_Dart_Startup_Flow.md) | How the app boots: Flutter engine binding, Firebase initialization, offline disk caching, and error shields. |
| **Step 05** | [`Step_05_Firebase_Options_Config.md`](Step_05_Firebase_Options_Config.md) | How the app talks to Google Cloud: platform switching (Android/iOS/Web), API keys, and security rules. |
| **Step 06** | [`Step_06_Core_Infrastructure.md`](Step_06_Core_Infrastructure.md) | The engine room: Dependency Injection via `GetIt`, encrypted hardware storage, error handling, and JnU validators. |
| **Step 07** | [`Step_07_App_Shell_Routing_Theme.md`](Step_07_App_Shell_Routing_Theme.md) | The gatekeeper & styling: `app.dart`, GoRouter with Role-Based Access Control (RBAC) guards, and the Emerald Scholar theme. |
| **Step 08** | [`Step_08_Shared_UI_Components.md`](Step_08_Shared_UI_Components.md) | The Design System widget library: reusable pill buttons, cards, text fields, state loaders, and the living Storybook screen. |
| **Step 09** | [`Step_09_Domain_Features_Clean_Arch.md`](Step_09_Domain_Features_Clean_Arch.md) | The business engine: deep dive into all 9 feature modules (`auth`, `dashboard`, `attendance`, `counseling`, `schedule`, etc.) using `domain`, `data`, and `presentation` layers. |
| **Step 10** | [`Step_10_Storage_Rules_Security.md`](Step_10_Storage_Rules_Security.md) | Cloud Storage security firewall (`storage.rules`): user ownership isolation, file MIME whitelisting, and size quotas. |
| **Step 11** | [`Step_11_Authentication_And_RBAC.md`](Step_11_Authentication_And_RBAC.md) | End-to-end Authentication & RBAC lifecycle: sign-up petitions, Cloud Functions claims injection, hardware keystore encryption, and GoRouter guards. |
