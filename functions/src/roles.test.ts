import { describe, it } from "node:test";
import * as assert from "node:assert";
import {
  isAdminRole,
  isSystemAdminRole,
  isTeacherRole,
  isChairmanRole,
  isStudentSideRole,
  canReviewSignupRequest,
  canAssignRole,
  isValidAcademicSession,
} from "./roles";
import { evaluateUploadPermission, evaluateDeletePermission } from "./storage";
import { executeGetAdminFeedback } from "./feedback";

function fakeFirestore(collections: Record<string, Array<{ id: string; data: any }>>): any {
  return {
    collection(name: string) {
      return {
        async get() {
          return {
            docs: (collections[name] || []).map((d) => ({ id: d.id, data: () => ({ ...d.data }) })),
          };
        },
      };
    },
  };
}

describe("Chairman Role: RBAC helpers", () => {
  it("1. CHAIRMAN has both admin and teacher capability; ADMIN is admin only", () => {
    assert.strictEqual(isAdminRole("CHAIRMAN"), true);
    assert.strictEqual(isTeacherRole("CHAIRMAN"), true);
    assert.strictEqual(isChairmanRole("chairman"), true);
    assert.strictEqual(isAdminRole("ADMIN"), true);
    assert.strictEqual(isTeacherRole("ADMIN"), false);
    assert.strictEqual(isAdminRole("TEACHER"), false);
    assert.strictEqual(isTeacherRole("TEACHER"), true);
    assert.strictEqual(isTeacherRole("faculty"), true);
    assert.strictEqual(isAdminRole(undefined), false);
    assert.strictEqual(isAdminRole("STUDENT"), false);
  });

  it("2. Only ADMIN is the system admin", () => {
    assert.strictEqual(isSystemAdminRole("ADMIN"), true);
    assert.strictEqual(isSystemAdminRole("admin"), true);
    assert.strictEqual(isSystemAdminRole("CHAIRMAN"), false);
  });

  it("3. Student-side roles", () => {
    assert.strictEqual(isStudentSideRole("STUDENT"), true);
    assert.strictEqual(isStudentSideRole("CR"), true);
    assert.strictEqual(isStudentSideRole("TEACHER"), false);
    assert.strictEqual(isStudentSideRole("CHAIRMAN"), false);
  });
});

describe("Chairman Role: signup review permissions", () => {
  it("4. Admin and Chairman can review any signup request", () => {
    for (const caller of ["ADMIN", "CHAIRMAN"]) {
      for (const requested of ["STUDENT", "CR", "TEACHER"]) {
        assert.strictEqual(canReviewSignupRequest(caller, false, requested), true, `${caller} -> ${requested}`);
      }
    }
  });

  it("5. Delegated faculty can review only STUDENT / CR requests", () => {
    assert.strictEqual(canReviewSignupRequest("TEACHER", true, "STUDENT"), true);
    assert.strictEqual(canReviewSignupRequest("TEACHER", true, "CR"), true);
    assert.strictEqual(canReviewSignupRequest("TEACHER", true, "TEACHER"), false);
    assert.strictEqual(canReviewSignupRequest("TEACHER", true, undefined), true); // defaults to STUDENT
  });

  it("6. Non-delegated faculty and students cannot review requests", () => {
    assert.strictEqual(canReviewSignupRequest("TEACHER", false, "STUDENT"), false);
    assert.strictEqual(canReviewSignupRequest("STUDENT", true, "STUDENT"), false);
    assert.strictEqual(canReviewSignupRequest("CR", false, "STUDENT"), false);
  });
});

describe("Chairman Role: role provisioning", () => {
  it("7. ADMIN may assign every role", () => {
    for (const r of ["STUDENT", "CR", "TEACHER", "CHAIRMAN", "ADMIN"]) {
      assert.strictEqual(canAssignRole("ADMIN", r), true, r);
    }
  });

  it("8. CHAIRMAN may assign every role except ADMIN (no privilege escalation)", () => {
    assert.strictEqual(canAssignRole("CHAIRMAN", "TEACHER"), true);
    assert.strictEqual(canAssignRole("CHAIRMAN", "STUDENT"), true);
    assert.strictEqual(canAssignRole("CHAIRMAN", "CHAIRMAN"), true);
    assert.strictEqual(canAssignRole("CHAIRMAN", "ADMIN"), false);
  });

  it("9. Teachers cannot assign roles; unknown roles are rejected", () => {
    assert.strictEqual(canAssignRole("TEACHER", "STUDENT"), false);
    assert.strictEqual(canAssignRole("ADMIN", "SUPERUSER"), false);
  });
});

describe("Student Session validation", () => {
  it("10. Accepts consecutive-year sessions only", () => {
    assert.strictEqual(isValidAcademicSession("2021-2022"), true);
    assert.strictEqual(isValidAcademicSession(" 2024-2025 "), true);
    assert.strictEqual(isValidAcademicSession("2021-2023"), false);
    assert.strictEqual(isValidAcademicSession("2021/2022"), false);
    assert.strictEqual(isValidAcademicSession("21-22"), false);
    assert.strictEqual(isValidAcademicSession(""), false);
    assert.strictEqual(isValidAcademicSession(undefined), false);
    assert.strictEqual(isValidAcademicSession(20212022), false);
  });
});

describe("Chairman Role: module integration", () => {
  it("11. Chairman can upload notice attachments and delete any file like an admin", () => {
    const chairman = { uid: "chair_1", token: { role: "CHAIRMAN" } };
    assert.doesNotThrow(() =>
      evaluateUploadPermission(chairman as any, {
        scope: "notice",
        fileName: "notice.pdf",
        mimeType: "application/pdf",
        fileSize: 1024,
      } as any)
    );
    assert.doesNotThrow(() => evaluateDeletePermission(chairman as any, "notices/n1/file.pdf"));
  });

  it("12. Chairman feedback audit never reveals anonymous student identities", async () => {
    const db = fakeFirestore({
      feedback: [
        { id: "f1", data: { isAnonymous: true, studentId: "ANONYMOUS", teacherId: "t1", comments: "Great" } },
        { id: "f2", data: { isAnonymous: false, studentId: "s2", studentName: "Rahim", teacherId: "t1" } },
      ],
      feedbackIdentities: [{ id: "f1", data: { studentId: "s1", studentName: "Karim", studentEmail: "k@x.bd" } }],
    });

    const chairView: any[] = await executeGetAdminFeedback(db, { uid: "chair", role: "CHAIRMAN" });
    const anon = chairView.find((f) => f.id === "f1");
    assert.strictEqual(anon.studentId, "ANONYMOUS");
    assert.strictEqual(anon.adminAuditStudentId, undefined);
    assert.strictEqual(chairView.find((f) => f.id === "f2").studentName, "Rahim");

    const adminView: any[] = await executeGetAdminFeedback(db, { uid: "admin", role: "ADMIN" });
    assert.strictEqual(adminView.find((f) => f.id === "f1").adminAuditStudentId, "s1");
  });

  it("13. Teachers cannot run the institutional feedback audit", async () => {
    const db = fakeFirestore({ feedback: [] });
    await assert.rejects(() => executeGetAdminFeedback(db, { uid: "t", role: "TEACHER" }));
  });
});
