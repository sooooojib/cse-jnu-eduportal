import request from 'supertest';
import { app } from '../../src/app';
import * as db from '../../src/config/database';
import { signAccessToken } from '../../src/common/utils/token';
import { UserRole } from '../../src/common/constants/roles';

describe('Student REST APIs Integration Tests', () => {
  const studentId = '11111111-1111-1111-1111-111111111111';
  const studentToken = signAccessToken({
    userId: studentId,
    email: 'student@cse.jnu.ac.bd',
    role: UserRole.STUDENT,
    year: 3,
    semester: 1,
  });

  const mockUserRow = {
    id: studentId,
    email: 'student@cse.jnu.ac.bd',
    full_name: 'Sajib Hossain',
    role: UserRole.STUDENT,
    student_id: 'B210305015',
    phone: null,
    year: 3,
    semester: 1,
    requested_year: null,
    requested_semester: null,
    semester_status: 'NONE',
    is_active: true,
    created_at: new Date(),
    updated_at: new Date(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Curriculum API (/api/v1/curriculum)', () => {
    it('GET /api/v1/curriculum/courses/my-courses returns student courses', async () => {
      const mockCourses = [
        {
          id: '22222222-2222-2222-2222-222222222222',
          code: 'CSE-3101',
          title: 'Database Management Systems',
          credit: 3.0,
          year: 3,
          semester: 1,
          courseType: 'THEORY',
          description: 'Relational databases and SQL',
          teacherId: '33333333-3333-3333-3333-333333333333',
          teacherName: 'Prof. Rahman',
        },
      ];

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        if (text.includes('FROM courses c')) {
          return { rows: mockCourses, rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .get('/api/v1/curriculum/courses/my-courses')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBe(1);
      expect(res.body.data[0].code).toBe('CSE-3101');

      querySpy.mockRestore();
    });

    it('GET /api/v1/curriculum/schedule returns daily/weekly schedule slots', async () => {
      const mockSlots = [
        {
          id: 'slot-1',
          courseId: 'course-1',
          courseCode: 'CSE-3101',
          courseTitle: 'Database Management Systems',
          teacherId: 'teacher-1',
          teacherName: 'Prof. Rahman',
          dayOfWeek: 'MONDAY',
          startTime: '09:00:00',
          endTime: '10:30:00',
          room: 'Room 402',
          targetYear: 3,
          targetSemester: 1,
        },
      ];

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        if (text.includes('FROM schedule_slots s')) {
          return { rows: mockSlots, rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .get('/api/v1/curriculum/schedule?day=MONDAY')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data[0].room).toBe('Room 402');

      querySpy.mockRestore();
    });

    it('GET /api/v1/curriculum/exams returns exam schedules', async () => {
      const mockExams = [
        {
          id: 'exam-1',
          courseId: 'course-1',
          courseCode: 'CSE-3101',
          courseTitle: 'Database Management Systems',
          title: 'Mid Term Examination',
          examDate: '2026-11-20',
          startTime: '10:00:00',
          endTime: '12:00:00',
          room: 'Exam Hall 1',
          year: 3,
          semester: 1,
        },
      ];

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        if (text.includes('FROM exams e')) {
          return { rows: mockExams, rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .get('/api/v1/curriculum/exams')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data[0].title).toBe('Mid Term Examination');

      querySpy.mockRestore();
    });
  });

  describe('Semester API (/api/v1/semester)', () => {
    it('GET /api/v1/semester/status returns student semester state', async () => {
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .get('/api/v1/semester/status')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.currentYear).toBe(3);
      expect(res.body.data.semesterStatus).toBe('NONE');

      querySpy.mockRestore();
    });

    it('POST /api/v1/semester/request submits an upgrade request', async () => {
      const withTxSpy = jest.spyOn(db, 'withTransaction').mockImplementation(async (cb: any) => {
        const mockClient = {
          query: jest.fn().mockResolvedValue({ rows: [], rowCount: 1 }),
        };
        return cb(mockClient);
      });

      let callCount = 0;
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          callCount++;
          if (callCount === 1) {
            // authenticate query
            return { rows: [mockUserRow], rowCount: 1 } as any;
          }
          if (callCount === 2) {
            // check user state before upgrade
            return { rows: [{ year: 3, semester: 1, semester_status: 'NONE' }], rowCount: 1 } as any;
          }
          // getStatus after upgrade
          return {
            rows: [
              {
                year: 3,
                semester: 1,
                requested_year: 3,
                requested_semester: 2,
                semester_status: 'PENDING',
                updated_at: new Date(),
              },
            ],
            rowCount: 1,
          } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/semester/request')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({ requestedYear: 3, requestedSemester: 2 });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.semesterStatus).toBe('PENDING');

      withTxSpy.mockRestore();
      querySpy.mockRestore();
    });
  });

  describe('Attendance API (/api/v1/attendance)', () => {
    it('POST /api/v1/attendance/verify marks student present on valid active code', async () => {
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        if (text.includes('FROM attendance_sessions s')) {
          return {
            rows: [
              {
                id: 'session-123',
                course_id: 'course-1',
                course_title: 'Database Management Systems',
                status: 'ACTIVE',
                expires_at: new Date(Date.now() + 300000),
              },
            ],
            rowCount: 1,
          } as any;
        }
        if (text.includes('SELECT id FROM attendance_records')) {
          return { rows: [], rowCount: 0 } as any;
        }
        if (text.includes('INSERT INTO attendance_records')) {
          return {
            rows: [{ verified_at: new Date() }],
            rowCount: 1,
          } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/attendance/verify')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({ code: '849201' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.courseTitle).toBe('Database Management Systems');

      querySpy.mockRestore();
    });

    it('POST /api/v1/attendance/verify rejects duplicate attendance submission', async () => {
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        if (text.includes('FROM attendance_sessions s')) {
          return {
            rows: [
              {
                id: 'session-123',
                course_id: 'course-1',
                course_title: 'Database Management Systems',
                status: 'ACTIVE',
                expires_at: null,
              },
            ],
            rowCount: 1,
          } as any;
        }
        if (text.includes('SELECT id FROM attendance_records')) {
          return { rows: [{ id: 'existing-record' }], rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/attendance/verify')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({ code: '849201' });

      expect(res.status).toBe(409);
      expect(res.body.success).toBe(false);

      querySpy.mockRestore();
    });
  });

  describe('Counseling API (/api/v1/counseling)', () => {
    it('GET /api/v1/counseling/slots returns available faculty slots', async () => {
      const mockSlots = [
        {
          id: 'slot-1',
          teacherId: 'teacher-1',
          teacherName: 'Prof. Hasan',
          teacherEmail: 'hasan@cse.jnu.ac.bd',
          slotDate: '2026-11-18',
          startTime: '10:00:00',
          endTime: '11:00:00',
          status: 'AVAILABLE',
          notes: 'Office Room 410',
        },
      ];

      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        if (text.includes('FROM counseling_slots cs')) {
          return { rows: mockSlots, rowCount: 1 } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .get('/api/v1/counseling/slots')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.length).toBe(1);
      expect(res.body.data[0].teacherName).toBe('Prof. Hasan');

      querySpy.mockRestore();
    });

    it('POST /api/v1/counseling/slots/:id/request creates booking request', async () => {
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        if (text.includes('SELECT id, status FROM counseling_slots')) {
          return { rows: [{ id: '22222222-2222-2222-2222-222222222222', status: 'AVAILABLE' }], rowCount: 1 } as any;
        }
        if (text.includes('SELECT id FROM counseling_requests')) {
          return { rows: [], rowCount: 0 } as any;
        }
        if (text.includes('INSERT INTO counseling_requests')) {
          return { rows: [{ id: 'req-1', created_at: new Date() }], rowCount: 1 } as any;
        }
        if (text.includes('FROM counseling_requests cr')) {
          return {
            rows: [
              {
                id: 'req-1',
                slotId: '22222222-2222-2222-2222-222222222222',
                teacherId: 'teacher-1',
                teacherName: 'Prof. Hasan',
                slotDate: '2026-11-18',
                startTime: '10:00:00',
                endTime: '11:00:00',
                category: 'ACADEMIC_ADVISING',
                notes: 'Discussion regarding thesis topic selection.',
                status: 'PENDING',
                reviewedAt: null,
                createdAt: new Date().toISOString(),
              },
            ],
            rowCount: 1,
          } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/counseling/slots/22222222-2222-2222-2222-222222222222/request')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({
          category: 'ACADEMIC_ADVISING',
          notes: 'Discussion regarding thesis topic selection.',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('PENDING');

      querySpy.mockRestore();
    });
  });

  describe('Feedback API (/api/v1/feedback)', () => {
    it('POST /api/v1/feedback submits course feedback and notifies teacher', async () => {
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1 AND role = \'TEACHER\'')) {
          return { rows: [{ id: '33333333-3333-3333-3333-333333333333', full_name: 'Prof. Rahman' }], rowCount: 1 } as any;
        }
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        if (text.includes('INSERT INTO feedbacks')) {
          return { rows: [{ id: 'feedback-1' }], rowCount: 1 } as any;
        }
        if (text.includes('INSERT INTO notifications')) {
          return { rows: [], rowCount: 1 } as any;
        }
        if (text.includes('FROM feedbacks f')) {
          return {
            rows: [
              {
                id: 'feedback-1',
                teacherId: '33333333-3333-3333-3333-333333333333',
                teacherName: 'Prof. Rahman',
                courseId: null,
                courseCode: null,
                courseTitle: null,
                rating: 5,
                comments: 'Outstanding lecture on indexing and B+ trees.',
                isAnonymous: true,
                createdAt: new Date().toISOString(),
              },
            ],
            rowCount: 1,
          } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .post('/api/v1/feedback')
        .set('Authorization', `Bearer ${studentToken}`)
        .send({
          teacherId: '33333333-3333-3333-3333-333333333333',
          rating: 5,
          comments: 'Outstanding lecture on indexing and B+ trees.',
          isAnonymous: true,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.rating).toBe(5);
      expect(res.body.data.isAnonymous).toBe(true);

      querySpy.mockRestore();
    });
  });

  describe('Notifications API (/api/v1/notifications)', () => {
    it('GET /api/v1/notifications returns user feed and unread count', async () => {
      const querySpy = jest.spyOn(db, 'query').mockImplementation(async (text: string) => {
        if (text.includes('FROM users WHERE id = $1')) {
          return { rows: [mockUserRow], rowCount: 1 } as any;
        }
        if (text.includes('SELECT COUNT(*)')) {
          return { rows: [{ count: '2' }], rowCount: 1 } as any;
        }
        if (text.includes('ORDER BY created_at DESC')) {
          return {
            rows: [
              {
                id: 'notif-1',
                title: 'Attendance Verified',
                body: 'Attendance for CSE-3101 was recorded.',
                notification_type: 'ATTENDANCE_VERIFIED',
                reference_type: 'ATTENDANCE',
                reference_id: null,
                is_read: false,
                created_at: new Date(),
              },
            ],
            rowCount: 1,
          } as any;
        }
        return { rows: [], rowCount: 0 } as any;
      });

      const res = await request(app)
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${studentToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.unreadCount).toBe(2);
      expect(res.body.data.notifications.length).toBe(1);

      querySpy.mockRestore();
    });
  });
});
