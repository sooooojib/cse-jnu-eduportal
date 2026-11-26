// S2-01: reassigning a course's teacher hands over control in one batch. Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, writeBatch, arrayRemove, arrayUnion, serverTimestamp, Timestamp } = require('firebase/firestore');

// S2-10: dates are Bangladesh (UTC+6) calendar dates.
function dhakaKey(offsetDays = 0) {
  const t = new Date(Date.now() + 6 * 3600e3);
  return new Date(Date.UTC(t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate() + offsetDays, 6)).toISOString().slice(0, 10);
}

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}
const mins = (m) => Timestamp.fromMillis(Date.now() + m * 60000);
const session = (teacherId) => ({
  courseId: 'C1', courseCode: 'CSE-3101', courseTitle: 'OS', teacherId, mode: 'CODE',
  isActive: true, status: 'ACTIVE', sessionDate: dhakaKey(), expiresAt: mins(15), lateAfter: mins(10),
  targetYear: 3, targetSemester: 1, totalPresentCount: 0,
});

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-assign',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/chairman'), { role: 'CHAIRMAN', isActive: true });
      await setDoc(doc(db, 'users/admin'), { role: 'ADMIN', isActive: true });
      await setDoc(doc(db, 'users/old'), { role: 'TEACHER', isActive: true, assignedCourseIds: ['C1'] });
      await setDoc(doc(db, 'users/new'), { role: 'TEACHER', isActive: true, assignedCourseIds: [] });
      await setDoc(doc(db, 'courses/C1'), { code: 'CSE-3101', year: 3, semester: 1, teacherId: 'old', teacherName: 'Old' });
      await setDoc(doc(db, 'courseAssignments/a1'), { courseId: 'C1', teacherId: 'old' });
      await setDoc(doc(db, 'schedules/w1'), { courseId: 'C1', teacherId: 'old', teacherName: 'Old', dayOfWeek: 'SUNDAY' });
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();

  // The same batch the app writes in assignCourseToTeacher.
  function reassign(db) {
    const b = writeBatch(db);
    b.delete(doc(db, 'courseAssignments/a1'));
    b.update(doc(db, 'users/old'), { assignedCourseIds: arrayRemove('C1'), updatedAt: serverTimestamp() });
    b.set(doc(db, 'courseAssignments/a2'), { courseId: 'C1', teacherId: 'new', teacherName: 'New', isCoordinator: false });
    b.update(doc(db, 'courses/C1'), { teacherId: 'new', teacherName: 'New', updatedAt: serverTimestamp() });
    b.update(doc(db, 'users/new'), { assignedCourseIds: arrayUnion('C1'), updatedAt: serverTimestamp() });
    b.update(doc(db, 'schedules/w1'), { teacherId: 'new', teacherName: 'New', updatedAt: serverTimestamp() }); // S2-02
    return b.commit();
  }

  await test('Before: the old teacher can start attendance, the new one cannot', async () => {
    await reset();
    await assertSucceeds(setDoc(doc(as('old'), 'attendanceSessions/s0'), session('old')));
    await assertFails(setDoc(doc(as('new'), 'attendanceSessions/s1'), session('new')));
  });

  await test('The chairman (and admin) can reassign in one batch', async () => {
    await reset();
    await assertSucceeds(reassign(as('chairman')));
    await reset();
    await assertSucceeds(reassign(as('admin')));
  });

  await test('Teachers cannot reassign courses', async () => {
    await reset();
    await assertFails(reassign(as('new')));
    await assertFails(reassign(as('old')));
  });

  await test('After: the old teacher cannot start attendance, the new one can', async () => {
    await reset();
    await reassign(as('chairman'));
    await assertFails(setDoc(doc(as('old'), 'attendanceSessions/s2'), session('old')));
    await assertSucceeds(setDoc(doc(as('new'), 'attendanceSessions/s3'), session('new')));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} course reassignment rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
