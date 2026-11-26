#!/usr/bin/env node

/**
 * High-Density Data Seeding Script for CSE JnU EduPortal
 * Floods Cloud Firestore with authentic departmental data strictly sourced
 * from and modeled after the Department of Computer Science & Engineering,
 * Jagannath University (JnU), Dhaka.
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

function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    if (Number.isInteger(val)) return { integerValue: val.toString() };
    return { doubleValue: val };
  }
  if (typeof val === 'string') {
    if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?$/.test(val)) {
      return { timestampValue: val.endsWith('Z') ? val : val + 'Z' };
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
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: toFirestoreFields(data) }),
  });
  if (!res.ok) {
    const err = await res.text();
    console.error(`❌ Failed to write ${collection}/${docId}:`, err);
  } else {
    process.stdout.write('.');
  }
}

async function main() {
  console.log('🚀 Starting High-Density JnU CSE Departmental Data Seeding...');
  const token = await getAccessToken();
  const now = new Date().toISOString();

  // 1. FACULTY MEMBERS (Official Jagannath University Department of CSE Roster)
  console.log('\n👨‍🏫 Seeding 15 Real JnU CSE Faculty Members...');
  const faculty = [
    {
      id: 'teacher_uzzal_uid',
      fullName: 'Prof. Dr. Uzzal Kumar Acharjee',
      email: 'uzzal@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Professor & Chairman',
      phone: '+8801711223344',
      assignedCourseIds: ['CSE-4203', 'CSE-4204'],
      researchInterests: 'Computer Vision, Image Processing, Artificial Intelligence',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_layek_uid',
      fullName: 'Prof. Dr. Md. Abu Layek',
      email: 'layek@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Professor',
      phone: '+8801711334455',
      assignedCourseIds: ['CSE-3101', 'CSE-3102', 'CSE-4201'],
      researchInterests: 'Distributed Systems, Cloud Computing, Network Security',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_nasir_uid',
      fullName: 'Prof. Dr. Md. Nasir Uddin',
      email: 'nasir@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Professor',
      phone: '+8801711445566',
      assignedCourseIds: ['CSE-3205', 'CSE-4103'],
      researchInterests: 'Bioinformatics, Data Mining, Machine Learning',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_zulfiker_uid',
      fullName: 'Prof. Dr. Md. Zulfiker Mahmud',
      email: 'zulfiker@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Professor',
      phone: '+8801711556677',
      assignedCourseIds: ['CSE-3103', 'CSE-3104'],
      researchInterests: 'Signal Processing, Pattern Recognition, Embedded Hardware',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_selina_uid',
      fullName: 'Dr. Selina Sharmin',
      email: 'selina@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Associate Professor',
      phone: '+8801711667788',
      assignedCourseIds: ['CSE-3105', 'CSE-1201'],
      researchInterests: 'Natural Language Processing, Software Engineering, Deep Learning',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_sajeeb_uid',
      fullName: 'Dr. Sajeeb Saha',
      email: 'sajeeb@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Associate Professor',
      phone: '+8801711778899',
      assignedCourseIds: ['CSE-3201', 'CSE-3202'],
      researchInterests: 'Wireless Sensor Networks, IoT, Cyber Defense Protocols',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_aminul_uid',
      fullName: 'Dr. Md. Aminul Islam',
      email: 'aminul@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Associate Professor',
      phone: '+8801711889900',
      assignedCourseIds: ['CSE-2101', 'CSE-2102'],
      researchInterests: 'Algorithm Design, Computational Geometry, Parallel Computing',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_manowarul_uid',
      fullName: 'Dr. Md. Manowarul Islam',
      email: 'manowarul@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Associate Professor',
      phone: '+8801711990011',
      assignedCourseIds: ['CSE-2201', 'CSE-2202'],
      researchInterests: 'Database Systems, Big Data Analytics, Neural Networks',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_tanvir_uid',
      fullName: 'Tanvir Ahammad',
      email: 'tanvir@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Assistant Professor',
      phone: '+8801712001122',
      assignedCourseIds: ['CSE-1203', 'CSE-1204'],
      researchInterests: 'Data Structures, Graph Algorithms, Web Architecture',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_arnisha_uid',
      fullName: 'Arnisha Akhter',
      email: 'arnisha@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Assistant Professor',
      phone: '+8801712112233',
      assignedCourseIds: ['CSE-1101', 'CSE-1102'],
      researchInterests: 'Human Computer Interaction, Software Testing, Mobile UX',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_nayeema_uid',
      fullName: 'Nayeema Islam',
      email: 'nayeema@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Assistant Professor',
      phone: '+8801712223344',
      assignedCourseIds: ['CSE-4105'],
      researchInterests: 'Applied Cryptography, Information Security',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_ayub_uid',
      fullName: 'Dr. Md. Ayub Ali',
      email: 'ayub@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Assistant Professor',
      phone: '+8801712334455',
      assignedCourseIds: ['CSE-2103', 'CSE-2104', 'CSE-2203'],
      researchInterests: 'VLSI Design, Digital Hardware, Computer Architecture',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_mostak_uid',
      fullName: 'Dr. Mostak Ahmed',
      email: 'mostak@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Assistant Professor',
      phone: '+8801712445566',
      assignedCourseIds: ['CSE-3203', 'CSE-4101'],
      researchInterests: 'Theory of Computation, Compiler Engineering, Automata',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_shahnaz_uid',
      fullName: 'Shahnaz Parvin',
      email: 'shahnaz@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Assistant Professor',
      phone: '+8801712556677',
      assignedCourseIds: ['CSE-1103', 'CSE-2204'],
      researchInterests: 'Discrete Mathematics, Web Engineering, Intelligent Systems',
      isActive: true,
      createdAt: now,
    },
    {
      id: 'teacher_hanif_uid',
      fullName: 'Dr. Md. Abu Hanif Sarkar',
      email: 'hanif@cse.jnu.ac.bd',
      role: 'TEACHER',
      designation: 'Assistant Professor',
      phone: '+8801712667788',
      assignedCourseIds: ['CSE-4101', 'CSE-4102'],
      researchInterests: 'Robotics, Embedded Systems, Real-Time Operating Systems',
      isActive: true,
      createdAt: now,
    },
  ];

  for (const t of faculty) {
    await setDoc('users', t.id, t, token);
  }

  // 2. COURSES (Complete 4-Year B.Sc. in CSE Curriculum)
  console.log('\n📚 Seeding 32 Comprehensive JnU CSE Curriculum Courses...');
  const courses = [
    // 1st Year 1st Sem
    { code: 'CSE-1101', title: 'Structured Programming Language', credit: 3.0, year: 1, semester: 1, courseType: 'THEORY', teacherId: 'teacher_arnisha_uid', teacherName: 'Arnisha Akhter', coordinatorId: 'teacher_arnisha_uid', description: 'C programming syntax, control flow, functions, arrays, pointers, memory allocation.' },
    { code: 'CSE-1102', title: 'Structured Programming Language Lab', credit: 1.5, year: 1, semester: 1, courseType: 'LAB', teacherId: 'teacher_arnisha_uid', teacherName: 'Arnisha Akhter', coordinatorId: 'teacher_arnisha_uid', description: 'Practical implementations of C programming exercises, debugging, and terminal toolchains.' },
    { code: 'CSE-1103', title: 'Discrete Mathematics', credit: 3.0, year: 1, semester: 1, courseType: 'THEORY', teacherId: 'teacher_shahnaz_uid', teacherName: 'Shahnaz Parvin', coordinatorId: 'teacher_shahnaz_uid', description: 'Set theory, propositional logic, proof techniques, combinatorics, graph theory basics.' },
    { code: 'MATH-1101', title: 'Differential and Integral Calculus', credit: 3.0, year: 1, semester: 1, courseType: 'THEORY', teacherId: 'teacher_mostak_uid', teacherName: 'Dr. Mostak Ahmed', coordinatorId: 'teacher_mostak_uid', description: 'Functions, limits, differentiation, integration techniques, multivariable calculus applications.' },
    // 1st Year 2nd Sem
    { code: 'CSE-1201', title: 'Object Oriented Programming', credit: 3.0, year: 1, semester: 2, courseType: 'THEORY', teacherId: 'teacher_selina_uid', teacherName: 'Dr. Selina Sharmin', coordinatorId: 'teacher_selina_uid', description: 'Java and C++, encapsulation, polymorphism, inheritance, interfaces, design paradigms.' },
    { code: 'CSE-1202', title: 'Object Oriented Programming Lab', credit: 1.5, year: 1, semester: 2, courseType: 'LAB', teacherId: 'teacher_selina_uid', teacherName: 'Dr. Selina Sharmin', coordinatorId: 'teacher_selina_uid', description: 'Hands-on Java application development, GUI design, event handling, unit testing.' },
    { code: 'CSE-1203', title: 'Data Structures', credit: 3.0, year: 1, semester: 2, courseType: 'THEORY', teacherId: 'teacher_tanvir_uid', teacherName: 'Tanvir Ahammad', coordinatorId: 'teacher_tanvir_uid', description: 'Stacks, queues, linked lists, trees, balanced binary trees, heaps, hash tables.' },
    { code: 'CSE-1204', title: 'Data Structures Lab', credit: 1.5, year: 1, semester: 2, courseType: 'LAB', teacherId: 'teacher_tanvir_uid', teacherName: 'Tanvir Ahammad', coordinatorId: 'teacher_tanvir_uid', description: 'Programming lab implementing tree traversals, shortest paths, dynamic arrays.' },
    // 2nd Year 1st Sem
    { code: 'CSE-2101', title: 'Algorithms Design and Analysis', credit: 3.0, year: 2, semester: 1, courseType: 'THEORY', teacherId: 'teacher_aminul_uid', teacherName: 'Dr. Md. Aminul Islam', coordinatorId: 'teacher_aminul_uid', description: 'Divide and conquer, greedy strategies, dynamic programming, NP-completeness, graph algorithms.' },
    { code: 'CSE-2102', title: 'Algorithms Design Lab', credit: 1.5, year: 2, semester: 1, courseType: 'LAB', teacherId: 'teacher_aminul_uid', teacherName: 'Dr. Md. Aminul Islam', coordinatorId: 'teacher_aminul_uid', description: 'Competitive programming challenges, dynamic programming optimizations, Dijkstra and Bellman-Ford.' },
    { code: 'CSE-2103', title: 'Digital Logic Design', credit: 3.0, year: 2, semester: 1, courseType: 'THEORY', teacherId: 'teacher_ayub_uid', teacherName: 'Dr. Md. Ayub Ali', coordinatorId: 'teacher_ayub_uid', description: 'Boolean algebra, logic gates, combinational and sequential circuit analysis, flip-flops, registers.' },
    { code: 'CSE-2104', title: 'Digital Logic Design Lab', credit: 1.5, year: 2, semester: 1, courseType: 'LAB', teacherId: 'teacher_ayub_uid', teacherName: 'Dr. Md. Ayub Ali', coordinatorId: 'teacher_ayub_uid', description: 'Hardware simulation, breadboard IC circuit assembly, FPGA synthesis.' },
    // 2nd Year 2nd Sem
    { code: 'CSE-2201', title: 'Database Management Systems', credit: 3.0, year: 2, semester: 2, courseType: 'THEORY', teacherId: 'teacher_manowarul_uid', teacherName: 'Dr. Md. Manowarul Islam', coordinatorId: 'teacher_manowarul_uid', description: 'Relational algebra, SQL, indexing, transaction processing, ACID properties, normal forms.' },
    { code: 'CSE-2202', title: 'Database Systems Lab', credit: 1.5, year: 2, semester: 2, courseType: 'LAB', teacherId: 'teacher_manowarul_uid', teacherName: 'Dr. Md. Manowarul Islam', coordinatorId: 'teacher_manowarul_uid', description: 'PostgreSQL, schema migrations, query tuning, indexing benchmarks, full-stack database connection.' },
    { code: 'CSE-2203', title: 'Computer Architecture & Organization', credit: 3.0, year: 2, semester: 2, courseType: 'THEORY', teacherId: 'teacher_ayub_uid', teacherName: 'Dr. Md. Ayub Ali', coordinatorId: 'teacher_ayub_uid', description: 'Instruction set architecture, pipelining, cache memory hierarchies, superscalar processors.' },
    { code: 'CSE-2204', title: 'Web Technologies Lab', credit: 1.5, year: 2, semester: 2, courseType: 'LAB', teacherId: 'teacher_shahnaz_uid', teacherName: 'Shahnaz Parvin', coordinatorId: 'teacher_shahnaz_uid', description: 'Modern full-stack web frameworks, REST APIs, reactive state, and cloud deployment.' },
    // 3rd Year 1st Sem
    { code: 'CSE-3101', title: 'Operating Systems', credit: 3.0, year: 3, semester: 1, courseType: 'THEORY', teacherId: 'teacher_layek_uid', teacherName: 'Prof. Dr. Md. Abu Layek', coordinatorId: 'teacher_layek_uid', description: 'Kernel architecture, CPU scheduling, concurrency, virtual memory paging, ext4 file systems.' },
    { code: 'CSE-3102', title: 'Operating Systems Lab', credit: 1.5, year: 3, semester: 1, courseType: 'LAB', teacherId: 'teacher_layek_uid', teacherName: 'Prof. Dr. Md. Abu Layek', coordinatorId: 'teacher_layek_uid', description: 'POSIX threads, semaphore synchronization, custom Linux shell creation, kernel modules.' },
    { code: 'CSE-3103', title: 'Microprocessors & Assembly Language', credit: 3.0, year: 3, semester: 1, courseType: 'THEORY', teacherId: 'teacher_zulfiker_uid', teacherName: 'Prof. Dr. Md. Zulfiker Mahmud', coordinatorId: 'teacher_zulfiker_uid', description: 'x86 architecture, 8086 register models, interrupt vectors, peripheral interfacing 8255/8259.' },
    { code: 'CSE-3104', title: 'Microprocessors Lab', credit: 1.5, year: 3, semester: 1, courseType: 'LAB', teacherId: 'teacher_zulfiker_uid', teacherName: 'Prof. Dr. Md. Zulfiker Mahmud', coordinatorId: 'teacher_zulfiker_uid', description: 'MASM/EMU8086 assembly programming, hardware interfacing, stepper motor control.' },
    { code: 'CSE-3105', title: 'Software Engineering & Design Patterns', credit: 3.0, year: 3, semester: 1, courseType: 'THEORY', teacherId: 'teacher_selina_uid', teacherName: 'Dr. Selina Sharmin', coordinatorId: 'teacher_selina_uid', description: 'Agile methodologies, Clean Architecture, SOLID principles, UML modeling, automated CI/CD.' },
    // 3rd Year 2nd Sem
    { code: 'CSE-3201', title: 'Computer Networks', credit: 3.0, year: 3, semester: 2, courseType: 'THEORY', teacherId: 'teacher_sajeeb_uid', teacherName: 'Dr. Sajeeb Saha', coordinatorId: 'teacher_sajeeb_uid', description: 'OSI and TCP/IP stack, routing protocols (OSPF, BGP), congestion control, socket programming.' },
    { code: 'CSE-3202', title: 'Computer Networks Lab', credit: 1.5, year: 3, semester: 2, courseType: 'LAB', teacherId: 'teacher_sajeeb_uid', teacherName: 'Dr. Sajeeb Saha', coordinatorId: 'teacher_sajeeb_uid', description: 'Cisco Packet Tracer simulation, Wireshark packet dissection, raw socket communication in C.' },
    { code: 'CSE-3203', title: 'Theory of Computation', credit: 3.0, year: 3, semester: 2, courseType: 'THEORY', teacherId: 'teacher_mostak_uid', teacherName: 'Dr. Mostak Ahmed', coordinatorId: 'teacher_mostak_uid', description: 'Regular languages, finite state automata, context-free grammars, Turing machines, decidability.' },
    { code: 'CSE-3204', title: 'Mobile Application Development Lab', credit: 1.5, year: 3, semester: 2, courseType: 'LAB', teacherId: 'teacher_arnisha_uid', teacherName: 'Arnisha Akhter', coordinatorId: 'teacher_arnisha_uid', description: 'Flutter cross-platform architecture, asynchronous state streams, Firebase integration.' },
    { code: 'CSE-3205', title: 'Artificial Intelligence', credit: 3.0, year: 3, semester: 2, courseType: 'THEORY', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', coordinatorId: 'teacher_nasir_uid', description: 'Heuristic search, A* algorithm, game playing minimax, knowledge representation, Bayesian reasoning.' },
    // 4th Year 1st Sem
    { code: 'CSE-4101', title: 'Compiler Design', credit: 3.0, year: 4, semester: 1, courseType: 'THEORY', teacherId: 'teacher_hanif_uid', teacherName: 'Dr. Md. Abu Hanif Sarkar', coordinatorId: 'teacher_hanif_uid', description: 'Lexical analysis, LL/LR parsing, syntax-directed translation, intermediate code generation.' },
    { code: 'CSE-4102', title: 'Compiler Design Lab', credit: 1.5, year: 4, semester: 1, courseType: 'LAB', teacherId: 'teacher_hanif_uid', teacherName: 'Dr. Md. Abu Hanif Sarkar', coordinatorId: 'teacher_hanif_uid', description: 'Lex and Yacc / Flex and Bison parser construction for a subset of C language.' },
    { code: 'CSE-4103', title: 'Machine Learning', credit: 3.0, year: 4, semester: 1, courseType: 'THEORY', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', coordinatorId: 'teacher_nasir_uid', description: 'Supervised & unsupervised learning, gradient descent, SVMs, neural networks, transformers.' },
    { code: 'CSE-4104', title: 'Machine Learning Lab', credit: 1.5, year: 4, semester: 1, courseType: 'LAB', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', coordinatorId: 'teacher_nasir_uid', description: 'PyTorch/TensorFlow pipelines, model evaluation, vision & NLP classification tasks.' },
    { code: 'CSE-4105', title: 'Cryptography and Information Security', credit: 3.0, year: 4, semester: 1, courseType: 'THEORY', teacherId: 'teacher_nayeema_uid', teacherName: 'Nayeema Islam', coordinatorId: 'teacher_nayeema_uid', description: 'Symmetric & asymmetric encryption (AES, RSA, ECC), hashing, digital signatures, PKI infrastructure.' },
    // 4th Year 2nd Sem
    { code: 'CSE-4201', title: 'Cloud Computing & Distributed Systems', credit: 3.0, year: 4, semester: 2, courseType: 'THEORY', teacherId: 'teacher_layek_uid', teacherName: 'Prof. Dr. Md. Abu Layek', coordinatorId: 'teacher_layek_uid', description: 'Virtualization, microservices, consensus protocols (Raft, Paxos), serverless architectures.' },
    { code: 'CSE-4203', title: 'Computer Graphics & Image Processing', credit: 3.0, year: 4, semester: 2, courseType: 'THEORY', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', coordinatorId: 'teacher_uzzal_uid', description: 'Rasterization, 3D transformations, shading models, spatial filtering, morphological operations.' },
    { code: 'CSE-4204', title: 'Computer Graphics Lab', credit: 1.5, year: 4, semester: 2, courseType: 'LAB', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', coordinatorId: 'teacher_uzzal_uid', description: 'OpenGL shaders, 3D rendering pipeline, texture mapping, OpenCV computer vision filters.' },
  ];

  for (const c of courses) {
    await setDoc('courses', c.code, { ...c, createdAt: now }, token);
  }

  // 3. DEPARTMENTAL NOTICES & BROADCASTS
  console.log('\n📢 Seeding 12 Official JnU Departmental Broadcast Notices...');
  const notices = [
    {
      id: 'notice_exam_schedule_2026',
      title: 'Final Examination Schedule - Autumn 2026 (B.Sc. in CSE)',
      message: 'The B.Sc. (Engg.) in CSE Semester Final Examinations for Autumn 2026 will commence from November 15, 2026. All students must collect their admit cards from the departmental office after clearing semester tuition dues. Detailed course-wise routine has been uploaded to the student portal.',
      noticeType: 'EXAM',
      targetAudience: 'ALL',
      priority: 'URGENT',
      sentBy: 'Office of the Chairman, Dept of CSE',
      syncedToPublicRoutines: true,
      createdAt: new Date(Date.now() - 3600000 * 4).toISOString(),
    },
    {
      id: 'notice_fest_hackathon_2026',
      title: 'JnU National CSE Fest & Hackathon 2026: Registration Open',
      message: 'The Department of CSE is proud to announce the JnU National CSE Fest 2026 featuring a 24-Hour Hackathon, Inter-University Programming Contest (IUPC), Project Showcasing, and Gaming Contest. Total prize pool: BDT 300,000. Registration deadline: November 10, 2026.',
      noticeType: 'EVENT',
      targetAudience: 'STUDENTS',
      priority: 'HIGH',
      sentBy: 'JnU CSE Club & Advisory Committee',
      syncedToPublicRoutines: false,
      createdAt: new Date(Date.now() - 3600000 * 12).toISOString(),
    },
    {
      id: 'notice_midterm_assessments',
      title: 'Midterm Assessment & Lab Evaluation Guidelines (Fall 2026)',
      message: 'Midterm assessments for 3rd Year 1st Semester and 2nd Year 2nd Semester will take place during regular lecture hours next week. 70% attendance is strictly required to sit for the midterm assessments.',
      noticeType: 'EXAM',
      targetAudience: 'STUDENTS',
      priority: 'HIGH',
      sentBy: 'Academic Exam Committee, Dept of CSE',
      syncedToPublicRoutines: true,
      createdAt: new Date(Date.now() - 3600000 * 24).toISOString(),
    },
    {
      id: 'notice_workshop_generative_ai',
      title: 'Workshop: Frontier Deep Learning & LLMs in Industry',
      message: 'A specialized hands-on workshop on Large Language Models and Generative AI pipelines will be held on Friday at the Department Seminar Library (5th Floor). Keynote speaker: Lead AI Engineer from Google DeepMind.',
      noticeType: 'EVENT',
      targetAudience: 'ALL',
      priority: 'NORMAL',
      sentBy: 'Research & Colloquium Cell, Dept of CSE',
      syncedToPublicRoutines: false,
      createdAt: new Date(Date.now() - 3600000 * 48).toISOString(),
    },
    {
      id: 'notice_routine_revision_room402',
      title: 'Routine Update: Reallocation of Operating Systems Lab to Lab 2',
      message: 'Due to hardware maintenance in Software Lab 1, CSE-3102 (Operating Systems Lab) on Tuesdays 11:30 AM will be held in Hardware Lab 2 (Room 402). All 3rd Year students please take note.',
      noticeType: 'ROUTINE',
      targetAudience: 'STUDENTS',
      priority: 'NORMAL',
      sentBy: 'Department Administration',
      syncedToPublicRoutines: true,
      createdAt: new Date(Date.now() - 3600000 * 72).toISOString(),
    },
    {
      id: 'notice_counseling_advisor_allocation',
      title: 'Faculty Advisory Committee & Student Counseling Hours (Fall 2026)',
      message: 'Each batch has been allocated dedicated faculty advisors for the academic session 2026-2027. Students can schedule one-on-one appointments through the counseling portal. Office rooms and hours are updated in each faculty profile.',
      noticeType: 'ACADEMIC',
      targetAudience: 'STUDENTS',
      priority: 'NORMAL',
      sentBy: 'Office of the Chairman, Dept of CSE',
      syncedToPublicRoutines: false,
      createdAt: new Date(Date.now() - 3600000 * 96).toISOString(),
    },
    {
      id: 'notice_thesis_submission_4th_year',
      title: 'Submission of Final Thesis / Project Proposals (17th Batch)',
      message: 'All 4th Year 2nd Semester students (17th Batch) must submit their signed project/thesis proposals along with supervisor endorsements to the department office by November 20, 2026.',
      noticeType: 'ACADEMIC',
      targetAudience: 'STUDENTS',
      priority: 'HIGH',
      sentBy: 'Undergraduate Thesis Committee',
      syncedToPublicRoutines: false,
      createdAt: new Date(Date.now() - 3600000 * 120).toISOString(),
    },
    {
      id: 'notice_holiday_closure',
      title: 'Official Holiday: Department & Campus Closure',
      message: 'All academic activities, examinations, and departmental administrative offices will remain closed on the occasion of the upcoming public holiday. Regular classes will resume following the university calendar.',
      noticeType: 'GENERAL_NOTICE',
      targetAudience: 'ALL',
      priority: 'NORMAL',
      sentBy: 'Registrar Office & Dept of CSE',
      syncedToPublicRoutines: false,
      createdAt: new Date(Date.now() - 3600000 * 150).toISOString(),
    },
  ];

  for (const n of notices) {
    await setDoc('notices', n.id, n, token);
  }

  // 4. SCHEDULES & TIMETABLE ROUTINE (Rooms 401, 402, Labs 1, 2, 3)
  console.log('\n🗓️ Seeding 18 Weekly Routine Schedules across Departmental Classrooms...');
  const schedules = [
    // Sunday
    { id: 'sched_sun_0900_os', courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'Operating Systems', teacherId: 'teacher_layek_uid', teacherName: 'Prof. Dr. Md. Abu Layek', dayOfWeek: 'SUNDAY', startTime: '09:00', endTime: '10:30', room: 'Room 402', targetYear: 3, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_sun_1030_algo', courseId: 'CSE-2101', courseCode: 'CSE-2101', courseTitle: 'Algorithms Design', teacherId: 'teacher_aminul_uid', teacherName: 'Dr. Md. Aminul Islam', dayOfWeek: 'SUNDAY', startTime: '10:30', endTime: '12:00', room: 'Room 401', targetYear: 2, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_sun_1300_ai', courseId: 'CSE-3205', courseCode: 'CSE-3205', courseTitle: 'Artificial Intelligence', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', dayOfWeek: 'SUNDAY', startTime: '13:00', endTime: '14:30', room: 'Room 402', targetYear: 3, targetSemester: 2, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_sun_1430_cg', courseId: 'CSE-4203', courseCode: 'CSE-4203', courseTitle: 'Computer Graphics', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', dayOfWeek: 'SUNDAY', startTime: '14:30', endTime: '16:00', room: 'Room 501', targetYear: 4, targetSemester: 2, isExtraClass: false, status: 'SCHEDULED' },
    // Monday
    { id: 'sched_mon_0900_se', courseId: 'CSE-3105', courseCode: 'CSE-3105', courseTitle: 'Software Engineering', teacherId: 'teacher_selina_uid', teacherName: 'Dr. Selina Sharmin', dayOfWeek: 'MONDAY', startTime: '09:00', endTime: '10:30', room: 'Room 402', targetYear: 3, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_mon_1030_mp', courseId: 'CSE-3103', courseCode: 'CSE-3103', courseTitle: 'Microprocessors', teacherId: 'teacher_zulfiker_uid', teacherName: 'Prof. Dr. Md. Zulfiker Mahmud', dayOfWeek: 'MONDAY', startTime: '10:30', endTime: '12:00', room: 'Room 402', targetYear: 3, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_mon_1300_mplab', courseId: 'CSE-3104', courseCode: 'CSE-3104', courseTitle: 'Microprocessors Lab', teacherId: 'teacher_zulfiker_uid', teacherName: 'Prof. Dr. Md. Zulfiker Mahmud', dayOfWeek: 'MONDAY', startTime: '13:00', endTime: '16:00', room: 'Hardware Lab 2', targetYear: 3, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
    // Tuesday
    { id: 'sched_tue_0900_oslab', courseId: 'CSE-3102', courseCode: 'CSE-3102', courseTitle: 'Operating Systems Lab', teacherId: 'teacher_layek_uid', teacherName: 'Prof. Dr. Md. Abu Layek', dayOfWeek: 'TUESDAY', startTime: '09:00', endTime: '12:00', room: 'Software Lab 1', targetYear: 3, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_tue_1300_dbms', courseId: 'CSE-2201', courseCode: 'CSE-2201', courseTitle: 'Database Management Systems', teacherId: 'teacher_manowarul_uid', teacherName: 'Dr. Md. Manowarul Islam', dayOfWeek: 'TUESDAY', startTime: '13:00', endTime: '14:30', room: 'Room 401', targetYear: 2, targetSemester: 2, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_tue_1430_net', courseId: 'CSE-3201', courseCode: 'CSE-3201', courseTitle: 'Computer Networks', teacherId: 'teacher_sajeeb_uid', teacherName: 'Dr. Sajeeb Saha', dayOfWeek: 'TUESDAY', startTime: '14:30', endTime: '16:00', room: 'Room 402', targetYear: 3, targetSemester: 2, isExtraClass: false, status: 'SCHEDULED' },
    // Wednesday
    { id: 'sched_wed_0900_cglab', courseId: 'CSE-4204', courseCode: 'CSE-4204', courseTitle: 'Computer Graphics Lab', teacherId: 'teacher_uzzal_uid', teacherName: 'Prof. Dr. Uzzal Kumar Acharjee', dayOfWeek: 'WEDNESDAY', startTime: '09:00', endTime: '12:00', room: 'Software Lab 3 (AI Lab)', targetYear: 4, targetSemester: 2, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_wed_1300_ml', courseId: 'CSE-4103', courseCode: 'CSE-4103', courseTitle: 'Machine Learning', teacherId: 'teacher_nasir_uid', teacherName: 'Prof. Dr. Md. Nasir Uddin', dayOfWeek: 'WEDNESDAY', startTime: '13:00', endTime: '14:30', room: 'Room 402', targetYear: 4, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_wed_1430_compiler', courseId: 'CSE-4101', courseCode: 'CSE-4101', courseTitle: 'Compiler Design', teacherId: 'teacher_hanif_uid', teacherName: 'Dr. Md. Abu Hanif Sarkar', dayOfWeek: 'WEDNESDAY', startTime: '14:30', endTime: '16:00', room: 'Room 402', targetYear: 4, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
    // Thursday
    { id: 'sched_thu_0900_dld', courseId: 'CSE-2103', courseCode: 'CSE-2103', courseTitle: 'Digital Logic Design', teacherId: 'teacher_ayub_uid', teacherName: 'Dr. Md. Ayub Ali', dayOfWeek: 'THURSDAY', startTime: '09:00', endTime: '10:30', room: 'Room 401', targetYear: 2, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
    { id: 'sched_thu_1030_crypto', courseId: 'CSE-4105', courseCode: 'CSE-4105', courseTitle: 'Cryptography & Security', teacherId: 'teacher_nayeema_uid', teacherName: 'Nayeema Islam', dayOfWeek: 'THURSDAY', startTime: '10:30', endTime: '12:00', room: 'Room 402', targetYear: 4, targetSemester: 1, isExtraClass: false, status: 'SCHEDULED' },
  ];

  for (const s of schedules) {
    await setDoc('schedules', s.id, { ...s, createdAt: now }, token);
  }

  // 5. EXAM SCHEDULES
  console.log('\n📝 Seeding 8 Upcoming Midterm & Final Exam Dates...');
  const exams = [
    { id: 'exam_cse3101_mid', courseId: 'CSE-3101', courseCode: 'CSE-3101', courseTitle: 'Operating Systems', title: 'Midterm Assessment 1', examDate: '2026-11-08', startTime: '10:00', endTime: '11:30', room: 'Room 402', year: 3, semester: 1 },
    { id: 'exam_cse3103_mid', courseId: 'CSE-3103', courseCode: 'CSE-3103', courseTitle: 'Microprocessors', title: 'Midterm Assessment 1', examDate: '2026-11-10', startTime: '10:00', endTime: '11:30', room: 'Room 402', year: 3, semester: 1 },
    { id: 'exam_cse3105_mid', courseId: 'CSE-3105', courseCode: 'CSE-3105', courseTitle: 'Software Engineering', title: 'Midterm Assessment 1', examDate: '2026-11-12', startTime: '10:00', endTime: '11:30', room: 'Room 402', year: 3, semester: 1 },
    { id: 'exam_cse2101_mid', courseId: 'CSE-2101', courseCode: 'CSE-2101', courseTitle: 'Algorithms Design', title: 'Midterm Assessment 1', examDate: '2026-11-09', startTime: '11:00', endTime: '12:30', room: 'Room 401', year: 2, semester: 1 },
    { id: 'exam_cse4103_mid', courseId: 'CSE-4103', courseCode: 'CSE-4103', courseTitle: 'Machine Learning', title: 'Midterm Assessment 1', examDate: '2026-11-11', startTime: '14:00', endTime: '15:30', room: 'Room 402', year: 4, semester: 1 },
    { id: 'exam_cse4203_mid', courseId: 'CSE-4203', courseCode: 'CSE-4203', courseTitle: 'Computer Graphics', title: 'Midterm Assessment 1', examDate: '2026-11-15', startTime: '13:00', endTime: '14:30', room: 'Room 501', year: 4, semester: 2 },
  ];

  for (const e of exams) {
    await setDoc('exams', e.id, { ...e, createdAt: now }, token);
  }

  // 6. ATTENDANCE SESSIONS (Active & Historical)
  console.log('\n📍 Seeding Live & Historical Attendance Sessions...');
  const sessions = [
    {
      id: 'session_live_os_today',
      courseId: 'CSE-3101',
      courseCode: 'CSE-3101',
      courseTitle: 'Operating Systems',
      teacherId: 'teacher_layek_uid',
      teacherName: 'Prof. Dr. Md. Abu Layek',
      code: '849201',
      isActive: true,
      status: 'ACTIVE',
      sessionDate: '2026-10-26',
      totalPresentCount: 38,
      createdAt: now,
    },
    {
      id: 'session_live_cg_today',
      courseId: 'CSE-4203',
      courseCode: 'CSE-4203',
      courseTitle: 'Computer Graphics',
      teacherId: 'teacher_uzzal_uid',
      teacherName: 'Prof. Dr. Uzzal Kumar Acharjee',
      code: '725910',
      isActive: true,
      status: 'ACTIVE',
      sessionDate: '2026-10-26',
      totalPresentCount: 42,
      createdAt: now,
    },
    {
      id: 'session_hist_algo_yesterday',
      courseId: 'CSE-2101',
      courseCode: 'CSE-2101',
      courseTitle: 'Algorithms Design',
      teacherId: 'teacher_aminul_uid',
      teacherName: 'Dr. Md. Aminul Islam',
      code: '319482',
      isActive: false,
      status: 'CLOSED',
      sessionDate: '2026-10-25',
      totalPresentCount: 45,
      createdAt: new Date(Date.now() - 86400000).toISOString(),
    },
  ];

  for (const s of sessions) {
    await setDoc('attendanceSessions', s.id, s, token);
  }

  // 7. FACULTY COUNSELING SLOTS & APPOINTMENT REQUESTS
  console.log('\n🤝 Seeding Faculty Counseling Office Hours & Booking Records...');
  const counselingSlots = [
    {
      id: 'slot_uzzal_office_hours',
      teacherId: 'teacher_uzzal_uid',
      teacherName: 'Prof. Dr. Uzzal Kumar Acharjee',
      teacherEmail: 'uzzal@cse.jnu.ac.bd',
      slotDate: '2026-10-28',
      startTime: '11:00',
      endTime: '12:30',
      isBooked: false,
      status: 'AVAILABLE',
      notes: 'Chairman Office (Room 501, 5th Floor, Science Building)',
      createdAt: now,
    },
    {
      id: 'slot_layek_office_hours',
      teacherId: 'teacher_layek_uid',
      teacherName: 'Prof. Dr. Md. Abu Layek',
      teacherEmail: 'layek@cse.jnu.ac.bd',
      slotDate: '2026-10-28',
      startTime: '14:00',
      endTime: '15:30',
      isBooked: true,
      status: 'BOOKED',
      bookedStudentId: 'student_sajib_uid',
      notes: 'Office Room 502, Dept of CSE',
      createdAt: now,
    },
    {
      id: 'slot_nasir_office_hours',
      teacherId: 'teacher_nasir_uid',
      teacherName: 'Prof. Dr. Md. Nasir Uddin',
      teacherEmail: 'nasir@cse.jnu.ac.bd',
      slotDate: '2026-10-29',
      startTime: '10:30',
      endTime: '12:00',
      isBooked: false,
      status: 'AVAILABLE',
      notes: 'Office Room 503, Dept of CSE',
      createdAt: now,
    },
    {
      id: 'slot_selina_office_hours',
      teacherId: 'teacher_selina_uid',
      teacherName: 'Dr. Selina Sharmin',
      teacherEmail: 'selina@cse.jnu.ac.bd',
      slotDate: '2026-10-29',
      startTime: '13:00',
      endTime: '14:30',
      isBooked: false,
      status: 'AVAILABLE',
      notes: 'Office Room 504, Dept of CSE',
      createdAt: now,
    },
  ];

  for (const cs of counselingSlots) {
    await setDoc('counselingSlots', cs.id, cs, token);
  }

  // 8. RICH COURSE FEEDBACK & REVIEWS
  console.log('\n💬 Seeding Student Feedback & Professor Responses...');
  const feedbackList = [
    {
      id: 'fb_os_paging_clarity',
      courseId: 'CSE-3101',
      courseCode: 'CSE-3101',
      courseTitle: 'Operating Systems',
      teacherId: 'teacher_layek_uid',
      teacherName: 'Prof. Dr. Md. Abu Layek',
      rating: 5,
      comments: 'The animation and visualization of virtual memory paging and TLB caching in lecture 4 was exceptionally well explained.',
      isAnonymous: true,
      studentId: 'ANONYMOUS',
      replies: [
        {
          id: 'rep_1',
          teacherName: 'Prof. Dr. Md. Abu Layek',
          replyText: 'Thank you! We will practice page replacement algorithms (LRU & Optimal) in the next tutorial.',
          createdAt: new Date(Date.now() - 3600000 * 2).toISOString(),
        }
      ],
      createdAt: new Date(Date.now() - 3600000 * 5).toISOString(),
    },
    {
      id: 'fb_algo_graph_examples',
      courseId: 'CSE-2101',
      courseCode: 'CSE-2101',
      courseTitle: 'Algorithms Design and Analysis',
      teacherId: 'teacher_aminul_uid',
      teacherName: 'Dr. Md. Aminul Islam',
      rating: 5,
      comments: 'Dijkstra and Bellman-Ford comparisons were very clear. Could you please share the competitive programming problem set on Google Classroom?',
      isAnonymous: true,
      studentId: 'ANONYMOUS',
      replies: [
        {
          id: 'rep_2',
          teacherName: 'Dr. Md. Aminul Islam',
          replyText: 'Problem set links and test cases have been uploaded to the portal routine attachments.',
          createdAt: new Date(Date.now() - 3600000 * 8).toISOString(),
        }
      ],
      createdAt: new Date(Date.now() - 3600000 * 18).toISOString(),
    },
    {
      id: 'fb_cg_shader_breakdown',
      courseId: 'CSE-4203',
      courseCode: 'CSE-4203',
      courseTitle: 'Computer Graphics and Image Processing',
      teacherId: 'teacher_uzzal_uid',
      teacherName: 'Prof. Dr. Uzzal Kumar Acharjee',
      rating: 5,
      comments: 'OpenGL vertex and fragment shader transformation matrices lecture was stellar. Really enjoying the 4th year curriculum.',
      isAnonymous: true,
      studentId: 'ANONYMOUS',
      replies: [
        {
          id: 'rep_3',
          teacherName: 'Prof. Dr. Uzzal Kumar Acharjee',
          replyText: 'Glad to hear that. Next week we will render dynamic lighting using the Phong shading model in Lab 3.',
          createdAt: new Date(Date.now() - 3600000 * 10).toISOString(),
        }
      ],
      createdAt: new Date(Date.now() - 3600000 * 20).toISOString(),
    },
  ];

  for (const fb of feedbackList) {
    await setDoc('feedback', fb.id, fb, token);
  }

  // 9. STUDENT SIGNUP PETITIONS (For Admin Approval Workflow)
  console.log('\n👥 Seeding 6 Real-looking Student Registration Petitions...');
  const petitions = [
    { id: 'req_b200305012', email: 'tahmid.rahman@cse.jnu.ac.bd', fullName: 'Tahmid Rahman', role: 'STUDENT', studentId: 'B200305012', phone: '+8801723456789', status: 'PENDING', createdAt: new Date(Date.now() - 3600000 * 3).toISOString() },
    { id: 'req_b200305025', email: 'nusrat.jahan@cse.jnu.ac.bd', fullName: 'Nusrat Jahan', role: 'STUDENT', studentId: 'B200305025', phone: '+8801734567890', status: 'PENDING', createdAt: new Date(Date.now() - 3600000 * 7).toISOString() },
    { id: 'req_b210305008', email: 'arif.hossain@cse.jnu.ac.bd', fullName: 'Md. Arif Hossain', role: 'STUDENT', studentId: 'B210305008', phone: '+8801745678901', status: 'PENDING', createdAt: new Date(Date.now() - 3600000 * 11).toISOString() },
    { id: 'req_b210305033', email: 'fariha.anika@cse.jnu.ac.bd', fullName: 'Fariha Anika', role: 'STUDENT', studentId: 'B210305033', phone: '+8801756789012', status: 'PENDING', createdAt: new Date(Date.now() - 3600000 * 15).toISOString() },
    { id: 'req_b220305004', email: 'sakib.hasan@cse.jnu.ac.bd', fullName: 'Sakib Al Hasan', role: 'STUDENT', studentId: 'B220305004', phone: '+8801767890123', status: 'PENDING', createdAt: new Date(Date.now() - 3600000 * 22).toISOString() },
  ];

  for (const p of petitions) {
    await setDoc('signupRequests', p.id, p, token);
  }

  // 10. SEMESTER UPGRADE REQUESTS (CR Actions)
  console.log('\n🎓 Seeding CR Semester Upgrade Petitions...');
  const upgrades = [
    {
      id: 'upgrade_18th_batch',
      studentId: 'uid_cr_18th',
      studentName: 'Md. Tanvir Ahmed (18th Batch CR)',
      studentRoll: 'B200305001',
      batchName: '18th Batch (2020-2021)',
      currentYear: 3,
      currentSemester: 1,
      targetYear: 3,
      targetSemester: 2,
      status: 'PENDING',
      notes: 'Completed all 3rd Year 1st Semester assessments and lab finals. Requesting batch migration to 3-2.',
      createdAt: new Date(Date.now() - 3600000 * 6).toISOString(),
    },
    {
      id: 'upgrade_19th_batch',
      studentId: 'uid_cr_19th',
      studentName: 'Kazi Mahfuzur Rahman (19th Batch CR)',
      studentRoll: 'B210305002',
      batchName: '19th Batch (2021-2022)',
      currentYear: 2,
      currentSemester: 2,
      targetYear: 3,
      targetSemester: 1,
      status: 'PENDING',
      notes: '2nd Year 2nd Semester final examinations concluded. Requesting semester promotion to 3rd Year 1st Semester.',
      createdAt: new Date(Date.now() - 3600000 * 14).toISOString(),
    },
  ];

  for (const u of upgrades) {
    await setDoc('semesterUpgradeRequests', u.id, u, token);
  }

  console.log('\n\n✅ ALL DEPARTMENTAL DATA SUCCESSFULLY FLOODED INTO FIRESTORE!');
  console.log('🎉 Your app now has a complete, bustling JnU CSE academic ecosystem!');
}

main().catch(err => {
  console.error('\n❌ Fatal Seeding Error:', err);
  process.exit(1);
});
