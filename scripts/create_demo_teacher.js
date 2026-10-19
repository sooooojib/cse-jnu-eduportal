/**
 * Script to create and configure a Demo Teacher Account in Firebase Auth & Firestore.
 * 
 * Credentials:
 *   Email    : teacher@cse.jnu.ac.bd
 *   Password : Teacher12345
 *   Role     : TEACHER
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'sajib-73b14';
const WEB_API_KEY = 'AIzaSyB4jae-WiPeCGo6zYQ1b6IQDKTyHZYgZ6Q';

function getFirebaseToolsToken() {
  try {
    const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
    if (fs.existsSync(configPath)) {
      const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
      return config.tokens.access_token;
    }
  } catch (e) {
    console.warn('Could not read firebase-tools token:', e.message);
  }
  return null;
}

const TEACHER_EMAIL = 'teacher@cse.jnu.ac.bd';
const TEACHER_PASSWORD = 'Teacher12345';
const TEACHER_NAME = 'Dr. Md. Abu Layek';

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

async function setDoc(collection, docId, fields, token) {
  return httpsRequest(
    'firestore.googleapis.com',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`,
    'PATCH',
    { fields },
    { Authorization: `Bearer ${token}` }
  );
}

async function main() {
  console.log('🚀 Setting up Demo Faculty / Teacher Account...\n');

  // Step 1: Sign in as existing admin to get an ID token with authorization
  console.log('Step 1: Authenticating as Admin for Firestore permissions...');
  let adminIdToken;
  try {
    const adminAuth = await httpsPost(
      'identitytoolkit.googleapis.com',
      `/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
      {
        email: 'cseadmin@cse.jnu.ac.bd',
        password: 'Admin12345',
        returnSecureToken: true,
      }
    );
    adminIdToken = adminAuth.idToken;
    console.log('✅ Admin authenticated\n');
  } catch (e) {
    console.error('❌ Failed to authenticate admin:', e);
    process.exit(1);
  }

  const fsToken = getFirebaseToolsToken() || adminIdToken;

  // Step 2: Create Teacher user in Firebase Auth
  console.log('Step 2: Creating Teacher in Firebase Authentication...');
  let teacherUid;
  try {
    const created = await httpsPost(
      'identitytoolkit.googleapis.com',
      `/v1/accounts:signUp?key=${WEB_API_KEY}`,
      {
        email: TEACHER_EMAIL,
        password: TEACHER_PASSWORD,
        displayName: TEACHER_NAME,
        returnSecureToken: true,
      }
    );
    teacherUid = created.localId;
    console.log(`✅ Teacher Auth created! UID: ${teacherUid}\n`);
  } catch (e) {
    if (e.error?.message === 'EMAIL_EXISTS') {
      console.log('ℹ️  Teacher email already exists. Fetching UID & signing in...');
      try {
        const lookup = await httpsPost(
          'identitytoolkit.googleapis.com',
          `/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
          {
            email: TEACHER_EMAIL,
            password: TEACHER_PASSWORD,
            returnSecureToken: true,
          }
        );
        teacherUid = lookup.localId;
        console.log(`✅ Signed in to existing Teacher UID: ${teacherUid}\n`);
      } catch (e2) {
        console.error('Cannot login with default password:', e2);
        process.exit(1);
      }
    } else {
      console.error('❌ Auth error:', e);
      process.exit(1);
    }
  }

  const now = new Date().toISOString();

  // Step 3: Write users document
  console.log('Step 3: Creating / Updating teacher profile in users collection...');
  await setDoc('users', teacherUid, {
    id: { stringValue: teacherUid },
    email: { stringValue: TEACHER_EMAIL },
    fullName: { stringValue: TEACHER_NAME },
    role: { stringValue: 'TEACHER' },
    phone: { stringValue: '+8801711223344' },
    avatarUrl: { stringValue: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=250' },
    isActive: { booleanValue: true },
    assignedCourseIds: {
      arrayValue: {
        values: [
          { stringValue: 'CSE-3101' },
          { stringValue: 'CSE-3102' },
          { stringValue: 'CSE-4107' },
        ],
      },
    },
    fcmTokens: { arrayValue: { values: [] } },
    createdAt: { timestampValue: now },
    updatedAt: { timestampValue: now },
  }, adminIdToken);
  console.log('✅ users document configured');

  // Step 4: Seed assigned courses
  console.log('Step 4: Ensuring courses are linked to this teacher UID...');
  const courses = [
    {
      code: 'CSE-3101',
      title: 'Operating Systems',
      credit: 3.0,
      year: 3,
      semester: 1,
      type: 'THEORY',
      desc: 'Processes, Threads, CPU Scheduling, Virtual Memory, Concurrency, and Deadlock Avoidance.',
    },
    {
      code: 'CSE-3102',
      title: 'Operating Systems Sessional',
      credit: 1.5,
      year: 3,
      semester: 1,
      type: 'LAB',
      desc: 'Hands-on Linux Kernel System Calls, POSIX Threads, Semaphores, and IPC in C.',
    },
    {
      code: 'CSE-4107',
      title: 'Distributed Systems & Cloud',
      credit: 3.0,
      year: 4,
      semester: 1,
      type: 'THEORY',
      desc: 'Consensus algorithms, Paxos, Raft, Microservices, and Cloud Native Architectures.',
    },
  ];

  for (const c of courses) {
    await setDoc('courses', c.code, {
      id: { stringValue: c.code },
      code: { stringValue: c.code },
      title: { stringValue: c.title },
      credit: { doubleValue: c.credit },
      year: { integerValue: String(c.year) },
      semester: { integerValue: String(c.semester) },
      courseType: { stringValue: c.type },
      description: { stringValue: c.desc },
      teacherId: { stringValue: teacherUid },
      teacherName: { stringValue: TEACHER_NAME },
      coordinatorId: { stringValue: teacherUid },
      updatedAt: { timestampValue: now },
    }, adminIdToken);
    console.log(`  ✓ Course: ${c.code} -> ${c.title}`);
  }

  // Step 5: Seed Course Assignments
  console.log('Step 5: Seeding courseAssignments...');
  for (const c of courses) {
    const asgnId = `asgn_${teacherUid.substring(0, 6)}_${c.code}`;
    await setDoc('courseAssignments', asgnId, {
      id: { stringValue: asgnId },
      courseId: { stringValue: c.code },
      courseCode: { stringValue: c.code },
      courseTitle: { stringValue: c.title },
      teacherId: { stringValue: teacherUid },
      teacherName: { stringValue: TEACHER_NAME },
      isCoordinator: { booleanValue: true },
      assignedAt: { timestampValue: now },
    }, adminIdToken);
  }
  console.log('✅ courseAssignments seeded');

  // Step 6: Seed Time-Aware Routine Schedules
  const daysOfWeek = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
  const todayIndex = new Date().getDay();
  const todayDay = daysOfWeek[todayIndex];
  const tomorrowDay = daysOfWeek[(todayIndex + 1) % 7];

  console.log(`Step 6: Seeding schedule slots for today (${todayDay}) and tomorrow (${tomorrowDay})...`);
  const schedulesToSeed = [
    {
      id: `sch_teacher_today_1`,
      courseId: 'CSE-3101',
      courseCode: 'CSE-3101',
      courseTitle: 'Operating Systems',
      dayOfWeek: todayDay,
      startTime: '10:00',
      endTime: '11:30',
      room: 'Room 501 (Academic Complex)',
      targetYear: 3,
      targetSemester: 1,
    },
    {
      id: `sch_teacher_today_2`,
      courseId: 'CSE-3102',
      courseCode: 'CSE-3102',
      courseTitle: 'Operating Systems Sessional',
      dayOfWeek: todayDay,
      startTime: '12:00',
      endTime: '14:30',
      room: 'Software Lab 2 (7th Floor)',
      targetYear: 3,
      targetSemester: 1,
    },
    {
      id: `sch_teacher_tomorrow_1`,
      courseId: 'CSE-4107',
      courseCode: 'CSE-4107',
      courseTitle: 'Distributed Systems & Cloud',
      dayOfWeek: tomorrowDay,
      startTime: '09:00',
      endTime: '10:30',
      room: 'Seminar Room 402',
      targetYear: 4,
      targetSemester: 1,
    },
    {
      id: `sch_teacher_tomorrow_2`,
      courseId: 'CSE-3101',
      courseCode: 'CSE-3101',
      courseTitle: 'Operating Systems Problem Session',
      dayOfWeek: tomorrowDay,
      startTime: '11:00',
      endTime: '12:30',
      room: 'Room 501',
      targetYear: 3,
      targetSemester: 1,
    },
  ];

  for (const s of schedulesToSeed) {
    await setDoc('schedules', s.id, {
      id: { stringValue: s.id },
      courseId: { stringValue: s.courseId },
      courseCode: { stringValue: s.courseCode },
      courseTitle: { stringValue: s.courseTitle },
      teacherId: { stringValue: teacherUid },
      teacherName: { stringValue: TEACHER_NAME },
      dayOfWeek: { stringValue: s.dayOfWeek },
      startTime: { stringValue: s.startTime },
      endTime: { stringValue: s.endTime },
      room: { stringValue: s.room },
      targetYear: { integerValue: String(s.targetYear) },
      targetSemester: { integerValue: String(s.targetSemester) },
      isExtraClass: { booleanValue: false },
      createdAt: { timestampValue: now },
    }, adminIdToken);
    console.log(`  ✓ Class: [${s.dayOfWeek}] ${s.startTime} ${s.courseCode} in ${s.room}`);
  }

  // Step 7: Create/Authenticate Student for Student Actions (counseling & feedback)
  console.log('Step 7: Authenticating Demo Student for booking & feedback creation...');
  const STUDENT_EMAIL = 'demostudent2026@cse.jnu.ac.bd';
  const STUDENT_PASSWORD = 'Student12345';
  const STUDENT_NAME = 'Sajib Ahmed';
  let studentUid;
  let studentIdToken;

  try {
    const studentSignUp = await httpsPost(
      'identitytoolkit.googleapis.com',
      `/v1/accounts:signUp?key=${WEB_API_KEY}`,
      {
        email: STUDENT_EMAIL,
        password: STUDENT_PASSWORD,
        displayName: STUDENT_NAME,
        returnSecureToken: true,
      }
    );
    studentUid = studentSignUp.localId;
    studentIdToken = studentSignUp.idToken;
    console.log(`✅ Demo Student Auth created (UID: ${studentUid})`);
  } catch (err) {
    if (err.error?.message === 'EMAIL_EXISTS') {
      try {
        const studentSignIn = await httpsPost(
          'identitytoolkit.googleapis.com',
          `/v1/accounts:signInWithPassword?key=${WEB_API_KEY}`,
          {
            email: STUDENT_EMAIL,
            password: STUDENT_PASSWORD,
            returnSecureToken: true,
          }
        );
        studentUid = studentSignIn.localId;
        studentIdToken = studentSignIn.idToken;
        console.log(`✅ Demo Student signed in (UID: ${studentUid})`);
      } catch (signInErr) {
        console.warn('Could not sign in with demo student credentials:', signInErr.error?.message || signInErr);
      }
    } else {
      console.warn('Student auth issue:', err.error?.message || err);
    }
  }

  // Ensure student profile in users
  if (studentUid) {
    await setDoc('users', studentUid, {
      id: { stringValue: studentUid },
      email: { stringValue: STUDENT_EMAIL },
      fullName: { stringValue: STUDENT_NAME },
      role: { stringValue: 'STUDENT' },
      studentId: { stringValue: '2020CSE042' },
      year: { integerValue: '3' },
      semester: { integerValue: '1' },
      isActive: { booleanValue: true },
      fcmTokens: { arrayValue: { values: [] } },
      createdAt: { timestampValue: now },
      updatedAt: { timestampValue: now },
    }, adminIdToken);
  }

  // Step 8: Seed Pending Counseling Bookings
  console.log('Step 8: Seeding pending counseling bookings...');
  const bookings = [
    {
      id: `cb_${teacherUid.substring(0, 5)}_1`,
      studentName: 'Sajib Ahmed (2020CSE042)',
      category: 'ACADEMIC_ADVISING',
      notes: 'Questions about Virtual Memory Paging and OS Project milestone.',
    },
    {
      id: `cb_${teacherUid.substring(0, 5)}_2`,
      studentName: 'Nusrat Jahan (2022CSE019)',
      category: 'RESEARCH_DISCUSSION',
      notes: 'Undergraduate thesis proposal discussion on Distributed Consensus.',
    },
  ];

  const bookingToken = studentIdToken || adminIdToken;
  for (const b of bookings) {
    try {
      await setDoc('counselingBookings', b.id, {
        id: { stringValue: b.id },
        teacherId: { stringValue: teacherUid },
        teacherName: { stringValue: TEACHER_NAME },
        studentId: { stringValue: studentUid || 'student_sajib_uid' },
        studentName: { stringValue: b.studentName },
        category: { stringValue: b.category },
        notes: { stringValue: b.notes },
        status: { stringValue: 'PENDING' },
        createdAt: { timestampValue: now },
      }, bookingToken);
      console.log(`  ✓ Pending Counseling from: ${b.studentName}`);
    } catch (err) {
      console.warn(`  Notice: counseling booking not seeded (${err.status || err.message})`);
    }
  }

  // Step 9: Seed Feedback
  console.log('Step 9: Seeding student course feedback...');
  const feedbacks = [
    {
      id: `fb_${teacherUid.substring(0, 5)}_1`,
      courseCode: 'CSE-3101',
      rating: 5,
      comments: 'Dr. Layek explains process synchronization and deadlock with crystal clarity.',
    },
    {
      id: `fb_${teacherUid.substring(0, 5)}_2`,
      courseCode: 'CSE-3102',
      rating: 5,
      comments: 'The Linux POSIX thread lab exercises are hands-on and very practical.',
    },
  ];

  for (const f of feedbacks) {
    try {
      await setDoc('feedback', f.id, {
        id: { stringValue: f.id },
        studentId: { stringValue: studentUid || 'student_sajib_uid' },
        teacherId: { stringValue: teacherUid },
        teacherName: { stringValue: TEACHER_NAME },
        courseCode: { stringValue: f.courseCode },
        rating: { integerValue: String(f.rating) },
        comments: { stringValue: f.comments },
        isAnonymous: { booleanValue: true },
        replies: { arrayValue: { values: [] } },
        createdAt: { timestampValue: now },
      }, bookingToken);
      console.log(`  ✓ Feedback: 5★ for ${f.courseCode}`);
    } catch (err) {
      console.warn(`  Notice: feedback not seeded (${err.status || err.message})`);
    }
  }

  console.log('\n════════════════════════════════════════════════════');
  console.log('🎉 DEMO TEACHER ACCOUNT READY FOR TESTING!');
  console.log('════════════════════════════════════════════════════');
  console.log(`  Email       : ${TEACHER_EMAIL}`);
  console.log(`  Password    : ${TEACHER_PASSWORD}`);
  console.log(`  Name        : ${TEACHER_NAME}`);
  console.log(`  Role        : TEACHER`);
  console.log(`  UID         : ${teacherUid}`);
  console.log('════════════════════════════════════════════════════\n');
}

main().catch(console.error);
