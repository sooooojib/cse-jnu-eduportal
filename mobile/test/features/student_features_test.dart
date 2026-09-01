import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// Curriculum
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:cse_jnu_eduportal/features/curriculum/presentation/controllers/schedule_controller.dart';

// Attendance
import 'package:cse_jnu_eduportal/features/attendance/domain/entities/attendance_entities.dart';
import 'package:cse_jnu_eduportal/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:cse_jnu_eduportal/features/attendance/presentation/controllers/attendance_controller.dart';

// Counseling
import 'package:cse_jnu_eduportal/features/counseling/domain/entities/counseling_entities.dart';
import 'package:cse_jnu_eduportal/features/counseling/domain/repositories/counseling_repository.dart';
import 'package:cse_jnu_eduportal/features/counseling/presentation/controllers/counseling_controller.dart';

// Feedback
import 'package:cse_jnu_eduportal/features/feedback/domain/entities/feedback_entities.dart';
import 'package:cse_jnu_eduportal/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:cse_jnu_eduportal/features/feedback/presentation/controllers/feedback_controller.dart';

// Profile
import 'package:cse_jnu_eduportal/features/profile/domain/entities/semester_status.dart';
import 'package:cse_jnu_eduportal/features/profile/domain/repositories/semester_repository.dart';
import 'package:cse_jnu_eduportal/features/profile/presentation/controllers/profile_controller.dart';

// Notifications
import 'package:cse_jnu_eduportal/features/notifications/domain/entities/notification_entities.dart';
import 'package:cse_jnu_eduportal/features/notifications/domain/repositories/notification_repository.dart';
import 'package:cse_jnu_eduportal/features/notifications/presentation/controllers/notification_controller.dart';

// Mock Repositories
class MockCurriculumRepository implements CurriculumRepository {
  @override
  Future<List<Course>> getMyCourses() async {
    return const [
      Course(
        id: 'c1',
        code: 'CSE-3101',
        title: 'Database Systems',
        credit: 3.0,
        year: 3,
        semester: 1,
        courseType: 'THEORY',
        teacherName: 'Prof. Rahman',
      ),
    ];
  }

  @override
  Future<List<ScheduleSlot>> getSchedule({String? day}) async {
    return const [
      ScheduleSlot(
        id: 's1',
        courseId: 'c1',
        courseCode: 'CSE-3101',
        courseTitle: 'Database Systems',
        teacherId: 't1',
        teacherName: 'Prof. Rahman',
        dayOfWeek: 'MONDAY',
        startTime: '09:00:00',
        endTime: '10:30:00',
        room: 'Room 402',
        targetYear: 3,
        targetSemester: 1,
      ),
    ];
  }

  @override
  Future<List<Exam>> getExams() async {
    return const [
      Exam(
        id: 'e1',
        courseId: 'c1',
        courseCode: 'CSE-3101',
        courseTitle: 'Database Systems',
        title: 'Mid Term Exam',
        examDate: '2026-11-20',
        startTime: '10:00:00',
        endTime: '12:00:00',
        room: 'Room 402',
        year: 3,
        semester: 1,
      ),
    ];
  }
}

