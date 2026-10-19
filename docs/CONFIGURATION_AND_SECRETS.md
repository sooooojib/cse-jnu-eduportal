# CSE JnU EduPortal — Configuration and Secrets Management

This document defines the configuration parameters, environment secrets, and security practices for external communications (Email & WhatsApp), Firebase Cloud Functions, and mobile runtime architectures in the **CSE JnU EduPortal**.

---

## 1. Security Architecture & Invariants

### 1.1 Server-Side Secret Isolation (Never in Flutter)
* **Zero Client Secrets**: SMTP credentials, API secret tokens, and administrative service account keys are **strictly forbidden** from the Flutter client codebase (`mobile/`).
* **Client Impersonation Protection**: Clients cannot forge or trigger arbitrary transactional emails directly. All email dispatches are governed exclusively through authenticated, role-gated Cloud Functions (`approveSignupRequest`, `rejectSignupRequest`, `testEmailTransport`).
* **Privileged Credentials Handling**: Temporary passwords generated during onboarding are produced by server-side Cloud Functions and dispatched directly to the user's verified university email. They are never sent from or stored in the client.

### 1.2 Non-Blocking External Communication Isolation
* **Transaction Decoupling**: External communication calls (SMTP dispatch, network socket connections, third-party messaging APIs) are **never executed inside atomic Firestore transactions**.
* **Zero State Corruption**: If an external email server encounters a network timeout, authentication failure, or invalid mailbox, the failure **must not roll back or corrupt core application state** (such as approving the user's account or updating semester status).
* **Audit Trail**: Every outbound communication event (success or failure) is logged to the server-side `communicationLogs` collection with timestamp, recipient, template type, and error diagnostics.

---

## 2. Environment Variables & Secret Configuration

### 2.1 Backend Secrets (`functions/.env`)

Configure the following variables in Google Cloud Secret Manager or `functions/.env` for local emulator / Cloud Functions runtime:

| Variable Name | Required | Default / Example | Purpose |
| :--- | :---: | :--- | :--- |
| `SMTP_HOST` | **Yes** (Prod) | `smtp.gmail.com` or `mail.jnu.ac.bd` | Hostname of institutional SMTP server |
| `SMTP_PORT` | No | `587` (TLS) or `465` (SSL) | SMTP connection port |
| `SMTP_USER` | **Yes** (Prod) | `notifications@cse.jnu.ac.bd` | Authorized SMTP authentication username |
| `SMTP_PASS` | **Yes** (Prod) | `••••••••••••••••` | Authorized SMTP app password / API token |
| `SENDER_EMAIL` | No | `cse.jnu.eduportal@gmail.com` | Institutional sender display email |
| `PORTAL_BASE_URL` | No | `https://cse-jnu-eduportal.web.app` | Base URL used to construct login links |

> [!NOTE]
> In local development or test environments where `SMTP_HOST` and `SMTP_PASS` are unset, the system automatically enters **Safe Dev Mode**. Emails are logged to the console and recorded as `SENT` (with a simulated message ID `sim_...`) in `communicationLogs` without crashing or requiring live network connectivity.

### 2.2 Configuring Secrets in Firebase / Google Cloud
To configure production secrets using Firebase Functions Secret Manager:
```bash
# Set individual secrets
firebase functions:secrets:set SMTP_HOST
firebase functions:secrets:set SMTP_PORT
firebase functions:secrets:set SMTP_USER
firebase functions:secrets:set SMTP_PASS
firebase functions:secrets:set SENDER_EMAIL
firebase functions:secrets:set PORTAL_BASE_URL
```

---

## 3. Approved Email Notification Workflows

The server provides branded HTML and plain-text templates with the official Jagannath University Department of Computer Science & Engineering identity:

### 3.1 Onboarding Email (`ONBOARDING`)
* **Trigger**: Triggered automatically upon administrative approval of a pending user signup (`approveSignupRequest`).
* **Content**: Branded welcome banner, institutional role (Student, Faculty Member, CR), Student ID (for students), temporary login password, and secure login action button.
* **Security Notice**: Instructs user to change password immediately upon first login and warns against sharing credentials.

### 3.2 Signup Rejection Email (`SIGNUP_REJECTION`)
* **Trigger**: Triggered when an administrator rejects a signup petition (`rejectSignupRequest`).
* **Content**: Official decline statement, departmental reason recorded by the administrator, and instructions for resolving the discrepancy at the department office with university admission documents.

### 3.3 Semester Decision Email (`SEMESTER_DECISION`)
* **Trigger**: Academic semester upgrade approval or rejection.
* **Content**: Summarizes new academic cohort or explanation for rejection.

---

## 4. WhatsApp Routine-Sharing Architecture

### 4.1 Authoritative Bangladeshi Phone Number Normalization
Mobile numbers are strictly validated and formatted according to Bangladesh National Numbering Plan rules:
* **Approved Operator Prefixes**:
  * `013`, `017`: Grameenphone
  * `014`, `019`: Banglalink
  * `016`, `018`: Robi / Airtel
  * `015`: Teletalk
* **Formats Produced**:
  * **National**: `01712345678` (11 digits, standard local display)
  * **International**: `+8801712345678` (E.164 international standard)
  * **WhatsApp Target**: `8801712345678` (Required format for `wa.me` links, digits only, no leading `+`)
  * **Display**: `01712-345678`

### 4.2 Multi-Tier Deep Link Resolution & Fallback
The `WhatsAppShareService` and `WhatsAppShareDialog` implement a 3-tier launching pipeline:
1. **Tier 1 (Native Scheme)**: Attempts opening `whatsapp://send?phone=...&text=...` directly into the installed WhatsApp client via `LaunchMode.externalApplication`.
2. **Tier 2 (Universal Web Link)**: If native intent fails, cascades to `https://wa.me/8801...?text=...` or universal web endpoint.
3. **Tier 3 (Safe Clipboard Fallback)**: If no compatible browser or intent handler exists on the device, the routine message is copied to the system clipboard and a clear user instruction toast is displayed.
4. **Broadcast vs. Direct Recipient**: If a valid contact number is provided, the message targets that specific recipient. If left empty, it opens WhatsApp for general broadcast to class groups.

---

## 5. Security Rules for Communication Logs

In [`firestore.rules`](file:///Users/sajib/Desktop/CSE_DEPT/firestore.rules):
```rules
match /communicationLogs/{logId} {
  allow read: if isAdmin();
  allow write: if false; // Server-side Cloud Functions only
}
```
* Clients have zero write permission to `communicationLogs`.
* Only authenticated administrators can inspect delivery logs, message IDs, and failure reasons.
