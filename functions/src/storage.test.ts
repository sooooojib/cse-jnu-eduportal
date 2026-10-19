import { describe, it } from "node:test";
import * as assert from "node:assert";
import {
  MAX_IMAGE_SIZE_BYTES,
  MAX_DOCUMENT_SIZE_BYTES,
  DISALLOWED_EXTENSIONS,
  isApprovedStoragePath,
  validateFileTypeAndSize,
  evaluateDeletePermission,
  executeGetStorageUploadPolicy,
} from "./storage";

describe("STAGE 26: Firebase Cloud Storage Invariants & Security Rules Tests", () => {
  const adminAuth = { uid: "admin_uid_1", token: { role: "ADMIN" } };
  const teacherAuth = { uid: "teacher_uid_1", token: { role: "TEACHER" } };
  const studentAuth = { uid: "student_uid_1", token: { role: "STUDENT" } };
  const otherStudentAuth = { uid: "student_uid_2", token: { role: "STUDENT" } };

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. AUTHORIZED UPLOAD TESTS
  // ─────────────────────────────────────────────────────────────────────────────
  it("1. Authorized Upload: Admin can generate upload policy for notice attachment", () => {
    const policy = executeGetStorageUploadPolicy(adminAuth, {
      scope: "notice",
      fileName: "semester_routine_final.pdf",
      fileSizeBytes: 2 * 1024 * 1024,
      contentType: "application/pdf",
      entityId: "notice_101",
    });

    assert.ok(policy.storagePath.startsWith("notices/notice_101/"));
    assert.strictEqual(policy.contentType, "application/pdf");
    assert.strictEqual(policy.metadata.uploadedBy, "admin_uid_1");
    assert.strictEqual(policy.maxSizeBytes, MAX_DOCUMENT_SIZE_BYTES);
  });

  it("2. Authorized Upload: User can upload their own avatar with valid image", () => {
    const policy = executeGetStorageUploadPolicy(studentAuth, {
      scope: "avatar",
      fileName: "profile_photo.jpg",
      fileSizeBytes: 1024 * 1024, // 1MB
      contentType: "image/jpeg",
      targetUserId: "student_uid_1",
    });

    assert.ok(policy.storagePath.startsWith("avatars/student_uid_1/"));
    assert.strictEqual(policy.metadata.uploadedBy, "student_uid_1");
    assert.strictEqual(policy.maxSizeBytes, MAX_IMAGE_SIZE_BYTES);
  });

  it("3. Authorized Upload: Student can upload feedback attachment", () => {
    const policy = executeGetStorageUploadPolicy(studentAuth, {
      scope: "feedback",
      fileName: "code_snippet_bug.png",
      fileSizeBytes: 500 * 1024,
      contentType: "image/png",
      entityId: "feedback_202",
    });

    assert.ok(policy.storagePath.startsWith("feedback/feedback_202/attachments/"));
    assert.strictEqual(policy.metadata.uploadedBy, "student_uid_1");
    assert.strictEqual(policy.metadata.scope, "feedback");
  });

  it("4. Authorized Upload: Teacher can upload feedback reply attachment", () => {
    const policy = executeGetStorageUploadPolicy(teacherAuth, {
      scope: "feedback_reply",
      fileName: "annotated_solution.pdf",
      fileSizeBytes: 1.5 * 1024 * 1024,
      contentType: "application/pdf",
      entityId: "feedback_202",
    });

    assert.ok(policy.storagePath.startsWith("feedback/feedback_202/replies/"));
    assert.strictEqual(policy.metadata.uploadedBy, "teacher_uid_1");
  });

  it("5. Authorized Upload: Participant can upload counseling attachment", () => {
    const policy = executeGetStorageUploadPolicy(studentAuth, {
      scope: "counseling",
      fileName: "advising_transcript.pdf",
      fileSizeBytes: 800 * 1024,
      contentType: "application/pdf",
      entityId: "counseling_booking_303",
    });

    assert.ok(policy.storagePath.startsWith("counseling/counseling_booking_303/"));
    assert.strictEqual(policy.metadata.uploadedBy, "student_uid_1");
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. UNAUTHORIZED UPLOAD TESTS
  // ─────────────────────────────────────────────────────────────────────────────
  it("6. Unauthorized Upload: Rejects unauthenticated upload attempts", () => {
    assert.throws(
      () => {
        executeGetStorageUploadPolicy(undefined, {
          scope: "feedback",
          fileName: "test.png",
          fileSizeBytes: 1024,
          contentType: "image/png",
        });
      },
      (err: any) => err.code === "unauthenticated"
    );
  });

  it("7. Unauthorized Upload: Non-admin cannot upload notice attachments", () => {
    assert.throws(
      () => {
        executeGetStorageUploadPolicy(studentAuth, {
          scope: "notice",
          fileName: "fake_notice.pdf",
          fileSizeBytes: 1024,
          contentType: "application/pdf",
        });
      },
      (err: any) => err.code === "permission-denied" && err.message.includes("administrators")
    );
  });

  it("8. Unauthorized Upload: Student cannot upload feedback reply attachments (teacher-only)", () => {
    assert.throws(
      () => {
        executeGetStorageUploadPolicy(studentAuth, {
          scope: "feedback_reply",
          fileName: "unauthorized_reply.pdf",
          fileSizeBytes: 1024,
          contentType: "application/pdf",
          entityId: "feedback_202",
        });
      },
      (err: any) => err.code === "permission-denied" && err.message.includes("teachers or administrators")
    );
  });

  it("9. Unauthorized Upload: User cannot upload avatar for another user", () => {
    assert.throws(
      () => {
        executeGetStorageUploadPolicy(studentAuth, {
          scope: "avatar",
          fileName: "victim_avatar.jpg",
          fileSizeBytes: 1024,
          contentType: "image/jpeg",
          targetUserId: "student_uid_2", // mismatched target
        });
      },
      (err: any) => err.code === "permission-denied" && err.message.includes("their own avatar")
    );
  });

  it("10. Never trust arbitrary paths: Blocks unapproved paths and directory traversal", () => {
    assert.strictEqual(isApprovedStoragePath("system/config.json"), false);
    assert.strictEqual(isApprovedStoragePath("../etc/passwd"), false);
    assert.strictEqual(isApprovedStoragePath("root/secret.pem"), false);
    assert.strictEqual(isApprovedStoragePath("feedback/../../dangerous.js"), false);
    assert.strictEqual(isApprovedStoragePath("/notices/root_file.pdf"), false);

    assert.strictEqual(isApprovedStoragePath("notices/notice_1/file.pdf"), true);
    assert.strictEqual(isApprovedStoragePath("avatars/u1/photo.jpg"), true);
    assert.strictEqual(isApprovedStoragePath("feedback/f1/attachments/att_1.png"), true);
    assert.strictEqual(isApprovedStoragePath("counseling/c1/att_1.pdf"), true);
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. OVERSIZED FILE TESTS
  // ─────────────────────────────────────────────────────────────────────────────
  it("11. Oversized File: Rejects images exceeding 5MB limit", () => {
    const oversizedImageBytes = 5.1 * 1024 * 1024; // 5.1 MB
    assert.throws(
      () => {
        validateFileTypeAndSize("huge_photo.jpg", "image/jpeg", oversizedImageBytes, true);
      },
      (err: any) => err.code === "invalid-argument" && err.message.includes("5MB")
    );
  });

  it("12. Oversized File: Rejects documents exceeding 10MB limit", () => {
    const oversizedDocBytes = 10.5 * 1024 * 1024; // 10.5 MB
    assert.throws(
      () => {
        validateFileTypeAndSize("huge_document.pdf", "application/pdf", oversizedDocBytes, false);
      },
      (err: any) => err.code === "invalid-argument" && err.message.includes("10MB")
    );
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. UNSUPPORTED FILE TYPE TESTS
  // ─────────────────────────────────────────────────────────────────────────────
  it("13. Unsupported File Type: Strictly rejects dangerous executable and script extensions", () => {
    for (const ext of DISALLOWED_EXTENSIONS) {
      assert.throws(
        () => {
          validateFileTypeAndSize(`malicious_script.${ext}`, "application/octet-stream", 1024, false);
        },
        (err: any) => err.code === "invalid-argument" && err.message.includes("strictly prohibited"),
        `Expected extension .${ext} to be prohibited`
      );
    }
  });

  it("14. Unsupported File Type: Rejects non-allowed MIME content types", () => {
    assert.throws(
      () => {
        validateFileTypeAndSize("archive.zip", "application/zip", 1024, false);
      },
      (err: any) => err.code === "invalid-argument" && err.message.includes("content-type")
    );

    assert.throws(
      () => {
        validateFileTypeAndSize("program.bin", "application/octet-stream", 1024, false);
      },
      (err: any) => err.code === "invalid-argument"
    );
  });

  it("15. Allowed File Types: Successfully validates JPEG, PNG, WEBP, PDF, TXT, DOC, DOCX", () => {
    assert.doesNotThrow(() => validateFileTypeAndSize("report.pdf", "application/pdf", 1024, false));
    assert.doesNotThrow(() => validateFileTypeAndSize("notes.txt", "text/plain", 1024, false));
    assert.doesNotThrow(() => validateFileTypeAndSize("photo.png", "image/png", 1024, true));
    assert.doesNotThrow(() => validateFileTypeAndSize("photo.webp", "image/webp", 1024, true));
    assert.doesNotThrow(() => validateFileTypeAndSize("photo.jpg", "image/jpeg", 1024, true));
    assert.doesNotThrow(() => validateFileTypeAndSize("doc.docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", 1024, false));
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. DELETION PERMISSIONS TESTS
  // ─────────────────────────────────────────────────────────────────────────────
  it("16. Deletion Permissions: Uploader can delete their own attachment", () => {
    assert.doesNotThrow(() => {
      evaluateDeletePermission(studentAuth, "feedback/f1/attachments/att_1.png", "student_uid_1");
    });
  });

  it("17. Deletion Permissions: Admin can delete any approved attachment", () => {
    assert.doesNotThrow(() => {
      evaluateDeletePermission(adminAuth, "feedback/f1/attachments/att_1.png", "student_uid_1");
    });
    assert.doesNotThrow(() => {
      evaluateDeletePermission(adminAuth, "notices/n1/file.pdf");
    });
  });

  it("18. Deletion Permissions: Non-owner is denied deletion of another user's file", () => {
    assert.throws(
      () => {
        evaluateDeletePermission(otherStudentAuth, "feedback/f1/attachments/att_1.png", "student_uid_1");
      },
      (err: any) => err.code === "permission-denied"
    );
  });

  it("19. Deletion Permissions: Non-admin cannot delete notice attachments", () => {
    assert.throws(
      () => {
        evaluateDeletePermission(studentAuth, "notices/n1/file.pdf");
      },
      (err: any) => err.code === "permission-denied" && err.message.includes("administrators")
    );
  });

  it("20. Deletion Permissions: Rejects deletion outside approved scopes", () => {
    assert.throws(
      () => {
        evaluateDeletePermission(adminAuth, "secrets/private_key.pem");
      },
      (err: any) => err.code === "invalid-argument" && err.message.includes("approved storage scopes")
    );
  });
});
