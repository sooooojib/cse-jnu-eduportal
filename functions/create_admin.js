const admin = require('firebase-admin');

// Initialize with application default credentials (uses firebase CLI login)
admin.initializeApp({
  projectId: 'sajib-73b14',
});

const auth = admin.auth();
const db = admin.firestore();

async function createAdmin() {
  const email = 'admin2@cse.jnu.ac.bd';
  const password = 'Admin12345';
  const fullName = 'System Administrator 2';

  try {
    // 1. Create user in Firebase Auth
    const userRecord = await auth.createUser({
      email,
      password,
      displayName: fullName,
      emailVerified: true,
    });

    console.log('✅ Auth user created:', userRecord.uid);

    // 2. Create user document in Firestore with admin role
    await db.collection('users').doc(userRecord.uid).set({
      id: userRecord.uid,
      email,
      fullName,
      role: 'admin',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('✅ Firestore user document created');
    console.log('');
    console.log('=== New Admin Created ===');
    console.log('Email   :', email);
    console.log('Password:', password);
    console.log('UID     :', userRecord.uid);
    console.log('========================');

    process.exit(0);
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

createAdmin();
