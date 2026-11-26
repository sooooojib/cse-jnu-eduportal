// S2-04: "Change role" without a Cloud Function. Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, writeBatch, deleteField, serverTimestamp } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-roles',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/admin'), { role: 'ADMIN', isActive: true });
      await setDoc(doc(db, 'users/admin2'), { role: 'ADMIN', isActive: true });
      await setDoc(doc(db, 'users/chairman'), { role: 'CHAIRMAN', isActive: true });
      await setDoc(doc(db, 'users/teacher'), { role: 'TEACHER', isActive: true });
      await setDoc(doc(db, 'users/oldCr'), { role: 'CR', year: 3, semester: 1, isActive: true });
      await setDoc(doc(db, 'users/student'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
      await setDoc(doc(db, 'crTransfers/oldCr'), { fromUid: 'oldCr', toUid: 'student', status: 'PENDING' });
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();
  const role = (who, uid, r, extra = {}) => updateDoc(doc(as(who), `users/${uid}`), { role: r, updatedAt: serverTimestamp(), ...extra });

  // The batch the app writes to appoint a new CR.
  function appointCr(who) {
    const db = as(who);
    const b = writeBatch(db);
    b.update(doc(db, 'users/oldCr'), { role: 'STUDENT', isCR: deleteField(), updatedAt: serverTimestamp() });
    b.delete(doc(db, 'crTransfers/oldCr'));
    b.update(doc(db, 'users/student'), { role: 'CR', isCR: deleteField(), updatedAt: serverTimestamp() });
    return b.commit();
  }

  await test('Chairman appoints a CR; the old CR becomes a student in the same batch', async () => {
    await reset();
    await assertSucceeds(appointCr('chairman'));
  });

  await test('Admin appoints a CR and can change any staff role, including Admin', async () => {
    await reset();
    await assertSucceeds(appointCr('admin'));
    await assertSucceeds(role('admin', 'teacher', 'CHAIRMAN'));
    await assertSucceeds(role('admin', 'admin2', 'TEACHER'));
  });

  await test('Chairman: staff <-> staff, but never to or from Admin', async () => {
    await reset();
    await assertSucceeds(role('chairman', 'teacher', 'CHAIRMAN'));
    await reset();
    await assertFails(role('chairman', 'teacher', 'ADMIN'));
    await assertFails(role('chairman', 'admin', 'TEACHER'));
  });

  await test('Chairman: no crossing groups, no own role, no isCR flag, no extra fields', async () => {
    await reset();
    await assertFails(role('chairman', 'student', 'TEACHER'));
    await assertFails(role('chairman', 'teacher', 'STUDENT'));
    await assertFails(role('chairman', 'chairman', 'TEACHER'));
    await assertFails(role('chairman', 'student', 'CR', { isCR: true }));
    await assertFails(role('chairman', 'student', 'CR', { year: 4 }));
  });

  await test('Teachers and students cannot change roles', async () => {
    await reset();
    await assertFails(appointCr('teacher'));
    await assertFails(role('teacher', 'student', 'CR'));
    await assertFails(role('student', 'student', 'CR'));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} role change rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
