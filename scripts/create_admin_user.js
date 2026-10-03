#!/usr/bin/env node

/**
 * Script to create or update an Admin user in Firebase Auth and Cloud Firestore.
 * 
 * Usage:
 *   node scripts/create_admin_user.js [email] [password] [fullName]
 * 
 * Default:
 *   email:    admin@cse.jnu.ac.bd
 *   password: Admin123456!
 *   fullName: Department Administrator
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const email = process.argv[2] || 'admin@cse.jnu.ac.bd';
const password = process.argv[3] || 'Admin123456!';
const fullName = process.argv[4] || 'Department Administrator';

const PROJECT_ID = 'sajib-73b14';

async function getAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(configPath)) {
    throw new Error('Firebase CLI configuration not found at ' + configPath + '. Please run "firebase login" first.');
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  if (!config.tokens || !config.tokens.access_token) {
    throw new Error('No access token found in firebase-tools.json. Please run "firebase login --reauth".');
  }

  return config.tokens.access_token;
}

async function createOrUpdateAdmin() {
  console.log('🔐 Provisioning Demo Admin Account for CSE JnU EduPortal...');
  console.log(`   Email:     ${email}`);
  console.log(`   Password:  ${password}`);
  console.log(`   Full Name: ${fullName}`);
  console.log(`   Role:      ADMIN\n`);

  const token = await getAccessToken();

  // 1. Check if user already exists in Firebase Auth
  console.log('1️⃣ Looking up user in Firebase Authentication...');
  const lookupRes = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:lookup`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ email: [email] }),
  });

  let uid = null;
  if (lookupRes.ok) {
    const lookupData = await lookupRes.json();
    if (lookupData.users && lookupData.users.length > 0) {
      uid = lookupData.users[0].localId;
      console.log(`   ✓ Found existing Auth user with UID: ${uid}`);
    }
  }

  // 2. Create or Update user in Auth
  if (!uid) {
    console.log('2️⃣ Creating new Firebase Auth user...');
    const createRes = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: email,
        password: password,
        displayName: fullName,
        emailVerified: true,
      }),
    });

    const createData = await createRes.json();
    if (!createRes.ok) {
      throw new Error(`Failed to create Auth user: ${JSON.stringify(createData)}`);
    }

    uid = createData.localId;
    console.log(`   ✓ Created Auth user with UID: ${uid}`);
  } else {
    console.log('2️⃣ Updating password and display name for existing user...');
    const updateRes = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:update`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        localId: uid,
        password: password,
        displayName: fullName,
        emailVerified: true,
      }),
    });

    const updateData = await updateRes.json();
    if (!updateRes.ok) {
      throw new Error(`Failed to update Auth user: ${JSON.stringify(updateData)}`);
    }
    console.log(`   ✓ Updated Auth user password & profile.`);
  }

  // 3. Set Custom Claims: { role: "ADMIN" }
  console.log('3️⃣ Injecting ADMIN custom claims for RBAC security rules...');
  const claimsRes = await fetch(`https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:update`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      localId: uid,
      customAttributes: JSON.stringify({ role: 'ADMIN' }),
    }),
  });

  const claimsData = await claimsRes.json();
  if (!claimsRes.ok) {
    throw new Error(`Failed to set custom claims: ${JSON.stringify(claimsData)}`);
  }
  console.log('   ✓ Custom claim { role: "ADMIN" } successfully set.');

  // 4. Create or Update user document in Cloud Firestore
  console.log('4️⃣ Upserting authoritative Firestore user document in "users" collection...');
  const nowIso = new Date().toISOString();
  const firestoreDocUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`;

  const firestoreBody = {
    fields: {
      id: { stringValue: uid },
      email: { stringValue: email },
      fullName: { stringValue: fullName },
      role: { stringValue: 'ADMIN' },
      isActive: { booleanValue: true },
      assignedCourseIds: { arrayValue: { values: [] } },
      fcmTokens: { arrayValue: { values: [] } },
      createdAt: { timestampValue: nowIso },
      updatedAt: { timestampValue: nowIso },
    },
  };

  const fsRes = await fetch(firestoreDocUrl, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(firestoreBody),
  });

  const fsData = await fsRes.json();
  if (!fsRes.ok) {
    throw new Error(`Failed to write Firestore user document: ${JSON.stringify(fsData)}`);
  }
  console.log(`   ✓ Document "users/${uid}" saved in Cloud Firestore.`);

  console.log('\n=============================================================');
  console.log('🎉 DEMO ADMIN ACCOUNT READY!');
  console.log('=============================================================');
  console.log(`📧 Email:    ${email}`);
  console.log(`🔑 Password: ${password}`);
  console.log(`👤 Name:     ${fullName}`);
  console.log(`🛡️ Role:     ADMIN`);
  console.log(`🆔 UID:      ${uid}`);
  console.log('=============================================================\n');
}

createOrUpdateAdmin().catch((err) => {
  console.error('\n❌ Error creating admin user:', err.message);
  process.exit(1);
});
