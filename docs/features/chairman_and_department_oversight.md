# Chairman Role, Dual-Mode Dashboard, Student Session & Teacher Monitoring

Implementation reference for Epic F08. Role permissions are summarised in [role_matrices.md](role_matrices.md).

---

## 1. Roles

| Role | Lands on | Dashboard switcher |
| :--- | :--- | :--- |
| `CHAIRMAN` | Faculty dashboard (`/dashboard/teacher`) with faculty tabs | **Faculty View / Department Admin** |
| `TEACHER` with `isAdminDelegate: true` | Faculty dashboard | **Faculty View / Signup Committee** |
| `TEACHER` | Faculty dashboard | none |
| `ADMIN` | Admin Console (`/dashboard/admin`) | none |

### How the role is created
- **New account:** Admin or Chairman → User Directory → Create user → role *Chairman of the Department* (`createAdminUser`). The Chairman cannot create `ADMIN` accounts.
- **Promote an existing teacher:** system Admin → User Directory → ⋮ → *Change role* (`updateUserRole`). This updates Firebase Auth custom claims and the Firestore profile. The user gets a notification and must **sign out and sign in again**.
- **Signup committee:** Admin or Chairman → User Directory → ⋮ on a teacher → *Grant signup committee access* (`setAdminDelegate`).

### Where the checks live
| Layer | Location |
| :--- | :--- |
| Flutter | `UserRole.hasTeacherAccess` / `hasAdminAccess` / `isStudentSide` and `User.canSwitchToAdminView` (`mobile/lib/core/constants/role_constants.dart`, `features/auth/domain/entities/user.dart`) |
| Router | `AppRouter._canAccessAdminRoute`. Chairman: all `/admin/*`. Delegates: only `/admin/signup-requests`. |
| Cloud Functions | `functions/src/roles.ts`: `isAdminRole` (ADMIN, CHAIRMAN), `isSystemAdminRole` (ADMIN), `isTeacherRole` (TEACHER, CHAIRMAN), `canReviewSignupRequest`, `canAssignRole` |
| Firestore rules | `isSystemAdmin()`, `isChairman()`, `isAdmin()` (= either), `isTeacher()`, `isAdminDelegate()` |

---

## 2. Student Session

