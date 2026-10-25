import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { buildWhatsAppShareUrls } from "./communication";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// ─── TIME & DATE UTILITIES ───────────────────────────────────────────────────

/**
 * Parses time strings like "09:00", "09:30 AM", "2:30 PM", "14:15" into minutes from midnight (0-1439).
 */
export function parseTimeToMinutes(timeStr: string): number {
  if (!timeStr || typeof timeStr !== "string") {
    throw new HttpsError("invalid-argument", "Invalid time string format.");
  }

  const clean = timeStr.trim().toUpperCase();
  const is12Hr = clean.includes("AM") || clean.includes("PM");

  if (is12Hr) {
    const parts = clean.split(/\s+/);
    const timeParts = parts[0].split(":");
    let hours = parseInt(timeParts[0], 10);
    const minutes = parseInt(timeParts[1] || "0", 10);
    const modifier = parts[1];

    if (isNaN(hours) || isNaN(minutes) || minutes < 0 || minutes > 59) {
      throw new HttpsError("invalid-argument", `Malformed time value: "${timeStr}".`);
    }

    if (modifier === "PM" && hours < 12) hours += 12;
    if (modifier === "AM" && hours === 12) hours = 0;
    return hours * 60 + minutes;
  } else {
    const timeParts = clean.split(":");
    const hours = parseInt(timeParts[0], 10);
    const minutes = parseInt(timeParts[1] || "0", 10);

    if (isNaN(hours) || isNaN(minutes) || hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
      throw new HttpsError("invalid-argument", `Malformed 24h time value: "${timeStr}".`);
    }
    return hours * 60 + minutes;
  }
}

/**
 * Checks if two time intervals [startA, endA) and [startB, endB) overlap.
 */
export function checkIntervalOverlap(
  startA: number,
  endA: number,
  startB: number,
  endB: number
): boolean {
  return Math.max(startA, startB) < Math.min(endA, endB);
}

const DAYS_OF_WEEK = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];

/**
 * Returns tomorrow's day of week and ISO date string ("YYYY-MM-DD") in UTC+6 (Bangladesh).
 */
export function getTomorrowInfo(nowUtc?: Date): {
  tomorrowDate: string;
  tomorrowDayOfWeek: string;
  todayDate: string;
} {
  const base = nowUtc ? new Date(nowUtc) : new Date();
  // Adjust to UTC+6 (Asia/Dhaka)
  const utcMs = base.getTime() + base.getTimezoneOffset() * 60000;
  const dhakaTime = new Date(utcMs + 6 * 3600000);

  const todayYear = dhakaTime.getFullYear();
  const todayMonth = String(dhakaTime.getMonth() + 1).padStart(2, "0");
  const todayDay = String(dhakaTime.getDate()).padStart(2, "0");
  const todayDate = `${todayYear}-${todayMonth}-${todayDay}`;

  const tomorrow = new Date(dhakaTime.getTime() + 24 * 3600000);
  const tomYear = tomorrow.getFullYear();
  const tomMonth = String(tomorrow.getMonth() + 1).padStart(2, "0");
  const tomDay = String(tomorrow.getDate()).padStart(2, "0");
  const tomorrowDate = `${tomYear}-${tomMonth}-${tomDay}`;
  const tomorrowDayOfWeek = DAYS_OF_WEEK[tomorrow.getDay()];

  return { tomorrowDate, tomorrowDayOfWeek, todayDate };
}

// ─── 1. CREATE SCHEDULE SLOT ────────────────────────────────────────────────

