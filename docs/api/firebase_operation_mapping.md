# Firebase Operation & API Mapping Specification
## CSE JnU EduPortal — Stage 11 API Redesign

---

## 1. Overview & Paradigm Shift

In the Firebase architecture, traditional **HTTP REST Endpoints** (`GET`, `POST`, `PUT`, `DELETE`) are superseded by two distinct access patterns:

1. **Direct Firestore SDK Operations**: Read and write operations performed directly from the Flutter mobile app against Cloud Firestore collections, authorized via **Firestore Security Rules**.
2. **Cloud Functions (Callable & Triggers)**: Invoked for operations that require multi-document transactions, the Firebase Admin SDK, or elevated system privileges.

---

## 2. Comprehensive Endpoint-to-Firebase Mapping

### 2.1 Authentication & Registration Module

| Previous REST Endpoint | Firebase Modern Equivalent | Execution Model | Security & Authorization |
|:---|:---|:---|:---|
| `POST /api/v1/auth/login` | `FirebaseAuth.instance.signInWithEmailAndPassword(email, password)` | Client SDK | Public; validates credentials against Firebase Auth directory. |
| `GET /api/v1/auth/me` | `FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get()` | Client SDK | Authenticated user reading own profile (`isUser(uid)`). |
| `POST /api/v1/auth/logout` | `FirebaseAuth.instance.signOut()` | Client SDK | Client-side session termination. |
| `POST /api/v1/auth/refresh` | **Deprecated / Auto** | Native SDK | Handled automatically by Firebase Auth token refresher. |
| `POST /api/v1/auth/signup-request` | `FirebaseFirestore.instance.collection('signupRequests').add(data)` | Client SDK | Public write with schema validation (`status == 'PENDING'`). |

---

### 2.2 Admin Management Module

| Previous REST Endpoint | Firebase Modern Equivalent | Execution Model | Security & Authorization |
|:---|:---|:---|:---|
| `GET /api/v1/admin/signup-requests` | `collection('signupRequests').where('status', '==', 'PENDING').snapshots()` | Client SDK | `isAdmin()` Security Rule. |
| `POST /api/v1/admin/signup-requests/:id/approve` | `FirebaseFunctions.instance.httpsCallable('approveSignupRequest').call({'requestId': id, ...})` | **Cloud Function** | `isAdmin()` required; creates Auth account + Firestore user doc + sends welcome email. |
| `POST /api/v1/admin/signup-requests/:id/reject` | `FirebaseFunctions.instance.httpsCallable('rejectSignupRequest').call({'requestId': id, 'reason': ...})` | **Cloud Function** | `isAdmin()` required; updates status + sends rejection email. |
| `GET /api/v1/admin/users` | `collection('users').where('role', '==', selectedRole).snapshots()` | Client SDK | `isAdmin()` Security Rule. |
| `POST /api/v1/admin/users` | `FirebaseFunctions.instance.httpsCallable('createDepartmentUser').call(userData)` | **Cloud Function** | `isAdmin()` required; provisions Auth account + sets Custom Claims + creates user doc. |
| `DELETE /api/v1/admin/users/:id` | `FirebaseFunctions.instance.httpsCallable('deleteDepartmentUser').call({'userId': id})` | **Cloud Function** | `isAdmin()` required; deletes Auth user + disables Firestore profile. |
| `POST /api/v1/admin/users/:teacherId/courses` | `collection('users').doc(teacherId).update({'assignedCourseIds': courseIds})` | Client SDK | `isAdmin()` Security Rule. |
| `GET /api/v1/admin/semester-requests` | `collection('semesterUpgradeRequests').where('status', '==', 'PENDING').snapshots()` | Client SDK | `isAdmin()` Security Rule. |
| `POST /api/v1/admin/semester-requests/:id/approve` | `FirebaseFunctions.instance.httpsCallable('approveSemesterUpgrade').call({'requestId': id})` | **Cloud Function** | `isAdmin()` required; updates user `(year, semester)` + updates Auth Custom Claims. |
| `POST /api/v1/admin/semester-requests/:id/reject` | `FirebaseFunctions.instance.httpsCallable('rejectSemesterUpgrade').call({'requestId': id, 'reason': ...})` | **Cloud Function** | `isAdmin()` required; sets status `REJECTED`. |

