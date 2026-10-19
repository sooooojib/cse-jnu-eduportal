import { describe, it, beforeEach } from "node:test";
import * as assert from "node:assert";
import {
  validateDeviceToken,
  validateNotificationPayload,
  executeRegisterDeviceToken,
  executeUnregisterDeviceToken,
  executeCreateNotification,
  executeMarkNotificationAsRead,
  executeMarkAllNotificationsAsRead,
  dispatchPushNotification,
} from "./notifications";

class MockDocumentReference {
  constructor(
    public id: string,
    private db: MockFirestore,
    public collectionName: string
  ) {}

  async get(): Promise<any> {
    const data = this.db.store[this.collectionName]?.[this.id];
    return {
      id: this.id,
      exists: !!data,
      data: () => (data ? { ...data } : undefined),
      ref: this,
    };
  }

  async set(data: any): Promise<void> {
    if (!this.db.store[this.collectionName]) {
      this.db.store[this.collectionName] = {};
    }
    this.db.store[this.collectionName][this.id] = { id: this.id, ...data };
  }

  async update(data: any): Promise<void> {
    const current = this.db.store[this.collectionName]?.[this.id];
    if (!current) {
      throw new Error(`NOT_FOUND: Document ${this.id} not found.`);
    }

    const updated = { ...current };
    for (const [key, value] of Object.entries(data)) {
      if (value && typeof value === "object") {
        const vAny = value as any;
        const cName = vAny.constructor?.name;
        if (cName === "ArrayUnionTransform" || vAny._methodName === "arrayUnion") {
          const elements = vAny.elements || vAny._elements || [];
          const existingArray: any[] = updated[key] || [];
          updated[key] = Array.from(new Set([...existingArray, ...elements]));
          continue;
        }
        if (cName === "ArrayRemoveTransform" || vAny._methodName === "arrayRemove") {
          const elements = new Set(vAny.elements || vAny._elements || []);
          const existingArray: any[] = updated[key] || [];
          updated[key] = existingArray.filter((x) => !elements.has(x));
          continue;
        }
        if (cName === "ServerTimestampTransform" || vAny._methodName === "serverTimestamp") {
          updated[key] = new Date().toISOString();
          continue;
        }
      }
      updated[key] = value;
    }

    this.db.store[this.collectionName][this.id] = updated;
  }
}

class MockCollectionReference {
  constructor(public collectionName: string, private db: MockFirestore) {}

