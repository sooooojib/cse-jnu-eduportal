import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

// ─── AUTH / SIGNUP APPROVAL FUNCTION ─────────────────────────────────────────

export const approveSignupRequest = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only administrators can approve signup requests.");
  }

  const { requestId, assignedYear, assignedSemester } = request.data;
  if (!requestId) {
    throw new HttpsError("invalid-argument", "Missing requestId parameter.");
  }

  const requestRef = db.collection("signupRequests").doc(requestId);
  const requestDoc = await requestRef.get();
  if (!requestDoc.exists) {
    throw new HttpsError("not-found", "Signup request not found.");
  }

  const reqData = requestDoc.data()!;
  if (reqData.status !== "PENDING") {
    throw new HttpsError("failed-precondition", `Request is already ${reqData.status}.`);
  }

  // Generate random 10-character initial password
  const randomPassword = Math.random().toString(36).slice(-8) + "Aa1!";

  // Create Firebase Auth user
  let userRecord: admin.auth.UserRecord;
  try {
    userRecord = await auth.createUser({
      email: reqData.email,
      password: randomPassword,
      displayName: reqData.fullName,
      emailVerified: true,
    });
  } catch (err: any) {
    throw new HttpsError("already-exists", `Failed to create auth user: ${err.message}`);
  }

  const role = reqData.role || "STUDENT";
  const year = assignedYear || 1;
  const semester = assignedSemester || 1;

  // Set custom claims for sub-millisecond RBAC in Security Rules
  await auth.setCustomUserClaims(userRecord.uid, {
    role,
    year,
    semester,
  });

  // Create Firestore User Document
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection("users").doc(userRecord.uid).set({
    email: reqData.email,
    fullName: reqData.fullName,
    role,
    studentId: reqData.studentId || null,
    phone: reqData.phone || null,
    year: role === "STUDENT" || role === "CR" ? year : null,
    semester: role === "STUDENT" || role === "CR" ? semester : null,
    assignedCourseIds: [],
    isActive: true,
    createdAt: now,
    updatedAt: now,
  });

  // Mark Signup Request Approved
  await requestRef.update({
    status: "APPROVED",
    reviewedBy: request.auth.uid,
    approvedUserId: userRecord.uid,
    updatedAt: now,
  });

  return {
    success: true,
    userId: userRecord.uid,
    tempPassword: randomPassword,
    message: "User approved and provisioned successfully.",
  };
});

export const rejectSignupRequest = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only administrators can reject signup requests.");
  }

  const { requestId, reason } = request.data;
  if (!requestId) {
    throw new HttpsError("invalid-argument", "Missing requestId.");
  }

  const requestRef = db.collection("signupRequests").doc(requestId);
  await requestRef.update({
    status: "REJECTED",
    rejectionReason: reason || "Does not meet departmental verification criteria.",
    reviewedBy: request.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: "Signup request rejected." };
});

// ─── SEMESTER UPGRADE APPROVAL ────────────────────────────────────────────────

