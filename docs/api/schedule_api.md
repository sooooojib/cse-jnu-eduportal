# Academic Schedule & Routine API Specification

This document details the endpoints for **Weekly Timetable Matrices**, **Daily Time-Aware Class Schedules**, **CR Routine Management**, and **WhatsApp Routine Broadcasting**.

---

## 1. `GET /api/v1/schedules/weekly`

### Overview
Retrieves the complete weekly routine matrix (Sunday through Thursday) for a specific academic batch or faculty member.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/schedules/weekly`
* **Authentication**: Required (`Bearer <token>`)
* **Required Role**: All Authenticated Roles
* **Query Parameters**:
  - `year`: Batch year (defaults to student's year if student).
  - `semester`: Batch semester (defaults to student's semester if student).
  - `teacherId`: Filter by faculty member.
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "year": 3,
      "semester": 1,
      "schedule": {
        "SUNDAY": [
          {
            "id": "s1eebc99-9c0b-4ef8-bb6d-6bb9bd380a77",
            "courseCode": "CSE-3101",
            "courseTitle": "Operating Systems",
            "startTime": "09:00",
            "endTime": "10:30",
            "room": "Room 402",
            "teacherName": "Prof. Dr. Rahman"
          }
        ],
        "MONDAY": [],
        "TUESDAY": [],
        "WEDNESDAY": [],
        "THURSDAY": []
      }
    },
    "message": "Weekly routine retrieved."
  }
  ```

---

## 2. `GET /api/v1/schedules/daily`

### Overview
Retrieves the time-aware class routine feed. For students/CRs, returns today's classes. For teachers, automatically toggles between Today (05:00–16:59) and Tomorrow (17:00–04:59).

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/schedules/daily`
* **Authentication**: Required
* **Required Role**: All Authenticated Roles
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "displayMode": "TODAY",
      "targetDate": "2026-08-28",
      "dayOfWeek": "SUNDAY",
      "slots": [
        {
          "slotId": "s1eebc99-9c0b-4ef8-bb6d-6bb9bd380a77",
          "courseId": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
          "courseCode": "CSE-3101",
          "courseTitle": "Operating Systems",
          "startTime": "09:00",
          "endTime": "10:30",
          "room": "Room 402",
          "teacherName": "Prof. Dr. Rahman",
          "hasActiveSession": false
        }
      ]
    },
    "message": "Daily schedule retrieved."
  }
  ```

---

## 3. `POST /api/v1/schedules/slots`

### Overview
Creates or adjusts a routine slot. CRs are strictly restricted to scheduling for the immediate next calendar day (Tomorrow).

* **HTTP Method**: `POST`
* **Endpoint**: `/api/v1/schedules/slots`
* **Authentication**: Required
* **Required Role**: `CR`, `ADMIN`
* **Request Body**:
  ```json
  {
    "courseId": "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a33",
    "teacherId": "b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
    "dayOfWeek": "MONDAY",
    "startTime": "09:00",
    "endTime": "10:30",
    "room": "Room 402",
    "targetYear": 3,
    "targetSemester": 1
  }
  ```
* **Validation Rules**:
  - If role is `CR`: `dayOfWeek` must match tomorrow's day of week.
  - `startTime` must precede `endTime`.
  - Checks for room, teacher, and batch collisions.
* **Success Response (`201 Created`)**: `{ "success": true, "data": { "id": "s2eebc99..." }, "message": "Class routine slot scheduled." }`
* **Possible Errors**:
  - `400 Bad Request`: `CR_DATE_LOCKED` ("Class Representatives can only schedule slots for tomorrow.")
  - `409 Conflict`: `SCHEDULE_COLLISION` ("Room 402 is already booked for another course at this time.")

---

## 4. `DELETE /api/v1/schedules/slots/:id`

### Overview
Removes a routine slot from the schedule.

* **HTTP Method**: `DELETE`
* **Endpoint**: `/api/v1/schedules/slots/:id`
* **Authentication**: Required
* **Required Role**: `CR`, `ADMIN`
* **Success Response (`200 OK`)**: `{ "success": true, "message": "Schedule slot deleted." }`

---

## 5. `GET /api/v1/schedules/whatsapp-broadcast`

### Overview
Generates the pre-formatted markdown text for tomorrow's routine to populate WhatsApp group broadcasts.

* **HTTP Method**: `GET`
* **Endpoint**: `/api/v1/schedules/whatsapp-broadcast`
* **Authentication**: Required
* **Required Role**: `CR`, `ADMIN`
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "data": {
      "targetDate": "2026-08-29",
      "formattedText": "📚 *CSE Department Class Routine for Tomorrow*\n📅 Date: 29/08/2026\n🏛️ Year: 3rd Year · Semester: 1st Semester\n\n1️⃣ *CSE-3101: Operating Systems*\n⏰ Time: 09:00 AM - 10:30 AM\n👨‍🏫 Teacher: Prof. Dr. Rahman\n📍 Room: Room 402\n\n_Sent via CSE JnU EduPortal_",
      "whatsappUrl": "https://api.whatsapp.com/send?text=%F0%9F%93%9A%20*CSE%20Department%20Class%20Routine..."
    },
    "message": "Broadcast text generated."
  }
  ```
