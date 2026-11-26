// S1-01: members-only data. Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, collection, query, where } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');

const USERS = {
  student: { role: 'STUDENT', year: 3, semester: 1, session: '2021-2022', isActive: true, email: 's@x.bd', phone: '017' },
  classmate: { role: 'STUDENT', year: 3, semester: 1, session: '2021-2022', isActive: true, email: 'c@x.bd' },
  junior: { role: 'STUDENT', year: 1, semester: 1, session: '2024-2025', isActive: true, email: 'j@x.bd' },
  cr: { role: 'CR', year: 3, semester: 1, session: '2021-2022', isActive: true },
  teacher: { role: 'TEACHER', isActive: true, assignedCourseIds: ['CSE-3101'], fullName: 'T' },
  chairman: { role: 'CHAIRMAN', isActive: true },
  gone: { role: 'STUDENT', year: 3, semester: 1, isActive: false },
};

const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-members',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, d] of Object.entries(USERS)) await setDoc(doc(db, `users/${uid}`), d);
    await setDoc(doc(db, 'courses/CSE-3101'), { code: 'CSE-3101', teacherId: 'teacher', year: 3, semester: 1 });
    await setDoc(doc(db, 'schedules/s1'), { courseId: 'CSE-3101', dayOfWeek: 'SUNDAY' });
    await setDoc(doc(db, 'attendance/sess_student'), { studentId: 'student', courseId: 'CSE-3101', status: 'PRESENT' });
    await setDoc(doc(db, 'attendance/sess_classmate'), { studentId: 'classmate', courseId: 'CSE-3101', status: 'ABSENT' });
    await setDoc(doc(db, 'counselingBookings/b1'), { studentId: 'student', teacherId: 'teacher', slotId: 'slot1', status: 'PENDING', reason: 'private' });
    await setDoc(doc(db, 'signupRequests/pending'), { userId: 'pending', email: 'p@x.bd', fullName: 'P', role: 'STUDENT', status: 'PENDING' });
  });
  const as = (uid) => env.authenticatedContext(uid).firestore();

  await test('A pending signup (no record) reads nothing but its own request and own (missing) profile', async () => {
    const db = as('pending');
    await assertSucceeds(getDoc(doc(db, 'users/pending')));
    await assertSucceeds(getDoc(doc(db, 'signupRequests/pending')));
    await assertFails(getDoc(doc(db, 'users/student')));
    await assertFails(getDocs(query(collection(db, 'users'), where('role', 'in', ['TEACHER', 'CHAIRMAN']))));
    await assertFails(getDoc(doc(db, 'attendance/sess_student')));
    await assertFails(getDoc(doc(db, 'counselingBookings/b1')));
    await assertFails(getDoc(doc(db, 'courses/CSE-3101')));
    await assertFails(getDoc(doc(db, 'schedules/s1')));
  });

  await test('A deactivated account reads nothing (except its own profile)', async () => {
    const db = as('gone');
    await assertSucceeds(getDoc(doc(db, 'users/gone')));
    await assertFails(getDoc(doc(db, 'courses/CSE-3101')));
    await assertFails(getDoc(doc(db, 'users/classmate')));
  });

  await test('A student reads only their own attendance', async () => {
    const db = as('student');
    await assertSucceeds(getDoc(doc(db, 'attendance/sess_student')));
    await assertSucceeds(getDocs(query(collection(db, 'attendance'), where('studentId', '==', 'student'))));
    await assertFails(getDoc(doc(db, 'attendance/sess_classmate')));
    await assertFails(getDocs(query(collection(db, 'attendance'), where('courseId', '==', 'CSE-3101'))));
  });

  await test('A student sees teacher profiles and their own batch, not other students', async () => {
    const db = as('student');
    await assertSucceeds(getDoc(doc(db, 'users/teacher')));
    await assertSucceeds(getDoc(doc(db, 'users/classmate')));
    await assertFails(getDoc(doc(db, 'users/junior')));
    await assertFails(getDocs(collection(db, 'users')));
    await assertSucceeds(getDocs(query(collection(db, 'users'), where('role', 'in', ['TEACHER', 'CHAIRMAN']))));
    await assertSucceeds(getDocs(query(collection(db, 'users'),
      where('year', '==', 3), where('semester', '==', 1), where('session', '==', '2021-2022'))));
    await assertFails(getDocs(query(collection(db, 'users'), where('year', '==', 1), where('semester', '==', 1))));
  });

  await test('A CR can list their own semester for notifications', async () => {
    await assertSucceeds(getDocs(query(collection(as('cr'), 'users'), where('year', '==', 3), where('semester', '==', 1))));
  });

  await test('Teachers and the Chairman read all users and course attendance', async () => {
    await assertSucceeds(getDoc(doc(as('teacher'), 'users/junior')));
    await assertSucceeds(getDocs(query(collection(as('teacher'), 'attendance'), where('courseId', '==', 'CSE-3101'))));
    await assertSucceeds(getDocs(collection(as('chairman'), 'users')));
  });

  await test('Counseling bookings: only the student, the teacher or admins', async () => {
    await assertSucceeds(getDoc(doc(as('student'), 'counselingBookings/b1')));
    await assertSucceeds(getDoc(doc(as('teacher'), 'counselingBookings/b1')));
    await assertSucceeds(getDoc(doc(as('chairman'), 'counselingBookings/b1')));
    await assertFails(getDoc(doc(as('classmate'), 'counselingBookings/b1')));
    await assertSucceeds(getDocs(query(collection(as('student'), 'counselingBookings'), where('studentId', '==', 'student'))));
    await assertSucceeds(getDocs(query(collection(as('teacher'), 'counselingBookings'),
      where('teacherId', '==', 'teacher'), where('slotId', '==', 'slot1'), where('status', '==', 'PENDING'))));
    await assertFails(getDocs(query(collection(as('classmate'), 'counselingBookings'), where('slotId', '==', 'slot1'))));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} members-only rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
