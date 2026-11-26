// S1-10: only real members book counseling / post feedback. Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-s110',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/student'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
    await setDoc(doc(db, 'users/junior'), { role: 'STUDENT', year: 1, semester: 1, isActive: true });
    await setDoc(doc(db, 'users/senior'), { role: 'STUDENT', year: 4, semester: 1, isActive: true });
    await setDoc(doc(db, 'users/teacher'), { role: 'TEACHER', isActive: true });
    await setDoc(doc(db, 'users/otherTeacher'), { role: 'TEACHER', isActive: true });
    await setDoc(doc(db, 'courses/CSE-3101'), { code: 'CSE-3101', year: 3, semester: 1, teacherId: 'teacher' });
    await setDoc(doc(db, 'enrollments/CSE-3101_senior'), { courseId: 'CSE-3101', studentId: 'senior', type: 'RETAKE' });
    await setDoc(doc(db, 'counselingSlots/slot1'), { teacherId: 'teacher', isBooked: false, status: 'AVAILABLE' });
    // 'pending' signed up but was never approved: no users record.
  });
  const as = (uid) => env.authenticatedContext(uid).firestore();
  const booking = (uid, extra = {}) => ({ studentId: uid, teacherId: 'teacher', slotId: 'slot1', status: 'PENDING', ...extra });
  const fb = (uid, extra = {}) => ({
    studentId: uid, teacherId: 'teacher', courseId: 'CSE-3101', rating: 1, comments: 'Bad class today',
    isAnonymous: false, replies: [], ...extra,
  });

  await test('Any approved student can book any teacher (no semester limit)', async () => {
    await assertSucceeds(setDoc(doc(as('student'), 'counselingBookings/b1'), booking('student')));
    await assertSucceeds(setDoc(doc(as('junior'), 'counselingBookings/b2'), booking('junior')));
  });

  await test('A pending (unapproved) login cannot book', async () => {
    await assertFails(setDoc(doc(as('pending'), 'counselingBookings/b3'), booking('pending')));
  });

  await test('A booking must use a real slot and that slot\'s teacher', async () => {
    await assertFails(setDoc(doc(as('student'), 'counselingBookings/b4'), booking('student', { teacherId: 'otherTeacher' })));
    await assertFails(setDoc(doc(as('student'), 'counselingBookings/b5'), booking('student', { slotId: 'nope' })));
    await assertFails(setDoc(doc(as('student'), 'counselingBookings/b6'), booking('student', { slotId: '' })));
    await assertFails(setDoc(doc(as('teacher'), 'counselingBookings/b7'), booking('teacher')));
  });

  await test('Course feedback: own semester or a retake student only', async () => {
    await assertSucceeds(setDoc(doc(as('student'), 'feedback/f1'), fb('student')));
    await assertSucceeds(setDoc(doc(as('senior'), 'feedback/f2'), fb('senior')));
    await assertFails(setDoc(doc(as('junior'), 'feedback/f3'), fb('junior')));
  });

  await test('Course feedback must name the course\'s teacher', async () => {
    await assertFails(setDoc(doc(as('student'), 'feedback/f4'), fb('student', { teacherId: 'otherTeacher' })));
  });

  await test('General feedback about any real teacher is allowed; a fake teacher is not', async () => {
    const { courseId, ...general } = fb('junior');
    await assertSucceeds(setDoc(doc(as('junior'), 'feedback/f5'), general));
    await assertFails(setDoc(doc(as('junior'), 'feedback/f6'), { ...general, teacherId: 'student' }));
    await assertFails(setDoc(doc(as('junior'), 'feedback/f7'), { ...general, teacherId: 'ghost' }));
  });

  await test('A pending (unapproved) login cannot post feedback', async () => {
    const { courseId, ...general } = fb('pending');
    await assertFails(setDoc(doc(as('pending'), 'feedback/f8'), general));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} counseling / feedback access rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
