#!/usr/bin/env node

/**
 * Script to seed initial demo data (Courses, Faculty, Signup Petitions, Semester Requests)
 * into Cloud Firestore for testing the Admin Dashboard and Management screens.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'sajib-73b14';

async function getAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  return config.tokens.access_token;
}

async function setDoc(collection, docId, fields, token) {
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
    console.error(`Failed to write ${collection}/${docId}:`, err);
  }
}

async function seed() {
  console.log('🌱 Seeding demo departmental data for CSE JnU EduPortal...');
  const token = await getAccessToken();
  const now = new Date().toISOString();

  // 1. Faculty Profiles
  console.log('👨‍🏫 Seeding faculty accounts in users collection...');
  const faculty = [
    {
      id: 'teacher_layek_uid',
      name: 'Dr. Md. Abu Layek',
      email: 'layek@cse.jnu.ac.bd',
      courses: ['CSE-3101', 'CSE-3102'],
    },
    {
      id: 'teacher_uzzal_uid',
      name: 'Dr. Uzzal Kumar Acharjee',
      email: 'uzzal@cse.jnu.ac.bd',
      courses: ['CSE-3103', 'CSE-3104'],
    },
    {
      id: 'teacher_nasir_uid',
      name: 'Dr. Mohammed Nasir Uddin',
      email: 'nasir.jnu.cse@gmail.com',
      courses: ['CSE-3105'],
    },
  ];

  for (const f of faculty) {
    await setDoc('users', f.id, {
      id: { stringValue: f.id },
      email: { stringValue: f.email },
      fullName: { stringValue: f.name },
      role: { stringValue: 'TEACHER' },
      isActive: { booleanValue: true },
      assignedCourseIds: {
        arrayValue: { values: f.courses.map((c) => ({ stringValue: c })) },
      },
      fcmTokens: { arrayValue: { values: [] } },
      createdAt: { timestampValue: now },
      updatedAt: { timestampValue: now },
    }, token);
    console.log(`  ✓ Faculty: ${f.name}`);
  }

  // 1b. Enrolled Students & Class Representative (CR)
  console.log('🎓 Seeding student and CR accounts in users collection...');
  const students = [
    {
      id: 'student_sajib_uid',
      name: 'Sajib Ahmed',
      email: 'sajib@cse.jnu.ac.bd',
      role: 'STUDENT',
      studentId: '2022CSE001',
      year: 3,
      semester: 1,
    },
    {
      id: 'student_rahim_uid',
      name: 'Rahim Ullah',
      email: 'rahim@cse.jnu.ac.bd',
      role: 'STUDENT',
      studentId: '2022CSE015',
      year: 3,
      semester: 1,
    },
    {
      id: 'student_fatima_uid',
      name: 'Fatima Zohra',
      email: 'fatima@cse.jnu.ac.bd',
      role: 'STUDENT',
      studentId: '2023CSE012',
      year: 2,
      semester: 1,
    },
    {
      id: 'cr_hasan_uid',
      name: 'Mahmudul Hasan (CR)',
      email: 'hasan.cr@cse.jnu.ac.bd',
      role: 'CR',
      studentId: '2022CSE025',
      year: 3,
      semester: 1,
    },
  ];

  for (const s of students) {
    await setDoc('users', s.id, {
      id: { stringValue: s.id },
      email: { stringValue: s.email },
      fullName: { stringValue: s.name },
      role: { stringValue: s.role },
      studentId: { stringValue: s.studentId },
      year: { integerValue: s.year },
      semester: { integerValue: s.semester },
      isActive: { booleanValue: true },
      assignedCourseIds: { arrayValue: { values: [] } },
      fcmTokens: { arrayValue: { values: [] } },
      createdAt: { timestampValue: now },
      updatedAt: { timestampValue: now },
    }, token);
    console.log(`  ✓ ${s.role}: ${s.name} (${s.studentId})`);
  }

  // 2. Syllabus Courses
  console.log('📚 Seeding departmental courses...');
  const courses = [
    {
      code: 'CSE-1101',
      title: 'Structured Programming Language',
      credit: 3.0,
      year: 1,
      semester: 1,
      type: 'THEORY',
      desc: 'C programming, structures, pointers, file I/O.',
    },
    {
      code: 'CSE-1102',
      title: 'Structured Programming Language Sessional',
      credit: 1.5,
      year: 1,
      semester: 1,
      type: 'LAB',
      desc: 'Hands-on programming assignments in C.',
    },
    {
      code: 'CSE-3101',
      title: 'Operating Systems',
      credit: 3.0,
      year: 3,
      semester: 1,
      type: 'THEORY',
      desc: 'Processes, CPU Scheduling, Virtual Memory, File Systems.',
      teacherId: 'teacher_layek_uid',
      teacherName: 'Dr. Md. Abu Layek',
    },
    {
      code: 'CSE-3102',
      title: 'Operating Systems Sessional',
      credit: 1.5,
      year: 3,
      semester: 1,
      type: 'LAB',
      desc: 'Linux Kernel calls, POSIX threads, synchronization.',
      teacherId: 'teacher_layek_uid',
      teacherName: 'Dr. Md. Abu Layek',
    },
    {
      code: 'CSE-3103',
      title: 'Database Management Systems',
      credit: 3.0,
      year: 3,
      semester: 1,
      type: 'THEORY',
      desc: 'Relational algebra, normal forms, transaction ACID properties.',
      teacherId: 'teacher_uzzal_uid',
      teacherName: 'Dr. Uzzal Kumar Acharjee',
    },
    {
      code: 'CSE-3104',
      title: 'Database Management Systems Sessional',
      credit: 1.5,
      year: 3,
      semester: 1,
      type: 'LAB',
      desc: 'PostgreSQL, Stored Procedures, Triggers, full stack DB design.',
      teacherId: 'teacher_uzzal_uid',
      teacherName: 'Dr. Uzzal Kumar Acharjee',
    },
    {
      code: 'CSE-3105',
      title: 'Computer Networks',
      credit: 3.0,
      year: 3,
      semester: 1,
      type: 'THEORY',
      desc: 'TCP/IP architecture, socket programming, routing algorithms.',
      teacherId: 'teacher_nasir_uid',
      teacherName: 'Dr. Mohammed Nasir Uddin',
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
      teacherId: c.teacherId ? { stringValue: c.teacherId } : { nullValue: null },
      teacherName: c.teacherName ? { stringValue: c.teacherName } : { nullValue: null },
      createdAt: { timestampValue: now },
      updatedAt: { timestampValue: now },
    }, token);
    console.log(`  ✓ Course: ${c.code} - ${c.title}`);
  }

  // 3. Course Assignments
  console.log('📌 Seeding teacher course assignments...');
  const assignments = [
    {
      id: 'asgn_layek_3101',
      courseId: 'CSE-3101',
      courseCode: 'CSE-3101',
      courseTitle: 'Operating Systems',
      teacherId: 'teacher_layek_uid',
      teacherName: 'Dr. Md. Abu Layek',
      isCoordinator: true,
    },
    {
      id: 'asgn_layek_3102',
      courseId: 'CSE-3102',
      courseCode: 'CSE-3102',
      courseTitle: 'Operating Systems Sessional',
      teacherId: 'teacher_layek_uid',
      teacherName: 'Dr. Md. Abu Layek',
      isCoordinator: false,
    },
    {
      id: 'asgn_uzzal_3103',
      courseId: 'CSE-3103',
      courseCode: 'CSE-3103',
      courseTitle: 'Database Management Systems',
      teacherId: 'teacher_uzzal_uid',
      teacherName: 'Dr. Uzzal Kumar Acharjee',
      isCoordinator: true,
    },
  ];

  for (const a of assignments) {
    await setDoc('courseAssignments', a.id, {
      id: { stringValue: a.id },
      courseId: { stringValue: a.courseId },
      courseCode: { stringValue: a.courseCode },
      courseTitle: { stringValue: a.courseTitle },
      teacherId: { stringValue: a.teacherId },
      teacherName: { stringValue: a.teacherName },
      isCoordinator: { booleanValue: a.isCoordinator },
      assignedAt: { timestampValue: now },
    }, token);
    console.log(`  ✓ Allocation: ${a.teacherName} -> ${a.courseCode}`);
  }

  // 4. Pending Signup Requests (for Admin moderation testing)
  console.log('📬 Seeding pending signup requests...');
  const signupRequests = [
    {
      id: 'req_student_tanvir',
      email: 'tanvir.cse23@jnu.ac.bd',
      fullName: 'Tanvir Ahmed',
      role: 'STUDENT',
      studentId: '2023CSE042',
      phone: '+8801711223344',
      status: 'PENDING',
    },
    {
      id: 'req_student_nusrat',
      email: 'nusrat.cse24@jnu.ac.bd',
      fullName: 'Nusrat Jahan',
      role: 'STUDENT',
      studentId: '2024CSE019',
      phone: '+8801822334455',
      status: 'PENDING',
    },
  ];

  for (const s of signupRequests) {
    await setDoc('signupRequests', s.id, {
      id: { stringValue: s.id },
      email: { stringValue: s.email },
      fullName: { stringValue: s.fullName },
      role: { stringValue: s.role },
      studentId: { stringValue: s.studentId },
      phone: { stringValue: s.phone },
      status: { stringValue: s.status },
      createdAt: { timestampValue: now },
    }, token);
    console.log(`  ✓ Signup Petition: ${s.fullName} (${s.studentId})`);
  }

  // 5. Pending Semester Promotion Requests
  console.log('🎓 Seeding pending semester upgrade requests...');
  const semesterRequests = [
    {
      id: 'sem_req_arif',
      studentId: 'uid_student_arif',
      studentName: 'Ariful Islam',
      studentRoll: '2022CSE028',
      currentYear: 2,
      currentSemester: 2,
      requestedYear: 3,
      requestedSemester: 1,
      status: 'PENDING',
    },
  ];

  for (const sm of semesterRequests) {
    await setDoc('semesterUpgradeRequests', sm.id, {
      id: { stringValue: sm.id },
      studentId: { stringValue: sm.studentId },
      studentName: { stringValue: sm.studentName },
      studentRoll: { stringValue: sm.studentRoll },
      currentYear: { integerValue: String(sm.currentYear) },
      currentSemester: { integerValue: String(sm.currentSemester) },
      requestedYear: { integerValue: String(sm.requestedYear) },
      requestedSemester: { integerValue: String(sm.requestedSemester) },
      status: { stringValue: sm.status },
      createdAt: { timestampValue: now },
    }, token);
    console.log(`  ✓ Semester Petition: ${sm.studentName} (${sm.studentRoll})`);
  }

  // 6. Active Attendance Session
  console.log('📋 Seeding active attendance session...');
  await setDoc('attendanceSessions', 'sess_active_3101', {
    id: { stringValue: 'sess_active_3101' },
    courseId: { stringValue: 'CSE-3101' },
    courseCode: { stringValue: 'CSE-3101' },
    courseTitle: { stringValue: 'Operating Systems' },
    teacherId: { stringValue: 'teacher_layek_uid' },
    teacherName: { stringValue: 'Dr. Md. Abu Layek' },
    code: { stringValue: '849201' },
    isActive: { booleanValue: true },
    status: { stringValue: 'ACTIVE' },
    sessionDate: { stringValue: new Date().toISOString().substring(0, 10) },
    totalPresentCount: { integerValue: '42' },
    createdAt: { timestampValue: now },
  }, token);
  console.log('  ✓ Active Session: CSE-3101 (Code: 849201)');

  // 7. Course & Faculty Feedback
  console.log('💬 Seeding anonymous student feedback...');
  await setDoc('feedback', 'fb_os_layek', {
    id: { stringValue: 'fb_os_layek' },
    courseId: { stringValue: 'CSE-3101' },
    courseCode: { stringValue: 'CSE-3101' },
    courseTitle: { stringValue: 'Operating Systems' },
    teacherId: { stringValue: 'teacher_layek_uid' },
    teacherName: { stringValue: 'Dr. Md. Abu Layek' },
    rating: { integerValue: '5' },
    comments: { stringValue: 'The OS process scheduling lectures and lab tasks are structured exceptionally well.' },
    isAnonymous: { booleanValue: true },
    replies: { arrayValue: { values: [] } },
    attachments: { arrayValue: { values: [] } },
    createdAt: { timestampValue: now },
  }, token);
  console.log('  ✓ Anonymous Feedback: CSE-3101');

  console.log('\n✅ Firestore demo data seeded successfully!');
}

seed().catch(console.error);
