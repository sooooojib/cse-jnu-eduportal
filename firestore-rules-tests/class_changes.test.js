// Security-rule tests for one-day class changes and the protected weekly
// routine, run against the local Firestore emulator (never live data).
const fs = require('fs');
const path = require('path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, addDoc, deleteDoc, updateDoc, collection, Timestamp } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');

const USERS = {
  cr: { role: 'CR', year: 3, semester: 1, session: '2021-2022', isActive: true },
  student: { role: 'STUDENT', year: 3, semester: 1, isActive: true },
  otherStudent: { role: 'STUDENT', year: 2, semester: 1, isActive: true },
  teacher: { role: 'TEACHER', assignedCourseIds: ['CSE-3101'], isActive: true },
  otherTeacher: { role: 'TEACHER', assignedCourseIds: ['CSE-1101'], isActive: true },
  admin: { role: 'ADMIN', isActive: true },
};

function daysFromNow(n) {
  // Midday in Bangladesh of that day (06:00 UTC), as the app writes it (S2-10).
  const t = new Date(Date.now() + 6 * 3600e3);
  return new Date(Date.UTC(t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate() + n, 6));
}
function key(d) {
  return d.toISOString().slice(0, 10);
}

function change(by, extra = {}) {
  const d = daysFromNow(2);
  return {
    type: 'EXTRA', date: key(d), dateTs: Timestamp.fromDate(d), dayOfWeek: 'FRIDAY',
    courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'OS', teacherId: 'teacher', teacherName: 'T',
    targetYear: 3, targetSemester: 1, startTime: '01:00 PM', endTime: '02:00 PM', room: 'Room 302',
    createdBy: by, createdByName: by, createdByRole: USERS[by].role, ...extra,
  };
}

