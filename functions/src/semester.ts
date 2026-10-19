import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();
const auth = admin.auth();

// ─── VALIDATION ─────────────────────────────────────────────────────────────

export function validateSemesterInput(year: any, semester: any): { year: number; semester: number } {
  const y = Number(year);
  const s = Number(semester);

  if (!Number.isInteger(y) || y < 1 || y > 4) {
    throw new HttpsError("invalid-argument", `Academic year must be an integer between 1 and 4. Received: ${year}`);
  }

  if (!Number.isInteger(s) || s < 1 || s > 2) {
    throw new HttpsError("invalid-argument", `Academic semester must be either 1 or 2. Received: ${semester}`);
  }

  return { year: y, semester: s };
}

// ─── CORE EXECUTORS ─────────────────────────────────────────────────────────

export async function executeSubmitSemesterRequest(
  firestore: admin.firestore.Firestore,
  studentId: string,
  requestedYear: number,
  requestedSemester: number
) {
  const validated = validateSemesterInput(requestedYear, requestedSemester);

  const userDoc = await firestore.collection("users").doc(studentId).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "Student user profile not found.");
  }
  const userData = userDoc.data() || {};

  // Check duplicate pending request
  const existingPending = await firestore
    .collection("semesterUpgradeRequests")
    .where("studentId", "==", studentId)
    .where("status", "==", "PENDING")
    .get();

  if (!existingPending.empty) {
    throw new HttpsError(
      "failed-precondition",
      "You already have a pending enrollment/semester request. Please wait for administrator review or change your existing request."
    );
  }

  const currentYear = userData.year ?? null;
  const currentSemester = userData.semester ?? null;
  const studentName = userData.fullName || "Student";
  const studentRoll = userData.studentId || "";

  const payload = {
    studentId,
    studentName,
    studentRoll,
    currentYear,
    currentSemester,
    requestedYear: validated.year,
    requestedSemester: validated.semester,
    status: "PENDING",
    rejectionReason: null,
    isDismissed: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const docRef = await firestore.collection("semesterUpgradeRequests").add(payload);

  return {
    id: docRef.id,
    ...payload,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };
}

