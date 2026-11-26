// S2-11: small attendance summary records (free plan). Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, writeBatch, arrayUnion, arrayRemove, increment, serverTimestamp, Timestamp } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}
function dhakaKey(offsetDays = 0) {
  const t = new Date(Date.now() + 6 * 3600e3);
  return new Date(Date.UTC(t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate() + offsetDays, 6)).toISOString().slice(0, 10);
}
const mins = (m) => Timestamp.fromDate(new Date(Date.now() + m * 60000));
const secs = (s) => Timestamp.fromDate(new Date(Date.now() + s * 1000));

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-stats',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/stu'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
      await setDoc(doc(db, 'users/mate'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
      await setDoc(doc(db, 'users/t'), { role: 'TEACHER', isActive: true, assignedCourseIds: ['C1'] });
      await setDoc(doc(db, 'users/t2'), { role: 'TEACHER', isActive: true, assignedCourseIds: ['C2'] });
      await setDoc(doc(db, 'courses/C1'), { code: 'CSE-3101', year: 3, semester: 1, teacherId: 't' });
      await setDoc(doc(db, 'studentStats/stu'), { present: { C1: ['2026-11-01'], C2: ['2026-11-02'] }, complete: true });
      await setDoc(doc(db, 'attendanceSessions/s1'), {
        courseId: 'C1', teacherId: 't', mode: 'CODE', isActive: true, status: 'ACTIVE', sessionDate: dhakaKey(),
        expiresAt: mins(10), targetYear: 3, targetSemester: 1, totalPresentCount: 0,
      });
      await setDoc(doc(db, 'attendanceSessions/s1/private/code'), { code: 'ABC234', prevCode: '', issuedAt: secs(-5) });
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();

  await test('"Classes held": only the course teacher (or admin) writes it; members read it', async () => {
    await reset();
    await assertSucceeds(setDoc(doc(as('t'), 'courseStats/C1'), { heldDates: ['2026-11-01'], updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as('t2'), 'courseStats/C1'), { heldDates: [] }));
    await assertFails(setDoc(doc(as('stu'), 'courseStats/C1'), { heldDates: [] }));
    await assertFails(setDoc(doc(as('t'), 'courseStats/C1'), { heldDates: [], extra: 1 }));
    await assertSucceeds(getDoc(doc(as('stu'), 'courseStats/C1')));
  });

  await test('The full code-mark batch (mark + count + own summary) is allowed', async () => {
    await reset();
    const db = as('stu');
    const b = writeBatch(db);
    b.set(doc(db, 'attendance/s1_stu'), {
      id: 's1_stu', sessionId: 's1', studentId: 'stu', courseId: 'C1', status: 'PRESENT', markedBy: 'SELF',
      codeUsed: 'ABC234', date: dhakaKey(),
    });
    b.update(doc(db, 'attendanceSessions/s1'), { totalPresentCount: increment(1) });
    b.set(doc(db, 'studentStats/stu'), { present: { C1: arrayUnion(dhakaKey()) }, updatedAt: serverTimestamp() }, { merge: true });
    await assertSucceeds(b.commit());
  });

  await test('A teacher changes only their own course in a student\'s summary', async () => {
    await reset();
    await assertSucceeds(setDoc(doc(as('t'), 'studentStats/stu'), { present: { C1: arrayRemove('2026-11-01') }, lastCourseId: 'C1' }, { merge: true }));
    await assertSucceeds(setDoc(doc(as('t'), 'studentStats/mate'), { present: { C1: arrayUnion('2026-11-01') }, lastCourseId: 'C1' }, { merge: true }));
    await assertFails(setDoc(doc(as('t'), 'studentStats/stu'), { present: { C2: [] }, lastCourseId: 'C1' }, { merge: true }));
    await assertFails(setDoc(doc(as('t'), 'studentStats/stu'), { present: { C2: [] }, lastCourseId: 'C2' }, { merge: true }));
    await assertFails(updateDoc(doc(as('t'), 'studentStats/stu'), { complete: false, lastCourseId: 'C1' }));
  });

  await test('Classmates can neither read nor write someone\'s summary', async () => {
    await reset();
    await assertFails(getDoc(doc(as('mate'), 'studentStats/stu')));
    await assertFails(setDoc(doc(as('mate'), 'studentStats/stu'), { present: {} }));
    await assertSucceeds(getDoc(doc(as('t'), 'studentStats/stu')));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} attendance summary rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
