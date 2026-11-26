// S1-09: notifications can't be faked. Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, addDoc, collection } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-notices',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/student'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
    await setDoc(doc(db, 'users/teacher'), { role: 'TEACHER', isActive: true });
    await setDoc(doc(db, 'users/otherTeacher'), { role: 'TEACHER', isActive: true });
    await setDoc(doc(db, 'users/admin'), { role: 'ADMIN', isActive: true });
    await setDoc(doc(db, 'semesterUpgradeRequests/decided'), { studentId: 'student', status: 'APPROVED', reviewedBy: 'teacher' });
    await setDoc(doc(db, 'semesterUpgradeRequests/pending'), { studentId: 'student', status: 'PENDING' });
  });
  const as = (uid) => env.authenticatedContext(uid).firestore();
  const note = (extra) => ({ userId: 'student', title: 'X', body: 'Y', isRead: false, ...extra });

  await test('A teacher cannot send a made-up message ("Fee due, send money")', async () => {
    for (const type of ['ROUTINE_ANNOUNCEMENT', 'ATTENDANCE_SESSION', 'SCHEDULE_UPDATE', 'GENERAL']) {
      await assertFails(addDoc(collection(as('teacher'), 'notifications'),
        note({ senderId: 'teacher', notificationType: type, title: 'Fee due', body: 'Send money' })));
    }
  });

  await test('A semester notice needs a decided request reviewed by the sender', async () => {
    const sem = (by, id) => note({ senderId: by, notificationType: 'SEMESTER', referenceType: 'SEMESTER_REQUEST', referenceId: id });
    await assertSucceeds(addDoc(collection(as('teacher'), 'notifications'), sem('teacher', 'decided')));
    await assertFails(addDoc(collection(as('otherTeacher'), 'notifications'), sem('otherTeacher', 'decided')));
    await assertFails(addDoc(collection(as('teacher'), 'notifications'), sem('teacher', 'pending')));
    await assertFails(addDoc(collection(as('teacher'), 'notifications'), note({ notificationType: 'SEMESTER', referenceType: 'SEMESTER_REQUEST', referenceId: 'decided' })));
  });

  await test('Admins can still post notices', async () => {
    await assertSucceeds(addDoc(collection(as('admin'), 'notifications'), note({ notificationType: 'ANNOUNCEMENT' })));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} notification rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
