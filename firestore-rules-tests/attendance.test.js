// Security-rule tests for attendance (rotating code, own semester, late,
// teacher-only edits), run against the local Firestore emulator.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, deleteDoc, Timestamp, serverTimestamp } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');

const USERS = {
  student: { role: 'STUDENT', year: 3, semester: 1 },
  other: { role: 'STUDENT', year: 2, semester: 1 },
  teacher: { role: 'TEACHER', assignedCourseIds: ['CSE-3101'] },
  otherTeacher: { role: 'TEACHER', assignedCourseIds: ['CSE-1101'] },
};

const mins = (m) => Timestamp.fromDate(new Date(Date.now() + m * 60000));
const secs = (s) => Timestamp.fromDate(new Date(Date.now() + s * 1000));

function session(extra = {}) {
  return {
    courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS', teacherId: 'teacher', mode: 'CODE',
    isActive: true, status: 'ACTIVE', sessionDate: '2026-11-26', expiresAt: mins(15), lateAfter: mins(10),
    targetYear: 3, targetSemester: 1, totalPresentCount: 0, ...extra,
  };
}

function mark(uid, extra = {}) {
  return {
    id: `s1_${uid}`, sessionId: 's1', studentId: uid, courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS',
    status: 'PRESENT', markedBy: 'SELF', codeUsed: 'ABC234', date: '2026-11-26', ...extra,
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
    projectId: 'demo-attendance',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset({ sess = {}, code = {} } = {}) {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const [uid, data] of Object.entries(USERS)) await setDoc(doc(db, `users/${uid}`), data);
      await setDoc(doc(db, 'courses/CSE-3101'), { code: 'CSE-3101', teacherId: 'teacher', year: 3, semester: 1 });
      await setDoc(doc(db, 'attendanceSessions/s1'), session(sess));
      await setDoc(doc(db, 'attendanceSessions/s1/private/code'), { code: 'ABC234', prevCode: 'XYZ789', issuedAt: secs(-5), ...code });
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();
  const markDoc = (uid, who = uid) => doc(as(who), `attendance/s1_${uid}`);

  await test('Student marks present with the current or previous code', async () => {
    await reset();
    await assertSucceeds(setDoc(markDoc('student'), mark('student')));
    await reset();
    await assertSucceeds(setDoc(markDoc('student'), mark('student', { codeUsed: 'XYZ789' })));
  });

  await test('Wrong code, or a code from a screen that stopped rotating, is rejected', async () => {
    await reset();
    await assertFails(setDoc(markDoc('student'), mark('student', { codeUsed: 'NOPE22' })));
    await reset({ code: { issuedAt: secs(-120) } });
    await assertFails(setDoc(markDoc('student'), mark('student')));
  });

  await test('Students cannot read the code', async () => {
    await reset();
    await assertFails(getDoc(doc(as('student'), 'attendanceSessions/s1/private/code')));
    await assertSucceeds(getDoc(doc(as('teacher'), 'attendanceSessions/s1/private/code')));
  });

  await test('Another semester cannot mark, even with the right code', async () => {
    await reset();
    await assertFails(setDoc(markDoc('other'), mark('other')));
  });

  await test('After lateAfter a self-mark must be LATE', async () => {
    await reset({ sess: { lateAfter: mins(-1) } });
    await assertFails(setDoc(markDoc('student'), mark('student')));
    await assertSucceeds(setDoc(markDoc('student'), mark('student', { status: 'LATE' })));
  });

  await test('Closed, expired or manual sessions take no self-marks', async () => {
    await reset({ sess: { isActive: false } });
    await assertFails(setDoc(markDoc('student'), mark('student')));
    await reset({ sess: { expiresAt: mins(-1) } });
    await assertFails(setDoc(markDoc('student'), mark('student')));
    await reset({ sess: { mode: 'MANUAL' } });
    await assertFails(setDoc(markDoc('student'), mark('student')));
  });

  await test('Students cannot mark for someone else or change a record', async () => {
    await reset();
    await assertFails(setDoc(markDoc('other', 'student'), mark('other')));
    await assertSucceeds(setDoc(markDoc('student'), mark('student')));
    await assertFails(updateDoc(markDoc('student'), { status: 'PRESENT', markedBy: 'TEACHER' }));
    await assertFails(deleteDoc(markDoc('student')));
  });

  await test('Course teacher marks / corrects; other teachers cannot', async () => {
    await reset();
    const t = mark('student', { markedBy: 'TEACHER', status: 'ABSENT', codeUsed: null });
    await assertSucceeds(setDoc(markDoc('student', 'teacher'), t));
    await assertSucceeds(updateDoc(markDoc('student', 'teacher'), { status: 'LATE', markedBy: 'TEACHER' }));
    await assertFails(updateDoc(markDoc('student', 'otherTeacher'), { status: 'PRESENT', markedBy: 'TEACHER' }));
    await assertFails(setDoc(markDoc('other', 'otherTeacher'), mark('other', { markedBy: 'TEACHER' })));
  });

  await test('Sessions: only for own course, never with a public code', async () => {
    await reset();
    await assertSucceeds(setDoc(doc(as('teacher'), 'attendanceSessions/s2'), session()));
    await assertFails(setDoc(doc(as('teacher'), 'attendanceSessions/s3'), session({ code: 'ABC234' })));
    await assertFails(setDoc(doc(as('otherTeacher'), 'attendanceSessions/s4'), session({ teacherId: 'otherTeacher' })));
    await assertFails(setDoc(doc(as('student'), 'attendanceSessions/s5'), session({ teacherId: 'student' })));
  });

  await test('Only the session teacher closes it / rotates the code', async () => {
    await reset();
    await assertSucceeds(updateDoc(doc(as('teacher'), 'attendanceSessions/s1'), { isActive: false }));
    await reset();
    await assertFails(updateDoc(doc(as('student'), 'attendanceSessions/s1'), { totalPresentCount: 1 }));
    await assertFails(updateDoc(doc(as('otherTeacher'), 'attendanceSessions/s1'), { isActive: false }));
    await assertSucceeds(setDoc(doc(as('teacher'), 'attendanceSessions/s1/private/code'), { code: 'NEW234', prevCode: 'ABC234', issuedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as('student'), 'attendanceSessions/s1/private/code'), { code: 'MINE22', issuedAt: serverTimestamp() }));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} attendance rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
