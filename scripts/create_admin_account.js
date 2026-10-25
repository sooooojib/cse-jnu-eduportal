#!/usr/bin/env node

const fs = require('fs');
const os = require('os');
const path = require('path');
const admin = require(path.join(__dirname, '..', 'functions', 'node_modules', 'firebase-admin'));

const PROJECT_ID = 'sajib-73b14';

async function getAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  return config.tokens.access_token;
}

async function setFirestoreDoc(collection, docId, fields, token) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Failed to write ${collection}/${docId}: ${err}`);
  }
}

async function createAdmin(email, password, fullName) {
  const token = await getAccessToken();

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: {
        getAccessToken: async () => ({ access_token: token, expires_in: 3600 }),
      },
      projectId: PROJECT_ID,
    });
  }

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
    console.log(`Found existing user for ${email}: UID = ${userRecord.uid}`);
    await admin.auth().updateUser(userRecord.uid, {
      password: password,
      displayName: fullName,
      emailVerified: true,
      disabled: false,
    });
    console.log(`Updated credentials for existing user: ${email}`);
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: fullName,
        emailVerified: true,
      });
      console.log(`Created new Auth user: ${email} (UID: ${userRecord.uid})`);
    } else {
      throw err;
    }
  }

  // Set custom claims
  await admin.auth().setCustomUserClaims(userRecord.uid, {
    role: 'ADMIN',
  });
  console.log(`Assigned Custom Claim { role: 'ADMIN' } to ${email}`);

  // Create or update Firestore document
  const now = new Date().toISOString();
  const fields = {
    id: { stringValue: userRecord.uid },
    email: { stringValue: email },
    fullName: { stringValue: fullName },
    role: { stringValue: 'ADMIN' },
    isActive: { booleanValue: true },
    department: { stringValue: 'Computer Science & Engineering' },
    university: { stringValue: 'Jagannath University' },
    assignedCourseIds: { arrayValue: { values: [] } },
    fcmTokens: { arrayValue: { values: [] } },
    updatedAt: { timestampValue: now },
  };

  await setFirestoreDoc('users', userRecord.uid, fields, token);
  console.log(`Updated Firestore document /users/${userRecord.uid} with role: 'ADMIN'`);

  return {
    uid: userRecord.uid,
    email: email,
    password: password,
    fullName: fullName,
  };
}

async function main() {
  console.log('==================================================');
  console.log('🔐 PROVISIONING ADMIN ACCOUNT FOR CSE JNU PORTAL');
  console.log('==================================================');

  const admin1 = await createAdmin('admin@cse.jnu.ac.bd', 'AdminPassword2026!', 'Department Administrator');
  const admin2 = await createAdmin('cseadmin@cse.jnu.ac.bd', 'AdminPassword2026!', 'Lead System Admin');

  console.log('\n==================================================');
  console.log('✅ ADMIN ACCOUNTS SUCCESSFULLY CREATED & VERIFIED:');
  console.log('==================================================');
  console.log(`1. Email:    ${admin1.email}`);
  console.log(`   Password: ${admin1.password}`);
  console.log(`   UID:      ${admin1.uid}`);
  console.log('--------------------------------------------------');
  console.log(`2. Email:    ${admin2.email}`);
  console.log(`   Password: ${admin2.password}`);
  console.log(`   UID:      ${admin2.uid}`);
  console.log('==================================================');
}

main().catch(err => {
  console.error('Fatal error provisioning admin account:', err);
  process.exit(1);
});
