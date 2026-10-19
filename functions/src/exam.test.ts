import { describe, it } from "node:test";
import * as assert from "node:assert";
import {
  validateExamInput,
  getTodayDateUtc6,
  ExamInput,
} from "./exam";
import { parseTimeToMinutes, checkIntervalOverlap } from "./schedule";

describe("STAGE 22: Server-Side Exam System, Authorization & Validation Tests", () => {
  // ─── 1. DATE & TIME UTILITY TESTS ──────────────────────────────────────────

  it("1. getTodayDateUtc6 produces a valid YYYY-MM-DD date string", () => {
    const today = getTodayDateUtc6();
    assert.match(today, /^\d{4}-\d{2}-\d{2}$/);
  });

  // ─── 2. INPUT VALIDATION TESTS ─────────────────────────────────────────────

  it("2. validateExamInput succeeds on valid data", () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const validData: ExamInput = {
      courseId: "cse-3101",
      title: "Mid-Term Examination",
      examDate: tomorrow,
      startTime: "10:00 AM",
      endTime: "12:00 PM",
      room: "Room 401",
      year: 3,
      semester: 1,
      type: "MID_TERM",
      instructions: "Calculators allowed",
    };

    const validated = validateExamInput(validData, true);
    assert.strictEqual(validated.courseId, "cse-3101");
    assert.strictEqual(validated.title, "Mid-Term Examination");
    assert.strictEqual(validated.room, "Room 401");
    assert.strictEqual(validated.year, 3);
    assert.strictEqual(validated.semester, 1);
    assert.strictEqual(validated.type, "MID_TERM");
    assert.strictEqual(validated.startMinutes, 600); // 10:00 AM
    assert.strictEqual(validated.endMinutes, 720); // 12:00 PM
  });

  it("3. validateExamInput rejects missing courseId or empty title", () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    assert.throws(
      () => validateExamInput({ courseId: "", title: "Exam", examDate: tomorrow, startTime: "10:00", endTime: "12:00", room: "401", year: 3, semester: 1 }),
      /Course ID is required/
    );
    assert.throws(
      () => validateExamInput({ courseId: "cse-1", title: "   ", examDate: tomorrow, startTime: "10:00", endTime: "12:00", room: "401", year: 3, semester: 1 }),
      /Exam title is required/
    );
  });

  it("4. validateExamInput rejects invalid examDate format or past date", () => {
    assert.throws(
      () => validateExamInput({ courseId: "c1", title: "Exam", examDate: "invalid-date", startTime: "10:00", endTime: "12:00", room: "401", year: 3, semester: 1 }),
      /Valid exam date/
    );

    // Past date (e.g. 2020-01-01)
    assert.throws(
      () => validateExamInput({ courseId: "c1", title: "Exam", examDate: "2020-01-01", startTime: "10:00", endTime: "12:00", room: "401", year: 3, semester: 1 }, true),
      /Cannot schedule an exam on a past date/
    );
  });

  it("5. validateExamInput rejects end time before/equal to start time", () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    assert.throws(
      () => validateExamInput({ courseId: "c1", title: "Exam", examDate: tomorrow, startTime: "12:00 PM", endTime: "10:00 AM", room: "401", year: 3, semester: 1 }),
      /End time must be after start time/
    );
    assert.throws(
      () => validateExamInput({ courseId: "c1", title: "Exam", examDate: tomorrow, startTime: "10:00 AM", endTime: "10:00 AM", room: "401", year: 3, semester: 1 }),
      /End time must be after start time/
    );
  });

  it("6. validateExamInput rejects durations < 15 mins or > 300 mins (5 hours)", () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    // 10 minutes duration
    assert.throws(
      () => validateExamInput({ courseId: "c1", title: "Exam", examDate: tomorrow, startTime: "10:00 AM", endTime: "10:10 AM", room: "401", year: 3, semester: 1 }),
      /Exam duration must be between 15 minutes and 5 hours/
    );
    // 6 hours duration
    assert.throws(
      () => validateExamInput({ courseId: "c1", title: "Exam", examDate: tomorrow, startTime: "09:00 AM", endTime: "03:30 PM", room: "401", year: 3, semester: 1 }),
      /Exam duration must be between 15 minutes and 5 hours/
    );
  });

  it("7. validateExamInput rejects out-of-range academic year or semester", () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    assert.throws(
      () => validateExamInput({ courseId: "c1", title: "Exam", examDate: tomorrow, startTime: "10:00", endTime: "12:00", room: "401", year: 0, semester: 1 }),
      /Year must be between 1 and 5/
    );
    assert.throws(
      () => validateExamInput({ courseId: "c1", title: "Exam", examDate: tomorrow, startTime: "10:00", endTime: "12:00", room: "401", year: 6, semester: 1 }),
      /Year must be between 1 and 5/
    );
    assert.throws(
      () => validateExamInput({ courseId: "c1", title: "Exam", examDate: tomorrow, startTime: "10:00", endTime: "12:00", room: "401", year: 3, semester: 4 }),
      /Semester must be between 1 and 3/
    );
  });

  // ─── 3. MOCK FIRESTORE & CORE SERVICE BEHAVIOR TESTS ────────────────────────

  class MockFirestore {
    data: { [col: string]: { [id: string]: any } } = {
      users: {},
      courses: {},
      exams: {},
    };

    reset() {
      this.data = { users: {}, courses: {}, exams: {} };
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

  const mockDb = new MockFirestore();

  class AuthoritativeExamService {
    db: MockFirestore;
    constructor(db: MockFirestore) {
      this.db = db;
    }

    async createExam(callerUid: string, data: any) {
      const user = this.db.getDoc("users", callerUid);
      if (!user) throw new Error("UNAUTHENTICATED");

      const role = (user.role || "STUDENT").toUpperCase();
      const userYear = Number(user.year);
      const userSemester = Number(user.semester);
      const assignedCourses: string[] = user.assignedCourseIds || [];

      if (role === "STUDENT") {
        throw new Error("PERMISSION_DENIED: Regular students cannot schedule exams.");
      }

      const validated = validateExamInput(data, true);

      if (role === "CR") {
        if (userYear !== validated.year || userSemester !== validated.semester) {
          throw new Error(`PERMISSION_DENIED: CR cannot schedule for other cohorts.`);
        }
      } else if (role === "TEACHER") {
        if (!assignedCourses.includes(validated.courseId)) {
          throw new Error("PERMISSION_DENIED: Teacher can only schedule for assigned courses.");
        }
      }

      // Check course
      const course = this.db.getDoc("courses", validated.courseId);
      if (course && role === "CR") {
        if (Number(course.year) !== validated.year || Number(course.semester) !== validated.semester) {
          throw new Error("INVALID_ARGUMENT: Selected course does not belong to your academic cohort.");
        }
      }

      // Check collision
      const existingExams = Object.values(this.db.data["exams"] || {});
      for (const existing of existingExams) {
        if (existing.examDate === validated.examDate) {
          const existStart = parseTimeToMinutes(existing.startTime);
          const existEnd = parseTimeToMinutes(existing.endTime);

          if (checkIntervalOverlap(validated.startMinutes, validated.endMinutes, existStart, existEnd)) {
            if (existing.room.toUpperCase() === validated.room.toUpperCase()) {
              throw new Error(`ALREADY_EXISTS: Room Collision in ${validated.room}.`);
            }
            if (Number(existing.year) === validated.year && Number(existing.semester) === validated.semester) {
              throw new Error(`ALREADY_EXISTS: Cohort Collision for Year ${validated.year} Semester ${validated.semester}.`);
            }
          }
        }
      }

      const examId = "exam_" + Math.random().toString(36).slice(2, 9);
      const newExam = {
        id: examId,
        ...validated,
        createdBy: callerUid,
        creatorRole: role,
        courseCode: course?.code || validated.courseId,
        courseTitle: course?.title || validated.title,
        startTime: validated.normStartTime,
        endTime: validated.normEndTime,
      };

      this.db.setDoc("exams", examId, newExam);
      return newExam;
    }

    async updateExam(callerUid: string, examId: string, data: any) {
      const user = this.db.getDoc("users", callerUid);
      if (!user) throw new Error("UNAUTHENTICATED");

      const role = (user.role || "STUDENT").toUpperCase();
      const existing = this.db.getDoc("exams", examId);
      if (!existing) throw new Error("NOT_FOUND: Exam not found.");

      if (role === "ADMIN") {
        // allowed
      } else if (role === "CR") {
        if (Number(user.year) !== Number(existing.year) || Number(user.semester) !== Number(existing.semester)) {
          throw new Error("PERMISSION_DENIED: CR cannot edit exam of another cohort.");
        }
      } else if (role === "TEACHER") {
        const assigned: string[] = user.assignedCourseIds || [];
        if (!assigned.includes(existing.courseId) && existing.createdBy !== callerUid) {
          throw new Error("PERMISSION_DENIED: Teacher not assigned to course.");
        }
      } else if (existing.createdBy !== callerUid) {
        throw new Error("PERMISSION_DENIED: User cannot edit exam.");
      }

      const validated = validateExamInput(data, false);

      // Check collision excluding this exam
      const allExams = Object.values(this.db.data["exams"] || {});
      for (const ex of allExams) {
        if (ex.id !== examId && ex.examDate === validated.examDate) {
          const existStart = parseTimeToMinutes(ex.startTime);
          const existEnd = parseTimeToMinutes(ex.endTime);

          if (checkIntervalOverlap(validated.startMinutes, validated.endMinutes, existStart, existEnd)) {
            if (ex.room.toUpperCase() === validated.room.toUpperCase()) {
              throw new Error(`ALREADY_EXISTS: Room Collision in ${validated.room}.`);
            }
            if (Number(ex.year) === validated.year && Number(ex.semester) === validated.semester) {
              throw new Error(`ALREADY_EXISTS: Cohort Collision.`);
            }
          }
        }
      }

      const updated = {
        ...existing,
        ...validated,
        startTime: validated.normStartTime,
        endTime: validated.normEndTime,
        updatedBy: callerUid,
      };
      this.db.setDoc("exams", examId, updated);
      return updated;
    }

    async deleteExam(callerUid: string, examId: string) {
      const user = this.db.getDoc("users", callerUid);
      if (!user) throw new Error("UNAUTHENTICATED");

      const role = (user.role || "STUDENT").toUpperCase();
      const existing = this.db.getDoc("exams", examId);
      if (!existing) throw new Error("NOT_FOUND: Exam not found.");

      if (role === "ADMIN") {
        // allowed
      } else if (role === "CR") {
        if (Number(user.year) !== Number(existing.year) || Number(user.semester) !== Number(existing.semester)) {
          throw new Error("PERMISSION_DENIED: CR cannot delete exam of another cohort.");
        }
      } else if (role === "TEACHER") {
        const assigned: string[] = user.assignedCourseIds || [];
        if (!assigned.includes(existing.courseId) && existing.createdBy !== callerUid) {
          throw new Error("PERMISSION_DENIED: Teacher not assigned to course.");
        }
      } else if (existing.createdBy !== callerUid) {
        throw new Error("PERMISSION_DENIED: User cannot delete exam.");
      }

      this.db.deleteDoc("exams", examId);
      return { success: true };
    }
  }

  const service = new AuthoritativeExamService(mockDb);

  it("8. Regular student is strictly prevented from creating an exam", async () => {
    mockDb.reset();
    mockDb.setDoc("users", "student_1", {
      fullName: "Sajib Student",
      role: "STUDENT",
      year: 3,
      semester: 1,
    });

    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    await assert.rejects(
      service.createExam("student_1", {
        courseId: "cse-3101",
        title: "Mid-Term",
        examDate: tomorrow,
        startTime: "10:00 AM",
        endTime: "12:00 PM",
        room: "Room 401",
        year: 3,
        semester: 1,
      }),
      /PERMISSION_DENIED: Regular students cannot schedule exams/
    );
  });

  it("9. CR can schedule an exam for their own cohort", async () => {
    mockDb.reset();
    mockDb.setDoc("users", "cr_3_1", {
      fullName: "Sabbir CR",
      role: "CR",
      year: 3,
      semester: 1,
    });
    mockDb.setDoc("courses", "cse-3101", {
      code: "CSE 3101",
      title: "Operating Systems",
      year: 3,
      semester: 1,
    });

    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const exam = await service.createExam("cr_3_1", {
      courseId: "cse-3101",
      title: "Mid-Term Examination",
      examDate: tomorrow,
      startTime: "10:00 AM",
      endTime: "12:00 PM",
      room: "Room 401",
      year: 3,
      semester: 1,
      type: "MID_TERM",
    });

    assert.ok(exam.id);
    assert.strictEqual(exam.courseCode, "CSE 3101");
    assert.strictEqual(exam.year, 3);
    assert.strictEqual(exam.semester, 1);
  });

  it("10. CR cannot schedule an exam for another cohort", async () => {
    mockDb.reset();
    mockDb.setDoc("users", "cr_3_1", {
      fullName: "Sabbir CR",
      role: "CR",
      year: 3,
      semester: 1,
    });

    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    await assert.rejects(
      service.createExam("cr_3_1", {
        courseId: "cse-4101",
        title: "Compiler Design Exam",
        examDate: tomorrow,
        startTime: "10:00 AM",
        endTime: "12:00 PM",
        room: "Room 401",
        year: 4, // different year
        semester: 1,
      }),
      /PERMISSION_DENIED: CR cannot schedule for other cohorts/
    );
  });

  it("11. Teacher can schedule for assigned course, but rejected for unassigned course", async () => {
    mockDb.reset();
    mockDb.setDoc("users", "teacher_1", {
      fullName: "Dr. Anisur Rahman",
      role: "TEACHER",
      assignedCourseIds: ["cse-3101", "cse-3103"],
    });

    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);

    // Assigned course succeeds
    const exam = await service.createExam("teacher_1", {
      courseId: "cse-3101",
      title: "Class Test 1",
      examDate: tomorrow,
      startTime: "09:00 AM",
      endTime: "10:00 AM",
      room: "Room 402",
      year: 3,
      semester: 1,
      type: "CT",
    });
    assert.ok(exam.id);

    // Unassigned course rejected
    await assert.rejects(
      service.createExam("teacher_1", {
        courseId: "cse-4101",
        title: "Final Exam",
        examDate: tomorrow,
        startTime: "10:00 AM",
        endTime: "12:00 PM",
        room: "Room 501",
        year: 4,
        semester: 1,
      }),
      /PERMISSION_DENIED: Teacher can only schedule for assigned courses/
    );
  });

  it("12. Admin has unrestricted creation rights for any cohort and course", async () => {
    mockDb.reset();
    mockDb.setDoc("users", "admin_1", {
      fullName: "Department Admin",
      role: "ADMIN",
    });

    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const exam = await service.createExam("admin_1", {
      courseId: "cse-2201",
      title: "Semester Final",
      examDate: tomorrow,
      startTime: "02:00 PM",
      endTime: "05:00 PM",
      room: "Main Exam Hall A",
      year: 2,
      semester: 2,
      type: "FINAL",
    });
    assert.ok(exam.id);
    assert.strictEqual(exam.creatorRole, "ADMIN");
  });

  it("13. Detects and prevents room collisions on the same date and overlapping time", async () => {
    mockDb.reset();
    mockDb.setDoc("users", "admin_1", { role: "ADMIN" });

    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);

    // Book Room 401 for 10:00 AM - 12:00 PM
    await service.createExam("admin_1", {
      courseId: "cse-3101",
      title: "OS Mid-Term",
      examDate: tomorrow,
      startTime: "10:00 AM",
      endTime: "12:00 PM",
      room: "Room 401",
      year: 3,
      semester: 1,
    });

    // Try booking Room 401 for 11:00 AM - 01:00 PM (overlaps)
    await assert.rejects(
      service.createExam("admin_1", {
        courseId: "cse-2101",
        title: "DS Quiz",
        examDate: tomorrow,
        startTime: "11:00 AM",
        endTime: "01:00 PM",
        room: "Room 401",
        year: 2,
        semester: 1,
      }),
      /ALREADY_EXISTS: Room Collision in Room 401/
    );

    // Non-overlapping room booking succeeds (e.g. 12:00 PM - 02:00 PM back-to-back)
    const validNext = await service.createExam("admin_1", {
      courseId: "cse-2101",
      title: "DS Quiz",
      examDate: tomorrow,
      startTime: "12:00 PM",
      endTime: "01:00 PM",
      room: "Room 401",
      year: 2,
      semester: 1,
    });
    assert.ok(validNext.id);
  });

  it("14. Detects and prevents cohort collisions (same year & semester at same time)", async () => {
    mockDb.reset();
    mockDb.setDoc("users", "admin_1", { role: "ADMIN" });

    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);

    // Schedule Year 3 Semester 1 exam in Room 401
    await service.createExam("admin_1", {
      courseId: "cse-3101",
      title: "OS Mid-Term",
      examDate: tomorrow,
      startTime: "10:00 AM",
      endTime: "12:00 PM",
      room: "Room 401",
      year: 3,
      semester: 1,
    });

    // Try scheduling another Year 3 Semester 1 exam in Room 402 at same time
    await assert.rejects(
      service.createExam("admin_1", {
        courseId: "cse-3103",
        title: "Algorithms Mid-Term",
        examDate: tomorrow,
        startTime: "10:30 AM",
        endTime: "12:30 PM",
        room: "Room 402",
        year: 3,
        semester: 1,
      }),
      /ALREADY_EXISTS: Cohort Collision for Year 3 Semester 1/
    );
  });

  it("15. Exam update and delete authorization rules are properly enforced", async () => {
    mockDb.reset();
    mockDb.setDoc("users", "cr_3_1", { role: "CR", year: 3, semester: 1 });
    mockDb.setDoc("users", "cr_4_1", { role: "CR", year: 4, semester: 1 });
    mockDb.setDoc("users", "student_1", { role: "STUDENT", year: 3, semester: 1 });
    mockDb.setDoc("users", "admin_1", { role: "ADMIN" });

    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);

    // CR 3-1 creates exam
    const exam = await service.createExam("cr_3_1", {
      courseId: "cse-3101",
      title: "OS Mid-Term",
      examDate: tomorrow,
      startTime: "10:00 AM",
      endTime: "12:00 PM",
      room: "Room 401",
      year: 3,
      semester: 1,
    });

    // Student cannot update or delete
    await assert.rejects(
      service.updateExam("student_1", exam.id, { ...exam, title: "Modified Title" }),
      /PERMISSION_DENIED/
    );
    await assert.rejects(
      service.deleteExam("student_1", exam.id),
      /PERMISSION_DENIED/
    );

    // CR from different cohort cannot update or delete
    await assert.rejects(
      service.updateExam("cr_4_1", exam.id, { ...exam, title: "Modified Title" }),
      /PERMISSION_DENIED: CR cannot edit exam of another cohort/
    );
    await assert.rejects(
      service.deleteExam("cr_4_1", exam.id),
      /PERMISSION_DENIED: CR cannot delete exam of another cohort/
    );

    // Authorized CR can update
    const updated = await service.updateExam("cr_3_1", exam.id, {
      ...exam,
      title: "OS Mid-Term (Updated)",
      room: "Room 402",
    });
    assert.strictEqual(updated.title, "OS Mid-Term (Updated)");
    assert.strictEqual(updated.room, "Room 402");

    // Admin can delete
    const deleteRes = await service.deleteExam("admin_1", exam.id);
    assert.strictEqual(deleteRes.success, true);
    assert.strictEqual(mockDb.getDoc("exams", exam.id), null);
  });
});