export const createScheduleSlot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const callerUid = request.auth.uid;
  const userDoc = await db.collection("users").doc(callerUid).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }
  const userData = userDoc.data()!;
  const userRole = (userData.role || request.auth.token.role || "STUDENT").toUpperCase();

  const isCR = userRole === "CR";
  const isTeacher = userRole === "TEACHER";
  const isAdmin = userRole === "ADMIN";

  if (!isCR && !isTeacher && !isAdmin) {
    throw new HttpsError(
      "permission-denied",
      "Only Class Representatives (CR), Teachers, and Administrators can create schedule slots."
    );
  }

  const {
    courseId,
    courseCode,
    courseTitle,
    teacherId,
    teacherName,
    dayOfWeek,
    startTime,
    endTime,
    room,
    targetYear,
    targetSemester,
    isExtraClass,
    date, // Optional specific calendar date
  } = request.data || {};

  // Basic Validations
  if (!courseId || typeof courseId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid courseId.");
  }
  if (!dayOfWeek || typeof dayOfWeek !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid dayOfWeek.");
  }
  if (!startTime || !endTime) {
    throw new HttpsError("invalid-argument", "Both startTime and endTime are required.");
  }
  if (!room || typeof room !== "string" || room.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Room information is required.");
  }
  if (!targetYear || !targetSemester) {
    throw new HttpsError("invalid-argument", "Target year and semester are required.");
  }

  const startMins = parseTimeToMinutes(startTime);
  const endMins = parseTimeToMinutes(endTime);

  if (startMins >= endMins) {
    throw new HttpsError("invalid-argument", "startTime must precede endTime.");
  }
  if (endMins - startMins < 30) {
    throw new HttpsError("invalid-argument", "Class duration must be at least 30 minutes.");
  }
  if (endMins - startMins > 240) {
    throw new HttpsError("invalid-argument", "Class duration cannot exceed 4 hours.");
  }

  const normDayOfWeek = dayOfWeek.trim().toUpperCase();
  if (!DAYS_OF_WEEK.includes(normDayOfWeek)) {
    throw new HttpsError("invalid-argument", `Invalid day of week: ${dayOfWeek}`);
  }

  // ─── CR COHORT LOCK RULE ───
  if (isCR) {
    // Cohort Lock: CR can schedule routine for any day of the week, but only for their own registered academic year and semester
    if (userData.year !== targetYear || userData.semester !== targetSemester) {
      throw new HttpsError(
        "permission-denied",
        `CR_COHORT_MISMATCH: You can only schedule classes for your own cohort (Year ${userData.year}, Semester ${userData.semester}).`
      );
    }
  }

  // ─── TEACHER AUTHORIZATION RULE ───
  if (isTeacher && !isAdmin) {
    const assignedIds: string[] = userData.assignedCourseIds || [];
    if (!assignedIds.includes(courseId)) {
      throw new HttpsError(
        "permission-denied",
        `TEACHER_UNAUTHORIZED: You are not assigned to instruct course "${courseId}".`
      );
    }
  }

  // ─── COURSE & TEACHER EXISTENCE VALIDATION ───
  const courseDoc = await db.collection("courses").doc(courseId).get();
  if (!courseDoc.exists) {
    throw new HttpsError("not-found", `Course "${courseId}" does not exist in academic records.`);
  }
  const courseData = courseDoc.data()!;
  const resolvedCourseCode = courseCode || courseData.code || "";
  const resolvedCourseTitle = courseTitle || courseData.title || "";

  let resolvedTeacherId = teacherId || courseData.teacherId || "";
  let resolvedTeacherName = teacherName || courseData.teacherName || "";

  if (resolvedTeacherId) {
    const teacherDoc = await db.collection("users").doc(resolvedTeacherId).get();
    if (!teacherDoc.exists) {
      throw new HttpsError("not-found", `Teacher with ID "${resolvedTeacherId}" not found.`);
    }
    const tData = teacherDoc.data()!;
    if (tData.role !== "TEACHER" && tData.role !== "ADMIN") {
      throw new HttpsError("invalid-argument", `User "${resolvedTeacherId}" is not a recognized faculty member.`);
    }
    resolvedTeacherName = tData.fullName || resolvedTeacherName;
  }

  // ─── CONFLICT DETECTION & ATOMIC INSERTION TRANSACTION ───
  const cleanRoom = room.trim();
  const effectiveDate = date && typeof date === "string" && date.trim().length > 0 ? date.trim() : null;

  const newSlotRef = db.collection("schedules").doc();

  return db.runTransaction(async (transaction) => {
    // 1. Query existing schedule slots on this day
    const query = db.collection("schedules").where("dayOfWeek", "==", normDayOfWeek);
    const existingSnap = await transaction.get(query);

    for (const doc of existingSnap.docs) {
      const slot = doc.data();

      // If slot is date-specific and doesn't match this date, skip
      if (effectiveDate && slot.date && slot.date !== effectiveDate) {
        continue;
      }

      const slotStart = parseTimeToMinutes(slot.startTime);
      const slotEnd = parseTimeToMinutes(slot.endTime);

      if (checkIntervalOverlap(startMins, endMins, slotStart, slotEnd)) {
        // A. Room Conflict
        if (slot.room && slot.room.trim().toLowerCase() === cleanRoom.toLowerCase()) {
          throw new HttpsError(
            "already-exists",
            `ROOM_CONFLICT: ${cleanRoom} is already booked by ${slot.courseCode || "another class"} from ${slot.startTime} to ${slot.endTime}.`
          );
        }

        // B. Teacher Conflict
        if (resolvedTeacherId && slot.teacherId === resolvedTeacherId) {
          throw new HttpsError(
            "already-exists",
            `TEACHER_CONFLICT: Faculty ${resolvedTeacherName || "member"} is already scheduled for ${slot.courseCode} from ${slot.startTime} to ${slot.endTime}.`
          );
        }

        // C. Cohort / Batch Conflict
        if (slot.targetYear === targetYear && slot.targetSemester === targetSemester) {
          throw new HttpsError(
            "already-exists",
            `COHORT_CONFLICT: Year ${targetYear}, Semester ${targetSemester} already has class ${slot.courseCode} scheduled from ${slot.startTime} to ${slot.endTime}.`
          );
        }
      }
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const slotData = {
      courseId,
      courseCode: resolvedCourseCode,
      courseTitle: resolvedCourseTitle,
      teacherId: resolvedTeacherId,
      teacherName: resolvedTeacherName,
      dayOfWeek: normDayOfWeek,
      startTime: startTime.trim(),
      endTime: endTime.trim(),
      room: cleanRoom,
      targetYear: Number(targetYear),
      targetSemester: Number(targetSemester),
      isExtraClass: Boolean(isExtraClass),
      date: effectiveDate,
      createdBy: callerUid,
      creatorRole: userRole,
      createdAt: now,
      updatedAt: now,
    };

    transaction.set(newSlotRef, slotData);

    return {
      success: true,
      slotId: newSlotRef.id,
      slot: {
        id: newSlotRef.id,
        ...slotData,
        createdAt: new Date().toISOString(),
      },
      message: "Schedule slot created successfully.",
    };
  });
});

