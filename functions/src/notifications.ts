import * as admin from "firebase-admin";
import { HttpsError } from "firebase-functions/v2/https";

export type NotificationType =
  | "SIGNUP_DECISION"
  | "SEMESTER_DECISION"
  | "COUNSELING_STATUS"
  | "FEEDBACK_REPLY"
  | "FEEDBACK_SUBMISSION"
  | "ATTENDANCE"
  | "NOTICE"
  | "GENERAL";

export interface NotificationPayload {
  userId: string;
  title: string;
  body: string;
  notificationType: NotificationType;
  referenceId?: string;
  referenceType?: string;
  route?: string;
}

export const STALE_TOKEN_ERROR_CODES = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
  "messaging/mismatched-credential",
]);

/**
 * Validates device FCM registration token.
 */
export function validateDeviceToken(token: any): string {
  if (!token || typeof token !== "string") {
    throw new HttpsError("invalid-argument", "FCM device token must be a non-empty string.");
  }
  const trimmed = token.trim();
  if (trimmed.length < 10 || trimmed.length > 500) {
    throw new HttpsError("invalid-argument", "FCM device token has an invalid length.");
  }
  return trimmed;
}

/**
 * Validates notification payload before saving to Firestore.
 */
export function validateNotificationPayload(data: any): NotificationPayload {
  if (!data || typeof data !== "object") {
    throw new HttpsError("invalid-argument", "Notification data must be an object.");
  }

  const { userId, title, body, notificationType, referenceId, referenceType, route } = data;

  if (!userId || typeof userId !== "string" || !userId.trim()) {
    throw new HttpsError("invalid-argument", "Target userId is required.");
  }

  if (!title || typeof title !== "string" || !title.trim()) {
    throw new HttpsError("invalid-argument", "Notification title is required.");
  }

  if (!body || typeof body !== "string" || !body.trim()) {
    throw new HttpsError("invalid-argument", "Notification body is required.");
  }

  const validTypes: NotificationType[] = [
    "SIGNUP_DECISION",
    "SEMESTER_DECISION",
    "COUNSELING_STATUS",
    "FEEDBACK_REPLY",
    "FEEDBACK_SUBMISSION",
    "ATTENDANCE",
    "NOTICE",
    "GENERAL",
  ];

  const type = (notificationType || "GENERAL").toUpperCase() as NotificationType;
  if (!validTypes.includes(type)) {
    throw new HttpsError("invalid-argument", `Unsupported notificationType: ${notificationType}`);
  }

  return {
    userId: userId.trim(),
    title: title.trim(),
    body: body.trim(),
    notificationType: type,
    referenceId: referenceId && typeof referenceId === "string" ? referenceId.trim() : undefined,
    referenceType: referenceType && typeof referenceType === "string" ? referenceType.trim() : undefined,
    route: route && typeof route === "string" ? route.trim() : undefined,
  };
}

/**
 * ─── 1. DEVICE TOKEN REGISTRATION (Supports Multiple Devices) ─────────────────
 */
export async function executeRegisterDeviceToken(
  firestore: admin.firestore.Firestore,
  uid: string,
  token: string
) {
  if (!uid || typeof uid !== "string") {
    throw new HttpsError("unauthenticated", "User must be authenticated to register device token.");
  }

  const validToken = validateDeviceToken(token);

  const userRef = firestore.collection("users").doc(uid);
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User account profile not found.");
  }

  await userRef.update({
    fcmTokens: admin.firestore.FieldValue.arrayUnion(validToken),
    lastDeviceTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, message: "Device token registered successfully." };
}

/**
 * ─── 2. LOGOUT TOKEN HANDLING (Removes Token From User Account) ───────────────
 */
