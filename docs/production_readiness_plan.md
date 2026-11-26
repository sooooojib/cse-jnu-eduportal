# JnU EduPortal: Production Readiness Plan (3 Stages)

This plan turns the results of three audits (security, data consistency, production readiness) into three stages of work. Each stage stands on its own: give it to the developer as one task, finish it, test it, then move on.

**Current state:** all features work. 480 of 480 app tests and 74 of 74 security-rule tests pass, with 0 analyzer errors. **The app is not ready for launch yet**: the items below must be fixed first.

**How to use this document**
- Each item has an ID (S1-…, S2-…, S3-…). You can ask for single items ("do S1-04 and S1-07") or a whole stage ("do Stage 1").
- **Done when** describes how to check the item is finished.
- Items marked **👤 You** need an action or decision from you; the developer can't do them alone.
- Security-rule changes are tested on the local emulator first, then deployed to the live project (`sajib-73b14`).

**Before Stage 1: actions only you can take**

| # | Action | Why |
|---|---|---|
| 👤 A | **Change the passwords** of the admin account and all demo accounts now. | Several scripts committed to GitHub contain real passwords (`scripts/setup_accounts.js`, `scripts/create_admin_user.js`, `scripts/create_student_and_cr.js`, `scripts/create_demo_teacher.js`). |
| 👤 B | **Decide: free (Spark) plan or Blaze?** | Blaze (pay-as-you-go, very cheap at this size, needs a billing account) unlocks push notifications to phones, server-side role changes and deleting logins. On the free plan, Stage 2 includes extra work to stay under the daily read limit. |
| 👤 C | **Decide: restrict signup to university emails?** (for example `@…jnu.ac.bd` only) | Stops strangers from signing up at all. |
| 👤 D | **Provide a privacy policy page**: a website, or a Google Doc / GitHub page. | Google Play and the App Store require a link. |

---

## Stage 1: Security (close every loophole)

**Goal:** only approved, active members can see or change data, and each role can do only what it should.
**Size:** about 1 day. **Result:** security rules redeployed, with new emulator tests for every item.

### S1-01 · Members-only data (critical)
- **Problem:** signing up creates a login before approval. Most data only requires "signed in", so a stranger who signs up (never approved) can read **every user's email, phone and roll, everyone's attendance, and all counseling bookings with reasons**. This was confirmed on the emulator.
- **Fix:** add an `isMember()` rule helper (users record exists and `isActive != false`) and use it instead of "signed in" for all reads and writes. Also:
  - **Users:** classmates and rosters see only public fields (name, roll, role, year, semester); email and phone are visible only to the person and to staff.
  - **Attendance records:** visible only to the student themself, the course's teacher and admins.
  - **Counseling bookings:** visible only to the student, the teacher and admins.
- **Where:** `firestore.rules` (users ~L157, attendance ~L449, counselingBookings ~L471, courses / schedules / exams / classChanges / enrollments / holidays reads). Also check which app screens read other users' email or phone, and switch them to the public fields.
- **Done when:** an emulator test proves that a pending signup login can read nothing except its own request, and that a student can't read another student's attendance or phone.
- **✅ Done.** Deployed, with 7 new emulator tests (`firestore-rules-tests/members_only.test.js`). Two limitations remain:
  - Firestore can't hide single fields, so students still see their **own batch's** full records (needed for My Class and class notices). Fully hiding classmates' email requires moving contact details into a separate private record, a possible follow-up.
  - Attendance is readable by any teacher, not only the course's teacher, because the live roster query can't be checked per course.

### S1-02 · Deactivated accounts lose all powers
- **Problem:** "deactivated" is checked only at sign-in, so a deactivated teacher who is still signed in can keep creating exams and marking attendance.
- **Fix:** make every role check (`isRole`) and `isMember()` also require `isActive != false` in the users record.
- **Done when:** an emulator test shows a deactivated teacher can't create an exam or mark attendance.
- **✅ Done.** Every role check now requires an active account, and so does every "own record" action: editing your profile, cancelling a booking, editing a semester request, and the CR hand-over. Deployed, with 5 new emulator tests (`firestore-rules-tests/deactivated.test.js`) covering a deactivated teacher, CR, student and Chairman. A deactivated person can still open their own profile, so the app can show "Your account has been deactivated".

### S1-03 · Role comes from the user record, not the old login token
- **Problem:** `isRole` trusts a role stored in the login token first. Accounts given a token role by old scripts keep those powers even after being demoted in the database.
- **Fix:** read the role from the users record only (or require both to agree).
- **Done when:** an emulator test shows a token saying TEACHER with a record saying STUDENT gets student permissions only.
- **✅ Done.** In the rules, roles come from the users record only. In the app, `UserModel.fromFirestore` also uses the record's role; the token role is only a fallback for a record with no role. Deployed, with 3 new emulator tests (`firestore-rules-tests/role_source.test.js`), and the two app tests that expected the token role to win were updated. File storage still uses token roles; that's fixed in S1-11.

### S1-04 · CRs can't file false "not taken" or change other batches' classes
- **Problem:** a CR can create a "not taken" report, a cancel or a move for **any course and any teacher**. False reports appear in the Chairman's Teacher Monitoring.
- **Fix:** for a CR, the course's year and semester must equal the CR's own. The change's `teacherId` must equal the course's teacher. For cancel, move and not taken, the original routine slot must belong to that course.
- **Where:** `firestore.rules` `classChanges` (`validChange`, `crOwnBatch`, ~L357-383).
- **Done when:** emulator tests reject a 3-1 CR reporting "not taken" for a 1-1 course or naming another teacher.
- **✅ Done.** Every one-day change (by a CR, teacher or admin) must match a real course and its semester, and name **that course's current teacher**. Cancel, move and not taken must point at a routine slot of the same course, or at an extra class of it. The change form now takes the teacher from the course, so outdated routine slots don't block real reports. Deployed, with 3 new emulator tests in `firestore-rules-tests/class_changes.test.js` and 1 app test. This also covers the class-change part of S1-12.

