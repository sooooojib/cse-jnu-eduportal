// Security-rule tests for exams and exam notifications, run against the
// local Firestore emulator (never live data).
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, addDoc, deleteDoc, updateDoc, collection } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');

const USERS = {
  cr: { role: 'CR', year: 3, semester: 1, isActive: true },
  otherCr: { role: 'CR', year: 2, semester: 1, isActive: true },
  student: { role: 'STUDENT', year: 3, semester: 1, isActive: true },
  otherStudent: { role: 'STUDENT', year: 2, semester: 1, isActive: true },
  teacher: { role: 'TEACHER', assignedCourseIds: ['CSE-3101'], isActive: true },
  otherTeacher: { role: 'TEACHER', assignedCourseIds: ['CSE-1101'], isActive: true },
  chairman: { role: 'CHAIRMAN', isActive: true },
};

function exam(by, extra = {}) {
  return {
    courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS', title: 'Mid-Term', examDate: '2026-12-10',
    startTime: '10:00 AM', endTime: '12:00 PM', room: 'Room 401', year: 3, semester: 1, type: 'MID_TERM',
    status: 'SCHEDULED', createdBy: by, ...extra,
  };
}

const results = [];
async function test(name, fn) {
  try {
    await fn();
    results.push(['PASS', name]);
  } catch (e) {
    results.push(['FAIL', name, e.message]);
  }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-exams',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const [uid, data] of Object.entries(USERS)) await setDoc(doc(db, `users/${uid}`), data);
      await setDoc(doc(db, 'courses/CSE-3101'), { code: 'CSE-3101', teacherId: 'teacher', year: 3, semester: 1 });
      await setDoc(doc(db, 'exams/mid'), exam('teacher'));
      await setDoc(doc(db, 'exams/final'), exam('teacher', { type: 'FINAL' }));
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();
  const add = (uid, data) => addDoc(collection(as(uid), 'exams'), data);

  await test('CR schedules Mid-Term, CT, Quiz, Lab Exam for their own semester', async () => {
    await reset();
    for (const type of ['MID_TERM', 'CT', 'QUIZ', 'LAB_EXAM']) await assertSucceeds(add('cr', exam('cr', { type })));
  });

  await test('CR cannot schedule a Final', async () => {
    await reset();
    await assertFails(add('cr', exam('cr', { type: 'FINAL' })));
  });

  await test('CR cannot schedule or change another semester', async () => {
    await reset();
    await assertFails(add('otherCr', exam('otherCr')));
    await assertFails(updateDoc(doc(as('otherCr'), 'exams/mid'), { room: 'Room 999' }));
  });

  await test('CR can edit / cancel their semester exam but not the Final', async () => {
    await reset();
    await assertSucceeds(updateDoc(doc(as('cr'), 'exams/mid'), { room: 'Room 402' }));
    await assertSucceeds(updateDoc(doc(as('cr'), 'exams/mid'), { status: 'CANCELLED', statusNote: 'Holiday' }));
    await assertFails(updateDoc(doc(as('cr'), 'exams/final'), { room: 'Room 402' }));
    await assertFails(updateDoc(doc(as('cr'), 'exams/mid'), { type: 'FINAL' }));
  });

  await test('Teacher: own course (incl. Final) yes, others no', async () => {
    await reset();
    await assertSucceeds(add('teacher', exam('teacher', { type: 'FINAL' })));
    await assertFails(add('otherTeacher', exam('otherTeacher')));
    await assertFails(updateDoc(doc(as('otherTeacher'), 'exams/mid'), { room: 'Room 402' }));
  });

  await test('Students cannot schedule or change exams', async () => {
    await reset();
    await assertFails(add('student', exam('student')));
    await assertFails(updateDoc(doc(as('student'), 'exams/mid'), { room: 'Room 402' }));
  });

  await test('Cannot create in someone else\'s name or change the creator', async () => {
    await reset();
    await assertFails(add('cr', exam('teacher')));
    await assertFails(updateDoc(doc(as('cr'), 'exams/mid'), { createdBy: 'cr' }));
  });

  await test('Only Admin / Chairman delete; others cancel instead', async () => {
    await reset();
    await assertFails(deleteDoc(doc(as('cr'), 'exams/mid')));
    await assertFails(deleteDoc(doc(as('teacher'), 'exams/mid')));
    await assertSucceeds(deleteDoc(doc(as('chairman'), 'exams/mid')));
  });

  await test('Bad data is rejected (date format, type, status)', async () => {
    await reset();
    await assertFails(add('teacher', exam('teacher', { examDate: '10/12/2026' })));
    await assertFails(add('teacher', exam('teacher', { type: 'VIVA' })));
    await assertFails(add('teacher', exam('teacher', { status: 'DELETED' })));
  });

  const note = (from, to) => ({
    userId: to, senderId: from, title: 'New Mid-Term', body: 'x', notificationType: 'EXAM_UPDATE', isRead: false,
  });

  await test('CR can notify students of their own semester only', async () => {
    await reset();
    await assertSucceeds(addDoc(collection(as('cr'), 'notifications'), note('cr', 'student')));
    await assertFails(addDoc(collection(as('cr'), 'notifications'), note('cr', 'otherStudent')));
  });

  await test('Teacher can notify; students cannot; sender must be honest', async () => {
    await reset();
    await assertSucceeds(addDoc(collection(as('teacher'), 'notifications'), note('teacher', 'otherStudent')));
    await assertFails(addDoc(collection(as('student'), 'notifications'), note('student', 'otherStudent')));
    await assertFails(addDoc(collection(as('cr'), 'notifications'), note('teacher', 'student')));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} exam rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