export async function executeUnregisterDeviceToken(
  firestore: admin.firestore.Firestore,
  uid: string,
  token: string
) {
  if (!uid || typeof uid !== "string") {
    throw new HttpsError("unauthenticated", "User must be authenticated to unregister device token.");
  }

  const validToken = validateDeviceToken(token);

  const userRef = firestore.collection("users").doc(uid);
  const userDoc = await userRef.get();
  if (userDoc.exists) {
    await userRef.update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(validToken),
      lastDeviceTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return { success: true, message: "Device token unregistered successfully." };
}

/**
 * ─── 3. CREATE IN-APP NOTIFICATION RECORD ────────────────────────────────────
 */
export async function executeCreateNotification(
  firestore: admin.firestore.Firestore,
  payload: any
) {
  const validated = validateNotificationPayload(payload);
  const notifRef = firestore.collection("notifications").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();

  const record = {
    id: notifRef.id,
    userId: validated.userId,
    title: validated.title,
    body: validated.body,
    notificationType: validated.notificationType,
    referenceId: validated.referenceId || null,
    referenceType: validated.referenceType || null,
    route: validated.route || "/notifications",
    isRead: false,
    createdAt: now,
    updatedAt: now,
  };

  await notifRef.set(record);
  return { success: true, notificationId: notifRef.id, notification: record };
}

/**
 * ─── 4. MARK NOTIFICATION AS READ (With Ownership & Visibility Protection) ───
 */
export async function executeMarkNotificationAsRead(
  firestore: admin.firestore.Firestore,
  caller: { uid: string; role: string },
  notificationId: string
) {
  if (!caller || !caller.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  if (!notificationId || typeof notificationId !== "string") {
    throw new HttpsError("invalid-argument", "Missing notificationId.");
  }

  const notifRef = firestore.collection("notifications").doc(notificationId);
  const doc = await notifRef.get();
  if (!doc.exists) {
    throw new HttpsError("not-found", "Notification record not found.");
  }

  const data = doc.data()!;
  // Strict Privacy: Only the recipient user or administrator can access/modify
  if (data.userId !== caller.uid && data.userId !== "ALL" && caller.role !== "ADMIN") {
    throw new HttpsError("permission-denied", "You are not authorized to view or modify this notification.");
  }

  await notifRef.update({
    isRead: true,
    readAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, notificationId };
}

/**
 * ─── 5. MARK ALL NOTIFICATIONS AS READ ───────────────────────────────────────
 */
export async function executeMarkAllNotificationsAsRead(
  firestore: admin.firestore.Firestore,
  caller: { uid: string }
) {
  if (!caller || !caller.uid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const snapshot = await firestore
    .collection("notifications")
    .where("userId", "==", caller.uid)
    .where("isRead", "==", false)
    .get();

  if (snapshot.empty) {
    return { success: true, updatedCount: 0 };
  }

  const batch = firestore.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  snapshot.docs.forEach((doc) => {
    batch.update(doc.ref, {
      isRead: true,
      readAt: now,
    });
  });

  await batch.commit();

  return { success: true, updatedCount: snapshot.size };
}

/**
 * ─── 6. DISPATCH PUSH NOTIFICATION & PRUNE STALE TOKENS ───────────────────────
 */
export async function dispatchPushNotification(
  firestore: admin.firestore.Firestore,
  messaging: admin.messaging.Messaging,
  notificationId: string,
  notifData: any
) {
  const userId = notifData.userId;
  if (!userId) {
    return { skipped: true, reason: "No target userId specified." };
  }

  // Handle broadcast notifications (userId == "ALL")
  if (userId === "ALL") {
    try {
      const topicMessage: admin.messaging.Message = {
        topic: "all_users",
        notification: {
          title: notifData.title || "CSE JnU EduPortal",
          body: notifData.body || "",
        },
        data: {
          notificationId,
          notificationType: notifData.notificationType || "GENERAL",
          referenceId: notifData.referenceId || "",
          referenceType: notifData.referenceType || "",
          route: notifData.route || "/notifications",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      await messaging.send(topicMessage);
      return { successCount: 1, failureCount: 0, staleTokensPruned: 0 };
    } catch (err: any) {
      console.error("FCM broadcast error:", err);
      return { successCount: 0, failureCount: 1, error: err.message };
    }
  }

  // Fetch target user's registered FCM tokens
  const userDoc = await firestore.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    return { skipped: true, reason: "Target user not found." };
  }

  const rawTokens: string[] = userDoc.data()?.fcmTokens || [];
  const fcmTokens = Array.from(new Set(rawTokens.filter((t) => typeof t === "string" && t.trim().length > 0)));

  if (fcmTokens.length === 0) {
    return { skipped: true, reason: "No active FCM tokens registered for user." };
  }

  const payload: admin.messaging.MulticastMessage = {
    tokens: fcmTokens,
    notification: {
      title: notifData.title || "CSE JnU EduPortal",
      body: notifData.body || "",
    },
    data: {
      notificationId,
      notificationType: notifData.notificationType || "GENERAL",
      referenceId: notifData.referenceId || "",
      referenceType: notifData.referenceType || "",
      route: notifData.route || "/notifications",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "cse_jnu_notifications",
        sound: "default",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(payload);

    // Identify and prune stale or invalid tokens
    const staleTokens: string[] = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error) {
        if (STALE_TOKEN_ERROR_CODES.has(resp.error.code)) {
          staleTokens.push(fcmTokens[idx]);
        }
      }
    });

    if (staleTokens.length > 0) {
      console.log(`Pruning ${staleTokens.length} stale FCM token(s) for user ${userId}`);
      await firestore.collection("users").doc(userId).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
      });
    }

    return {
      successCount: response.successCount,
      failureCount: response.failureCount,
      staleTokensPruned: staleTokens.length,
    };
  } catch (err: any) {
    console.error("FCM multicast error:", err);
    return { successCount: 0, failureCount: fcmTokens.length, error: err.message };
  }
}
