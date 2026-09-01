import * as admin from "firebase-admin";

// Initialize admin with default credentials
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

async function seedDatabase() {
  console.log("🚀 Starting CSE JnU EduPortal Firestore database seeding...");

  const now = admin.firestore.FieldValue.serverTimestamp();

  // 1. SEED COURSES
  console.log("📚 Seeding syllabus courses...");
  const courses = [
    {
      id: "CSE-3101",
      code: "CSE-3101",
      title: "Operating Systems",
      credit: 3.0,
      year: 3,
      semester: 1,
      courseType: "THEORY",
      description: "Processes, Threads, CPU Scheduling, Synchronization, Memory Management, File Systems.",
      teacherName: "Dr. Mohammad Shafiul Alam",
    },
    {
      id: "CSE-3102",
      code: "CSE-3102",
      title: "Operating Systems Sessional",
      credit: 1.5,
      year: 3,
      semester: 1,
      courseType: "LAB",
      description: "Linux Shell Scripting, POSIX Threads, Semaphores, IPC in C/C++.",
      teacherName: "Dr. Mohammad Shafiul Alam",
    },
    {
      id: "CSE-3103",
      code: "CSE-3103",
      title: "Database Management Systems",
      credit: 3.0,
      year: 3,
      semester: 1,
      courseType: "THEORY",
      description: "Relational Algebra, SQL, Normalization, Query Optimization, Transaction Processing.",
      teacherName: "Prof. Dr. Ujjal Kumar Bhowmik",
    },
    {
      id: "CSE-3104",
      code: "CSE-3104",
      title: "Database Management Systems Sessional",
      credit: 1.5,
      year: 3,
      semester: 1,
      courseType: "LAB",
      description: "PostgreSQL, Complex Queries, Indexes, Stored Procedures, Full-Stack Integration.",
      teacherName: "Prof. Dr. Ujjal Kumar Bhowmik",
    },
    {
      id: "CSE-3105",
      code: "CSE-3105",
      title: "Computer Networks",
      credit: 3.0,
      year: 3,
      semester: 1,
      courseType: "THEORY",
      description: "OSI & TCP/IP Reference Models, Routing Protocols, Congestion Control, Sockets.",
      teacherName: "Dr. Abu Sayed",
    },
  ];

  for (const c of courses) {
    await db.collection("courses").doc(c.id).set({
      ...c,
      createdAt: now,
      updatedAt: now,
    });
    console.log(`  ✓ Course ${c.code}: ${c.title}`);
  }

  // 2. SEED CLASS SCHEDULES (3rd Year, 1st Semester Routine)
  console.log("⏰ Seeding weekly routine schedule...");
  const schedules = [
    {
      id: "sch_sun_0900",
      courseId: "CSE-3101",
      courseCode: "CSE-3101",
      courseTitle: "Operating Systems",
      teacherName: "Dr. Mohammad Shafiul Alam",
      dayOfWeek: "SUNDAY",
      startTime: "09:00",
      endTime: "10:30",
      room: "Room 402",
      targetYear: 3,
      targetSemester: 1,
      isExtraClass: false,
    },
    {
      id: "sch_sun_1030",
      courseId: "CSE-3103",
      courseCode: "CSE-3103",
      courseTitle: "Database Management Systems",
      teacherName: "Prof. Dr. Ujjal Kumar Bhowmik",
      dayOfWeek: "SUNDAY",
      startTime: "10:30",
      endTime: "12:00",
      room: "Room 402",
      targetYear: 3,
      targetSemester: 1,
      isExtraClass: false,
    },
    {
      id: "sch_mon_0900",
      courseId: "CSE-3105",
      courseCode: "CSE-3105",
      courseTitle: "Computer Networks",
      teacherName: "Dr. Abu Sayed",
      dayOfWeek: "MONDAY",
      startTime: "09:00",
      endTime: "10:30",
      room: "Room 402",
      targetYear: 3,
      targetSemester: 1,
      isExtraClass: false,
    },
    {
      id: "sch_tue_1100",
      courseId: "CSE-3102",
      courseCode: "CSE-3102",
      courseTitle: "Operating Systems Sessional",
      teacherName: "Dr. Mohammad Shafiul Alam",
      dayOfWeek: "TUESDAY",
      startTime: "11:00",
      endTime: "01:30",
      room: "Software Lab 2",
      targetYear: 3,
      targetSemester: 1,
      isExtraClass: false,
    },
  ];

  for (const s of schedules) {
    await db.collection("schedules").doc(s.id).set({
      ...s,
      createdAt: now,
    });
    console.log(`  ✓ Routine slot: ${s.dayOfWeek} ${s.startTime} - ${s.courseCode}`);
  }

  // 3. SEED UPCOMING EXAMINATIONS
  console.log("📝 Seeding examination dates...");
  const exams = [
    {
      id: "exam_mid_3101",
      courseId: "CSE-3101",
      courseCode: "CSE-3101",
      courseTitle: "Operating Systems",
      title: "Midterm Assessment 1",
      examDate: "2026-09-15",
      startTime: "10:00",
      endTime: "11:30",
      room: "Room 402 / Lab 2",
      year: 3,
      semester: 1,
    },
    {
      id: "exam_mid_3103",
      courseId: "CSE-3103",
      courseCode: "CSE-3103",
      courseTitle: "Database Management Systems",
      title: "Midterm Assessment 1",
      examDate: "2026-09-22",
      startTime: "10:00",
      endTime: "11:30",
      room: "Room 402",
      year: 3,
      semester: 1,
    },
  ];

  for (const e of exams) {
    await db.collection("exams").doc(e.id).set({
      ...e,
      createdAt: now,
    });
    console.log(`  ✓ Exam: ${e.courseCode} on ${e.examDate}`);
  }

  // 4. SEED SAMPLE COUNSELING SLOTS
  console.log("🤝 Seeding faculty counseling slots...");
  const slots = [
    {
      id: "coun_slot_1",
      teacherId: "teacher_shafiul_uid",
      teacherName: "Dr. Mohammad Shafiul Alam",
      teacherEmail: "shafiul@cse.jnu.ac.bd",
      slotDate: "2026-09-02",
      startTime: "11:00",
      endTime: "12:00",
      isBooked: false,
      status: "AVAILABLE",
      notes: "Room 410, Department of CSE",
    },
    {
      id: "coun_slot_2",
      teacherId: "teacher_ujjal_uid",
      teacherName: "Prof. Dr. Ujjal Kumar Bhowmik",
      teacherEmail: "ujjal@cse.jnu.ac.bd",
      slotDate: "2026-09-03",
      startTime: "02:00",
      endTime: "03:00",
      isBooked: false,
      status: "AVAILABLE",
      notes: "Room 408, Department of CSE",
    },
  ];

  for (const sl of slots) {
    await db.collection("counselingSlots").doc(sl.id).set({
      ...sl,
      createdAt: now,
    });
    console.log(`  ✓ Counseling: ${sl.teacherName} on ${sl.slotDate} (${sl.startTime})`);
  }

  console.log("\n✅ Firestore database seed complete! All core collections populated.");
}

seedDatabase().catch((err) => {
  console.error("❌ Seeding failed:", err);
  process.exit(1);
});
