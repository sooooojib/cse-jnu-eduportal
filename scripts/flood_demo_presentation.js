#!/usr/bin/env node

/**
 * Rich Presentation Demo Seeder for CSE JnU EduPortal
 * Floods Firestore with comprehensive, interconnected TODAY (2026-11-18) & weekly data
 * for Student (Y4S2), CR (Y4S1), Teacher (Dr. Md. Abu Layek), and Admin demo accounts.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'sajib-73b14';

// Real logged-in demo account UIDs in Firebase Auth & Firestore
const STUDENT_UID = '0MGtt2JRPiWj2gdyvbhvrb1uqc82'; // Tanvir Rahman (Student) - Y4S2
const CR_UID = 'oKuNcNUSF8Q7iGBUi0InC1mkpR32';       // Kamrul Hasan (CR) - Y4S1
const TEACHER_UID = 'nuZsDH0TCLa2GxOwJLDbcv1kiGr2';  // Dr. Md. Abu Layek - TEACHER
const ADMIN1_UID = 'HSV1KjrsbiRZwDcCpSONPTafMNg2';   // admin@cse.jnu.ac.bd
const ADMIN2_UID = 'm9D12Dz4n8bSFSXvsMkizbkfDSJ2';   // cseadmin@cse.jnu.ac.bd

function getAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  return config.tokens.access_token;
}

function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    if (Number.isInteger(val)) return { integerValue: val.toString() };
    return { doubleValue: val };
  }
  if (typeof val === 'string') {
    if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3,6})?Z$/.test(val)) {
      return { timestampValue: val };
    }
    return { stringValue: val };
  }
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(toFirestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      fields[k] = toFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function toFirestoreFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    fields[k] = toFirestoreValue(v);
  }
  return fields;
}

async function setDoc(collection, docId, data, token) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${encodeURIComponent(docId)}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: toFirestoreFields(data) }),
  });
  if (!res.ok) {
    const err = await res.text();
    console.error(`\nFailed ${collection}/${docId}: ${err}`);
  } else {
    process.stdout.write('.');
  }
}

async function updateDocFields(collection, docId, data, token) {
  const mask = Object.keys(data).map((k) => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${encodeURIComponent(docId)}?${mask}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: toFirestoreFields(data) }),
  });
  if (!res.ok) {
    const err = await res.text();
    console.error(`\nFailed update ${collection}/${docId}: ${err}`);
  } else {
    process.stdout.write('.');
  }
}

async function runPool(tasks, concurrency = 10) {
  let idx = 0;
  async function worker() {
    while (idx < tasks.length) {
      const current = idx++;
      await tasks[current]();
    }
  }
  const workers = Array.from({ length: Math.min(concurrency, tasks.length) }, worker);
  await Promise.all(workers);
}

async function main() {
  const token = getAccessToken();
  const nowDate = new Date();
  const now = nowDate.toISOString();
  const hoursAgo = (h) => new Date(nowDate.getTime() - h * 3600000).toISOString();
  const hoursFromNow = (h) => new Date(nowDate.getTime() + h * 3600000).toISOString();
  const daysFromNowStr = (d) => {
    const dt = new Date(nowDate.getTime() + d * 86400000);
    return dt.toISOString().slice(0, 10);
  };

  const TODAY = daysFromNowStr(0);      // 2026-11-18 (Wednesday)
  const TOMORROW = daysFromNowStr(1);   // 2026-11-19 (Thursday)
  const DAY_PLUS_2 = daysFromNowStr(2); // 2026-11-20
  const DAY_PLUS_3 = daysFromNowStr(3); // 2026-11-21
  const DAY_PLUS_4 = daysFromNowStr(4); // 2026-11-22
  const DAY_PLUS_5 = daysFromNowStr(5); // 2026-11-23
  const DAY_PLUS_6 = daysFromNowStr(6); // 2026-11-24
  const DAY_PLUS_8 = daysFromNowStr(8); // 2026-11-26
  const DAY_PLUS_10 = daysFromNowStr(10); // 2026-11-28

  console.log(`Starting Rich Presentation Flood for TODAY = ${TODAY} (Wednesday)`);

  const ops = [];

  // ─── 1. ENSURE COURSES & TEACHER ASSIGNMENTS LINKED TO REAL TEACHER UID ─────
  const courses = [
    { code: 'CSE-4201', title: 'Cloud Computing & Distributed Systems', credit: 3.0, year: 4, semester: 2, courseType: 'THEORY', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', coordinatorId: TEACHER_UID, description: 'Distributed consensus (Raft, Paxos), cloud-native microservices, Kubernetes, fault-tolerant storage.' },
    { code: 'CSE-4203', title: 'Computer Graphics & Image Processing', credit: 3.0, year: 4, semester: 2, courseType: 'THEORY', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', coordinatorId: 'teacher_uzzal_uid', description: '3D rendering pipelines, ray tracing, shading models, OpenCV image restoration & segmentation.' },
    { code: 'CSE-4204', title: 'Computer Graphics & Vision Lab', credit: 1.5, year: 4, semester: 2, courseType: 'LAB', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', coordinatorId: 'teacher_uzzal_uid', description: 'OpenGL GLSL shaders, 3D scene transformations, real-time object detection lab.' },
    { code: 'CSE-4205', title: 'Deep Learning & Generative AI', credit: 3.0, year: 4, semester: 2, courseType: 'THEORY', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', coordinatorId: 'teacher_nasir_uid', description: 'Transformers, attention mechanisms, diffusion models, reinforcement learning, fine-tuning LLMs.' },
    { code: 'CSE-4206', title: 'Undergraduate Thesis & Project Defense', credit: 3.0, year: 4, semester: 2, courseType: 'LAB', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', coordinatorId: TEACHER_UID, description: 'Final year capstone research supervision, publication preparation, and live system defense.' },
    { code: 'CSE-4107', title: 'Distributed Systems & Cloud Architecture', credit: 3.0, year: 4, semester: 1, courseType: 'THEORY', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', coordinatorId: TEACHER_UID, description: 'Distributed transactions, RPCs, CAP theorem, serverless computing, cloud security.' },
    { code: 'CSE-4101', title: 'Compiler Design', credit: 3.0, year: 4, semester: 1, courseType: 'THEORY', teacherId: 'teacher_hanif_uid', teacherName: 'Dr. Md. Abu Hanif Sarkar', coordinatorId: 'teacher_hanif_uid', description: 'Lexical analysis, LL(1)/LALR(1) parsing, semantic analysis, LLVM intermediate code.' },
    { code: 'CSE-4102', title: 'Compiler Design Lab', credit: 1.5, year: 4, semester: 1, courseType: 'LAB', teacherId: 'teacher_hanif_uid', teacherName: 'Dr. Md. Abu Hanif Sarkar', coordinatorId: 'teacher_hanif_uid', description: 'Flex/Bison lexer and parser implementation for custom subset of C.' },
    { code: 'CSE-4103', title: 'Machine Learning', credit: 3.0, year: 4, semester: 1, courseType: 'THEORY', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', coordinatorId: 'teacher_nasir_uid', description: 'Supervised/unsupervised learning, SVMs, random forests, backpropagation, evaluation metrics.' },
    { code: 'CSE-4105', title: 'Cryptography & Information Security', credit: 3.0, year: 4, semester: 1, courseType: 'THEORY', teacherId: 'teacher_nayeema_uid', teacherName: 'Nayeema Islam', coordinatorId: 'teacher_nayeema_uid', description: 'AES, RSA, Elliptic Curve Cryptography, TLS 1.3, zero-trust security architecture.' },
    { code: 'CSE-3101', title: 'Operating Systems', credit: 3.0, year: 3, semester: 1, courseType: 'THEORY', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', coordinatorId: TEACHER_UID, description: 'Kernel architecture, CPU scheduling, deadlock avoidance, virtual memory paging, ext4.' },
    { code: 'CSE-3102', title: 'Operating Systems Lab', credit: 1.5, year: 3, semester: 1, courseType: 'LAB', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', coordinatorId: TEACHER_UID, description: 'POSIX pthreads, semaphores, custom Linux shell, system calls.' },
    { code: 'CSE-3103', title: 'Microprocessors & Assembly Language', credit: 3.0, year: 3, semester: 1, courseType: 'THEORY', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', coordinatorId: TEACHER_UID, description: 'x86 architecture, 8086 registers, interrupt vectors, peripheral interfacing.' },
    { code: 'CSE-3105', title: 'Software Engineering & Design Patterns', credit: 3.0, year: 3, semester: 1, courseType: 'THEORY', teacherId: 'teacher_selina_uid', teacherName: 'Dr. Selina Sharmin', coordinatorId: 'teacher_selina_uid', description: 'Clean Architecture, SOLID principles, Agile sprints, UML, automated testing.' },
    { code: 'CSE-2101', title: 'Algorithms Design & Analysis', credit: 3.0, year: 2, semester: 1, courseType: 'THEORY', teacherId: 'teacher_aminul_uid', teacherName: 'Dr. Md. Aminul Islam', coordinatorId: 'teacher_aminul_uid', description: 'Dynamic programming, greedy algorithms, graph flows, NP-completeness.' },
    { code: 'CSE-1101', title: 'Structured Programming Language', credit: 3.0, year: 1, semester: 1, courseType: 'THEORY', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', coordinatorId: TEACHER_UID, description: 'C syntax, pointers, structs, dynamic memory management, file I/O.' },
  ];

  for (const c of courses) {
    ops.push(() => setDoc('courses', c.code, { ...c, id: c.code, createdAt: now, updatedAt: now }, token));
  }

  // Ensure Dr. Md. Abu Layek (logged-in Teacher) has CSE-4201 & CSE-4206 in his assignedCourseIds too
  ops.push(() =>
    updateDocFields(
      'users',
      TEACHER_UID,
      {
        assignedCourseIds: ['CSE-4201', 'CSE-4206', 'CSE-4107', 'CSE-3101', 'CSE-3102', 'CSE-3103', 'CSE-1101'],
        updatedAt: now,
      },
      token
    )
  );

  // ─── 2. HEAVY CLASS SCHEDULE FLOOD (TODAY WEDNESDAY + TOMORROW THURSDAY + FULL WEEK) ───
  // Written to BOTH 'schedules' AND 'scheduleSlots' so Student, CR, and Teacher dashboards ALL show rich classes!
  const scheduleDefs = [
    // === WEDNESDAY (TODAY!) — Y4S2 (Student Demo Account) ===
    { id: 'demo2026_wed_y4s2_1', courseId: 'CSE-4201', courseCode: 'CSE-4201', courseTitle: 'Cloud Computing & Distributed Systems', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'WEDNESDAY', startTime: '09:00 AM', endTime: '10:30 AM', room: 'Room 402, Science Bldg', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_wed_y4s2_2', courseId: 'CSE-4203', courseCode: 'CSE-4203', courseTitle: 'Computer Graphics & Image Processing', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', dayOfWeek: 'WEDNESDAY', startTime: '10:30 AM', endTime: '12:00 PM', room: 'Room 501, Dept of CSE', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_wed_y4s2_3', courseId: 'CSE-4205', courseCode: 'CSE-4205', courseTitle: 'Deep Learning & Generative AI', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', dayOfWeek: 'WEDNESDAY', startTime: '12:15 PM', endTime: '01:45 PM', room: 'AI Research Lab (Room 503)', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_wed_y4s2_4', courseId: 'CSE-4204', courseCode: 'CSE-4204', courseTitle: 'Computer Graphics & Vision Lab', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', dayOfWeek: 'WEDNESDAY', startTime: '02:30 PM', endTime: '04:30 PM', room: 'Software Lab 3', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_wed_y4s2_5', courseId: 'CSE-4206', courseCode: 'CSE-4206', courseTitle: 'Thesis & Capstone Review Session', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'WEDNESDAY', startTime: '04:30 PM', endTime: '05:30 PM', room: 'Seminar Library (5th Floor)', targetYear: 4, targetSemester: 2, isExtraClass: true },

    // === WEDNESDAY (TODAY!) — Y4S1 (CR Demo Account) ===
    { id: 'demo2026_wed_y4s1_1', courseId: 'CSE-4101', courseCode: 'CSE-4101', courseTitle: 'Compiler Design', teacherId: 'teacher_hanif_uid', teacherName: 'Dr. Md. Abu Hanif Sarkar', dayOfWeek: 'WEDNESDAY', startTime: '09:00 AM', endTime: '10:30 AM', room: 'Room 401, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_wed_y4s1_2', courseId: 'CSE-4107', courseCode: 'CSE-4107', courseTitle: 'Distributed Systems & Cloud Architecture', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'WEDNESDAY', startTime: '10:45 AM', endTime: '12:15 PM', room: 'Room 402, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_wed_y4s1_3', courseId: 'CSE-4103', courseCode: 'CSE-4103', courseTitle: 'Machine Learning', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', dayOfWeek: 'WEDNESDAY', startTime: '01:00 PM', endTime: '02:30 PM', room: 'Room 403, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_wed_y4s1_4', courseId: 'CSE-4105', courseCode: 'CSE-4105', courseTitle: 'Cryptography & Information Security', teacherId: 'teacher_nayeema_uid', teacherName: 'Nayeema Islam', dayOfWeek: 'WEDNESDAY', startTime: '02:45 PM', endTime: '04:15 PM', room: 'Cyber Security Lab (Room 405)', targetYear: 4, targetSemester: 1, isExtraClass: false },

    // === WEDNESDAY (TODAY!) — Y3S1 (Teacher + 3rd Year Cohort) ===
    { id: 'demo2026_wed_y3s1_1', courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'Operating Systems', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'WEDNESDAY', startTime: '12:30 PM', endTime: '02:00 PM', room: 'Room 302, Block A', targetYear: 3, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_wed_y3s1_2', courseId: 'CSE-3102', courseCode: 'CSE-3102', courseTitle: 'Operating Systems Lab', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'WEDNESDAY', startTime: '02:30 PM', endTime: '04:00 PM', room: 'Software Lab 1', targetYear: 3, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_wed_y3s1_3', courseId: 'CSE-3105', courseCode: 'CSE-3105', courseTitle: 'Software Engineering & Design Patterns', teacherId: 'teacher_selina_uid', teacherName: 'Dr. Selina Sharmin', dayOfWeek: 'WEDNESDAY', startTime: '09:30 AM', endTime: '11:00 AM', room: 'Room 304, Block A', targetYear: 3, targetSemester: 1, isExtraClass: false },

    // === THURSDAY (TOMORROW!) — Y4S2, Y4S1, Y3S1 ===
    { id: 'demo2026_thu_y4s2_1', courseId: 'CSE-4201', courseCode: 'CSE-4201', courseTitle: 'Cloud Computing & Distributed Systems', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'THURSDAY', startTime: '09:30 AM', endTime: '11:00 AM', room: 'Room 402, Science Bldg', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_thu_y4s2_2', courseId: 'CSE-4205', courseCode: 'CSE-4205', courseTitle: 'Deep Learning & Generative AI', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', dayOfWeek: 'THURSDAY', startTime: '11:15 AM', endTime: '12:45 PM', room: 'AI Research Lab (Room 503)', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_thu_y4s2_3', courseId: 'CSE-4203', courseCode: 'CSE-4203', courseTitle: 'Computer Graphics & Image Processing', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', dayOfWeek: 'THURSDAY', startTime: '02:00 PM', endTime: '03:30 PM', room: 'Room 501, Dept of CSE', targetYear: 4, targetSemester: 2, isExtraClass: false },

    { id: 'demo2026_thu_y4s1_1', courseId: 'CSE-4105', courseCode: 'CSE-4105', courseTitle: 'Cryptography & Information Security', teacherId: 'teacher_nayeema_uid', teacherName: 'Nayeema Islam', dayOfWeek: 'THURSDAY', startTime: '09:00 AM', endTime: '10:30 AM', room: 'Room 401, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_thu_y4s1_2', courseId: 'CSE-4107', courseCode: 'CSE-4107', courseTitle: 'Distributed Systems & Cloud Architecture', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'THURSDAY', startTime: '11:15 AM', endTime: '12:45 PM', room: 'Room 402, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_thu_y4s1_3', courseId: 'CSE-4102', courseCode: 'CSE-4102', courseTitle: 'Compiler Design Lab', teacherId: 'teacher_hanif_uid', teacherName: 'Dr. Md. Abu Hanif Sarkar', dayOfWeek: 'THURSDAY', startTime: '02:00 PM', endTime: '04:30 PM', room: 'Software Lab 2', targetYear: 4, targetSemester: 1, isExtraClass: false },

    { id: 'demo2026_thu_y3s1_1', courseId: 'CSE-3103', courseCode: 'CSE-3103', courseTitle: 'Microprocessors & Assembly Language', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'THURSDAY', startTime: '02:00 PM', endTime: '03:30 PM', room: 'Hardware Lab 2', targetYear: 3, targetSemester: 1, isExtraClass: false },

    // === SUNDAY, MONDAY, TUESDAY, FRIDAY, SATURDAY (Full Weekly Coverage) ===
    { id: 'demo2026_sun_y4s2_1', courseId: 'CSE-4201', courseCode: 'CSE-4201', courseTitle: 'Cloud Computing & Distributed Systems', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'SUNDAY', startTime: '09:00 AM', endTime: '10:30 AM', room: 'Room 402, Science Bldg', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_sun_y4s2_2', courseId: 'CSE-4203', courseCode: 'CSE-4203', courseTitle: 'Computer Graphics & Image Processing', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', dayOfWeek: 'SUNDAY', startTime: '11:00 AM', endTime: '12:30 PM', room: 'Room 501, Dept of CSE', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_sun_y4s1_1', courseId: 'CSE-4103', courseCode: 'CSE-4103', courseTitle: 'Machine Learning', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', dayOfWeek: 'SUNDAY', startTime: '10:00 AM', endTime: '11:30 AM', room: 'Room 401, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_sun_y4s1_2', courseId: 'CSE-4107', courseCode: 'CSE-4107', courseTitle: 'Distributed Systems & Cloud Architecture', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'SUNDAY', startTime: '01:00 PM', endTime: '02:30 PM', room: 'Room 402, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },

    { id: 'demo2026_mon_y4s2_1', courseId: 'CSE-4205', courseCode: 'CSE-4205', courseTitle: 'Deep Learning & Generative AI', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', dayOfWeek: 'MONDAY', startTime: '09:30 AM', endTime: '11:00 AM', room: 'AI Research Lab (Room 503)', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_mon_y4s2_2', courseId: 'CSE-4204', courseCode: 'CSE-4204', courseTitle: 'Computer Graphics & Vision Lab', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', dayOfWeek: 'MONDAY', startTime: '02:00 PM', endTime: '04:30 PM', room: 'Software Lab 3', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_mon_y4s1_1', courseId: 'CSE-4101', courseCode: 'CSE-4101', courseTitle: 'Compiler Design', teacherId: 'teacher_hanif_uid', teacherName: 'Dr. Md. Abu Hanif Sarkar', dayOfWeek: 'MONDAY', startTime: '10:30 AM', endTime: '12:00 PM', room: 'Room 401, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_mon_y3s1_1', courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'Operating Systems', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'MONDAY', startTime: '09:00 AM', endTime: '10:30 AM', room: 'Room 302, Block A', targetYear: 3, targetSemester: 1, isExtraClass: false },

    { id: 'demo2026_tue_y4s2_1', courseId: 'CSE-4201', courseCode: 'CSE-4201', courseTitle: 'Cloud Computing & Distributed Systems', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'TUESDAY', startTime: '10:00 AM', endTime: '11:30 AM', room: 'Room 402, Science Bldg', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_tue_y4s2_2', courseId: 'CSE-4206', courseCode: 'CSE-4206', courseTitle: 'Undergraduate Thesis & Project Defense', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'TUESDAY', startTime: '02:30 PM', endTime: '04:30 PM', room: 'Seminar Library (5th Floor)', targetYear: 4, targetSemester: 2, isExtraClass: false },
    { id: 'demo2026_tue_y4s1_1', courseId: 'CSE-4105', courseCode: 'CSE-4105', courseTitle: 'Cryptography & Information Security', teacherId: 'teacher_nayeema_uid', teacherName: 'Nayeema Islam', dayOfWeek: 'TUESDAY', startTime: '09:00 AM', endTime: '10:30 AM', room: 'Room 405, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },
    { id: 'demo2026_tue_y4s1_2', courseId: 'CSE-4103', courseCode: 'CSE-4103', courseTitle: 'Machine Learning', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', dayOfWeek: 'TUESDAY', startTime: '11:30 AM', endTime: '01:00 PM', room: 'Room 403, Science Bldg', targetYear: 4, targetSemester: 1, isExtraClass: false },

    // Special Extra Lab/Seminar on Saturday for demo completeness
    { id: 'demo2026_sat_y4s2_1', courseId: 'CSE-4206', courseCode: 'CSE-4206', courseTitle: 'Thesis Presentation & Mock Defense', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'SATURDAY', startTime: '10:00 AM', endTime: '12:00 PM', room: 'Seminar Library (5th Floor)', targetYear: 4, targetSemester: 2, isExtraClass: true },
    { id: 'demo2026_sat_y4s1_1', courseId: 'CSE-4107', courseCode: 'CSE-4107', courseTitle: 'Cloud Architecture Workshop (Extra)', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', dayOfWeek: 'SATURDAY', startTime: '02:00 PM', endTime: '03:30 PM', room: 'Software Lab 1', targetYear: 4, targetSemester: 1, isExtraClass: true },
  ];

  for (const s of scheduleDefs) {
    const docData = {
      ...s,
      status: 'SCHEDULED',
      createdBy: TEACHER_UID,
      createdByCrId: CR_UID,
      creatorRole: 'TEACHER',
      createdAt: now,
      updatedAt: now,
    };
    ops.push(() => setDoc('schedules', s.id, docData, token));
    ops.push(() => setDoc('scheduleSlots', s.id, docData, token));
  }

  // ─── 3. UPCOMING & TODAY EXAMS (TODAY, TOMORROW, NEXT 10 DAYS) ──────────────
  const exams = [
    // Y4S2 (Student Demo Account)
    { id: 'demo2026_exam_4201_today', courseId: 'CSE-4201', courseCode: 'CSE-4201', courseTitle: 'Cloud Computing & Distributed Systems', title: 'Class Test 2: Consensus & Raft Protocol', type: 'CLASS_TEST', examDate: TODAY, startTime: '10:30 AM', endTime: '11:30 AM', room: 'Room 402, Science Bldg', year: 4, semester: 2, invigilatorId: TEACHER_UID, invigilatorName: 'Dr. Md. Abu Layek', instructions: 'Closed book assessment. Bring student ID card.' },
    { id: 'demo2026_exam_4203_tmrw', courseId: 'CSE-4203', courseCode: 'CSE-4203', courseTitle: 'Computer Graphics & Image Processing', title: 'Midterm Assessment 2', type: 'MIDTERM', examDate: TOMORROW, startTime: '11:00 AM', endTime: '12:30 PM', room: 'Room 501, Dept of CSE', year: 4, semester: 2, invigilatorId: 'teacher_uzzal_uid', invigilatorName: 'Prof. Dr. Uzzal Kumar Acharjee', instructions: 'Scientific calculators permitted.' },
    { id: 'demo2026_exam_4205_d4', courseId: 'CSE-4205', courseCode: 'CSE-4205', courseTitle: 'Deep Learning & Generative AI', title: 'Midterm Examination (Transformers & CNNs)', type: 'MIDTERM', examDate: DAY_PLUS_4, startTime: '10:00 AM', endTime: '11:30 AM', room: 'AI Research Lab (Room 503)', year: 4, semester: 2, invigilatorId: 'teacher_nasir_uid', invigilatorName: 'Prof. Dr. Md. Nasir Uddin', instructions: 'Arrive 15 minutes prior to start.' },
    { id: 'demo2026_exam_4204_d6', courseId: 'CSE-4204', courseCode: 'CSE-4204', courseTitle: 'Computer Graphics & Vision Lab', title: 'Lab Final & Live Shader Evaluation', type: 'LAB_FINAL', examDate: DAY_PLUS_6, startTime: '02:00 PM', endTime: '04:30 PM', room: 'Software Lab 3', year: 4, semester: 2, invigilatorId: 'teacher_uzzal_uid', invigilatorName: 'Prof. Dr. Uzzal Kumar Acharjee', instructions: 'Bring project source code and lab report.' },
    { id: 'demo2026_exam_4206_d10', courseId: 'CSE-4206', courseCode: 'CSE-4206', courseTitle: 'Undergraduate Thesis & Project Defense', title: 'Final Year Project & Thesis Defense', type: 'FINAL', examDate: DAY_PLUS_10, startTime: '09:30 AM', endTime: '01:00 PM', room: 'Seminar Library (5th Floor)', year: 4, semester: 2, invigilatorId: TEACHER_UID, invigilatorName: 'Dr. Md. Abu Layek', instructions: 'Submit 3 spiral-bound thesis copies and slide deck.' },

    // Y4S1 (CR Demo Account)
    { id: 'demo2026_exam_4107_today', courseId: 'CSE-4107', courseCode: 'CSE-4107', courseTitle: 'Distributed Systems & Cloud Architecture', title: 'Quiz 2: Cloud Security & Firebase Rules', type: 'CLASS_TEST', examDate: TODAY, startTime: '11:00 AM', endTime: '12:00 PM', room: 'Room 402, Science Bldg', year: 4, semester: 1, invigilatorId: TEACHER_UID, invigilatorName: 'Dr. Md. Abu Layek', instructions: 'Bring blue/black ballpoint pen and JnU ID.' },
    { id: 'demo2026_exam_4101_tmrw', courseId: 'CSE-4101', courseCode: 'CSE-4101', courseTitle: 'Compiler Design', title: 'Midterm Assessment: Parsing & AST', type: 'MIDTERM', examDate: TOMORROW, startTime: '10:00 AM', endTime: '11:30 AM', room: 'Room 401, Science Bldg', year: 4, semester: 1, invigilatorId: 'teacher_hanif_uid', invigilatorName: 'Dr. Md. Abu Hanif Sarkar', instructions: 'Covers LL(1), LR(0), and SLR parsing tables.' },
    { id: 'demo2026_exam_4103_d5', courseId: 'CSE-4103', courseCode: 'CSE-4103', courseTitle: 'Machine Learning', title: 'Midterm Examination', type: 'MIDTERM', examDate: DAY_PLUS_5, startTime: '01:00 PM', endTime: '02:30 PM', room: 'Room 403, Science Bldg', year: 4, semester: 1, invigilatorId: 'teacher_nasir_uid', invigilatorName: 'Prof. Dr. Md. Nasir Uddin', instructions: 'Calculators allowed.' },
    { id: 'demo2026_exam_4105_d8', courseId: 'CSE-4105', courseCode: 'CSE-4105', courseTitle: 'Cryptography & Information Security', title: 'Semester Final Examination', type: 'FINAL', examDate: DAY_PLUS_8, startTime: '10:00 AM', endTime: '01:00 PM', room: 'Room 405, Science Bldg', year: 4, semester: 1, invigilatorId: 'teacher_nayeema_uid', invigilatorName: 'Nayeema Islam', instructions: 'Admit card mandatory.' },

    // Y3S1 (Teacher Demo Account + 3rd Year)
    { id: 'demo2026_exam_3101_today', courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'Operating Systems', title: 'Midterm Assessment: Process Sync & Paging', type: 'MIDTERM', examDate: TODAY, startTime: '01:00 PM', endTime: '02:30 PM', room: 'Room 302, Block A', year: 3, semester: 1, invigilatorId: TEACHER_UID, invigilatorName: 'Dr. Md. Abu Layek', instructions: 'Covers CPU scheduling, deadlocks, and virtual memory.' },
    { id: 'demo2026_exam_3102_d3', courseId: 'CSE-3102', courseCode: 'CSE-3102', courseTitle: 'Operating Systems Lab', title: 'Linux Kernel & Shell Scripting Lab Test', type: 'LAB_FINAL', examDate: DAY_PLUS_3, startTime: '02:00 PM', endTime: '04:00 PM', room: 'Software Lab 1', year: 3, semester: 1, invigilatorId: TEACHER_UID, invigilatorName: 'Dr. Md. Abu Layek', instructions: 'Live coding on Ubuntu lab workstations.' },
  ];

  for (const e of exams) {
    ops.push(() => setDoc('exams', e.id, { ...e, createdBy: TEACHER_UID, creatorRole: 'TEACHER', createdAt: now, updatedAt: now }, token));
  }

  // ─── 4. LIVE ATTENDANCE SESSIONS (TODAY) + RICH HISTORICAL ROSTERS ──────────
  const liveSessions = [
    {
      id: 'demo2026_sess_live_4201',
      courseId: 'CSE-4201',
      courseCode: 'CSE-4201',
      courseTitle: 'Cloud Computing & Distributed Systems',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      code: 'JNU421',
      isActive: true,
      status: 'ACTIVE',
      targetYear: 4,
      targetSemester: 2,
      sessionDate: TODAY,
      startTime: now,
      expiresAt: hoursFromNow(8), // Stays active for the whole demo day!
      totalPresentCount: 9,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'demo2026_sess_live_4107',
      courseId: 'CSE-4107',
      courseCode: 'CSE-4107',
      courseTitle: 'Distributed Systems & Cloud Architecture',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      code: 'JNU417',
      isActive: true,
      status: 'ACTIVE',
      targetYear: 4,
      targetSemester: 1,
      sessionDate: TODAY,
      startTime: now,
      expiresAt: hoursFromNow(8),
      totalPresentCount: 11,
      createdAt: now,
      updatedAt: now,
    },
    {
      id: 'demo2026_sess_live_3101',
      courseId: 'CSE-3101',
      courseCode: 'CSE-3101',
      courseTitle: 'Operating Systems',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      code: 'JNU311',
      isActive: true,
      status: 'ACTIVE',
      targetYear: 3,
      targetSemester: 1,
      sessionDate: TODAY,
      startTime: now,
      expiresAt: hoursFromNow(8),
      totalPresentCount: 12,
      createdAt: now,
      updatedAt: now,
    },
  ];

  for (const s of liveSessions) {
    ops.push(() => setDoc('attendanceSessions', s.id, s, token));
  }

  // Rich attendance history for Student (Y4S2) & CR (Y4S1) so Attendance dashboard charts & percentages shine!
  const studentCourses = [
    { id: 'CSE-4201', code: 'CSE-4201', title: 'Cloud Computing & Distributed Systems', present: 11, total: 12 },
    { id: 'CSE-4203', code: 'CSE-4203', title: 'Computer Graphics & Image Processing', present: 10, total: 11 },
    { id: 'CSE-4204', code: 'CSE-4204', title: 'Computer Graphics & Vision Lab', present: 8, total: 8 },
    { id: 'CSE-4205', code: 'CSE-4205', title: 'Deep Learning & Generative AI', present: 9, total: 10 },
  ];

  for (const sc of studentCourses) {
    for (let i = 1; i <= sc.total; i++) {
      const sessId = `demo2026_hist_${sc.code}_${i}`;
      const isPresent = i <= sc.present;
      const dateStr = daysFromNowStr(-1 * (sc.total - i + 1));
      const recId = `${sessId}_${STUDENT_UID}`;
      ops.push(() =>
        setDoc(
          'attendance',
          recId,
          {
            id: recId,
            sessionId: sessId,
            studentId: STUDENT_UID,
            studentName: 'Tanvir Rahman (Student)',
            studentRoll: 'B200305025',
            courseId: sc.id,
            courseCode: sc.code,
            courseTitle: sc.title,
            status: isPresent ? 'PRESENT' : 'ABSENT',
            isManualOverride: false,
            date: dateStr,
            verifiedAt: isPresent ? hoursAgo(24 * (sc.total - i + 1)) : null,
            updatedAt: hoursAgo(24 * (sc.total - i + 1)),
          },
          token
        )
      );
    }
  }

  const crCourses = [
    { id: 'CSE-4107', code: 'CSE-4107', title: 'Distributed Systems & Cloud Architecture', present: 11, total: 12 },
    { id: 'CSE-4101', code: 'CSE-4101', title: 'Compiler Design', present: 10, total: 10 },
    { id: 'CSE-4103', code: 'CSE-4103', title: 'Machine Learning', present: 9, total: 10 },
    { id: 'CSE-4105', code: 'CSE-4105', title: 'Cryptography & Information Security', present: 8, total: 9 },
  ];

  for (const cc of crCourses) {
    for (let i = 1; i <= cc.total; i++) {
      const sessId = `demo2026_hist_${cc.code}_${i}`;
      const isPresent = i <= cc.present;
      const dateStr = daysFromNowStr(-1 * (cc.total - i + 1));
      const recId = `${sessId}_${CR_UID}`;
      ops.push(() =>
        setDoc(
          'attendance',
          recId,
          {
            id: recId,
            sessionId: sessId,
            studentId: CR_UID,
            studentName: 'Kamrul Hasan (CR)',
            studentRoll: 'B200305001',
            courseId: cc.id,
            courseCode: cc.code,
            courseTitle: cc.title,
            status: isPresent ? 'PRESENT' : 'ABSENT',
            isManualOverride: false,
            date: dateStr,
            verifiedAt: isPresent ? hoursAgo(24 * (cc.total - i + 1)) : null,
            updatedAt: hoursAgo(24 * (cc.total - i + 1)),
          },
          token
        )
      );
    }
  }

  // ─── 5. COUNSELING SLOTS & BOOKING REQUESTS (TODAY + UPCOMING) ──────────────
  const counselingSlots = [
    // Dr. Md. Abu Layek (Logged-in Teacher) - OPEN slots for today & upcoming
    { id: 'demo2026_cslot_layek_today_1', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', teacherEmail: 'teacher@cse.jnu.ac.bd', slotDate: TODAY, startTime: '11:30', endTime: '12:30', isBooked: false, status: 'AVAILABLE', notes: 'Room 502, Dept of CSE — Thesis & Cloud Systems Advising' },
    { id: 'demo2026_cslot_layek_today_2', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', teacherEmail: 'teacher@cse.jnu.ac.bd', slotDate: TODAY, startTime: '15:00', endTime: '16:00', isBooked: false, status: 'AVAILABLE', notes: 'Room 502, Dept of CSE — Academic & Project Consultation' },
    { id: 'demo2026_cslot_layek_tmrw_1', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', teacherEmail: 'teacher@cse.jnu.ac.bd', slotDate: TOMORROW, startTime: '10:30', endTime: '11:30', isBooked: false, status: 'AVAILABLE', notes: 'Room 502, Dept of CSE — Office Hours' },
    { id: 'demo2026_cslot_layek_d3', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', teacherEmail: 'teacher@cse.jnu.ac.bd', slotDate: DAY_PLUS_3, startTime: '14:00', endTime: '15:00', isBooked: false, status: 'AVAILABLE', notes: 'Room 502, Dept of CSE — Research Paper Review' },

    // Booked slot for Student (with professor message!)
    { id: 'demo2026_cslot_layek_booked_stu', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', teacherEmail: 'teacher@cse.jnu.ac.bd', slotDate: TOMORROW, startTime: '14:00', endTime: '14:45', isBooked: true, status: 'BOOKED', bookedStudentId: STUDENT_UID, bookedStudentName: 'Tanvir Rahman (Student)', bookedBookingId: 'demo2026_cbook_stu_approved', notes: 'Room 502, Dept of CSE' },

    // Booked slot for CR (with professor message!)
    { id: 'demo2026_cslot_layek_booked_cr', teacherId: TEACHER_UID, teacherName: 'Dr. Md. Abu Layek', teacherEmail: 'teacher@cse.jnu.ac.bd', slotDate: DAY_PLUS_2, startTime: '11:00', endTime: '11:45', isBooked: true, status: 'BOOKED', bookedStudentId: CR_UID, bookedStudentName: 'Kamrul Hasan (CR)', bookedBookingId: 'demo2026_cbook_cr_approved', notes: 'Room 502, Dept of CSE' },

    // Other Senior JnU CSE Professors — OPEN slots
    { id: 'demo2026_cslot_uzzal_today', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', teacherEmail: 'uzzal@cse.jnu.ac.bd', slotDate: TODAY, startTime: '14:00', endTime: '15:00', isBooked: false, status: 'AVAILABLE', notes: 'Chairman Office, Room 501 — Vision Research & Thesis' },
    { id: 'demo2026_cslot_nasir_tmrw', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', teacherEmail: 'nasir@cse.jnu.ac.bd', slotDate: TOMORROW, startTime: '10:00', endTime: '11:30', isBooked: false, status: 'AVAILABLE', notes: 'Room 503, Dept of CSE — AI & Deep Learning Guidance' },
    { id: 'demo2026_cslot_selina_d2', teacherId: 'teacher_selina_uid', teacherName: 'Dr. Selina Sharmin', teacherEmail: 'selina@cse.jnu.ac.bd', slotDate: DAY_PLUS_2, startTime: '13:00', endTime: '14:30', isBooked: false, status: 'AVAILABLE', notes: 'Room 504, Dept of CSE — Software Architecture & Career Advising' },
    { id: 'demo2026_cslot_sajeeb_d3', teacherId: 'teacher_sajeeb_uid', teacherName: 'Dr. Sajeeb Saha', teacherEmail: 'sajeeb@cse.jnu.ac.bd', slotDate: DAY_PLUS_3, startTime: '11:00', endTime: '12:30', isBooked: false, status: 'AVAILABLE', notes: 'Room 505, Dept of CSE — Networks & IoT Lab Guidance' },
    { id: 'demo2026_cslot_aminul_d4', teacherId: 'teacher_aminul_uid', teacherName: 'Dr. Md. Aminul Islam', teacherEmail: 'aminul@cse.jnu.ac.bd', slotDate: DAY_PLUS_4, startTime: '10:30', endTime: '12:00', isBooked: false, status: 'AVAILABLE', notes: 'Room 506, Dept of CSE — ICPC & Algorithm Coaching' },
  ];

  for (const cs of counselingSlots) {
    ops.push(() => setDoc('counselingSlots', cs.id, { ...cs, createdAt: now, updatedAt: now }, token));
  }

  // Counseling Bookings (Approved with teacherMessage + Pending requests for Teacher to approve live!)
  const counselingBookings = [
    {
      id: 'demo2026_cbook_stu_approved',
      slotId: 'demo2026_cslot_layek_booked_stu',
      studentId: STUDENT_UID,
      studentName: 'Tanvir Rahman (Student)',
      studentEmail: 'student2026@cse.jnu.ac.bd',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      slotDate: TOMORROW,
      startTime: '14:00',
      endTime: '14:45',
      category: 'Thesis / Project',
      notes: 'Reviewing final architecture diagrams and Firestore security rules for EduPortal thesis defense.',
      teacherMessage: 'Approved! Please bring your printed system architecture diagrams and test coverage report to Room 502 at 14:00 sharp.',
      status: 'APPROVED',
      reviewedAt: hoursAgo(2),
      createdAt: hoursAgo(6),
      updatedAt: hoursAgo(2),
    },
    {
      id: 'demo2026_cbook_cr_approved',
      slotId: 'demo2026_cslot_layek_booked_cr',
      studentId: CR_UID,
      studentName: 'Kamrul Hasan (CR)',
      studentEmail: 'cr2026@cse.jnu.ac.bd',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      slotDate: DAY_PLUS_2,
      startTime: '11:00',
      endTime: '11:45',
      category: 'Academic Advising',
      notes: 'Coordinating 4th Year 1st Semester lab evaluation schedule and makeup class slot.',
      teacherMessage: 'Confirmed. Bring the batch attendance sheet and preferred lab dates so we can finalize the notice.',
      status: 'APPROVED',
      reviewedAt: hoursAgo(3),
      createdAt: hoursAgo(10),
      updatedAt: hoursAgo(3),
    },
    // Pending requests targeting Dr. Md. Abu Layek (so Teacher Counseling Requests tab has live items to approve!)
    {
      id: 'demo2026_cbook_pending_1',
      slotId: 'demo2026_cslot_layek_today_1',
      studentId: STUDENT_UID,
      studentName: 'Tanvir Rahman (Student)',
      studentEmail: 'student2026@cse.jnu.ac.bd',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      slotDate: TODAY,
      startTime: '11:30',
      endTime: '12:30',
      category: 'Career Guidance',
      notes: 'Seeking recommendation letter guidance for M.Sc. applications in Distributed Systems.',
      status: 'PENDING',
      createdAt: hoursAgo(1),
      updatedAt: hoursAgo(1),
    },
    {
      id: 'demo2026_cbook_pending_2',
      slotId: 'demo2026_cslot_layek_today_2',
      studentId: 'student_sajib_uid',
      studentName: 'Sajib Ahmed',
      studentEmail: 'sajib@cse.jnu.ac.bd',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      slotDate: TODAY,
      startTime: '15:00',
      endTime: '16:00',
      category: 'Course Difficulty',
      notes: 'Need clarification on POSIX semaphore synchronization lab assignment and deadlock detection.',
      status: 'PENDING',
      createdAt: hoursAgo(2),
      updatedAt: hoursAgo(2),
    },
    {
      id: 'demo2026_cbook_pending_3',
      slotId: 'demo2026_cslot_layek_tmrw_1',
      studentId: 'student_rahim_uid',
      studentName: 'Rahim Ullah',
      studentEmail: 'rahim@cse.jnu.ac.bd',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      slotDate: TOMORROW,
      startTime: '10:30',
      endTime: '11:30',
      category: 'Research Supervision',
      notes: 'Discussing IEEE conference paper draft on Cloud Autoscaling and Edge Telemetry.',
      status: 'PENDING',
      createdAt: hoursAgo(4),
      updatedAt: hoursAgo(4),
    },
    {
      id: 'demo2026_cbook_pending_4',
      slotId: 'demo2026_cslot_layek_d3',
      studentId: CR_UID,
      studentName: 'Kamrul Hasan (CR)',
      studentEmail: 'cr2026@cse.jnu.ac.bd',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      slotDate: DAY_PLUS_3,
      startTime: '14:00',
      endTime: '15:00',
      category: 'Thesis / Project',
      notes: 'Requesting feedback on capstone mobile deployment and Firebase App Check security audit.',
      status: 'PENDING',
      createdAt: hoursAgo(5),
      updatedAt: hoursAgo(5),
    },
  ];

  for (const cb of counselingBookings) {
    ops.push(() => setDoc('counselingBookings', cb.id, cb, token));
  }

  // ─── 6. FEEDBACK & PROFESSOR REPLIES (NAMED & ANONYMOUS) ────────────────────
  const feedbacks = [
    {
      id: 'demo2026_fb_1',
      courseId: 'CSE-4201',
      courseCode: 'CSE-4201',
      courseTitle: 'Cloud Computing & Distributed Systems',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      studentId: 'ANONYMOUS',
      studentName: 'Anonymous Student',
      studentEmail: null,
      realStudentId: STUDENT_UID,
      isAnonymous: true,
      rating: 5,
      comments: 'The live walkthrough of Raft leader election and Firebase transaction locking made distributed consensus super intuitive. Best lecture of the semester!',
      attachments: [],
      hasReplied: true,
      replies: [
        {
          id: 'rep_demo_1',
          teacherId: TEACHER_UID,
          teacherName: 'Dr. Md. Abu Layek',
          replyText: 'Thank you for the thoughtful feedback! Next week we will benchmark multi-region Firestore replication and failover recovery.',
          createdAt: hoursAgo(2),
        },
      ],
      createdAt: hoursAgo(6),
      updatedAt: hoursAgo(2),
    },
    {
      id: 'demo2026_fb_2',
      courseId: 'CSE-4107',
      courseCode: 'CSE-4107',
      courseTitle: 'Distributed Systems & Cloud Architecture',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      studentId: CR_UID,
      studentName: 'Kamrul Hasan (CR)',
      studentEmail: 'cr2026@cse.jnu.ac.bd',
      realStudentId: CR_UID,
      isAnonymous: false,
      rating: 5,
      comments: 'Could we please have an extra tutorial session on Cloud Functions security rules and atomic transactions before the upcoming quiz?',
      attachments: [],
      hasReplied: false,
      replies: [],
      createdAt: hoursAgo(3),
      updatedAt: hoursAgo(3),
    },
    {
      id: 'demo2026_fb_3',
      courseId: 'CSE-3101',
      courseCode: 'CSE-3101',
      courseTitle: 'Operating Systems',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      studentId: 'ANONYMOUS',
      studentName: 'Anonymous Student',
      studentEmail: null,
      realStudentId: 'student_sajib_uid',
      isAnonymous: true,
      rating: 4,
      comments: 'Virtual memory paging examples were crystal clear. Adding 2 more numerical problems on multi-level page tables to the slides would be very helpful.',
      attachments: [],
      hasReplied: false,
      replies: [],
      createdAt: hoursAgo(8),
      updatedAt: hoursAgo(8),
    },
    {
      id: 'demo2026_fb_4',
      courseId: 'CSE-4203',
      courseCode: 'CSE-4203',
      courseTitle: 'Computer Graphics & Image Processing',
      teacherId: 'teacher_uzzal_uid',
      teacherName: 'Prof. Dr. Uzzal Kumar Acharjee',
      studentId: STUDENT_UID,
      studentName: 'Tanvir Rahman (Student)',
      studentEmail: 'student2026@cse.jnu.ac.bd',
      realStudentId: STUDENT_UID,
      isAnonymous: false,
      rating: 5,
      comments: 'Loved the hands-on OpenGL shader demo and Phong illumination visualization in Software Lab 3.',
      attachments: [],
      hasReplied: true,
      replies: [
        {
          id: 'rep_demo_4',
          teacherId: 'teacher_uzzal_uid',
          teacherName: 'Prof. Dr. Uzzal Kumar Acharjee',
          replyText: 'Glad you enjoyed it, Tanvir! Keep polishing your final project shader pipeline for next week.',
          createdAt: hoursAgo(5),
        },
      ],
      createdAt: hoursAgo(14),
      updatedAt: hoursAgo(5),
    },
    {
      id: 'demo2026_fb_5',
      courseId: 'CSE-3102',
      courseCode: 'CSE-3102',
      courseTitle: 'Operating Systems Lab',
      teacherId: TEACHER_UID,
      teacherName: 'Dr. Md. Abu Layek',
      studentId: 'ANONYMOUS',
      studentName: 'Anonymous Student',
      studentEmail: null,
      realStudentId: 'student_rahim_uid',
      isAnonymous: true,
      rating: 5,
      comments: 'Building our own custom Unix shell with piping and background process signals was challenging but super rewarding.',
      attachments: [],
      hasReplied: true,
      replies: [
        {
          id: 'rep_demo_5',
          teacherId: TEACHER_UID,
          teacherName: 'Dr. Md. Abu Layek',
          replyText: 'Great work! Hands-on systems programming is the best way to master OS internals.',
          createdAt: hoursAgo(12),
        },
      ],
      createdAt: hoursAgo(20),
      updatedAt: hoursAgo(12),
    },
  ];

  for (const fb of feedbacks) {
    const { realStudentId, ...publicFb } = fb;
    ops.push(() => setDoc('feedback', fb.id, publicFb, token));
    ops.push(() =>
      setDoc(
        'feedbackIdentities',
        fb.id,
        {
          id: fb.id,
          feedbackId: fb.id,
          studentId: realStudentId,
          teacherId: fb.teacherId,
          isAnonymous: fb.isAnonymous,
          createdAt: fb.createdAt,
          updatedAt: fb.updatedAt,
        },
        token
      )
    );
  }

  // ─── 7. FRESH NOTICES (TODAY & RECENT) ──────────────────────────────────────
  const notices = [
    {
      id: 'demo2026_notice_defense',
      title: 'Live Project & Thesis Presentation Schedule — Autumn 2026',
      message: 'Final year B.Sc. in CSE project demonstrations and viva-voce sessions are underway today in Seminar Library (5th Floor). Students must arrive 15 minutes early with live builds and system documentation.',
      noticeType: 'ACADEMIC',
      targetAudience: 'ALL',
      priority: 'URGENT',
      sentBy: 'Office of the Chairman, Dept of CSE',
      syncedToPublicRoutines: true,
      createdAt: hoursAgo(1),
    },
    {
      id: 'demo2026_notice_exam_today',
      title: 'Updated Midterm & Class Test Schedule (Nov 18 – Nov 28, 2026)',
      message: 'All students of 3rd Year and 4th Year are informed that Class Tests and Midterm Assessments for CSE-4201, CSE-4107, CSE-4203, and CSE-3101 are published on the Exam Schedule tab. Minimum 70% attendance required.',
      noticeType: 'EXAM',
      targetAudience: 'ALL',
      priority: 'HIGH',
      sentBy: 'Academic Exam Committee, Dept of CSE',
      syncedToPublicRoutines: true,
      createdAt: hoursAgo(3),
    },
    {
      id: 'demo2026_notice_hackathon',
      title: 'JnU National CSE Fest & 24-Hour Hackathon 2026 Finalists Announced',
      message: 'Congratulations to all 32 finalist teams selected for the JnU National CSE Fest Hackathon! Opening ceremony starts this Friday at 9:00 AM in the Central Auditorium.',
      noticeType: 'EVENT',
      targetAudience: 'ALL',
      priority: 'HIGH',
      sentBy: 'JnU CSE Club & Faculty Advisors',
      syncedToPublicRoutines: false,
      createdAt: hoursAgo(7),
    },
    {
      id: 'demo2026_notice_lab_upgrade',
      title: 'AI Research Lab (Room 503) GPU Cluster Access Open for 4th Year',
      message: '4th Year thesis students enrolled in Deep Learning (CSE-4205) and Computer Vision can now request NVIDIA RTX workstation slots via their faculty supervisor.',
      noticeType: 'ROUTINE',
      targetAudience: 'STUDENTS',
      priority: 'NORMAL',
      sentBy: 'Lab Administration, Dept of CSE',
      syncedToPublicRoutines: false,
      createdAt: hoursAgo(16),
    },
  ];

  for (const n of notices) {
    ops.push(() => setDoc('notices', n.id, n, token));
  }

  // ─── 8. RICH UNREAD NOTIFICATIONS FOR ALL DEMO ACCOUNTS ─────────────────────
  const notifications = [
    // Student notifications
    { id: 'demo2026_notif_stu_1', userId: STUDENT_UID, title: 'Live Attendance Open: CSE-4201', body: 'Dr. Md. Abu Layek opened an attendance session for Cloud Computing & Distributed Systems (Code: JNU421).', notificationType: 'ATTENDANCE_SESSION', referenceId: 'demo2026_sess_live_4201', referenceType: 'ATTENDANCE', route: '/dashboard/student', isRead: false, createdAt: hoursAgo(0.2) },
    { id: 'demo2026_notif_stu_2', userId: STUDENT_UID, title: 'Counseling Approved by Dr. Md. Abu Layek', body: 'Your appointment for Tomorrow (14:00 - 14:45) is confirmed. Message: "Bring your printed system architecture diagrams to Room 502."', notificationType: 'COUNSELING_DECISION', referenceId: 'demo2026_cbook_stu_approved', referenceType: 'COUNSELING', route: '/dashboard/student', isRead: false, createdAt: hoursAgo(1.5) },
    { id: 'demo2026_notif_stu_3', userId: STUDENT_UID, title: 'Today\'s Assessment: CSE-4201 Class Test 2', body: 'Reminder: Class Test 2 on Consensus & Raft Protocol starts at 10:30 AM in Room 402, Science Bldg.', notificationType: 'EXAM_REMINDER', referenceId: 'demo2026_exam_4201_today', referenceType: 'EXAM', route: '/dashboard/student', isRead: false, createdAt: hoursAgo(2.5) },
    { id: 'demo2026_notif_stu_4', userId: STUDENT_UID, title: 'Professor Replied to Your Feedback', body: 'Prof. Dr. Uzzal Kumar Acharjee replied to your CSE-4203 Computer Graphics evaluation.', notificationType: 'FEEDBACK_REPLY', referenceId: 'demo2026_fb_4', referenceType: 'FEEDBACK', route: '/dashboard/student', isRead: false, createdAt: hoursAgo(5) },
    { id: 'demo2026_notif_stu_5', userId: STUDENT_UID, title: 'Extra Thesis Review Session Today at 4:30 PM', body: 'Dr. Md. Abu Layek scheduled CSE-4206 Thesis & Capstone Review in Seminar Library (5th Floor).', notificationType: 'SCHEDULE_UPDATE', referenceId: 'demo2026_wed_y4s2_5', referenceType: 'SCHEDULE', route: '/dashboard/student', isRead: false, createdAt: hoursAgo(4) },

    // CR notifications
    { id: 'demo2026_notif_cr_1', userId: CR_UID, title: 'Live Attendance Open: CSE-4107', body: 'Dr. Md. Abu Layek opened attendance for Distributed Systems & Cloud Architecture (Code: JNU417).', notificationType: 'ATTENDANCE_SESSION', referenceId: 'demo2026_sess_live_4107', referenceType: 'ATTENDANCE', route: '/dashboard/cr', isRead: false, createdAt: hoursAgo(0.3) },
    { id: 'demo2026_notif_cr_2', userId: CR_UID, title: 'Counseling Confirmed — Dr. Md. Abu Layek', body: 'Confirmed for Friday 11:00 - 11:45. Message: "Bring the batch attendance sheet and preferred lab dates."', notificationType: 'COUNSELING_DECISION', referenceId: 'demo2026_cbook_cr_approved', referenceType: 'COUNSELING', route: '/dashboard/cr', isRead: false, createdAt: hoursAgo(2) },
    { id: 'demo2026_notif_cr_3', userId: CR_UID, title: 'Tomorrow\'s Routine Ready for WhatsApp Broadcast', body: '3 classes scheduled for Y4S1 tomorrow (Thursday). Tap Broadcast Routine to notify your batch.', notificationType: 'SCHEDULE_UPDATE', referenceId: 'demo2026_thu_y4s1_1', referenceType: 'SCHEDULE', route: '/dashboard/cr', isRead: false, createdAt: hoursAgo(4) },
    { id: 'demo2026_notif_cr_4', userId: CR_UID, title: 'Today\'s Quiz: CSE-4107 at 11:00 AM', body: 'Quiz 2: Cloud Security & Firebase Rules in Room 402, Science Bldg.', notificationType: 'EXAM_REMINDER', referenceId: 'demo2026_exam_4107_today', referenceType: 'EXAM', route: '/dashboard/cr', isRead: false, createdAt: hoursAgo(3) },

    // Teacher notifications
    { id: 'demo2026_notif_tch_1', userId: TEACHER_UID, title: '4 Pending Counseling Requests', body: 'Tanvir Rahman, Sajib Ahmed, Rahim Ullah, and Kamrul Hasan requested office-hour appointments.', notificationType: 'COUNSELING_REQUEST', referenceId: 'demo2026_cbook_pending_1', referenceType: 'COUNSELING', route: '/dashboard/teacher', isRead: false, createdAt: hoursAgo(0.5) },
    { id: 'demo2026_notif_tch_2', userId: TEACHER_UID, title: 'New Student Feedback Received (5★)', body: 'Kamrul Hasan (CR) submitted feedback for CSE-4107 Distributed Systems & Cloud Architecture.', notificationType: 'FEEDBACK_SUBMITTED', referenceId: 'demo2026_fb_2', referenceType: 'FEEDBACK', route: '/dashboard/teacher', isRead: false, createdAt: hoursAgo(2.5) },
    { id: 'demo2026_notif_tch_3', userId: TEACHER_UID, title: '4 Classes Scheduled Today (Wednesday)', body: '09:00 AM CSE-4201, 10:45 AM CSE-4107, 12:30 PM CSE-3101, 02:30 PM CSE-3102 Lab, 04:30 PM Thesis Review.', notificationType: 'SCHEDULE_UPDATE', referenceId: 'demo2026_wed_y4s2_1', referenceType: 'SCHEDULE', route: '/dashboard/teacher', isRead: false, createdAt: hoursAgo(3) },
    { id: 'demo2026_notif_tch_4', userId: TEACHER_UID, title: 'Anonymous Feedback Received (4★)', body: 'An anonymous student submitted course feedback for CSE-3101 Operating Systems.', notificationType: 'FEEDBACK_SUBMITTED', referenceId: 'demo2026_fb_3', referenceType: 'FEEDBACK', route: '/dashboard/teacher', isRead: false, createdAt: hoursAgo(7) },

    // Admin notifications
    { id: 'demo2026_notif_adm_1', userId: ADMIN1_UID, title: '6 Pending Signup Petitions', body: 'New JnU CSE student and faculty registration requests are awaiting administrative review.', notificationType: 'SIGNUP_REQUEST', referenceId: 'demo2026_req_1', referenceType: 'ADMIN', route: '/dashboard/admin', isRead: false, createdAt: hoursAgo(1) },
    { id: 'demo2026_notif_adm_2', userId: ADMIN1_UID, title: '3 Pending Semester Upgrade Petitions', body: 'Students from 18th, 19th, and 20th batches submitted semester progression requests.', notificationType: 'SEMESTER_REQUEST', referenceId: 'demo2026_upg_1', referenceType: 'ADMIN', route: '/dashboard/admin', isRead: false, createdAt: hoursAgo(2) },
    { id: 'demo2026_notif_adm2_1', userId: ADMIN2_UID, title: '6 Pending Signup Petitions', body: 'New JnU CSE student and faculty registration requests are awaiting administrative review.', notificationType: 'SIGNUP_REQUEST', referenceId: 'demo2026_req_1', referenceType: 'ADMIN', route: '/dashboard/admin', isRead: false, createdAt: hoursAgo(1) },

    // Broadcast to ALL
    { id: 'demo2026_notif_all_1', userId: 'ALL', title: 'Live Project & Thesis Defense Day — Dept of CSE, JnU', body: 'Welcome to the Autumn 2026 Capstone Showcase in Seminar Library (5th Floor). Best wishes to all presenting teams!', notificationType: 'GENERAL_NOTICE', referenceId: 'demo2026_notice_defense', referenceType: 'NOTICE', route: '/notifications', isRead: false, createdAt: hoursAgo(0.5) },
  ];

  for (const n of notifications) {
    ops.push(() => setDoc('notifications', n.id, n, token));
  }

  // ─── 9. PENDING SIGNUP & SEMESTER UPGRADE REQUESTS FOR ADMIN DEMO ───────────
  const signupRequests = [
    { id: 'demo2026_req_1', email: 'mehedi.hasan22@cse.jnu.ac.bd', fullName: 'Mehedi Hasan Shuvo', role: 'STUDENT', studentId: 'B220305014', phone: '+8801715223344', status: 'PENDING', createdAt: hoursAgo(1) },
    { id: 'demo2026_req_2', email: 'sumaiya.akter22@cse.jnu.ac.bd', fullName: 'Sumaiya Akter Mim', role: 'STUDENT', studentId: 'B220305029', phone: '+8801819334455', status: 'PENDING', createdAt: hoursAgo(3) },
    { id: 'demo2026_req_3', email: 'rafiul.islam23@cse.jnu.ac.bd', fullName: 'Md. Rafiul Islam', role: 'STUDENT', studentId: 'B230305007', phone: '+8801912445566', status: 'PENDING', createdAt: hoursAgo(5) },
    { id: 'demo2026_req_4', email: 'farhana.lecturer@cse.jnu.ac.bd', fullName: 'Farhana Yasmin', role: 'TEACHER', studentId: null, phone: '+8801711882233', status: 'PENDING', createdAt: hoursAgo(6) },
  ];

  for (const r of signupRequests) {
    ops.push(() => setDoc('signupRequests', r.id, r, token));
  }

  const upgradeRequests = [
    { id: 'demo2026_upg_1', studentId: 'student_sajib_uid', studentName: 'Sajib Ahmed', studentRoll: '2022CSE001', currentYear: 3, currentSemester: 1, targetYear: 3, targetSemester: 2, status: 'PENDING', notes: 'Completed all 3rd Year 1st Semester theory & lab finals. Requesting promotion to 3-2.', createdAt: hoursAgo(2), updatedAt: hoursAgo(2) },
    { id: 'demo2026_upg_2', studentId: 'student_rahim_uid', studentName: 'Rahim Ullah', studentRoll: '2022CSE015', currentYear: 3, currentSemester: 1, targetYear: 3, targetSemester: 2, status: 'PENDING', notes: 'Cleared semester tuition and lab viva. Requesting enrollment upgrade to 3rd Year 2nd Semester.', createdAt: hoursAgo(5), updatedAt: hoursAgo(5) },
    { id: 'demo2026_upg_3', studentId: 'student_fatima_uid', studentName: 'Fatima Zohra', studentRoll: '2023CSE012', currentYear: 2, currentSemester: 1, targetYear: 2, targetSemester: 2, status: 'PENDING', notes: 'Promoted to 2nd Year 2nd Semester following midterm & final evaluations.', createdAt: hoursAgo(8), updatedAt: hoursAgo(8) },
  ];

  for (const u of upgradeRequests) {
    ops.push(() => setDoc('semesterUpgradeRequests', u.id, u, token));
  }

  console.log(`\nWriting ${ops.length} rich Firestore documents in parallel...`);
  await runPool(ops, 12);

  console.log('\n\nDONE! Flooded Firestore with full presentation demo data!');
  console.log('Live Attendance Verification Codes (Active for 8 hours today):');
  console.log('  - Y4S2 Student (CSE-4201 Cloud Computing):  JNU421');
  console.log('  - Y4S1 CR      (CSE-4107 Distributed Sys):  JNU417');
  console.log('  - Y3S1 Batch   (CSE-3101 Operating Sys):    JNU311');
}

main().catch((err) => {
  console.error('\nFatal seeding error:', err);
  process.exit(1);
});
