import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/models/attendance_models.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/signup_request_model.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/user_model.dart';
import 'package:cse_jnu_eduportal/features/counseling/data/models/counseling_models.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/models/curriculum_models.dart';
import 'package:cse_jnu_eduportal/features/feedback/data/models/feedback_models.dart';
import 'package:cse_jnu_eduportal/features/notifications/data/models/notification_models.dart';
import 'package:cse_jnu_eduportal/features/profile/data/models/semester_upgrade_request_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Stage 13: Firestore Data Models & Typed Entity Verification', () {
    test('1. UserModel serialize & deserialize with Firestore schema', () {
      final user = UserModel(
        id: 'uid_test_123',
        email: 'test@cse.jnu.ac.bd',
        fullName: 'Test User',
        role: UserRole.student,
        studentId: '2020CSE042',
        year: 3,
        semester: 1,
        assignedCourseIds: const ['CSE-3101'],
      );

      final firestoreMap = user.toFirestore();
      expect(firestoreMap['email'], equals('test@cse.jnu.ac.bd'));
      expect(firestoreMap['role'], equals('STUDENT'));
      expect(firestoreMap['studentId'], equals('2020CSE042'));

      final json = user.toJson();
      final reconstituted = UserModel.fromJson(json);
      expect(reconstituted.id, equals(user.id));
      expect(reconstituted.role, equals(UserRole.student));
    });

    test('2. SignupRequestModel serialize & deserialize', () {
      final req = SignupRequestModel(
        id: 'req_1',
        email: 'app@cse.jnu.ac.bd',
        fullName: 'Applicant',
        role: UserRole.student,
        status: 'PENDING',
        createdAt: '2026-08-01T00:00:00Z',
      );

      final fsMap = req.toFirestore();
      expect(fsMap['status'], equals('PENDING'));
      expect(fsMap['email'], equals('app@cse.jnu.ac.bd'));

      final reconstituted = SignupRequestModel.fromJson(req.toJson());
      expect(reconstituted.fullName, equals('Applicant'));
    });

    test('3. CourseModel, CourseAssignmentModel & EnrollmentModel', () {
      const course = CourseModel(
        id: 'CSE-3101',
        code: 'CSE-3101',
        title: 'Operating Systems',
        credit: 3.0,
        year: 3,
        semester: 1,
        courseType: 'THEORY',
        teacherId: 'teacher_1',
        teacherName: 'Prof. Karim',
      );
      expect(course.toFirestore()['code'], equals('CSE-3101'));
      expect(course.toFirestore()['credit'], equals(3.0));

      const assignment = CourseAssignmentModel(
        id: 'asg_1',
        courseId: 'CSE-3101',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        teacherId: 'teacher_1',
        teacherName: 'Prof. Karim',
        isCoordinator: true,
      );
      expect(assignment.toJson()['isCoordinator'], isTrue);

      const enrollment = EnrollmentModel(
        id: 'enr_1',
        studentId: 'uid_42',
        studentName: 'Sajib',
        studentRoll: '2020CSE042',
        year: 3,
        semester: 1,
        enrolledCourseIds: ['CSE-3101'],
      );
      expect(enrollment.toJson()['enrolledCourseIds'], contains('CSE-3101'));
    });

    test('4. ScheduleSlotModel & ExamModel serialize correctly', () {
      const slot = ScheduleSlotModel(
        id: 'slot_1',
        courseId: 'CSE-3101',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        teacherId: 't_1',
        teacherName: 'Prof. Karim',
        dayOfWeek: 'SUNDAY',
        startTime: '09:00',
        endTime: '10:30',
        room: 'Room 402',
        targetYear: 3,
        targetSemester: 1,
      );
      expect(slot.toFirestore()['dayOfWeek'], equals('SUNDAY'));

      const exam = ExamModel(
        id: 'exam_1',
        courseId: 'CSE-3101',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        title: 'Midterm 1',
        examDate: '2026-09-15',
        startTime: '10:00',
        endTime: '11:30',
        room: 'Room 402',
        year: 3,
        semester: 1,
      );
      expect(exam.toFirestore()['examDate'], equals('2026-09-15'));
    });

    test('5. AttendanceSessionModel & AttendanceRecordModel composite keys', () {
      const session = AttendanceSessionModel(
        id: 'sess_1',
        courseId: 'CSE-3101',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        teacherId: 't_1',
        teacherName: 'Prof. Karim',
        code: '7K9P2X',
        isActive: true,
        status: 'ACTIVE',
        sessionDate: '2026-09-01',
        createdAt: '2026-09-01T09:00:00Z',
      );
      expect(session.toFirestore()['code'], equals('7K9P2X'));

      const record = AttendanceRecordModel(
        id: 'sess_1_uid_42',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        status: 'PRESENT',
        verifiedAt: '2026-09-01T09:05:00Z',
        studentId: 'uid_42',
        studentName: 'Sajib',
      );
      expect(record.id, equals('sess_1_uid_42'));
      expect(record.toFirestore()['status'], equals('PRESENT'));
    });

    test('6. CounselingSlotModel & CounselingBookingModel', () {
      const slot = CounselingSlotModel(
        id: 'cslot_1',
        teacherId: 't_1',
        teacherName: 'Prof. Karim',
        teacherEmail: 'karim@cse.jnu.ac.bd',
        slotDate: '2026-09-02',
        startTime: '11:00',
        endTime: '12:00',
        status: 'AVAILABLE',
      );
      expect(slot.toFirestore()['status'], equals('AVAILABLE'));

      const booking = CounselingBookingModel(
        id: 'cbook_1',
        slotId: 'cslot_1',
        teacherId: 't_1',
        teacherName: 'Prof. Karim',
        slotDate: '2026-09-02',
        startTime: '11:00',
        endTime: '12:00',
        category: 'ACADEMIC_ADVISING',
        notes: 'Queries on Deadlocks',
        status: 'PENDING',
        createdAt: '2026-09-01T15:00:00Z',
      );
      expect(booking.toJson()['status'], equals('PENDING'));
    });

    test('7. FeedbackItemModel, AttachmentModel & FeedbackReplyModel', () {
      const attachment = AttachmentModel(
        id: 'att_1',
        fileName: 'note.png',
        fileUrl: 'https://firebasestorage.../note.png',
        mimeType: 'image/png',
        fileSize: 2048,
      );
      const reply = FeedbackReplyModel(
        id: 'rep_1',
        teacherName: 'Prof. Karim',
        replyText: 'Understood, will review in next lecture.',
        createdAt: '2026-09-02T10:00:00Z',
      );
      const feedback = FeedbackItemModel(
        id: 'fbk_1',
        teacherId: 't_1',
        teacherName: 'Prof. Karim',
        courseId: 'CSE-3101',
        courseCode: 'CSE-3101',
        courseTitle: 'Operating Systems',
        rating: 5,
        comments: 'Excellent explanation of virtual memory paging.',
        isAnonymous: true,
        attachments: [attachment],
        replies: [reply],
        createdAt: '2026-09-01T18:00:00Z',
      );

      final fs = feedback.toFirestore();
      expect(fs['isAnonymous'], isTrue);
      expect(fs['studentId'], equals('ANONYMOUS'));
      expect(fs['attachments'], isNotEmpty);
      expect(fs['replies'], isNotEmpty);
    });

    test('8. SemesterUpgradeRequestModel & AppNotificationModel', () {
      const semReq = SemesterUpgradeRequestModel(
        currentYear: 2,
        currentSemester: 2,
        requestedYear: 3,
        requestedSemester: 1,
        status: 'PENDING',
        studentId: 'uid_42',
        studentName: 'Sajib',
      );
      expect(semReq.toFirestore()['requestedYear'], equals(3));
      expect(semReq.toFirestore()['status'], equals('PENDING'));

      const notif = AppNotificationModel(
        id: 'notif_1',
        title: 'Counseling Approved',
        body: 'Your meeting is scheduled.',
        notificationType: 'COUNSELING',
        isRead: false,
        createdAt: '2026-09-01T12:00:00Z',
      );
      expect(notif.toFirestore()['notificationType'], equals('COUNSELING'));
      expect(notif.toFirestore()['isRead'], isFalse);
    });
  });
}
