import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {
  isAdminRole,
  isSystemAdminRole,
  isTeacherRole,
  isStudentSideRole,
  normalizeRole,
  canReviewSignupRequest,
  canAssignRole,
  isValidAcademicSession,
  SELF_SIGNUP_ROLES,
  ROLE_ADMIN,
  ROLE_TEACHER,
  ROLE_CHAIRMAN,
} from "./roles";

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

// ─── AUTH / SIGNUP APPROVAL FUNCTION ─────────────────────────────────────────

/** Loads the caller's role and admin-delegation flag (token role wins, doc as fallback). */
async function resolveCaller(authCtx: { uid: string; token: any }) {
  const doc = await db.collection("users").doc(authCtx.uid).get();
  const data = doc.exists ? doc.data()! : {};
  const role = normalizeRole(authCtx.token?.role || data.role);
  return { role, isAdminDelegate: data.isAdminDelegate === true };
}

export const approveSignupRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const caller = await resolveCaller(request.auth);

  const { requestId, assignedYear, assignedSemester } = request.data || {};
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

  const requestedRole = normalizeRole(reqData.role) || "STUDENT";
  if (!SELF_SIGNUP_ROLES.includes(requestedRole)) {
    throw new HttpsError("invalid-argument", `Signup requests cannot be approved for role ${requestedRole}.`);
  }
  if (!canReviewSignupRequest(caller.role, caller.isAdminDelegate, requestedRole)) {
    throw new HttpsError(
      "permission-denied",
      "Only administrators, the department chairman, or delegated faculty (student/CR requests only) can approve signup requests."
    );
  }

  // The session is fixed to what the applicant chose at signup; approvers cannot
  // change it here (it can be corrected later from the User Directory).
  const session = typeof reqData.session === "string" ? reqData.session.trim() : null;
  if (isStudentSideRole(requestedRole) && session && !isValidAcademicSession(session)) {
    throw new HttpsError("invalid-argument", `Invalid academic session "${session}". Expected format: 2021-2022.`);
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

  const role = requestedRole;
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
    session: isStudentSideRole(role) ? (session || null) : null,
    isAdminDelegate: false,
    assignedCourseIds: [],
    isActive: true,
    createdAt: now,
    updatedAt: now,
  });

  // Mark Signup Request Approved
  await requestRef.update({
    status: "APPROVED",
    reviewedBy: request.auth.uid,
    reviewedByRole: caller.role,
    approvedUserId: userRecord.uid,
    updatedAt: now,
  });

  // Create Welcome In-App Notification for Provisioned User
  const welcomeNotifRef = db.collection("notifications").doc();
  await welcomeNotifRef.set({
    id: welcomeNotifRef.id,
    userId: userRecord.uid,
    title: "Account Approved",
    body: "Welcome to CSE JnU EduPortal! Your account has been verified and activated.",
    notificationType: "SIGNUP_DECISION",
    referenceId: userRecord.uid,
    referenceType: "SIGNUP",
    route: isTeacherRole(role) ? "/dashboard/teacher" : "/dashboard/student",
    isRead: false,
    createdAt: now,
    updatedAt: now,
  });

  // Safe External Communication: Dispatch Onboarding Email (Non-blocking)
  try {
    const { html, text } = generateOnboardingEmailHtml({
      fullName: reqData.fullName,
      email: reqData.email,
      role,
      studentId: reqData.studentId,
      tempPassword: randomPassword,
    });
    await safeDispatchEmail(db, {
      to: reqData.email,
      subject: "Welcome to CSE JnU EduPortal — Your Account Details",
      html,
      text,
      templateType: "ONBOARDING",
      metadata: { userId: userRecord.uid, role },
    });
  } catch (err) {
    console.error("Non-blocking onboarding email error:", err);
  }

  return {
    success: true,
    userId: userRecord.uid,
    tempPassword: randomPassword,
    message: "User approved and provisioned successfully.",
  };
});

