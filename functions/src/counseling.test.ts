import { describe, it, beforeEach } from "node:test";
import * as assert from "node:assert";
import {
  APPROVED_PURPOSES,
  normalizeCounselingPurpose,
  validateCounselingSlotInput,
} from "./counseling";
import { parseTimeToMinutes, checkIntervalOverlap } from "./schedule";

describe("STAGE 23: Counseling System Authorization, Validation & Atomic Concurrency Tests", () => {
  // ─── 1. APPROVED PURPOSES VALIDATION ────────────────────────────────────────

  it("1. Validates all 6 approved counseling purposes and case/key aliases", () => {
    // 6 Approved purposes
    assert.strictEqual(APPROVED_PURPOSES.length, 6);
    assert.deepStrictEqual([...APPROVED_PURPOSES], [
      "Academic Advising",
      "Research Discussion",
      "Mental Pressure",
      "Class Issue",
      "Career Guidance",
      "Other",
    ]);

    // Exact matches
    for (const purpose of APPROVED_PURPOSES) {
      assert.strictEqual(normalizeCounselingPurpose(purpose), purpose);
    }

    // Key / alias variations
    assert.strictEqual(normalizeCounselingPurpose("ACADEMIC_ADVISING"), "Academic Advising");
    assert.strictEqual(normalizeCounselingPurpose("RESEARCH_DISCUSSION"), "Research Discussion");
    assert.strictEqual(normalizeCounselingPurpose("MENTAL_PRESSURE"), "Mental Pressure");
    assert.strictEqual(normalizeCounselingPurpose("CLASS_ISSUE"), "Class Issue");
    assert.strictEqual(normalizeCounselingPurpose("CAREER_GUIDANCE"), "Career Guidance");
    assert.strictEqual(normalizeCounselingPurpose("OTHER"), "Other");

    // Invalid purposes rejected
    assert.throws(() => normalizeCounselingPurpose("Random Chat"), /Invalid counseling purpose/);
    assert.throws(() => normalizeCounselingPurpose(""), /purpose \/ category is required/);
    assert.throws(() => normalizeCounselingPurpose(null), /purpose \/ category is required/);
  });

  // ─── 2. COUNSELING SLOT INPUT VALIDATION ─────────────────────────────────────

  it("2. validateCounselingSlotInput succeeds on valid slot parameters", () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const result = validateCounselingSlotInput({
      slotDate: tomorrow,
      startTime: "10:00 AM",
      endTime: "11:30 AM",
      notes: "Room 501, 5th Floor",
    });

    assert.strictEqual(result.slotDate, tomorrow);
    assert.strictEqual(result.normStartTime, "10:00");
    assert.strictEqual(result.normEndTime, "11:30");
    assert.strictEqual(result.startMinutes, 600);
    assert.strictEqual(result.endMinutes, 690);
    assert.strictEqual(result.notes, "Room 501, 5th Floor");
  });

  it("3. validateCounselingSlotInput rejects invalid date, past date, or wrong time order", () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);

    // Invalid date format
    assert.throws(
      () => validateCounselingSlotInput({ slotDate: "tomorrow", startTime: "10:00", endTime: "11:00" }),
      /Valid slot date in YYYY-MM-DD format is required/
    );

    // Past date (2020-01-01)
    assert.throws(
      () => validateCounselingSlotInput({ slotDate: "2020-01-01", startTime: "10:00", endTime: "11:00" }),
      /Cannot create counseling slots in the past/
    );

    // End time before start time
    assert.throws(
      () => validateCounselingSlotInput({ slotDate: tomorrow, startTime: "11:00", endTime: "10:00" }),
      /End time must be strictly after start time/
    );

    // Duration too short (< 15 mins)
    assert.throws(
      () => validateCounselingSlotInput({ slotDate: tomorrow, startTime: "10:00", endTime: "10:10" }),
      /duration must be at least 15 minutes/
    );

    // Duration too long (> 240 mins)
    assert.throws(
      () => validateCounselingSlotInput({ slotDate: tomorrow, startTime: "09:00", endTime: "14:00" }),
      /duration cannot exceed 4 hours/
    );
  });

  // ─── 3. SIMULATED TRANSACTIONAL FIRESTORE & COUNSELING SERVICE ──────────────

  class MockFirestoreDb {
    data: { [col: string]: { [id: string]: any } } = {
      users: {},
      counselingSlots: {},
      counselingBookings: {},
    };

    reset() {
      this.data = {
        users: {},
        counselingSlots: {},
        counselingBookings: {},
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

  class AuthoritativeCounselingService {
    db: MockFirestoreDb;
    private _slotLocks = new Map<string, Promise<void>>();

    constructor(db: MockFirestoreDb) {
      this.db = db;
    }

    async createSlot(caller: { uid: string; role: string; fullName?: string; email?: string }, data: any) {
      if (caller.role !== "TEACHER" && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only teachers or administrators can create counseling slots.");
      }

      const validated = validateCounselingSlotInput(data);

      // Check teacher overlap
      const slots = Object.values(this.db.data.counselingSlots || {});
      for (const s of slots) {
        if (s.teacherId === caller.uid && s.slotDate === validated.slotDate && s.status !== "CANCELLED") {
          const sStart = parseTimeToMinutes(s.startTime);
          const sEnd = parseTimeToMinutes(s.endTime);
          if (checkIntervalOverlap(validated.startMinutes, validated.endMinutes, sStart, sEnd)) {
            throw new Error(`ALREADY_EXISTS: You already have a counseling slot scheduled (${s.startTime} - ${s.endTime}) overlapping this time.`);
          }
        }
      }

      const id = `slot_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const newSlot = {
        id,
        teacherId: caller.uid,
        teacherName: caller.fullName || "Teacher Name",
        teacherEmail: caller.email || "teacher@cse.jnu.ac.bd",
        slotDate: validated.slotDate,
        startTime: validated.normStartTime,
        endTime: validated.normEndTime,
        startMinutes: validated.startMinutes,
        endMinutes: validated.endMinutes,
        isBooked: false,
        status: "AVAILABLE",
        bookedStudentId: null,
        bookedStudentName: null,
        bookedBookingId: null,
        notes: validated.notes || null,
        createdAt: new Date().toISOString(),
      };

      this.db.setDoc("counselingSlots", id, newSlot);
      return { success: true, slotId: id, slot: newSlot };
    }

    async deleteSlot(caller: { uid: string; role: string }, slotId: string) {
      const slot = this.db.getDoc("counselingSlots", slotId);
      if (!slot) throw new Error("NOT_FOUND: Counseling slot not found.");

      if (slot.teacherId !== caller.uid && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: You can only delete your own counseling slots.");
      }

      if (slot.isBooked === true || slot.status === "BOOKED") {
        throw new Error("FAILED_PRECONDITION: Cannot delete a booked counseling slot. Please cancel the booking first.");
      }

      // Cancel pending bookings
      const bookings = Object.values(this.db.data.counselingBookings || {});
      for (const b of bookings) {
        if (b.slotId === slotId && b.status === "PENDING") {
          b.status = "CANCELLED";
          b.rejectionReason = "Counseling slot was deleted by faculty.";
          this.db.setDoc("counselingBookings", b.id, b);
        }
      }

      this.db.deleteDoc("counselingSlots", slotId);
      return { success: true, message: "Slot deleted." };
    }

    async requestBooking(
      caller: { uid: string; role: string; fullName?: string; email?: string },
      data: { slotId: string; purpose?: string; category?: string; notes?: string }
    ) {
      if (caller.role !== "STUDENT" && caller.role !== "CR" && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only students or CRs can request counseling appointments.");
      }

      const purpose = normalizeCounselingPurpose(data.category || data.purpose);
      const slot = this.db.getDoc("counselingSlots", data.slotId);
      if (!slot) throw new Error("NOT_FOUND: Counseling slot not found.");

      if (slot.isBooked === true || slot.status === "BOOKED") {
        throw new Error("FAILED_PRECONDITION: This counseling slot is already booked.");
      }
      if (slot.status === "CANCELLED") {
        throw new Error("FAILED_PRECONDITION: This counseling slot is no longer active.");
      }

      // Duplicate check for this user on this slot
      const bookings = Object.values(this.db.data.counselingBookings || {});
      for (const b of bookings) {
        if (b.slotId === data.slotId && b.studentId === caller.uid) {
          if (b.status === "PENDING" || b.status === "APPROVED") {
            throw new Error("ALREADY_EXISTS: You have already requested this counseling slot.");
          }
        }
      }

      const id = `booking_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const newBooking = {
        id,
        slotId: data.slotId,
        studentId: caller.uid,
        studentName: caller.fullName || "Student Name",
        studentEmail: caller.email || "student@cse.jnu.ac.bd",
        teacherId: slot.teacherId,
        teacherName: slot.teacherName,
        slotDate: slot.slotDate,
        startTime: slot.startTime,
        endTime: slot.endTime,
        category: purpose,
        notes: (data.notes || "").trim(),
        status: "PENDING",
        createdAt: new Date().toISOString(),
      };

      this.db.setDoc("counselingBookings", id, newBooking);
      return { success: true, bookingId: id, booking: newBooking };
    }

    /**
     * ATOMIC APPROVAL TRANSACTION WITH MUTUAL EXCLUSION LOCK
     */
    async approveBooking(caller: { uid: string; role: string }, bookingId: string) {
      const initialBooking = this.db.getDoc("counselingBookings", bookingId);
      if (!initialBooking) throw new Error("NOT_FOUND: Counseling booking request not found.");

      const slotId = initialBooking.slotId;

      // Acquire slot-level transactional mutex lock (simulates Firestore transaction isolation)
      while (this._slotLocks.has(slotId)) {
        await this._slotLocks.get(slotId);
      }

      let releaseLock!: () => void;
      const lockPromise = new Promise<void>((resolve) => {
        releaseLock = resolve;
      });
      this._slotLocks.set(slotId, lockPromise);

      try {
        // Step 1: Read winning booking inside transaction
        const booking = this.db.getDoc("counselingBookings", bookingId);
        if (!booking) throw new Error("NOT_FOUND: Counseling booking request not found.");

        if (booking.teacherId !== caller.uid && caller.role !== "ADMIN") {
          throw new Error("PERMISSION_DENIED: Only the assigned teacher can approve this booking.");
        }

        if (booking.status !== "PENDING") {
          throw new Error(`FAILED_PRECONDITION: Booking request is already ${booking.status} and cannot be approved.`);
        }

        // Step 2: Read slot inside transaction
        const slot = this.db.getDoc("counselingSlots", slotId);
        if (!slot) throw new Error("NOT_FOUND: Associated counseling slot not found.");

        // Step 3: CRITICAL ATOMIC MUTUAL EXCLUSION CHECK
        if (slot.isBooked === true || slot.status === "BOOKED" || slot.bookedBookingId) {
          throw new Error("FAILED_PRECONDITION: This counseling slot has already been booked and confirmed for another student.");
        }

        // Step 4: Lock Slot atomically
        slot.isBooked = true;
        slot.status = "BOOKED";
        slot.bookedStudentId = booking.studentId;
        slot.bookedStudentName = booking.studentName;
        slot.bookedBookingId = bookingId;
        slot.updatedAt = new Date().toISOString();
        this.db.setDoc("counselingSlots", slotId, slot);

        // Step 5: Approve winning booking
        booking.status = "APPROVED";
        booking.reviewedAt = new Date().toISOString();
        booking.reviewedBy = caller.uid;
        this.db.setDoc("counselingBookings", bookingId, booking);

        // Step 6: Atomically reject competing pending requests for this slot
        const allBookings = Object.values(this.db.data.counselingBookings || {});
        for (const comp of allBookings) {
          if (comp.slotId === slotId && comp.id !== bookingId && comp.status === "PENDING") {
            comp.status = "REJECTED";
            comp.rejectionReason = "Slot already booked by another student.";
            comp.reviewedAt = new Date().toISOString();
            comp.reviewedBy = caller.uid;
            this.db.setDoc("counselingBookings", comp.id, comp);
          }
        }

        return { success: true, bookingId, slotId, message: "Booking approved and slot locked atomically." };
      } finally {
        this._slotLocks.delete(slotId);
        releaseLock();
      }
    }

    async rejectBooking(caller: { uid: string; role: string }, bookingId: string, reason?: string) {
      const booking = this.db.getDoc("counselingBookings", bookingId);
      if (!booking) throw new Error("NOT_FOUND: Booking not found.");

      if (booking.teacherId !== caller.uid && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: Only the assigned teacher can reject this booking.");
      }

      if (booking.status !== "PENDING") {
        throw new Error(`FAILED_PRECONDITION: Cannot reject a booking that is currently ${booking.status}.`);
      }

      booking.status = "REJECTED";
      booking.rejectionReason = reason || "Declined by faculty.";
      booking.reviewedAt = new Date().toISOString();
      booking.reviewedBy = caller.uid;
      this.db.setDoc("counselingBookings", bookingId, booking);

      return { success: true, message: "Booking rejected." };
    }

    async cancelBooking(caller: { uid: string; role: string }, bookingId: string) {
      const booking = this.db.getDoc("counselingBookings", bookingId);
      if (!booking) throw new Error("NOT_FOUND: Booking not found.");

      if (booking.studentId !== caller.uid && caller.role !== "ADMIN") {
        throw new Error("PERMISSION_DENIED: You can only cancel your own counseling requests.");
      }

      if (booking.status === "CANCELLED") {
        throw new Error("FAILED_PRECONDITION: This booking is already cancelled.");
      }

      if (booking.status === "APPROVED" && booking.slotId) {
        const slot = this.db.getDoc("counselingSlots", booking.slotId);
        if (slot) {
          slot.isBooked = false;
          slot.status = "AVAILABLE";
          slot.bookedStudentId = null;
          slot.bookedStudentName = null;
          slot.bookedBookingId = null;
          this.db.setDoc("counselingSlots", booking.slotId, slot);
        }
      }

      booking.status = "CANCELLED";
      this.db.setDoc("counselingBookings", bookingId, booking);
      return { success: true, message: "Booking cancelled." };
    }
  }

  const service = new AuthoritativeCounselingService(mockDb);

  beforeEach(() => {
    mockDb.reset();
  });

  // ─── 4. TEACHER SLOT CREATION & OVERLAP PROTECTION ─────────────────────────

  it("4. Teacher successfully creates a counseling slot with valid details", async () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const result = await service.createSlot(
      { uid: "teacher_layek", role: "TEACHER", fullName: "Dr. Md. Abu Layek" },
      {
        slotDate: tomorrow,
        startTime: "10:00 AM",
        endTime: "11:00 AM",
        notes: "Room 501, 5th Floor",
      }
    );

    assert.strictEqual(result.success, true);
    assert.strictEqual(result.slot.teacherId, "teacher_layek");
    assert.strictEqual(result.slot.isBooked, false);
    assert.strictEqual(result.slot.status, "AVAILABLE");
    assert.strictEqual(result.slot.slotDate, tomorrow);
  });

  it("5. Non-teacher (Student / CR) cannot create counseling slots", async () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    await assert.rejects(
      async () =>
        service.createSlot(
          { uid: "student_1", role: "STUDENT" },
          { slotDate: tomorrow, startTime: "10:00", endTime: "11:00" }
        ),
      /Only teachers or administrators can create counseling slots/
    );

    await assert.rejects(
      async () =>
        service.createSlot(
          { uid: "cr_1", role: "CR" },
          { slotDate: tomorrow, startTime: "10:00", endTime: "11:00" }
        ),
      /Only teachers or administrators can create counseling slots/
    );
  });

  it("6. Prevents overlapping counseling slots for the same teacher on the same date", async () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    await service.createSlot(
      { uid: "teacher_layek", role: "TEACHER" },
      { slotDate: tomorrow, startTime: "10:00", endTime: "11:30" }
    );

    // Overlapping slot (11:00 - 12:00)
    await assert.rejects(
      async () =>
        service.createSlot(
          { uid: "teacher_layek", role: "TEACHER" },
          { slotDate: tomorrow, startTime: "11:00", endTime: "12:00" }
        ),
      /You already have a counseling slot scheduled/
    );

    // Different teacher at the same time is allowed (both have their own office hours)
    const t2Result = await service.createSlot(
      { uid: "teacher_uzzal", role: "TEACHER" },
      { slotDate: tomorrow, startTime: "10:00", endTime: "11:30" }
    );
    assert.strictEqual(t2Result.success, true);
  });

  // ─── 5. STUDENT & CR REQUESTING SLOTS ──────────────────────────────────────

  it("7. Student and CR can submit booking requests across approved purposes", async () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const { slotId } = await service.createSlot(
      { uid: "teacher_layek", role: "TEACHER" },
      { slotDate: tomorrow, startTime: "10:00", endTime: "11:00" }
    );

    // Student requests with "Academic Advising"
    const req1 = await service.requestBooking(
      { uid: "student_1", role: "STUDENT", fullName: "Rahim Student" },
      { slotId, category: "Academic Advising", notes: "Need guidance on thesis topic" }
    );
    assert.strictEqual(req1.success, true);
    assert.strictEqual(req1.booking.category, "Academic Advising");
    assert.strictEqual(req1.booking.status, "PENDING");

    // CR requests with "Research Discussion"
    const req2 = await service.requestBooking(
      { uid: "cr_1", role: "CR", fullName: "Karim CR" },
      { slotId, category: "Research Discussion", notes: "Discuss paper submission" }
    );
    assert.strictEqual(req2.success, true);
    assert.strictEqual(req2.booking.category, "Research Discussion");
    assert.strictEqual(req2.booking.status, "PENDING");
  });

  it("8. Prevents duplicate booking request by the same student for the same slot", async () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const { slotId } = await service.createSlot(
      { uid: "teacher_layek", role: "TEACHER" },
      { slotDate: tomorrow, startTime: "10:00", endTime: "11:00" }
    );

    await service.requestBooking(
      { uid: "student_1", role: "STUDENT" },
      { slotId, category: "Mental Pressure", notes: "Feeling overwhelmed with coursework" }
    );

    // Duplicate attempt
    await assert.rejects(
      async () =>
        service.requestBooking(
          { uid: "student_1", role: "STUDENT" },
          { slotId, category: "Class Issue", notes: "Another query" }
        ),
      /You have already requested this counseling slot/
    );
  });

  // ─── 6. CRITICAL BUSINESS RULE: ATOMIC SINGLE-BOOKING APPROVAL & CONCURRENCY ───

  it("9. Atomic Approval: Exactly ONE booking approved, slot locked, and competing requests safely rejected", async () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const { slotId } = await service.createSlot(
      { uid: "teacher_layek", role: "TEACHER" },
      { slotDate: tomorrow, startTime: "10:00", endTime: "11:00" }
    );

    // 3 students submit requests for the same slot
    const b1 = await service.requestBooking({ uid: "s1", role: "STUDENT", fullName: "Student 1" }, { slotId, category: "Academic Advising" });
    const b2 = await service.requestBooking({ uid: "s2", role: "STUDENT", fullName: "Student 2" }, { slotId, category: "Career Guidance" });
    const b3 = await service.requestBooking({ uid: "s3", role: "STUDENT", fullName: "Student 3" }, { slotId, category: "Class Issue" });

    // Teacher approves Student 2's request
    const approvalResult = await service.approveBooking({ uid: "teacher_layek", role: "TEACHER" }, b2.bookingId);
    assert.strictEqual(approvalResult.success, true);

    // Check slot state
    const slotDoc = mockDb.getDoc("counselingSlots", slotId);
    assert.strictEqual(slotDoc.isBooked, true);
    assert.strictEqual(slotDoc.status, "BOOKED");
    assert.strictEqual(slotDoc.bookedBookingId, b2.bookingId);
    assert.strictEqual(slotDoc.bookedStudentId, "s2");

    // Check winning booking state
    const b2Doc = mockDb.getDoc("counselingBookings", b2.bookingId);
    assert.strictEqual(b2Doc.status, "APPROVED");

    // Check competing requests: Automatically marked REJECTED
    const b1Doc = mockDb.getDoc("counselingBookings", b1.bookingId);
    assert.strictEqual(b1Doc.status, "REJECTED");
    assert.strictEqual(b1Doc.rejectionReason, "Slot already booked by another student.");

    const b3Doc = mockDb.getDoc("counselingBookings", b3.bookingId);
    assert.strictEqual(b3Doc.status, "REJECTED");
    assert.strictEqual(b3Doc.rejectionReason, "Slot already booked by another student.");

    // Subsequent approval attempt on the same slot throws FAILED_PRECONDITION
    await assert.rejects(
      async () => service.approveBooking({ uid: "teacher_layek", role: "TEACHER" }, b1.bookingId),
      /Booking request is already REJECTED and cannot be approved/
    );
  });

  it("10. Concurrency Test: Competing concurrent approval calls result in exactly 1 success and 0 slot double-bookings", async () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const { slotId } = await service.createSlot(
      { uid: "teacher_layek", role: "TEACHER" },
      { slotDate: tomorrow, startTime: "02:00 PM", endTime: "03:00 PM" }
    );

    const bAlpha = await service.requestBooking({ uid: "student_alpha", role: "STUDENT" }, { slotId, category: "Research Discussion" });
    const bBeta = await service.requestBooking({ uid: "student_beta", role: "STUDENT" }, { slotId, category: "Other" });

    // Fire both approval requests concurrently
    const [resAlpha, resBeta] = await Promise.allSettled([
      service.approveBooking({ uid: "teacher_layek", role: "TEACHER" }, bAlpha.bookingId),
      service.approveBooking({ uid: "teacher_layek", role: "TEACHER" }, bBeta.bookingId),
    ]);

    // Exactly one must be fulfilled, exactly one rejected
    const fulfilled = [resAlpha, resBeta].filter((r) => r.status === "fulfilled");
    const rejected = [resAlpha, resBeta].filter((r) => r.status === "rejected");

    assert.strictEqual(fulfilled.length, 1, "Exactly one approval must succeed");
    assert.strictEqual(rejected.length, 1, "Competing concurrent approval must be rejected");

    // Verify error message on the rejected call
    const err = (rejected[0] as PromiseRejectedResult).reason;
    assert.match(err.message, /(already booked|already REJECTED)/);

    // Verify database state: Slot is booked by only 1 student
    const slotDoc = mockDb.getDoc("counselingSlots", slotId);
    assert.strictEqual(slotDoc.isBooked, true);
    assert.strictEqual(slotDoc.status, "BOOKED");

    const approvedBookings = Object.values(mockDb.data.counselingBookings).filter(
      (b: any) => b.slotId === slotId && b.status === "APPROVED"
    );
    assert.strictEqual(approvedBookings.length, 1, "Only one booking can ever be APPROVED in the slot");

    const rejectedBookings = Object.values(mockDb.data.counselingBookings).filter(
      (b: any) => b.slotId === slotId && b.status === "REJECTED"
    );
    assert.strictEqual(rejectedBookings.length, 1, "The competing booking must be REJECTED");
  });

  // ─── 7. TEACHER REJECTION & STUDENT CANCELLATION ────────────────────────────

  it("11. Teacher can reject a pending booking, leaving the slot available for other requests", async () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const { slotId } = await service.createSlot(
      { uid: "teacher_layek", role: "TEACHER" },
      { slotDate: tomorrow, startTime: "10:00", endTime: "11:00" }
    );

    const b = await service.requestBooking({ uid: "s1", role: "STUDENT" }, { slotId, category: "Class Issue" });

    const rejectResult = await service.rejectBooking(
      { uid: "teacher_layek", role: "TEACHER" },
      b.bookingId,
      "Please attend my open office hours tomorrow instead."
    );

    assert.strictEqual(rejectResult.success, true);
    const bDoc = mockDb.getDoc("counselingBookings", b.bookingId);
    assert.strictEqual(bDoc.status, "REJECTED");
    assert.strictEqual(bDoc.rejectionReason, "Please attend my open office hours tomorrow instead.");

    // Slot remains AVAILABLE for other requests
    const slotDoc = mockDb.getDoc("counselingSlots", slotId);
    assert.strictEqual(slotDoc.isBooked, false);
    assert.strictEqual(slotDoc.status, "AVAILABLE");
  });

  it("12. Student can cancel an approved booking, resetting slot to AVAILABLE", async () => {
    const tomorrow = new Date(Date.now() + 86400000 * 2).toISOString().slice(0, 10);
    const { slotId } = await service.createSlot(
      { uid: "teacher_layek", role: "TEACHER" },
      { slotDate: tomorrow, startTime: "10:00", endTime: "11:00" }
    );

    const b = await service.requestBooking({ uid: "s1", role: "STUDENT" }, { slotId, category: "Other" });
    await service.approveBooking({ uid: "teacher_layek", role: "TEACHER" }, b.bookingId);

    // Slot is booked
    assert.strictEqual(mockDb.getDoc("counselingSlots", slotId).isBooked, true);

    // Student cancels
    const cancelRes = await service.cancelBooking({ uid: "s1", role: "STUDENT" }, b.bookingId);
    assert.strictEqual(cancelRes.success, true);

    // Slot freed up
    const slotDoc = mockDb.getDoc("counselingSlots", slotId);
    assert.strictEqual(slotDoc.isBooked, false);
    assert.strictEqual(slotDoc.status, "AVAILABLE");
    assert.strictEqual(slotDoc.bookedStudentId, null);
  });
});