- The signup form shows a required **Academic Session** dropdown for Student and CR. It lists the last 8 sessions, newest first.
- Approval dialog (`SignupApprovalDialog`, shared by the Requests screen, the pending-signups card, and the Chairman's Admin View):
  - shows the applicant's session **read-only**. It is saved exactly as chosen at signup; the server ignores any session sent with an approval;
  - the approver picks one **Semester** from the 8 levels (Year 1 · Semester 1 … Year 4 · Semester 2). Nothing is pre-selected, and *Approve & Provision* stays disabled until one is chosen;
  - a wrong session is corrected **after** approval: Admin or Chairman → User Directory → ⋮ → *Set academic session* (available for every student).
  - Nothing is guessed from the session: students may take longer than the normal duration, and session jams shift whole batches.
- `approveSignupRequest` saves `session` to `/users/{uid}`.
- Existing students show "Session not set". Admin or Chairman can set it via User Directory → ⋮ → *Set academic session*.

### Filters & ordering on admin lists (Admin, Chairman, signup committee)
Each list keeps its scrolling chips (role tabs, status tabs) and gets a **dropdown filter** below them (shared widget `AdminFilterDropdown`). Ordering rules live in `RequestOrdering` (`features/admin/presentation/utils/request_ordering.dart`) and are used by both the full screens and the dashboard cards.

| Screen | Scrolling chips (kept) | Dropdown filter(s) | Ordering |
| :--- | :--- | :--- | :--- |
| User Directory | All Roles / Faculty / Students / CRs / Admins | Semester (Students & CRs tabs): All, 1.1 … 4.2 | Alphabetical |
| Signup Petitions | Pending / Approved / Rejected / All | Session: All requests, Session 2019-20 …, Students – session not set, Teachers (+ search box) | Sessions oldest first, then no-session students, then teachers. Newest request first within a group. |
| Semester Petitions | Pending / Approved / Rejected / All | Requested semester: All, 1.1 … 4.2 (+ search box) | By requested semester, oldest request first. Backwards requests are flagged "Lower than current semester". |
| Course Catalog | n/a | Semester, Type (Theory / Lab) | By semester, then course code |
| Teacher Assignments | n/a | Teacher (+ existing search) | n/a |
| Attendance Logs | n/a | Teacher, Status (Active / Completed) | Newest first |
| Course Feedback | n/a | Teacher, Rating (1★–5★) | n/a |
| Notice & Alerts | Notice type tabs | Audience (Everyone / Students / Faculty / CRs) | n/a |
| Teacher Monitoring | n/a | Teacher, Semester | Alphabetical |

---

## 3. Dual-Mode Dashboard

`DashboardModeSelector` (`features/dashboard/presentation/widgets/dashboard_mode_selector.dart`) sits directly under the welcome header. The selected mode is remembered per user on the device.

| Mode | Content |
| :--- | :--- |
| Faculty View | Existing faculty dashboard: metrics, today's classes, quick actions |
| Department Admin (Chairman) | Overview grid, pending signups (with sessions), Teacher Class Delivery summary, Admin quick actions |
| Signup Committee (delegate) | Pending Student / CR signups with approve / reject |

---

## 4. Teacher Course Monitoring

Screen: **Admin quick actions → Teacher Monitoring** (`/admin/teacher-monitoring`). Chairman and Admin only.

Data comes from `attendanceSessions`, `courses`, `courseAssignments`, `schedules` (+ legacy `scheduleSlots`), and `users`. Aggregation lives in `TeacherMonitoringCalculator` (pure Dart, unit-tested).

| Metric | Rule |
| :--- | :--- |
| Classes conducted | Distinct days with ≥ 1 attendance session for the teacher + course. Same-day re-launches count once. |
| Target / progress | `course.targetClassCount`, set per course by the Admin / Chairman in Course Catalog. There is no default: courses without a target show "Target not set" and no progress bar. |
| Avg. student turnout | Mean of each class day's highest `totalPresentCount`, divided by the active Student + CR count in the course's Year/Semester |
| Held vs scheduled (estimate) | Only when a **semester start date** is set on the screen. Expected = weekly recurring routine slots (not extra / one-off) that fell between that date and today. Missed = expected − conducted. |
| Session history | Per-day list with present count and re-launch count |

When a start date is set, classes before it are excluded, so the view becomes "this semester". The date is stored on the device.

**Known limits:** there is no holiday calendar, so the missed-class estimate counts public holidays as missed. Two genuine classes of the same course on one day count as one.

---

## 5. CR Class List & CR Role Transfer

- **My Class** (dashboard card under *Active Semester*, route `/my-class`, Students **and** CRs): everyone with the **same year, semester and session**, including "You", each with a **CR / Student** badge, plus search. The user's session must be set; otherwise the screen explains how to get it set.
  - **Classmates** tab: the list. Only the CR sees *Make CR*.
  - **CR Requests** tab (count badge): a student sees CR offers made to them with Accept / Decline. The CR sees the status of the offer they sent (waiting / declined / accepted) with *Cancel Request*. The dashboard card highlights a pending offer and opens this tab directly.
- **Transfer:** the CR taps *Make CR* on a classmate. This creates `crTransfers/{crUid}` with status `PENDING` and notifies the classmate. The CR stays CR and can cancel while it is pending. Only one transfer per CR at a time.
- **Accept / Decline:** the classmate sees the offer in *My Class → CR Requests* (their dashboard My Class card is highlighted with a *CR offer* tag).
  - **Accept** runs one Firestore batch: the transfer becomes `ACCEPTED`, the classmate becomes `CR`, the old CR becomes `STUDENT`. Both apps reload the profile and switch dashboards automatically.
  - **Decline** leaves everything unchanged and notifies the CR.
- **No admin / chairman step, no Cloud Functions.** Security rules (`crHandoverTo`, `crHandoverFrom`, `match /crTransfers`) only allow those role changes inside the accept batch, only for a pending transfer, only between same-class students, and only while the sender is still CR.
- **Rule tests:** `firestore-rules-tests/` (19 cases, run with `npm install && npm test` in that folder; uses the local emulator, never live data).
- **Limitation:** accounts that carry a `role` custom claim in their login token (only accounts provisioned by the Cloud Functions, which are not deployed) would keep the old claim until a server updates it. Accounts created by the app and scripts use the Firestore role, so this does not affect them.

## 6. Class Scheduling: Central Weekly Routine + One-day Changes

**Central weekly routine** (`schedules`): one routine per semester (Year 1 · Semester 1 … Year 4 · Semester 2). Every week repeats it. It is set by Admin / Chairman on **Admin → Class Routine** (`/admin/routine`, `AdminRoutineScreen`): pick the semester, see Sunday–Thursday (weekend days appear when used), and add / edit / remove classes (course, teacher, day, time, room). Saving is blocked on a room, teacher or batch clash with any semester's routine that weekday. Teachers can still adjust the routine for their own courses. **CRs can never edit or delete it.**

**One-day changes** (`classChanges`): made from one form, *Change a Class*. They never change the routine.

| Change | Who | Days | What students see |
| :--- | :--- | :--- | :--- |
| **Extra class** | CR (own batch), teacher (own courses), admin | CR/admin: past 7 … next 7 days. Teacher: today … next 7 | A new class that day, tagged "Extra class" |
| **Cancel** (planned) | same | same | Struck through, "Cancelled: reason" |
| **Move** (day / time / room) | same | same | New time / room, "Moved from 09:00 AM, Room 302" |
| **Not taken** (class was due but did not happen) | CR (own batch), admin. **Not teachers.** | Today and the past 7 days only | Struck through, "Not taken: reason" |

- **Form:** pick the type, then the day. CRs get an *Earlier* button for the past week; *Not taken* shows Today and the past 7 days. For an extra class pick the course (teacher fills in automatically). For cancel / move / not taken, pick one of that day's classes (moved and extra classes can also be reported as not taken).
- **Clash check (no Cloud Functions needed):** checks that day's effective schedule for all batches and blocks saving if the **room**, **teacher** or **batch** is busy, saying why.
- **Where it shows:** dashboards (Classes card), the *Class Changes* card (next 7 days, then "Past 7 days"), the WhatsApp routine message, and **Teacher Monitoring**.
- **Teacher Monitoring:** a cancelled class is not expected (not counted against the teacher), an extra class is expected, and a **not-taken class stays expected and is counted** ("2 not taken (reported by CR)" on the course, a "Not taken" total at the top, and in the teacher's subtitle). Each course has a **Class log**: held classes (from attendance) and every change, with date, reason and who reported it.
- **Undo:** whoever made a change (or an admin) can undo it. A teacher cannot remove a CR's not-taken report. Changes are never edited in place.
- **Rules:** `match /classChanges` (types EXTRA / CANCEL / MOVE / NOT_TAKEN, `dateTs` window −7 … +7 days, NOT_TAKEN only up to today and never by teachers, teachers only today onward, creator-only undo) and the tightened `match /schedules`. Emulator tests: `firestore-rules-tests/class_changes.test.js` (17 cases).
- **Fixed along the way:** the old CR dashboard form saved "tomorrow's" class without a date, so it became a permanent weekly class. Dashboards also ignored dates, so old one-off classes showed every week.

## 7. Exams

**Who can schedule** (enforced by `match /exams` in the security rules, mirrored in `ExamPermissions`):

| Who | Can schedule / edit / cancel | Delete |
| :--- | :--- | :--- |
| Admin / Chairman | Any exam | Yes |
| Teacher | Their own courses (all types, incl. Final) | No |
| CR | Their own semester: Mid-Term, Class Test, Quiz, Lab Exam (**not Final**) | No |
| Student | View only | No |

- **Form** (`ExamFormDialog`, bottom sheet): type, course (teachers see only their courses; the semester follows the course; the CR is fixed to their semester), title, date ("in 3 days"), **From / To** time, room with suggestions from the routine and other exams, invigilator, instructions.
- **Clash check before saving** (`ExamClashes`): blocked if the room has another exam or another semester's class, the semester already has an exam then, or the invigilator is teaching / on duty. The semester's own class at that time is not a clash: the class shows "Exam in this slot".
- **Cancel instead of delete:** `status: CANCELLED` + reason; the exam stays listed, struck through. Editing a cancelled exam reschedules it. Changing the date / start records `previousDate` / `previousStartTime` ("Postponed from …").
- **Students are told:** after saving or cancelling, an `EXAM_UPDATE` notification goes to every student of the semester (rules: teachers / admins to anyone, a CR only to their own semester). Tapping it opens the Schedule. The details sheet also has **Share on WhatsApp**.
- **Where it shows:** Schedule → Exam Schedule (Upcoming / Past, calm exam cards), dashboard Exams tab, and the "Upcoming exams" count, which now skips past and cancelled exams.
- **Rules tests:** `firestore-rules-tests/exams.test.js` (11 cases).

## 8. Attendance

**Teacher** (Attendance tab, or **Start Attendance** on a class, which opens that exact course and class):
- Choose the course (all courses where you are the course teacher or assigned). If no class is scheduled today, it is a holiday, or today's class was cancelled, the app asks before starting an extra / makeup session. If a session is already open for the course, a **Resume** banner appears instead of starting a new one.
- **Code** mode: a 6-character code that **changes every 20 seconds** (the previous one is still accepted briefly). Keep the screen open; if the screen stops rotating, codes stop working after ~45 s. **+5 min** extends.
- **By hand** mode: no code; call the roll.
- The roster shows the course's semester plus retake students, updates **live** as students mark themselves (the present count on the session stays in sync), and each tap (**P / A**) **saves automatically**. A teacher's pending tap is never overwritten by a live update; saving writes only the students the teacher changed.
- **Close & Save** records everyone not marked as **Absent**, saves the present count and closes.
- **Recent Classes** (last 7 days): reopen a class to correct it; edits are logged (`editLog`).
- **Course report**: every student's present / absent per class date (P / A), totals and %, students below 75% first. **Export Excel** (department register layout: university, course, teacher, Sl / Roll / Name, one column per date) shares or downloads an `.xlsx`; **Copy CSV** for pasting.
- Late marking was removed: every mark is Present or Absent (older Late records still count as attended).

**Student** (Attendance tab): pick the class under **Open now** (auto-picked when only one), type the code → "You are marked present for …". Per course: attended ÷ held, the days missed, and advice ("You can miss 2 more classes" / "Attend the next 4 classes in a row to reach 75%"). A day counts as **held** only if the class actually ran (a session with at least one student present), the same rule Teacher Monitoring uses.

**Retakes** (Profile → Add Retake): a student can add a course from an **earlier** semester only. Retake classes, changes and exams then show on their dashboard and schedule, they can mark attendance there, and they appear on that course's roster and report. Their retake percentage counts only classes **from the day they enrolled**. Students can remove only their own retakes (with a confirmation); admin-made enrollments cannot be removed by students.

**Data / rules** (`ClassAttendanceService`, no Cloud Functions):
- `attendanceSessions/{id}`: no code; `mode` CODE / MANUAL, `slotId`, `targetYear/Semester`. Only the course teacher creates; only the session's teacher updates.
- `attendanceSessions/{id}/private/code`: `code`, `prevCode`, `issuedAt`; readable / writable only by the session's teacher (and admins).
- `attendance/{sessionId}_{studentId}`: self-marks only by the student, for their own semester or a retake enrollment, with the current / previous code while it is fresh, status PRESENT only; `markedBy` SELF / TEACHER. Teacher marks (PRESENT / ABSENT) only for their own course. Students never edit or delete; only admins delete.
- `enrollments/{courseId}_{studentId}` with `type: RETAKE`: created / deleted by the student only for an earlier-semester course; otherwise admin-only.
- Rules tests: `firestore-rules-tests/attendance.test.js`.

## 9. Holidays

- **Admin / Chairman → Holidays** marks department holidays (one per date with a reason). Everyone can read them.
- On a holiday, the weekly routine is off everywhere (dashboards, Schedule tab, clash checks, exam clash check, Teacher Monitoring's expected classes). **Extra classes** added for that day still show and still count.
- The **Change a Class** form shows the holiday and allows only **Extra** on that date (no cancel / move / not taken for classes that are not happening).
- Rules: `match /holidays` (read: signed in; write: admin / chairman). Tests in `firestore-rules-tests/class_changes.test.js`.

## 10. Schedule notices

- When the CR or a teacher adds, cancels or moves a class for a day, the semester's students get an in-app **SCHEDULE_UPDATE** notification (sent in the background so saving stays fast). A CR can only notify their own semester. "Not taken" reports are not announced.

## 11. Signup & Approval (free plan, no Cloud Functions)

1. **Signup:** the person fills in the form **with a password**. Their login is created right away and a request is filed under their uid (`signupRequests/{uid}`, `status: PENDING`). They are signed out.
2. **Before approval:** signing in shows "Your account is waiting for approval by a teacher or the admin." After a rejection: "Your signup was not approved: <reason>".
3. **Who approves:**
   - **Student / CR signups:** **any teacher**, the Chairman or the Admin. The reviewer picks the semester; the session comes from the signup.
   - **Teacher signups:** Admin / Chairman only.
   - Approving creates the account and marks the request approved in **one batch**; the rules check that the account matches the request exactly (role, email, chosen semester, session, active). A teacher can never overwrite an existing account or edit a request's details.
4. **Semester requests:** any teacher, the Chairman or the Admin approves / rejects. Approving moves the student to exactly the requested semester in the same batch.
5. Every decision records `reviewedBy`.
6. **Where:** every teacher's dashboard has the **Faculty / Admin** switch; the teacher's Admin view lists pending Student / CR signups and semester requests. Teachers can open only those two admin pages. The old "signup committee" option is gone.
7. Old requests from before this change (no login attached) can't be approved; the app asks the person to sign up again.
8. Rules tests: `firestore-rules-tests/signup_approval.test.js`.

## 12. Deployment Checklist

1. `cd functions && npm run build && firebase deploy --only functions` (new: `updateUserRole`, `setAdminDelegate`; changed: approval, provisioning, all role checks).
2. `firebase deploy --only firestore:rules`. Signup requests now **require** `session` for Student/CR, so older app builds can no longer submit student signups.
3. Ship the mobile app update.
4. Promote the Chairman account (Admin → User Directory → Change role → Chairman). They must sign in again.
