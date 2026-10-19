import { describe, it, beforeEach } from "node:test";
import * as assert from "node:assert";
import {
  cleanPhoneNumber,
  normalizeBangladeshiPhone,
  buildWhatsAppShareUrls,
  generateOnboardingEmailHtml,
  generateSignupRejectionEmailHtml,
  safeDispatchEmail,
  EmailTransport,
} from "./communication";

// ─── MOCK FIRESTORE IMPLEMENTATION ──────────────────────────────────────────

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
}

class MockCollectionReference {
  constructor(
    public name: string,
    private db: MockFirestore
  ) {}

  doc(id?: string): MockDocumentReference {
    const docId = id || `mock_doc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return new MockDocumentReference(docId, this.db, this.name);
  }
}

class MockFirestore {
  public store: Record<string, Record<string, any>> = {};

  collection(name: string): MockCollectionReference {
    return new MockCollectionReference(name, this);
  }
}

// ─── STAGE 28: EXTERNAL COMMUNICATION TESTS ─────────────────────────────────

describe("STAGE 28: External Communication (Email & WhatsApp Integration) Tests", () => {
  let mockDb: MockFirestore;

  beforeEach(() => {
    mockDb = new MockFirestore();
  });

  // 1. Phone number cleaning
  it("1. cleanPhoneNumber strips punctuation, formatting and extra whitespace", () => {
    assert.strictEqual(cleanPhoneNumber("  +880 1712-345 678  "), "+8801712345678");
    assert.strictEqual(cleanPhoneNumber("(018) 12-345678"), "01812345678");
    assert.strictEqual(cleanPhoneNumber(""), "");
    assert.strictEqual(cleanPhoneNumber(null as any), "");
  });

  // 2. Phone normalization for all Bangladeshi operators
  it("2. normalizeBangladeshiPhone identifies and normalizes valid operators", () => {
    // Grameenphone (017, 013)
    const gp1 = normalizeBangladeshiPhone("01712345678");
    assert.strictEqual(gp1.isValid, true);
    assert.strictEqual(gp1.operator, "Grameenphone");
    assert.strictEqual(gp1.national, "01712345678");
    assert.strictEqual(gp1.international, "+8801712345678");
    assert.strictEqual(gp1.whatsAppNumber, "8801712345678");

    const gp2 = normalizeBangladeshiPhone("+8801300000000");
    assert.strictEqual(gp2.isValid, true);
    assert.strictEqual(gp2.operator, "Grameenphone");

    // Banglalink (019, 014)
    const bl1 = normalizeBangladeshiPhone("8801911223344");
    assert.strictEqual(bl1.isValid, true);
    assert.strictEqual(bl1.operator, "Banglalink");
    assert.strictEqual(bl1.national, "01911223344");

    const bl2 = normalizeBangladeshiPhone("01455667788");
    assert.strictEqual(bl2.isValid, true);
    assert.strictEqual(bl2.operator, "Banglalink");

    // Robi & Airtel (018, 016)
    const robi = normalizeBangladeshiPhone("01812345678");
    assert.strictEqual(robi.isValid, true);
    assert.strictEqual(robi.operator, "Robi");

    const airtel = normalizeBangladeshiPhone("+88 016-1234-5678");
    assert.strictEqual(airtel.isValid, true);
    assert.strictEqual(airtel.operator, "Robi");

    // Teletalk (015)
    const tt = normalizeBangladeshiPhone("01552345678");
    assert.strictEqual(tt.isValid, true);
    assert.strictEqual(tt.operator, "Teletalk");
  });

  // 3. Phone normalization rejections
  it("3. normalizeBangladeshiPhone rejects invalid numbers and unsupported prefixes", () => {
    // Invalid operator prefix 011, 012, 010
    const inv1 = normalizeBangladeshiPhone("01112345678");
    assert.strictEqual(inv1.isValid, false);
    assert.ok(inv1.error?.includes("Invalid operator prefix"));

    // Short number
    const inv2 = normalizeBangladeshiPhone("0171234");
    assert.strictEqual(inv2.isValid, false);
    assert.ok(inv2.error?.includes("must be 11 digits"));

    // Long number
    const inv3 = normalizeBangladeshiPhone("01712345678999");
    assert.strictEqual(inv3.isValid, false);

    // Empty or non-numeric
    const inv4 = normalizeBangladeshiPhone("");
    assert.strictEqual(inv4.isValid, false);
    const inv5 = normalizeBangladeshiPhone("abcdefghijk");
    assert.strictEqual(inv5.isValid, false);
  });

  // 4. WhatsApp deep link generation without recipient (broadcast)
  it("4. buildWhatsAppShareUrls generates valid broadcast links without phone number", () => {
    const text = "CSE JnU Class Routine Update for Tomorrow";
    const links = buildWhatsAppShareUrls(text);

    assert.ok(links.webUrl.startsWith("https://api.whatsapp.com/send?text="));
    assert.ok(links.appUrl.startsWith("whatsapp://send?text="));
    assert.ok(links.waMeUrl.startsWith("https://wa.me/?text="));
    assert.ok(links.webUrl.includes(encodeURIComponent(text)));
    assert.strictEqual(links.targetPhone, undefined);
  });

  // 5. WhatsApp deep link generation with validated recipient
  it("5. buildWhatsAppShareUrls generates direct messaging links with formatted BD phone", () => {
    const text = "Tomorrow's Algorithm Lab is scheduled at 10:00 AM in Room 402.";
    const rawPhone = "+880 1712 345678";
    const links = buildWhatsAppShareUrls(text, rawPhone);

    assert.strictEqual(links.targetPhone, "01712345678");
    assert.strictEqual(links.waMeUrl, `https://wa.me/8801712345678?text=${encodeURIComponent(text)}`);
    assert.strictEqual(
      links.webUrl,
      `https://api.whatsapp.com/send?phone=8801712345678&text=${encodeURIComponent(text)}`
    );
    assert.strictEqual(
      links.appUrl,
      `whatsapp://send?phone=8801712345678&text=${encodeURIComponent(text)}`
    );
  });

  // 6. WhatsApp deep links throws on invalid phone
  it("6. buildWhatsAppShareUrls rejects invalid recipient phone with invalid-argument error", () => {
    assert.throws(
      () => buildWhatsAppShareUrls("Routine notice", "01234567890"),
      /Invalid operator prefix/
    );
  });

  // 7. Unicode and Bangla text encoding in WhatsApp URLs
  it("7. buildWhatsAppShareUrls cleanly encodes Bangla characters and multi-line routines", () => {
    const routine = "সিএসই জগন্নাথ বিশ্ববিদ্যালয়\nআগামীকালের ক্লাস শিডিউল:\n- সিএসই ৩১০১: সকাল ১০:০০";
    const links = buildWhatsAppShareUrls(routine);

    assert.ok(links.waMeUrl.includes(encodeURIComponent(routine)));
    assert.doesNotThrow(() => decodeURIComponent(links.waMeUrl));
  });

  // 8. Onboarding email template generation
  it("8. generateOnboardingEmailHtml creates branded HTML and fallback text for student", () => {
    const email = generateOnboardingEmailHtml({
      fullName: "Tanvir Ahmed",
      email: "tanvir@jnu.ac.bd",
      role: "STUDENT",
      studentId: "B200305001",
      tempPassword: "TempPassword123!",
    });

    assert.ok(email.text.includes("Dear Tanvir Ahmed"));
    assert.ok(email.text.includes("tanvir@jnu.ac.bd"));
    assert.ok(email.text.includes("B200305001"));
    assert.ok(email.text.includes("TempPassword123!"));
    assert.ok(email.text.includes("Student"));

    assert.ok(email.html.includes("CSE JnU EduPortal"));
    assert.ok(email.html.includes("Initial Temporary Password"));
    assert.ok(email.html.includes("TempPassword123!"));
    assert.ok(email.html.includes("Jagannath University"));
  });

  // 9. Onboarding email template for faculty
  it("9. generateOnboardingEmailHtml formats faculty role and omits studentId when absent", () => {
    const email = generateOnboardingEmailHtml({
      fullName: "Dr. Mohammed Nasir",
      email: "nasir@cse.jnu.ac.bd",
      role: "TEACHER",
    });

    assert.ok(email.text.includes("Faculty Member"));
    assert.ok(!email.text.includes("Student ID"));
    assert.ok(!email.html.includes("Initial Temporary Password"));
    assert.ok(email.html.includes("Faculty Member"));
  });

  // 10. Signup rejection email template
  it("10. generateSignupRejectionEmailHtml includes custom reason and official guidance", () => {
    const email = generateSignupRejectionEmailHtml({
      fullName: "Anik Roy",
      email: "anik@gmail.com",
      reason: "HSC registration roll does not match Jagannath University 2025 admission database.",
    });

    assert.ok(email.text.includes("Anik Roy"));
    assert.ok(email.text.includes("HSC registration roll does not match"));
    assert.ok(email.html.includes("Reason for Decline"));
    assert.ok(email.html.includes("HSC registration roll does not match"));
  });

  // 11. Safe email dispatcher with successful transport
  it("11. safeDispatchEmail delivers email and writes SENT record to communicationLogs", async () => {
    const mockTransport: EmailTransport = async (opts) => {
      assert.strictEqual(opts.to, "student@jnu.ac.bd");
      assert.strictEqual(opts.subject, "Welcome to CSE JnU");
      return { messageId: "msg_test_12345" };
    };

    const res = await safeDispatchEmail(
      mockDb as any,
      {
        to: "student@jnu.ac.bd",
        subject: "Welcome to CSE JnU",
        html: "<p>Welcome</p>",
        text: "Welcome",
        templateType: "ONBOARDING",
        metadata: { userId: "user_123" },
      },
      mockTransport
    );

    assert.strictEqual(res.success, true);
    assert.ok(res.logId);

    const logDoc = await mockDb.collection("communicationLogs").doc(res.logId).get();
    assert.strictEqual(logDoc.exists, true);
    assert.strictEqual(logDoc.data().status, "SENT");
    assert.strictEqual(logDoc.data().recipient, "student@jnu.ac.bd");
    assert.strictEqual(logDoc.data().messageId, "msg_test_12345");
    assert.strictEqual(logDoc.data().templateType, "ONBOARDING");
  });

  // 12. Safe email dispatcher isolates external transport errors without crashing caller
  it("12. safeDispatchEmail catches transport errors and writes FAILED status without throwing", async () => {
    const failingTransport: EmailTransport = async () => {
      throw new Error("SMTP connection timeout to mailserver:587");
    };

    // MUST NOT THROW
    const res = await safeDispatchEmail(
      mockDb as any,
      {
        to: "student@jnu.ac.bd",
        subject: "Welcome",
        html: "<p>Welcome</p>",
        text: "Welcome",
        templateType: "ONBOARDING",
      },
      failingTransport
    );

    assert.strictEqual(res.success, false);
    assert.ok(res.error?.includes("SMTP connection timeout"));

    const logDoc = await mockDb.collection("communicationLogs").doc(res.logId).get();
    assert.strictEqual(logDoc.exists, true);
    assert.strictEqual(logDoc.data().status, "FAILED");
    assert.strictEqual(logDoc.data().recipient, "student@jnu.ac.bd");
    assert.ok(logDoc.data().error.includes("SMTP connection timeout"));
  });

  // 13. Safe email dispatcher handles invalid recipient email address safely
  it("13. safeDispatchEmail rejects invalid recipient address and logs failure", async () => {
    const res = await safeDispatchEmail(
      mockDb as any,
      {
        to: "not-an-email",
        subject: "Test",
        html: "<p>Hi</p>",
        text: "Hi",
        templateType: "TEST",
      }
    );

    assert.strictEqual(res.success, false);
    assert.ok(res.error?.includes("Invalid recipient email address"));

    const logDoc = await mockDb.collection("communicationLogs").doc(res.logId).get();
    assert.strictEqual(logDoc.exists, true);
    assert.strictEqual(logDoc.data().status, "FAILED");
  });

  // 14. Dev mode fallback when no transport and no SMTP config
  it("14. safeDispatchEmail operates safely in dev mode without SMTP configuration", async () => {
    const res = await safeDispatchEmail(
      mockDb as any,
      {
        to: "dev_user@jnu.ac.bd",
        subject: "Dev Mode Routine Notice",
        html: "<p>Notice</p>",
        text: "Notice",
        templateType: "NOTICE",
      }
    );

    assert.strictEqual(res.success, true);
    const logDoc = await mockDb.collection("communicationLogs").doc(res.logId).get();
    assert.strictEqual(logDoc.exists, true);
    assert.strictEqual(logDoc.data().status, "SENT");
    assert.ok(logDoc.data().messageId.startsWith("sim_"));
  });
});