// ─── 2. UPDATE SCHEDULE SLOT ────────────────────────────────────────────────

export const updateScheduleSlot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const { slotId, ...updates } = request.data || {};
  if (!slotId || typeof slotId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid slotId parameter.");
  }

  const slotRef = db.collection("schedules").doc(slotId);
  const callerUid = request.auth.uid;
  const userDoc = await db.collection("users").doc(callerUid).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }
  const userData = userDoc.data()!;
  const userRole = (userData.role || request.auth.token.role || "STUDENT").toUpperCase();

  const isCR = userRole === "CR";
  const isTeacher = userRole === "TEACHER";
  const isAdmin = userRole === "ADMIN";

  if (!isCR && !isTeacher && !isAdmin) {
    throw new HttpsError("permission-denied", "Unauthorized to update schedule slots.");
  }

  return db.runTransaction(async (transaction) => {
    const slotDoc = await transaction.get(slotRef);
    if (!slotDoc.exists) {
      throw new HttpsError("not-found", "Schedule slot not found.");
    }
    const current = slotDoc.data()!;

    // Authorization checks
    if (isTeacher && !isAdmin) {
      const assignedIds: string[] = userData.assignedCourseIds || [];
      if (!assignedIds.includes(current.courseId)) {
        throw new HttpsError("permission-denied", "Teachers can only modify slots for their assigned courses.");
      }
    }

    if (isCR) {
      if (current.createdBy !== callerUid && current.targetYear !== userData.year) {
        throw new HttpsError("permission-denied", "CR can only edit slots created for their cohort.");
      }
    }

    const newStartTime = updates.startTime || current.startTime;
    const newEndTime = updates.endTime || current.endTime;
    const newRoom = updates.room ? updates.room.trim() : current.room;
    const newDayOfWeek = updates.dayOfWeek ? updates.dayOfWeek.trim().toUpperCase() : current.dayOfWeek;
    const effectiveTeacherId = updates.teacherId || current.teacherId;
    const effectiveYear = updates.targetYear !== undefined ? Number(updates.targetYear) : current.targetYear;
    const effectiveSem = updates.targetSemester !== undefined ? Number(updates.targetSemester) : current.targetSemester;

    const startMins = parseTimeToMinutes(newStartTime);
    const endMins = parseTimeToMinutes(newEndTime);
    if (startMins >= endMins) {
      throw new HttpsError("invalid-argument", "startTime must precede endTime.");
    }

    // Check conflicts against all OTHER slots
    const query = db.collection("schedules").where("dayOfWeek", "==", newDayOfWeek);
    const existingSnap = await transaction.get(query);

    for (const doc of existingSnap.docs) {
      if (doc.id === slotId) continue; // Skip self

      const slot = doc.data();
      const slotStart = parseTimeToMinutes(slot.startTime);
      const slotEnd = parseTimeToMinutes(slot.endTime);

      if (checkIntervalOverlap(startMins, endMins, slotStart, slotEnd)) {
        if (slot.room && slot.room.trim().toLowerCase() === newRoom.toLowerCase()) {
          throw new HttpsError(
            "already-exists",
            `ROOM_CONFLICT: ${newRoom} is already booked by ${slot.courseCode} (${slot.startTime} - ${slot.endTime}).`
          );
        }
        if (effectiveTeacherId && slot.teacherId === effectiveTeacherId) {
          throw new HttpsError(
            "already-exists",
            `TEACHER_CONFLICT: Teacher is already scheduled for ${slot.courseCode} (${slot.startTime} - ${slot.endTime}).`
          );
        }
        if (slot.targetYear === effectiveYear && slot.targetSemester === effectiveSem) {
          throw new HttpsError(
            "already-exists",
            `COHORT_CONFLICT: Year ${effectiveYear} Sem ${effectiveSem} already has ${slot.courseCode} (${slot.startTime} - ${slot.endTime}).`
          );
        }
      }
    }

    const updatedData = {
      ...updates,
      dayOfWeek: newDayOfWeek,
      startTime: newStartTime,
      endTime: newEndTime,
      room: newRoom,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.update(slotRef, updatedData);
    return { success: true, message: "Schedule slot updated successfully." };
  });
});

