// Security-rule tests for student retake enrollments (local emulator only).
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, deleteDoc } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');

const USERS = {
  s3: { role: 'STUDENT', year: 3, semester: 1 },
  other: { role: 'STUDENT', year: 3, semester: 1 },
  teacher: { role: 'TEACHER' },
  admin: { role: 'ADMIN' },
};
const COURSES = {
  'CSE-2101': { code: 'CSE-2101', year: 2, semester: 1 }, // earlier
  'CSE-2201': { code: 'CSE-2201', year: 2, semester: 2 }, // earlier
  'CSE-3101': { code: 'CSE-3101', year: 3, semester: 1 }, // same semester
  'CSE-4101': { code: 'CSE-4101', year: 4, semester: 1 }, // future
};

const retake = (uid, courseId, extra = {}) => ({
  courseId, studentId: uid, type: 'RETAKE', enrolledOn: '2026-11-26', ...extra,
});

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
    projectId: 'demo-enrollments',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const [uid, data] of Object.entries(USERS)) await setDoc(doc(db, `users/${uid}`), data);
      for (const [id, data] of Object.entries(COURSES)) await setDoc(doc(db, `courses/${id}`), data);
      await setDoc(doc(db, 'enrollments/CSE-2101_other'), { courseId: 'CSE-2101', studentId: 'other', type: 'ADMIN' });
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();
  const enr = (uid, courseId, who = uid) => doc(as(who), `enrollments/${courseId}_${uid}`);

  await test('Student can retake a course from an earlier semester', async () => {
    await reset();
    await assertSucceeds(setDoc(enr('s3', 'CSE-2101'), retake('s3', 'CSE-2101')));
    await assertSucceeds(setDoc(enr('s3', 'CSE-2201'), retake('s3', 'CSE-2201')));
  });

  await test('Same-semester or future-semester retakes are denied', async () => {
    await reset();
    await assertFails(setDoc(enr('s3', 'CSE-3101'), retake('s3', 'CSE-3101')));
    await assertFails(setDoc(enr('s3', 'CSE-4101'), retake('s3', 'CSE-4101')));
  });

  await test('Cannot enroll someone else, use a wrong id, or a non-existent course', async () => {
    await reset();
    await assertFails(setDoc(enr('other', 'CSE-2201', 's3'), retake('other', 'CSE-2201')));
    await assertFails(setDoc(doc(as('s3'), 'enrollments/random'), retake('s3', 'CSE-2101')));
    await assertFails(setDoc(enr('s3', 'NOPE-1'), retake('s3', 'NOPE-1')));
    await assertFails(setDoc(enr('s3', 'CSE-2101'), retake('s3', 'CSE-2101', { type: 'ADMIN' })));
  });

  await test('Teachers cannot self-enroll; admins can create any enrollment', async () => {
    await reset();
    await assertFails(setDoc(enr('teacher', 'CSE-2101'), retake('teacher', 'CSE-2101')));
    await assertSucceeds(setDoc(doc(as('admin'), 'enrollments/CSE-4101_s3'), { courseId: 'CSE-4101', studentId: 's3', type: 'ADMIN' }));
  });

  await test('Student removes only their own RETAKE, never admin enrollments', async () => {
    await reset();
    await assertSucceeds(setDoc(enr('s3', 'CSE-2101'), retake('s3', 'CSE-2101')));
    await assertFails(deleteDoc(doc(as('s3'), 'enrollments/CSE-2101_other')));
    await assertFails(deleteDoc(doc(as('other'), 'enrollments/CSE-2101_other')));
    await assertSucceeds(deleteDoc(enr('s3', 'CSE-2101')));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} enrollment rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