---

### 2.3 Academic Curriculum & Schedules Module

| Previous REST Endpoint | Firebase Modern Equivalent | Execution Model | Security & Authorization |
|:---|:---|:---|:---|
| `GET /api/v1/courses` | `collection('courses').get()` | Client SDK | Authenticated users (`isAuthenticated()`). |
| `GET /api/v1/courses/my-courses` | `collection('courses').where('year', '==', u.year).where('semester', '==', u.semester).get()` | Client SDK | Filtered by student's active batch. |
| `POST /api/v1/courses` | `collection('courses').add(courseData)` | Client SDK | `isAdmin()` Security Rule. |
| `PUT /api/v1/courses/:id` | `collection('courses').doc(id).update(courseData)` | Client SDK | `isAdmin()` Security Rule. |
| `DELETE /api/v1/courses/:id` | `collection('courses').doc(id).delete()` | Client SDK | `isAdmin()` Security Rule. |
| `GET /api/v1/schedule` | `collection('schedules').where('targetYear', '==', u.year).where('targetSemester', '==', u.semester).get()` | Client SDK | Authenticated users. |
| `POST /api/v1/schedule` | `collection('schedules').add(slotData)` | Client SDK | `isAdmin()` or `isCR()` (CR restricted to tomorrow's date). |
| `PUT /api/v1/schedule/:id` | `collection('schedules').doc(id).update(slotData)` | Client SDK | `isAdmin()` or `isCR()`. |
| `DELETE /api/v1/schedule/:id` | `collection('schedules').doc(id).delete()` | Client SDK | `isAdmin()` or `isCR()`. |
| `GET /api/v1/exams` | `collection('exams').where('year', '==', u.year).where('semester', '==', u.semester).get()` | Client SDK | Authenticated users. |
| `POST /api/v1/exams` | `collection('exams').add(examData)` | Client SDK | `isAdmin()` or `isTeacher()`. |

---

### 2.4 Attendance Terminal & Verification Module

| Previous REST Endpoint | Firebase Modern Equivalent | Execution Model | Security & Authorization |
|:---|:---|:---|:---|
| `POST /api/v1/attendance/session/start` | `collection('attendanceSessions').add({'courseId': id, 'code': code, 'isActive': true, ...})` | Client SDK | `isTeacher()` assigned to the course. |
| `POST /api/v1/attendance/session/:id/stop` | `collection('attendanceSessions').doc(id).update({'isActive': false, 'status': 'CLOSED'})` | Client SDK | `isTeacher()` owner of session. |
| `GET /api/v1/attendance/session/:id/roster` | `collection('attendance').where('sessionId', '==', id).snapshots()` | Client SDK (Real-time) | `isTeacher()` owner of session. |
| `POST /api/v1/attendance/verify` | `collection('attendance').add({'sessionId': sId, 'studentId': uid, 'status': 'PRESENT', ...})` | Client SDK | `isStudent()` enrolled in course. Unique rule on `(sessionId, studentId)`. |
| `GET /api/v1/attendance/summary` | `collection('attendance').where('studentId', '==', uid).get()` | Client SDK | `isUser(uid)`. Client aggregates course percentages. |
| `PUT /api/v1/attendance/record/:id/override` | `collection('attendance').doc(id).update({'status': newStatus, 'isManualOverride': true})` | Client SDK | `isTeacher()` or `isAdmin()`. |
| `GET /api/v1/attendance/course/:id/export` | `FirebaseFunctions.instance.httpsCallable('exportAttendanceExcel').call({'courseId': id})` | **Cloud Function (HTTP)** | `isTeacher()`, `isCR()`, or `isAdmin()`. Streams back formatted `.xlsx` base64 / binary. |

---

### 2.5 Faculty Counseling & Office Hours Module

| Previous REST Endpoint | Firebase Modern Equivalent | Execution Model | Security & Authorization |
|:---|:---|:---|:---|
| `GET /api/v1/counseling/slots` | `collection('counselingSlots').where('isBooked', '==', false).snapshots()` | Client SDK | Authenticated users. |
| `POST /api/v1/counseling/slots` | `collection('counselingSlots').add(slotData)` | Client SDK | `isTeacher()`. |
| `POST /api/v1/counseling/requests` | `collection('counselingBookings').add(bookingData)` | Client SDK | `isStudent()` with `status: 'PENDING'`. |
| `GET /api/v1/counseling/requests/my-requests` | `collection('counselingBookings').where('studentId', '==', uid).snapshots()` | Client SDK | `isUser(uid)`. |
| `POST /api/v1/counseling/requests/:id/approve` | `FirebaseFunctions.instance.httpsCallable('approveCounselingBooking').call({'bookingId': id})` | **Cloud Function** | `isTeacher()` owning slot. Executes atomic transaction locking slot & rejecting competing petitions. |
| `POST /api/v1/counseling/requests/:id/reject` | `collection('counselingBookings').doc(id).update({'status': 'REJECTED'})` | Client SDK | `isTeacher()` owning slot. |
| `DELETE /api/v1/counseling/requests/:id` | `collection('counselingBookings').doc(id).update({'status': 'CANCELLED'})` | Client SDK | `studentId == request.auth.uid`. |

---

### 2.6 Feedback & Threaded Replies Module

| Previous REST Endpoint | Firebase Modern Equivalent | Execution Model | Security & Authorization |
|:---|:---|:---|:---|
| `POST /api/v1/feedback` | `collection('feedback').add(feedbackPayload)` | Client SDK | `isStudent()`. If anonymous, `studentId` is set to `"ANONYMOUS"`. |
| `GET /api/v1/feedback/my-submissions` | `collection('feedback').where('studentId', '==', uid).snapshots()` | Client SDK | `isUser(uid)`. |
| `GET /api/v1/feedback/teacher` | `collection('feedback').where('teacherId', '==', uid).snapshots()` | Client SDK | `isTeacher()`. Anonymity preserved in stored document. |
| `POST /api/v1/feedback/:id/reply` | `collection('feedback').doc(id).update({'replies': FieldValue.arrayUnion([replyDoc])})` | Client SDK | `teacherId == request.auth.uid` or `isAdmin()`. |
| `GET /api/v1/admin/feedback/audit` | `collection('feedback').orderBy('createdAt', descending: true).get()` | Client SDK | `isAdmin()` Security Rule. |

---

### 2.7 Semester Progression Module

| Previous REST Endpoint | Firebase Modern Equivalent | Execution Model | Security & Authorization |
|:---|:---|:---|:---|
| `GET /api/v1/semester/status` | `collection('semesterUpgradeRequests').where('studentId', '==', uid).orderBy('createdAt', descending: true).limit(1).snapshots()` | Client SDK | `isUser(uid)`. |
| `POST /api/v1/semester/request` | `collection('semesterUpgradeRequests').add(upgradePayload)` | Client SDK | `isStudent()` with `status: 'PENDING'`. |

---

### 2.8 Notifications Module

| Previous REST Endpoint | Firebase Modern Equivalent | Execution Model | Security & Authorization |
|:---|:---|:---|:---|
| `GET /api/v1/notifications` | `collection('notifications').where('userId', '==', uid).orderBy('createdAt', descending: true).limit(50).snapshots()` | Client SDK (Real-time) | `isUser(uid)`. |
| `PUT /api/v1/notifications/:id/read` | `collection('notifications').doc(id).update({'isRead': true})` | Client SDK | `isUser(resource.data.userId)`. |
| `PUT /api/v1/notifications/read-all` | Batch write iterating over unread documents | Client SDK | `isUser(resource.data.userId)`. |
