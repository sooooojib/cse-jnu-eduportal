import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/user_model.dart';
import 'package:cse_jnu_eduportal/features/auth/data/models/signup_request_model.dart';
import 'package:cse_jnu_eduportal/features/curriculum/data/models/curriculum_models.dart';
import 'package:cse_jnu_eduportal/features/attendance/data/models/attendance_models.dart';
import 'package:cse_jnu_eduportal/features/counseling/data/models/counseling_models.dart';
import 'package:cse_jnu_eduportal/features/feedback/data/models/feedback_models.dart';
import 'package:cse_jnu_eduportal/features/profile/data/repositories/semester_repository_impl.dart';
import 'package:cse_jnu_eduportal/features/notifications/data/models/notification_models.dart';

void main() {
  group('Firestore Data Models & Serialization Tests', () {
    test('UserModel serializes and deserializes correctly', () {
      final model = UserModel.fromJson({
        'id': 'uid_123',
        'email': 'student@cse.jnu.ac.bd',
        'fullName': 'Sajib Ahmed',
        'role': 'STUDENT',
        'studentId': '2020CSE042',
        'year': 3,
        'semester': 1,
        'assignedCourseIds': ['CSE-3101'],
        'isActive': true,
      });

      expect(model.id, 'uid_123');
      expect(model.role, UserRole.student);
      expect(model.fullName, 'Sajib Ahmed');
      expect(model.assignedCourseIds, ['CSE-3101']);

      final firestoreMap = model.toFirestore();
      expect(firestoreMap['email'], 'student@cse.jnu.ac.bd');
      expect(firestoreMap['role'], 'STUDENT');
      expect(firestoreMap['year'], 3);
    });

    test('SignupRequestModel handles serialization and pending status', () {
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

    test('CourseModel and ScheduleSlotModel serialize accurately', () {
      final course = CourseModel.fromJson({
        'id': 'CSE-3101',
        'code': 'CSE-3101',
        'title': 'Operating Systems',
        'credit': 3.0,
        'year': 3,
        'semester': 1,
        'courseType': 'THEORY',
        'teacherName': 'Dr. Shafiul Alam',
      });

      expect(course.code, 'CSE-3101');
      expect(course.credit, 3.0);

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
    });

    test('AttendanceSessionModel and AttendanceRecordModel handle verification codes', () {
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

      final record = AttendanceRecordModel.fromJson({
        'id': 'rec_1',
        'courseCode': 'CSE-3101',
        'courseTitle': 'Operating Systems',
        'status': 'PRESENT',
        'verifiedAt': '2026-08-31T09:05:00Z',
      });

      expect(record.status, 'PRESENT');
    });

    test('CounselingSlotModel and CounselingBookingModel handle booking statuses', () {
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

      expect(booking.category, 'ACADEMIC_ADVISING');
      expect(booking.status, 'PENDING');
    });

    test('FeedbackItemModel handles anonymous reviews and threaded replies', () {
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

    test('SemesterStatusModel and NotificationModels parse correctly', () {
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
    });
  });
}
