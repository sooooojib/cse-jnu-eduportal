import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

// Ensure Firebase Admin is initialized
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// ─── UTILITY HELPERS ──────────────────────────────────────────────────────────

const SAFE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"; // 32 chars, excludes 0/O, 1/I

/**
 * Generates a cryptographically secure 6-character uppercase verification code.
 */
export function generateSecureAttendanceCode(): string {
  const bytes = crypto.randomBytes(6);
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += SAFE_ALPHABET[bytes[i] % SAFE_ALPHABET.length];
  }
  return code;
}

async function getUserRole(auth: any): Promise<string | undefined> {
  if (auth.token?.role) return auth.token.role;
  try {
    const uDoc = await db.collection("users").doc(auth.uid).get();
    return uDoc.data()?.role;
  } catch (_) {
    return undefined;
  }
}

// ─── 1. START ATTENDANCE SESSION (TEACHER) ────────────────────────────────────

export const startAttendanceSession = onCall(async (request) => {
  // 1. Authoritative Auth Check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const role = await getUserRole(request.auth);
  const isTeacher = role === "TEACHER" || role === "ADMIN";
  if (!isTeacher) {
    throw new HttpsError("permission-denied", "Only teachers or administrators can start an attendance session.");
  }

  const { courseId, durationMinutes } = request.data || {};
  if (!courseId || typeof courseId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid courseId parameter.");
  }

  const duration = typeof durationMinutes === "number" && durationMinutes > 0 && durationMinutes <= 180
    ? durationMinutes
    : 15; // Default 15 minutes validity

  // 2. Authoritative Course Verification & Teacher Authorization
  const courseRef = db.collection("courses").doc(courseId);
  const courseDoc = await courseRef.get();
  if (!courseDoc.exists) {
    throw new HttpsError("not-found", `Course ${courseId} does not exist.`);
  }

  const courseData = courseDoc.data()!;
  const teacherUid = request.auth.uid;
  const isDirectTeacher = courseData.teacherId === teacherUid;

  // Also check courseAssignments table in case of secondary assignment
  let isAssigned = isDirectTeacher || role === "ADMIN";
  if (!isAssigned) {
    const assignCheck = await db.collection("courseAssignments")
      .where("courseId", "==", courseId)
      .where("teacherId", "==", teacherUid)
      .limit(1)
      .get();
    if (!assignCheck.empty) {
      isAssigned = true;
    }
  }

  if (!isAssigned) {
    throw new HttpsError("permission-denied", "Unauthorized. You are not the assigned teacher for this course.");
  }

  // 3. Fetch Teacher Profile Name
  let teacherName = "Professor";
  const teacherUserDoc = await db.collection("users").doc(teacherUid).get();
  if (teacherUserDoc.exists && teacherUserDoc.data()?.fullName) {
    teacherName = teacherUserDoc.data()!.fullName;
  } else if (courseData.teacherName) {
    teacherName = courseData.teacherName;
  }

  // 4. Deactivate any previous active session for this course/teacher
  const existingActive = await db.collection("attendanceSessions")
    .where("courseId", "==", courseId)
    .where("teacherId", "==", teacherUid)
    .where("isActive", "==", true)
    .get();

  if (!existingActive.empty) {
    const batch = db.batch();
    existingActive.docs.forEach((doc) => {
      batch.update(doc.ref, {
        isActive: false,
        status: "COMPLETED",
        closedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
  }

  // 5. Generate secure 6-character code
  let code = generateSecureAttendanceCode();
  // Ensure no active collision
  const collision = await db.collection("attendanceSessions")
    .where("code", "==", code)
    .where("isActive", "==", true)
    .limit(1)
    .get();
  if (!collision.empty) {
    code = generateSecureAttendanceCode();
  }

  // 6. Define validity & expiration
  const nowMillis = Date.now();
  const expiresAtMillis = nowMillis + duration * 60 * 1000;
  const expiresAt = admin.firestore.Timestamp.fromMillis(expiresAtMillis);
  const now = admin.firestore.FieldValue.serverTimestamp();

  // 7. Create Session Document
  const sessionRef = db.collection("attendanceSessions").doc();
  const sessionData = {
    id: sessionRef.id,
    courseId,
    courseCode: courseData.code || courseId,
    courseTitle: courseData.title || "",
    teacherId: teacherUid,
    teacherName,
    code,
    isActive: true,
    status: "ACTIVE",
    sessionDate: new Date().toISOString().substring(0, 10),
    startTime: now,
    expiresAt,
    targetYear: courseData.year || 1,
    targetSemester: courseData.semester || 1,
    totalPresentCount: 0,
    createdAt: now,
    updatedAt: now,
  };

  await sessionRef.set(sessionData);

  return {
    success: true,
    session: {
      ...sessionData,
      id: sessionRef.id,
      expiresAtMillis,
    },
    message: `Attendance session active with code ${code}. Valid for ${duration} minutes.`,
  };
});

// ─── 2. DEACTIVATE ATTENDANCE SESSION (TEACHER) ────────────────────────────────

export const deactivateAttendanceSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const role = await getUserRole(request.auth);
  const { sessionId } = request.data || {};
  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid sessionId parameter.");
  }

  const sessionRef = db.collection("attendanceSessions").doc(sessionId);
  const sessionDoc = await sessionRef.get();
  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Attendance session not found.");
  }

  const sessionData = sessionDoc.data()!;
  const isOwner = sessionData.teacherId === request.auth.uid;
  const isTeacherOrAdmin = role === "TEACHER" || role === "ADMIN";
  if (!isOwner && role !== "ADMIN" && !isTeacherOrAdmin) {
    throw new HttpsError("permission-denied", "Unauthorized. You cannot deactivate another teacher's attendance session.");
  }

  await sessionRef.update({
    isActive: false,
    status: "COMPLETED",
    closedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    sessionId,
    message: "Attendance session has been deactivated successfully.",
  };
});

// ─── 3. SUBMIT ATTENDANCE CODE (STUDENT / CR) ─────────────────────────────────

export const submitAttendanceCode = onCall(async (request) => {
  // 1. Authenticated User Check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const role = await getUserRole(request.auth);
  const isStudentOrCr = role === "STUDENT" || role === "CR";
  if (!isStudentOrCr) {
    throw new HttpsError("permission-denied", "Only enrolled students and CRs can submit attendance.");
  }

  const { code, courseId } = request.data || {};

  // 2. Format & Length Validation (Exact 6 chars)
  if (!code || typeof code !== "string" || code.trim().length !== 6) {
    throw new HttpsError("invalid-argument", "Attendance code must be exactly 6 characters.");
  }
  const cleanCode = code.trim().toUpperCase();

  const studentUid = request.auth.uid;

  // 3. Authoritative Firestore Transaction with Concurrent Duplicate Protection
  return db.runTransaction(async (transaction) => {
    // A. Query active session matching code
    const activeQuery = db.collection("attendanceSessions")
      .where("code", "==", cleanCode)
      .where("isActive", "==", true)
      .limit(1);

    const activeSnap = await transaction.get(activeQuery);

    if (activeSnap.empty) {
      // Diagnostic check: check if code exists but is inactive or expired
      const anyQuery = db.collection("attendanceSessions")
        .where("code", "==", cleanCode)
        .limit(1);
      const anySnap = await transaction.get(anyQuery);

      if (!anySnap.empty) {
        const pastDoc = anySnap.docs[0].data();
        if (!pastDoc.isActive || pastDoc.status === "COMPLETED") {
          throw new HttpsError("failed-precondition", "This attendance session has already been closed by the professor.");
        }
        if (pastDoc.expiresAt && pastDoc.expiresAt.toMillis() < Date.now()) {
          throw new HttpsError("deadline-exceeded", "This attendance session has expired.");
        }
      }
      throw new HttpsError("not-found", "Invalid attendance code. No active session found.");
    }

    const sessionDoc = activeSnap.docs[0];
    const sessionData = sessionDoc.data();
    const sessionId = sessionDoc.id;

    // B. Validate Session is Active
    if (!sessionData.isActive || sessionData.status !== "ACTIVE") {
      throw new HttpsError("failed-precondition", "This attendance session is not active.");
    }

    // C. Validate Session is Not Expired
    const nowMillis = Date.now();
    const expiresAtMillis = sessionData.expiresAt ? sessionData.expiresAt.toMillis() : 0;
    if (expiresAtMillis > 0 && expiresAtMillis < nowMillis) {
      transaction.update(sessionDoc.ref, {
        isActive: false,
        status: "EXPIRED",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw new HttpsError("deadline-exceeded", "Attendance code has expired.");
    }

    // D. Validate Course Match (if courseId provided)
    if (courseId && courseId !== sessionData.courseId) {
      throw new HttpsError("invalid-argument", "This code is for a different course than selected.");
    }

    // E. Read and Validate Student Profile
    const studentUserRef = db.collection("users").doc(studentUid);
    const studentUserDoc = await transaction.get(studentUserRef);
    if (!studentUserDoc.exists) {
      throw new HttpsError("not-found", "Student user profile not found.");
    }

    const studentData = studentUserDoc.data()!;
    if (studentData.isActive === false) {
      throw new HttpsError("permission-denied", "Student account is suspended or inactive.");
    }

    // F. Verify Enrollment / Course Eligibility
    const cohortMatches = studentData.year === sessionData.targetYear &&
                          studentData.semester === sessionData.targetSemester;

    let isEnrolled = cohortMatches;
    if (!isEnrolled) {
      const enrollmentDocId = `${sessionData.courseId}_${studentUid}`;
      const enrollmentRef = db.collection("enrollments").doc(enrollmentDocId);
      const enrollmentDoc = await transaction.get(enrollmentRef);
      if (enrollmentDoc.exists && enrollmentDoc.data()?.status !== "DROPPED") {
        isEnrolled = true;
      }
    }

    if (!isEnrolled) {
      throw new HttpsError("permission-denied", "You are not enrolled in this course.");
    }

    // G. Duplicate Protection Check via Composite Key `${sessionId}_${studentUid}`
    const recordDocId = `${sessionId}_${studentUid}`;
    const recordRef = db.collection("attendance").doc(recordDocId);
    const existingRecord = await transaction.get(recordRef);

    if (existingRecord.exists) {
      throw new HttpsError("already-exists", "Attendance has already been recorded for this session.");
    }

    // H. Atomically Write PRESENT Attendance Record
    const recordData = {
      id: recordDocId,
      sessionId,
      studentId: studentUid,
      studentName: studentData.fullName || "Student",
      studentRoll: studentData.studentId || "",
      courseId: sessionData.courseId,
      courseCode: sessionData.courseCode,
      courseTitle: sessionData.courseTitle,
      status: "PRESENT",
      isManualOverride: false,
      date: sessionData.sessionDate || new Date().toISOString().substring(0, 10),
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    transaction.set(recordRef, recordData);

    // I. Atomically Increment Session Attendance Count
    transaction.update(sessionDoc.ref, {
      totalPresentCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      message: "Attendance verified and marked PRESENT successfully.",
      recordId: recordDocId,
      courseCode: sessionData.courseCode,
      courseTitle: sessionData.courseTitle,
      date: sessionData.sessionDate,
    };
  });
});

// ─── 4. GET SESSION ROSTER (TEACHER) ──────────────────────────────────────────

export const getAttendanceSessionRoster = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const role = await getUserRole(request.auth);
  const { sessionId } = request.data || {};
  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "Missing or invalid sessionId parameter.");
  }

  const sessionRef = db.collection("attendanceSessions").doc(sessionId);
  const sessionDoc = await sessionRef.get();
  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Attendance session not found.");
  }

  const sessionData = sessionDoc.data()!;
  const isOwner = sessionData.teacherId === request.auth.uid;
  const isTeacherOrAdmin = role === "TEACHER" || role === "ADMIN";
  if (!isOwner && role !== "ADMIN" && !isTeacherOrAdmin) {
    throw new HttpsError("permission-denied", "Unauthorized to view this attendance roster.");
  }

  // 1. Fetch all candidate students for targetYear and targetSemester
  const studentsSnap = await db.collection("users")
    .where("role", "in", ["STUDENT", "CR"])
    .where("year", "==", sessionData.targetYear)
    .where("semester", "==", sessionData.targetSemester)
    .get();

  const studentMap = new Map<string, any>();
  studentsSnap.docs.forEach((doc) => {
    studentMap.set(doc.id, { id: doc.id, ...doc.data() });
  });

  // Also include any explicit enrollments
  const enrollmentsSnap = await db.collection("enrollments")
    .where("courseId", "==", sessionData.courseId)
    .get();

  for (const enrDoc of enrollmentsSnap.docs) {
    const sId = enrDoc.data().studentId;
    if (sId && !studentMap.has(sId)) {
      const sDoc = await db.collection("users").doc(sId).get();
      if (sDoc.exists) {
        studentMap.set(sId, { id: sId, ...sDoc.data() });
      }
    }
  }

  // 2. Fetch all recorded attendance documents for this session
  const recordsSnap = await db.collection("attendance")
    .where("sessionId", "==", sessionId)
    .get();

  const attendanceMap = new Map<string, any>();
  recordsSnap.docs.forEach((doc) => {
    const data = doc.data();
    attendanceMap.set(data.studentId, data);
  });

  // 3. Assemble complete roster
  const roster = Array.from(studentMap.values()).map((s) => {
    const record = attendanceMap.get(s.id);
    return {
      studentId: s.id,
      studentRoll: s.studentId || "N/A",
      studentName: s.fullName || "Student",
      status: record ? record.status : "ABSENT",
      isManualOverride: record ? (record.isManualOverride || false) : false,
      verifiedAt: record?.verifiedAt ? record.verifiedAt.toDate().toISOString() : null,
    };
  });

  // Sort alphabetically or by student roll
  roster.sort((a, b) => a.studentRoll.localeCompare(b.studentRoll));

  const totalPresent = roster.filter((r) => r.status === "PRESENT").length;

  return {
    success: true,
    sessionId,
    courseCode: sessionData.courseCode,
    courseTitle: sessionData.courseTitle,
    sessionDate: sessionData.sessionDate,
    code: sessionData.code,
    isActive: sessionData.isActive,
    totalEnrolled: roster.length,
    totalPresent,
    roster,
  };
});

