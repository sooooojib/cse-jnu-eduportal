// Security-rule tests for attendance (rotating code, own semester, late,
// teacher-only edits), run against the local Firestore emulator.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, updateDoc, deleteDoc, Timestamp, serverTimestamp, writeBatch, increment } = require('firebase/firestore');

// S2-10: dates are Bangladesh (UTC+6) calendar dates.
function dhakaKey(offsetDays = 0) {
  const t = new Date(Date.now() + 6 * 3600e3);
  return new Date(Date.UTC(t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate() + offsetDays, 6)).toISOString().slice(0, 10);
}

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');

const USERS = {
  student: { role: 'STUDENT', year: 3, semester: 1 },
  classmate: { role: 'STUDENT', year: 3, semester: 1 },
  other: { role: 'STUDENT', year: 4, semester: 1 }, // a senior (can retake 3-1)
  junior: { role: 'STUDENT', year: 2, semester: 1 },
  teacher: { role: 'TEACHER', assignedCourseIds: ['CSE-3101'] },
  otherTeacher: { role: 'TEACHER', assignedCourseIds: ['CSE-1101'] },
};

const mins = (m) => Timestamp.fromDate(new Date(Date.now() + m * 60000));
const secs = (s) => Timestamp.fromDate(new Date(Date.now() + s * 1000));

function session(extra = {}) {
  return {
    courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS', teacherId: 'teacher', mode: 'CODE',
    isActive: true, status: 'ACTIVE', sessionDate: dhakaKey(), expiresAt: mins(15), lateAfter: mins(10),
    targetYear: 3, targetSemester: 1, totalPresentCount: 0, ...extra,
  };
}