### S1-05 · Teachers can't redirect a session to someone else's course
- **Problem:** a teacher can edit their own attendance session's course, then mark attendance for another teacher's course.
- **Fix:** on session update, freeze `courseId`, `targetYear`, `targetSemester`, `sessionDate` and `mode`.
- **Where:** `firestore.rules` `attendanceSessions` update (~L417-420).
- **Done when:** an emulator test rejects changing a session's course.
- **✅ Done.** After creation, a session's course, semester, date, mode, teacher and code can't be changed; it can only be extended, counted and closed. A new session must also match its course's real semester. Deployed, with 2 new emulator tests in `firestore-rules-tests/attendance.test.js`. No app changes were needed: the app never changes those fields.

### S1-06 · Feedback can't be tampered with
- **Problems:**
  - a teacher can rewrite feedback about themselves (1★ → 5★);
  - a student can change which teacher their feedback is about;
  - an anonymous feedback's identity record is written separately and can fail, after which another user can claim that feedback.
- **Fix:**
  - **Teachers:** may change only `replies`, `status`, `readAt` and `updatedAt`.
  - **Students:** can't change `teacherId` or `courseId`.
  - **Anonymous feedback:** write the feedback and its identity record in **one batch**.
- **Where:** `firestore.rules` feedback update (~L494-500), feedbackIdentities (~L530); `feedback_repository_impl.dart` (~L168-178).
- **Done when:** emulator tests reject a teacher changing the rating and a student changing the teacher.
- **✅ Done.**
  - **Teacher** (the feedback is about them): may change only replies, status and read-time.
  - **Author:** may change only rating (1–5), comments, attachments and anonymity; never the teacher or course, and never sets someone else as the author.
  - **Admins:** can still moderate.
  - **Anonymous feedback:** must be created **together** with its hidden identity record, in one batch (the app now does this). An identity record can't be added later, so nobody can claim existing feedback.
  - **Tests:** deployed, with 7 new emulator tests (`firestore-rules-tests/feedback.test.js`).

### S1-07 · Semester requests can't skip semesters
- **Problem:** a student can claim a fake current semester (for example "I'm in 3-2") and request 4-1. If approved, a 1-1 student jumps to 4-1.
- **Fix:**
  - **Rules:** the request's current year and semester must match the student's real record, and the requested level must be the next semester (one step ahead). Approval also re-checks this against the real record.
  - **App:** the request form shows the real current semester; it can't be typed.
- **Where:** `firestore.rules` semesterUpgradeRequests create (~L585), `approvedSemesterChange` (~L150-161) and update (~L595-610); the student semester request screen.
- **Done when:** emulator tests reject a fake current semester and a jump of more than one step.

### S1-08 · Approved accounts contain only the allowed fields
- **Problem:** when approving a signup, a teacher can add extra fields such as `isCR: true`, which gives CR powers.
- **Fix:** the new account may contain only an exact list of fields; `isCR`, `assignedCourseIds`, `isAdminDelegate` and `lastSemesterRequestId` aren't allowed.
- **Where:** `firestore.rules` `approvedApplicant()` (~L136-149).
- **Done when:** an emulator test rejects approval with `isCR: true`.
- **✅ Done.** When a teacher approves a signup, the new account may contain only the 16 normal fields. The course list and FCM tokens must be empty, and the name and roll must match the signup exactly. So `isCR`, course access, admin flags or an edited name / roll are refused. Deployed, with a new emulator test (5 attempts) in `firestore-rules-tests/signup_approval.test.js`. No app change was needed. Admin / Chairman approvals keep their full account-creation rights.

### S1-09 · Notifications can't be faked
- **Problem:** any teacher can send any SEMESTER, SCHEDULE_UPDATE or ANNOUNCEMENT notification with any text to any user, with no sender recorded (for example "Fee due, send money").
- **Fix:** every notification must carry `senderId` equal to the sender. A SEMESTER notification needs a matching decided request; schedule notices go only to that course's students.
- **Where:** `firestore.rules` notifications create (~L568-570); the app code that sends notifications.
- **Done when:** an emulator test rejects a teacher's notification without a sender, or with an unrelated SEMESTER notice.
- **✅ Done.** A non-admin notification must have `senderId` equal to the sender and must point at the real thing it is about:
  - a class-change notice needs a class change made by the sender, and goes only to that change's semester;
  - an exam notice needs a real exam, goes only to that exam's semester, and the sender must be that semester's CR, the course teacher or the exam's creator;
  - a semester notice needs a decided request for that student, reviewed by the sender.

  Free-text teacher notices (announcement, routine, attendance) are gone; only admins can send those. The app now sends the exam id, and the semester-approval notice sends the request id and the sender. Deployed, with a new `firestore-rules-tests/notifications.test.js` plus updated exam and class-change tests.

### S1-10 · Only real members can book counseling or post feedback
- **Problem:** unapproved logins can book counseling and post feedback (for example a 1★ about a teacher).
- **Fix:**
  - **Both:** require `isMember()`.
  - **Feedback:** also require that the student is in the course's semester or enrolled in it (retake).
- **Where:** `firestore.rules` counselingBookings create (~L472) and feedback create (~L488).
- **Done when:** emulator tests reject a pending login and a student of another semester.
- **✅ Done.**
  - **Counseling:** by decision, an approved student (or CR) may book **any** teacher, with no semester limit. The booking must point at a real slot and name that slot's teacher. Pending logins and teachers can't book.
  - **Feedback:** only approved students/CRs can post it, and it must be about a real teacher or chairman. Course feedback must name the course's own teacher and come from that course's semester or a retake student (enrollment `courseId_uid`). General feedback about a teacher, with no course, is still allowed.

  Deployed, with a new `firestore-rules-tests/counseling_feedback_access.test.js` (7 tests). No app change was needed.

### S1-11 · File storage locked down (and fixed)
- **Problems:**
  - **Counseling and feedback files:** any signed-in user can upload into another person's counseling folder and read all counseling and feedback files.
  - **Notice attachments (bug):** teachers and admins **can't** upload them, because storage checks a login-token role that nobody sets.
- **Fix:**
  - **Counseling files:** a single rule that checks the booking record, so only the student and that teacher can read or write.
  - **Roles:** read them from the users record.
  - **Uploads:** add size and type limits.
