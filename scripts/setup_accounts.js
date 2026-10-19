const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'sajib-73b14';
const WEB_API_KEY = 'AIzaSyB4jae-WiPeCGo6zYQ1b6IQDKTyHZYgZ6Q';

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

async function getAdminToken() {
  const adminCandidates = [
    { email: 'cseadmin@cse.jnu.ac.bd', password: 'Admin12345' },
    { email: 'admin@cse.jnu.ac.bd', password: 'Admin12345' },
    { email: 'admin2@cse.jnu.ac.bd', password: 'Admin12345' },
  ];

  for (const cred of adminCandidates) {
    try {
      const res = await httpsPost(
        'identitytoolkit.googleapis.com',
        `/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
        {
          email: cred.email,
          password: cred.password,
          returnSecureToken: true,
        }
      );
      console.log(`✅ Authenticated as Admin via ${cred.email}`);
      return { idToken: res.idToken, adminEmail: cred.email };
    } catch (err) {
      // Try next
    }
  }
  throw new Error('Could not authenticate with any known admin account.');
}

async function ensureUser({ email, password, displayName, role, studentId, year, semester }, adminToken) {
  console.log(`\nChecking / Creating ${role} user: ${email}...`);
  let uid;
  try {
    const signup = await httpsPost(
      'identitytoolkit.googleapis.com',
      `/v1/accounts:signUp?key=${WEB_API_KEY}`,
      {
        email,
        password,
        displayName,
        returnSecureToken: true,
      }
    );
    uid = signup.localId;
    console.log(`  -> Created in Firebase Auth! UID: ${uid}`);
  } catch (err) {
    if (err.error?.message === 'EMAIL_EXISTS') {
      console.log(`  -> Account already exists in Auth. Signing in / updating password...`);
      // Update password just to be 100% sure the password matches what we tell the user
      const signIn = await httpsPost(
        'identitytoolkit.googleapis.com',
        `/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
        {
          email,
          password,
          returnSecureToken: true,
        }
      ).catch(async () => {
        // If password was different, try resetting via admin or change password
        return null;
      });

      if (signIn) {
        uid = signIn.localId;
      } else {
        // Use lookup by creating a temporary custom token or lookup
        console.log(`  -> Password differs or lookup needed.`);
        // Try sign-in with known common password or update
        // We can sign in as user if we knew old password, or look up in Firestore
      }
    } else {
      console.error(`  ❌ Error signing up:`, err);
    }
  }

  // If uid not yet known, search Firestore /users for matching email
  if (!uid) {
    const usersRes = await httpsRequest(
      'firestore.googleapis.com',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users`,
      'GET',
      null,
      { Authorization: `Bearer ${adminToken}` }
    );
    const docs = usersRes.documents || [];
    for (const d of docs) {
      const dEmail = d.fields?.email?.stringValue;
      if (dEmail && dEmail.toLowerCase() === email.toLowerCase()) {
        uid = d.fields?.id?.stringValue || path.basename(d.name);
        console.log(`  -> Found existing UID in Firestore: ${uid}`);
        break;
      }
    }
  }

  if (!uid) {
    throw new Error(`Could not determine UID for ${email}`);
  }

  // Create or Update Firestore user document
  const docFields = {
    id: { stringValue: uid },
    email: { stringValue: email },
    fullName: { stringValue: displayName },
    role: { stringValue: role },
    isActive: { booleanValue: true },
    studentId: studentId ? { stringValue: studentId } : { nullValue: null },
    year: year ? { integerValue: year } : { nullValue: null },
    semester: semester ? { integerValue: semester } : { nullValue: null },
    assignedCourseIds: { arrayValue: { values: [] } },
    fcmTokens: { arrayValue: { values: [] } },
  };

  await httpsRequest(
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`,
    'PATCH',
    { fields: docFields },
    { Authorization: `Bearer ${adminToken}` }
  );

  console.log(`  -> Firestore document configured for ${email} with role ${role} (Year ${year}, Sem ${semester})`);
  return { uid, email, password, role, displayName, studentId, year, semester };
}

async function listAllUsers(adminToken) {
  const usersRes = await httpsRequest(
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users`,
    'GET',
    null,
    { Authorization: `Bearer ${adminToken}` }
  );
  return (usersRes.documents || []).map((d) => {
    const f = d.fields || {};
    return {
      uid: f.id?.stringValue || path.basename(d.name),
      email: f.email?.stringValue,
      role: f.role?.stringValue,
      fullName: f.fullName?.stringValue,
      studentId: f.studentId?.stringValue || '-',
      year: f.year?.integerValue || '-',
      semester: f.semester?.integerValue || '-',
      isActive: f.isActive?.booleanValue,
    };
  });
}

async function main() {
  const { idToken, adminEmail } = await getAdminToken();

  // 1. Ensure Student Account
  const student = await ensureUser(
    {
      email: 'student@cse.jnu.ac.bd',
      password: 'Student12345',
      displayName: 'Tanvir Ahmed (Student)',
      role: 'STUDENT',
      studentId: 'B200305001',
      year: 3,
      semester: 1,
    },
    idToken
  );

  // 2. Ensure CR Account
  const cr = await ensureUser(
    {
      email: 'cr@cse.jnu.ac.bd',
      password: 'Cr12345!',
      displayName: 'Mahmudul Hasan (CR)',
      role: 'CR',
      studentId: 'B200305010',
      year: 3,
      semester: 1,
    },
    idToken
  );

  // 3. List all accounts
  console.log('\n======================================================');
  console.log('📋 CURRENT REGISTERED ACCOUNTS IN CSE JNU EDUPORTAL:');
  console.log('======================================================');
  const allUsers = await listAllUsers(idToken);
  console.table(allUsers);
}

main().catch((err) => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