// ─── 3. DELETE SCHEDULE SLOT ────────────────────────────────────────────────

export const deleteScheduleSlot = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const { slotId } = request.data || {};
  if (!slotId || typeof slotId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid slotId parameter.");
  }

  const slotRef = db.collection("schedules").doc(slotId);
  const slotDoc = await slotRef.get();
  if (!slotDoc.exists) {
    throw new HttpsError("not-found", "Schedule slot not found.");
  }

  const slot = slotDoc.data()!;
  const callerUid = request.auth.uid;
  const userDoc = await db.collection("users").doc(callerUid).get();
  const userData = userDoc.data() || {};
  const userRole = (userData.role || request.auth.token.role || "STUDENT").toUpperCase();

  const isCR = userRole === "CR";
  const isTeacher = userRole === "TEACHER";
  const isAdmin = userRole === "ADMIN";

  if (!isCR && !isTeacher && !isAdmin) {
    throw new HttpsError("permission-denied", "Unauthorized to delete schedule slots.");
  }

  if (isTeacher && !isAdmin) {
    const assignedIds: string[] = userData.assignedCourseIds || [];
    if (!assignedIds.includes(slot.courseId)) {
      throw new HttpsError("permission-denied", "Teachers can only delete slots for their assigned courses.");
    }
  }

  if (isCR) {
    if (slot.createdBy !== callerUid && slot.targetYear !== userData.year) {
      throw new HttpsError("permission-denied", "CR can only delete slots within their cohort.");
    }
  }

  await slotRef.delete();
  return { success: true, message: "Schedule slot deleted successfully." };
});

// ─── 4. GET TEACHER AVAILABILITY ────────────────────────────────────────────