- **Where:** `storage.rules`.
- **Done when:** an outsider can't read or write counseling files, and an admin can upload a notice attachment.
- **✅ Rules done and tested. ⚠️ Not deployed: Firebase Storage has never been set up on `sajib-73b14`**, so today no upload reaches the cloud and the app keeps local file paths. Setting up Storage on a new project needs the Blaze (pay-as-you-go) plan; it has a free monthly allowance. After setting it up, deploy with `npx firebase-tools deploy --only storage --project sajib-73b14` and accept the cross-service (Firestore) permission prompt.
  - **Roles and accounts:** read from the Firestore users record. Pending or deactivated logins can do nothing.
  - **Notices:** the admin or chairman uploads; members read.
  - **Profile photos:** your own folder only (or an admin); images up to 5 MB.
  - **Counseling files:** only that booking's student and teacher (and admins). The old "any folder named after you" rule is gone.
  - **Student feedback files:** only the uploader or an admin can read them by path, so other students and teachers can't list or read them. The teacher still sees them through the saved link.
  - **Reply files:** only the teacher the feedback is about can upload.
  - **Uploads:** images, PDF, TXT, DOC and DOCX only; 10 MB limit (5 MB for photos); `uploadedBy` must be the uploader. Everything else is closed.
  - **Tests:** new `firestore-rules-tests/storage.test.js` (7 tests). `npm test` now runs the Firestore and Storage emulators together.
  - **For now (free plan, no card):** file uploads are switched off with `AppFeatures.fileUploads = false` (`mobile/lib/core/config/app_features.dart`).
    - **Hidden:** feedback and reply "Add File", the notice photo / camera / file choices, and profile-photo upload.
    - **Still works:** notices can attach a pasted link (for example Google Drive), and an existing profile photo can be removed.
    - **Later options:** small photos stored in Firestore, or turning on Storage and deploying these rules; then set the flag to `true`.

### S1-12 · Exams and extra classes match the course's semester
- **Problem:** a teacher can create an exam (or an extra class) for their course under the wrong semester.
- **Fix:** the exam's or change's year and semester must equal the course's.
- **Where:** `firestore.rules` exams (~L395-410), classChanges EXTRA.
- **✅ Done.** Every exam (created or edited, by anyone, admins included) must belong to a real course and use that course's year and semester. Extra classes and other class changes already had this check from S1-04. The exam form now always saves the chosen course's year and semester, so switching the dropdowns can't cause a mismatch. Deployed, with a new case in `firestore-rules-tests/exams.test.js`.

### S1-13 · Email verification at signup (with 👤 C)
- **Problem:** anyone can sign up using a real student's roll and email, and a teacher might approve it.
- **Fix:**
  - **App:** send a verification email at signup. The teacher's request sheet shows "Email verified ✓ / not verified", and approval is allowed only after verification.
  - **Rules:** require `email_verified` for the account to be created.
  - **If 👤 C is yes:** also accept only the university email domain.
- **Where:** `auth_remote_datasource.dart` (signup), `signup_request_screen.dart`, `teacher_requests_view.dart`, `firestore.rules` users create / signupRequests.

### S1-14 · Missing database index (semester status is broken now)
- **Problem:** the student's semester request history needs a database index that doesn't exist, so it fails with "requires an index".
- **Fix:** add the index `semesterUpgradeRequests: studentId ASC, createdAt DESC` to `firestore.indexes.json` and deploy it. Also add error handling in `semester_repository_impl.dart`.
- **Done when:** the semester card and request history load on the phone.
- **✅ Done.** The index `semesterUpgradeRequests (studentId ↑, createdAt ↓)` was added to `firestore.indexes.json` and deployed. `semester_repository_impl.dart` loads both the semester card and the request history through one `_myRequests()` helper. If the index is ever missing or still building, it falls back to an unsorted query and sorts on the phone, so the card can't break with "requires an index" again. All app tests pass. Still to check: the screen on a real phone (none was connected).

### S1-15 · "Delete my account" (store requirement)
- **Problem:** Google Play requires apps with sign-up to let users delete their account in the app.
- **Fix:** Profile → **Delete my account**. After confirming (and re-entering the password), it removes the person's own data and their login; this works on the free plan.
- **Done when:** a test account can delete itself and can no longer sign in.
- **✅ Done (on-phone check still to do).** Profile → **Delete my account** (both the profile screen and the profile pop-up).
  - **How it works:** the student re-enters their password. The app then deletes, in order: notifications, semester requests, counseling bookings, retake enrollments, feedback they wrote (named and anonymous, plus the hidden identity), the signup record, the profile, and finally the login.
  - **Kept:** attendance records, which are official department records. The dialog says so.
  - **CRs** are asked to hand over the role first; **staff** are told to ask the admin (their accounts are made by the department).
  - **Rules:** a student may delete only their own records; a CR (role or `isCR` flag) or staff member can't delete their own profile.
  - **Code:** `mobile/lib/features/auth/data/services/account_deletion_service.dart`, `.../profile/presentation/widgets/delete_account_button.dart`.
  - **Tests:** `firestore-rules-tests/account_deletion.test.js` (3 tests) and `mobile/test/features/profile/delete_account_button_test.dart` (3 tests). Deployed.
  - **Still to do:** for the Play listing, also give a web link or e-mail for deletion requests (Play asks for one in the Data safety form).

**Stage 1 checklist:** all items have emulator tests → full rule tests pass → app tests pass → rules and indexes deployed → checked on the phone (student, CR, teacher, chairman, admin).

#### Stage 1 checklist: results (2026-11-27)

| Step | Result |
|---|---|
| Items done | 13 of 15. **Open:** S1-07 (skipped by choice) and S1-13 (email verification). S1-11 rules are ready but not deployed: Storage isn't set up, so uploads are switched off in the app. |
| Emulator tests per item | ✅ Every done item has rule tests (S1-14 is an index, covered by an app fallback). Files: `members_only`, `deactivated`, `role_source`, `class_changes`, `attendance`, `feedback`, `signup_approval`, `notifications`, `counseling_feedback_access`, `storage`, `exams`, `account_deletion`, plus the older `cr_transfer` and `enrollments`. |
| Full rule tests | ✅ 123 / 123 pass (`cd firestore-rules-tests && npm test`, Firestore and Storage emulators). |
| App tests | ✅ 484 / 484 pass. `flutter analyze lib` shows 0 errors. |
| Rules and indexes deployed | ✅ Firestore rules live and identical to the repo (the CLI reports "already up to date"). 6 indexes deployed. Every ordered app query has its index, and there are no range or array queries needing more. ⚠️ Storage rules aren't deployed (no bucket). |
| Checked on the phone | ⏳ Not done: no phone connected. Use the list below. |

