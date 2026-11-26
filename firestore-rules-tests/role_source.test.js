// S1-03: the role comes from the users record only; token claims are ignored.
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
    projectId: 'demo-roles',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/demoted'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
    await setDoc(doc(db, 'users/promoted'), { role: 'TEACHER', assignedCourseIds: ['CSE-3101'], isActive: true });
    await setDoc(doc(db, 'users/oldadmin'), { role: 'STUDENT', year: 1, semester: 1, isActive: true });
    await setDoc(doc(db, 'courses/CSE-3101'), { code: 'CSE-3101', teacherId: 'promoted', year: 3, semester: 1 });
  });
  const exam = (by) => ({
    courseId: 'CSE-3101', courseCode: 'CSE-3101', title: 'CT', examDate: '2026-12-10', startTime: '10:00 AM',
    endTime: '11:00 AM', room: 'R', year: 3, semester: 1, type: 'FINAL', status: 'SCHEDULED', createdBy: by,
  });

  await test('A stale TEACHER token claim gives no teacher powers when the record says STUDENT', async () => {
    const db = env.authenticatedContext('demoted', { role: 'TEACHER' }).firestore();
    await assertFails(addDoc(collection(db, 'exams'), exam('demoted')));
  });

  await test('A stale ADMIN token claim gives no admin powers', async () => {
    const db = env.authenticatedContext('oldadmin', { role: 'ADMIN' }).firestore();
    await assertFails(setDoc(doc(db, 'holidays/2026-12-16'), { date: '2026-12-16', title: 'X' }));
  });

  await test('The record role works even when the token still says STUDENT', async () => {
    const db = env.authenticatedContext('promoted', { role: 'STUDENT' }).firestore();
    await assertSucceeds(addDoc(collection(db, 'exams'), exam('promoted')));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} role-source rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
