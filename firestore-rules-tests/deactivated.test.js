// S1-02: deactivated accounts lose all powers. Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, addDoc, collection, writeBatch, Timestamp, serverTimestamp } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const day = (n) => { const d = new Date(); d.setDate(d.getDate() + n); d.setHours(12, 0, 0, 0); return d; };
const key = (d) => d.toISOString().slice(0, 10);

const ACTIVE = {
  teacher: { role: 'TEACHER', assignedCourseIds: ['CSE-3101'], isActive: true },
  cr: { role: 'CR', year: 3, semester: 1, session: '2021-2022', isActive: true },
  student: { role: 'STUDENT', year: 3, semester: 1, session: '2021-2022', isActive: true },
  chairman: { role: 'CHAIRMAN', isActive: true },
};

const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-deactivated',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset(inactive = []) {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const [uid, d] of Object.entries(ACTIVE)) {
        await setDoc(doc(db, `users/${uid}`), { ...d, isActive: !inactive.includes(uid) });
      }
      await setDoc(doc(db, 'courses/CSE-3101'), { code: 'CSE-3101', teacherId: 'teacher', year: 3, semester: 1 });
      await setDoc(doc(db, 'counselingBookings/b1'), { studentId: 'student', teacherId: 'teacher', status: 'PENDING' });
      await setDoc(doc(db, 'signupRequests/newbie'), {
        userId: 'newbie', email: 'n@x.bd', fullName: 'N', role: 'STUDENT', session: '2023-2024', status: 'PENDING',
      });
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();
  const exam = (by) => ({
    courseId: 'CSE-3101', courseCode: 'CSE-3101', title: 'CT', examDate: '2026-12-10', startTime: '10:00 AM',
    endTime: '11:00 AM', room: 'R', year: 3, semester: 1, type: 'CT', status: 'SCHEDULED', createdBy: by,
  });
  const change = (by) => ({
    type: 'EXTRA', date: key(day(2)), dateTs: Timestamp.fromDate(day(2)), dayOfWeek: 'FRIDAY', courseId: 'CSE-3101', teacherId: 'teacher',
    targetYear: 3, targetSemester: 1, startTime: '01:00 PM', endTime: '02:00 PM', room: 'R', createdBy: by,
  });

  await test('Active accounts still work (control)', async () => {
    await reset();
    await assertSucceeds(addDoc(collection(as('teacher'), 'exams'), exam('teacher')));
    await assertSucceeds(addDoc(collection(as('cr'), 'classChanges'), change('cr')));
    await assertSucceeds(updateDoc(doc(as('student'), 'users/student'), { fullName: 'New Name' }));
  });

  await test('A deactivated teacher can no longer schedule exams, change classes or approve signups', async () => {
    await reset(['teacher']);
    await assertFails(addDoc(collection(as('teacher'), 'exams'), exam('teacher')));
    await assertFails(addDoc(collection(as('teacher'), 'classChanges'), change('teacher')));
    const tdb = as('teacher');
    const b = writeBatch(tdb);
    b.set(doc(tdb, 'users/newbie'), { email: 'n@x.bd', role: 'STUDENT', year: 1, semester: 1, session: '2023-2024', isActive: true });
    b.update(doc(tdb, 'signupRequests/newbie'), { status: 'APPROVED', assignedYear: 1, assignedSemester: 1, createdUserId: 'newbie', reviewedBy: 'teacher' });
    await assertFails(b.commit());
    await assertFails(updateDoc(doc(as('teacher'), 'counselingBookings/b1'), { status: 'APPROVED' }));
  });

  await test('A deactivated CR can no longer change classes or hand over the CR role', async () => {
    await reset(['cr']);
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr')));
    await assertFails(setDoc(doc(as('cr'), 'crTransfers/cr'), { fromUid: 'cr', toUid: 'student', status: 'PENDING' }));
  });

  await test('A deactivated student can no longer edit their profile, cancel bookings or request a semester change', async () => {
    await reset(['student']);
    await assertFails(updateDoc(doc(as('student'), 'users/student'), { fullName: 'New Name' }));
    await assertFails(updateDoc(doc(as('student'), 'counselingBookings/b1'), { status: 'CANCELLED' }));
    await assertFails(addDoc(collection(as('student'), 'semesterUpgradeRequests'), {
      studentId: 'student', requestedYear: 3, requestedSemester: 2, status: 'PENDING',
    }));
  });

  await test('A deactivated Chairman loses admin powers', async () => {
    await reset(['chairman']);
    await assertFails(setDoc(doc(as('chairman'), 'holidays/2026-12-16'), { date: '2026-12-16', title: 'Victory Day' }));
    await assertFails(updateDoc(doc(as('chairman'), 'users/student'), { year: 4 }));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} deactivated-account rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
