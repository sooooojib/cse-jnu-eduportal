import { describe, it } from "node:test";
import * as assert from "node:assert";
import {
  parseTimeToMinutes,
  checkIntervalOverlap,
  getTomorrowInfo,
} from "./schedule";

describe("STAGE 21: Server-Side Schedule System & Conflict Protection Tests", () => {
  // ─── 1. TIME PARSING & INTERVAL OVERLAP TESTS ────────────────────────────────

  it("1. parseTimeToMinutes correctly parses 24h and 12h time formats", () => {
    assert.strictEqual(parseTimeToMinutes("09:00"), 540);
    assert.strictEqual(parseTimeToMinutes("10:30"), 630);
    assert.strictEqual(parseTimeToMinutes("14:45"), 885);
    assert.strictEqual(parseTimeToMinutes("09:00 AM"), 540);
    assert.strictEqual(parseTimeToMinutes("12:00 PM"), 720); // noon
    assert.strictEqual(parseTimeToMinutes("12:30 AM"), 30);  // post midnight
    assert.strictEqual(parseTimeToMinutes("02:30 PM"), 870);
  });

  it("2. checkIntervalOverlap correctly identifies overlaps and adjacent intervals", () => {
    // Overlapping: 09:00-10:30 (540-630) and 10:00-11:30 (600-690)
    assert.strictEqual(checkIntervalOverlap(540, 630, 600, 690), true);

    // Contained: 09:00-12:00 and 10:00-11:00
    assert.strictEqual(checkIntervalOverlap(540, 720, 600, 660), true);

    // Adjacent back-to-back: 09:00-10:30 and 10:30-12:00 -> NO OVERLAP
    assert.strictEqual(checkIntervalOverlap(540, 630, 630, 720), false);

    // Distinct: 09:00-10:00 and 13:00-14:00
    assert.strictEqual(checkIntervalOverlap(540, 600, 780, 840), false);
  });

  it("3. getTomorrowInfo accurately calculates tomorrow date and day of week in UTC+6", () => {
    const info = getTomorrowInfo();
    assert.ok(info.todayDate, "Must provide todayDate");
    assert.ok(info.tomorrowDate, "Must provide tomorrowDate");
    assert.ok(info.tomorrowDayOfWeek, "Must provide tomorrowDayOfWeek");
    assert.match(info.tomorrowDate, /^\d{4}-\d{2}-\d{2}$/);
    assert.match(info.tomorrowDayOfWeek, /^(SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)$/);
  });

  // ─── 2. TRANSACTIONAL MOCK SERVICE MIRRORING CLOUD FUNCTIONS ─────────────────

  class MockFirestore {
    data: { [col: string]: { [id: string]: any } } = {
      users: {},
      courses: {},
      schedules: {},
    };

    reset() {
      this.data = { users: {}, courses: {}, schedules: {} };
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

  class AuthoritativeScheduleService {
    db: MockFirestore;
    constructor(db: MockFirestore) {
      this.db = db;
    }

    async createSlot(auth: { uid: string; role: string }, payload: any) {
      if (!auth) throw new Error("UNAUTHENTICATED");
      const user = this.db.getDoc("users", auth.uid);
      if (!user) throw new Error("USER_NOT_FOUND");
      const userRole = (user.role || auth.role).toUpperCase();

      if (userRole !== "CR" && userRole !== "TEACHER" && userRole !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only CR, Teachers, and Admins can schedule.");
      }

      const { courseId, dayOfWeek, startTime, endTime, room, targetYear, targetSemester, date } = payload;
      if (!courseId || !dayOfWeek || !startTime || !endTime || !room || !targetYear || !targetSemester) {
        throw new Error("INVALID_ARGUMENT: Missing required fields.");
      }

      const startMins = parseTimeToMinutes(startTime);
      const endMins = parseTimeToMinutes(endTime);
      if (startMins >= endMins) throw new Error("INVALID_ARGUMENT: startTime must precede endTime.");

      const normDay = dayOfWeek.trim().toUpperCase();
      const { tomorrowDate, tomorrowDayOfWeek } = getTomorrowInfo();

      // CR Tomorrow-Only Rule
      if (userRole === "CR") {
        if (normDay !== tomorrowDayOfWeek) {
          throw new Error(`CR_TOMORROW_ONLY: CR can only schedule for tomorrow (${tomorrowDayOfWeek}).`);
        }
        if (date && date !== tomorrowDate) {
          throw new Error(`CR_TOMORROW_ONLY: CR can only schedule for tomorrow (${tomorrowDate}).`);
        }
        if (user.year !== targetYear || user.semester !== targetSemester) {
          throw new Error(`CR_COHORT_MISMATCH: Cannot schedule for other cohorts.`);
        }
      }

      // Teacher assigned course check
      if (userRole === "TEACHER" && userRole !== "ADMIN") {
        const assigned: string[] = user.assignedCourseIds || [];
        if (!assigned.includes(courseId)) {
          throw new Error(`TEACHER_UNAUTHORIZED: Course not assigned to this teacher.`);
        }
      }

      // Course check
      const course = this.db.getDoc("courses", courseId);
      if (!course) throw new Error(`COURSE_NOT_FOUND: Course "${courseId}" does not exist.`);

      // Teacher check
      const teacherId = payload.teacherId || course.teacherId;
      if (teacherId) {
        const teacher = this.db.getDoc("users", teacherId);
        if (!teacher) throw new Error("TEACHER_NOT_FOUND");
      }

      // Conflict checks
      const cleanRoom = room.trim();
      const existing = Object.values(this.db.data.schedules || {}).filter((s: any) => s.dayOfWeek === normDay);

      for (const slot of existing) {
        const slotStart = parseTimeToMinutes(slot.startTime);
        const slotEnd = parseTimeToMinutes(slot.endTime);

        if (checkIntervalOverlap(startMins, endMins, slotStart, slotEnd)) {
          if (slot.room.toLowerCase() === cleanRoom.toLowerCase()) {
            throw new Error(`ROOM_CONFLICT: ${cleanRoom} is already booked.`);
          }
          if (teacherId && slot.teacherId === teacherId) {
            throw new Error(`TEACHER_CONFLICT: Faculty is already teaching another class.`);
          }
          if (slot.targetYear === targetYear && slot.targetSemester === targetSemester) {
            throw new Error(`COHORT_CONFLICT: Cohort already has another class scheduled.`);
          }
        }
      }

      const slotId = `slot_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      const newSlot = {
        id: slotId,
        courseId,
        courseCode: course.code,
        courseTitle: course.title,
        teacherId,
        teacherName: payload.teacherName || course.teacherName || "Faculty",
        dayOfWeek: normDay,
        startTime,
        endTime,
        room: cleanRoom,
        targetYear,
        targetSemester,
        isExtraClass: Boolean(payload.isExtraClass),
        date: date || (userRole === "CR" ? tomorrowDate : null),
        createdBy: auth.uid,
      };

      this.db.setDoc("schedules", slotId, newSlot);
      return { success: true, slotId, slot: newSlot };
    }

    async deleteSlot(auth: { uid: string; role: string }, slotId: string) {
      if (!auth) throw new Error("UNAUTHENTICATED");
      const user = this.db.getDoc("users", auth.uid);
      if (!user) throw new Error("USER_NOT_FOUND");
      const userRole = (user.role || auth.role).toUpperCase();

      const slot = this.db.getDoc("schedules", slotId);
      if (!slot) throw new Error("NOT_FOUND");

      if (userRole === "STUDENT") throw new Error("PERMISSION_DENIED");
      if (userRole === "TEACHER" && userRole !== "ADMIN") {
        const assigned: string[] = user.assignedCourseIds || [];
        if (!assigned.includes(slot.courseId)) throw new Error("PERMISSION_DENIED");
      }
      if (userRole === "CR") {
        if (slot.createdBy !== auth.uid && slot.targetYear !== user.year) throw new Error("PERMISSION_DENIED");
      }

      this.db.deleteDoc("schedules", slotId);
      return { success: true };
    }

    async getAvailability(teacherId: string, dayOfWeek: string) {
      const teacher = this.db.getDoc("users", teacherId);
      if (!teacher) throw new Error("TEACHER_NOT_FOUND");

      const normDay = dayOfWeek.trim().toUpperCase();
      const slots = Object.values(this.db.data.schedules || {}).filter(
        (s: any) => s.teacherId === teacherId && s.dayOfWeek === normDay
      );

      const busy = slots.map((s: any) => ({
        id: s.id,
        courseCode: s.courseCode,
        startTime: s.startTime,
        endTime: s.endTime,
        startMins: parseTimeToMinutes(s.startTime),
        endMins: parseTimeToMinutes(s.endTime),
      }));

      busy.sort((a, b) => a.startMins - b.endMins);

      const DAY_START = 480; // 08:00
      const DAY_END = 1020;  // 17:00
      const availableWindows: any[] = [];
      let pointer = DAY_START;

      for (const b of busy) {
        if (b.startMins > pointer) {
          availableWindows.push({
            startMins: pointer,
            endMins: b.startMins,
            duration: b.startMins - pointer,
          });
        }
        pointer = Math.max(pointer, b.endMins);
      }
      if (pointer < DAY_END) {
        availableWindows.push({
          startMins: pointer,
          endMins: DAY_END,
          duration: DAY_END - pointer,
        });
      }

      return { teacherId, dayOfWeek: normDay, busy, availableWindows };
    }
  }

  const service = new AuthoritativeScheduleService(mockDb);

  function seedDb() {
    mockDb.reset();
    mockDb.setDoc("users", "admin_1", {
      fullName: "Department Admin",
      role: "ADMIN",
    });
    mockDb.setDoc("users", "teacher_layek", {
      fullName: "Dr. Md. Abu Layek",
      role: "TEACHER",
      assignedCourseIds: ["CSE-3101", "CSE-3102"],
    });
    mockDb.setDoc("users", "teacher_hasan", {
      fullName: "Prof. Hasan",
      role: "TEACHER",
      assignedCourseIds: ["CSE-3103"],
    });
    mockDb.setDoc("users", "cr_tanvir", {
      fullName: "Tanvir Ahmed",
      role: "CR",
      year: 3,
      semester: 1,
    });
    mockDb.setDoc("users", "student_rahim", {
      fullName: "Rahim Khan",
      role: "STUDENT",
      year: 3,
      semester: 1,
    });

    mockDb.setDoc("courses", "CSE-3101", {
      code: "CSE-3101",
      title: "Operating Systems",
      teacherId: "teacher_layek",
      teacherName: "Dr. Md. Abu Layek",
      year: 3,
      semester: 1,
    });
    mockDb.setDoc("courses", "CSE-3103", {
      code: "CSE-3103",
      title: "Artificial Intelligence",
      teacherId: "teacher_hasan",
      teacherName: "Prof. Hasan",
      year: 3,
      semester: 1,
    });
  }

  // ─── 3. AUTHORITATIVE BUSINESS RULE TESTS ────────────────────────────────────

  it("4. Unauthorized Student is prevented from creating schedule slots", async () => {
    seedDb();
    const { tomorrowDayOfWeek } = getTomorrowInfo();

    await assert.rejects(
      service.createSlot({ uid: "student_rahim", role: "STUDENT" }, {
        courseId: "CSE-3101",
        dayOfWeek: tomorrowDayOfWeek,
        startTime: "09:00",
        endTime: "10:30",
        room: "Room 401",
        targetYear: 3,
        targetSemester: 1,
      }),
      /PERMISSION_DENIED/,
      "Students must not be allowed to schedule classes"
    );
  });

  it("5. CR Tomorrow-Only Rule: CR successfully schedules for tomorrow", async () => {
    seedDb();
    const { tomorrowDate, tomorrowDayOfWeek } = getTomorrowInfo();

    const result = await service.createSlot({ uid: "cr_tanvir", role: "CR" }, {
      courseId: "CSE-3101",
      dayOfWeek: tomorrowDayOfWeek,
      date: tomorrowDate,
      startTime: "09:00 AM",
      endTime: "10:30 AM",
      room: "Room 402",
      targetYear: 3,
      targetSemester: 1,
    });

    assert.strictEqual(result.success, true);
    assert.strictEqual(result.slot.room, "Room 402");
    assert.strictEqual(result.slot.courseCode, "CSE-3101");
  });

  it("6. CR Tomorrow-Only Rule: Rejects CR scheduling for today or past days", async () => {
    seedDb();
    const { todayDate } = getTomorrowInfo();

    await assert.rejects(
      service.createSlot({ uid: "cr_tanvir", role: "CR" }, {
        courseId: "CSE-3101",
        dayOfWeek: "SUNDAY",
        date: todayDate, // Not tomorrow
        startTime: "10:30",
        endTime: "12:00",
        room: "Room 402",
        targetYear: 3,
        targetSemester: 1,
      }),
      /CR_TOMORROW_ONLY/,
      "Server-side check must reject any day other than tomorrow"
    );
  });

  it("7. CR Cohort Lock: Rejects CR scheduling for a different year or semester", async () => {
    seedDb();
    const { tomorrowDate, tomorrowDayOfWeek } = getTomorrowInfo();

    await assert.rejects(
      service.createSlot({ uid: "cr_tanvir", role: "CR" }, {
        courseId: "CSE-3101",
        dayOfWeek: tomorrowDayOfWeek,
        date: tomorrowDate,
        startTime: "14:00",
        endTime: "15:30",
        room: "Room 402",
        targetYear: 4, // CR is registered in Year 3
        targetSemester: 1,
      }),
      /CR_COHORT_MISMATCH/,
      "CR must be prohibited from scheduling for other batches"
    );
  });

  it("8. Teacher Authorization: Teacher can schedule assigned courses but not unassigned courses", async () => {
    seedDb();

    // Assigned course (CSE-3101) -> Success
    const res = await service.createSlot({ uid: "teacher_layek", role: "TEACHER" }, {
      courseId: "CSE-3101",
      dayOfWeek: "MONDAY",
      startTime: "10:30",
      endTime: "12:00",
      room: "Room 403",
      targetYear: 3,
      targetSemester: 1,
    });
    assert.strictEqual(res.success, true);

    // Unassigned course (CSE-3103 assigned to Prof. Hasan) -> Rejected
    await assert.rejects(
      service.createSlot({ uid: "teacher_layek", role: "TEACHER" }, {
        courseId: "CSE-3103",
        dayOfWeek: "MONDAY",
        startTime: "14:00",
        endTime: "15:30",
        room: "Room 403",
        targetYear: 3,
        targetSemester: 1,
      }),
      /TEACHER_UNAUTHORIZED/
    );
  });

  it("9. Collision Protection: Room Collision is prevented", async () => {
    seedDb();
    // Schedule slot 1: Room 401 on SUNDAY from 09:00 to 10:30
    await service.createSlot({ uid: "admin_1", role: "ADMIN" }, {
      courseId: "CSE-3101",
      dayOfWeek: "SUNDAY",
      startTime: "09:00",
      endTime: "10:30",
      room: "Room 401",
      targetYear: 3,
      targetSemester: 1,
    });

    // Schedule slot 2: Same Room 401 on SUNDAY from 10:00 to 11:30 (overlaps by 30 mins!)
    await assert.rejects(
      service.createSlot({ uid: "admin_1", role: "ADMIN" }, {
        courseId: "CSE-3103",
        dayOfWeek: "SUNDAY",
        startTime: "10:00",
        endTime: "11:30",
        room: "Room 401",
        targetYear: 2,
        targetSemester: 1,
      }),
      /ROOM_CONFLICT/,
      "Must prevent double-booking the same room during overlapping times"
    );
  });

  it("10. Collision Protection: Teacher Collision is prevented", async () => {
    seedDb();
    // Schedule Dr. Layek on SUNDAY 09:00 - 10:30 in Room 401
    await service.createSlot({ uid: "teacher_layek", role: "TEACHER" }, {
      courseId: "CSE-3101",
      dayOfWeek: "SUNDAY",
      startTime: "09:00",
      endTime: "10:30",
      room: "Room 401",
      targetYear: 3,
      targetSemester: 1,
    });

    // Attempt to schedule Dr. Layek simultaneously in Room 402 for another batch
    await assert.rejects(
      service.createSlot({ uid: "admin_1", role: "ADMIN" }, {
        courseId: "CSE-3101",
        teacherId: "teacher_layek",
        dayOfWeek: "SUNDAY",
        startTime: "09:30",
        endTime: "11:00",
        room: "Room 402",
        targetYear: 4,
        targetSemester: 1,
      }),
      /TEACHER_CONFLICT/,
      "Must prevent scheduling the same faculty member in two places at once"
    );
  });

  it("11. Collision Protection: Cohort Collision is prevented", async () => {
    seedDb();
    // Year 3 Sem 1 has CSE-3101 on SUNDAY 09:00 - 10:30
    await service.createSlot({ uid: "admin_1", role: "ADMIN" }, {
      courseId: "CSE-3101",
      dayOfWeek: "SUNDAY",
      startTime: "09:00",
      endTime: "10:30",
      room: "Room 401",
      targetYear: 3,
      targetSemester: 1,
    });

    // Attempt to schedule another class for Year 3 Sem 1 at 09:30 in a different room
    await assert.rejects(
      service.createSlot({ uid: "admin_1", role: "ADMIN" }, {
        courseId: "CSE-3103",
        dayOfWeek: "SUNDAY",
        startTime: "09:30",
        endTime: "11:00",
        room: "Room 501",
        targetYear: 3,
        targetSemester: 1,
      }),
      /COHORT_CONFLICT/,
      "Students cannot attend two classes at the same time"
    );
  });

  it("12. Non-overlapping back-to-back classes in the same room succeed without conflict", async () => {
    seedDb();
    // Class 1: 09:00 - 10:30 in Room 401
    const s1 = await service.createSlot({ uid: "admin_1", role: "ADMIN" }, {
      courseId: "CSE-3101",
      dayOfWeek: "SUNDAY",
      startTime: "09:00",
      endTime: "10:30",
      room: "Room 401",
      targetYear: 3,
      targetSemester: 1,
    });
    assert.strictEqual(s1.success, true);

    // Class 2: 10:30 - 12:00 in the same Room 401 (back-to-back!)
    const s2 = await service.createSlot({ uid: "admin_1", role: "ADMIN" }, {
      courseId: "CSE-3103",
      dayOfWeek: "SUNDAY",
      startTime: "10:30",
      endTime: "12:00",
      room: "Room 401",
      targetYear: 2,
      targetSemester: 1,
    });
    assert.strictEqual(s2.success, true);
  });

  it("13. Slot Deletion: Unauthorized users cannot delete, authorized users can delete", async () => {
    seedDb();
    const { slotId } = await service.createSlot({ uid: "admin_1", role: "ADMIN" }, {
      courseId: "CSE-3101",
      dayOfWeek: "WEDNESDAY",
      startTime: "11:00",
      endTime: "12:30",
      room: "Room 401",
      targetYear: 3,
      targetSemester: 1,
    });

    // Student tries to delete -> Rejected
    await assert.rejects(
      service.deleteSlot({ uid: "student_rahim", role: "STUDENT" }, slotId),
      /PERMISSION_DENIED/
    );

    // Admin deletes -> Success
    const delRes = await service.deleteSlot({ uid: "admin_1", role: "ADMIN" }, slotId);
    assert.strictEqual(delRes.success, true);
    assert.strictEqual(mockDb.getDoc("schedules", slotId), null);
  });

  it("14. Teacher Availability accurately calculates busy and free time blocks", async () => {
    seedDb();
    // Schedule 2 classes for Dr. Layek on TUESDAY:
    // 09:00 - 10:30 (540-630)
    // 13:00 - 14:30 (780-870)
    await service.createSlot({ uid: "teacher_layek", role: "TEACHER" }, {
      courseId: "CSE-3101",
      dayOfWeek: "TUESDAY",
      startTime: "09:00",
      endTime: "10:30",
      room: "Room 401",
      targetYear: 3,
      targetSemester: 1,
    });
    await service.createSlot({ uid: "teacher_layek", role: "TEACHER" }, {
      courseId: "CSE-3101",
      dayOfWeek: "TUESDAY",
      startTime: "13:00",
      endTime: "14:30",
      room: "Room 401",
      targetYear: 3,
      targetSemester: 1,
    });

    const avail = await service.getAvailability("teacher_layek", "TUESDAY");
    assert.strictEqual(avail.busy.length, 2);

    // Free windows should include:
    // 1. 08:00 - 09:00 (480-540, 60 mins)
    // 2. 10:30 - 13:00 (630-780, 150 mins)
    // 3. 14:30 - 17:00 (870-1020, 150 mins)
    assert.strictEqual(avail.availableWindows.length, 3);
    assert.strictEqual(avail.availableWindows[0].duration, 60);
    assert.strictEqual(avail.availableWindows[1].duration, 150);
    assert.strictEqual(avail.availableWindows[2].duration, 150);
  });
});
