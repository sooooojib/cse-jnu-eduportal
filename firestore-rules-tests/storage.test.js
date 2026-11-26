// S1-11: file storage locked down. Emulator only (firestore + storage).
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['PASS', name]); } catch (e) { results.push(['FAIL', name, e.message]); }
}
const BYTES = new Uint8Array([1, 2, 3]);
const PDF = (uid) => ({ contentType: 'application/pdf', customMetadata: { uploadedBy: uid } });
const JPG = (uid) => ({ contentType: 'image/jpeg', customMetadata: { uploadedBy: uid } });

(async () => {
  // Same project as `emulators:exec`, so storage rules can read the Firestore emulator.
  const env = await initializeTestEnvironment({
    projectId: 'demo-rules-tests',
    storage: { rules: RULES, host: '127.0.0.1', port: 9199 },
    firestore: { rules: 'rules_version = "2"; service cloud.firestore { match /{d=**} { allow read, write: if false; } }', host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin'), { role: 'ADMIN', isActive: true });
    await setDoc(doc(db, 'users/chairman'), { role: 'CHAIRMAN', isActive: true });
    await setDoc(doc(db, 'users/teacher'), { role: 'TEACHER', isActive: true });
    await setDoc(doc(db, 'users/otherTeacher'), { role: 'TEACHER', isActive: true });
    await setDoc(doc(db, 'users/student'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
    await setDoc(doc(db, 'users/outsider'), { role: 'STUDENT', year: 3, semester: 1, isActive: true });
    await setDoc(doc(db, 'users/gone'), { role: 'STUDENT', isActive: false });
    await setDoc(doc(db, 'counselingBookings/b1'), { studentId: 'student', teacherId: 'teacher', status: 'APPROVED' });
    await setDoc(doc(db, 'feedback/f1'), { studentId: 'student', teacherId: 'teacher' });
    const st = ctx.storage();
    await st.ref('counseling/b1/seed.pdf').put(BYTES, PDF('student'));
    await st.ref('feedback/draft_1/attachments/a.jpg').put(BYTES, JPG('student'));
    await st.ref('notices/n1/seed.pdf').put(BYTES, PDF('admin'));
  });
  const as = (uid) => env.authenticatedContext(uid).storage();
  const put = (uid, p, meta) => as(uid).ref(p).put(BYTES, meta);
  const read = (uid, p) => as(uid).ref(p).getMetadata();

  await test('Admins and the chairman can upload notice attachments (role read from users record)', async () => {
    await assertSucceeds(put('admin', 'notices/n2/a.pdf', PDF('admin')));
    await assertSucceeds(put('chairman', 'notices/n2/b.pdf', PDF('chairman')));
    await assertFails(put('teacher', 'notices/n2/c.pdf', PDF('teacher')));
    await assertFails(put('student', 'notices/n2/d.pdf', PDF('student')));
  });

  await test('Notice attachments: wrong type, too big or fake uploader are rejected', async () => {
    await assertFails(put('admin', 'notices/n3/x.exe', { contentType: 'application/octet-stream', customMetadata: { uploadedBy: 'admin' } }));
    await assertFails(as('admin').ref('notices/n3/big.pdf').put(new Uint8Array(10 * 1024 * 1024 + 1), PDF('admin')));
    await assertFails(put('admin', 'notices/n3/y.pdf', PDF('someoneElse')));
  });

  await test('Counseling files: only that booking\'s student and teacher (and admins)', async () => {
    await assertSucceeds(read('student', 'counseling/b1/seed.pdf'));
    await assertSucceeds(read('teacher', 'counseling/b1/seed.pdf'));
    await assertSucceeds(read('admin', 'counseling/b1/seed.pdf'));
    await assertFails(read('outsider', 'counseling/b1/seed.pdf'));
    await assertFails(read('otherTeacher', 'counseling/b1/seed.pdf'));
    await assertSucceeds(put('teacher', 'counseling/b1/notes.pdf', PDF('teacher')));
    await assertFails(put('outsider', 'counseling/b1/x.pdf', PDF('outsider')));
    await assertFails(put('outsider', 'counseling/outsider/x.pdf', PDF('outsider')));
    await assertFails(put('student', 'counseling/nobooking/x.pdf', PDF('student')));
  });

  await test('Student feedback files: only the uploader (and admins) can read them by path', async () => {
    await assertSucceeds(put('student', 'feedback/draft_2/attachments/b.jpg', JPG('student')));
    await assertSucceeds(read('student', 'feedback/draft_1/attachments/a.jpg'));
    await assertFails(read('outsider', 'feedback/draft_1/attachments/a.jpg'));
    await assertFails(read('teacher', 'feedback/draft_1/attachments/a.jpg'));
    await assertFails(put('teacher', 'feedback/draft_3/attachments/c.jpg', JPG('teacher')));
  });

  await test('Reply files: only the teacher the feedback is about', async () => {
    await assertSucceeds(put('teacher', 'feedback/f1/replies/r.jpg', JPG('teacher')));
    await assertFails(put('otherTeacher', 'feedback/f1/replies/r2.jpg', JPG('otherTeacher')));
    await assertSucceeds(read('student', 'feedback/f1/replies/r.jpg'));
    await assertFails(read('outsider', 'feedback/f1/replies/r.jpg'));
  });

  await test('Profile photos: own folder, images only; deactivated / unapproved users are out', async () => {
    await assertSucceeds(put('student', 'avatars/student/me.jpg', JPG('student')));
    await assertFails(put('student', 'avatars/outsider/me.jpg', JPG('student')));
    await assertFails(put('student', 'avatars/student/me.pdf', PDF('student')));
    await assertFails(put('gone', 'avatars/gone/me.jpg', JPG('gone')));
    await assertFails(put('pending', 'avatars/pending/me.jpg', JPG('pending')));
    await assertFails(read('gone', 'notices/n1/seed.pdf'));
    await assertSucceeds(read('student', 'notices/n1/seed.pdf'));
  });

  await test('Unknown folders are closed', async () => {
    await assertFails(put('admin', 'random/x.pdf', PDF('admin')));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} storage rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
