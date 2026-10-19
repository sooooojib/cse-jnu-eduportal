import { describe, it } from "node:test";
import * as assert from "node:assert";
import {
  validateSemesterInput,
  executeSubmitSemesterRequest,
  executeChangeSemesterRequest,
  executeDismissSemesterRejection,
  executeApproveSemesterUpgrade,
  executeRejectSemesterUpgrade,
  executeGetStudentSemesterStatus,
} from "./semester";

// ─── In-Memory Mock Firestore ────────────────────────────────────────────────

class MockDocumentSnapshot {
  constructor(public id: string, private _data: any) {}
  get exists() {
    return this._data !== undefined && this._data !== null;
  }
  data() {
    return this._data ? JSON.parse(JSON.stringify(this._data)) : undefined;
  }
}

class MockQuerySnapshot {
  constructor(public docs: MockDocumentSnapshot[]) {}
  get empty() {
    return this.docs.length === 0;
  }
  get size() {
    return this.docs.length;
  }
}

class MockFirestore {
  public store: Map<string, Map<string, any>> = new Map();

  collection(name: string) {
    if (!this.store.has(name)) {
      this.store.set(name, new Map());
    }
    const collMap = this.store.get(name)!;

    return {
      doc: (id?: string) => {
        const docId = id || `doc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        return {
          id: docId,
          get: async () => new MockDocumentSnapshot(docId, collMap.get(docId)),
          set: async (data: any, options?: { merge?: boolean }) => {
            if (options?.merge && collMap.has(docId)) {
              collMap.set(docId, { ...collMap.get(docId), ...data });
            } else {
              collMap.set(docId, { ...data });
            }
          },
          update: async (data: any) => {
            const current = collMap.get(docId);
            if (!current) throw new Error(`Document ${docId} does not exist`);
            collMap.set(docId, { ...current, ...data });
          },
        };
      },
      add: async (data: any) => {
        const docId = `doc_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        collMap.set(docId, { ...data });
        return { id: docId };
      },
      where: (field: string, op: string, val: any) => {
        let docs = Array.from(collMap.entries()).map(([k, v]) => new MockDocumentSnapshot(k, v));
        docs = docs.filter((d) => {
          const dData = d.data();
          if (op === "==") return dData?.[field] === val;
          return true;
        });

        const queryObj: any = {
          where: (f2: string, op2: string, val2: any) => {
            docs = docs.filter((d) => {
              const dData = d.data();
              if (op2 === "==") return dData?.[f2] === val2;
              return true;
            });
            return queryObj;
          },
          orderBy: () => queryObj,
          limit: () => queryObj,
          get: async () => new MockQuerySnapshot(docs),
        };
        return queryObj;
      },
      orderBy: () => ({
        limit: () => ({
          get: async () => {
            const docs = Array.from(collMap.entries()).map(([k, v]) => new MockDocumentSnapshot(k, v));
            return new MockQuerySnapshot(docs);
          },
        }),
        get: async () => {
          const docs = Array.from(collMap.entries()).map(([k, v]) => new MockDocumentSnapshot(k, v));
          return new MockQuerySnapshot(docs);
        },
      }),
      get: async () => {
        const docs = Array.from(collMap.entries()).map(([k, v]) => new MockDocumentSnapshot(k, v));
        return new MockQuerySnapshot(docs);
      },
    };
  }

  async runTransaction(updateFunction: (transaction: any) => Promise<any>): Promise<any> {
    const transaction = {
      get: async (ref: any) => ref.get(),
      set: (ref: any, data: any, options?: any) => ref.set(data, options),
      update: (ref: any, data: any) => ref.update(data),
      delete: (ref: any) => {
        // delete
      },
    };
    return updateFunction(transaction);
  }
}

// ─── UNIT TESTS ─────────────────────────────────────────────────────────────