#### Phone check (tick each)

Install the latest build first (`cd mobile && flutter run --release` with the phone plugged in).

**Student**
- [ ] Routine, exams, attendance and notices load (no "permission denied").
- [ ] The semester card and request history load (S1-14).
- [ ] Classmates' profiles open; teachers' profiles open.
- [ ] Book a counseling slot with a teacher from another semester (S1-10).
- [ ] Give feedback on one of your own courses. Teacher-only feedback also works.
- [ ] Mark attendance with a live code.
- [ ] No "Add File" or photo upload buttons are visible (uploads are off).
- [ ] **Delete my account** on a spare test student: after that, the login is refused (S1-15).

**CR**
- [ ] Move, cancel or mark "not taken" one of your semester's classes. Students get the notice (S1-04, S1-09).
- [ ] Schedule a Mid-Term (Final isn't offered). Students get the notice.
- [ ] "Delete my account" says to hand over the CR role first.

**Teacher**
- [ ] Open, extend and close an attendance session for your course; use manual mode.
- [ ] Create or edit an exam for your course. Students of that semester get the notice (S1-12).
- [ ] Requests tab: approve a student signup, and approve or reject a semester request. The student gets the notice (S1-08, S1-09).
- [ ] Reply to feedback and approve a counseling booking.

**Chairman**
- [ ] Central routine and teacher monitoring load.
- [ ] Create a Final exam.
- [ ] Department Admin view works.

**Admin**
- [ ] Post a notice with a pasted link attachment.
- [ ] Users list, signup approvals and holidays work.
- [ ] Deactivate a test account; that account is then refused everywhere (S1-02).

---

## Stage 2: Data in sync and within the free-plan limits

**Goal:** every screen shows the same numbers and nothing is left in a half-changed state. The app stays inside the free daily limit (if 👤 B = free plan).
**Size:** about 1–2 days.

### S2-01 · Changing a course's teacher is done properly
- **Problems:**
  - the old teacher keeps full control (attendance, exams, class changes);
  - removing an assignment can leave the course with **no** teacher;
  - the steps aren't done together, so a half-finished change is possible.
- **Fix:** do it in **one batch**: remove the old teacher (their assignment and course list), set the new one, and update the course's `teacherId`. Clear the course's teacher only if it is the teacher being removed.
- **Where:** `admin_remote_datasource.dart` `assignCourseToTeacher` (~L545-578) and `removeCourseAssignment` (~L597-616).
- **Done when:** after reassigning, the old teacher can't start attendance for the course and the new teacher can.
- **✅ Done.** A course has **one** teacher, and assigning a teacher replaces the current one in a single batch:
  - the course's old assignments are deleted;
  - the course is removed from every old teacher's `assignedCourseIds`;
  - the new assignment is created;
  - the course's `teacherId` / `teacherName` (and coordinator) are set, and the course is added to the new teacher's list.

  Removing an assignment is also one batch, and it clears the course's teacher only if that teacher is the current one. The assign dialog warns: "Now taught by X. Assigning replaces them…". No rule change was needed. Tests: `firestore-rules-tests/course_assignment.test.js` (4: old teacher loses attendance and new teacher gains it, chairman/admin only) and `mobile/test/features/admin/course_assignment_test.dart` (5, using the new dev-only package `fake_cloud_firestore`). Courses already wrongly shared in the database stay as they are until they're reassigned once.

### S2-02 · Routine and dashboards follow the course's current teacher
- **Problems:**
  - routine slots keep the old teacher's ID and name, so Monitoring, clash checks and the schedule show the old teacher;
  - the teacher's dashboard matches classes **by name**, so two teachers with the same name see each other's classes.
- **Fix:** on reassignment, update the course's routine slots in the same batch. Match a teacher's classes by course and teacher **ID only**, never by name.
- **Where:** `admin_remote_datasource.dart`, `teacher_remote_datasource.dart` (~L238-246), `teacher_monitoring_calculator.dart` (~L95-101).
- **✅ Done.**
  - **Routine follows the teacher:** reassigning a course (same batch as S2-01) moves its weekly slots and upcoming dated classes that were held by the old teacher, or by nobody, to the new teacher (ID and name). Slots deliberately given to another teacher (for example a lab) and past classes are left alone. Removing the current teacher clears their name from those slots ("Teacher not set"). Monitoring and clash checks read the slot's teacher ID, so they now follow automatically; the calculator needed no change.
  - **Teacher dashboard:** classes match by course or teacher **ID only**; the name match is gone.
  - **Exams bug found and fixed:** the dashboard's "today" list showed every exam of the teacher's courses on every day, plus everyone's exams that day, and it read the whole `exams` collection. It now queries only that day (`examDate ==`) and keeps the teacher's own courses.
  - **Tests:** `mobile/test/features/admin/course_assignment_test.dart` (+1 routine test, plus checks in the removal test) and `mobile/test/features/teacher/teacher_dashboard_matching_test.dart` (2: same-name teachers, today's own exams). The rules batch test now includes a slot update. No rule change was needed.

### S2-03 · One rule for "class held"
- **Problem:** if the teacher's phone closes mid-session, the saved present count stays 0. Monitoring then says the class wasn't held. Students who marked see it as held, and absent students get no absence.
- **Fix:** everywhere (Monitoring, student summary, CR dashboard, course report), a class is **held if at least one student is marked present**, counted from the actual attendance records rather than the saved count. When the teacher next opens Attendance, expired sessions are closed automatically and absences recorded (see S2-09).
- **Where:** `teacher_monitoring_calculator.dart` (~L147-167), `class_attendance_service.dart` (`mySummary`, `courseReport`), `cr_remote_datasource.dart` (~L355-370).
- **Done when:** a test with a killed teacher app shows the same result on every screen.
- **✅ Done.**
  - **The count no longer depends on the teacher's phone:** a student's code mark saves their record **and** adds 1 to the session's `totalPresentCount` in one batch. The new rule `selfCountBump` allows only that one field, only +1, only once, and only together with the student's own new valid SELF mark. Students still can't read others' records, so the count is what every screen uses. "Finish" now recounts from the saved records instead of trusting the on-screen roster.
  - **One rule everywhere:** a day is held if the present count is above 0 or someone is marked present. The student summary and the CR dashboard used to count a day as held when the student had *any* record (even ABSENT from an empty class); they now use the same rule as Monitoring and the course report.
  - **Tests:** 2 new rule tests in `attendance.test.js` (the count rises with marks; it can't be raised without a valid mark, twice, by 5, or with other fields), and `mobile/test/features/attendance/class_held_rule_test.dart` (killed teacher app: student, report and Monitoring agree). Deployed.
  - **Left for S2-09:** closing expired sessions automatically and recording absences. Old sessions whose count stayed 0 before this fix still show as not held.

### S2-04 · "Change role" works
- **Problem:** User Directory → Change role always fails (it needs a server function), so the Admin can't appoint a CR or fix a wrong role.
- **Fix:** direct role change allowed by the rules: the Admin may set any role, and the Chairman any role except Admin. Appointing a CR removes CR from the previous CR of that batch, with a confirmation. (If 👤 B = Blaze, the server function can be deployed instead.)
- **Where:** `admin_remote_datasource.dart` `updateUserRole` (~L353-367), `firestore.rules` users update.
- **✅ Done (free plan, no server function).** `updateUserRole` now writes the role directly; since S1-03 the app reads roles from the users record, so no login-token claims are needed.
  - **Who:** Admin may change any role; the Chairman any role except to or from Admin. Nobody changes their own role.
  - **Groups:** staff change within Teacher, Chairman and Admin; students within Student and CR. The menu offers only those choices.
  - **Appointing a CR:** in one batch, the previous CR of that year and semester (by role or the old `isCR` flag) becomes a Student, and their pending CR hand-over is cancelled. A confirmation names them first.
  - **Rules:** new `chairmanRoleChange()` (only `role`, `isCR` removal and `updatedAt`; the groups above; not self; never Admin).
  - **Tests:** `firestore-rules-tests/role_change.test.js` (5) and `mobile/test/features/admin/role_change_test.dart` (4). Deployed.

### S2-05 · Semester promotion done right + "Promote whole batch"
- **Problems:**
  - a promoted CR stays CR, so the old batch has none and the new batch has two;
  - open CR offers get stuck;
  - the previous semester's attendance and exams vanish from the student's screens;
  - every student must request individually.
- **Fix:**
  - **On promotion:** the CR role is removed (the old batch keeps or appoints a CR), open CR offers are cancelled, and attendance history shows past semesters as well (a semester filter).
  - **New Admin / Chairman tool, "Promote batch":** select a semester and session (for example 3-1, session 2021-22) → preview the list → move everyone to the next semester in one go, keeping each CR as CR of the same batch.
- **Where:** `admin_remote_datasource.dart` (`approveSemesterUpgrade`), new admin screen, `class_attendance_service.dart` / `cr_remote_datasource.dart` (history), `firestore.rules`.
- **✅ Done (free plan).**
  - **Single promotion** (a teacher approves a request): if the student is the CR, in the same batch they become a Student (role and the old `isCR` flag), and every open CR offer from or to them is cancelled. The old batch keeps or appoints its own CR (S2-04). Rules: `approvedSemesterChange` now also allows role CR→STUDENT and removing `isCR`, never anything else. Teachers can read CR offers, and can cancel one only in the batch that moves one of the two students.
  - **"Promote Batch"** (Admin / Chairman tile → sheet): pick a semester (and optionally a session), see the list with ticks, then **Promote N students**. Everyone moves to the next semester in one go; 4-2 is refused as final. CRs stay CR, open offers stay valid because the whole batch moves, and each student gets a notice. Pending semester requests are closed: approved if they asked for exactly that semester, otherwise rejected with "Your whole batch was promoted…". Code: `admin/data/services/batch_promotion_service.dart`, `admin/presentation/widgets/promote_batch_sheet.dart`.
  - **History:** the student's Attendance and Exam Schedule have semester chips (**Now · 3-2**, 3-1, 2-2, …), so earlier semesters stay visible. Past views are read-only, and retakes show only under "Now". The CR dashboard keeps showing the current semester.
  - **Tests:** `firestore-rules-tests/semester_promotion.test.js` (5) and `mobile/test/features/admin/semester_promotion_test.dart` (6). Deployed.

### S2-06 · Retake courses everywhere
- **Problem:** retake exams show on the dashboard but not in Schedule → Exams. Monitoring's class size ignores retake students, so turnout looks too high.
- **Fix:** include retake enrolments in the Exam tab and in Monitoring's class size.
- **Where:** `curriculum_repository_impl.dart` `getExams` (~L421-436), `teacher_monitoring_calculator.dart` (~L52-58).
- **✅ Done.**
  - **Exams tab:** `getExams` adds the exams of the student's RETAKE courses when a student or CR views their own current semester; other semesters and teacher views are unchanged.
  - **Monitoring:** class size is the semester's active students plus active retake students of that course who aren't already in it. The monitoring repository reads `enrollments` (type RETAKE) and passes `retakeStudents` to the calculator.
  - **Tests:** `mobile/test/features/curriculum/retake_everywhere_test.dart` (4). No rule change.

### S2-07 · Deactivate instead of delete
- **Problem:** "Delete user" removes the profile but not the login. The person sees a wrong message, can't sign up again, and their courses and assignments are left pointing at nobody.
- **Fix:** the admin action becomes **Deactivate** (the person sees "Your account has been deactivated"), with **Reactivate** to undo it. For a teacher, their course assignments are handed to "unassigned" with a warning. Full deletion is self-service (S1-15) or via Blaze.
- **Where:** `admin_management_screens.dart`, `admin_remote_datasource.dart` (~L304).
- **✅ Done.** User Directory → ⋮ now has **Deactivate** / **Reactivate**; "Delete user" is gone. Not available on yourself, and the Chairman can't deactivate an Admin. Deactivated people are labelled "· Deactivated".
  - **One batch:** `isActive: false`. Login already says "Your account has been deactivated…", and the rules ignore the account (S1-02).
  - **Teacher or Chairman:** their courses become unassigned (course teacher cleared, assignments deleted, `assignedCourseIds` emptied, their weekly and upcoming slots cleared). The confirmation lists those courses.
  - **CR:** the role drops to Student and open CR offers are cancelled, so the batch can get a new CR (S2-04).
  - **Reactivate** only turns the account back on; courses and the CR role are reassigned by hand.
  - **Rules:** Admin / Chairman may cancel an open CR offer; the Chairman's role change may go together with `isActive`.
  - **Tests:** `firestore-rules-tests/deactivate_user.test.js` (4), `mobile/test/features/admin/deactivate_user_test.dart` (3), and 2 updated widget tests in `admin_management_test.dart`. Deployed. Full deletion stays self-service (S1-15).

### S2-08 · Changing a course's semester moves its dependents
- **Problem:** editing a course's year or semester doesn't move its routine slots, upcoming exams or attendance sessions.
- **Fix:** update them in the same batch, or block the change (with an explanation) once the course has a routine.
- **Where:** `admin_remote_datasource.dart` `updateCourse` (~L449-461).
- **✅ Done.** When an edit changes a course's year or semester, `updateCourse` does it in one batch with its **weekly routine slots, upcoming dated classes and upcoming exams**. Past attendance sessions, past classes and past exams stay with the semester they happened in. The edit dialog asks first ("Move CSE-3101 to Year 3, Semester 2?").
  - **Blocked, with the reason, when:**
    - a moving routine class would clash with another course in the new semester (names both classes);
    - the course has upcoming class changes, which can't be edited (asks to remove them first).
  - **Rules:** the exam semester check (S1-12) reads the course *after* the write (`getAfter`), so course and exams can move together; a lone exam still can't leave its course's semester.
  - **Tests:** `mobile/test/features/admin/course_semester_move_test.dart` (4) and a new case in `exams.test.js`. Deployed.

### S2-09 · Open sessions don't stay open forever
- **Problem:** a session that is never closed stays "open", never records absences and shows as "open" in Recent Classes.
- **Fix:** when a teacher opens Attendance, any of their expired sessions are closed automatically and absences recorded. Recent Classes also gets a **Close** button for stale ones.
- **Where:** `class_attendance_service.dart`, `attendance_controller.dart`, `teacher_attendance_terminal_screen.dart`.
- **✅ Done.**
  - **Auto-close:** when a teacher opens Attendance, `closeStaleSessions()` finishes each of their sessions (last 30 days) that is still open and either expired over 15 minutes ago (room to Extend) or is from an earlier day. It works like "Close & save": the full class list (semester and retakes) is loaded, everyone without a mark is recorded ABSENT, the count is recounted from records (S2-03), and the session is closed. A message says how many were closed. The class on screen is never auto-closed, and failures are retried next time.
  - **Recent Classes:** a stale session shows a **Close** button instead of the arrow.
  - **Tests:** 2 new in `mobile/test/features/attendance/class_attendance_test.dart` (which sessions close; the on-screen class is never closed). No rule change.

### S2-10 · "Today" uses Bangladesh time, not the phone's clock
- **Problem:** a phone with a wrong date or time zone files attendance and class changes under the wrong day.
- **Fix:** compute dates in Asia/Dhaka (UTC+6). Where possible, use the server time saved with the session as the source of truth.
- **Where:** `class_time.dart` (`dateKey`), `class_attendance_service.dart`, `class_change_repository.dart`.
- **✅ Done.**
  - **App:** `ClassTime.now()` is Bangladesh wall-clock time (UTC+6), and `ClassTime.instant()` is the real moment, both corrected by `ClassTime.serverOffset`. The offset is learned once per sign-in by `ServerClock.sync` (touches the user's own `updatedAt` with server time and reads it back: 1 write + 1 read). Attendance (session date, expiry, open-now, recent / stale), class changes, and the "today" views of the schedules, dashboards and routine use them. Deadline checks use `instant()`, day checks use `now()`. Class-change `dateTs` is midday Dhaka (06:00 UTC).
  - **Rules (the real guarantee, server clock):** a new attendance session's `sessionDate` must be today in Dhaka (`dhakaDateKey(request.time)`). Its `expiresAt` must be in the future and at most about 3 h ahead; extending is capped at 4 h from now. Every mark (self or teacher) must carry the session's own date. A class change's `date` must equal the Dhaka date of its `dateTs`.
  - **Tests:** 2 new rule tests in `attendance.test.js` and 1 in `class_changes.test.js` (fixtures now use Dhaka dates), plus `mobile/test/core/bangladesh_time_test.dart` (3). Deployed. The build already on phones in Bangladesh keeps working.

### S2-11 · Stay inside the free daily read limit (if 👤 B = free plan)
- **Problem:** each dashboard load reads every attendance session of the semester (about 500 reads by mid-term). 100 students pass the free limit of 50,000 reads a day, and then the app stops for everyone until the next day. Monitoring, teacher lists and admin logs also read whole collections.
- **Fix:**
  - **Per-course "classes held" counter:** updated by the teacher on Close &amp; Save.
  - **Per-student attendance summary:** one small record per student, updated when attendance is marked, so the dashboard reads a handful of records instead of hundreds.
  - **Lighter lookups:** teachers found by role, exams by course.
  - **Lists:** Monitoring and logs limited by date range, with admin lists paginated.
- **Where:** `cr_remote_datasource.dart` (~L248, L344, L381-395), `class_attendance_service.dart`, `teacher_monitoring_repository_impl.dart` (~L22-26, L59), `curriculum_repository_impl.dart` (~L405), `teacher_remote_datasource.dart` (~L278), `admin_remote_datasource.dart` (~L926, L943).
- **Done when:** estimated reads per dashboard load are under 30, and a usage test with 1,000 students stays under 50k a day.
- **✅ Done (free plan).**
  - **"Classes held" per course:** `courseStats/{courseId}.heldDates`, rebuilt from that course's sessions by the teacher on every save, close and auto-close. Rules: course teacher or admin only. A course without one falls back to its own sessions until the next save.
  - **Per-student summary:** `studentStats/{uid}.present.{courseId}`. It's raised by the student's own code mark (same batch) and by teacher marks (a teacher may change only their course's entry), and rebuilt once from the student's records if missing. It's the student's display copy; official reports still read the records. It's deleted with the account (S1-15).
  - **Shared code:** `attendance/data/services/attendance_totals.dart`, used by both the Attendance screen and the student / CR dashboard, so the numbers match.
  - **Lighter dashboard:** the counseling count is a `count()` query; exams are upcoming only (new index year + semester + examDate); the dashboard skips the recent-marks list; the **weekly routine and course list** come from the phone's offline copy and go to the server at most every 6 h (`core/network/cache_first.dart`; pull-to-refresh forces it). One-day class changes, holidays and exams stay live.
  - **Admin:** Monitoring reads only the chosen period's sessions; Attendance Logs show the last 60 days; Feedback the newest 300.
  - **Estimate per dashboard load:** about **22 reads** normally and about 40 when the 6-hour routine refresh is due, against about 800 before. Breakdown: profile 2, enrolments 1, own summary 1, "classes held" about 8, open sessions 1, holidays 2, class changes 2, counseling 2, upcoming exams about 3.
  - **Daily use:** at 2 dashboard opens a day (one with refresh) that's about 62 reads per student, so about 700 students fit in 50,000 reads a day. **1,000 students at that rate would be about 62k, over the free limit.** The likely real size (8 batches × about 60, so about 500) is about 31k. To fit 1,000, raise the cache to 24 h and cache holidays too (about 45k).
  - **Tests:** `firestore-rules-tests/attendance_stats.test.js` (4) and `mobile/test/features/attendance/free_plan_reads_test.dart` (5, including 500 conflicting sessions that must not be read). Deployed (rules and index).

### S2-12 · Friendly error messages everywhere
- **Problem:** about 40 places still show raw text such as "[cloud_firestore/permission-denied]".
- **Fix:** one shared helper that turns errors into plain sentences ("No internet connection", "You don't have permission to do this", …), used by every message bar.
- **Where:** `admin_management_screens.dart`, `my_class_screen.dart`, `cr_transfer_cards.dart`, `class_change_sheet.dart`, `class_changes_card.dart`, `class_actions_sheet.dart`, `exam_details_dialog.dart`, `admin_routine_screen.dart`, `admin_notification_hub_screen.dart`, `department_holidays_sheet.dart`, `student_profile_screen.dart`, `student_feedback_screen.dart`, `teacher_feedback_screen.dart`.

- **✅ Done.** One shared helper, `friendlyError(e)` (`mobile/lib/core/error/friendly_error.dart`), turns any error into a plain sentence:
  - "You don't have permission to do this."
  - "No internet connection…"
  - "This is taking too long…"
  - "That item no longer exists…"
  - "Please sign in again."
  - "This list is still being prepared…" (missing or building index)
  - "The app has reached today's free usage limit. Please try again tomorrow." (free plan)
  - sign-in errors such as wrong password or email already in use.

  Messages written for people (our validation texts) pass through. Technical prefixes ("[cloud_firestore/…]", "Exception:", "ServerException(message: …)") are removed. Programming errors become "Something went wrong. Please try again." It's used by every message bar, error panel and controller (40 files), and the data layer no longer wraps raw errors into its messages. `ErrorHandler`'s permission text now matches. Tests: `mobile/test/core/friendly_error_test.dart` (4).

### S2-13 · Smaller sync fixes
- **Exams on a holiday:** show a warning when an exam is scheduled on a holiday.
- **Rejection notices:** notify the student when their signup or semester request is rejected.
- **Refresh:** Class Changes, Requests and the dashboards refresh when the screen is reopened; the cached-data badge also appears on teacher and admin screens.
- **Double periods:** two sessions of the same course on one day count as two classes when they are for two different routine slots.
- **✅ Done.**
  - **Exams on a holiday:** the exam form loads the holiday list and, under the date, warns "This day is a holiday (Victory Day). You can still save…" (saving is not blocked).
  - **Rejection notices:** rejecting a semester request now notifies the student with the reason (the rules from S1-09 already allowed it). A rejected *signup* has no account to notify; sign-in already shows "rejected" with the reason.
  - **Refresh:** `RefreshBus` + `RefreshOnReopen` (`core/utils/refresh_on_reopen.dart`). The app shell pings when the app returns to the front or a tab is selected. The student/CR, teacher and admin dashboards, Class Changes and Requests then reload quietly, at most once a minute (free-plan reads). The cached-data badge was already on the teacher and admin dashboards.
  - **Double periods:** one class = one (day, routine slot) (`attendance/domain/services/class_keys.dart`). Sessions for different slots on one day are two classes; sessions without a slot that day join them. This applies to Monitoring (which already *expected* two), the course report (columns "2.11.26 (1)", "(2)" in CSV and Excel), the student summary and the CR dashboard. New marks store the session's `slotId`; older marks with only the day count for one class that day.
  - **Tests:** `mobile/test/features/attendance/double_period_test.dart` (6) and a holiday-warning case in `exam_management_test.dart`. No rule change.

**Stage 2 checklist:** tests for each item → full app and rule tests pass → deployed → checked on the phone (reassign a course, promote a batch, kill the teacher app mid-session, change a role).

#### Stage 2 checklist: results (2026-11-27)

| Step | Result |
|---|---|
| Items done | ✅ 13 of 13 (S2-01 … S2-13), all on the free plan. |
| Tests for each item | ✅ Every item has app tests, and rule tests where the rules changed: `course_assignment`, `role_change`, `semester_promotion`, `deactivate_user`, `attendance` (count, Dhaka dates), `exams` (course move), `class_changes` (Dhaka dates), `attendance_stats`; app tests in `test/features/admin`, `attendance`, `curriculum`, `teacher`, `core`. |
| Full rule tests | ✅ 151 / 151 pass (Firestore and Storage emulators). |
| App tests | ✅ 536 / 536 pass; `flutter analyze lib`: 0 errors. |
| Deployed | ✅ Firestore rules live and identical to the repo; 8 indexes deployed. Storage rules are still not deployed (no bucket on the free plan; uploads are off). |
| Checked on the phone | ⏳ Not done: no phone connected. A new build must be installed first (the build on the phone predates Stage 2). |

#### Stage 2 phone check (tick each)

Install: plug in the phone, then `cd mobile && flutter run` (or `flutter run --release`).

- [ ] **Reassign a course** (Admin → Teacher Courses → assign a different teacher): the box warns "Now taught by X…". Afterwards the old teacher can't open attendance for it, the new one can, and the routine shows the new teacher's name.
- [ ] **Promote a batch** (Admin / Chairman → Promote Batch): pick a semester and see the list, then promote. Students move up; the CR stays CR. A student sees past semesters in Attendance and Exams via the chips.
- [ ] **Kill the teacher app mid-session:** a teacher opens attendance and a student marks with the code. Force-close the teacher's app. The class counts as held for the student right away. When the teacher reopens Attendance more than 15 minutes after expiry, it says "Closed 1 earlier class…" and the other students show as absent.
- [ ] **Change a role** (User Directory → ⋮ → Change role): make a student CR; the confirmation names the old CR, who becomes a student. Teacher ↔ Chairman also works.
- [ ] Also worth a look: **Deactivate / Reactivate** a test user (login refused, then allowed); a **double period** counts as two classes; an **exam on a holiday** shows the warning; reopening the app refreshes the dashboard.

---

## Stage 3: Launch preparation

**Goal:** a signed release build that passes Google Play (and App Store) review, with a clean live database.
**Size:** about half a day of developer work, plus your store setup.

### S3-01 · Release signing (👤 you keep the key safe)
- **Problem:** release builds are signed with the debug key, so Google Play rejects them.
- **Fix:** create an upload keystore, add `key.properties` (kept out of git) and configure release signing in `build.gradle.kts` (~L28-29). Bump the version (`1.0.0+1` → as needed) for each upload.
- **👤 You:** store the keystore file and its password somewhere safe. If you lose them, you can't update the app.

### S3-02 · Scripts without passwords (after 👤 A)
- **Fix:** all scripts read passwords from environment variables only, and the literal passwords are removed from the repo. Optionally, scrub them from git history (`git filter-repo`); treat the old passwords as burned either way.
- **Where:** `scripts/setup_accounts.js`, `scripts/create_admin_user.js`, `scripts/create_student_and_cr.js`, `scripts/create_demo_teacher.js`, `scripts/create_chairman_test_accounts.js`.

### S3-03 · Clean live database, separate test project
- **Problem:** demo users, never-closed demo sessions (code 849201), old signup requests without logins and demo semester requests are in the live project.
- **Fix:** delete the demo records (list reviewed with you first) and stop running seed scripts against the live project. Create a separate test Firebase project for demos.
- **👤 You:** approve the list of records to delete.

### S3-04 · App Check in production mode
- **Problem:** the app always uses App Check's debug mode, which gives no protection and would break if enforcement were turned on.
- **Fix:** release builds use `--dart-define=ENV=production` (Play Integrity / App Attest). Turn on App Check enforcement in Firebase after testing.
- **Where:** `core/config/env_config.dart` (~L20), `main.dart`, `app_check_service.dart` (~L44).

### S3-05 · Push notifications decision (👤 B)
- **If Blaze:** deploy the notification function, so phones get real push notifications.
- **If free plan:** stop asking for push permission, and label notifications "in-app" (the bell). Stop storing FCM tokens and stop printing them in logs (`push_notification_service.dart` ~L42, ~L68).

### S3-06 · Android release setup
- **Remove** the `READ_MEDIA_IMAGES` permission (`AndroidManifest.xml` ~L6). The system photo picker doesn't need it, and Google Play flags it.
- **Turn on code shrinking:** R8 with keep rules for Firebase (`build.gradle.kts` ~L30).
- **Build with** `--obfuscate --split-debug-info` and upload the symbols to Crashlytics.
- **Confirm:** target SDK 35 and the notification permission flow on Android 13+.

### S3-07 · iOS setup
- **Add** `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` (photo upload crashes without them).
- **Set** the display name to "JnU EduPortal".
- **Check** the bundle id and the notification usage text.

### S3-08 · Privacy and store listing (👤 D)
- **In the app:** a privacy policy link on the Login and Profile screens.
- **Google Play:** fill in the Data Safety form (what is collected: name, email, phone, roll, attendance, photos).
- **Account deletion:** add a public account-deletion link or page (Play requires one in addition to the in-app button).

### S3-09 · Profile photos stored properly
- **Problem:** photos are saved inside the user records, which slows every user read.
- **Fix:** store small thumbnails (about 20 KB), or use Firebase Storage if the project has a bucket.
- **Where:** `student_profile_dialog.dart` (~L342), `teacher_profile_dialog.dart`.

### S3-10 · Polish and clean-up
- **Hard-coded text:**
  - replace "Session 2025–26" (`admin_header.dart` ~L227) with the real current session;
  - replace the "Assigned Instructor" placeholder in exports (`attendance_entities.dart` ~L389) with the real teacher name, or leave it blank;
  - move the hard-coded faculty list on the welcome screen (`welcome_screen.dart` ~L585-651) to data, or remove it.
- **Leftovers in code:** remove the mock fallback data from production code (`teacher_attendance_terminal_screen.dart` ~L1286-1307); route `debugPrint` calls through the app logger and keep them silent in release; fix the 36 analyzer warnings.
- **Docs:** update the README and older docs (`docs/requirements/*`, `role_matrices.md`) for the new flows: teachers approving, signup with a password, Late removed, holidays, retakes.

### S3-11 · Final release check
- **Build:** a signed release build on a real phone, installed from the Play Console **internal testing** track.
- **Walk through every role:** student, CR, teacher, chairman, admin; sign up, approve, attendance, schedule changes, exams, semester request, feedback, counseling, delete account.
- **Monitor:** watch Crashlytics and the Firebase usage page for 2–3 days with a small group before opening to everyone.

---

## Summary

| Stage | Focus | Main result | Needs from you |
|---|---|---|---|
| **1** | Security | No loopholes; members-only data; email verification; delete account; index fix | A (passwords), C (email domain) |
| **2** | Data in sync + cost | Same numbers everywhere; proper teacher changes, role changes, batch promotion; inside free limits | B (plan) |
| **3** | Launch | Signed release, store requirements, clean database, polish | Keystore, D (privacy policy), approve data clean-up |

**Already production-grade (no work needed):**
- **Attendance:** the rotating private code, own semester only, live roster and auto-absent.
- **Schedule:** the routine, one-day changes, holidays and clash checks.
- **Exams:** permissions, plus cancel and postpone.
- **Accounts:** signup and approval, and the CR hand-over.
- **App basics:** crash reporting, offline mode and bundled fonts.
- **Tests:** 480 app tests and 74 security-rule tests.
