const admin = require('firebase-admin');

// Initialize Firebase Admin with project ID
admin.initializeApp({
  projectId: 'sajib-73b14',
});

const auth = admin.auth();
const db = admin.firestore();

const TARGET_ACCOUNTS = [
  {
    email: 'cseadmin@cse.jnu.ac.bd',
    password: 'Admin12345',
    fullName: 'Department Administrator',
    role: 'ADMIN',
    studentId: null,
    year: null,
    semester: null,
  },
  {
    email: 'teacher@cse.jnu.ac.bd',
    password: 'Teacher12345',
    fullName: 'Dr. Md. Abu Layek',
    role: 'TEACHER',
    studentId: null,
    year: null,
    semester: null,
  },
  {
    email: 'student@cse.jnu.ac.bd',
    password: 'Student12345',
    fullName: 'Tanvir Ahmed',
    role: 'STUDENT',
    studentId: 'B200305001',
    year: 3,
    semester: 1,
  },
  {
    email: 'cr@cse.jnu.ac.bd',
    password: 'Cr12345!',
    fullName: 'Mahmudul Hasan',
    role: 'CR',
    studentId: 'B200305010',
    year: 3,
    semester: 1,
  },
];

async function ensureUser(account) {
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(account.email);
    console.log(`Existing Auth user found: ${account.email} (UID: ${userRecord.uid})`);
    // Update password
    await auth.updateUser(userRecord.uid, {
      password: account.password,
      displayName: account.fullName,
      emailVerified: true,
    });
    console.log(`  -> Password refreshed for ${account.email}`);
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      userRecord = await auth.createUser({
        email: account.email,
        password: account.password,
        displayName: account.fullName,
        emailVerified: true,
      });
      console.log(`Created new Auth user: ${account.email} (UID: ${userRecord.uid})`);
    } else {
      throw err;
    }
  }

  // Set Custom Claims for Cloud Functions role authorization
  await auth.setCustomUserClaims(userRecord.uid, {
    role: account.role,
  });

  // Create or Update Firestore user profile
  const userDocRef = db.collection('users').doc(userRecord.uid);
  const userSnapshot = await userDocRef.get();

  const profileData = {
    id: userRecord.uid,
    email: account.email,
    fullName: account.fullName,
    role: account.role,
    isActive: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (account.studentId) profileData.studentId = account.studentId;
  if (account.year) profileData.year = account.year;
  if (account.semester) profileData.semester = account.semester;

  if (!userSnapshot.exists) {
    profileData.createdAt = admin.firestore.FieldValue.serverTimestamp();
    profileData.assignedCourseIds = [];
    profileData.fcmTokens = [];
    await userDocRef.set(profileData);
    console.log(`  -> Created Firestore user doc for ${account.email}`);
  } else {
    await userDocRef.set(profileData, { merge: true });
    console.log(`  -> Updated Firestore user doc for ${account.email}`);
  }

  return {
    uid: userRecord.uid,
    ...account,
  };
}

async function listAllAccounts() {
  const snapshot = await db.collection('users').get();
  const accounts = [];

  snapshot.forEach((doc) => {
    const data = doc.data();
    accounts.push({
      UID: doc.id.substring(0, 10) + '...',
      Email: data.email || 'N/A',
      Name: data.fullName || 'N/A',
      Role: data.role || 'N/A',
      'Student ID': data.studentId || '-',
      Year: data.year ?? '-',
      Semester: data.semester ?? '-',
      Active: data.isActive ? '✅' : '❌',
    });
  });

  return accounts;
}

async function main() {
  console.log('==================================================');
  console.log('🛠️ CREATING & CONFIGURING EDUPORTAL ACCOUNTS');
  console.log('==================================================\n');

  for (const acc of TARGET_ACCOUNTS) {
    await ensureUser(acc);
  }

  console.log('\n==================================================');
  console.log('📋 COMPLETE EDUPORTAL ACCOUNTS DIRECTORY');
  console.log('==================================================');
  const allAccounts = await listAllAccounts();
  console.table(allAccounts);

  console.log('\n🔐 LOGIN CREDENTIALS SUMMARY:');
  console.log('──────────────────────────────────────────────────');
  for (const acc of TARGET_ACCOUNTS) {
    console.log(`[${acc.role}]`);
    console.log(`  Email    : ${acc.email}`);
    console.log(`  Password : ${acc.password}`);
    console.log(`  Name     : ${acc.fullName}`);
    if (acc.studentId) console.log(`  ID       : ${acc.studentId}`);
    if (acc.year) console.log(`  Cohort   : Year ${acc.year}, Semester ${acc.semester}`);
    console.log('──────────────────────────────────────────────────');
  }

  process.exit(0);
}

main().catch((err) => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