// ─── 5. UPDATE ATTENDANCE ROSTER (TEACHER MANUAL OVERRIDE) ────────────────────

export const updateAttendanceRoster = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated.");
  }

  const role = await getUserRole(request.auth);
  const { sessionId, updates } = request.data || {};
  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "Missing sessionId.");
  }
  if (!Array.isArray(updates) || updates.length === 0) {
    throw new HttpsError("invalid-argument", "Missing or empty updates array.");
  }

  const sessionRef = db.collection("attendanceSessions").doc(sessionId);
  const sessionDoc = await sessionRef.get();
  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Attendance session not found.");
  }

  const sessionData = sessionDoc.data()!;
  const isOwner = sessionData.teacherId === request.auth.uid;
  const isTeacherOrAdmin = role === "TEACHER" || role === "ADMIN";
  if (!isOwner && role !== "ADMIN" && !isTeacherOrAdmin) {
    throw new HttpsError("permission-denied", "Unauthorized to update this attendance roster.");
  }

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const update of updates) {
    const { studentId, status } = update;
    if (!studentId || (status !== "PRESENT" && status !== "ABSENT")) {
      continue;
    }

    const recordId = `${sessionId}_${studentId}`;
    const recordRef = db.collection("attendance").doc(recordId);

    // Fetch student info if creating record for the first time
    const studentDoc = await db.collection("users").doc(studentId).get();
    const studentData = studentDoc.data() || {};

    batch.set(recordRef, {
      id: recordId,
      sessionId,
      studentId,
      studentName: studentData.fullName || "Student",
      studentRoll: studentData.studentId || "",
      courseId: sessionData.courseId,
      courseCode: sessionData.courseCode,
      courseTitle: sessionData.courseTitle,
      status,
      isManualOverride: true,
      date: sessionData.sessionDate || new Date().toISOString().substring(0, 10),
      verifiedAt: status === "PRESENT" ? now : null,
      updatedAt: now,
    }, { merge: true });
  }

  await batch.commit();

  // Recalculate present count
  const presentSnap = await db.collection("attendance")
    .where("sessionId", "==", sessionId)
    .where("status", "==", "PRESENT")
    .get();

  const totalPresentCount = presentSnap.size;
  await sessionRef.update({
    totalPresentCount,
    updatedAt: now,
  });

  return {
    success: true,
    sessionId,
    totalPresentCount,
    updatedCount: updates.length,
    message: "Attendance roster updated successfully.",
  };
});
