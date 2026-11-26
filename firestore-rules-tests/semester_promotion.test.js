// S2-05: semester promotion (single approval and "Promote batch"). Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDocs, updateDoc, writeBatch, collection, query, where, deleteField, serverTimestamp } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-promotion',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/teacher'), { role: 'TEACHER', isActive: true });
      await setDoc(doc(db, 'users/chairman'), { role: 'CHAIRMAN', isActive: true });
      await setDoc(doc(db, 'users/cr'), { role: 'CR', year: 3, semester: 1, session: '2021-22', isActive: true });
      await setDoc(doc(db, 'users/mate'), { role: 'STUDENT', year: 3, semester: 1, session: '2021-22', isActive: true });
      await setDoc(doc(db, 'users/mate2'), { role: 'STUDENT', year: 3, semester: 1, session: '2021-22', isActive: true });
      await setDoc(doc(db, 'semesterUpgradeRequests/r1'), { studentId: 'cr', status: 'PENDING', requestedYear: 3, requestedSemester: 2 });
      await setDoc(doc(db, 'semesterUpgradeRequests/r2'), { studentId: 'mate2', status: 'PENDING', requestedYear: 3, requestedSemester: 2 });
      await setDoc(doc(db, 'crTransfers/cr'), { fromUid: 'cr', toUid: 'mate', status: 'PENDING' });
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();

  // What the app writes when a teacher approves the CR's own request.
  function approveCr(who, userPatch = {}) {
    const db = as(who);
    const b = writeBatch(db);
    b.update(doc(db, 'users/cr'), {
      year: 3, semester: 2, lastSemesterRequestId: 'r1', role: 'STUDENT', isCR: deleteField(), updatedAt: serverTimestamp(), ...userPatch,
    });
    b.update(doc(db, 'crTransfers/cr'), { status: 'CANCELLED', updatedAt: serverTimestamp() });
    b.update(doc(db, 'semesterUpgradeRequests/r1'), { status: 'APPROVED', reviewedBy: who, updatedAt: serverTimestamp() });
    return b.commit();
  }

  await test('Approving a CR\'s promotion drops the CR role and cancels their open offer', async () => {
    await reset();
    await assertSucceeds(approveCr('teacher'));
  });

  await test('Approval can\'t make anyone CR or staff, or set the isCR flag', async () => {
    await reset();
    await assertFails(approveCr('teacher', { role: 'TEACHER' }));
    await assertFails(approveCr('teacher', { role: 'CR', isCR: true }));
  });

  await test('A teacher can read open offers, but can cancel one only when a student moves', async () => {
    await reset();
    await assertSucceeds(getDocs(query(collection(as('teacher'), 'crTransfers'), where('toUid', '==', 'mate'), where('status', '==', 'PENDING'))));
    await assertFails(updateDoc(doc(as('teacher'), 'crTransfers/cr'), { status: 'CANCELLED', updatedAt: serverTimestamp() }));
  });

  // "Promote batch": everyone of 3-1 moves to 3-2, the CR stays CR.
  function promoteBatch(who) {
    const db = as(who);
    const b = writeBatch(db);
    for (const uid of ['cr', 'mate', 'mate2']) b.update(doc(db, `users/${uid}`), { year: 3, semester: 2, updatedAt: serverTimestamp() });
    b.update(doc(db, 'semesterUpgradeRequests/r2'), { status: 'APPROVED', reviewedBy: who, updatedAt: serverTimestamp() });
    b.set(doc(db, 'notifications/n1'), { userId: 'mate', senderId: who, title: 'Semester updated', body: 'x', notificationType: 'SEMESTER', isRead: false });
    return b.commit();
  }

  await test('The Chairman can promote a whole batch (CR stays CR)', async () => {
    await reset();
    await assertSucceeds(promoteBatch('chairman'));
  });

  await test('A teacher cannot promote a batch (only via each student\'s request)', async () => {
    await reset();
    await assertFails(promoteBatch('teacher'));
    await assertFails(updateDoc(doc(as('teacher'), 'users/mate'), { year: 3, semester: 2 }));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} semester promotion rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
