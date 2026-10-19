/**
 * Creates a new admin user via Firebase REST APIs.
 * Uses the Web API key for Auth + Firebase Admin SDK for Firestore.
 */
const https = require('https');

const PROJECT_ID = 'sajib-73b14';
const WEB_API_KEY = 'AIzaSyB4jae-WiPeCGo6zYQ1b6IQDKTyHZYgZ6Q';

// New admin credentials
const NEW_ADMIN_EMAIL = 'cseadmin@cse.jnu.ac.bd';
const NEW_ADMIN_PASSWORD = 'Admin12345';
const NEW_ADMIN_NAME = 'CSE Department Admin';

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
          if (res.statusCode >= 400) reject(json);
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

async function main() {
  console.log('🚀 Creating admin user...\n');

  // ── Step 1: Sign in as existing admin to get an ID token ────────────────
  console.log('Step 1: Getting auth token...');
  let idToken;
  try {
    const signIn = await httpsPost(
      'identitytoolkit.googleapis.com',
      `/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
      {
        email: 'admin@cse.jnu.ac.bd',
        password: 'Admin12345',
        returnSecureToken: true,
      }
    );
    idToken = signIn.idToken;
    console.log('✅ Got auth token\n');
  } catch (e) {
    console.log('⚠️  Could not sign in as existing admin, trying admin2...');
    try {
      const signIn = await httpsPost(
        'identitytoolkit.googleapis.com',
        `/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
        {
          email: 'admin2@cse.jnu.ac.bd',
          password: 'Admin12345',
          returnSecureToken: true,
        }
      );
      idToken = signIn.idToken;
      console.log('✅ Got auth token from admin2\n');
    } catch (e2) {
      console.error('❌ Cannot get auth token:', e2.error?.message || e2.message);
      process.exit(1);
    }
  }

  // ── Step 2: Create the new admin user in Firebase Auth ──────────────────
  console.log('Step 2: Creating Firebase Auth user...');
  let uid;
  try {
    const created = await httpsPost(
      'identitytoolkit.googleapis.com',
      `/v1/accounts:signUp?key=${WEB_API_KEY}`,
      {
        email: NEW_ADMIN_EMAIL,
        password: NEW_ADMIN_PASSWORD,
        displayName: NEW_ADMIN_NAME,
        returnSecureToken: true,
      }
    );
    uid = created.localId;
    console.log(`✅ Auth user created! UID: ${uid}\n`);
  } catch (e) {
    if (e.error?.message === 'EMAIL_EXISTS') {
      // Get UID of existing user
      console.log('⚠️  Email already exists, fetching UID...');
      try {
        const lookup = await httpsPost(
          'identitytoolkit.googleapis.com',
          `/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
          {
            email: NEW_ADMIN_EMAIL,
            password: NEW_ADMIN_PASSWORD,
            returnSecureToken: true,
          }
        );
        uid = lookup.localId;
        console.log(`✅ Got existing UID: ${uid}\n`);
      } catch (e2) {
        console.error('❌ Cannot get UID for existing email:', e2.error?.message);
        process.exit(1);
      }
    } else {
      console.error('❌ Auth creation failed:', e.error?.message || JSON.stringify(e));
      process.exit(1);
    }
  }

  // ── Step 3: Create Firestore document ───────────────────────────────────
  console.log('Step 3: Creating Firestore user document...');
  try {
    const firestoreDoc = {
      fields: {
        id:               { stringValue: uid },
        email:            { stringValue: NEW_ADMIN_EMAIL },
        fullName:         { stringValue: NEW_ADMIN_NAME },
        role:             { stringValue: 'ADMIN' },
        isActive:         { booleanValue: true },
        assignedCourseIds:{ arrayValue: { values: [] } },
        fcmTokens:        { arrayValue: { values: [] } },
      },
    };

    await httpsRequest(
      'firestore.googleapis.com',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`,
      'PATCH',
      firestoreDoc,
      { Authorization: `Bearer ${idToken}` }
    );

    console.log('✅ Firestore document created!\n');
  } catch (e) {
    console.error('❌ Firestore failed:', JSON.stringify(e, null, 2));
    console.log('\n📝 Manual fix: Add this document in Firestore Console:');
    console.log(`   Collection: users`);
    console.log(`   Document ID: ${uid}`);
    console.log(`   Fields: id="${uid}", email="${NEW_ADMIN_EMAIL}", fullName="${NEW_ADMIN_NAME}", role="ADMIN", isActive=true`);
    process.exit(1);
  }

  // ── Done ─────────────────────────────────────────────────────────────────
  console.log('════════════════════════════════════');
  console.log('✅  NEW ADMIN CREATED SUCCESSFULLY!');
  console.log('════════════════════════════════════');
  console.log(`  Email    : ${NEW_ADMIN_EMAIL}`);
  console.log(`  Password : ${NEW_ADMIN_PASSWORD}`);
  console.log(`  UID      : ${uid}`);
  console.log(`  Role     : ADMIN`);
  console.log('════════════════════════════════════');
}

main().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});
