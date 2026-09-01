# Functional Requirements: Roles, Authentication & Account Access

This document specifies the requirements for **User Roles**, **Authentication**, **Authorization / RBAC**, and **Signup & Account Approval**.

---

## 1. User Roles

### Role Definitions
1. **`STUDENT` (Student)**: Enrolled undergraduate student belonging to a specific academic Year (1–4) and Semester (1–2).
2. **`CR` (Class Representative)**: Enrolled undergraduate student possessing standard student capabilities plus delegated administrative privileges to schedule tomorrow's class routine, broadcast schedules to WhatsApp, and export class attendance sheets.
3. **`TEACHER` (Professor / Faculty)**: Departmental instructor assigned to courses, managing live attendance verification sessions, holding counseling office hours, reviewing course feedback, and viewing teaching timetables.
4. **`ADMIN` (Department Administrator)**: Administrative authority managing signup requests, approving semester promotions, managing the user directory, and assigning courses to teachers.

---

## 2. Feature: Signup & Account Request Pipeline

### Overview
Public registration gateway where prospective students, CRs, and teachers submit onboarding requests for administrator review.

### Feature Specification
* **Who can use it**: Public / Unauthenticated users.
* **What the user can do**: Select an account type (`STUDENT`, `CR`, `TEACHER`), enter identification and contact details, and submit a registration request.
* **Required Inputs**:
  - `accountType`: Role selection (`STUDENT`, `CR`, or `TEACHER`).
  - `name`: Full legal/institutional name (string, 2–100 characters).
  - `email`: Valid institutional or personal email address (unique in system).
  - `studentId`: Required if role is `STUDENT` or `CR` (e.g., `2020CSE001`).
  - `phone`: Required if role is `TEACHER` (e.g., `01700000000`).
* **Expected Outputs**:
  - `201 Created` status with confirmation message: *"Your request has been sent to the admin for approval. You will receive an email with your credentials once approved."*
  - Persistent record created in `SignupRequest` queue with status `PENDING`.
* **Validation Rules**:
  - Email must match standard email regex pattern.
  - If `accountType` is `STUDENT` or `CR`, `studentId` is mandatory and must match departmental student ID format (e.g., `^\d{4}CSE\d{3}$`).
  - If `accountType` is `TEACHER`, `phone` is mandatory and must match Bangladeshi phone format (`^(\+88)?01[3-9]\d{8}$`).
  - Email and Student ID must not already exist in active `User` table or active `PENDING` requests.
* **Authorization Requirements**: Publicly accessible.
* **Important Business Rules**:
  - Submitting a request does **not** grant immediate platform access.
  - Initial password is not supplied by the applicant; it is cryptographically generated upon Admin approval.
* **Edge Cases**:
  - Re-submission with an existing email that was previously `REJECTED`: System allows new submission or updates the existing rejected request record.
  - Submitting with an already active `APPROVED` email: System rejects with `409 Conflict` ("Account already exists. Please log in.").
* **Dependencies on Other Features**: Depends on Admin Approval Pipeline and Email Dispatch Service.
* **Ambiguities**:
  - **AMBIGUOUS — REQUIRES DECISION**: How are initial Year and Semester selected for student signups? (Recommended: Default to Year 1 Sem 1, or allow student to select in signup form, or set by Admin during approval).

---

## 3. Feature: Admin Signup Moderation & Credential Provisioning

### Overview
Administrator review queue for approving or rejecting incoming registration requests.

### Feature Specification
* **Who can use it**: `ADMIN` only.
* **What the user can do**: View pending signup requests, approve a request with automated password generation & email dispatch, or reject a request with an optional reason note.
* **Required Inputs**:
  - `requestId`: Target `SignupRequest` UUID.
  - `action`: `APPROVE` or `REJECT`.
  - `rejectionReason`: Required if action is `REJECT` (string, max 500 chars).
  - `assignedYear` & `assignedSemester`: Optional inputs when approving `STUDENT` or `CR` (default to 1 / 1).
* **Expected Outputs**:
  - If `APPROVE`:
    - Generates cryptographically secure 8+ character random password.
    - Creates active `User` record with hashed password.
    - Updates `SignupRequest` status to `APPROVED`.
    - Triggers async HTML welcome email containing login credentials.
  - If `REJECT`:
    - Updates `SignupRequest` status to `REJECTED` with reason recorded.
* **Validation Rules**: `requestId` must exist and be in `PENDING` state.
* **Authorization Requirements**: Protected by `ADMIN` RBAC guard.
* **Important Business Rules**:
  - The provisioning operation must run inside an atomic database transaction.
* **Edge Cases**:
  - Email dispatch failure: User record is created, but system flags email delivery retry queue.
  - Admin approves a request whose email was created out-of-band: Transaction aborts with `409 Conflict`.
* **Dependencies on Other Features**: Email Service, User Management, Auth Service.

---

## 4. Feature: User Authentication & Session Management

### Overview
Secure login mechanism with JWT access/refresh tokens.

### Feature Specification
* **Who can use it**: All active users (`STUDENT`, `CR`, `TEACHER`, `ADMIN`).
* **What the user can do**: Log in with email and password, refresh tokens, view active session info, and log out.
* **Required Inputs**:
  - `email`: User email address.
  - `password`: User password (plain text via HTTPS).
* **Expected Outputs**:
  - `200 OK` with JSON envelope containing `accessToken`, `refreshToken`, and sanitized `User` profile object (`id`, `name`, `email`, `role`, `year`, `semester`, `studentId`, `phone`, `avatarUrl`).
* **Validation Rules**:
  - Non-empty email and password strings.
  - Password comparison against secure stored hash (Argon2id/bcrypt).
* **Authorization Requirements**: Public for `/login` and `/refresh`; Authenticated for `/me` and `/logout`.
* **Important Business Rules**:
  - Short-lived Access Token (e.g., 15 minutes) + Long-lived Refresh Token (e.g., 7 days).
  - Failed logins must increment rate-limiting counter to prevent brute-force attacks (max 5 failed attempts per 5 minutes per IP/email).
* **Edge Cases**:
  - Account disabled / deleted while token is active: Token validation checks user active status or blacklist.
  - User role changed while logged in: Refresh token exchange returns updated claims.
* **Dependencies on Other Features**: User Repository, Token Service, Secure Storage.
* **Ambiguities**:
  - **AMBIGUOUS — REQUIRES DECISION**: Password self-reset / "Forgot Password" workflow is not present in original documentation. Should a standard email OTP password reset flow be included for mobile users?

---

## 5. Feature: Role-Based Access Control (RBAC) & Authorization

### Overview
Authoritative backend policy engine enforcing endpoint and action permissions.

### Feature Specification
* **Who can use it**: Backend middleware / Security interceptors.
* **What the system does**: Decodes JWT bearer token, checks active status, verifies assigned role against route requirements, and grants or rejects access.
* **Authorization Matrix Summary**:
  - `ADMIN`: Full access to user management, course assignments, signup approvals, and semester request approvals.
  - `TEACHER`: Access to assigned courses, live attendance sessions, counseling slot creation and approval, received feedback, and personal teaching timetable.
  - `CR`: Student permissions + permission to schedule routine slots for tomorrow, broadcast routines to WhatsApp, and export class attendance.
  - `STUDENT`: Access to personal course attendance, attendance code submission, routine viewing, counseling bookings, feedback submission, and semester upgrade petitions.
* **Expected Outputs**:
  - `401 Unauthorized` if token is missing, expired, or signature is invalid.
  - `403 Forbidden` if user role is not authorized for the requested endpoint.
