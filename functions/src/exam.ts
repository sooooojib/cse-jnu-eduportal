import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { parseTimeToMinutes, checkIntervalOverlap } from "./schedule";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// ─── DATE HELPERS ────────────────────────────────────────────────────────────

export function getTodayDateUtc6(): string {
  const nowUtc = new Date();
  const utc6 = new Date(nowUtc.getTime() + 6 * 60 * 60 * 1000);
  const year = utc6.getUTCFullYear();
  const month = String(utc6.getUTCMonth() + 1).padStart(2, "0");
  const day = String(utc6.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export interface ExamInput {
  courseId: string;
  courseCode?: string;
  courseTitle?: string;
  title: string;
  examDate: string; // YYYY-MM-DD
  startTime: string; // HH:MM or HH:MM AM/PM
  endTime: string; // HH:MM or HH:MM AM/PM
  room: string;
  year: number;
  semester: number;
  type?: "MID_TERM" | "FINAL" | "QUIZ" | "LAB_EXAM" | "CT";
  instructions?: string;
  invigilatorName?: string;
  invigilatorId?: string;
}

export function validateExamInput(data: any, isNew: boolean = true): {
  courseId: string;
  title: string;
  examDate: string;
  normStartTime: string;
  normEndTime: string;
  startMinutes: number;
  endMinutes: number;
  room: string;
  year: number;
  semester: number;
  type: string;
  instructions: string;
  invigilatorName: string;
  invigilatorId: string;
} {
  const {
    courseId,
    title,
    examDate,
    startTime,
    endTime,
    room,
    year,
    semester,
    type,
    instructions,
    invigilatorName,
    invigilatorId,
  } = data || {};

  if (!courseId || typeof courseId !== "string" || !courseId.trim()) {
    throw new HttpsError("invalid-argument", "Course ID is required.");
  }
  if (!title || typeof title !== "string" || !title.trim()) {
    throw new HttpsError("invalid-argument", "Exam title is required.");
  }
  if (!examDate || typeof examDate !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(examDate.trim())) {
    throw new HttpsError("invalid-argument", "Valid exam date in YYYY-MM-DD format is required.");
  }
  if (!startTime || typeof startTime !== "string") {
    throw new HttpsError("invalid-argument", "Start time is required.");
  }
  if (!endTime || typeof endTime !== "string") {
    throw new HttpsError("invalid-argument", "End time is required.");
  }
  if (!room || typeof room !== "string" || !room.trim()) {
    throw new HttpsError("invalid-argument", "Exam room/hall is required.");
  }

  const numYear = Number(year);
  const numSemester = Number(semester);
  if (isNaN(numYear) || numYear < 1 || numYear > 5) {
    throw new HttpsError("invalid-argument", "Year must be between 1 and 5.");
  }
  if (isNaN(numSemester) || numSemester < 1 || numSemester > 3) {
    throw new HttpsError("invalid-argument", "Semester must be between 1 and 3.");
  }

  const startMinutes = parseTimeToMinutes(startTime);
  const endMinutes = parseTimeToMinutes(endTime);
  const duration = endMinutes - startMinutes;

  if (duration <= 0) {
    throw new HttpsError("invalid-argument", "End time must be after start time.");
  }
  if (duration < 15 || duration > 300) {
    throw new HttpsError("invalid-argument", "Exam duration must be between 15 minutes and 5 hours.");
  }

  const cleanExamDate = examDate.trim();
  const today = getTodayDateUtc6();
  if (isNew && cleanExamDate < today) {
    throw new HttpsError("invalid-argument", "Cannot schedule an exam on a past date.");
  }

  return {
    courseId: courseId.trim(),
    title: title.trim(),
    examDate: cleanExamDate,
    normStartTime: startTime.trim(),
    normEndTime: endTime.trim(),
    startMinutes,
    endMinutes,
    room: room.trim(),
    year: numYear,
    semester: numSemester,
    type: (type || "MID_TERM").toUpperCase(),
    instructions: (instructions || "").trim(),
    invigilatorName: (invigilatorName || "").trim(),
    invigilatorId: (invigilatorId || "").trim(),
  };
}

// ─── TRANSACTIONAL CORE EXAM OPERATIONS ─────────────────────────────────────

export async function executeCreateExam(
  callerUid: string,
  data: ExamInput,
  firestore: admin.firestore.Firestore = db
) {
  // 1. Fetch Caller Profile & RBAC
  const userDoc = await firestore.collection("users").doc(callerUid).get();
  if (!userDoc.exists) {
    throw new HttpsError("unauthenticated", "User record not found in system.");
  }

  const userData = userDoc.data()!;
  const role = (userData.role || "STUDENT").toUpperCase();
  const userYear = Number(userData.year);
  const userSemester = Number(userData.semester);
  const assignedCourses: string[] = userData.assignedCourseIds || [];

  if (role === "STUDENT") {
    throw new HttpsError(
      "permission-denied",
      "Regular students are not authorized to schedule exams. Please contact your Class Representative or Course Teacher."
    );
  }

  const validated = validateExamInput(data, true);

  // Role validation
  if (role === "CR") {
    if (userYear !== validated.year || userSemester !== validated.semester) {
      throw new HttpsError(
        "permission-denied",
        `CR authorization error: You can only schedule exams for Year ${userYear} Semester ${userSemester}.`
      );
    }
  } else if (role === "TEACHER") {
    if (!assignedCourses.includes(validated.courseId)) {
      throw new HttpsError(
        "permission-denied",
        "Teacher authorization error: You can only schedule exams for courses assigned to you."
      );
    }
  }

  // Verify course
  const courseDoc = await firestore.collection("courses").doc(validated.courseId).get();
  let courseCode = data.courseCode || validated.courseId;
  let courseTitle = data.courseTitle || validated.title;

  if (courseDoc.exists) {
    const cData = courseDoc.data()!;
    courseCode = cData.code || courseCode;
    courseTitle = cData.title || courseTitle;

    if (role === "CR") {
      if (Number(cData.year) !== validated.year || Number(cData.semester) !== validated.semester) {
        throw new HttpsError(
          "invalid-argument",
          "Selected course does not belong to your academic cohort."
        );
      }
    }
  }

  // 2. Transactional Collision Prevention (Room Collision & Cohort Collision)
  return await firestore.runTransaction(async (transaction) => {
    const sameDateQuery = firestore
      .collection("exams")
      .where("examDate", "==", validated.examDate);

    const snapshot = await transaction.get(sameDateQuery);

    for (const doc of snapshot.docs) {
      const existing = doc.data();
      const existStart = parseTimeToMinutes(existing.startTime);
      const existEnd = parseTimeToMinutes(existing.endTime);

      if (checkIntervalOverlap(validated.startMinutes, validated.endMinutes, existStart, existEnd)) {
        // Room collision
        if (existing.room.toUpperCase() === validated.room.toUpperCase()) {
          throw new HttpsError(
            "already-exists",
            `Room Collision: "${validated.room}" is already reserved for an exam (${existing.courseCode}: ${existing.title}) from ${existing.startTime} to ${existing.endTime}.`
          );
        }

        // Cohort collision
        if (
          Number(existing.year) === validated.year &&
          Number(existing.semester) === validated.semester
        ) {
          throw new HttpsError(
            "already-exists",
            `Cohort Collision: Year ${validated.year} Semester ${validated.semester} already has an exam (${existing.courseCode}) scheduled during this time window (${existing.startTime} - ${existing.endTime}).`
          );
        }
      }
    }

    const examRef = firestore.collection("exams").doc();
    const examData = {
      id: examRef.id,
      courseId: validated.courseId,
      courseCode,
      courseTitle,
      title: validated.title,
      examDate: validated.examDate,
      startTime: validated.normStartTime,
      endTime: validated.normEndTime,
      room: validated.room,
      year: validated.year,
      semester: validated.semester,
      type: validated.type,
      instructions: validated.instructions,
      invigilatorName: validated.invigilatorName || userData.fullName || "",
      invigilatorId: validated.invigilatorId || (role === "TEACHER" ? callerUid : ""),
      createdBy: callerUid,
      creatorRole: role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.set(examRef, examData);

    return {
      success: true,
      message: `Exam scheduled successfully: ${courseCode} (${validated.title}) on ${validated.examDate}.`,
      exam: {
        ...examData,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    };
  });
}

export async function executeUpdateExam(
  callerUid: string,
  examId: string,
  data: ExamInput,
  firestore: admin.firestore.Firestore = db
) {
  if (!examId || typeof examId !== "string") {
    throw new HttpsError("invalid-argument", "Exam ID is required for editing.");
  }

  const userDoc = await firestore.collection("users").doc(callerUid).get();
  if (!userDoc.exists) {
    throw new HttpsError("unauthenticated", "User record not found in system.");
  }

  const userData = userDoc.data()!;
  const role = (userData.role || "STUDENT").toUpperCase();
  const userYear = Number(userData.year);
  const userSemester = Number(userData.semester);
  const assignedCourses: string[] = userData.assignedCourseIds || [];

  const examDoc = await firestore.collection("exams").doc(examId).get();
  if (!examDoc.exists) {
    throw new HttpsError("not-found", "Exam schedule record not found.");
  }

  const existingExam = examDoc.data()!;

  // Role validation: Admin, CR of that cohort, Teacher assigned to course, or creator
  if (role === "ADMIN") {
    // Admin has full edit rights
  } else if (role === "CR") {
    if (userYear !== Number(existingExam.year) || userSemester !== Number(existingExam.semester)) {
      throw new HttpsError("permission-denied", "You can only edit exams for your registered cohort.");
    }
  } else if (role === "TEACHER") {
    if (!assignedCourses.includes(existingExam.courseId) && existingExam.createdBy !== callerUid) {
      throw new HttpsError("permission-denied", "You can only edit exams for courses assigned to you.");
    }
  } else if (existingExam.createdBy !== callerUid) {
    throw new HttpsError("permission-denied", "You are not authorized to edit this exam.");
  }

  const validated = validateExamInput(data, false);

  // Collision check excluding current exam
  return await firestore.runTransaction(async (transaction) => {
    const sameDateQuery = firestore
      .collection("exams")
      .where("examDate", "==", validated.examDate);

    const snapshot = await transaction.get(sameDateQuery);

    for (const doc of snapshot.docs) {
      if (doc.id === examId) continue;
      const existing = doc.data();
      const existStart = parseTimeToMinutes(existing.startTime);
      const existEnd = parseTimeToMinutes(existing.endTime);

      if (checkIntervalOverlap(validated.startMinutes, validated.endMinutes, existStart, existEnd)) {
        if (existing.room.toUpperCase() === validated.room.toUpperCase()) {
          throw new HttpsError(
            "already-exists",
            `Room Collision: "${validated.room}" is already reserved for another exam from ${existing.startTime} to ${existing.endTime}.`
          );
        }

        if (
          Number(existing.year) === validated.year &&
          Number(existing.semester) === validated.semester
        ) {
          throw new HttpsError(
            "already-exists",
            `Cohort Collision: Year ${validated.year} Semester ${validated.semester} already has another exam scheduled at this time.`
          );
        }
      }
    }

    const examRef = firestore.collection("exams").doc(examId);
    const updatedData = {
      courseId: validated.courseId,
      courseCode: data.courseCode || existingExam.courseCode,
      courseTitle: data.courseTitle || existingExam.courseTitle,
      title: validated.title,
      examDate: validated.examDate,
      startTime: validated.normStartTime,
      endTime: validated.normEndTime,
      room: validated.room,
      year: validated.year,
      semester: validated.semester,
      type: validated.type,
      instructions: validated.instructions,
      invigilatorName: validated.invigilatorName || existingExam.invigilatorName,
      invigilatorId: validated.invigilatorId || existingExam.invigilatorId,
      updatedBy: callerUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.update(examRef, updatedData);

    return {
      success: true,
      message: "Exam updated successfully.",
      exam: {
        id: examId,
        ...existingExam,
        ...updatedData,
        updatedAt: new Date().toISOString(),
      },
    };
  });
}

export async function executeDeleteExam(
  callerUid: string,
  examId: string,
  firestore: admin.firestore.Firestore = db
) {
  if (!examId || typeof examId !== "string") {
    throw new HttpsError("invalid-argument", "Exam ID is required for deletion.");
  }

  const userDoc = await firestore.collection("users").doc(callerUid).get();
  if (!userDoc.exists) {
    throw new HttpsError("unauthenticated", "User record not found in system.");
  }

  const userData = userDoc.data()!;
  const role = (userData.role || "STUDENT").toUpperCase();
  const userYear = Number(userData.year);
  const userSemester = Number(userData.semester);
  const assignedCourses: string[] = userData.assignedCourseIds || [];

  const examDoc = await firestore.collection("exams").doc(examId).get();
  if (!examDoc.exists) {
    throw new HttpsError("not-found", "Exam schedule record not found.");
  }

  const existingExam = examDoc.data()!;

  // Role validation: Admin, CR of that cohort, Teacher assigned to course, or creator
  if (role === "ADMIN") {
    // Admin has full delete rights
  } else if (role === "CR") {
    if (userYear !== Number(existingExam.year) || userSemester !== Number(existingExam.semester)) {
      throw new HttpsError("permission-denied", "You can only delete exams for your registered cohort.");
    }
  } else if (role === "TEACHER") {
    if (!assignedCourses.includes(existingExam.courseId) && existingExam.createdBy !== callerUid) {
      throw new HttpsError("permission-denied", "You can only delete exams for courses assigned to you.");
    }
  } else if (existingExam.createdBy !== callerUid) {
    throw new HttpsError("permission-denied", "You are not authorized to delete this exam.");
  }

  await firestore.collection("exams").doc(examId).delete();

  return {
    success: true,
    message: "Exam deleted successfully.",
  };
}

// ─── CALLABLE CLOUD FUNCTIONS ────────────────────────────────────────────────

export const createExam = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated to schedule an exam.");
  }
  return await executeCreateExam(request.auth.uid, request.data);
});

export const updateExam = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated to update an exam.");
  }
  const { examId, ...data } = request.data || {};
  return await executeUpdateExam(request.auth.uid, examId, data as ExamInput);
});

export const deleteExam = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated to delete an exam.");
  }
  const { examId } = request.data || {};
  return await executeDeleteExam(request.auth.uid, examId);
});
