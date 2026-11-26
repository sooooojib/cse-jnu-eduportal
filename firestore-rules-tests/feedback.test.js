// S1-06: feedback can't be tampered with. Emulator only.
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, writeBatch, collection } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const USERS = {
  student: { role: 'STUDENT', year: 3, semester: 1, isActive: true },
  other: { role: 'STUDENT', year: 3, semester: 1, isActive: true },
  teacher: { role: 'TEACHER', isActive: true },
  admin: { role: 'ADMIN', isActive: true },
};
const fb = (extra = {}) => ({
  studentId: 'student', studentName: 'S', teacherId: 'teacher', teacherName: 'T', courseId: 'CSE-3101',
  rating: 1, comments: 'Bad class today', isAnonymous: false, replies: [], ...extra,
});

const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}

(async () => {
  const env = await initializeTestEnvironment({
    projectId: 'demo-feedback',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const [uid, d] of Object.entries(USERS)) await setDoc(doc(db, `users/${uid}`), d);
      await setDoc(doc(db, 'courses/CSE-3101'), { code: 'CSE-3101', year: 3, semester: 1, teacherId: 'teacher' });
      await setDoc(doc(db, 'feedback/named'), fb());
      await setDoc(doc(db, 'feedback/anon'), fb({ studentId: 'ANONYMOUS', studentName: 'Anonymous Student', isAnonymous: true }));
      await setDoc(doc(db, 'feedbackIdentities/anon'), { feedbackId: 'anon', studentId: 'student' });
      await setDoc(doc(db, 'feedback/orphan'), fb({ studentId: 'ANONYMOUS', isAnonymous: true })); // legacy: no identity
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();

  await test('A student posts named feedback, or anonymous feedback together with its identity', async () => {
    await reset();
    await assertSucceeds(setDoc(doc(as('student'), 'feedback/n2'), fb()));
    const db = as('student');
    const b = writeBatch(db);
    b.set(doc(db, 'feedback/a2'), fb({ studentId: 'ANONYMOUS', isAnonymous: true }));
    b.set(doc(db, 'feedbackIdentities/a2'), { feedbackId: 'a2', studentId: 'student' });
    await assertSucceeds(b.commit());
  });

  await test('Anonymous feedback without its identity record is rejected', async () => {
    await reset();
    await assertFails(setDoc(doc(as('student'), 'feedback/a3'), fb({ studentId: 'ANONYMOUS', isAnonymous: true })));
  });

  await test('Nobody can claim existing anonymous feedback afterwards', async () => {
    await reset();
    await assertFails(setDoc(doc(as('other'), 'feedbackIdentities/orphan'), { feedbackId: 'orphan', studentId: 'other' }));
    await assertFails(updateDoc(doc(as('other'), 'feedback/orphan'), { rating: 5 }));
  });

  await test('The teacher can reply but cannot change the rating or the words', async () => {
    await reset();
    await assertSucceeds(updateDoc(doc(as('teacher'), 'feedback/named'), { replies: [{ id: 'r1', replyText: 'Thanks' }] }));
    await assertFails(updateDoc(doc(as('teacher'), 'feedback/named'), { rating: 5 }));
    await assertFails(updateDoc(doc(as('teacher'), 'feedback/anon'), { comments: 'Great class!' }));
  });

  await test('The author edits rating / words / anonymity, but not who or what it is about', async () => {
    await reset();
    await assertSucceeds(updateDoc(doc(as('student'), 'feedback/named'), { rating: 2, comments: 'Better today' }));
    await assertSucceeds(updateDoc(doc(as('student'), 'feedback/named'), { isAnonymous: true, studentId: 'ANONYMOUS' }));
    await reset();
    await assertFails(updateDoc(doc(as('student'), 'feedback/named'), { teacherId: 'someoneElse' }));
    await assertFails(updateDoc(doc(as('student'), 'feedback/named'), { courseId: 'CSE-1101' }));
    await assertFails(updateDoc(doc(as('student'), 'feedback/named'), { studentId: 'other' }));
    await assertFails(updateDoc(doc(as('student'), 'feedback/named'), { rating: 9 }));
  });

  await test('An anonymous author can edit via their hidden identity; others cannot', async () => {
    await reset();
    await assertSucceeds(updateDoc(doc(as('student'), 'feedback/anon'), { comments: 'Edited anonymously' }));
    await assertFails(updateDoc(doc(as('other'), 'feedback/anon'), { comments: 'Not mine' }));
  });

  await test('Admins can still moderate', async () => {
    await reset();
    await assertSucceeds(updateDoc(doc(as('admin'), 'feedback/named'), { status: 'HIDDEN' }));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} feedback rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