export const getTeacherAvailability = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const { teacherId, dayOfWeek } = request.data || {};
  if (!teacherId || !dayOfWeek) {
    throw new HttpsError("invalid-argument", "teacherId and dayOfWeek are required.");
  }

  const normDay = dayOfWeek.trim().toUpperCase();

  const teacherDoc = await db.collection("users").doc(teacherId).get();
  if (!teacherDoc.exists) {
    throw new HttpsError("not-found", "Teacher not found.");
  }

  // Fetch all scheduled classes for this teacher on this day
  const snap = await db
    .collection("schedules")
    .where("teacherId", "==", teacherId)
    .where("dayOfWeek", "==", normDay)
    .get();

  const busySlots = snap.docs.map((doc) => {
    const data = doc.data();
    return {
      id: doc.id,
      courseCode: data.courseCode || "",
      courseTitle: data.courseTitle || "",
      room: data.room || "",
      startTime: data.startTime || "",
      endTime: data.endTime || "",
      startMins: parseTimeToMinutes(data.startTime),
      endMins: parseTimeToMinutes(data.endTime),
    };
  });

  // Sort busy slots by start time
  busySlots.sort((a, b) => a.startMins - b.endMins);

  // Calculate free windows between 08:00 AM (480 mins) and 05:00 PM (1020 mins)
  const DAY_START = 480; // 08:00
  const DAY_END = 1020;  // 17:00

  const availableWindows: { startTime: string; endTime: string; durationMinutes: number }[] = [];
  let currentPointer = DAY_START;

  for (const slot of busySlots) {
    if (slot.startMins > currentPointer) {
      const duration = slot.startMins - currentPointer;
      if (duration >= 30) {
        availableWindows.push({
          startTime: minutesToTimeString(currentPointer),
          endTime: minutesToTimeString(slot.startMins),
          durationMinutes: duration,
        });
      }
    }
    currentPointer = Math.max(currentPointer, slot.endMins);
  }

  if (currentPointer < DAY_END) {
    const duration = DAY_END - currentPointer;
    if (duration >= 30) {
      availableWindows.push({
        startTime: minutesToTimeString(currentPointer),
        endTime: minutesToTimeString(DAY_END),
        durationMinutes: duration,
      });
    }
  }

  return {
    teacherId,
    teacherName: teacherDoc.data()?.fullName || "Faculty",
    dayOfWeek: normDay,
    busySlots,
    availableWindows,
  };
});

function minutesToTimeString(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  const padH = String(h).padStart(2, "0");
  const padM = String(m).padStart(2, "0");
  return `${padH}:${padM}`;
}

// ─── 5. WHATSAPP ROUTINE BROADCAST GENERATOR ────────────────────────────────

export const getWhatsAppBroadcast = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const { year, semester } = request.data || {};
  let targetYear = year;
  let targetSemester = semester;

  if (!targetYear || !targetSemester) {
    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    if (userDoc.exists) {
      targetYear = targetYear || userDoc.data()?.year || 1;
      targetSemester = targetSemester || userDoc.data()?.semester || 1;
    }
  }

  const { tomorrowDate, tomorrowDayOfWeek } = getTomorrowInfo();

  const snap = await db
    .collection("schedules")
    .where("targetYear", "==", Number(targetYear))
    .where("targetSemester", "==", Number(targetSemester))
    .where("dayOfWeek", "==", tomorrowDayOfWeek)
    .get();

  const slots = snap.docs.map((d) => d.data());
  slots.sort((a, b) => parseTimeToMinutes(a.startTime) - parseTimeToMinutes(b.startTime));

  let formattedText = `*Department of Computer Science & Engineering, JnU*\n`;
  formattedText += `*Class Routine Notice*\n\n`;
  formattedText += `*Date:* ${tomorrowDate} (${tomorrowDayOfWeek})\n`;
  formattedText += `*Batch:* Year ${targetYear}, Semester ${targetSemester}\n`;
  formattedText += `────────────────────────────────────────\n`;

  if (slots.length === 0) {
    formattedText += `Notice: There are no classes scheduled for tomorrow.\n`;
  } else {
    formattedText += `*Scheduled Classes:*\n\n`;
    slots.forEach((s, idx) => {
      formattedText += `${idx + 1}. *${s.courseCode}: ${s.courseTitle}*\n`;
      formattedText += `   Time: ${s.startTime} - ${s.endTime}\n`;
      formattedText += `   Room: ${s.room}\n`;
      if (s.teacherName) {
        formattedText += `   Faculty: ${s.teacherName}\n`;
      }
      if (s.isExtraClass) {
        formattedText += `   Note: Extra Class\n`;
      }
      if (idx < slots.length - 1) {
        formattedText += `\n`;
      }
    });
  }

  const { recipientPhone } = request.data || {};
  const urls = buildWhatsAppShareUrls(formattedText, recipientPhone);

  return {
    targetDate: tomorrowDate,
    dayOfWeek: tomorrowDayOfWeek,
    totalSlots: slots.length,
    formattedText,
    whatsappUrl: urls.webUrl,
    whatsappAppUrl: urls.appUrl,
    waMeUrl: urls.waMeUrl,
    targetPhone: urls.targetPhone || null,
  };
});