export const rejectSignupRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const caller = await resolveCaller(request.auth);

  const { requestId, reason } = request.data || {};
  if (!requestId) {
    throw new HttpsError("invalid-argument", "Missing requestId.");
  }

  const requestRef = db.collection("signupRequests").doc(requestId);
  const requestDoc = await requestRef.get();
  if (!requestDoc.exists) {
    throw new HttpsError("not-found", "Signup request not found.");
  }
  const reqData = requestDoc.data();
  if (!canReviewSignupRequest(caller.role, caller.isAdminDelegate, reqData?.role)) {
    throw new HttpsError(
      "permission-denied",
      "Only administrators, the department chairman, or delegated faculty (student/CR requests only) can reject signup requests."
    );
  }

  const declineReason = reason || "Does not meet departmental verification criteria.";

  await requestRef.update({
    status: "REJECTED",
    rejectionReason: declineReason,
    reviewedBy: request.auth.uid,
    reviewedByRole: caller.role,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Safe External Communication: Dispatch Rejection Notification Email
  if (reqData && reqData.email) {
    try {
      const { html, text } = generateSignupRejectionEmailHtml({
        fullName: reqData.fullName || "Applicant",
        email: reqData.email,
        reason: declineReason,
      });
      await safeDispatchEmail(db, {
        to: reqData.email,
        subject: "CSE JnU EduPortal — Registration Update",
        html,
        text,
        templateType: "SIGNUP_REJECTION",
        metadata: { requestId },
      });
    } catch (err) {
      console.error("Non-blocking rejection email error:", err);
    }
  }

  return { success: true, message: "Signup request rejected." };
});

// ─── STAGE 28: EXTERNAL COMMUNICATION & WHATSAPP ENDPOINTS ───────────────────

import {
  normalizeBangladeshiPhone,
  buildWhatsAppShareUrls,
  generateOnboardingEmailHtml,
  generateSignupRejectionEmailHtml,
  safeDispatchEmail,
} from "./communication";

export const formatBangladeshiPhone = onCall((request) => {
  const phone = request.data?.phone;
  return normalizeBangladeshiPhone(phone);
});

export const generateWhatsAppDeepLinks = onCall((request) => {
  const { text, phone } = request.data || {};
  if (!text || typeof text !== "string") {
    throw new HttpsError("invalid-argument", "Message text is required.");
  }
  return buildWhatsAppShareUrls(text, phone);
});

export const testEmailTransport = onCall(async (request) => {
  if (!request.auth || !isSystemAdminRole(request.auth.token.role)) {
    throw new HttpsError("permission-denied", "Only administrators can test email transport.");
  }
  const to = request.data?.to || request.auth.token.email;
  return await safeDispatchEmail(db, {
    to,
    subject: "CSE JnU EduPortal — Email Transport Verification",
    html: "<p>Email transport test succeeded.</p>",
    text: "Email transport test succeeded.",
    templateType: "TEST",
  });
});

// Note: Semester and Enrollment functions moved to ./semester.ts

// Note: Counseling functions moved to ./counseling.ts for atomic concurrency & validation

// ─── STAGE 27: NOTIFICATION ENGINE & FCM DISPATCH TRIGGER ─────────────────────

import {
  executeRegisterDeviceToken,
  executeUnregisterDeviceToken,
  executeMarkNotificationAsRead,
  executeMarkAllNotificationsAsRead,
  dispatchPushNotification,
} from "./notifications";

export const registerDeviceToken = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated to register device token.");
  }
  const token = request.data?.token;
  return await executeRegisterDeviceToken(db, request.auth.uid, token);
});

export const unregisterDeviceToken = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be authenticated to unregister device token.");
  }
  const token = request.data?.token;
  return await executeUnregisterDeviceToken(db, request.auth.uid, token);
});

export const markNotificationRead = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { notificationId } = request.data || {};
  return await executeMarkNotificationAsRead(
    db,
    { uid: request.auth.uid, role: request.auth.token.role || "STUDENT" },
    notificationId
  );
});

export const markAllNotificationsRead = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  return await executeMarkAllNotificationsAsRead(db, { uid: request.auth.uid });
});

export const onNotificationCreated = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notifData = snap.data();
    await dispatchPushNotification(db, admin.messaging(), event.params.notificationId, notifData);
  }
);

// ─── STAGE 16: ADMIN USER MANAGEMENT ──────────────────────────────────────────

