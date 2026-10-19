import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { parseTimeToMinutes, checkIntervalOverlap } from "./schedule";
import { getTodayDateUtc6 } from "./exam";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// ─── APPROVED COUNSELING PURPOSES ───────────────────────────────────────────

export const APPROVED_PURPOSES = [
  "Academic Advising",
  "Research Discussion",
  "Mental Pressure",
  "Class Issue",
  "Career Guidance",
  "Other",
] as const;

export type CounselingPurpose = typeof APPROVED_PURPOSES[number];

const PURPOSE_ALIASES: Record<string, CounselingPurpose> = {
  "ACADEMIC_ADVISING": "Academic Advising",
  "academic advising": "Academic Advising",
  "academic_advising": "Academic Advising",
  "RESEARCH_DISCUSSION": "Research Discussion",
  "research discussion": "Research Discussion",
  "research_discussion": "Research Discussion",
  "MENTAL_PRESSURE": "Mental Pressure",
  "mental pressure": "Mental Pressure",
  "mental_pressure": "Mental Pressure",
  "CLASS_ISSUE": "Class Issue",
  "class issue": "Class Issue",
  "class_issue": "Class Issue",
  "CAREER_GUIDANCE": "Career Guidance",
  "career guidance": "Career Guidance",
  "career_guidance": "Career Guidance",
  "OTHER": "Other",
  "other": "Other",
};

export function normalizeCounselingPurpose(input: any): CounselingPurpose {
  if (!input || typeof input !== "string") {
    throw new HttpsError("invalid-argument", "Counseling purpose / category is required.");
  }
  const trimmed = input.trim();
  if (APPROVED_PURPOSES.includes(trimmed as CounselingPurpose)) {
    return trimmed as CounselingPurpose;
  }
  const alias = PURPOSE_ALIASES[trimmed] || PURPOSE_ALIASES[trimmed.toUpperCase()];
  if (alias) {
    return alias;
  }
  throw new HttpsError(
    "invalid-argument",
    `Invalid counseling purpose "${input}". Allowed: ${APPROVED_PURPOSES.join(", ")}`
  );
}

// ─── VALIDATION HELPERS ─────────────────────────────────────────────────────

export function validateCounselingSlotInput(data: any): {
  slotDate: string;
  normStartTime: string;
  normEndTime: string;
  startMinutes: number;
  endMinutes: number;
  notes: string;
} {
  const { slotDate, startTime, endTime, notes } = data || {};

  if (!slotDate || typeof slotDate !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(slotDate.trim())) {
    throw new HttpsError("invalid-argument", "Valid slot date in YYYY-MM-DD format is required.");
  }

  const todayStr = getTodayDateUtc6();
  if (slotDate.trim() < todayStr) {
    throw new HttpsError("invalid-argument", "Cannot create counseling slots in the past.");
  }

  if (!startTime || typeof startTime !== "string") {
    throw new HttpsError("invalid-argument", "Start time is required.");
  }
  if (!endTime || typeof endTime !== "string") {
    throw new HttpsError("invalid-argument", "End time is required.");
  }

  const startMinutes = parseTimeToMinutes(startTime);
  const endMinutes = parseTimeToMinutes(endTime);

  if (endMinutes <= startMinutes) {
    throw new HttpsError("invalid-argument", "End time must be strictly after start time.");
  }

  const duration = endMinutes - startMinutes;
  if (duration < 15) {
    throw new HttpsError("invalid-argument", "Counseling slot duration must be at least 15 minutes.");
  }
  if (duration > 240) {
    throw new HttpsError("invalid-argument", "Counseling slot duration cannot exceed 4 hours (240 minutes).");
  }

  const pad = (n: number) => String(n).padStart(2, "0");
  const normStartTime = `${pad(Math.floor(startMinutes / 60))}:${pad(startMinutes % 60)}`;
  const normEndTime = `${pad(Math.floor(endMinutes / 60))}:${pad(endMinutes % 60)}`;

  return {
    slotDate: slotDate.trim(),
    normStartTime,
    normEndTime,
    startMinutes,
    endMinutes,
    notes: typeof notes === "string" ? notes.trim() : "",
  };
}