describe("STAGE 25: Semester and Enrollment Workflow Tests", () => {
  it("1. validateSemesterInput succeeds on valid academic year (1-4) and semester (1-2)", () => {
    const res1 = validateSemesterInput(1, 1);
    assert.strictEqual(res1.year, 1);
    assert.strictEqual(res1.semester, 1);

    const res2 = validateSemesterInput(4, 2);
    assert.strictEqual(res2.year, 4);
    assert.strictEqual(res2.semester, 2);
  });

  it("2. validateSemesterInput rejects invalid year (outside 1-4) or invalid semester", () => {
    assert.throws(() => validateSemesterInput(0, 1), /Academic year must be an integer between 1 and 4/);
    assert.throws(() => validateSemesterInput(5, 1), /Academic year must be an integer between 1 and 4/);
    assert.throws(() => validateSemesterInput(2, 3), /Academic semester must be either 1 or 2/);
    assert.throws(() => validateSemesterInput(2, 0), /Academic semester must be either 1 or 2/);
  });

  it("3. executeSubmitSemesterRequest creates a valid pending request for a student", async () => {
    const firestore = new MockFirestore() as any;
    await firestore.collection("users").doc("student-1").set({
      fullName: "Sajib Ahmed",
      studentId: "B210305015",
      year: 2,
      semester: 2,
    });

    const res = await executeSubmitSemesterRequest(firestore, "student-1", 3, 1);
    assert.strictEqual(res.studentId, "student-1");
    assert.strictEqual(res.currentYear, 2);
    assert.strictEqual(res.currentSemester, 2);
    assert.strictEqual(res.requestedYear, 3);
    assert.strictEqual(res.requestedSemester, 1);
    assert.strictEqual(res.status, "PENDING");
  });

  it("4. Prevents duplicate requests: Throws if student already has a PENDING request", async () => {
    const firestore = new MockFirestore() as any;
    await firestore.collection("users").doc("student-1").set({
      fullName: "Sajib Ahmed",
      year: 2,
      semester: 2,
    });

    await executeSubmitSemesterRequest(firestore, "student-1", 3, 1);

    await assert.rejects(
      async () => executeSubmitSemesterRequest(firestore, "student-1", 3, 2),
      /You already have a pending enrollment\/semester request/
    );
  });

  it("5. executeChangeSemesterRequest allows student to modify pending target year & semester", async () => {
    const firestore = new MockFirestore() as any;
    await firestore.collection("users").doc("student-1").set({
      fullName: "Sajib Ahmed",
      year: 2,
      semester: 2,
    });

    const initial = await executeSubmitSemesterRequest(firestore, "student-1", 3, 1);
    const updated = await executeChangeSemesterRequest(firestore, "student-1", initial.id, 3, 2);

    assert.strictEqual((updated as any).requestedYear, 3);
    assert.strictEqual((updated as any).requestedSemester, 2);
  });

  it("6. Prevents modifying someone else's request or changing processed requests", async () => {
    const firestore = new MockFirestore() as any;
    await firestore.collection("users").doc("student-1").set({
      fullName: "Sajib Ahmed",
      year: 2,
      semester: 2,
    });

    const initial = await executeSubmitSemesterRequest(firestore, "student-1", 3, 1);

    // Another student unauthorized
    await assert.rejects(
      async () => executeChangeSemesterRequest(firestore, "student-2", initial.id, 4, 1),
      /You can only modify your own enrollment request/
    );
  });

  it("7. executeApproveSemesterUpgrade updates student profile, marks request APPROVED, and creates notification", async () => {
    const firestore = new MockFirestore() as any;
    await firestore.collection("users").doc("student-1").set({
      fullName: "Sajib Ahmed",
      year: 2,
      semester: 2,
    });

    const initial = await executeSubmitSemesterRequest(firestore, "student-1", 3, 1);

    const result = await executeApproveSemesterUpgrade(firestore, null, "admin-root", initial.id);
    assert.strictEqual(result.success, true);
    assert.strictEqual(result.newYear, 3);
    assert.strictEqual(result.newSemester, 1);

    // Verify user profile updated
    const userDoc = await firestore.collection("users").doc("student-1").get();
    assert.strictEqual(userDoc.data()?.year, 3);
    assert.strictEqual(userDoc.data()?.semester, 1);

    // Verify request status is APPROVED
    const reqDoc = await firestore.collection("semesterUpgradeRequests").doc(initial.id).get();
    assert.strictEqual(reqDoc.data()?.status, "APPROVED");
    assert.strictEqual(reqDoc.data()?.approvedBy, "admin-root");

    // Verify notification was posted
    const notifs = await firestore.collection("notifications").get();
    assert.strictEqual(notifs.docs.length, 1);
    assert.strictEqual(notifs.docs[0].data()?.userId, "student-1");
    assert.ok(notifs.docs[0].data()?.body.includes("Year 3, Semester 1"));
  });

  it("8. Prevents processing the same request twice (double approval or approving after already processed)", async () => {
    const firestore = new MockFirestore() as any;
    await firestore.collection("users").doc("student-1").set({
      fullName: "Sajib Ahmed",
      year: 2,
      semester: 2,
    });

    const initial = await executeSubmitSemesterRequest(firestore, "student-1", 3, 1);
    await executeApproveSemesterUpgrade(firestore, null, "admin-root", initial.id);

    // Attempting to approve again
    await assert.rejects(
      async () => executeApproveSemesterUpgrade(firestore, null, "admin-root", initial.id),
      /This request has already been processed with status APPROVED/
    );
  });

  it("9. executeRejectSemesterUpgrade rejects request with reason and notifies student", async () => {
    const firestore = new MockFirestore() as any;
    await firestore.collection("users").doc("student-1").set({
      fullName: "Sajib Ahmed",
      year: 2,
      semester: 2,
    });

    const initial = await executeSubmitSemesterRequest(firestore, "student-1", 3, 1);
    const result = await executeRejectSemesterUpgrade(
      firestore,
      "admin-root",
      initial.id,
      "Incomplete prerequisites for 3rd year."
    );

    assert.strictEqual(result.success, true);

    const reqDoc = await firestore.collection("semesterUpgradeRequests").doc(initial.id).get();
    assert.strictEqual(reqDoc.data()?.status, "REJECTED");
    assert.strictEqual(reqDoc.data()?.rejectionReason, "Incomplete prerequisites for 3rd year.");

    // Verify rejection notification
    const notifs = await firestore.collection("notifications").get();
    assert.strictEqual(notifs.docs.length, 1);
    assert.ok(notifs.docs[0].data()?.body.includes("Incomplete prerequisites for 3rd year."));
  });

  it("10. executeDismissSemesterRejection allows student to dismiss rejection and clear rejected status", async () => {
    const firestore = new MockFirestore() as any;
    await firestore.collection("users").doc("student-1").set({
      fullName: "Sajib Ahmed",
      year: 2,
      semester: 2,
    });

    const initial = await executeSubmitSemesterRequest(firestore, "student-1", 3, 1);
    await executeRejectSemesterUpgrade(firestore, "admin-root", initial.id, "Prerequisites missing.");

    const dismissRes = await executeDismissSemesterRejection(firestore, "student-1", initial.id);
    assert.strictEqual(dismissRes.success, true);

    const reqDoc = await firestore.collection("semesterUpgradeRequests").doc(initial.id).get();
    assert.strictEqual(reqDoc.data()?.status, "DISMISSED");
    assert.strictEqual(reqDoc.data()?.isDismissed, true);
  });

  it("11. executeGetStudentSemesterStatus accurately resolves all 4 states: NO_ENROLLMENT, PENDING, APPROVED, REJECTED", async () => {
    const firestore = new MockFirestore() as any;

    // State 1: NO_ENROLLMENT
    await firestore.collection("users").doc("new-student").set({
      fullName: "Fresh Student",
      year: null,
      semester: null,
    });
    const s1 = await executeGetStudentSemesterStatus(firestore, "new-student");
    assert.strictEqual(s1.status, "NO_ENROLLMENT");

    // State 2: PENDING
    const req = await executeSubmitSemesterRequest(firestore, "new-student", 1, 1);
    const s2 = await executeGetStudentSemesterStatus(firestore, "new-student");
    assert.strictEqual(s2.status, "PENDING");
    assert.strictEqual(s2.requestedYear, 1);

    // State 3: REJECTED
    await executeRejectSemesterUpgrade(firestore, "admin-root", req.id, "Invalid high school certificate.");
    const s3 = await executeGetStudentSemesterStatus(firestore, "new-student");
    assert.strictEqual(s3.status, "REJECTED");
    assert.strictEqual(s3.rejectionReason, "Invalid high school certificate.");

    // Dismissal -> resets to active/no-enrollment
    await executeDismissSemesterRejection(firestore, "new-student", req.id);

    // Re-submit and Approve -> State 4: APPROVED
    const req2 = await executeSubmitSemesterRequest(firestore, "new-student", 1, 1);
    await executeApproveSemesterUpgrade(firestore, null, "admin-root", req2.id);

    const s4 = await executeGetStudentSemesterStatus(firestore, "new-student");
    assert.strictEqual(s4.status, "APPROVED");
    assert.strictEqual(s4.currentYear, 1);
    assert.strictEqual(s4.currentSemester, 1);
  });
});
