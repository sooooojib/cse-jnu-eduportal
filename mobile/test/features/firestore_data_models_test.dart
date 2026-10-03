import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/user_model.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/signup_request_model.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/models/curriculum_models.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/models/attendance_models.dart';
import 'package:cse_jnu_eduportal/features/counseling/data/models/counseling_models.dart';
import 'package:cse_jnu_eduportal/features/feedback/data/models/feedback_models.dart';
import 'package:cse_jnu_eduportal/features/profile/data/models/semester_upgrade_request_model.dart';
import 'package:cse_jnu_eduportal/features/notifications/data/models/notification_models.dart';

void main() {
  group('Firestore Data Models & Serialization Tests', () {
    test('1. UserModel serializes and deserializes correctly', () {
      final model = UserModel.fromJson({
        'id': 'uid_123',
        'email': 'student@cse.jnu.ac.bd',
        'fullName': 'Sajib Ahmed',
        'role': 'STUDENT',
        'studentId': '2020CSE042',
        'year': 3,
        'semester': 1,
        'assignedCourseIds': ['CSE-3101'],
        'fcmTokens': ['token_123'],
        'isActive': true,
      });

      expect(model.id, 'uid_123');
      expect(model.role, UserRole.student);
      expect(model.fullName, 'Sajib Ahmed');
      expect(model.assignedCourseIds, ['CSE-3101']);
      expect(model.fcmTokens, ['token_123']);
      expect(model.isActive, true);

      final firestoreMap = model.toFirestore();
      expect(firestoreMap['email'], 'student@cse.jnu.ac.bd');
      expect(firestoreMap['role'], 'STUDENT');
      expect(firestoreMap['year'], 3);
      expect(firestoreMap['fcmTokens'], ['token_123']);
    });

    test('2. SignupRequestModel handles serialization and pending status', () {
      final model = SignupRequestModel.fromJson({
        'id': 'req_99',
        'email': 'applicant@cse.jnu.ac.bd',
        'fullName': 'Tahmid Rahman',
        'role': 'STUDENT',
        'studentId': '2024CSE015',
        'status': 'PENDING',
        'createdAt': '2026-08-31T20:00:00Z',
      });

      expect(model.id, 'req_99');
      expect(model.status, 'PENDING');
      expect(model.role, UserRole.student);

      final json = model.toJson();
      expect(json['status'], 'PENDING');
    });

    test('3. CourseModel, CourseAssignmentModel & EnrollmentModel serialize accurately', () {
      final course = CourseModel.fromJson({
        'id': 'CSE-3101',
        'code': 'CSE-3101',
        'title': 'Operating Systems',
        'credit': 3.0,
        'year': 3,
        'semester': 1,
        'courseType': 'THEORY',
        'teacherName': 'Dr. Shafiul Alam',
        'coordinatorId': 'uid_teacher_1',
      });

      expect(course.code, 'CSE-3101');
      expect(course.credit, 3.0);
      expect(course.coordinatorId, 'uid_teacher_1');

      final assignment = CourseAssignmentModel.fromJson({
        'id': 'asg_1',
        'courseId': 'CSE-3101',
        'courseCode': 'CSE-3101',
        'courseTitle': 'Operating Systems',
        'teacherId': 'uid_teacher_1',
        'teacherName': 'Dr. Shafiul Alam',
        'isCoordinator': true,
      });

      expect(assignment.courseCode, 'CSE-3101');
      expect(assignment.isCoordinator, true);

      final enrollment = EnrollmentModel.fromJson({
        'id': 'enr_1',
        'studentId': 'uid_student_42',
        'studentName': 'Sajib Ahmed',
        'studentRoll': '2020CSE042',
        'year': 3,
        'semester': 1,
        'enrolledCourseIds': ['CSE-3101', 'CSE-3102'],
      });

      expect(enrollment.studentRoll, '2020CSE042');
      expect(enrollment.enrolledCourseIds.length, 2);
    });

    test('4. ScheduleSlotModel and ExamModel serialize accurately', () {
      final slot = ScheduleSlotModel.fromJson({
        'id': 'slot_1',
        'courseId': 'CSE-3101',
        'courseCode': 'CSE-3101',
        'courseTitle': 'Operating Systems',
        'teacherId': 't_1',
        'teacherName': 'Dr. Shafiul Alam',
        'dayOfWeek': 'SUNDAY',
        'startTime': '09:00',
        'endTime': '10:30',
        'room': 'Room 402',
        'targetYear': 3,
        'targetSemester': 1,
        'isExtraClass': false,
      });

      expect(slot.room, 'Room 402');
      expect(slot.dayOfWeek, 'SUNDAY');

      final exam = ExamModel.fromJson({
        'id': 'exam_1',
        'courseId': 'CSE-3101',
        'courseCode': 'CSE-3101',
        'courseTitle': 'Operating Systems',
        'title': 'Midterm Assessment 1',
        'examDate': '2026-09-15',
        'startTime': '10:00',
        'endTime': '11:30',
        'room': 'Room 402',
        'year': 3,
        'semester': 1,
      });

      expect(exam.title, 'Midterm Assessment 1');
      expect(exam.examDate, '2026-09-15');
    });

    test('5. AttendanceSessionModel, AttendanceRecordModel & VerificationResult handle invariants', () {
      final session = AttendanceSessionModel.fromJson({
        'id': 'sess_1',
        'courseId': 'CSE-3101',
        'courseCode': 'CSE-3101',
        'courseTitle': 'Operating Systems',
        'teacherId': 't_1',
        'teacherName': 'Dr. Shafiul Alam',
        'code': '7K9P2X',
        'isActive': true,
        'status': 'ACTIVE',
        'sessionDate': '2026-08-31',
        'totalPresentCount': 42,
        'createdAt': '2026-08-31T09:00:00Z',
      });

      expect(session.code, '7K9P2X');
      expect(session.isActive, true);

      // Verify composite docId invariant
      final studentId = 'uid_student_42';
      final compositeDocId = '${session.id}_$studentId';
      expect(compositeDocId, 'sess_1_uid_student_42');

      final record = AttendanceRecordModel.fromJson({
        'id': compositeDocId,
        'sessionId': session.id,
        'studentId': studentId,
        'studentName': 'Sajib Ahmed',
        'studentRoll': '2020CSE042',
        'courseCode': 'CSE-3101',
        'courseTitle': 'Operating Systems',
        'status': 'PRESENT',
        'verifiedAt': '2026-08-31T09:05:00Z',
      });

      expect(record.id, 'sess_1_uid_student_42');
      expect(record.studentName, 'Sajib Ahmed');
      expect(record.status, 'PRESENT');

      const result = AttendanceVerificationResult(
        success: true,
        message: 'Attendance marked successfully.',
        courseCode: 'CSE-3101',
        recordId: 'sess_1_uid_student_42',
      );
      expect(result.success, true);
      expect(result.recordId, 'sess_1_uid_student_42');
    });

    test('6. CounselingSlotModel and CounselingBookingModel handle student & status properties', () {
      final slot = CounselingSlotModel.fromJson({
        'id': 'slot_1',
        'teacherId': 't_1',
        'teacherName': 'Dr. Shafiul Alam',
        'teacherEmail': 'shafiul@cse.jnu.ac.bd',
        'slotDate': '2026-09-02',
        'startTime': '11:00',
        'endTime': '12:00',
        'isBooked': false,
        'status': 'AVAILABLE',
      });

      expect(slot.status, 'AVAILABLE');

      final booking = CounselingBookingModel.fromJson({
        'id': 'book_1',
        'slotId': 'slot_1',
        'studentId': 'uid_student_42',
        'studentName': 'Sajib Ahmed',
        'teacherId': 't_1',
        'teacherName': 'Dr. Shafiul Alam',
        'slotDate': '2026-09-02',
        'startTime': '11:00',
        'endTime': '12:00',
        'category': 'ACADEMIC_ADVISING',
        'notes': 'Banker Algorithm questions',
        'status': 'PENDING',
        'createdAt': '2026-08-31T20:00:00Z',
      });

      expect(booking.studentId, 'uid_student_42');
      expect(booking.studentName, 'Sajib Ahmed');
      expect(booking.category, 'ACADEMIC_ADVISING');
      expect(booking.status, 'PENDING');
    });

    test('7. FeedbackItemModel, FeedbackReplyModel & AttachmentModel handle anonymous reviews', () {
      final attachment = AttachmentModel.fromJson({
        'id': 'att_1',
        'fileName': 'note.png',
        'fileUrl': 'https://firebasestorage.googleapis.com/...',
        'mimeType': 'image/png',
        'fileSize': 1024,
      });
      expect(attachment.fileName, 'note.png');

      final feedback = FeedbackItemModel.fromJson({
        'id': 'fb_1',
        'teacherId': 't_1',
        'teacherName': 'Dr. Shafiul Alam',
        'rating': 5,
        'comments': 'Excellent lecture on Paging and Segmentation',
        'isAnonymous': true,
        'attachments': [
          {
            'id': 'att_1',
            'fileName': 'note.png',
            'fileUrl': 'https://firebasestorage.googleapis.com/...',
            'mimeType': 'image/png',
            'fileSize': 1024,
          }
        ],
        'replies': [
          {
            'id': 'rep_1',
            'teacherName': 'Dr. Shafiul Alam',
            'replyText': 'Thank you!',
            'createdAt': '2026-09-01T10:00:00Z',
          }
        ],
        'createdAt': '2026-08-31T20:00:00Z',
      });

      expect(feedback.isAnonymous, true);
      expect(feedback.rating, 5);
      expect(feedback.attachments.length, 1);
      expect(feedback.replies.length, 1);
      expect(feedback.replies.first.replyText, 'Thank you!');
    });

    test('8. SemesterUpgradeRequestModel, SemesterStatusModel & NotificationModels parse correctly', () {
      final semStatus = SemesterStatusModel.fromJson({
        'currentYear': 3,
        'currentSemester': 1,
        'requestedYear': 3,
        'requestedSemester': 2,
        'status': 'PENDING',
      });

      expect(semStatus.isPending, true);
      expect(semStatus.currentYear, 3);
      expect(semStatus.requestedSemester, 2);

      final semUpgrade = SemesterUpgradeRequestModel.fromJson({
        'id': 'sem_req_1',
        'studentId': 'uid_student_42',
        'studentName': 'Sajib Ahmed',
        'studentRoll': '2020CSE042',
        'currentYear': 2,
        'currentSemester': 2,
        'requestedYear': 3,
        'requestedSemester': 1,
        'status': 'PENDING',
        'createdAt': '2026-08-31T20:00:00Z',
      });

      expect(semUpgrade.id, 'sem_req_1');
      expect(semUpgrade.studentRoll, '2020CSE042');
      expect(semUpgrade.requestedYear, 3);

      final notif = AppNotificationModel.fromJson({
        'id': 'notif_1',
        'title': 'Booking Approved',
        'body': 'Your appointment was approved.',
        'notificationType': 'COUNSELING',
        'isRead': false,
        'createdAt': '2026-08-31T20:00:00Z',
      });

      expect(notif.isRead, false);
      expect(notif.notificationType, 'COUNSELING');

      final feed = NotificationFeedModel.fromJson({
        'unreadCount': 1,
        'notifications': [
          {
            'id': 'notif_1',
            'title': 'Booking Approved',
            'body': 'Your appointment was approved.',
            'notificationType': 'COUNSELING',
            'isRead': false,
            'createdAt': '2026-08-31T20:00:00Z',
          }
        ],
      });

      expect(feed.unreadCount, 1);
      expect(feed.notifications.length, 1);
    });
  });
}
