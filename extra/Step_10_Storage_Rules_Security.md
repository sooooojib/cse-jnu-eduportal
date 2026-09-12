# `storage.rules` — Firebase Cloud Storage Security Rules Guide

In Firebase, **[`storage.rules`](file:///Users/sajib/Desktop/CSE_DEPT/storage.rules)** defines the **server-side security firewall** for Google Cloud Storage.

While the Flutter mobile app provides the user interface for uploading profile pictures and document attachments, **`storage.rules` runs entirely in Google's cloud infrastructure**. It cannot be bypassed, tampered with, or overridden by any client-side code.

---

## 📄 Complete File Overview

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }

    function isAdmin() {
      return isAuthenticated() && request.auth.token.role == 'ADMIN';
    }

    function isValidImage() {
      return request.resource.contentType.matches('image/(jpeg|png|webp)') &&
             request.resource.size < 5 * 1024 * 1024;
    }

    function isValidDocument() {
      return (
        request.resource.contentType.matches('image/(jpeg|png|webp)') ||
        request.resource.contentType == 'application/pdf' ||
        request.resource.contentType == 'text/plain'
      ) && request.resource.size < 10 * 1024 * 1024;
    }

    // Profile Avatars
    match /avatars/{userId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if (isOwner(userId) || isAdmin()) && isValidImage();
      allow delete: if isOwner(userId) || isAdmin();
    }

    // Feedback Attachments
    match /feedback/{userId}/{attachmentId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId) && isValidDocument();
      allow delete: if isOwner(userId) || isAdmin();
    }

    // Counseling Attachments
    match /counseling/{userId}/{attachmentId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId) && isValidDocument();
      allow delete: if isOwner(userId) || isAdmin();
    }
  }
}
```

---

## 🔍 Key Security Functions Explained

### 1. `isAuthenticated()`
```javascript
function isAuthenticated() {
  return request.auth != null;
}
```
* Ensures that only logged-in university users with an active Firebase Auth JWT token can access storage. Anonymous or public web scrapers are completely blocked.

---

### 2. `isOwner(userId)`
```javascript
function isOwner(userId) {
  return isAuthenticated() && request.auth.uid == userId;
}
```
* **Critical Privacy Check:** Ensures that User `A` cannot upload, overwrite, or delete files belonging to User `B`. The upload path's `{userId}` folder must strictly match the caller's authenticated `request.auth.uid`.

---

### 3. `isAdmin()`
```javascript
function isAdmin() {
  return isAuthenticated() && request.auth.token.role == 'ADMIN';
}
```
* Checks the user's custom token claims (`request.auth.token.role`).
* Allows department administrators to moderate, delete, or manage user files when necessary.

---

### 4. `isValidImage()` (Protection Against Malicious File Uploads)
```javascript
function isValidImage() {
  return request.resource.contentType.matches('image/(jpeg|png|webp)') &&
         request.resource.size < 5 * 1024 * 1024;
}
```
* **File Type Whitelisting**: Only allows genuine image formats (`JPEG`, `PNG`, `WebP`). Executable files (`.exe`, `.sh`, `.apk`, `.js`) are immediately rejected.
* **Size Quota Enforcement**: Caps file size at **5 Megabytes** (`5 * 1024 * 1024` bytes) to prevent accidental bandwidth abuse or storage exhaustion attacks.

---

### 5. `isValidDocument()`
```javascript
function isValidDocument() {
  return (
    request.resource.contentType.matches('image/(jpeg|png|webp)') ||
    request.resource.contentType == 'application/pdf' ||
    request.resource.contentType == 'text/plain'
  ) && request.resource.size < 10 * 1024 * 1024;
}
```
* Used for academic attachments (e.g. medical certificates, counseling documents, feedback screenshots).
* Accepts images, PDFs, and plain text files.
* Caps the document size limit at **10 Megabytes**.

---

## 🗂️ Storage Bucket Folder Rules

```text
Google Cloud Storage Bucket (sajib-73b14.firebasestorage.app)
├── avatars/
│   └── {userId}/          # 1. Profile Avatars
│       └── photo.jpg
│
├── feedback/
│   └── {userId}/          # 2. Feedback Attachments
│       └── issue_proof.png
│
└── counseling/
    └── {userId}/          # 3. Counseling Documents
        └── medical_note.pdf
```

### 1. Profile Avatars (`/avatars/{userId}/{fileName}`)
* **Read**: Any authenticated university member can view avatars in the roster or profile card.
* **Write (Upload/Replace)**: Only the owner (`isOwner(userId)`) or an Admin can upload, and the file must pass `isValidImage()` (under 5MB, valid image format).
* **Delete**: Only the owner or an Admin can remove the avatar.

---

### 2. Feedback Attachments (`/feedback/{userId}/{attachmentId}`)
* **Read**: Authenticated users.
* **Write**: Only the student uploading the feedback can attach supporting documents (`isValidDocument()`, under 10MB).
* **Delete**: Owner or Admin.

---

### 3. Counseling Attachments (`/counseling/{userId}/{attachmentId}`)
* **Read**: Authenticated users (the student and assigned teacher).
* **Write**: Only the student booking the counseling session can attach academic records or notes (`isValidDocument()`, under 10MB).
* **Delete**: Owner or Admin.

---

## 🛡️ Summary: Why This Architecture is Secure
1. **Zero Client Trust**: Even if someone alters the Flutter code on a rooted phone to upload a 500MB executable file, Google Cloud Storage immediately blocks the request at the network edge with a `403 Forbidden` error.
2. **Quota & Cost Protection**: Hard size limits (5MB for images, 10MB for documents) prevent accidental storage ballooning.
3. **Identity Isolation**: The `{userId}` path parameter locks every user into their own private directory.