export const createAdminUser = onCall(async (request) => {
  if (!request.auth || !isAdminRole(request.auth.token.role)) {
    throw new HttpsError("permission-denied", "Only administrators or the department chairman can provision new accounts.");
  }

  const { email, password, fullName, studentId, phone, year, semester, session } = request.data || {};
  const role = normalizeRole(request.data?.role);
  if (!email || !fullName || !role) {
    throw new HttpsError("invalid-argument", "Missing required fields (email, fullName, role).");
  }

  if (!canAssignRole(request.auth.token.role, role)) {
    throw new HttpsError("permission-denied", `You are not allowed to provision accounts with role: ${role}`);
  }

  if (session && !isValidAcademicSession(session)) {
    throw new HttpsError("invalid-argument", `Invalid academic session "${session}". Expected format: 2021-2022.`);
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
    session: isStudentSideRole(role) ? (session || null) : null,
    isAdminDelegate: false,
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
  if (!request.auth || !isAdminRole(request.auth.token.role)) {
    throw new HttpsError("permission-denied", "Only administrators or the department chairman can delete accounts.");
  }

  const { userId } = request.data || {};
  if (!userId) {
    throw new HttpsError("invalid-argument", "Missing userId parameter.");
  }

  if (userId === request.auth.uid) {
    throw new HttpsError("failed-precondition", "Administrators cannot delete their own active account.");
  }

  const targetDoc = await db.collection("users").doc(userId).get();
  const targetRole = normalizeRole(targetDoc.data()?.role);
  if (targetRole === ROLE_ADMIN && !isSystemAdminRole(request.auth.token.role)) {
    throw new HttpsError("permission-denied", "Only system administrators can delete administrator accounts.");
  }

  // 1. Delete from Firebase Auth
  try {
    await auth.deleteUser(userId);
  } catch (err: any) {
    console.warn(`Auth user ${userId} deletion notice: ${err.message}`);
  }

  // 2. Clean up course assignments if this user was a teacher
  if (targetDoc.exists) {
    if (isTeacherRole(targetRole)) {
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
  }
);

// ─── CHAIRMAN ROLE: ROLE CHANGES & ADMIN-VIEW DELEGATION ──────────────────────

/**
 * Change an existing user's role (e.g. promote a TEACHER to CHAIRMAN).
 * System ADMIN only. Updates both the Firestore profile and custom claims.
 */
export const updateUserRole = onCall(async (request) => {
  if (!request.auth || !isSystemAdminRole(request.auth.token.role)) {
    throw new HttpsError("permission-denied", "Only system administrators can change user roles.");
  }

  const { userId } = request.data || {};
  const newRole = normalizeRole(request.data?.role);
  if (!userId || typeof userId !== "string") {
    throw new HttpsError("invalid-argument", "Missing userId parameter.");
  }
  if (!canAssignRole(request.auth.token.role, newRole)) {
    throw new HttpsError("invalid-argument", `Invalid role: ${newRole}`);
  }
  if (userId === request.auth.uid && newRole !== ROLE_ADMIN) {
    throw new HttpsError("failed-precondition", "You cannot remove your own administrator role.");
  }

  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User not found.");
  }
  const data = userDoc.data()!;
  const oldRole = normalizeRole(data.role);

  // Faculty <-> Chairman/Admin changes keep course assignments; moving to a
  // student-side role is not supported (different identity requirements).
  if (isStudentSideRole(newRole) !== isStudentSideRole(oldRole)) {
    throw new HttpsError(
      "failed-precondition",
      "Changing between student-side (STUDENT/CR) and staff roles is not supported. Create a new account instead."
    );
  }

  const user = await auth.getUser(userId);
  const existingClaims = user.customClaims || {};
  await auth.setCustomUserClaims(userId, { ...existingClaims, role: newRole });

  await userRef.update({
    role: newRole,
    // Delegation only applies to plain faculty.
    isAdminDelegate: newRole === ROLE_TEACHER ? (data.isAdminDelegate === true) : false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  if (newRole === ROLE_CHAIRMAN) {
    const notifRef = db.collection("notifications").doc();
    await notifRef.set({
      id: notifRef.id,
      userId,
      title: "Chairman Access Granted",
      body: "You now have Chairman access. Sign out and sign in again to use the Department Admin view.",
      notificationType: "ROLE_CHANGE",
      referenceId: userId,
      referenceType: "USER",
      route: "/dashboard/teacher",
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return { success: true, userId, oldRole, newRole, message: `Role changed from ${oldRole} to ${newRole}.` };
});

/**
 * Grant or revoke the limited Admin View (signup review committee) for a
 * faculty member. Allowed for ADMIN and CHAIRMAN.
 */
export const setAdminDelegate = onCall(async (request) => {
  if (!request.auth || !isAdminRole(request.auth.token.role)) {
    throw new HttpsError("permission-denied", "Only administrators or the department chairman can manage admin-view access.");
  }
  const { userId, enabled } = request.data || {};
  if (!userId || typeof userId !== "string" || typeof enabled !== "boolean") {
    throw new HttpsError("invalid-argument", "userId (string) and enabled (boolean) are required.");
  }
  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User not found.");
  }
  if (normalizeRole(userDoc.data()?.role) !== ROLE_TEACHER) {
    throw new HttpsError("failed-precondition", "Admin-view delegation can only be granted to faculty members.");
  }
  await userRef.update({
    isAdminDelegate: enabled,
    adminDelegateGrantedBy: enabled ? request.auth.uid : null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true, userId, isAdminDelegate: enabled };
});

// ─── STAGE 20: AUTHORITATIVE ATTENDANCE FUNCTIONS ───────────────────────────

export {
  startAttendanceSession,
  deactivateAttendanceSession,
  submitAttendanceCode,
  getAttendanceSessionRoster,
  updateAttendanceRoster,
  generateSecureAttendanceCode,
} from "./attendance";

// ─── STAGE 21: AUTHORITATIVE SCHEDULE FUNCTIONS ─────────────────────────────

export {
  createScheduleSlot,
  updateScheduleSlot,
  deleteScheduleSlot,
  getTeacherAvailability,
  getWhatsAppBroadcast,
  parseTimeToMinutes,
  checkIntervalOverlap,
  getTomorrowInfo,
} from "./schedule";

// ─── STAGE 22: AUTHORITATIVE EXAM FUNCTIONS ─────────────────────────────────

export {
  createExam,
  updateExam,
  deleteExam,
  validateExamInput,
  executeCreateExam,
  executeUpdateExam,
  executeDeleteExam,
  getTodayDateUtc6,
} from "./exam";

// ─── STAGE 23: AUTHORITATIVE COUNSELING FUNCTIONS ───────────────────────────

export {
  APPROVED_PURPOSES,
  normalizeCounselingPurpose,
  validateCounselingSlotInput,
  executeCreateCounselingSlot,
  executeDeleteCounselingSlot,
  executeRequestBooking,
  executeApproveBooking,
  executeRejectBooking,
  executeCancelBooking,
  createCounselingSlot,
  deleteCounselingSlot,
  requestCounselingBooking,
  approveCounselingBooking,
  rejectCounselingBooking,
  cancelCounselingBooking,
} from "./counseling";

// ─── STAGE 24: AUTHORITATIVE FEEDBACK FUNCTIONS ─────────────────────────────

export {
  validateFeedbackInput,
  executeSubmitFeedback,
  executeEditFeedback,
  executeReplyToFeedback,
  executeEditFeedbackReply,
  executeGetTeacherFeedback,
  executeGetStudentFeedback,
  executeGetAdminFeedback,
  submitFeedback,
  editFeedback,
  replyToFeedback,
  editFeedbackReply,
} from "./feedback";

// ─── STAGE 25: SEMESTER AND ENROLLMENT WORKFLOW ─────────────────────────────

export {
  validateSemesterInput,
  executeSubmitSemesterRequest,
  executeChangeSemesterRequest,
  executeDismissSemesterRejection,
  executeApproveSemesterUpgrade,
  executeRejectSemesterUpgrade,
  executeGetStudentSemesterStatus,
  requestSemesterUpgrade,
  changeSemesterUpgradeRequest,
  dismissSemesterRejection,
  approveSemesterUpgrade,
  rejectSemesterUpgrade,
  getSemesterStatus,
} from "./semester";

// ─── STAGE 26: FIREBASE CLOUD STORAGE POLICY & DELETION ────────────────────

export {
  MAX_IMAGE_SIZE_BYTES,
  MAX_DOCUMENT_SIZE_BYTES,
  ALLOWED_IMAGE_MIME_TYPES,
  ALLOWED_DOCUMENT_MIME_TYPES,
  DISALLOWED_EXTENSIONS,
  sanitizePathSegment,
  isApprovedStoragePath,
  validateFileTypeAndSize,
  evaluateUploadPermission,
  evaluateDeletePermission,
  generateCanonicalStoragePath,
  executeGetStorageUploadPolicy,
  getStorageUploadPolicy,
  deleteStorageFile,
} from "./storage";



