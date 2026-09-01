# Functional Requirements: Feedback, Anonymity & Attachments

This document details the functional specifications for the **Confidential Feedback Pipeline**, **Cryptographic Anonymity Protection**, **Teacher Threaded Replies**, and **File Attachments**.

---

## 1. Feature: Student Course & Lecture Feedback

### Overview
A confidential feedback channel enabling students to provide constructive criticism, lecture evaluations, and star ratings directly to faculty members to foster academic improvement.

### Feature Specification
* **Who can use it**: `STUDENT`, `CR`.
* **What the user can do**:
  1. Select a professor from their enrolled course instructors.
  2. Assign an overall rating from 1 to 5 stars.
  3. Write detailed written feedback regarding lectures, course materials, or lab sessions.
  4. Toggle **"Submit Anonymously"** to mask their identity from the professor.
  5. Attach optional files (screenshots, assignment snippets, PDF documents).
  6. Submit the review and view subsequent faculty responses.
* **Required Inputs**:
  - `teacherId`: UUID of the instructor.
  - `rating`: Integer (1, 2, 3, 4, or 5).
  - `comments`: Feedback text (string, 10–2000 characters).
  - `isAnonymous`: Boolean (default `false`).
  - `attachmentIds`: Optional array of uploaded `Attachment` UUIDs.
* **Expected Outputs**:
  - `201 Created` with stored `Feedback` record.
  - Immediately visible in the student's personal feedback history and the teacher's inbox.
* **Validation Rules**:
  - `rating` must be an integer between 1 and 5 inclusive.
  - `comments` must meet minimum character length (10 chars) to prevent spam.
  - `teacherId` must correspond to an active faculty member in the department.
* **Authorization Requirements**: Protected by `STUDENT` and `CR` RBAC guards.

---

## 2. Feature: Anonymity Protection & Privacy Engine (BR-FEED)

### Architecture of Anonymity
To encourage honest and unbiased academic feedback, student identity protection is enforced at the backend serialization layer:

```
[ Student Submits Feedback with isAnonymous: true ]
                       │
                       ▼
            Database Record Stored
 (Preserves studentId for institutional integrity & audit)
                       │
                       ▼
┌────────────────────────────────────────────────────────┐
│               Backend Serialization Gateway            │
├────────────────────────────┬───────────────────────────┤
│ Query from TEACHER:        │ Query from ADMIN:         │
│ • studentId: STRIPPED      │ • studentId: VISIBLE      │
│ • studentName: "Anonymous" │ • studentName: Real Name  │
│ • studentEmail: STRIPPED   │ • Full Audit Trail        │
│ • avatar: Default Icon     │                           │
└────────────────────────────┴───────────────────────────┘
```

### Business Rules:
1. When a professor views feedback, if `isAnonymous === true`, the API guarantees that no identifying metadata (name, student ID, avatar, email, enrollment year) is returned.
2. Administrators retain read-only audit capabilities to prevent harassment or severe policy breaches while protecting routine academic feedback.

---

## 3. Feature: Faculty Threaded Replies

### Overview
Two-way academic communication allowing professors to respond publicly or privately to student feedback cards.

### Feature Specification
* **Who can use it**: `TEACHER`.
* **What the user can do**: View received feedback cards filtered by tabs (`All Feedbacks`, `Replied`, `Not Replied`), write an official response to any feedback entry, and attach reference files.
* **Required Inputs**:
  - `feedbackId`: Target `Feedback` UUID.
  - `replyText`: Response text (string, 2–2000 characters).
  - `attachmentIds`: Optional array of uploaded `Attachment` UUIDs.
* **Expected Outputs**:
  - Created `FeedbackReply` record linked to the parent feedback.
  - Threaded reply card rendered directly underneath the student review in both Teacher and Student views.
* **Validation Rules**:
  - Teacher can only reply to feedback directed to them (or `ADMIN` override).
* **Authorization Requirements**: `TEACHER`, `ADMIN`.

---

## 4. Feature: File Attachments Engine

### Overview
Multi-format file upload pipeline supporting feedback documentation, assignment questions, and counseling reference materials.

### Feature Specification
* **Who can use it**: All Authenticated Roles (`STUDENT`, `CR`, `TEACHER`, `ADMIN`).
* **What the user can do**: Upload documents, screenshots, and code files via `multipart/form-data`, receiving a persistent attachment token/URL to embed into feedback or replies.
* **Supported MIME Types**:
  - Images: `image/png`, `image/jpeg`, `image/webp`
  - Documents: `application/pdf`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document` (`.docx`)
  - Code/Text: `text/plain`, `text/x-c`, `text/x-java`, `text/x-python`
* **File Constraints**:
  - Maximum file size: **10 MB** per file.
  - Virus/malware scanning & filename sanitization on upload.
* **Validation Rules**:
  - Files exceeding size limit are rejected with `413 Payload Too Large`.
  - Unsupported file types are rejected with `415 Unsupported Media Type`.
* **Expected Outputs**: `201 Created` returning `attachmentId`, `fileUrl`, `fileName`, `fileSize`, `mimeType`.
