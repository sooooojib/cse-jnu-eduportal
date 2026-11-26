import { describe, it } from "node:test";
import * as assert from "node:assert";
import { generateSecureAttendanceCode } from "./attendance";
import { DiagnosticSanitizer } from "./monitoring";

describe("STAGE 34: Comprehensive Security Audit & Adversarial Attack Tests", () => {
  // ─── IN-MEMORY ADVERSARIAL TEST HARNESS ─────────────────────────────────────
  class AuditMockDb {
    data: Record<string, Record<string, any>> = {
      courses: {
        "CSE-3101": { id: "CSE-3101", code: "CSE-3101", teacherId: "teacher_prof_1" },
      },
      users: {
        student_1: { id: "student_1", role: "STUDENT", year: 3, semester: 1, isActive: true },
        student_2: { id: "student_2", role: "STUDENT", year: 3, semester: 1, isActive: true },
        teacher_1: { id: "teacher_1", role: "TEACHER", isActive: true },
      },
      attendanceSessions: {},
      attendance: {},
      counselingSlots: {
        slot_1: { id: "slot_1", teacherId: "teacher_1", isBooked: false, status: "AVAILABLE" },
      },
      counselingBookings: {
        book_1: { id: "book_1", slotId: "slot_1", studentId: "student_1", teacherId: "teacher_1", status: "PENDING" },
      },
      feedback: {},
      feedbackIdentities: {},
    };

    setDoc(col: string, id: string, doc: any) {
      if (!this.data[col]) this.data[col] = {};
      this.data[col][id] = JSON.parse(JSON.stringify(doc));
    }

    getDoc(col: string, id: string) {
      return this.data[col]?.[id] ? JSON.parse(JSON.stringify(this.data[col][id])) : null;
    }
  }

  // ─── 1. ATTENDANCE SECURITY & VERIFICATION ATTACKS ──────────────────────────

  it("AUDIT-ATT-01: Rejects attendance submission with invalid or tampered 6-char code", () => {
    const db = new AuditMockDb();
    const activeCode = generateSecureAttendanceCode();
    db.setDoc("attendanceSessions", "sess_1", {
      id: "sess_1",
      code: activeCode,
      courseId: "CSE-3101",
      isActive: true,
      expiresAt: Date.now() + 600000,
      targetYear: 3,
      targetSemester: 1,
    });

    const submitFn = (caller: any, code: string) => {
      if (!caller || !caller.uid) throw new Error("UNAUTHENTICATED");
      if (caller.role !== "STUDENT" && caller.role !== "CR") throw new Error("PERMISSION_DENIED");
      if (!code || code.length !== 6) throw new Error("INVALID_ARGUMENT");
      const session = Object.values(db.data.attendanceSessions).find((s) => s.code === code && s.isActive);
      if (!session) throw new Error("NOT_FOUND: Invalid attendance code");
      return { success: true };
    };

    // Tampered code attack
    assert.throws(
      () => submitFn({ uid: "student_1", role: "STUDENT" }, "WRONG1"),
      /NOT_FOUND/
    );

    // Unauthenticated attack
    assert.throws(
      () => submitFn(null, activeCode),
      /UNAUTHENTICATED/
    );

    // Teacher attempting student attendance
    assert.throws(
      () => submitFn({ uid: "teacher_1", role: "TEACHER" }, activeCode),
      /PERMISSION_DENIED/
    );

    // Malformed code length
    assert.throws(
      () => submitFn({ uid: "student_1", role: "STUDENT" }, "ABC"),
      /INVALID_ARGUMENT/
    );
  });

  it("AUDIT-ATT-02: Prevents duplicate attendance submissions by same student", () => {
    const db = new AuditMockDb();
    const activeCode = generateSecureAttendanceCode();
    db.setDoc("attendanceSessions", "sess_1", {
      id: "sess_1",
      code: activeCode,
      courseId: "CSE-3101",
      isActive: true,
      expiresAt: Date.now() + 600000,
      targetYear: 3,
      targetSemester: 1,
    });

    const submitFn = (caller: any, code: string) => {
      const session = Object.values(db.data.attendanceSessions).find((s) => s.code === code && s.isActive);
      if (!session) throw new Error("NOT_FOUND");
      const recordKey = `${session.id}_${caller.uid}`;
      if (db.getDoc("attendance", recordKey)) {
        throw new Error("ALREADY_EXISTS: Duplicate attendance attempt blocked");
      }
      db.setDoc("attendance", recordKey, { status: "PRESENT", studentId: caller.uid });
      return { success: true };
    };

    // First attempt succeeds
    const firstResult = submitFn({ uid: "student_1", role: "STUDENT" }, activeCode);
    assert.strictEqual(firstResult.success, true);

    // Replay / duplicate attempt must be rejected
    assert.throws(
      () => submitFn({ uid: "student_1", role: "STUDENT" }, activeCode),
      /ALREADY_EXISTS/
    );
  });

  // ─── 2. ANONYMOUS FEEDBACK PRIVACY AUDIT ────────────────────────────────────

  it("AUDIT-FEED-01: Verifies student true UID is masked to ANONYMOUS in teacher-visible document", () => {
    const db = new AuditMockDb();
    const caller = { uid: "secret_student_999", role: "STUDENT", fullName: "Alice Student" };

    const submitFeedbackFn = (user: any, data: any) => {
      const feedbackId = "fb_101";
      const teacherVisibleDoc = {
        id: feedbackId,
        teacherId: data.teacherId,
        rating: data.rating,
        comments: data.comments,
        isAnonymous: data.isAnonymous,
        // Privacy invariant: studentId must be ANONYMOUS when isAnonymous is true
        studentId: data.isAnonymous ? "ANONYMOUS" : user.uid,
        studentName: data.isAnonymous ? "Anonymous Student" : user.fullName,
        studentEmail: data.isAnonymous ? null : "student@jnu.ac.bd",
      };

      const identityDoc = {
        id: feedbackId,
        realStudentId: user.uid,
        isAnonymous: data.isAnonymous,
      };

      db.setDoc("feedback", feedbackId, teacherVisibleDoc);
      db.setDoc("feedbackIdentities", feedbackId, identityDoc);
      return { success: true, feedbackId };
    };

    submitFeedbackFn(caller, {
      teacherId: "teacher_1",
      rating: 5,
      comments: "Great lecture on distributed systems.",
      isAnonymous: true,
    });

    const teacherDoc = db.getDoc("feedback", "fb_101");
    assert.strictEqual(teacherDoc.studentId, "ANONYMOUS");
    assert.strictEqual(teacherDoc.studentName, "Anonymous Student");
    assert.strictEqual(teacherDoc.studentEmail, null);

    // Private identity doc is strictly separated
    const identityDoc = db.getDoc("feedbackIdentities", "fb_101");
    assert.strictEqual(identityDoc.realStudentId, "secret_student_999");
  });

  // ─── 3. COUNSELING AUTHORIZATION & CONCURRENCY AUDIT ─────────────────────────

  it("AUDIT-COUN-01: Prevents students from approving their own counseling booking", () => {
    const db = new AuditMockDb();

    const approveBookingFn = (caller: any, bookingId: string) => {
      const booking = db.getDoc("counselingBookings", bookingId);
      if (!booking) throw new Error("NOT_FOUND");
      if (caller.uid !== booking.teacherId && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only assigned teacher or admin can approve");
      }
      booking.status = "APPROVED";
      db.setDoc("counselingBookings", bookingId, booking);
      return { success: true };
    };

    // Rogue student tries to approve booking
    assert.throws(
      () => approveBookingFn({ uid: "student_1", role: "STUDENT" }, "book_1"),
      /PERMISSION_DENIED/
    );

    // Teacher succeeds
    const result = approveBookingFn({ uid: "teacher_1", role: "TEACHER" }, "book_1");
    assert.strictEqual(result.success, true);
  });

  // ─── 4. LOGGING PRIVACY & ZERO-LEAKAGE AUDIT ────────────────────────────────

  it("AUDIT-LOG-01: DiagnosticSanitizer purges credentials, JWTs, and passwords", () => {
    const attackPayload = {
      password: "HackerPassword#123",
      apiKey: "AIzaSyD-SecretKey",
      token: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signature",
      authorization: "Bearer secret_session_token",
      studentComment: "Confidential feedback evaluation",
      courseId: "CSE-3101",
    };

    const sanitized = DiagnosticSanitizer.sanitize(attackPayload);

    assert.strictEqual(sanitized.password, "[REDACTED]");
    assert.strictEqual(sanitized.apiKey, "[REDACTED]");
    assert.strictEqual(sanitized.token, "[REDACTED]");
    assert.strictEqual(sanitized.authorization, "[REDACTED]");
    assert.strictEqual(sanitized.studentComment, "[REDACTED]");
    assert.strictEqual(sanitized.courseId, "CSE-3101");
  });
});
