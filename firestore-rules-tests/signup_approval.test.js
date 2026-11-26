// Security-rule tests: signup with a real login + approval by any teacher,
// and semester requests decided by any teacher. Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, writeBatch, serverTimestamp } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');

const STAFF = {
  teacher: { role: 'TEACHER', isActive: true },
  chairman: { role: 'CHAIRMAN', isActive: true },
  admin: { role: 'ADMIN', isActive: true },
  student: { role: 'STUDENT', year: 2, semester: 2, isActive: true, email: 's@x.bd' },
  other: { role: 'STUDENT', year: 1, semester: 1, isActive: true },
};

const signup = (uid, extra = {}) => ({
  userId: uid, email: `${uid}@x.bd`, fullName: 'New Person', role: 'STUDENT', session: '2023-2024',
  status: 'PENDING', ...extra,
});

const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-signup',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const [uid, d] of Object.entries(STAFF)) await setDoc(doc(db, `users/${uid}`), d);
      await setDoc(doc(db, 'signupRequests/newbie'), signup('newbie'));
      await setDoc(doc(db, 'signupRequests/newteach'), signup('newteach', { role: 'TEACHER', session: '' }));
      await setDoc(doc(db, 'signupRequests/sneaky'), signup('admin')); // points at an existing account
      await setDoc(doc(db, 'semesterUpgradeRequests/r1'), {
        studentId: 'student', requestedYear: 3, requestedSemester: 1, status: 'PENDING',
      });
    });
  }
  const as = (uid, email) => env.authenticatedContext(uid, email ? { email } : {}).firestore();

  const approveBatch = (db, uid, req, user) => {
    const b = writeBatch(db);
    b.set(doc(db, `users/${uid}`), {
      id: uid, email: req.email, fullName: req.fullName, role: req.role, year: 2, semester: 1,
      session: req.session, isActive: true, assignedCourseIds: [], fcmTokens: [], ...user,
    });
    b.update(doc(db, `signupRequests/${uid}`), {
      status: 'APPROVED', assignedYear: 2, assignedSemester: 1, createdUserId: uid, reviewedBy: 'teacher',
      approvedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    return b.commit();
  };

  await test('A new person files their own request (id = uid, email = login email)', async () => {
    await reset();
    await assertSucceeds(setDoc(doc(as('fresh', 'fresh@x.bd'), 'signupRequests/fresh'), signup('fresh')));
    await assertFails(setDoc(doc(as('fresh', 'fresh@x.bd'), 'signupRequests/someoneelse'), signup('someoneelse')));
    await assertFails(setDoc(doc(as('fresh', 'fresh@x.bd'), 'signupRequests/fresh'), signup('fresh', { email: 'other@x.bd' })));
  });

  await test('Applicant reads only their own request; teachers read all', async () => {
    await reset();
    await assertSucceeds(getDoc(doc(as('newbie', 'newbie@x.bd'), 'signupRequests/newbie')));
    await assertFails(getDoc(doc(as('newbie', 'newbie@x.bd'), 'signupRequests/newteach')));
    await assertSucceeds(getDoc(doc(as('teacher'), 'signupRequests/newteach')));
    await assertFails(getDoc(doc(as('student'), 'signupRequests/newbie')));
  });

  await test('Any teacher approves a student signup (account + request in one batch)', async () => {
    await reset();
    await assertSucceeds(approveBatch(as('teacher'), 'newbie', signup('newbie')));
  });

  await test('Approval must match the request (role / semester / active)', async () => {
    await reset();
    await assertFails(approveBatch(as('teacher'), 'newbie', signup('newbie'), { role: 'CR' }));
    await reset();
    await assertFails(approveBatch(as('teacher'), 'newbie', signup('newbie'), { year: 4 }));
  });

  await test('S1-08: approval cannot slip in extra powers or change name / roll', async () => {
    await reset();
    await assertFails(approveBatch(as('teacher'), 'newbie', signup('newbie'), { isCR: true }));
    await reset();
    await assertFails(approveBatch(as('teacher'), 'newbie', signup('newbie'), { assignedCourseIds: ['CSE-3101'] }));
    await reset();
    await assertFails(approveBatch(as('teacher'), 'newbie', signup('newbie'), { isAdminDelegate: true }));
    await reset();
    await assertFails(approveBatch(as('teacher'), 'newbie', signup('newbie'), { fullName: 'Someone Else' }));
    await reset();
    await assertFails(approveBatch(as('teacher'), 'newbie', signup('newbie'), { studentId: 'B999' }));
  });

  await test('Teacher cannot create an account without approving, or overwrite an existing one', async () => {
    await reset();
    await assertFails(setDoc(doc(as('teacher'), 'users/newbie'), { email: 'newbie@x.bd', role: 'STUDENT', year: 2, semester: 1, isActive: true }));
    await assertFails(approveBatch(as('teacher'), 'admin', signup('admin')));
  });

  await test('Teacher signups: only Admin / Chairman approve', async () => {
    await reset();
    await assertFails(approveBatch(as('teacher'), 'newteach', signup('newteach', { role: 'TEACHER', session: '' })));
    await assertFails(updateDoc(doc(as('teacher'), 'signupRequests/newteach'), { status: 'REJECTED', reviewedBy: 'teacher' }));
    await assertSucceeds(updateDoc(doc(as('chairman'), 'signupRequests/newteach'), { status: 'REJECTED', reviewedBy: 'chairman' }));
  });

  await test('Teacher rejects a student signup, but cannot edit its details', async () => {
    await reset();
    await assertFails(updateDoc(doc(as('teacher'), 'signupRequests/newbie'), { status: 'REJECTED', reviewedBy: 'teacher', fullName: 'X' }));
    await assertSucceeds(updateDoc(doc(as('teacher'), 'signupRequests/newbie'), { status: 'REJECTED', reviewedBy: 'teacher', rejectionReason: 'Not a CSE student' }));
    await assertFails(updateDoc(doc(as('student'), 'signupRequests/newbie'), { status: 'APPROVED', reviewedBy: 'student' }));
  });

  const approveSemester = (db, year = 3, sem = 1) => {
    const b = writeBatch(db);
    b.update(doc(db, 'users/student'), { year, semester: sem, lastSemesterRequestId: 'r1', updatedAt: serverTimestamp() });
    b.update(doc(db, 'semesterUpgradeRequests/r1'), { status: 'APPROVED', reviewedBy: 'teacher', approvedAt: serverTimestamp() });
    return b.commit();
  };

  await test('Any teacher approves a semester request to exactly the requested semester', async () => {
    await reset();
    await assertFails(approveSemester(as('teacher'), 4, 2));
    await assertSucceeds(approveSemester(as('teacher')));
  });

  await test('Older requests stored as targetYear / targetSemester also approve correctly', async () => {
    await reset();
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'semesterUpgradeRequests/r1'), {
        studentId: 'student', targetYear: 3, targetSemester: 1, status: 'PENDING',
      });
    });
    await assertFails(approveSemester(as('teacher'), 1, 1)); // no silent move to Year 1
    await assertSucceeds(approveSemester(as('teacher')));
  });

  await test('Teacher rejects a semester request; cannot change a student otherwise', async () => {
    await reset();
    await assertSucceeds(updateDoc(doc(as('teacher'), 'semesterUpgradeRequests/r1'), { status: 'REJECTED', reviewedBy: 'teacher', rejectionReason: 'Results pending' }));
    await reset();
    await assertFails(updateDoc(doc(as('teacher'), 'users/student'), { year: 4 }));
    await assertFails(updateDoc(doc(as('teacher'), 'users/student'), { role: 'CR', lastSemesterRequestId: 'r1' }));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} signup / semester approval rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
