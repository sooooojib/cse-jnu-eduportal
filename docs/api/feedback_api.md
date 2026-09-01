# Feedback, Ratings & Attachments API Specification

This document details the endpoints for **Confidential Course & Lecture Feedback**, **Cryptographic Identity Protection**, **Teacher Threaded Replies**, and **File Attachments**.

---

## 1. `POST /api/v1/feedbacks`

### Overview
Submits a confidential course evaluation and star rating for a professor.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/feedbacks`
* **Authentication**: Required (`Bearer <token>`)
* **Required Role**: `STUDENT`, `CR`
* **Request Body**:
  ```json
  {
    "teacherId": "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
    "courseId": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
    "rating": 5,
    "comments": "The operating system memory paging lecture was exceptionally clear. Could we get additional practical examples for virtual memory?",
    "isAnonymous": true,
    "attachmentIds": ["f1eebc99-9c0b-4ef8-bb6d-6bb9bd380a99"]
  }
  ```
* **Validation Rules**:
  - `rating`: Integer from 1 to 5.
  - `comments`: Minimum 10 characters, maximum 2000 characters.
  - `isAnonymous`: Boolean (default `false`).
  - `teacherId`: Valid faculty UUID.
* **Success Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "data": {
      "feedbackId": "fb1eebc9-9c0b-4ef8-bb6d-6bb9bd380a01",
      "rating": 5,
      "isAnonymous": true,
      "createdAt": "2026-08-28T12:00:00.000Z"
    },
    "message": "Feedback submitted successfully."
  }
  ```

---

## 2. `GET /api/v1/feedbacks/my-submitted`

### Overview
Retrieves all feedback entries submitted by the authenticated student.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/feedbacks/my-submitted`
* **Authentication**: Required
* **Required Role**: `STUDENT`, `CR`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "feedbackId": "fb1eebc9-9c0b-4ef8-bb6d-6bb9bd380a01",
        "teacherName": "Prof. Dr. Rahman",
        "courseCode": "CSE-3101",
        "rating": 5,
        "comments": "The lecture on paging was exceptionally clear...",
        "isAnonymous": true,
        "submittedAt": "2026-08-28T12:00:00.000Z",
        "reply": {
          "replyId": "rp1eebc9-9c0b-4ef8-bb6d-6bb9bd380a02",
          "teacherName": "Prof. Dr. Rahman",
          "replyText": "Thank you for the feedback! We will allocate time for hands-on exercises.",
          "repliedAt": "2026-08-28T14:30:00.000Z"
        }
      }
    ],
    "message": "Submitted feedbacks retrieved."
  }
  ```

---

## 3. `GET /api/v1/feedbacks/teacher-inbox`

### Overview
Retrieves received student evaluations for the authenticated professor. Anonymized reviews have student identities completely stripped by the API serialization gateway.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/feedbacks/teacher-inbox`
* **Authentication**: Required
* **Required Role**: `TEACHER`
* **Query Parameters**:
  - `filter`: `all` (default) | `replied` | `not-replied`.
  - `rating`: Filter by specific star rating (1–5).
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "averageRating": 4.8,
      "totalFeedbacks": 18,
      "feedbacks": [
        {
          "feedbackId": "fb1eebc9-9c0b-4ef8-bb6d-6bb9bd380a01",
          "authorName": "Anonymous Student",
          "authorAvatar": null,
          "isAnonymous": true,
          "courseCode": "CSE-3101",
          "rating": 5,
          "comments": "The lecture on paging was exceptionally clear...",
          "submittedAt": "2026-08-28T12:00:00.000Z",
          "attachments": [],
          "reply": null
        }
      ]
    },
    "message": "Feedback inbox retrieved."
  }
  ```

---

## 4. `POST /api/v1/feedbacks/:id/replies`

### Overview
Allows a professor to author an official threaded reply to a student review.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/feedbacks/:id/replies`
* **Authentication**: Required
* **Required Role**: `TEACHER`
* **Request Body**:
  ```json
  {
    "replyText": "Thank you! We will allocate two additional lab sessions for virtual memory simulations."
  }
  ```
* **Validation Rules**: `replyText`: Required, min 2 chars, max 2000 chars.
* **Success Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "data": {
      "replyId": "rp1eebc9-9c0b-4ef8-bb6d-6bb9bd380a02",
      "feedbackId": "fb1eebc9-9c0b-4ef8-bb6d-6bb9bd380a01",
      "replyText": "Thank you! We will allocate two additional lab sessions...",
      "createdAt": "2026-08-28T14:30:00.000Z"
    },
    "message": "Reply posted successfully."
  }
  ```

---

## 5. `POST /api/v1/attachments/upload`

### Overview
Uploads a document, screenshot, or code attachment.

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/attachments/upload`
* **Authentication**: Required
* **Content-Type**: `multipart/form-data`
* **Request Body**:
  - `file`: Binary file stream (max 10MB; PNG, JPEG, PDF, DOCX, TXT, Java, C, Python).
  - `parentType`: `'FEEDBACK'`, `'FEEDBACK_REPLY'`, or `'COUNSELING'`.
* **Success Response (`201 Created`)**:
  ```json
  {
    "success": true,
    "data": {
      "attachmentId": "f1eebc99-9c0b-4ef8-bb6d-6bb9bd380a99",
      "fileName": "assignment_snippet.png",
      "fileUrl": "https://storage.cse.jnu.ac.bd/attachments/f1eebc99.png",
      "fileSizeBytes": 524288,
      "mimeType": "image/png"
    },
    "message": "File uploaded successfully."
  }
  ```
* **Possible Errors**:
  - `413 Payload Too Large`: `FILE_TOO_LARGE` ("Maximum file size is 10 MB.")
  - `415 Unsupported Media Type`: `UNSUPPORTED_MEDIA_TYPE` ("File type not supported.")
