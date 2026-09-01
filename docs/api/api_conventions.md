# API Design Conventions & Standards

This document establishes the uniform REST design standards, URL naming conventions, pagination schemas, filtering/sorting protocols, and standard headers for **CSE JnU EduPortal**.

---

## 1. URI & Naming Conventions

- **Resource Nouns**: Use plural, lowercase, kebab-case nouns for endpoints (e.g. `/attendance-sessions`, `/counseling-slots`, `/signup-requests`).
- **Hierarchical Sub-resources**: Nested paths represent ownership or parent-child relations:
  - `POST /counseling-slots/:slotId/requests` (Create request under specific slot)
  - `GET /attendance-sessions/:sessionId/roster` (Roster of a specific attendance session)
  - `POST /feedbacks/:feedbackId/replies` (Reply to a specific feedback entry)
- **Actions & State Transitions**: Use verb sub-paths for state-machine transitions:
  - `POST /attendance-sessions/:id/deactivate`
  - `POST /attendance-sessions/:id/regenerate-code`
  - `POST /admin/signup-requests/:id/approve`
  - `POST /admin/signup-requests/:id/reject`

---

## 2. Standard HTTP Headers

| Header | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `Authorization` | `String` | Yes (for protected endpoints) | `Bearer <access_jwt_token>` |
| `Content-Type` | `String` | Yes | `application/json` or `multipart/form-data` |
| `Accept` | `String` | Yes | `application/json` |
| `X-Client-Platform` | `String` | Optional | `flutter-android` or `flutter-ios` |
| `X-App-Version` | `String` | Optional | Semantic version string (e.g. `1.0.0`) |

---

## 3. Standard Pagination, Filtering & Sorting

### 3.1 Pagination Query Parameters
All list endpoints support standard limit-offset pagination:
- `page`: 1-indexed page number (default: `1`, minimum: `1`).
- `limit`: Number of records per page (default: `20`, minimum: `1`, maximum: `100`).

### 3.2 Sorting Parameter (`sort`)
- Suffix or prefix notation for sort order:
  - Ascending: `sort=title` or `sort=+created_at`
  - Descending: `sort=-created_at` or `sort=-rating`
- Multiple sort keys: `sort=-year,semester,code`

### 3.3 Standard Search & Filter Parameters
- `search`: Free-text search string matched against relevant text columns (e.g. `search=Rahman`).
- `status`: Exact filter on status enums (e.g. `status=PENDING` or `status=ACTIVE`).
- `year` & `semester`: Filter by academic batch (e.g. `year=3&semester=1`).

---

## 4. Standard Response Envelope Schemas

### 4.1 Single Resource Success Envelope (`200 OK`, `201 Created`)
```json
{
  "success": true,
  "data": {
    "id": "e3b0c442-98fc-1c14-9af0-2a3b95797741",
    "code": "CSE-3101",
    "title": "Operating Systems",
    "credit": 3.0,
    "year": 3,
    "semester": 1,
    "createdAt": "2026-08-28T12:00:00.000Z"
  },
  "message": "Resource retrieved successfully.",
  "meta": {
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```

### 4.2 Paginated List Success Envelope (`200 OK`)
```json
{
  "success": true,
  "data": [
    {
      "id": "e3b0c442-98fc-1c14-9af0-2a3b95797741",
      "code": "CSE-3101",
      "title": "Operating Systems"
    }
  ],
  "message": "Courses retrieved successfully.",
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 45,
    "totalPages": 3,
    "hasNextPage": true,
    "hasPrevPage": false,
    "timestamp": "2026-08-28T12:00:00.000Z"
  }
}
```
