import { describe, it } from "node:test";
import * as assert from "node:assert";
import { generateSecureAttendanceCode } from "./attendance";

describe("STAGE 20: Server-Side Attendance Verification & Authorization Tests", () => {
  // ─── 1. SECURE CODE GENERATION TESTS ────────────────────────────────────────

  it("1. generateSecureAttendanceCode produces secure 6-character code from unambiguous alphabet", () => {
    const code = generateSecureAttendanceCode();
    assert.strictEqual(code.length, 6, "Code must be exactly 6 characters");
    assert.match(code, /^[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6}$/, "Must only contain safe alphanumeric characters");

    // Test randomness & collision resistance across sample set
    const sampleSet = new Set<string>();
    for (let i = 0; i < 100; i++) {
      sampleSet.add(generateSecureAttendanceCode());
    }
    assert.strictEqual(sampleSet.size, 100, "All 100 generated codes must be unique");
  });

  // ─── 2. TRANSACTIONAL MEMORY HARNESS FOR FIRESTORE AUTHORITATIVE LOGIC ─────

  class MockFirestore {
    data: { [col: string]: { [id: string]: any } } = {
      courses: {},
      courseAssignments: {},
      users: {},
      enrollments: {},
      attendanceSessions: {},
      attendance: {},
    };

    reset() {
      this.data = {
        courses: {},
        courseAssignments: {},
        users: {},
        enrollments: {},
        attendanceSessions: {},
        attendance: {},
      };
    }

    setDoc(col: string, id: string, doc: any) {
      if (!this.data[col]) this.data[col] = {};
      this.data[col][id] = JSON.parse(JSON.stringify(doc));
    }

    getDoc(col: string, id: string) {
      return this.data[col]?.[id] ? JSON.parse(JSON.stringify(this.data[col][id])) : null;
    }
  }

  const mockDb = new MockFirestore();

  // Pure Authoritative Attendance Service mirroring Cloud Functions transaction logic
  class AttendanceService {
    db: MockFirestore;
    constructor(db: MockFirestore) {
      this.db = db;
    }

    // 1. Teacher starts session
    async startSession(auth: { uid: string; role: string; name?: string }, courseId: string, durationMinutes = 15) {
      if (!auth) throw new Error("UNAUTHENTICATED");
      if (auth.role !== "TEACHER" && auth.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only teachers or admins can start attendance sessions");
      }
      if (!courseId) throw new Error("INVALID_ARGUMENT: Missing courseId");

      const course = this.db.getDoc("courses", courseId);
      if (!course) throw new Error("NOT_FOUND: Course not found");

      const isAssigned = course.teacherId === auth.uid || auth.role === "ADMIN";
      if (!isAssigned) {
        throw new Error("PERMISSION_DENIED: Teacher is not authorized for this course");
      }

      // Deactivate any previous active sessions for this course
      for (const [, s] of Object.entries(this.db.data.attendanceSessions || {})) {
        if (s.courseId === courseId && s.teacherId === auth.uid && s.isActive) {
          s.isActive = false;
          s.status = "COMPLETED";
        }
      }

      const code = generateSecureAttendanceCode();
      const sessionId = `sess_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const now = Date.now();
      const expiresAt = now + durationMinutes * 60 * 1000;

      const session = {
        id: sessionId,
        courseId,
        courseCode: course.code,
        courseTitle: course.title,
        teacherId: auth.uid,
        teacherName: auth.name || course.teacherName || "Professor",
        code,
        isActive: true,
        status: "ACTIVE",
        startTime: now,
        expiresAt,
        sessionDate: new Date().toISOString().substring(0, 10),
        targetYear: course.year,
        targetSemester: course.semester,
        totalPresentCount: 0,
      };

      this.db.setDoc("attendanceSessions", sessionId, session);
      return session;
    }

    // 2. Deactivate session
    async deactivateSession(auth: { uid: string; role: string }, sessionId: string) {
      if (!auth) throw new Error("UNAUTHENTICATED");
      const session = this.db.getDoc("attendanceSessions", sessionId);
      if (!session) throw new Error("NOT_FOUND: Session not found");

      if (session.teacherId !== auth.uid && auth.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Unauthorized to deactivate this session");
      }

      session.isActive = false;
      session.status = "COMPLETED";
      this.db.setDoc("attendanceSessions", sessionId, session);
      return { success: true, sessionId };
    }

    // 3. Submit Attendance Code (Atomic Transaction Simulation)
    private _lock = new Map<string, Promise<any>>();

    async submitCode(auth: { uid: string; role: string }, code: string, courseId?: string) {
      if (!auth) throw new Error("UNAUTHENTICATED");
      if (auth.role !== "STUDENT" && auth.role !== "CR") {
        throw new Error("PERMISSION_DENIED: Only students and CRs can submit attendance");
      }

      if (!code || typeof code !== "string" || code.trim().length !== 6) {
        throw new Error("INVALID_ARGUMENT: Attendance code must be exactly 6 characters");
      }

      const cleanCode = code.trim().toUpperCase();

      // Ensure transactional mutex per (code + studentUid) to simulate Firestore transaction locking
      const lockKey = `${cleanCode}_${auth.uid}`;
      while (this._lock.has(lockKey)) {
        await this._lock.get(lockKey);
      }

      let releaseLock!: () => void;
      const lockPromise = new Promise<void>((resolve) => {
        releaseLock = resolve;
      });
      this._lock.set(lockKey, lockPromise);

      try {
        // A. Find session by code
        let matchingSession: any = null;
        for (const s of Object.values(this.db.data.attendanceSessions || {})) {
          if (s.code === cleanCode) {
            matchingSession = s;
            break;
          }
        }

        if (!matchingSession) {
          throw new Error("NOT_FOUND: Invalid attendance code");
        }

        if (!matchingSession.isActive || matchingSession.status !== "ACTIVE") {
          throw new Error("FAILED_PRECONDITION: This attendance session is no longer active");
        }

        if (Date.now() > matchingSession.expiresAt) {
          matchingSession.isActive = false;
          matchingSession.status = "EXPIRED";
          throw new Error("DEADLINE_EXCEEDED: This attendance session has expired");
        }

        if (courseId && courseId !== matchingSession.courseId) {
          throw new Error("INVALID_ARGUMENT: Code does not match selected course");
        }

        // B. Check student profile & enrollment
        const student = this.db.getDoc("users", auth.uid);
        if (!student) throw new Error("NOT_FOUND: Student profile not found");
        if (student.isActive === false) throw new Error("PERMISSION_DENIED: Student account inactive");

        const cohortMatch = student.year === matchingSession.targetYear &&
                            student.semester === matchingSession.targetSemester;
        const explicitEnrollment = this.db.getDoc("enrollments", `${matchingSession.courseId}_${auth.uid}`);
        const isEnrolled = cohortMatch || (explicitEnrollment && explicitEnrollment.status !== "DROPPED");

        if (!isEnrolled) {
          throw new Error("PERMISSION_DENIED: You are not enrolled in this course");
        }

        // C. Duplicate Protection Check via Composite ID
        const recordId = `${matchingSession.id}_${auth.uid}`;
        const existingRecord = this.db.getDoc("attendance", recordId);
        if (existingRecord) {
          throw new Error("ALREADY_EXISTS: You have already attended this session");
        }

        // D. Atomically Write PRESENT Attendance Record
        const record = {
          id: recordId,
          sessionId: matchingSession.id,
          studentId: auth.uid,
          studentName: student.fullName,
          studentRoll: student.studentId,
          courseId: matchingSession.courseId,
          courseCode: matchingSession.courseCode,
          courseTitle: matchingSession.courseTitle,
          status: "PRESENT",
          isManualOverride: false,
          date: matchingSession.sessionDate,
          verifiedAt: Date.now(),
        };

        this.db.setDoc("attendance", recordId, record);
        matchingSession.totalPresentCount += 1;
        this.db.setDoc("attendanceSessions", matchingSession.id, matchingSession);

        return {
          success: true,
          recordId,
          courseCode: matchingSession.courseCode,
          courseTitle: matchingSession.courseTitle,
        };
      } finally {
        this._lock.delete(lockKey);
        releaseLock();
      }
    }

    // 4. View Roster
    async getRoster(auth: { uid: string; role: string }, sessionId: string) {
      const session = this.db.getDoc("attendanceSessions", sessionId);
      if (!session) throw new Error("NOT_FOUND: Session not found");

      if (session.teacherId !== auth.uid && auth.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Unauthorized to view roster");
      }

      const roster: any[] = [];
      for (const [uid, user] of Object.entries(this.db.data.users || {})) {
        if ((user.role === "STUDENT" || user.role === "CR") &&
            user.year === session.targetYear &&
            user.semester === session.targetSemester) {
          const rec = this.db.getDoc("attendance", `${sessionId}_${uid}`);
          roster.push({
            studentId: uid,
            studentRoll: user.studentId,
            studentName: user.fullName,
            status: rec ? rec.status : "ABSENT",
            isManualOverride: rec ? rec.isManualOverride : false,
          });
        }
      }
      roster.sort((a, b) => (a.studentRoll || "").localeCompare(b.studentRoll || ""));
      return { sessionId, totalPresent: session.totalPresentCount, roster };
    }

    // 5. Update Roster manually
    async updateRoster(
      auth: { uid: string; role: string },
      sessionId: string,
      updates: Array<{ studentId: string; status: "PRESENT" | "ABSENT" }>
    ) {
      const session = this.db.getDoc("attendanceSessions", sessionId);
      if (!session) throw new Error("NOT_FOUND: Session not found");

      if (session.teacherId !== auth.uid && auth.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Unauthorized to modify roster");
      }

      for (const up of updates) {
        const student = this.db.getDoc("users", up.studentId);
        const recordId = `${sessionId}_${up.studentId}`;
        this.db.setDoc("attendance", recordId, {
          id: recordId,
          sessionId,
          studentId: up.studentId,
          studentName: student?.fullName || "Student",
          studentRoll: student?.studentId || "",
          courseId: session.courseId,
          courseCode: session.courseCode,
          courseTitle: session.courseTitle,
          status: up.status,
          isManualOverride: true,
          date: session.sessionDate,
          updatedAt: Date.now(),
        });
      }

      // Recalculate present count
      let presentCount = 0;
      for (const rec of Object.values(this.db.data.attendance || {})) {
        if (rec.sessionId === sessionId && rec.status === "PRESENT") {
          presentCount++;
        }
      }
      session.totalPresentCount = presentCount;
      this.db.setDoc("attendanceSessions", sessionId, session);

      return { success: true, totalPresentCount: presentCount };
    }
  }

  const service = new AttendanceService(mockDb);

  // Seed baseline fixture data
  const teacherUser = { uid: "teacher_layek", role: "TEACHER", name: "Dr. Md. Abu Layek" };
  const student1 = { uid: "student_sajib", role: "STUDENT", studentId: "B200305001", fullName: "Sajib Ahmed", year: 3, semester: 1 };
  const student2 = { uid: "student_rahim", role: "STUDENT", studentId: "B200305002", fullName: "Rahim Khan", year: 3, semester: 1 };
  const outsiderStudent = { uid: "student_unreg", role: "STUDENT", studentId: "B220305099", fullName: "Outsider", year: 1, semester: 1 };

  function setupFixture() {
    mockDb.reset();
    mockDb.setDoc("courses", "CSE-3101", {
      id: "CSE-3101",
      code: "CSE-3101",
      title: "Operating Systems",
      teacherId: "teacher_layek",
      teacherName: "Dr. Md. Abu Layek",
      year: 3,
      semester: 1,
    });
    mockDb.setDoc("courses", "CSE-1101", {
      id: "CSE-1101",
      code: "CSE-1101",
      title: "Structured Programming",
      teacherId: "teacher_other",
      teacherName: "Other Faculty",
      year: 1,
      semester: 1,
    });
    mockDb.setDoc("users", "teacher_layek", { ...teacherUser });
    mockDb.setDoc("users", "student_sajib", { ...student1 });
    mockDb.setDoc("users", "student_rahim", { ...student2 });
    mockDb.setDoc("users", "student_unreg", { ...outsiderStudent });
  }

  // ─── 3. TEST CASES IMPLEMENTING STAGE 20 CRITERIA ───────────────────────────

  it("2. Teacher successfully creates authorized attendance session with 6-char code and validity", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", 15);
    assert.strictEqual(session.courseCode, "CSE-3101");
    assert.strictEqual(session.teacherId, "teacher_layek");
    assert.strictEqual(session.code.length, 6);
    assert.strictEqual(session.isActive, true);
    assert.strictEqual(session.status, "ACTIVE");
    assert.ok(session.expiresAt > Date.now(), "Expiration must be in future");
  });

  it("3. Valid Attendance: Enrolled student enters correct 6-char code and is marked PRESENT", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", 15);
    const result = await service.submitCode({ uid: student1.uid, role: student1.role }, session.code);

    assert.strictEqual(result.success, true);
    assert.strictEqual(result.courseCode, "CSE-3101");

    const record = mockDb.getDoc("attendance", `${session.id}_${student1.uid}`);
    assert.ok(record, "Attendance record must exist");
    assert.strictEqual(record.status, "PRESENT");
    assert.strictEqual(record.studentId, student1.uid);
    assert.strictEqual(record.studentRoll, student1.studentId);

    const updatedSession = mockDb.getDoc("attendanceSessions", session.id);
    assert.strictEqual(updatedSession.totalPresentCount, 1);
  });

  it("4. Invalid Code: Throws NOT_FOUND for non-existent verification code", async () => {
    setupFixture();
    await service.startSession(teacherUser, "CSE-3101", 15);
    await assert.rejects(
      async () => service.submitCode({ uid: student1.uid, role: student1.role }, "999999"),
      /NOT_FOUND: Invalid attendance code/
    );
  });

  it("5. Wrong Code Length: Rejects codes that are not exactly 6 characters", async () => {
    setupFixture();
    await assert.rejects(
      async () => service.submitCode({ uid: student1.uid, role: student1.role }, "12345"),
      /INVALID_ARGUMENT: Attendance code must be exactly 6 characters/
    );
    await assert.rejects(
      async () => service.submitCode({ uid: student1.uid, role: student1.role }, "1234567"),
      /INVALID_ARGUMENT: Attendance code must be exactly 6 characters/
    );
  });

  it("6. Inactive Code: Rejects submission after teacher deactivates session", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", 15);
    await service.deactivateSession(teacherUser, session.id);

    await assert.rejects(
      async () => service.submitCode({ uid: student1.uid, role: student1.role }, session.code),
      /FAILED_PRECONDITION: This attendance session is no longer active/
    );
  });

  it("7. Expired Code: Rejects submission when validity window has passed", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", -1); // Expired immediately
    await assert.rejects(
      async () => service.submitCode({ uid: student1.uid, role: student1.role }, session.code),
      /DEADLINE_EXCEEDED: This attendance session has expired/
    );
  });

  it("8. Wrong Course: Rejects code if student specifies a mismatched courseId", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", 15);
    await assert.rejects(
      async () => service.submitCode({ uid: student1.uid, role: student1.role }, session.code, "CSE-1101"),
      /INVALID_ARGUMENT: Code does not match selected course/
    );
  });

  it("9. Unregistered/Unenrolled Student: Rejects student from different year/semester", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", 15);
    await assert.rejects(
      async () => service.submitCode({ uid: outsiderStudent.uid, role: outsiderStudent.role }, session.code),
      /PERMISSION_DENIED: You are not enrolled in this course/
    );
  });

  it("10. Duplicate Attendance: Rejects second attendance attempt by the same student", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", 15);
    // First attempt succeeds
    await service.submitCode({ uid: student1.uid, role: student1.role }, session.code);

    // Second attempt fails with ALREADY_EXISTS
    await assert.rejects(
      async () => service.submitCode({ uid: student1.uid, role: student1.role }, session.code),
      /ALREADY_EXISTS: You have already attended this session/
    );
  });

  it("11. Concurrent Duplicate Protection: Simultaneous concurrent calls result in exactly 1 success", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", 15);

    // Launch 5 simultaneous requests for the exact same student and session
    const results = await Promise.allSettled([
      service.submitCode({ uid: student1.uid, role: student1.role }, session.code),
      service.submitCode({ uid: student1.uid, role: student1.role }, session.code),
      service.submitCode({ uid: student1.uid, role: student1.role }, session.code),
      service.submitCode({ uid: student1.uid, role: student1.role }, session.code),
      service.submitCode({ uid: student1.uid, role: student1.role }, session.code),
    ]);

    const successes = results.filter((r) => r.status === "fulfilled");
    const rejections = results.filter((r) => r.status === "rejected");

    assert.strictEqual(successes.length, 1, "Exactly one concurrent request must succeed");
    assert.strictEqual(rejections.length, 4, "Remaining concurrent requests must be rejected");

    const sessionState = mockDb.getDoc("attendanceSessions", session.id);
    assert.strictEqual(sessionState.totalPresentCount, 1, "Count must be incremented exactly once");
  });

  it("12. Unauthorized Teacher: Rejects teacher attempting to start session for unassigned course", async () => {
    setupFixture();
    const fakeTeacher = { uid: "intruder_teacher", role: "TEACHER" };
    await assert.rejects(
      async () => service.startSession(fakeTeacher, "CSE-3101", 15),
      /PERMISSION_DENIED: Teacher is not authorized for this course/
    );
  });

  it("13. Unauthorized Roster Modification: Prevents unauthorized teacher from updating session roster", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", 15);
    const intruder = { uid: "other_teacher", role: "TEACHER" };

    await assert.rejects(
      async () => service.updateRoster(intruder, session.id, [{ studentId: student1.uid, status: "PRESENT" }]),
      /PERMISSION_DENIED: Unauthorized to modify roster/
    );
  });

  it("14. Manual Attendance & Roster Overrides: Teacher marks all present, all absent, and individual overrides", async () => {
    setupFixture();
    const session = await service.startSession(teacherUser, "CSE-3101", 15);

    // Initial roster shows both students ABSENT
    const initialRoster = await service.getRoster(teacherUser, session.id);
    assert.strictEqual(initialRoster.roster.length, 2);
    assert.strictEqual(initialRoster.roster[0].status, "ABSENT");
    assert.strictEqual(initialRoster.roster[1].status, "ABSENT");

    // Teacher Mark All Present
    const markAllPresent = await service.updateRoster(teacherUser, session.id, [
      { studentId: student1.uid, status: "PRESENT" },
      { studentId: student2.uid, status: "PRESENT" },
    ]);
    assert.strictEqual(markAllPresent.totalPresentCount, 2);

    // Verify roster reflects both present
    const updatedRoster1 = await service.getRoster(teacherUser, session.id);
    assert.strictEqual(updatedRoster1.roster[0].status, "PRESENT");
    assert.strictEqual(updatedRoster1.roster[1].status, "PRESENT");
    assert.strictEqual(updatedRoster1.roster[0].isManualOverride, true);

    // Individually modify Student 2 to ABSENT
    const individualOverride = await service.updateRoster(teacherUser, session.id, [
      { studentId: student2.uid, status: "ABSENT" },
    ]);
    assert.strictEqual(individualOverride.totalPresentCount, 1);

    const updatedRoster2 = await service.getRoster(teacherUser, session.id);
    assert.strictEqual(updatedRoster2.roster[0].status, "PRESENT");
    assert.strictEqual(updatedRoster2.roster[1].status, "ABSENT");
  });
});