class MockAttendanceRepository implements AttendanceRepository {
  @override
  Future<AttendanceSummary> getMySummary() async {
    return const AttendanceSummary(
      overallPercentage: 88.5,
      totalAttended: 23,
      totalSessions: 26,
      courseSummaries: [
        CourseAttendance(
          courseId: 'c1',
          courseCode: 'CSE-3101',
          courseTitle: 'Database Systems',
          attendedClasses: 23,
          totalClasses: 26,
          percentage: 88.5,
          isEligible: true,
        ),
      ],
      recentRecords: [
        AttendanceRecord(
          id: 'ar1',
          courseCode: 'CSE-3101',
          courseTitle: 'Database Systems',
          status: 'PRESENT',
          verifiedAt: '2026-11-10T09:05:00Z',
        ),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> verifyCode(String code, {String? courseId}) async {
    if (code == '849201') {
      return {'success': true, 'courseTitle': 'Database Systems'};
    }
    throw Exception('Invalid verification code');
  }
}

class MockCounselingRepository implements CounselingRepository {
  @override
  Future<List<CounselingSlot>> getAvailableSlots({String? teacherId}) async {
    return const [
      CounselingSlot(
        id: 'slot-1',
        teacherId: 'teacher-1',
        teacherName: 'Prof. Hasan',
        teacherEmail: 'hasan@cse.jnu.ac.bd',
        slotDate: '2026-11-18',
        startTime: '10:00:00',
        endTime: '11:00:00',
        status: 'AVAILABLE',
      ),
    ];
  }

  @override
  Future<CounselingBooking> requestBooking(String slotId, {required String category, required String notes}) async {
    return CounselingBooking(
      id: 'req-1',
      slotId: slotId,
      teacherId: 'teacher-1',
      teacherName: 'Prof. Hasan',
      slotDate: '2026-11-18',
      startTime: '10:00:00',
      endTime: '11:00:00',
      category: category,
      notes: notes,
      status: 'PENDING',
      createdAt: '2026-11-10T10:00:00Z',
    );
  }

  @override
  Future<List<CounselingBooking>> getMyBookings() async {
    return const [
      CounselingBooking(
        id: 'req-1',
        slotId: 'slot-1',
        teacherId: 'teacher-1',
        teacherName: 'Prof. Hasan',
        slotDate: '2026-11-18',
        startTime: '10:00:00',
        endTime: '11:00:00',
        category: 'ACADEMIC_ADVISING',
        notes: 'Discussion regarding thesis topic selection.',
        status: 'PENDING',
        createdAt: '2026-11-10T10:00:00Z',
      ),
    ];
  }

  @override
  Future<void> cancelBooking(String requestId) async {}
}

class MockFeedbackRepository implements FeedbackRepository {
  @override
  Future<FeedbackItem> submitFeedback({
    required String teacherId,
    String? courseId,
    required int rating,
    required String comments,
    required bool isAnonymous,
  }) async {
    return FeedbackItem(
      id: 'fb-1',
      teacherId: teacherId,
      teacherName: 'Prof. Rahman',
      rating: rating,
      comments: comments,
      isAnonymous: isAnonymous,
      replies: const [],
      createdAt: '2026-11-10T11:00:00Z',
    );
  }

  @override
  Future<List<FeedbackItem>> getMySubmissions() async {
    return const [
      FeedbackItem(
        id: 'fb-1',
        teacherId: 'teacher-1',
        teacherName: 'Prof. Rahman',
        courseId: 'c1',
        courseCode: 'CSE-3101',
        courseTitle: 'Database Systems',
        rating: 5,
        comments: 'Outstanding lecture on indexing and B+ trees.',
        isAnonymous: true,
        replies: [
          FeedbackReply(
            id: 'rep-1',
            teacherName: 'Prof. Rahman',
            replyText: 'Thank you for the constructive feedback!',
            createdAt: '2026-11-10T12:00:00Z',
          ),
        ],
        createdAt: '2026-11-10T11:00:00Z',
      ),
    ];
  }
}

class MockSemesterRepository implements SemesterRepository {
  @override
  Future<SemesterStatus> getStatus() async {
    return const SemesterStatus(
      currentYear: 3,
      currentSemester: 1,
      status: 'ACTIVE',
    );
  }

  @override
  Future<SemesterStatus> requestUpgrade({required int requestedYear, required int requestedSemester}) async {
    return SemesterStatus(
      currentYear: 3,
      currentSemester: 1,
      requestedYear: requestedYear,
      requestedSemester: requestedSemester,
      status: 'PENDING',
    );
  }
}

class MockNotificationRepository implements NotificationRepository {
  @override
  Future<NotificationFeed> getNotifications() async {
    return const NotificationFeed(
      unreadCount: 1,
      notifications: [
        AppNotification(
          id: 'n1',
          title: 'Attendance Recorded',
          body: 'Your attendance for CSE-3101 was recorded.',
          notificationType: 'ATTENDANCE_VERIFIED',
          isRead: false,
          createdAt: '2026-11-10T09:05:00Z',
        ),
      ],
    );
  }

  @override
  Future<void> markAsRead(String id) async {}

  @override
  Future<void> markAllAsRead() async {}
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Student Experience Feature Controllers & State Tests', () {
    test('ScheduleController fetches daily and weekly routine correctly', () async {
      final repo = MockCurriculumRepository();
      final controller = ScheduleController(getScheduleUseCase: GetScheduleUseCase(repo));

      expect(controller.state, isA<ScheduleInitial>());

      await controller.fetchSchedule(day: 'MONDAY');

      expect(controller.state, isA<ScheduleLoaded>());
      final loaded = controller.state as ScheduleLoaded;
      expect(loaded.slots.length, 1);
      expect(loaded.slots.first.courseCode, 'CSE-3101');
      expect(loaded.slots.first.room, 'Room 402');
    });

    test('ExamsController fetches upcoming examinations', () async {
      final repo = MockCurriculumRepository();
      final controller = ExamsController(getExamsUseCase: GetExamsUseCase(repo));

      expect(controller.state, isA<ExamsInitial>());

      await controller.fetchExams();

      expect(controller.state, isA<ExamsLoaded>());
      final loaded = controller.state as ExamsLoaded;
      expect(loaded.exams.length, 1);
      expect(loaded.exams.first.title, 'Mid Term Exam');
    });

    test('AttendanceController fetches summary and verifies 6-digit session codes', () async {
      final repo = MockAttendanceRepository();
      final controller = AttendanceController(
        getAttendanceSummaryUseCase: GetAttendanceSummaryUseCase(repo),
        verifyAttendanceCodeUseCase: VerifyAttendanceCodeUseCase(repo),
      );

      await controller.fetchSummary();

      expect(controller.state, isA<AttendanceLoaded>());
      final loaded = controller.state as AttendanceLoaded;
      expect(loaded.summary.overallPercentage, 88.5);
      expect(loaded.summary.courseSummaries.first.isEligible, isTrue);

      final result = await controller.submitVerificationCode('849201');
      expect(result, isTrue);
    });

    test('CounselingController fetches available slots and handles booking requests', () async {
      final repo = MockCounselingRepository();
      final controller = CounselingController(
        getAvailableSlotsUseCase: GetAvailableSlotsUseCase(repo),
        requestBookingUseCase: RequestBookingUseCase(repo),
        getMyBookingsUseCase: GetMyBookingsUseCase(repo),
        cancelBookingUseCase: CancelBookingUseCase(repo),
      );

      await controller.fetchAll();

      expect(controller.state, isA<CounselingLoaded>());
      final loaded = controller.state as CounselingLoaded;
      expect(loaded.availableSlots.length, 1);
      expect(loaded.myBookings.length, 1);
      expect(loaded.myBookings.first.teacherName, 'Prof. Hasan');

      final booked = await controller.bookSlot(
        'slot-1',
        category: 'RESEARCH_DISCUSSION',
        notes: 'Discussion on thesis architecture',
      );
      expect(booked, isTrue);
    });

    test('FeedbackController submits reviews and fetches history with replies', () async {
      final repo = MockFeedbackRepository();
      final controller = FeedbackController(
        submitFeedbackUseCase: SubmitFeedbackUseCase(repo),
        getMyFeedbackUseCase: GetMyFeedbackUseCase(repo),
      );

      await controller.fetchSubmissions();

      expect(controller.state, isA<FeedbackLoaded>());
      final loaded = controller.state as FeedbackLoaded;
      expect(loaded.submissions.length, 1);
      expect(loaded.submissions.first.replies.length, 1);
      expect(loaded.submissions.first.replies.first.teacherName, 'Prof. Rahman');

      final submitted = await controller.submitFeedback(
        teacherId: 'teacher-1',
        rating: 5,
        comments: 'Excellent presentation and guidance.',
        isAnonymous: true,
      );
      expect(submitted, isTrue);
    });

    test('ProfileController fetches status and handles semester upgrade requests', () async {
      final repo = MockSemesterRepository();
      final controller = ProfileController(
        getSemesterStatusUseCase: GetSemesterStatusUseCase(repo),
        requestSemesterUpgradeUseCase: RequestSemesterUpgradeUseCase(repo),
      );

      await controller.fetchSemesterStatus();

      expect(controller.state, isA<ProfileLoaded>());
      final loaded = controller.state as ProfileLoaded;
      expect(loaded.semesterStatus.currentYear, 3);
      expect(loaded.semesterStatus.status, 'ACTIVE');

      final upgraded = await controller.requestUpgrade(requestedYear: 3, requestedSemester: 2);
      expect(upgraded, isTrue);
      expect((controller.state as ProfileLoaded).semesterStatus.isPending, isTrue);
    });

    test('NotificationController fetches feed and updates unread counts', () async {
      final repo = MockNotificationRepository();
      final controller = NotificationController(
        getNotificationsUseCase: GetNotificationsUseCase(repo),
        markNotificationReadUseCase: MarkNotificationReadUseCase(repo),
        markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(repo),
      );

      await controller.fetchNotifications();

      expect(controller.state, isA<NotificationLoaded>());
      expect(controller.unreadCount, 1);
      final loaded = controller.state as NotificationLoaded;
      expect(loaded.feed.notifications.first.title, 'Attendance Recorded');
    });
  });
}