  doc(id?: string): MockDocumentReference {
    const docId = id || `doc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return new MockDocumentReference(docId, this.db, this.collectionName);
  }

  where(field: string, op: string, value: any): MockQuery {
    return new MockQuery(this.collectionName, this.db).where(field, op, value);
  }

  async get(): Promise<any> {
    return new MockQuery(this.collectionName, this.db).get();
  }
}

class MockQuery {
  private filters: Array<{ field: string; op: string; value: any }> = [];

  constructor(private collectionName: string, private db: MockFirestore) {}

  where(field: string, op: string, value: any): MockQuery {
    this.filters.push({ field, op, value });
    return this;
  }

  async get(): Promise<any> {
    const all = Object.values(this.db.store[this.collectionName] || {});
    const filtered = all.filter((doc: any) => {
      for (const f of this.filters) {
        if (f.op === "==" && doc[f.field] !== f.value) return false;
      }
      return true;
    });

    return {
      empty: filtered.length === 0,
      size: filtered.length,
      docs: filtered.map((d: any) => ({
        id: d.id,
        data: () => ({ ...d }),
        ref: new MockDocumentReference(d.id, this.db, this.collectionName),
      })),
    };
  }
}

class MockWriteBatch {
  private operations: Array<() => Promise<void>> = [];

  update(ref: MockDocumentReference, data: any): void {
    this.operations.push(async () => {
      await ref.update(data);
    });
  }

  set(ref: MockDocumentReference, data: any): void {
    this.operations.push(async () => {
      await ref.set(data);
    });
  }

  async commit(): Promise<void> {
    for (const op of this.operations) {
      await op();
    }
  }
}

class MockFirestore {
  public store: Record<string, Record<string, any>> = {};

  collection(name: string): MockCollectionReference {
    return new MockCollectionReference(name, this);
  }

  batch(): MockWriteBatch {
    return new MockWriteBatch();
  }

  reset(): void {
    this.store = {};
  }
}



describe("STAGE 27: Notification Engine, FCM Dispatch, Stale Token & Security Tests", () => {
  let db: MockFirestore;

  beforeEach(() => {
    db = new MockFirestore();
  });

  // ─── 1. DEVICE TOKEN VALIDATION ─────────────────────────────────────────────

  it("1. validateDeviceToken validates genuine tokens and rejects invalid tokens", () => {
    const valid = validateDeviceToken("fcm_token_sample_1234567890_abcdefg");
    assert.strictEqual(valid, "fcm_token_sample_1234567890_abcdefg");

    // Rejects empty or null
    assert.throws(() => validateDeviceToken(""), /FCM device token must be a non-empty string/);
    assert.throws(() => validateDeviceToken(null), /FCM device token must be a non-empty string/);
    assert.throws(() => validateDeviceToken(12345), /FCM device token must be a non-empty string/);

    // Rejects too short (< 10 chars)
    assert.throws(() => validateDeviceToken("abc"), /invalid length/);
  });

  // ─── 2. NOTIFICATION PAYLOAD VALIDATION ──────────────────────────────────────

  it("2. validateNotificationPayload succeeds on approved event types and populates defaults", () => {
    const result = validateNotificationPayload({
      userId: "student_101",
      title: "Semester Upgrade Approved",
      body: "Your request for Year 3 Semester 1 was approved.",
      notificationType: "SEMESTER_DECISION",
      referenceId: "upg_123",
      route: "/profile",
    });

    assert.strictEqual(result.userId, "student_101");
    assert.strictEqual(result.title, "Semester Upgrade Approved");
    assert.strictEqual(result.notificationType, "SEMESTER_DECISION");
    assert.strictEqual(result.referenceId, "upg_123");
    assert.strictEqual(result.route, "/profile");
  });

  it("3. validateNotificationPayload rejects missing userId, missing title, or unsupported notificationType", () => {
    assert.throws(
      () => validateNotificationPayload({ title: "Hi", body: "Test" }),
      /Target userId is required/
    );
    assert.throws(
      () => validateNotificationPayload({ userId: "u1", title: "", body: "Test" }),
      /Notification title is required/
    );
    assert.throws(
      () => validateNotificationPayload({ userId: "u1", title: "Hi", body: "" }),
      /Notification body is required/
    );
    assert.throws(
      () =>
        validateNotificationPayload({
          userId: "u1",
          title: "Hi",
          body: "Test",
          notificationType: "UNKNOWN_TYPE_123",
        }),
      /Unsupported notificationType/
    );
  });

  // ─── 3. DEVICE TOKEN REGISTRATION (MULTIPLE DEVICES) ───────────────────────

  it("4. executeRegisterDeviceToken registers new device tokens and supports multiple devices", async () => {
    // Setup user
    await db.collection("users").doc("user_42").set({
      id: "user_42",
      fullName: "Sajib",
      fcmTokens: ["phone_token_11111111"],
    });

    // Register second device (e.g. tablet or laptop)
    const result = await executeRegisterDeviceToken(
      db as any,
      "user_42",
      "tablet_token_22222222"
    );

    assert.strictEqual(result.success, true);

    const userDoc = await db.collection("users").doc("user_42").get();
    const tokens = userDoc.data()?.fcmTokens;
    assert.strictEqual(tokens.length, 2);
    assert.ok(tokens.includes("phone_token_11111111"));
    assert.ok(tokens.includes("tablet_token_22222222"));
  });

  // ─── 4. LOGOUT TOKEN HANDLING ───────────────────────────────────────────────

  it("5. executeUnregisterDeviceToken removes device token on logout", async () => {
    await db.collection("users").doc("user_42").set({
      id: "user_42",
      fcmTokens: ["device_a_token_1111", "device_b_token_2222"],
    });

    const result = await executeUnregisterDeviceToken(
      db as any,
      "user_42",
      "device_a_token_1111"
    );

    assert.strictEqual(result.success, true);

    const userDoc = await db.collection("users").doc("user_42").get();
    const tokens = userDoc.data()?.fcmTokens;
    assert.strictEqual(tokens.length, 1);
    assert.strictEqual(tokens[0], "device_b_token_2222");
  });

  // ─── 5. IN-APP NOTIFICATION RECORD CREATION ─────────────────────────────────

  it("6. executeCreateNotification creates an in-app notification with unread state", async () => {
    const res = await executeCreateNotification(db as any, {
      userId: "student_99",
      title: "Counseling Approved",
      body: "Appointment with Dr. Layek approved.",
      notificationType: "COUNSELING_STATUS",
      route: "/counseling",
    });

    assert.strictEqual(res.success, true);
    assert.ok(res.notificationId);

    const notifDoc = await db.collection("notifications").doc(res.notificationId).get();
    assert.strictEqual(notifDoc.exists, true);
    assert.strictEqual(notifDoc.data()?.isRead, false);
    assert.strictEqual(notifDoc.data()?.route, "/counseling");
    assert.strictEqual(notifDoc.data()?.notificationType, "COUNSELING_STATUS");
  });

  // ─── 6. UNREAD / READ STATE & VISIBILITY PERMISSIONS ────────────────────────

  it("7. executeMarkNotificationAsRead allows recipient to mark notification as read", async () => {
    await db.collection("notifications").doc("notif_1").set({
      id: "notif_1",
      userId: "student_99",
      title: "Feedback Response",
      body: "Teacher replied.",
      notificationType: "FEEDBACK_REPLY",
      isRead: false,
    });

    const res = await executeMarkNotificationAsRead(
      db as any,
      { uid: "student_99", role: "STUDENT" },
      "notif_1"
    );

    assert.strictEqual(res.success, true);
    const doc = await db.collection("notifications").doc("notif_1").get();
    assert.strictEqual(doc.data()?.isRead, true);
  });

  it("8. Prevents notifications from being accessed/modified by the wrong user", async () => {
    await db.collection("notifications").doc("notif_secret").set({
      id: "notif_secret",
      userId: "student_bob",
      title: "Secret Grade",
      body: "Grade updated.",
      notificationType: "GENERAL",
      isRead: false,
    });

    // Student Alice tries to mark Bob's notification as read
    await assert.rejects(
      async () => {
        await executeMarkNotificationAsRead(
          db as any,
          { uid: "student_alice", role: "STUDENT" },
          "notif_secret"
        );
      },
      /You are not authorized to view or modify this notification/
    );

    // Admin CAN access/mark
    const adminRes = await executeMarkNotificationAsRead(
      db as any,
      { uid: "admin_super", role: "ADMIN" },
      "notif_secret"
    );
    assert.strictEqual(adminRes.success, true);
  });

  it("9. executeMarkAllNotificationsAsRead marks all unread notifications of caller", async () => {
    await db.collection("notifications").doc("n1").set({
      id: "n1",
      userId: "student_1",
      isRead: false,
    });
    await db.collection("notifications").doc("n2").set({
      id: "n2",
      userId: "student_1",
      isRead: false,
    });
    await db.collection("notifications").doc("n3").set({
      id: "n3",
      userId: "student_2", // Different user
      isRead: false,
    });

    const res = await executeMarkAllNotificationsAsRead(db as any, { uid: "student_1" });
    assert.strictEqual(res.updatedCount, 2);

    const n1 = await db.collection("notifications").doc("n1").get();
    const n2 = await db.collection("notifications").doc("n2").get();
    const n3 = await db.collection("notifications").doc("n3").get();

    assert.strictEqual(n1.data()?.isRead, true);
    assert.strictEqual(n2.data()?.isRead, true);
    assert.strictEqual(n3.data()?.isRead, false); // Untouched
  });

  // ─── 7. PUSH NOTIFICATION DISPATCH & STALE TOKEN PRUNING ────────────────────

  it("10. dispatchPushNotification sends multicast with deep link data to user devices", async () => {
    await db.collection("users").doc("user_fcm").set({
      id: "user_fcm",
      fcmTokens: ["token_phone_active", "token_tablet_active"],
    });

    let sentMessage: any = null;
    const mockMessaging: any = {
      async sendEachForMulticast(msg: any) {
        sentMessage = msg;
        return {
          successCount: 2,
          failureCount: 0,
          responses: [{ success: true }, { success: true }],
        };
      },
    };

    const res = await dispatchPushNotification(db as any, mockMessaging, "notif_deep", {
      userId: "user_fcm",
      title: "New Counseling Slot",
      body: "Dr. Layek opened slots.",
      notificationType: "COUNSELING_STATUS",
      referenceId: "slot_505",
      route: "/counseling",
    });

    assert.strictEqual(res.successCount, 2);
    assert.strictEqual(res.failureCount, 0);
    assert.strictEqual(res.staleTokensPruned, 0);

    // Deep link and metadata verification
    assert.deepStrictEqual(sentMessage.tokens, ["token_phone_active", "token_tablet_active"]);
    assert.strictEqual(sentMessage.data.route, "/counseling");
    assert.strictEqual(sentMessage.data.notificationType, "COUNSELING_STATUS");
    assert.strictEqual(sentMessage.data.click_action, "FLUTTER_NOTIFICATION_CLICK");
  });

  it("11. dispatchPushNotification automatically prunes stale or unregistered tokens", async () => {
    await db.collection("users").doc("user_stale").set({
      id: "user_stale",
      fcmTokens: ["good_active_token", "old_stale_token_dead", "invalid_token_dead"],
    });

    const mockMessaging: any = {
      async sendEachForMulticast(msg: any) {
        return {
          successCount: 1,
          failureCount: 2,
          responses: [
            { success: true },
            {
              success: false,
              error: { code: "messaging/registration-token-not-registered" },
            },
            {
              success: false,
              error: { code: "messaging/invalid-registration-token" },
            },
          ],
        };
      },
    };

    const res = await dispatchPushNotification(db as any, mockMessaging, "notif_stale_test", {
      userId: "user_stale",
      title: "Test Prune",
      body: "Testing stale token removal.",
    });

    assert.strictEqual(res.successCount, 1);
    assert.strictEqual(res.failureCount, 2);
    assert.strictEqual(res.staleTokensPruned, 2);

    // Verify user document has only the good active token remaining
    const userDoc = await db.collection("users").doc("user_stale").get();
    const remainingTokens = userDoc.data()?.fcmTokens;
    assert.strictEqual(remainingTokens.length, 1);
    assert.strictEqual(remainingTokens[0], "good_active_token");
  });

  it("12. dispatchPushNotification handles broadcast notification (userId == ALL)", async () => {
    let sentTopicMessage: any = null;
    const mockMessaging: any = {
      async send(msg: any) {
        sentTopicMessage = msg;
        return "msg_12345";
      },
    };

    const res = await dispatchPushNotification(db as any, mockMessaging, "notif_all", {
      userId: "ALL",
      title: "Department Notice",
      body: "Classes suspended tomorrow.",
      notificationType: "NOTICE",
      route: "/notifications",
    });

    assert.strictEqual(res.successCount, 1);
    assert.strictEqual(sentTopicMessage.topic, "all_users");
    assert.strictEqual(sentTopicMessage.data.route, "/notifications");
  });
});