function mark(uid, extra = {}) {
  return {
    id: `s1_${uid}`, sessionId: 's1', studentId: uid, courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS',
    status: 'PRESENT', markedBy: 'SELF', codeUsed: 'ABC234', date: dhakaKey(), ...extra,
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

  await test('Another semester cannot mark, even with the right code, unless explicitly enrolled (retake)', async () => {
    await reset();
    await assertFails(setDoc(markDoc('other'), mark('other')));
    await assertSucceeds(setDoc(doc(as('other'), 'enrollments/CSE-3101_other'), {
      courseId: 'CSE-3101', studentId: 'other', type: 'RETAKE', year: 3, semester: 1,
    }));
    await assertSucceeds(setDoc(markDoc('other'), mark('other')));
    await assertSucceeds(deleteDoc(doc(as('other'), 'enrollments/CSE-3101_other')));
    await assertFails(setDoc(doc(as('other'), 'enrollments/CSE-3101_student'), {
      courseId: 'CSE-3101', studentId: 'student', type: 'RETAKE',
    }));
    // A junior cannot "retake" a course from a later semester, so cannot mark there.
    await assertFails(setDoc(doc(as('junior'), 'enrollments/CSE-3101_junior'), {
      courseId: 'CSE-3101', studentId: 'junior', type: 'RETAKE',
    }));
    await assertFails(setDoc(markDoc('junior'), mark('junior')));
  });

  await test('Self-mark only accepts PRESENT (LATE status is rejected)', async () => {
    await reset({ sess: { lateAfter: mins(-1) } });
    await assertFails(setDoc(markDoc('student'), mark('student', { status: 'LATE' })));
    await assertSucceeds(setDoc(markDoc('student'), mark('student', { status: 'PRESENT' })));
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

  await test('Course teacher marks / corrects PRESENT or ABSENT only; other teachers cannot', async () => {
    await reset();
    const t = mark('student', { markedBy: 'TEACHER', status: 'ABSENT', codeUsed: null });
    await assertSucceeds(setDoc(markDoc('student', 'teacher'), t));
    await assertSucceeds(updateDoc(markDoc('student', 'teacher'), { status: 'PRESENT', markedBy: 'TEACHER' }));
    await assertFails(updateDoc(markDoc('student', 'teacher'), { status: 'LATE', markedBy: 'TEACHER' }));
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

  await test('S2-10: a session is for today in Dhaka (server clock), open for at most ~3 hours', async () => {
    await reset();
    await assertFails(setDoc(doc(as('teacher'), 'attendanceSessions/y'), session({ sessionDate: dhakaKey(-1) })));
    await assertFails(setDoc(doc(as('teacher'), 'attendanceSessions/t'), session({ sessionDate: dhakaKey(1) })));
    await assertFails(setDoc(doc(as('teacher'), 'attendanceSessions/long'), session({ expiresAt: mins(60 * 24) })));
    await assertFails(setDoc(doc(as('teacher'), 'attendanceSessions/past'), session({ expiresAt: mins(-1) })));
    await assertSucceeds(setDoc(doc(as('teacher'), 'attendanceSessions/manual'), session({ mode: 'MANUAL', expiresAt: mins(180) })));
    // Extending: fine, but never more than 4 hours past now.
    await assertSucceeds(updateDoc(doc(as('teacher'), 'attendanceSessions/s1'), { expiresAt: mins(20) }));
    await assertFails(updateDoc(doc(as('teacher'), 'attendanceSessions/s1'), { expiresAt: mins(60 * 5) }));
  });

  await test('S2-10: a mark carries the session\'s own date', async () => {
    await reset();
    await assertFails(setDoc(markDoc('student'), mark('student', { date: dhakaKey(-1) })));
    const t = mark('student', { markedBy: 'TEACHER', status: 'ABSENT', codeUsed: null, date: dhakaKey(-2) });
    await assertFails(setDoc(markDoc('student', 'teacher'), t));
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

  await test('S1-05: a session cannot be moved to another course, semester, day or mode', async () => {
    await reset();
    const t = as('teacher');
    for (const change of [
      { courseId: 'CSE-1101' }, { targetYear: 1 }, { targetSemester: 2 }, { sessionDate: '2026-01-01' }, { mode: 'MANUAL' },
    ]) {
      await assertFails(updateDoc(doc(t, 'attendanceSessions/s1'), change));
    }
    // normal updates still work: extend, count, close
    await assertSucceeds(updateDoc(doc(t, 'attendanceSessions/s1'), { expiresAt: mins(30), totalPresentCount: 3 }));
    await assertSucceeds(updateDoc(doc(t, 'attendanceSessions/s1'), { isActive: false, status: 'COMPLETED' }));
  });

  await test('S1-05: a new session must match its course\'s semester', async () => {
    await reset();
    await assertFails(setDoc(doc(as('teacher'), 'attendanceSessions/s9'), session({ targetYear: 1 })));
    await assertFails(setDoc(doc(as('teacher'), 'attendanceSessions/s9'), session({ courseId: 'NO-SUCH' })));
    await assertSucceeds(setDoc(doc(as('teacher'), 'attendanceSessions/s9'), session()));
  });

  // S2-03: the present count rises with each student's own code mark, so the
  // class counts as held even if the teacher's app was closed.
  const markAndCount = (uid, rec = mark(uid), by = 1) => {
    const db = as(uid);
    const b = writeBatch(db);
    b.set(doc(db, `attendance/s1_${uid}`), rec);
    b.update(doc(db, 'attendanceSessions/s1'), { totalPresentCount: increment(by) });
    return b.commit();
  };

  await test('A code mark raises the present count by 1 (no teacher app needed)', async () => {
    await reset();
    await assertSucceeds(markAndCount('student'));
    await assertSucceeds(markAndCount('classmate'));
    let count;
    await env.withSecurityRulesDisabled(async (ctx) => {
      count = (await getDoc(doc(ctx.firestore(), 'attendanceSessions/s1'))).data().totalPresentCount;
    });
    if (count !== 2) throw new Error(`expected 2, got ${count}`);
  });

  await test('The count can\'t be raised without a valid mark, twice, by more than 1, or with other fields', async () => {
    await reset();
    await assertFails(updateDoc(doc(as('student'), 'attendanceSessions/s1'), { totalPresentCount: increment(1) }));
    await assertFails(markAndCount('student', mark('student', { codeUsed: 'NOPE22' })));
    await assertFails(markAndCount('student', mark('student'), 5));
    await assertSucceeds(markAndCount('student'));
    await assertFails(updateDoc(doc(as('student'), 'attendanceSessions/s1'), { totalPresentCount: increment(1) }));
    const db = as('classmate');
    const b = writeBatch(db);
    b.set(doc(db, 'attendance/s1_classmate'), mark('classmate'));
    b.update(doc(db, 'attendanceSessions/s1'), { totalPresentCount: increment(1), isActive: false });
    await assertFails(b.commit());
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
