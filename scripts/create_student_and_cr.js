const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'sajib-73b14';
const WEB_API_KEY = 'AIzaSyB4jae-WiPeCGo6zYQ1b6IQDKTyHZYgZ6Q';

function getAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(configPath)) {
    throw new Error('firebase-tools.json not found');
  }
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  return config.tokens.access_token;
}

function httpsPost(hostname, path, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(data);
    const options = {
      hostname,
      path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        ...headers,
      },
    };
    const req = https.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => (raw += chunk));
      res.on('end', () => {
        try {
          const json = JSON.parse(raw);
          if (res.statusCode >= 400) reject({ status: res.statusCode, ...json });
          else resolve(json);
        } catch (e) {
          reject({ message: raw });
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function httpsRequest(hostname, path, method, data, headers = {}) {
  return new Promise((resolve, reject) => {
    const body = data ? JSON.stringify(data) : undefined;
    const options = {
      hostname,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(body ? { 'Content-Length': Buffer.byteLength(body) } : {}),
        ...headers,
      },
    };
    const req = https.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => (raw += chunk));
      res.on('end', () => {
        try {
          const json = JSON.parse(raw);
          if (res.statusCode >= 400) reject({ status: res.statusCode, ...json });
          else resolve(json);
        } catch (e) {
          reject({ message: raw });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function createOrUpdateUser(acc, oauthToken) {
  console.log(`\nSetting up ${acc.role} account: ${acc.email}...`);
  let uid;
  let idToken;

  // 1. Try to create in Firebase Auth
  try {
    const created = await httpsPost(
      'identitytoolkit.googleapis.com',
      `/v1/accounts:signUp?key=${WEB_API_KEY}`,
      {
        email: acc.email,
        password: acc.password,
        displayName: acc.fullName,
        returnSecureToken: true,
      }
    );
    uid = created.localId;
    idToken = created.idToken;
    console.log(`  ✅ Created new Auth user! UID: ${uid}`);
  } catch (err) {
    if (err.error?.message === 'EMAIL_EXISTS') {
      console.log(`  ℹ️ Account already exists. Updating password to "${acc.password}"...`);
      // Sign in or update password via OAuth or API
      try {
        const signIn = await httpsPost(
          'identitytoolkit.googleapis.com',
          `/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
          {
            email: acc.email,
            password: acc.password,
            returnSecureToken: true,
          }
        );
        uid = signIn.localId;
        idToken = signIn.idToken;
        console.log(`  ✅ Existing user verified! UID: ${uid}`);
      } catch (signInErr) {
        // Change password using admin oauthToken
        const changeRes = await httpsPost(
          'identitytoolkit.googleapis.com',
          `/v1/accounts:update?key=${WEB_API_KEY}`,
          {
            email: acc.email,
            password: acc.password,
            returnSecureToken: true,
          },
          { Authorization: `Bearer ${oauthToken}` }
        ).catch(() => null);

        if (changeRes) {
          uid = changeRes.localId;
          console.log(`  ✅ Password updated via admin OAuth! UID: ${uid}`);
        }
      }
    } else {
      console.error(`  ❌ Error during Auth setup:`, err.error?.message || err);
    }
  }

  // If still missing UID, search Firestore
  if (!uid) {
    const listRes = await httpsRequest(
      'firestore.googleapis.com',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users`,
      'GET',
      null,
      { Authorization: `Bearer ${oauthToken}` }
    );
    for (const doc of listRes.documents || []) {
      if (doc.fields?.email?.stringValue?.toLowerCase() === acc.email.toLowerCase()) {
        uid = doc.fields?.id?.stringValue || path.basename(doc.name);
        console.log(`  ✅ Found UID in Firestore: ${uid}`);
        break;
      }
    }
  }

  if (!uid) {
    throw new Error(`Failed to resolve UID for ${acc.email}`);
  }

  // 2. Set/Update Firestore document
  const fields = {
    id: { stringValue: uid },
    email: { stringValue: acc.email },
    fullName: { stringValue: acc.fullName },
    role: { stringValue: acc.role },
    isActive: { booleanValue: true },
    studentId: acc.studentId ? { stringValue: acc.studentId } : { nullValue: null },
    year: acc.year ? { integerValue: acc.year } : { nullValue: null },
    semester: acc.semester ? { integerValue: acc.semester } : { nullValue: null },
    assignedCourseIds: { arrayValue: { values: [] } },
    fcmTokens: { arrayValue: { values: [] } },
  };

  await httpsRequest(
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`,
    'PATCH',
    { fields },
    { Authorization: `Bearer ${oauthToken}` }
  );

  console.log(`  ✅ Firestore document synced for ${acc.email} with role: ${acc.role}`);
  return { uid, ...acc };
}

async function getAllUsers(oauthToken) {
  const res = await httpsRequest(
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users?pageSize=100`,
    'GET',
    null,
    { Authorization: `Bearer ${oauthToken}` }
  );

  return (res.documents || []).map((doc) => {
    const f = doc.fields || {};
    return {
      Email: f.email?.stringValue || 'N/A',
      Name: f.fullName?.stringValue || 'N/A',
      Role: f.role?.stringValue || 'N/A',
      'Student ID': f.studentId?.stringValue || '-',
      Year: f.year?.integerValue ?? '-',
      Semester: f.semester?.integerValue ?? '-',
      Active: f.isActive?.booleanValue ? 'Yes' : 'No',
    };
  });
}

async function main() {
  console.log('====================================================');
  console.log('👥 CREATING STUDENT AND CR ACCOUNTS IN JNU EDUPORTAL');
  console.log('====================================================');

  const oauthToken = getAccessToken();

  const accountsToCreate = [
    {
      email: 'student2026@cse.jnu.ac.bd',
      password: 'Student12345!',
      fullName: 'Tanvir Rahman (Student)',
      role: 'STUDENT',
      studentId: 'B200305025',
      year: 3,
      semester: 1,
    },
    {
      email: 'cr2026@cse.jnu.ac.bd',
      password: 'Cr12345!',
      fullName: 'Kamrul Hasan (CR)',
      role: 'CR',
      studentId: 'B200305030',
      year: 3,
      semester: 1,
    },
  ];

  for (const acc of accountsToCreate) {
    await createOrUpdateUser(acc, oauthToken);
  }

  console.log('\n====================================================');
  console.log('📋 COMPLETE DIRECTORY OF ALL USERS IN FIRESTORE:');
  console.log('====================================================');
  const all = await getAllUsers(oauthToken);
  console.table(all);
}

main().catch((err) => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
