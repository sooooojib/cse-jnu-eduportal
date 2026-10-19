import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// ─── TYPES & INTERFACES ─────────────────────────────────────────────────────

export interface AttachmentData {
  id: string;
  fileName: string;
  fileUrl: string;
  mimeType: string;
  fileSize: number;
}

export interface FeedbackReplyData {
  id: string;
  teacherId?: string;
  teacherName: string;
  replyText: string;
  attachments?: AttachmentData[];
  createdAt: string;
  updatedAt?: string;
}

export interface FeedbackInput {
  teacherId: string;
  courseId?: string;
  courseCode?: string;
  courseTitle?: string;
  rating: number; // 1 to 5
  comments: string;
  isAnonymous?: boolean;
  attachments?: AttachmentData[];
}

// ─── VALIDATION HELPERS ─────────────────────────────────────────────────────

export function validateFeedbackInput(data: any): {
  teacherId: string;
  courseId?: string;
  courseCode?: string;
  courseTitle?: string;
  rating: number;
  comments: string;
  isAnonymous: boolean;
  attachments: AttachmentData[];
} {
  const { teacherId, courseId, courseCode, courseTitle, rating, comments, isAnonymous, attachments } = data || {};

  if (!teacherId || typeof teacherId !== "string" || !teacherId.trim()) {
    throw new HttpsError("invalid-argument", "Teacher ID is required.");
  }

  const numRating = Number(rating);
  if (isNaN(numRating) || !Number.isInteger(numRating) || numRating < 1 || numRating > 5) {
    throw new HttpsError("invalid-argument", "Rating must be an integer between 1 and 5.");
  }

  if (!comments || typeof comments !== "string" || comments.trim().length < 5) {
    throw new HttpsError("invalid-argument", "Comments must be at least 5 characters long.");
  }

  const validAttachments: AttachmentData[] = [];
  if (Array.isArray(attachments)) {
    for (const a of attachments) {
      if (a && typeof a.fileName === "string" && typeof a.fileUrl === "string") {
        validAttachments.push({
          id: a.id || `att_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
          fileName: a.fileName.trim(),
          fileUrl: a.fileUrl.trim(),
          mimeType: a.mimeType || "application/octet-stream",
          fileSize: Number(a.fileSize) || 0,
        });
      }
    }
  }

  return {
    teacherId: teacherId.trim(),
    courseId: courseId ? String(courseId).trim() : undefined,
    courseCode: courseCode ? String(courseCode).trim() : undefined,
    courseTitle: courseTitle ? String(courseTitle).trim() : undefined,
    rating: numRating,
    comments: comments.trim(),
    isAnonymous: Boolean(isAnonymous),
    attachments: validAttachments,
  };
}

// ─── CORE EXECUTORS (Injectable for Unit & Concurrency Testing) ──────────────

/**
 * 1. SUBMIT FEEDBACK
 * High-Security Anonymity:
 * When isAnonymous is true:
 * - feedback/{id} stores studentId: "ANONYMOUS", studentName: "Anonymous Student", studentEmail: null.
 * - feedbackIdentities/{id} stores the real student identity (ADMIN & Student Author ONLY).
 * Teachers cannot access feedbackIdentities, guaranteeing identity protection.
 */
export async function executeSubmitFeedback(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string; fullName?: string; email?: string },
  data: any
) {
  // Authorization: Student or CR (or Admin)
  if (caller.role !== "STUDENT" && caller.role !== "CR" && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only students or CRs can submit course and faculty feedback.");
  }

  const validated = validateFeedbackInput(data);

  // Fetch teacher details
  let teacherName = "Faculty Member";
  const teacherDoc = await firestore.collection("users").doc(validated.teacherId).get();
  if (teacherDoc.exists) {
    const tData = teacherDoc.data()!;
    teacherName = tData.fullName || teacherName;
  }

  // Fetch student details if not present in caller
  let studentName = caller.fullName || "Student";
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
  const feedbackRef = firestore.collection("feedback").doc();
  const identityRef = firestore.collection("feedbackIdentities").doc(feedbackRef.id);

  // Public/Teacher-accessible document
  const feedbackDocData = {
    id: feedbackRef.id,
    teacherId: validated.teacherId,
    teacherName,
    courseId: validated.courseId || null,
    courseCode: validated.courseCode || null,
    courseTitle: validated.courseTitle || null,
    rating: validated.rating,
    comments: validated.comments,
    isAnonymous: validated.isAnonymous,
    // Sensitive identity field: masked if anonymous
    studentId: validated.isAnonymous ? "ANONYMOUS" : caller.uid,
    studentName: validated.isAnonymous ? "Anonymous Student" : studentName,
    studentEmail: validated.isAnonymous ? null : studentEmail,
    attachments: validated.attachments,
    replies: [],
    hasReplied: false,
    createdAt: now,
    updatedAt: now,
  };

  // Secure identity document (Admin & Student Author ONLY)
  const identityDocData = {
    id: feedbackRef.id,
    feedbackId: feedbackRef.id,
    studentId: caller.uid,
    studentName: studentName || "Student",
    studentEmail: studentEmail || "",
    teacherId: validated.teacherId,
    isAnonymous: validated.isAnonymous,
    createdAt: now,
    updatedAt: now,
  };

  const batch = firestore.batch();
  batch.set(feedbackRef, feedbackDocData);
  batch.set(identityRef, identityDocData);

  // Notify teacher of incoming feedback
  const teacherNotifRef = firestore.collection("notifications").doc();
  batch.set(teacherNotifRef, {
    id: teacherNotifRef.id,
    userId: validated.teacherId,
    title: "New Student Feedback",
    body: `You received new ${validated.isAnonymous ? "anonymous " : ""}feedback${validated.courseCode ? " for " + validated.courseCode : ""}.`,
    notificationType: "FEEDBACK_SUBMISSION",
    referenceId: feedbackRef.id,
    referenceType: "FEEDBACK",
    route: "/teacher/feedback",
    isRead: false,
    createdAt: now,
    updatedAt: now,
  });

  await batch.commit();

  return {
    success: true,
    feedbackId: feedbackRef.id,
    feedback: feedbackDocData,
    message: validated.isAnonymous
      ? "Anonymous feedback submitted securely. Your identity is protected."
      : "Feedback submitted successfully.",
  };
}

/**
 * 2. EDIT FEEDBACK
 * Student author can update rating, comments, attachments, or anonymity.
 */
export async function executeEditFeedback(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string; fullName?: string; email?: string },
  feedbackId: string,
  data: any
) {
  if (!feedbackId || typeof feedbackId !== "string") {
    throw new HttpsError("invalid-argument", "Missing feedbackId.");
  }

  const identityRef = firestore.collection("feedbackIdentities").doc(feedbackId);
  const identityDoc = await identityRef.get();
  if (!identityDoc.exists) {
    throw new HttpsError("not-found", "Feedback record not found.");
  }

  const idData = identityDoc.data()!;
  if (idData.studentId !== caller.uid && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "You can only edit feedback you submitted.");
  }

  const feedbackRef = firestore.collection("feedback").doc(feedbackId);
  const feedbackDoc = await feedbackRef.get();
  if (!feedbackDoc.exists) {
    throw new HttpsError("not-found", "Feedback document not found.");
  }

  const numRating = Number(data.rating);
  if (isNaN(numRating) || numRating < 1 || numRating > 5) {
    throw new HttpsError("invalid-argument", "Rating must be between 1 and 5.");
  }
  if (!data.comments || typeof data.comments !== "string" || data.comments.trim().length < 5) {
    throw new HttpsError("invalid-argument", "Comments must be at least 5 characters long.");
  }

  const isAnonymous = typeof data.isAnonymous === "boolean" ? data.isAnonymous : idData.isAnonymous;
  const attachments = Array.isArray(data.attachments) ? data.attachments : (feedbackDoc.data()?.attachments || []);

  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = firestore.batch();
  batch.update(feedbackRef, {
    rating: numRating,
    comments: data.comments.trim(),
    isAnonymous,
    studentId: isAnonymous ? "ANONYMOUS" : idData.studentId,
    studentName: isAnonymous ? "Anonymous Student" : idData.studentName,
    studentEmail: isAnonymous ? null : idData.studentEmail,
    attachments,
    updatedAt: now,
  });

  batch.update(identityRef, {
    isAnonymous,
    updatedAt: now,
  });

  await batch.commit();

  return { success: true, message: "Feedback updated successfully." };
}

/**
 * 3. TEACHER REPLY TO FEEDBACK
 */
export async function executeReplyToFeedback(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string; fullName?: string },
  feedbackId: string,
  replyText: string,
  attachments?: AttachmentData[]
) {
  if (!feedbackId || typeof feedbackId !== "string") {
    throw new HttpsError("invalid-argument", "Missing feedbackId.");
  }
  if (!replyText || typeof replyText !== "string" || !replyText.trim()) {
    throw new HttpsError("invalid-argument", "Reply text cannot be empty.");
  }

  const feedbackRef = firestore.collection("feedback").doc(feedbackId);
  const feedbackDoc = await feedbackRef.get();
  if (!feedbackDoc.exists) {
    throw new HttpsError("not-found", "Feedback not found.");
  }

  const fData = feedbackDoc.data()!;
  if (fData.teacherId !== caller.uid && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only the assigned teacher can reply to this feedback.");
  }

  let teacherName = caller.fullName || "Faculty Member";
  if (!caller.fullName) {
    const uDoc = await firestore.collection("users").doc(caller.uid).get();
    if (uDoc.exists) {
      teacherName = uDoc.data()?.fullName || teacherName;
    }
  }

  const replyId = `rep_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const newReply: FeedbackReplyData = {
    id: replyId,
    teacherId: caller.uid,
    teacherName,
    replyText: replyText.trim(),
    attachments: attachments || [],
    createdAt: new Date().toISOString(),
  };

  const existingReplies: any[] = fData.replies || [];
  const updatedReplies = [...existingReplies, newReply];

  const now = admin.firestore.FieldValue.serverTimestamp();
  await feedbackRef.update({
    replies: updatedReplies,
    hasReplied: true,
    updatedAt: now,
  });

  // Notify student author (securely looking up studentId from feedbackIdentities so anonymity is preserved)
  let studentRecipientId = fData.studentId !== "ANONYMOUS" ? fData.studentId : null;
  if (!studentRecipientId) {
    const identDoc = await firestore.collection("feedbackIdentities").doc(feedbackId).get();
    if (identDoc.exists) {
      studentRecipientId = identDoc.data()?.studentId;
    }
  }

  if (studentRecipientId) {
    const studentNotifRef = firestore.collection("notifications").doc();
    await studentNotifRef.set({
      id: studentNotifRef.id,
      userId: studentRecipientId,
      title: "Feedback Response Received",
      body: `${teacherName} replied to your feedback${fData.courseCode ? " on " + fData.courseCode : ""}.`,
      notificationType: "FEEDBACK_REPLY",
      referenceId: feedbackId,
      referenceType: "FEEDBACK",
      route: "/feedback",
      isRead: false,
      createdAt: now,
      updatedAt: now,
    });
  }

  return { success: true, replyId, reply: newReply };
}

/**
 * 4. EDIT FEEDBACK REPLY
 */
export async function executeEditFeedbackReply(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string },
  feedbackId: string,
  replyId: string,
  newReplyText: string,
  attachments?: AttachmentData[]
) {
  if (!feedbackId || !replyId) {
    throw new HttpsError("invalid-argument", "Missing feedbackId or replyId.");
  }
  if (!newReplyText || !newReplyText.trim()) {
    throw new HttpsError("invalid-argument", "Reply text cannot be empty.");
  }

  const feedbackRef = firestore.collection("feedback").doc(feedbackId);
  const feedbackDoc = await feedbackRef.get();
  if (!feedbackDoc.exists) {
    throw new HttpsError("not-found", "Feedback not found.");
  }

  const fData = feedbackDoc.data()!;
  if (fData.teacherId !== caller.uid && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Unauthorized to edit this reply.");
  }

  const existingReplies: any[] = fData.replies || [];
  let found = false;
  const updatedReplies = existingReplies.map((r) => {
    if (r.id === replyId) {
      found = true;
      return {
        ...r,
        replyText: newReplyText.trim(),
        attachments: attachments || r.attachments,
        updatedAt: new Date().toISOString(),
      };
    }
    return r;
  });

  if (!found) {
    throw new HttpsError("not-found", "Reply not found in this feedback.");
  }

  await feedbackRef.update({
    replies: updatedReplies,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: "Reply updated successfully." };
}

/**
 * 5. GET TEACHER FEEDBACK (Supports ALL, REPLIED, NOT_REPLIED)
 * Anonymity is guaranteed: teacher never receives studentId, studentName, or email if isAnonymous.
 */
export async function executeGetTeacherFeedback(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string },
  filter: "ALL" | "REPLIED" | "NOT_REPLIED" = "ALL"
) {
  if (caller.role !== "TEACHER" && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only teachers or administrators can view received feedback.");
  }

  const querySnap = await firestore
    .collection("feedback")
    .where("teacherId", "==", caller.uid)
    .get();

  let items = querySnap.docs.map((doc) => {
    const data = doc.data();
    // Guarantee identity sanitization for teachers
    if (data.isAnonymous === true) {
      data.studentId = "ANONYMOUS";
      data.studentName = "Anonymous Student";
      data.studentEmail = null;
    }
    return { id: doc.id, ...data };
  });

  if (filter === "REPLIED") {
    items = items.filter((item: any) => item.hasReplied === true || (item.replies && item.replies.length > 0));
  } else if (filter === "NOT_REPLIED") {
    items = items.filter((item: any) => item.hasReplied !== true && (!item.replies || item.replies.length === 0));
  }

  return items;
}

/**
 * 6. GET STUDENT FEEDBACK SUBMISSIONS
 * Student author sees both their anonymous and non-anonymous submissions.
 */
export async function executeGetStudentFeedback(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string }
) {
  if (caller.role !== "STUDENT" && caller.role !== "CR" && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Unauthorized.");
  }

  // Read student's identity mappings
  const idSnap = await firestore
    .collection("feedbackIdentities")
    .where("studentId", "==", caller.uid)
    .get();

  const feedbackIds = idSnap.docs.map((doc) => doc.data().feedbackId || doc.id);
  if (feedbackIds.length === 0) {
    return [];
  }

  // Fetch feedback documents
  const items: any[] = [];
  for (const fId of feedbackIds) {
    const fDoc = await firestore.collection("feedback").doc(fId).get();
    if (fDoc.exists) {
      items.push({ id: fDoc.id, ...fDoc.data() });
    }
  }

  return items;
}

/**
 * 7. GET ADMIN ALL FEEDBACK (Institution Audit)
 */
export async function executeGetAdminFeedback(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string }
) {
  if (caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "Only administrators can audit all institutional feedback.");
  }

  const snap = await firestore.collection("feedback").get();
  const feedbackList = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

  // Join identities for administrative safety audit
  const idSnap = await firestore.collection("feedbackIdentities").get();
  const identityMap = new Map<string, any>();
  idSnap.docs.forEach((doc) => {
    identityMap.set(doc.id, doc.data());
  });

  return feedbackList.map((f: any) => {
    const sensitive = identityMap.get(f.id);
    return {
      ...f,
      adminAuditStudentId: sensitive?.studentId || null,
      adminAuditStudentName: sensitive?.studentName || null,
      adminAuditStudentEmail: sensitive?.studentEmail || null,
    };
  });
}

// ─── CALLABLE CLOUD FUNCTIONS ────────────────────────────────────────────────

export const submitFeedback = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "STUDENT",
    fullName: request.auth.token.name,
    email: request.auth.token.email,
  };
  return executeSubmitFeedback(db, caller, request.data);
});

export const editFeedback = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "STUDENT",
    fullName: request.auth.token.name,
    email: request.auth.token.email,
  };
  return executeEditFeedback(db, caller, request.data?.feedbackId, request.data);
});

export const replyToFeedback = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "TEACHER",
    fullName: request.auth.token.name,
  };
  return executeReplyToFeedback(
    db,
    caller,
    request.data?.feedbackId,
    request.data?.replyText,
    request.data?.attachments
  );
});

export const editFeedbackReply = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
  const caller = {
    uid: request.auth.uid,
    role: request.auth.token.role || "TEACHER",
  };
  return executeEditFeedbackReply(
    db,
    caller,
    request.data?.feedbackId,
    request.data?.replyId,
    request.data?.newReplyText,
    request.data?.attachments
  );
});
