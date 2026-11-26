// S1-15: "Delete my account". Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDocs, deleteDoc, collection, query, where, writeBatch } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-delete',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/student'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
      await setDoc(doc(db, 'users/other'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
      await setDoc(doc(db, 'users/cr'), { role: 'CR', year: 3, semester: 1, isActive: true });
      await setDoc(doc(db, 'users/flagCr'), { role: 'STUDENT', isCR: true, year: 3, semester: 1, isActive: true });
      await setDoc(doc(db, 'users/teacher'), { role: 'TEACHER', isActive: true });
      await setDoc(doc(db, 'signupRequests/student'), { userId: 'student', status: 'APPROVED' });
      await setDoc(doc(db, 'notifications/n1'), { userId: 'student', title: 'x' });
      await setDoc(doc(db, 'semesterUpgradeRequests/r1'), { studentId: 'student', status: 'PENDING' });
      await setDoc(doc(db, 'semesterUpgradeRequests/r2'), { studentId: 'other', status: 'PENDING' });
      await setDoc(doc(db, 'counselingBookings/b1'), { studentId: 'student', teacherId: 'teacher', status: 'PENDING' });
      await setDoc(doc(db, 'counselingBookings/b2'), { studentId: 'other', teacherId: 'teacher', status: 'PENDING' });
      await setDoc(doc(db, 'enrollments/C1_student'), { courseId: 'C1', studentId: 'student', type: 'RETAKE' });
      await setDoc(doc(db, 'feedback/named'), { studentId: 'student', teacherId: 'teacher', rating: 3 });
      await setDoc(doc(db, 'feedback/anon'), { studentId: 'ANONYMOUS', teacherId: 'teacher', rating: 3 });
      await setDoc(doc(db, 'feedbackIdentities/anon'), { studentId: 'student' });
      await setDoc(doc(db, 'feedback/others'), { studentId: 'other', teacherId: 'teacher', rating: 3 });
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();

  await test('A student can remove all their own data, then their profile (same order as the app)', async () => {
    await reset();
    const db = as('student');
    for (const [col, field] of [['notifications', 'userId'], ['semesterUpgradeRequests', 'studentId'], ['counselingBookings', 'studentId']]) {
      const snap = await assertSucceeds(getDocs(query(collection(db, col), where(field, '==', 'student'))));
      const b = writeBatch(db);
      snap.docs.forEach((d) => b.delete(d.ref));
      await assertSucceeds(b.commit());
    }
    await assertSucceeds(deleteDoc(doc(db, 'enrollments/C1_student')));
    await assertSucceeds(deleteDoc(doc(db, 'feedback/named')));
    await assertSucceeds(deleteDoc(doc(db, 'feedback/anon')));
    await assertSucceeds(deleteDoc(doc(db, 'feedbackIdentities/anon')));
    await assertSucceeds(deleteDoc(doc(db, 'signupRequests/student')));
    await assertSucceeds(deleteDoc(doc(db, 'users/student')));
  });

  await test('A student cannot delete other people\'s data or profile', async () => {
    await reset();
    const db = as('student');
    await assertFails(deleteDoc(doc(db, 'users/other')));
    await assertFails(deleteDoc(doc(db, 'semesterUpgradeRequests/r2')));
    await assertFails(deleteDoc(doc(db, 'counselingBookings/b2')));
    await assertFails(deleteDoc(doc(db, 'feedback/others')));
    await assertFails(deleteDoc(doc(db, 'signupRequests/other')));
  });

  await test('CRs (role or flag) and teachers cannot delete their own profile', async () => {
    await reset();
    await assertFails(deleteDoc(doc(as('cr'), 'users/cr')));
    await assertFails(deleteDoc(doc(as('flagCr'), 'users/flagCr')));
    await assertFails(deleteDoc(doc(as('teacher'), 'users/teacher')));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} account deletion rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