export const approveSemesterUpgrade = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only administrators can approve semester upgrades.");
  }

  const { requestId } = request.data;
  const upgradeRef = db.collection("semesterUpgradeRequests").doc(requestId);
  const upgradeDoc = await upgradeRef.get();
  if (!upgradeDoc.exists) {
    throw new HttpsError("not-found", "Semester upgrade request not found.");
  }

  const uData = upgradeDoc.data()!;
  const studentId = uData.studentId;
  const newYear = uData.requestedYear;
  const newSemester = uData.requestedSemester;

  // Update Firestore user document
  await db.collection("users").doc(studentId).update({
    year: newYear,
    semester: newSemester,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Update Custom Claims
  const userRecord = await auth.getUser(studentId);
  const existingClaims = userRecord.customClaims || {};
  await auth.setCustomUserClaims(studentId, {
    ...existingClaims,
    year: newYear,
    semester: newSemester,
  });

  await upgradeRef.update({
    status: "APPROVED",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Post in-app notification
  await db.collection("notifications").add({
    userId: studentId,
    title: "Semester Upgrade Approved",
    body: `Your academic level has been updated to Year ${newYear}, Semester ${newSemester}.`,
    notificationType: "SEMESTER",
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// ─── COUNSELING BOOKING MUTUAL-EXCLUSION TRANSACTION ─────────────────────────

export const approveCounselingBooking = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  const { bookingId } = request.data;
  const bookingRef = db.collection("counselingBookings").doc(bookingId);

  return db.runTransaction(async (transaction) => {
    const bookingDoc = await transaction.get(bookingRef);
    if (!bookingDoc.exists) {
      throw new HttpsError("not-found", "Booking not found.");
    }

    const bData = bookingDoc.data()!;
    if (bData.teacherId !== request.auth!.uid && request.auth!.token.role !== "ADMIN") {
      throw new HttpsError("permission-denied", "Only the assigned teacher can approve this booking.");
    }

    const slotId = bData.slotId;
    const slotRef = db.collection("counselingSlots").doc(slotId);
    const slotDoc = await transaction.get(slotRef);
    if (!slotDoc.exists) {
      throw new HttpsError("not-found", "Associated counseling slot not found.");
    }

    // Lock Slot
    transaction.update(slotRef, {
      isBooked: true,
      status: "BOOKED",
      bookedStudentId: bData.studentId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Approve winning booking
    transaction.update(bookingRef, {
      status: "APPROVED",
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Query and reject all other pending bookings for the same slot
    const competingQuery = db.collection("counselingBookings")
      .where("slotId", "==", slotId)
      .where("status", "==", "PENDING");
    
    const competingDocs = await transaction.get(competingQuery);
    competingDocs.forEach((doc) => {
      if (doc.id !== bookingId) {
        transaction.update(doc.ref, {
          status: "REJECTED",
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

    return { success: true, message: "Booking approved and slot locked atomically." };
  });
});

// ─── PUSH NOTIFICATION DISPATCH TRIGGER ──────────────────────────────────────

export const onNotificationCreated = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notifData = snap.data();
    const userId = notifData.userId;
    if (!userId) return;

    // Fetch user FCM tokens
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) return;

    const fcmTokens: string[] = userDoc.data()?.fcmTokens || [];
    if (fcmTokens.length === 0) return;

    const payload: admin.messaging.MulticastMessage = {
      tokens: fcmTokens,
      notification: {
        title: notifData.title || "CSE JnU EduPortal",
        body: notifData.body || "",
      },
      data: {
        notificationType: notifData.notificationType || "GENERAL",
        referenceId: notifData.referenceId || "",
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(payload);
      console.log(`Dispatched FCM notifications: ${response.successCount} successful.`);
    } catch (err) {
      console.error("FCM dispatch error:", err);
    }
  }
);

// ─── STAGE 16: ADMIN USER MANAGEMENT ──────────────────────────────────────────

export const createAdminUser = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only administrators can provision new accounts.");
  }

  const { email, password, fullName, role, studentId, phone, year, semester } = request.data;
  if (!email || !fullName || !role) {
    throw new HttpsError("invalid-argument", "Missing required fields (email, fullName, role).");
  }

  const validRoles = ["STUDENT", "TEACHER", "CR", "ADMIN"];
  if (!validRoles.includes(role)) {
    throw new HttpsError("invalid-argument", `Invalid role: ${role}`);
  }

  if ((role === "STUDENT" || role === "CR") && !studentId) {
    throw new HttpsError("invalid-argument", "Student ID is required for Students and CRs.");
  }

  // Check duplicate email
  try {
    const existing = await auth.getUserByEmail(email);
    if (existing) {
      throw new HttpsError("already-exists", "A user account with this email address already exists.");
    }
  } catch (err: any) {
    if (err.code !== "auth/user-not-found" && err.code !== 5) {
      if (err instanceof HttpsError) throw err;
    }
  }

  // Check duplicate studentId
  if (studentId) {
    const dupCheck = await db.collection("users").where("studentId", "==", studentId).get();
    if (!dupCheck.empty) {
      throw new HttpsError("already-exists", `A student account with ID ${studentId} already exists.`);
    }
  }

  // Create Firebase Auth user
  let userRecord: admin.auth.UserRecord;
  try {
    userRecord = await auth.createUser({
      email,
      password: password || Math.random().toString(36).slice(-8) + "Aa1!",
      displayName: fullName,
      emailVerified: true,
    });
  } catch (err: any) {
    throw new HttpsError("internal", `Failed to create auth user: ${err.message}`);
  }

  // Inject custom claims
  await auth.setCustomUserClaims(userRecord.uid, {
    role,
    year: (role === "STUDENT" || role === "CR") ? (year || 1) : null,
    semester: (role === "STUDENT" || role === "CR") ? (semester || 1) : null,
  });

  // Create user document in Firestore
  const now = admin.firestore.FieldValue.serverTimestamp();
  const userData = {
    id: userRecord.uid,
    email,
    fullName,
    role,
    studentId: studentId || null,
    phone: phone || null,
    year: (role === "STUDENT" || role === "CR") ? (year || 1) : null,
    semester: (role === "STUDENT" || role === "CR") ? (semester || 1) : null,
    assignedCourseIds: [],
    isActive: true,
    createdAt: now,
    updatedAt: now,
  };
  await db.collection("users").doc(userRecord.uid).set(userData);

  return {
    success: true,
    userId: userRecord.uid,
    user: userData,
    message: `Account for ${fullName} (${role}) provisioned successfully.`,
  };
});

export const deleteUserByAdmin = onCall(async (request) => {
  if (!request.auth || request.auth.token.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only administrators can delete accounts.");
  }

  const { userId } = request.data;
  if (!userId) {
    throw new HttpsError("invalid-argument", "Missing userId parameter.");
  }

  if (userId === request.auth.uid) {
    throw new HttpsError("failed-precondition", "Administrators cannot delete their own active account.");
  }

  // 1. Delete from Firebase Auth
  try {
    await auth.deleteUser(userId);
  } catch (err: any) {
    console.warn(`Auth user ${userId} deletion notice: ${err.message}`);
  }

  // 2. Clean up course assignments if this user was a teacher
  const userDoc = await db.collection("users").doc(userId).get();
  if (userDoc.exists) {
    const role = userDoc.data()?.role;
    if (role === "TEACHER") {
      const assignedQuery = await db.collection("courseAssignments").where("teacherId", "==", userId).get();
      const batch = db.batch();
      assignedQuery.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      const coursesQuery = await db.collection("courses").where("teacherId", "==", userId).get();
      const courseBatch = db.batch();
      coursesQuery.docs.forEach((doc) => {
        courseBatch.update(doc.ref, {
          teacherId: null,
          teacherName: null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await courseBatch.commit();
    }
  }

  // 3. Delete user document from Firestore
  await db.collection("users").doc(userId).delete();

  return {
    success: true,
    message: "User deleted and references unassigned successfully.",
  };
});
