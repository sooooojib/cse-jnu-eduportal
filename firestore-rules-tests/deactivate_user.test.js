// S2-07: deactivate instead of delete. Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, writeBatch, deleteField, serverTimestamp, updateDoc } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-deactivate',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/admin'), { role: 'ADMIN', isActive: true });
      await setDoc(doc(db, 'users/chairman'), { role: 'CHAIRMAN', isActive: true });
      await setDoc(doc(db, 'users/t'), { role: 'TEACHER', isActive: true, assignedCourseIds: ['C1'] });
      await setDoc(doc(db, 'users/cr'), { role: 'CR', isActive: true, year: 3, semester: 1 });
      await setDoc(doc(db, 'courses/C1'), { code: 'CSE-1', year: 3, semester: 1, teacherId: 't' });
      await setDoc(doc(db, 'courseAssignments/a1'), { courseId: 'C1', teacherId: 't' });
      await setDoc(doc(db, 'schedules/w1'), { courseId: 'C1', teacherId: 't', dayOfWeek: 'SUNDAY' });
      await setDoc(doc(db, 'crTransfers/cr'), { fromUid: 'cr', toUid: 's', status: 'PENDING' });
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();

  function deactivateTeacher(who) {
    const db = as(who);
    const b = writeBatch(db);
    b.update(doc(db, 'users/t'), { isActive: false, assignedCourseIds: [], updatedAt: serverTimestamp() });
    b.update(doc(db, 'courses/C1'), { teacherId: null, teacherName: null, updatedAt: serverTimestamp() });
    b.update(doc(db, 'schedules/w1'), { teacherId: '', teacherName: '', updatedAt: serverTimestamp() });
    b.delete(doc(db, 'courseAssignments/a1'));
    return b.commit();
  }
  function deactivateCr(who) {
    const db = as(who);
    const b = writeBatch(db);
    b.update(doc(db, 'users/cr'), { isActive: false, role: 'STUDENT', isCR: deleteField(), updatedAt: serverTimestamp() });
    b.update(doc(db, 'crTransfers/cr'), { status: 'CANCELLED', updatedAt: serverTimestamp() });
    return b.commit();
  }

  await test('Admin and Chairman can deactivate a teacher and free their courses in one batch', async () => {
    await reset();
    await assertSucceeds(deactivateTeacher('admin'));
    await reset();
    await assertSucceeds(deactivateTeacher('chairman'));
  });

  await test('Admin and Chairman can deactivate a CR (role dropped, offer cancelled)', async () => {
    await reset();
    await assertSucceeds(deactivateCr('admin'));
    await reset();
    await assertSucceeds(deactivateCr('chairman'));
  });

  await test('Chairman cannot deactivate an Admin; teachers cannot deactivate anyone', async () => {
    await reset();
    await assertFails(updateDoc(doc(as('chairman'), 'users/admin'), { isActive: false }));
    await assertFails(deactivateTeacher('t'));
    await assertFails(updateDoc(doc(as('t'), 'users/cr'), { isActive: false }));
  });

  await test('Reactivate', async () => {
    await reset();
    await deactivateTeacher('admin');
    await assertSucceeds(updateDoc(doc(as('chairman'), 'users/t'), { isActive: true, updatedAt: serverTimestamp() }));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} deactivate-user rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
