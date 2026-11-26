// Security-rule tests for the CR hand-over flow, run against the local
// Firestore emulator with the project's real firestore.rules.
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, setDoc, updateDoc, writeBatch, serverTimestamp, collection, query, where } = require('firebase/firestore');

const RULES = fs.readFileSync(path.resolve(process.argv[2]), 'utf8');

const base = { year: 3, semester: 1, session: '2021-2022', isActive: true };
const USERS = {
  cr: { ...base, role: 'CR', fullName: 'Old CR' },
  alice: { ...base, role: 'STUDENT', fullName: 'Alice' },
  bob: { ...base, role: 'STUDENT', fullName: 'Bob' },
  otherSession: { ...base, session: '2022-2023', role: 'STUDENT', fullName: 'Other Session' },
  otherSemester: { ...base, semester: 2, role: 'STUDENT', fullName: 'Other Semester' },
};

function transfer(to, extra = {}) {
  return {
    fromUid: 'cr', fromName: 'Old CR', toUid: to, toName: to,
    year: 3, semester: 1, session: '2021-2022', status: 'PENDING',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra,
  };
}

function acceptBatch(db, { demoteOld = true, promoteSelf = true, me = 'alice' } = {}) {
  const b = writeBatch(db);
  b.update(doc(db, 'crTransfers/cr'), { status: 'ACCEPTED', respondedAt: serverTimestamp(), updatedAt: serverTimestamp() });
  if (promoteSelf) b.update(doc(db, `users/${me}`), { role: 'CR', isCR: true, crTransferRef: 'cr', updatedAt: serverTimestamp() });
  if (demoteOld) b.update(doc(db, 'users/cr'), { role: 'STUDENT', isCR: false, crTransferRef: 'cr', updatedAt: serverTimestamp() });
  return b.commit();
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
    projectId: 'demo-cr-transfer',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });

  async function reset(extraTransfer) {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const [uid, data] of Object.entries(USERS)) await setDoc(doc(db, `users/${uid}`), data);
      if (extraTransfer) await setDoc(doc(db, 'crTransfers/cr'), extraTransfer);
    });
  }
  const as = (uid) => env.authenticatedContext(uid).firestore();

  await test('CR can offer the role to a classmate (same semester + session), with notification', async () => {
    await reset();
    const db = as('cr');
    const b = writeBatch(db);
    b.set(doc(db, 'crTransfers/cr'), transfer('alice'));
    b.set(doc(db, 'notifications/n1'), { userId: 'alice', notificationType: 'CR_TRANSFER', isRead: false, title: 't', body: 'b' });
    await assertSucceeds(b.commit());
  });

  await test('CR cannot offer to a different session', async () => {
    await reset();
    await assertFails(setDoc(doc(as('cr'), 'crTransfers/cr'), transfer('otherSession')));
  });

  await test('CR cannot offer to a different semester', async () => {
    await reset();
    await assertFails(setDoc(doc(as('cr'), 'crTransfers/cr'), transfer('otherSemester')));
  });

  await test('A regular student cannot create a transfer', async () => {
    await reset();
    await assertFails(setDoc(doc(as('alice'), 'crTransfers/alice'), { ...transfer('bob'), fromUid: 'alice' }));
  });

  await test('Cannot create a transfer in someone else\'s name', async () => {
    await reset();
    await assertFails(setDoc(doc(as('alice'), 'crTransfers/cr'), transfer('alice')));
  });

  await test('Student cannot make themself CR without a transfer', async () => {
    await reset();
    await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { role: 'CR', isCR: true, crTransferRef: 'cr' }));
  });

  await test('Student cannot make themself CR while the transfer is still PENDING (no accept)', async () => {
    await reset(transfer('alice'));
    await assertFails(updateDoc(doc(as('alice'), 'users/alice'), { role: 'CR', isCR: true, crTransferRef: 'cr' }));
  });

  await test('Invited classmate accepts: one batch swaps roles', async () => {
    await reset(transfer('alice'));
    await assertSucceeds(acceptBatch(as('alice')));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      assert.strictEqual((await getDoc(doc(db, 'users/alice'))).data().role, 'CR');
      assert.strictEqual((await getDoc(doc(db, 'users/cr'))).data().role, 'STUDENT');
      assert.strictEqual((await getDoc(doc(db, 'crTransfers/cr'))).data().status, 'ACCEPTED');
    });
  });

  await test('Accepting without demoting the old CR is rejected', async () => {
    await reset(transfer('alice'));
    await assertFails(acceptBatch(as('alice'), { demoteOld: false }));
  });

  await test('Accepting without becoming CR is rejected', async () => {
    await reset(transfer('alice'));
    await assertFails(acceptBatch(as('alice'), { promoteSelf: false }));
  });

  await test('A different classmate cannot accept someone else\'s offer', async () => {
    await reset(transfer('alice'));
    await assertFails(acceptBatch(as('bob'), { me: 'bob' }));
  });

  await test('Cannot demote the CR outside an accept batch', async () => {
    await reset(transfer('alice'));
    await assertFails(updateDoc(doc(as('alice'), 'users/cr'), { role: 'STUDENT', isCR: false, crTransferRef: 'cr' }));
  });

  await test('Accepted transfer cannot be replayed to promote again', async () => {
    await reset(transfer('alice', { status: 'ACCEPTED' }));
    await assertFails(updateDoc(doc(as('bob'), 'users/bob'), { role: 'CR', isCR: true, crTransferRef: 'cr' }));
  });

  await test('Invited classmate can decline; CR can cancel', async () => {
    await reset(transfer('alice'));
    await assertSucceeds(updateDoc(doc(as('alice'), 'crTransfers/cr'), { status: 'DECLINED', respondedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
    await reset(transfer('alice'));
    await assertSucceeds(updateDoc(doc(as('cr'), 'crTransfers/cr'), { status: 'CANCELLED', updatedAt: serverTimestamp() }));
  });

  await test('After a decline, accepting is rejected', async () => {
    await reset(transfer('alice', { status: 'DECLINED' }));
    await assertFails(acceptBatch(as('alice')));
  });

  await test('Outsiders cannot read a transfer; the two people can', async () => {
    await reset(transfer('alice'));
    await assertFails(getDoc(doc(as('bob'), 'crTransfers/cr')));
    await assertSucceeds(getDoc(doc(as('alice'), 'crTransfers/cr')));
    await assertSucceeds(getDoc(doc(as('cr'), 'crTransfers/cr')));
  });

  await test('CR can watch their own (not yet existing) transfer doc', async () => {
    await reset();
    await assertSucceeds(getDoc(doc(as('cr'), 'crTransfers/cr')));
  });

  await test('CR_TRANSFER notification to an unrelated user is rejected', async () => {
    await reset(transfer('alice'));
    await assertFails(setDoc(doc(as('cr'), 'notifications/n2'), { userId: 'bob', notificationType: 'CR_TRANSFER', isRead: false }));
  });

  await test('Invited student can query their pending offers; others get nothing they should not', async () => {
    await reset(transfer('alice'));
    const q = (db, uid) => getDocs(query(collection(db, 'crTransfers'), where('toUid', '==', uid), where('status', '==', 'PENDING')));
    const snap = await assertSucceeds(q(as('alice'), 'alice'));
    assert.strictEqual(snap.size, 1);
    await assertFails(q(as('bob'), 'alice'));
  });

  await env.cleanup();
  for (const r of results) console.log(r.join(' | '));
  const failed = results.filter((r) => r[0] === 'FAIL').length;
  console.log(`\n${results.length - failed}/${results.length} rule tests passed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
