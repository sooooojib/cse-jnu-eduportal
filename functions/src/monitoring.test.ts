import { describe, it } from "node:test";
import * as assert from "node:assert";
import {
  DiagnosticSanitizer,
  StructuredLogger,
  FailureCategory,
} from "./monitoring";
import { HttpsError } from "firebase-functions/v2/https";

describe("STAGE 33: Cloud Functions Monitoring & Structured Logging Tests", () => {
  it("1. DiagnosticSanitizer redacts passwords, tokens, secrets, and API keys", () => {
    const rawData = {
      password: "SuperSecretPassword123!",
      user_token: "xyz-token-abc",
      apiKey: "AIzaSyD-12345",
      operation: "approveSignupRequest",
      courseId: "CSE-3101",
    };

    const sanitized = DiagnosticSanitizer.sanitize(rawData);

    assert.strictEqual(sanitized.password, "[REDACTED]");
    assert.strictEqual(sanitized.user_token, "[REDACTED]");
    assert.strictEqual(sanitized.apiKey, "[REDACTED]");
    assert.strictEqual(sanitized.operation, "approveSignupRequest");
    assert.strictEqual(sanitized.courseId, "CSE-3101");
  });

  it("2. DiagnosticSanitizer redacts JWT strings and masks email addresses", () => {
    const rawJwt =
      "eyJhYmMxMjMiOiJ0ZXN0In0.eyJyZXN1bHQiOiJzdWNjZXNzIn0.abcdef123456";
    const rawEmail = "student@jnu.ac.bd";

    assert.strictEqual(DiagnosticSanitizer.sanitize(rawJwt), "[REDACTED_JWT]");
    assert.strictEqual(DiagnosticSanitizer.sanitize(rawEmail), "s***@jnu.ac.bd");
  });

  it("3. StructuredLogger.extractContext safely extracts request telemetry", () => {
    const mockRequest: any = {
      auth: { uid: "teacher_123", token: { role: "TEACHER" } },
      app: { appId: "1:123456789:android:abcdef" },
      data: { courseId: "CSE-3101", sessionId: "sess_456" },
    };

    const context = StructuredLogger.extractContext(
      "startAttendanceSession",
      mockRequest
    );

    assert.strictEqual(context.operation, "startAttendanceSession");
    assert.strictEqual(context.uid, "teacher_123");
    assert.strictEqual(context.role, "TEACHER");
    assert.strictEqual(context.appId, "1:123456789:android:abcdef");
    assert.strictEqual(context.courseId, "CSE-3101");
    assert.strictEqual(context.sessionId, "sess_456");
  });

  it("4. StructuredLogger formats errors with standard failure categories", () => {
    const httpsErr = new HttpsError(
      "permission-denied",
      "Only assigned teachers can start attendance."
    );
    const category: FailureCategory = "AUTHORIZATION";

    // Should format and not throw
    StructuredLogger.error(
      "startAttendanceSession",
      httpsErr,
      category,
      { uid: "unassigned_teacher" },
      { courseId: "CSE-3101" }
    );
  });

  it("5. StructuredLogger logs security audit events cleanly", () => {
    // Should log structured audit entry without throwing
    StructuredLogger.audit(
      "approveSignupRequest",
      "admin_super_uid",
      "APPROVED",
      "signupRequest",
      "req_789",
      { assignedRole: "STUDENT", year: 3, semester: 1 }
    );
  });
});