const routineSlot = {
  courseId: 'CSE-3101', courseCode: 'CSE-3101', dayOfWeek: 'SUNDAY', startTime: '09:00', endTime: '10:30',
  room: 'Room 302', targetYear: 3, targetSemester: 1, teacherId: 'teacher',
};

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
    projectId: 'demo-class-changes',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
  async function reset() {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const [uid, data] of Object.entries(USERS)) await setDoc(doc(db, `users/${uid}`), data);
      await setDoc(doc(db, 'courses/CSE-3101'), { code: 'CSE-3101', teacherId: 'teacher', year: 3, semester: 1 });
      await setDoc(doc(db, 'courses/CSE-1101'), { code: 'CSE-1101', teacherId: 'otherTeacher', year: 1, semester: 1 });
      await setDoc(doc(db, 'schedules/slotOther'), { ...routineSlot, courseId: 'CSE-1101', targetYear: 1, teacherId: 'otherTeacher' });
      await setDoc(doc(db, 'schedules/routine1'), routineSlot);
      await setDoc(doc(db, 'schedules/oldExtra'), { ...routineSlot, date: '2026-01-01', createdBy: 'cr' });
      await setDoc(doc(db, 'classChanges/existing'), change('cr'));
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();

  await test('CR can add an extra class for their own batch within the week', async () => {
    await reset();
    await assertSucceeds(addDoc(collection(as('cr'), 'classChanges'), change('cr')));
  });

  await test('CR can cancel / move a routine class (with originalSlotId)', async () => {
    await reset();
    await assertSucceeds(addDoc(collection(as('cr'), 'classChanges'), change('cr', { type: 'CANCEL', originalSlotId: 'routine1' })));
    await assertSucceeds(addDoc(collection(as('cr'), 'classChanges'), change('cr', { type: 'MOVE', originalSlotId: 'routine1' })));
  });

  await test('Cancel / move without originalSlotId is rejected', async () => {
    await reset();
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', { type: 'CANCEL' })));
  });

  await test('CR cannot change another batch', async () => {
    await reset();
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', { targetYear: 2 })));
  });

  const on = (n) => { const d = daysFromNow(n); return { date: key(d), dateTs: Timestamp.fromDate(d) }; };

  await test('Changes more than 7 days ahead or 7 days back are rejected', async () => {
    await reset();
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', on(12))));
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', on(-10))));
  });

  await test('S2-10: the date must be the Dhaka date of dateTs', async () => {
    await reset();
    const d = daysFromNow(2);
    const other = daysFromNow(3).toISOString().slice(0, 10);
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', { date: other, dateTs: Timestamp.fromDate(d) })));
  });

  await test('CR can record changes for the past 7 days', async () => {
    await reset();
    await assertSucceeds(addDoc(collection(as('cr'), 'classChanges'), change('cr', { type: 'MOVE', originalSlotId: 'routine1', ...on(-3) })));
  });

  await test('CR can mark a class not taken today or earlier, not in the future', async () => {
    await reset();
    const nt = (n) => change('cr', { type: 'NOT_TAKEN', originalSlotId: 'routine1', ...on(n) });
    await assertSucceeds(addDoc(collection(as('cr'), 'classChanges'), nt(0)));
    await assertSucceeds(addDoc(collection(as('cr'), 'classChanges'), nt(-6)));
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), nt(1)));
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', { type: 'NOT_TAKEN', ...on(-1) })));
  });

  await test('Admin can mark not taken; CR of another batch cannot', async () => {
    await reset();
    await assertSucceeds(addDoc(collection(as('admin'), 'classChanges'), change('admin', { type: 'NOT_TAKEN', originalSlotId: 'routine1', ...on(-1) })));
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', { type: 'NOT_TAKEN', originalSlotId: 'x', targetYear: 2, ...on(-1) })));
  });

  await test('Teacher cannot mark not taken or change past days', async () => {
    await reset();
    await assertFails(addDoc(collection(as('teacher'), 'classChanges'), change('teacher', { type: 'NOT_TAKEN', originalSlotId: 'routine1', ...on(-1) })));
    await assertFails(addDoc(collection(as('teacher'), 'classChanges'), change('teacher', { type: 'CANCEL', originalSlotId: 'routine1', ...on(-2) })));
    await assertSucceeds(addDoc(collection(as('teacher'), 'classChanges'), change('teacher', { type: 'CANCEL', originalSlotId: 'routine1', ...on(0) })));
  });

  await test('Teacher cannot undo a not-taken report made by the CR', async () => {
    await reset();
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'classChanges/nt1'), change('cr', { type: 'NOT_TAKEN', originalSlotId: 'routine1', ...on(-1) }));
    });
    await assertFails(deleteDoc(doc(as('teacher'), 'classChanges/nt1')));
    await assertSucceeds(deleteDoc(doc(as('cr'), 'classChanges/nt1')));
  });

  await test('Regular students cannot make changes', async () => {
    await reset();
    await assertFails(addDoc(collection(as('student'), 'classChanges'), change('student')));
  });

  await test('Teacher can change their own course, not someone else\'s', async () => {
    await reset();
    await assertSucceeds(addDoc(collection(as('teacher'), 'classChanges'), change('teacher')));
    await assertFails(addDoc(collection(as('otherTeacher'), 'classChanges'), change('otherTeacher')));
  });

  await test('Cannot create a change in someone else\'s name', async () => {
    await reset();
    await assertFails(addDoc(collection(as('teacher'), 'classChanges'), change('cr')));
  });

  await test('Changes cannot be edited; only the creator or an admin can undo', async () => {
    await reset();
    await assertFails(updateDoc(doc(as('cr'), 'classChanges/existing'), { room: 'Room 999' }));
    await assertFails(deleteDoc(doc(as('student'), 'classChanges/existing')));
    await assertSucceeds(deleteDoc(doc(as('cr'), 'classChanges/existing')));
    await reset();
    await assertSucceeds(deleteDoc(doc(as('admin'), 'classChanges/existing')));
  });

  await test('CR can no longer edit or delete the weekly routine', async () => {
    await reset();
    await assertFails(updateDoc(doc(as('cr'), 'schedules/routine1'), { room: 'Room 999' }));
    await assertFails(deleteDoc(doc(as('cr'), 'schedules/routine1')));
    await assertFails(setDoc(doc(as('cr'), 'schedules/newSlot'), routineSlot));
  });

  await test('CR can still remove an old one-off class they created', async () => {
    await reset();
    await assertSucceeds(deleteDoc(doc(as('cr'), 'schedules/oldExtra')));
  });

  await test('Teacher edits routine only for their own course; admin for any', async () => {
    await reset();
    await assertSucceeds(updateDoc(doc(as('teacher'), 'schedules/routine1'), { room: 'Room 401' }));
    await assertFails(updateDoc(doc(as('otherTeacher'), 'schedules/routine1'), { room: 'Room 401' }));
    await assertFails(updateDoc(doc(as('teacher'), 'schedules/routine1'), { courseId: 'CSE-1101' }));
    await assertSucceeds(updateDoc(doc(as('admin'), 'schedules/routine1'), { room: 'Room 500' }));
  });

  await test('CR can send SCHEDULE_UPDATE notifications to own semester, not others', async () => {
    await reset();
    await assertSucceeds(addDoc(collection(as('cr'), 'notifications'), {
      userId: 'student', senderId: 'cr', title: 'Class Moved', body: 'Room 401',
      notificationType: 'SCHEDULE_UPDATE', isRead: false, referenceType: 'CLASS_CHANGE', referenceId: 'existing',
    }));
    await assertFails(addDoc(collection(as('cr'), 'notifications'), {
      userId: 'otherStudent', senderId: 'cr', title: 'Class Moved', body: 'Room 401',
      notificationType: 'SCHEDULE_UPDATE', isRead: false, referenceType: 'CLASS_CHANGE', referenceId: 'existing',
    }));
    // a notice must point at a real change made by the sender
    await assertFails(addDoc(collection(as('cr'), 'notifications'), {
      userId: 'student', senderId: 'cr', title: 'Class Moved', body: 'Room 401',
      notificationType: 'SCHEDULE_UPDATE', isRead: false,
    }));
  });

  await test('Only admin can write holidays; any signed-in user can read', async () => {
    await reset();
    await assertFails(setDoc(doc(as('cr'), 'holidays/2026-12-16'), { date: '2026-12-16', title: 'Victory Day' }));
    await assertFails(setDoc(doc(as('teacher'), 'holidays/2026-12-16'), { date: '2026-12-16', title: 'Victory Day' }));
    await assertSucceeds(setDoc(doc(as('admin'), 'holidays/2026-12-16'), { date: '2026-12-16', title: 'Victory Day' }));
    await assertSucceeds(deleteDoc(doc(as('admin'), 'holidays/2026-12-16')));
  });

  await test('S1-04: a CR cannot file "not taken" for another semester\'s course', async () => {
    await reset();
    const d = on(-1);
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', {
      type: 'NOT_TAKEN', courseId: 'CSE-1101', courseCode: 'CSE-1101', teacherId: 'otherTeacher', originalSlotId: 'slotOther', ...d,
    })));
    // ...nor by claiming it is for their own semester
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', {
      type: 'NOT_TAKEN', courseId: 'CSE-1101', courseCode: 'CSE-1101', teacherId: 'otherTeacher', originalSlotId: 'slotOther',
      targetYear: 3, targetSemester: 1, ...d,
    })));
  });

  await test('S1-04: a report must name the course\'s real teacher', async () => {
    await reset();
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', {
      type: 'NOT_TAKEN', teacherId: 'otherTeacher', originalSlotId: 'routine1', ...on(-1),
    })));
    await assertSucceeds(addDoc(collection(as('cr'), 'classChanges'), change('cr', {
      type: 'NOT_TAKEN', teacherId: 'teacher', originalSlotId: 'routine1', ...on(-1),
    })));
  });

  await test('S1-04: cancel / move / not taken must point at a class of that course', async () => {
    await reset();
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', { type: 'CANCEL', originalSlotId: 'slotOther' })));
    await assertFails(addDoc(collection(as('cr'), 'classChanges'), change('cr', { type: 'MOVE', originalSlotId: 'noSuchSlot' })));
    // "not taken" for an extra class of the same course is fine
    await assertSucceeds(addDoc(collection(as('cr'), 'classChanges'), change('cr', {
      type: 'NOT_TAKEN', originalSlotId: 'change_existing', ...on(0),
    })));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} class-change rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