export async function executeChangeSemesterRequest(
  firestore: admin.firestore.Firestore,
  studentId: string,
  requestId: string,
  requestedYear: number,
  requestedSemester: number
) {
  const validated = validateSemesterInput(requestedYear, requestedSemester);

  const reqRef = firestore.collection("semesterUpgradeRequests").doc(requestId);
  const reqDoc = await reqRef.get();

  if (!reqDoc.exists) {
    throw new HttpsError("not-found", "Semester upgrade request not found.");
  }

  const reqData = reqDoc.data()!;
  if (reqData.studentId !== studentId) {
    throw new HttpsError("permission-denied", "You can only modify your own enrollment request.");
  }

  if (reqData.status !== "PENDING") {
    throw new HttpsError(
      "failed-precondition",
      `Cannot change a request with status ${reqData.status}. Only PENDING requests can be changed.`
    );
  }

  await reqRef.update({
    requestedYear: validated.year,
    requestedSemester: validated.semester,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const updatedDoc = await reqRef.get();
  return { id: reqRef.id, ...updatedDoc.data() };
}

export async function executeDismissSemesterRejection(
  firestore: admin.firestore.Firestore,
  studentId: string,
  requestId: string
) {
  const reqRef = firestore.collection("semesterUpgradeRequests").doc(requestId);
  const reqDoc = await reqRef.get();

  if (!reqDoc.exists) {
    throw new HttpsError("not-found", "Semester upgrade request not found.");
  }

  const reqData = reqDoc.data()!;
  if (reqData.studentId !== studentId) {
    throw new HttpsError("permission-denied", "You can only dismiss your own request notifications.");
  }

  if (reqData.status !== "REJECTED") {
    throw new HttpsError(
      "failed-precondition",
      `Only REJECTED requests can be dismissed. Current status: ${reqData.status}`
    );
  }

  await reqRef.update({
    isDismissed: true,
    status: "DISMISSED",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: "Rejection dismissed successfully." };
}

export async function executeApproveSemesterUpgrade(
  firestore: admin.firestore.Firestore,
  authInstance: admin.auth.Auth | null,
  adminUid: string,
  requestId: string
) {
  const upgradeRef = firestore.collection("semesterUpgradeRequests").doc(requestId);

  let studentId = "";
  let newYear = 1;
  let newSemester = 1;

  await firestore.runTransaction(async (transaction) => {
    const upgradeDoc = await transaction.get(upgradeRef);
    if (!upgradeDoc.exists) {
      throw new HttpsError("not-found", "Semester upgrade request not found.");
    }

    const uData = upgradeDoc.data()!;
    if (uData.status !== "PENDING") {
      throw new HttpsError(
        "failed-precondition",
        `This request has already been processed with status ${uData.status}. Cannot process twice.`
      );
    }

    studentId = uData.studentId;
    newYear = uData.requestedYear;
    newSemester = uData.requestedSemester;
    const now = admin.firestore.FieldValue.serverTimestamp();

    // 1. Update user profile
    const userRef = firestore.collection("users").doc(studentId);
    transaction.set(
      userRef,
      {
        year: newYear,
        semester: newSemester,
        updatedAt: now,
      },
      { merge: true }
    );

    // 2. Mark request as APPROVED
    transaction.update(upgradeRef, {
      status: "APPROVED",
      approvedBy: adminUid,
      approvedAt: now,
      updatedAt: now,
    });

    // 3. Create notification for student
    const notifRef = firestore.collection("notifications").doc();
    transaction.set(notifRef, {
      userId: studentId,
      title: "Semester Upgrade Approved",
      body: `Your academic level has been updated to Year ${newYear}, Semester ${newSemester}.`,
      notificationType: "SEMESTER",
      isRead: false,
      createdAt: now,
    });
  });

  // 4. Update custom claims if authInstance is provided
  if (authInstance && studentId) {
    try {
      const userRecord = await authInstance.getUser(studentId);
      const existingClaims = userRecord.customClaims || {};
      await authInstance.setCustomUserClaims(studentId, {
        ...existingClaims,
        year: newYear,
        semester: newSemester,
      });
    } catch (_) {}
  }

  // 5. Update cohort enrollments for affected dashboard/course/schedule data
  try {
    const coursesSnap = await firestore
      .collection("courses")
      .where("year", "==", newYear)
      .where("semester", "==", newSemester)
      .get();

    for (const cDoc of coursesSnap.docs) {
      const enrollmentId = `enroll_${studentId}_${cDoc.id}`;
      await firestore.collection("enrollments").doc(enrollmentId).set(
        {
          id: enrollmentId,
          studentId,
          courseId: cDoc.id,
          year: newYear,
          semester: newSemester,
          enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  } catch (_) {}

  return { success: true, newYear, newSemester };
}

export async function executeRejectSemesterUpgrade(
  firestore: admin.firestore.Firestore,
  adminUid: string,
  requestId: string,
  reason?: string
) {
  const upgradeRef = firestore.collection("semesterUpgradeRequests").doc(requestId);

  await firestore.runTransaction(async (transaction) => {
    const upgradeDoc = await transaction.get(upgradeRef);
    if (!upgradeDoc.exists) {
      throw new HttpsError("not-found", "Semester upgrade request not found.");
    }

    const uData = upgradeDoc.data()!;
    if (uData.status !== "PENDING") {
      throw new HttpsError(
        "failed-precondition",
        `This request has already been processed with status ${uData.status}. Cannot reject twice.`
      );
    }

    const studentId = uData.studentId;
    const now = admin.firestore.FieldValue.serverTimestamp();
    const rejectionReason = reason || "Academic eligibility requirements not met.";

    // 1. Mark request as REJECTED
    transaction.update(upgradeRef, {
      status: "REJECTED",
      rejectionReason,
      rejectedBy: adminUid,
      updatedAt: now,
    });

    // 2. Create notification for student
    const notifRef = firestore.collection("notifications").doc();
    transaction.set(notifRef, {
      userId: studentId,
      title: "Semester Upgrade Rejected",
      body: `Your semester upgrade request was declined. Reason: ${rejectionReason}`,
      notificationType: "SEMESTER",
      isRead: false,
      createdAt: now,
    });
  });

  return { success: true, message: "Request rejected successfully." };
}

export async function executeGetStudentSemesterStatus(
  firestore: admin.firestore.Firestore,
  studentId: string
) {
  const userDoc = await firestore.collection("users").doc(studentId).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }
  const userData = userDoc.data()!;

  // Look for latest active or pending request (excluding dismissed)
  const reqSnap = await firestore
    .collection("semesterUpgradeRequests")
    .where("studentId", "==", studentId)
    .orderBy("createdAt", "desc")
    .limit(5)
    .get();

  const currentYear = userData.year ?? null;
  const currentSemester = userData.semester ?? null;

  if (reqSnap.empty) {
    return {
      currentYear,
      currentSemester,
      requestedYear: null,
      requestedSemester: null,
      status: currentYear == null || currentSemester == null ? "NO_ENROLLMENT" : "APPROVED",
      rejectionReason: null,
    };
  }

  // Find most recent non-dismissed request
  const validDoc = reqSnap.docs.find((d) => d.data().status !== "DISMISSED");

  if (!validDoc) {
    return {
      currentYear,
      currentSemester,
      requestedYear: null,
      requestedSemester: null,
      status: currentYear == null || currentSemester == null ? "NO_ENROLLMENT" : "APPROVED",
      rejectionReason: null,
    };
  }

  const rData = validDoc.data();
  return {
    id: validDoc.id,
    currentYear,
    currentSemester,
    requestedYear: rData.requestedYear,
    requestedSemester: rData.requestedSemester,
    status: rData.status,
    rejectionReason: rData.rejectionReason ?? null,
    updatedAt: rData.updatedAt ? rData.updatedAt.toDate?.().toISOString() || rData.updatedAt : null,
  };
}

// ─── CLOUD FUNCTIONS (CALLABLES) ────────────────────────────────────────────

export const requestSemesterUpgrade = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { requestedYear, requestedSemester } = request.data || {};
  return executeSubmitSemesterRequest(db, request.auth.uid, requestedYear, requestedSemester);
});

export const changeSemesterUpgradeRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { requestId, requestedYear, requestedSemester } = request.data || {};
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }
  return executeChangeSemesterRequest(db, request.auth.uid, requestId, requestedYear, requestedSemester);
});

export const dismissSemesterRejection = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { requestId } = request.data || {};
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }
  return executeDismissSemesterRejection(db, request.auth.uid, requestId);
});

export const approveSemesterUpgrade = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only administrators can approve semester upgrades.");
  }
  const { requestId } = request.data || {};
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }
  return executeApproveSemesterUpgrade(db, auth, request.auth.uid, requestId);
});

export const rejectSemesterUpgrade = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only administrators can reject semester upgrades.");
  }
  const { requestId, reason } = request.data || {};
  if (!requestId) {
    throw new HttpsError("invalid-argument", "requestId is required.");
  }
  return executeRejectSemesterUpgrade(db, request.auth.uid, requestId, reason);
});

export const getSemesterStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  return executeGetStudentSemesterStatus(db, request.auth.uid);
});