// ─── CORE EXECUTORS (Injectable for Unit & Concurrency Testing) ──────────────

export async function executeCreateCounselingSlot(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string; fullName?: string; email?: string },
  data: any
) {
  // Authorization: Only TEACHER and ADMIN can create slots
  if (caller.role !== "TEACHER" && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only teachers or administrators can create counseling slots.");
  }

  const validated = validateCounselingSlotInput(data);

  // Fetch teacher details if not supplied in caller
  let teacherName = caller.fullName || "";
  let teacherEmail = caller.email || "";
  if (!teacherName || !teacherEmail) {
    const userDoc = await firestore.collection("users").doc(caller.uid).get();
    if (userDoc.exists) {
      const u = userDoc.data()!;
      teacherName = teacherName || u.fullName || "Faculty Member";
      teacherEmail = teacherEmail || u.email || "";
    }
  }

  // Prevent overlapping slot for the same teacher on the same date
  const existingSlotsSnap = await firestore
    .collection("counselingSlots")
    .where("teacherId", "==", caller.uid)
    .where("slotDate", "==", validated.slotDate)
    .get();

  for (const doc of existingSlotsSnap.docs) {
    const slot = doc.data();
    if (slot.status === "CANCELLED") continue;
    const existingStart = parseTimeToMinutes(slot.startTime);
    const existingEnd = parseTimeToMinutes(slot.endTime);

    if (checkIntervalOverlap(validated.startMinutes, validated.endMinutes, existingStart, existingEnd)) {
      throw new HttpsError(
        "already-exists",
        `You already have a counseling slot scheduled (${slot.startTime} - ${slot.endTime}) overlapping this time.`
      );
    }
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const slotRef = firestore.collection("counselingSlots").doc();
  const newSlot = {
    id: slotRef.id,
    teacherId: caller.uid,
    teacherName: teacherName || "Faculty Member",
    teacherEmail: teacherEmail || "",
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
    createdAt: now,
    updatedAt: now,
  };

  await slotRef.set(newSlot);
  return { success: true, slotId: slotRef.id, slot: newSlot };
}

export async function executeDeleteCounselingSlot(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string },
  slotId: string
) {
  if (!slotId || typeof slotId !== "string") {
    throw new HttpsError("invalid-argument", "Missing slotId.");
  }

  const slotRef = firestore.collection("counselingSlots").doc(slotId);
  const slotDoc = await slotRef.get();
  if (!slotDoc.exists) {
    throw new HttpsError("not-found", "Counseling slot not found.");
  }

  const slotData = slotDoc.data()!;
  if (slotData.teacherId !== caller.uid && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "You can only delete your own counseling slots.");
  }

  if (slotData.isBooked === true || slotData.status === "BOOKED") {
    throw new HttpsError(
      "failed-precondition",
      "Cannot delete a booked counseling slot. Please cancel the booking first."
    );
  }

  // Cancel any pending booking requests for this slot
  const pendingRequests = await firestore
    .collection("counselingBookings")
    .where("slotId", "==", slotId)
    .where("status", "==", "PENDING")
    .get();

  const batch = firestore.batch();
  pendingRequests.docs.forEach((doc) => {
    batch.update(doc.ref, {
      status: "CANCELLED",
      rejectionReason: "Counseling slot was deleted by faculty.",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  batch.delete(slotRef);
  await batch.commit();

  return { success: true, message: "Counseling slot and pending requests deleted." };
}

export async function executeRequestBooking(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string; fullName?: string; email?: string },
  data: any
) {
  // Authorization: Student or CR (or Admin)
  if (caller.role !== "STUDENT" && caller.role !== "CR" && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only students or CRs can request counseling appointments.");
  }

  const { slotId, category, purpose, notes } = data || {};
  if (!slotId || typeof slotId !== "string") {
    throw new HttpsError("invalid-argument", "Valid slotId is required.");
  }

  const normalizedPurpose = normalizeCounselingPurpose(category || purpose);

  // Check if slot exists and is available
  const slotRef = firestore.collection("counselingSlots").doc(slotId);
  const slotDoc = await slotRef.get();
  if (!slotDoc.exists) {
    throw new HttpsError("not-found", "Counseling slot not found.");
  }

  const slotData = slotDoc.data()!;
  if (slotData.isBooked === true || slotData.status === "BOOKED") {
    throw new HttpsError("failed-precondition", "This counseling slot is already booked.");
  }
  if (slotData.status === "CANCELLED") {
    throw new HttpsError("failed-precondition", "This counseling slot is no longer active.");
  }

  // Check if student already has a pending or approved request for this exact slot
  const existingUserBookings = await firestore
    .collection("counselingBookings")
    .where("slotId", "==", slotId)
    .where("studentId", "==", caller.uid)
    .get();

  for (const doc of existingUserBookings.docs) {
    const st = doc.data().status;
    if (st === "PENDING" || st === "APPROVED") {
      throw new HttpsError(
        "already-exists",
        "You already have a request submitted for this counseling slot."
      );
    }
  }

  // Retrieve student details if not supplied
  let studentName = caller.fullName || "";
  let studentEmail = caller.email || "";
  if (!studentName || !studentEmail) {
    const userDoc = await firestore.collection("users").doc(caller.uid).get();
    if (userDoc.exists) {
      const u = userDoc.data()!;
      studentName = studentName || u.fullName || "Student";
      studentEmail = studentEmail || u.email || "";
    }
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const bookingRef = firestore.collection("counselingBookings").doc();
  const bookingData = {
    id: bookingRef.id,
    slotId,
    studentId: caller.uid,
    studentName: studentName || "Student",
    studentEmail: studentEmail || "",
    teacherId: slotData.teacherId,
    teacherName: slotData.teacherName,
    slotDate: slotData.slotDate,
    startTime: slotData.startTime,
    endTime: slotData.endTime,
    category: normalizedPurpose,
    notes: typeof notes === "string" ? notes.trim() : "",
    status: "PENDING",
    createdAt: now,
    updatedAt: now,
  };

  await bookingRef.set(bookingData);

  // Notify teacher of incoming counseling appointment request
  if (slotData.teacherId) {
    const notifRef = firestore.collection("notifications").doc();
    await notifRef.set({
      id: notifRef.id,
      userId: slotData.teacherId,
      title: "New Counseling Request",
      body: `${bookingData.studentName} requested an appointment for ${normalizedPurpose} on ${slotData.slotDate} (${slotData.startTime}).`,
      notificationType: "COUNSELING_STATUS",
      referenceId: bookingRef.id,
      referenceType: "COUNSELING",
      route: "/teacher/counseling",
      isRead: false,
      createdAt: now,
      updatedAt: now,
    });
  }

  return { success: true, bookingId: bookingRef.id, booking: bookingData };
}

/**
 * ─── ATOMIC MUTUAL EXCLUSION APPROVAL ─────────────────────────────────────────
 * CRITICAL BUSINESS RULE:
 * Each counseling slot can have only ONE approved booking.
 * Approval must be atomic.
 * If multiple approval operations occur concurrently, only one can succeed.
 * Competing requests must be safely marked REJECTED inside the same transaction.
 */
export async function executeApproveBooking(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string },
  bookingId: string
) {
  if (!bookingId || typeof bookingId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid bookingId.");
  }

  const bookingRef = firestore.collection("counselingBookings").doc(bookingId);

  return await firestore.runTransaction(async (transaction) => {
    // 1. Read winning booking inside transaction
    const bookingDoc = await transaction.get(bookingRef);
    if (!bookingDoc.exists) {
      throw new HttpsError("not-found", "Counseling booking request not found.");
    }
    const bData = bookingDoc.data()!;

    // Authorization: Must be assigned teacher or ADMIN
    if (bData.teacherId !== caller.uid && caller.role !== "ADMIN") {
      throw new HttpsError("permission-denied", "Only the assigned teacher can approve this booking.");
    }

    // Check booking status
    if (bData.status !== "PENDING") {
      throw new HttpsError(
        "failed-precondition",
        `Booking request is already ${bData.status} and cannot be approved.`
      );
    }

    const slotId = bData.slotId;
    if (!slotId) {
      throw new HttpsError("failed-precondition", "Booking is not linked to a valid counseling slot.");
    }

    // 2. Read slot inside the same transaction
    const slotRef = firestore.collection("counselingSlots").doc(slotId);
    const slotDoc = await transaction.get(slotRef);
    if (!slotDoc.exists) {
      throw new HttpsError("not-found", "Associated counseling slot not found.");
    }
    const slotData = slotDoc.data()!;

    // 3. ATOMIC CHECK: Check if slot is already booked!
    if (slotData.isBooked === true || slotData.status === "BOOKED" || slotData.bookedBookingId) {
      throw new HttpsError(
        "failed-precondition",
        "This counseling slot has already been booked and confirmed for another student."
      );
    }

    // 4. Query competing pending bookings for the same slot inside the transaction
    const competingQuery = firestore
      .collection("counselingBookings")
      .where("slotId", "==", slotId)
      .where("status", "==", "PENDING");
    const competingDocs = await transaction.get(competingQuery);

    const now = admin.firestore.FieldValue.serverTimestamp();

    // 5. Atomic Mutex Lock on Slot
    transaction.update(slotRef, {
      isBooked: true,
      status: "BOOKED",
      bookedStudentId: bData.studentId || null,
      bookedStudentName: bData.studentName || null,
      bookedBookingId: bookingId,
      updatedAt: now,
    });

    // 6. Approve winning booking
    transaction.update(bookingRef, {
      status: "APPROVED",
      reviewedAt: now,
      reviewedBy: caller.uid,
      updatedAt: now,
    });

    // Notify winning student
    if (bData.studentId) {
      const winNotifRef = firestore.collection("notifications").doc();
      transaction.set(winNotifRef, {
        id: winNotifRef.id,
        userId: bData.studentId,
        title: "Counseling Booking Approved",
        body: `Your counseling request on ${slotData.slotDate} (${slotData.startTime} - ${slotData.endTime}) was approved by ${slotData.teacherName || "Faculty"}.`,
        notificationType: "COUNSELING_STATUS",
        referenceId: bookingId,
        referenceType: "COUNSELING",
        route: "/counseling",
        isRead: false,
        createdAt: now,
        updatedAt: now,
      });
    }

    // 7. Atomically reject all competing pending requests for this slot & notify them
    competingDocs.forEach((doc) => {
      if (doc.id !== bookingId) {
        transaction.update(doc.ref, {
          status: "REJECTED",
          rejectionReason: "Slot already booked by another student.",
          reviewedAt: now,
          reviewedBy: caller.uid,
          updatedAt: now,
        });

        const compData = doc.data();
        if (compData.studentId) {
          const compNotifRef = firestore.collection("notifications").doc();
          transaction.set(compNotifRef, {
            id: compNotifRef.id,
            userId: compData.studentId,
            title: "Counseling Slot Unavailable",
            body: `The counseling slot on ${slotData.slotDate} (${slotData.startTime}) was reserved by another student.`,
            notificationType: "COUNSELING_STATUS",
            referenceId: doc.id,
            referenceType: "COUNSELING",
            route: "/counseling",
            isRead: false,
            createdAt: now,
            updatedAt: now,
          });
        }
      }
    });

    return {
      success: true,
      bookingId,
      slotId,
      message: "Counseling booking approved and slot locked atomically.",
    };
  });
}

export async function executeRejectBooking(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string },
  bookingId: string,
  reason?: string
) {
  if (!bookingId || typeof bookingId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid bookingId.");
  }

  const bookingRef = firestore.collection("counselingBookings").doc(bookingId);
  const bookingDoc = await bookingRef.get();
  if (!bookingDoc.exists) {
    throw new HttpsError("not-found", "Counseling booking request not found.");
  }
  const bData = bookingDoc.data()!;

  if (bData.teacherId !== caller.uid && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only the assigned teacher can reject this booking.");
  }

  if (bData.status !== "PENDING") {
    throw new HttpsError("failed-precondition", `Cannot reject a booking that is currently ${bData.status}.`);
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  await bookingRef.update({
    status: "REJECTED",
    rejectionReason: reason || "Declined by faculty member.",
    reviewedAt: now,
    reviewedBy: caller.uid,
    updatedAt: now,
  });

  // Notify student of rejection
  if (bData.studentId) {
    const notifRef = firestore.collection("notifications").doc();
    await notifRef.set({
      id: notifRef.id,
      userId: bData.studentId,
      title: "Counseling Request Declined",
      body: `Your counseling request on ${bData.slotDate} (${bData.startTime}) was declined: ${reason || "Faculty unavailable"}`,
      notificationType: "COUNSELING_STATUS",
      referenceId: bookingId,
      referenceType: "COUNSELING",
      route: "/counseling",
      isRead: false,
      createdAt: now,
      updatedAt: now,
    });
  }

  return { success: true, message: "Booking request rejected." };
}

export async function executeCancelBooking(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string },
  bookingId: string
) {
  if (!bookingId || typeof bookingId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid bookingId.");
  }

  const bookingRef = firestore.collection("counselingBookings").doc(bookingId);

  return await firestore.runTransaction(async (transaction) => {
    const bookingDoc = await transaction.get(bookingRef);
    if (!bookingDoc.exists) {
      throw new HttpsError("not-found", "Counseling booking request not found.");
    }
    const bData = bookingDoc.data()!;

    // Only booking owner or Admin can cancel
    if (bData.studentId !== caller.uid && caller.role !== "ADMIN") {
      throw new HttpsError("permission-denied", "You can only cancel your own counseling requests.");
    }

    if (bData.status === "CANCELLED") {
      throw new HttpsError("failed-precondition", "This booking is already cancelled.");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    // If it was APPROVED, free up the slot
    if (bData.status === "APPROVED" && bData.slotId) {
      const slotRef = firestore.collection("counselingSlots").doc(bData.slotId);
      const slotDoc = await transaction.get(slotRef);
      if (slotDoc.exists) {
        transaction.update(slotRef, {
          isBooked: false,
          status: "AVAILABLE",
          bookedStudentId: null,
          bookedStudentName: null,
          bookedBookingId: null,
          updatedAt: now,
        });
      }
    }

    transaction.update(bookingRef, {
      status: "CANCELLED",
      updatedAt: now,
    });

    return { success: true, message: "Counseling booking cancelled." };
  });
}

// ─── CALLABLE CLOUD FUNCTIONS ────────────────────────────────────────────────

export const createCounselingSlot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "STUDENT",
    fullName: request.auth.token.name,
    email: request.auth.token.email,
  };
  return executeCreateCounselingSlot(db, caller, request.data);
});

export const deleteCounselingSlot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "STUDENT",
  };
  return executeDeleteCounselingSlot(db, caller, request.data?.slotId);
});

export const requestCounselingBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "STUDENT",
    fullName: request.auth.token.name,
    email: request.auth.token.email,
  };
  return executeRequestBooking(db, caller, request.data);
});

export const approveCounselingBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "STUDENT",
  };
  return executeApproveBooking(db, caller, request.data?.bookingId);
});

export const rejectCounselingBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "STUDENT",
  };
  return executeRejectBooking(db, caller, request.data?.bookingId, request.data?.reason);
});

export const cancelCounselingBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "STUDENT",
  };
  return executeCancelBooking(db, caller, request.data?.bookingId);
});
