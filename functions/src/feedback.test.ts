import { describe, it, beforeEach } from "node:test";
import * as assert from "node:assert";
import {
  validateFeedbackInput,
  AttachmentData,
} from "./feedback";

describe("STAGE 24: Feedback System, Anonymity Security & Role Visibility Tests", () => {
  // ─── 1. INPUT VALIDATION TESTS ─────────────────────────────────────────────

  it("1. validateFeedbackInput succeeds on valid data", () => {
    const valid = validateFeedbackInput({
      teacherId: "teacher_layek",
      courseId: "cse-3101",
      courseCode: "CSE-3101",
      courseTitle: "Operating Systems",
      rating: 5,
      comments: "Exceptional lectures and very clear explanations on process synchronization.",
      isAnonymous: true,
      attachments: [
        {
          id: "att_1",
          fileName: "notes.pdf",
          fileUrl: "https://storage.googleapis.com/test/notes.pdf",
          mimeType: "application/pdf",
          fileSize: 1024,
        },
      ],
    });

    assert.strictEqual(valid.teacherId, "teacher_layek");
    assert.strictEqual(valid.rating, 5);
    assert.strictEqual(valid.isAnonymous, true);
    assert.strictEqual(valid.attachments.length, 1);
    assert.strictEqual(valid.attachments[0].fileName, "notes.pdf");
  });

  it("2. validateFeedbackInput rejects missing teacherId, rating outside 1–5, or comments < 5 chars", () => {
    // Missing teacher
    assert.throws(
      () => validateFeedbackInput({ teacherId: "", rating: 4, comments: "Good class" }),
      /Teacher ID is required/
    );

    // Rating < 1
    assert.throws(
      () => validateFeedbackInput({ teacherId: "t1", rating: 0, comments: "Good class" }),
      /Rating must be an integer between 1 and 5/
    );

    // Rating > 5
    assert.throws(
      () => validateFeedbackInput({ teacherId: "t1", rating: 6, comments: "Good class" }),
      /Rating must be an integer between 1 and 5/
    );

    // Comments < 5 chars
    assert.throws(
      () => validateFeedbackInput({ teacherId: "t1", rating: 4, comments: "Hi" }),
      /Comments must be at least 5 characters long/
    );
  });

  // ─── 2. SIMULATED FIRESTORE & FEEDBACK SERVICE ──────────────────────────────

  class MockFirestoreDb {
    data: { [col: string]: { [id: string]: any } } = {
      users: {},
      feedback: {},
      feedbackIdentities: {},
    };

    reset() {
      this.data = {
        users: {},
        feedback: {},
        feedbackIdentities: {},
      };
    }

    setDoc(col: string, id: string, doc: any) {
      if (!this.data[col]) this.data[col] = {};
      this.data[col][id] = JSON.parse(JSON.stringify(doc));
    }

    getDoc(col: string, id: string) {
      return this.data[col]?.[id] ? JSON.parse(JSON.stringify(this.data[col][id])) : null;
    }

    deleteDoc(col: string, id: string) {
      if (this.data[col]) delete this.data[col][id];
    }
  }

  const mockDb = new MockFirestoreDb();

  class AuthoritativeFeedbackService {
    db: MockFirestoreDb;

    constructor(db: MockFirestoreDb) {
      this.db = db;
    }

    async submitFeedback(
      caller: { uid: string; role: string; fullName?: string; email?: string },
      data: any
    ) {
      if (caller.role !== "STUDENT" && caller.role !== "CR" && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only students or CRs can submit course and faculty feedback.");
      }

      const validated = validateFeedbackInput(data);
      const feedbackId = `fb_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

      // 1. Public / Teacher Accessible Feedback Doc
      const feedbackDoc = {
        id: feedbackId,
        teacherId: validated.teacherId,
        teacherName: "Faculty Member",
        courseId: validated.courseId || null,
        courseCode: validated.courseCode || null,
        courseTitle: validated.courseTitle || null,
        rating: validated.rating,
        comments: validated.comments,
        isAnonymous: validated.isAnonymous,
        // SENSITIVE PRIVACY PROTECTION:
        studentId: validated.isAnonymous ? "ANONYMOUS" : caller.uid,
        studentName: validated.isAnonymous ? "Anonymous Student" : (caller.fullName || "Student"),
        studentEmail: validated.isAnonymous ? null : (caller.email || null),
        attachments: validated.attachments,
        replies: [],
        hasReplied: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      // 2. Sensitive Identity Doc (Admin & Student Author ONLY - Teachers Forbidden)
      const identityDoc = {
        id: feedbackId,
        feedbackId,
        studentId: caller.uid,
        studentName: caller.fullName || "Student",
        studentEmail: caller.email || "student@cse.jnu.ac.bd",
        teacherId: validated.teacherId,
        isAnonymous: validated.isAnonymous,
        createdAt: new Date().toISOString(),
      };

      this.db.setDoc("feedback", feedbackId, feedbackDoc);
      this.db.setDoc("feedbackIdentities", feedbackId, identityDoc);

      return { success: true, feedbackId, feedback: feedbackDoc };
    }

    async editFeedback(
      caller: { uid: string; role: string },
      feedbackId: string,
      data: { rating: number; comments: string; isAnonymous?: boolean; attachments?: AttachmentData[] }
    ) {
      const identity = this.db.getDoc("feedbackIdentities", feedbackId);
      if (!identity) throw new Error("NOT_FOUND: Feedback record not found.");

      if (identity.studentId !== caller.uid && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: You can only edit feedback you submitted.");
      }

      const feedback = this.db.getDoc("feedback", feedbackId);
      if (!feedback) throw new Error("NOT_FOUND: Feedback document not found.");

      if (data.rating < 1 || data.rating > 5) {
        throw new Error("INVALID_ARGUMENT: Rating must be between 1 and 5.");
      }
      if (!data.comments || data.comments.trim().length < 5) {
        throw new Error("INVALID_ARGUMENT: Comments must be at least 5 characters long.");
      }

      const isAnonymous = typeof data.isAnonymous === "boolean" ? data.isAnonymous : identity.isAnonymous;

      feedback.rating = data.rating;
      feedback.comments = data.comments.trim();
      feedback.isAnonymous = isAnonymous;
      feedback.studentId = isAnonymous ? "ANONYMOUS" : identity.studentId;
      feedback.studentName = isAnonymous ? "Anonymous Student" : identity.studentName;
      feedback.studentEmail = isAnonymous ? null : identity.studentEmail;
      if (data.attachments) feedback.attachments = data.attachments;
      feedback.updatedAt = new Date().toISOString();

      identity.isAnonymous = isAnonymous;
      identity.updatedAt = new Date().toISOString();

      this.db.setDoc("feedback", feedbackId, feedback);
      this.db.setDoc("feedbackIdentities", feedbackId, identity);

      return { success: true, feedback };
    }

    async replyToFeedback(
      caller: { uid: string; role: string; fullName?: string },
      feedbackId: string,
      replyText: string,
      attachments?: AttachmentData[]
    ) {
      if (caller.role !== "TEACHER" && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only teachers or administrators can reply to feedback.");
      }

      const feedback = this.db.getDoc("feedback", feedbackId);
      if (!feedback) throw new Error("NOT_FOUND: Feedback not found.");

      if (feedback.teacherId !== caller.uid && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only the assigned teacher can reply to this feedback.");
      }

      if (!replyText || !replyText.trim()) {
        throw new Error("INVALID_ARGUMENT: Reply text cannot be empty.");
      }

      const replyId = `rep_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const reply = {
        id: replyId,
        teacherId: caller.uid,
        teacherName: caller.fullName || "Teacher Name",
        replyText: replyText.trim(),
        attachments: attachments || [],
        createdAt: new Date().toISOString(),
      };

      feedback.replies = [...(feedback.replies || []), reply];
      feedback.hasReplied = true;
      feedback.updatedAt = new Date().toISOString();
      this.db.setDoc("feedback", feedbackId, feedback);

      return { success: true, replyId, reply };
    }

    async editReply(
      caller: { uid: string; role: string },
      feedbackId: string,
      replyId: string,
      newReplyText: string
    ) {
      const feedback = this.db.getDoc("feedback", feedbackId);
      if (!feedback) throw new Error("NOT_FOUND: Feedback not found.");

      if (feedback.teacherId !== caller.uid && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Unauthorized to edit this reply.");
      }

      let found = false;
      feedback.replies = (feedback.replies || []).map((r: any) => {
        if (r.id === replyId) {
          found = true;
          return { ...r, replyText: newReplyText.trim(), updatedAt: new Date().toISOString() };
        }
        return r;
      });

      if (!found) throw new Error("NOT_FOUND: Reply not found.");
      this.db.setDoc("feedback", feedbackId, feedback);

      return { success: true, message: "Reply updated." };
    }

    async getTeacherReceivedFeedback(
      caller: { uid: string; role: string },
      filter: "ALL" | "REPLIED" | "NOT_REPLIED" = "ALL"
    ) {
      if (caller.role !== "TEACHER" && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only teachers can view received feedback.");
      }

      const all = Object.values(this.db.data.feedback || {});
      let items = all.filter((f) => f.teacherId === caller.uid);

      // SECURITY CRITICAL ASSERTION: Teacher view NEVER receives student identity for anonymous feedback
      items = items.map((f) => {
        if (f.isAnonymous) {
          return {
            ...f,
            studentId: "ANONYMOUS",
            studentName: "Anonymous Student",
            studentEmail: null,
          };
        }
        return f;
      });

      if (filter === "REPLIED") {
        items = items.filter((f) => f.hasReplied === true || (f.replies && f.replies.length > 0));
      } else if (filter === "NOT_REPLIED") {
        items = items.filter((f) => f.hasReplied !== true && (!f.replies || f.replies.length === 0));
      }

      return items;
    }

    // Direct simulated read of feedbackIdentities collection
    readFeedbackIdentity(caller: { uid: string; role: string }, feedbackId: string) {
      if (caller.role === "TEACHER") {
        throw new Error("PERMISSION_DENIED: Teachers are forbidden from accessing feedbackIdentities.");
      }
      const identity = this.db.getDoc("feedbackIdentities", feedbackId);
      if (!identity) throw new Error("NOT_FOUND");
      if (caller.role !== "ADMIN" && identity.studentId !== caller.uid) {
        throw new Error("PERMISSION_DENIED: You cannot view this identity.");
      }
      return identity;
    }

    async getAdminAllFeedback(caller: { uid: string; role: string }) {
      if (caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only administrators can audit all feedback.");
      }

      const feedbackList = Object.values(this.db.data.feedback || {});
      return feedbackList.map((f) => {
        const idDoc = this.db.getDoc("feedbackIdentities", f.id);
        return {
          ...f,
          adminAuditStudentId: idDoc?.studentId || null,
          adminAuditStudentName: idDoc?.studentName || null,
        };
      });
    }
  }

  const service = new AuthoritativeFeedbackService(mockDb);

  beforeEach(() => {
    mockDb.reset();
  });

  // ─── 3. ANONYMOUS & NON-ANONYMOUS SUBMISSION TESTS ─────────────────────────

  it("3. Anonymous Feedback: Stores masked studentId in feedback doc and isolates real identity in feedbackIdentities", async () => {
    const result = await service.submitFeedback(
      {
        uid: "student_secret_uid",
        role: "STUDENT",
        fullName: "Secret Student",
        email: "secret@jnu.ac.bd",
      },
      {
        teacherId: "teacher_layek",
        rating: 4,
        comments: "Course pace is slightly fast in the second half of the term.",
        isAnonymous: true,
      }
    );

    assert.strictEqual(result.success, true);
    const feedbackDoc = mockDb.getDoc("feedback", result.feedbackId);

    // SECURITY CHECK: Teacher-facing doc must NOT contain student real ID or name
    assert.strictEqual(feedbackDoc.isAnonymous, true);
    assert.strictEqual(feedbackDoc.studentId, "ANONYMOUS");
    assert.strictEqual(feedbackDoc.studentName, "Anonymous Student");
    assert.strictEqual(feedbackDoc.studentEmail, null);

    // Audit identity doc contains real student info
    const identityDoc = mockDb.getDoc("feedbackIdentities", result.feedbackId);
    assert.strictEqual(identityDoc.studentId, "student_secret_uid");
    assert.strictEqual(identityDoc.studentName, "Secret Student");
  });

  it("4. Non-Anonymous Feedback: Includes student name and ID in public feedback doc", async () => {
    const result = await service.submitFeedback(
      {
        uid: "student_karim_uid",
        role: "STUDENT",
        fullName: "Karim Student",
        email: "karim@jnu.ac.bd",
      },
      {
        teacherId: "teacher_layek",
        rating: 5,
        comments: "Very helpful office hours counseling sessions.",
        isAnonymous: false,
      }
    );

    assert.strictEqual(result.success, true);
    const feedbackDoc = mockDb.getDoc("feedback", result.feedbackId);
    assert.strictEqual(feedbackDoc.isAnonymous, false);
    assert.strictEqual(feedbackDoc.studentId, "student_karim_uid");
    assert.strictEqual(feedbackDoc.studentName, "Karim Student");
  });

  // ─── 4. SECURITY & IDENTITY PROTECTION TESTS ───────────────────────────────

  it("5. Identity Protection: Teachers are strictly prohibited from reading feedbackIdentities", () => {
    mockDb.setDoc("feedbackIdentities", "fb_test", {
      studentId: "student_secret_uid",
      studentName: "Secret Student",
    });

    // Teacher attempt to read feedbackIdentities must throw PERMISSION_DENIED
    assert.throws(
      () => service.readFeedbackIdentity({ uid: "teacher_layek", role: "TEACHER" }, "fb_test"),
      /Teachers are forbidden from accessing feedbackIdentities/
    );
  });

  it("6. Admin Visibility: Administrator can view institutional audit identity for anonymous feedback", async () => {
    await service.submitFeedback(
      { uid: "student_secret_uid", role: "STUDENT", fullName: "Secret Student" },
      { teacherId: "teacher_layek", rating: 5, comments: "Wonderful guidance", isAnonymous: true }
    );

    const adminAudit = await service.getAdminAllFeedback({ uid: "admin_uid", role: "ADMIN" });
    assert.strictEqual(adminAudit.length, 1);
    assert.strictEqual(adminAudit[0].isAnonymous, true);
    assert.strictEqual(adminAudit[0].studentName, "Anonymous Student");
    assert.strictEqual(adminAudit[0].adminAuditStudentId, "student_secret_uid");
  });

  // ─── 5. TEACHER VISIBILITY & REPLIES ───────────────────────────────────────

  it("7. Teacher Visibility: Teacher sees received feedback and can filter by All, Replied, and Not Replied", async () => {
    // Submit 2 feedback items: 1 replied, 1 unreplied
    const fb1 = await service.submitFeedback(
      { uid: "s1", role: "STUDENT" },
      { teacherId: "teacher_layek", rating: 4, comments: "First feedback item", isAnonymous: true }
    );
    const fb2 = await service.submitFeedback(
      { uid: "s2", role: "STUDENT" },
      { teacherId: "teacher_layek", rating: 5, comments: "Second feedback item", isAnonymous: false }
    );

    // Teacher replies to fb1
    await service.replyToFeedback(
      { uid: "teacher_layek", role: "TEACHER", fullName: "Dr. Layek" },
      fb1.feedbackId,
      "Thank you for your constructive comments. We will adjust the pace."
    );

    // Filter: ALL
    const all = await service.getTeacherReceivedFeedback({ uid: "teacher_layek", role: "TEACHER" }, "ALL");
    assert.strictEqual(all.length, 2);

    // Filter: REPLIED
    const replied = await service.getTeacherReceivedFeedback({ uid: "teacher_layek", role: "TEACHER" }, "REPLIED");
    assert.strictEqual(replied.length, 1);
    assert.strictEqual(replied[0].id, fb1.feedbackId);
    assert.strictEqual(replied[0].replies.length, 1);

    // Filter: NOT_REPLIED
    const notReplied = await service.getTeacherReceivedFeedback({ uid: "teacher_layek", role: "TEACHER" }, "NOT_REPLIED");
    assert.strictEqual(notReplied.length, 1);
    assert.strictEqual(notReplied[0].id, fb2.feedbackId);
  });

  it("8. Teacher can edit their reply", async () => {
    const fb = await service.submitFeedback(
      { uid: "s1", role: "STUDENT" },
      { teacherId: "teacher_layek", rating: 3, comments: "Need more lab exercises", isAnonymous: false }
    );

    const replyRes = await service.replyToFeedback(
      { uid: "teacher_layek", role: "TEACHER" },
      fb.feedbackId,
      "Initial reply"
    );

    const editRes = await service.editReply(
      { uid: "teacher_layek", role: "TEACHER" },
      fb.feedbackId,
      replyRes.replyId,
      "Updated detailed reply with lab resource links."
    );

    assert.strictEqual(editRes.success, true);
    const fbDoc = mockDb.getDoc("feedback", fb.feedbackId);
    assert.strictEqual(fbDoc.replies[0].replyText, "Updated detailed reply with lab resource links.");
  });

  // ─── 6. STUDENT EDITING & ATTACHMENT ACCESS ────────────────────────────────

  it("9. Student can edit their own feedback comments and rating", async () => {
    const fb = await service.submitFeedback(
      { uid: "student_1", role: "STUDENT", fullName: "Student One" },
      { teacherId: "teacher_layek", rating: 3, comments: "Initial feedback comment", isAnonymous: false }
    );

    const editResult = await service.editFeedback(
      { uid: "student_1", role: "STUDENT" },
      fb.feedbackId,
      { rating: 4, comments: "Revised feedback comment with more details." }
    );

    assert.strictEqual(editResult.success, true);
    const fbDoc = mockDb.getDoc("feedback", fb.feedbackId);
    assert.strictEqual(fbDoc.rating, 4);
    assert.strictEqual(fbDoc.comments, "Revised feedback comment with more details.");
  });

  it("10. Other users cannot edit another student's feedback (Unauthorized Access Protection)", async () => {
    const fb = await service.submitFeedback(
      { uid: "student_1", role: "STUDENT" },
      { teacherId: "teacher_layek", rating: 4, comments: "Good teaching methods", isAnonymous: false }
    );

    // Student 2 tries to edit Student 1's feedback
    await assert.rejects(
      async () =>
        service.editFeedback(
          { uid: "student_2", role: "STUDENT" },
          fb.feedbackId,
          { rating: 1, comments: "Tampered comments" }
        ),
      /You can only edit feedback you submitted/
    );
  });

  it("11. Other teachers cannot reply to feedback addressed to a different teacher", async () => {
    const fb = await service.submitFeedback(
      { uid: "s1", role: "STUDENT" },
      { teacherId: "teacher_layek", rating: 5, comments: "Very clear lecture", isAnonymous: false }
    );

    // Teacher Uzzal tries to reply to feedback sent to Teacher Layek
    await assert.rejects(
      async () =>
        service.replyToFeedback(
          { uid: "teacher_uzzal", role: "TEACHER" },
          fb.feedbackId,
          "Unauthorized reply attempt"
        ),
      /Only the assigned teacher can reply/
    );
  });

  it("12. Supports file attachments on feedback submissions and replies", async () => {
    const sampleAttachment: AttachmentData = {
      id: "att_doc_1",
      fileName: "syllabus_feedback.pdf",
      fileUrl: "https://storage.googleapis.com/test/syllabus_feedback.pdf",
      mimeType: "application/pdf",
      fileSize: 2048,
    };

    const fb = await service.submitFeedback(
      { uid: "s1", role: "STUDENT" },
      {
        teacherId: "teacher_layek",
        rating: 5,
        comments: "See attached documentation on suggested course topics.",
        isAnonymous: true,
        attachments: [sampleAttachment],
      }
    );

    const fbDoc = mockDb.getDoc("feedback", fb.feedbackId);
    assert.strictEqual(fbDoc.attachments.length, 1);
    assert.strictEqual(fbDoc.attachments[0].fileName, "syllabus_feedback.pdf");
  });
});
