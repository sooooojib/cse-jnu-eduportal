class ApiEndpoints {
  // Health
  static const String health = '/health';

  // Authentication
  static const String login = '/auth/login';
  static const String signupRequest = '/auth/signup-request';
  static const String refreshToken = '/auth/refresh-token';
  static const String me = '/auth/me';
  static const String changePassword = '/auth/change-password';
  static const String logout = '/auth/logout';

  // Curriculum & Routine
  static const String myCourses = '/curriculum/courses/my-courses';
  static const String schedule = '/curriculum/schedule';
  static const String exams = '/curriculum/exams';

  // Semester Lifecycle
  static const String semesterStatus = '/semester/status';
  static const String semesterRequest = '/semester/request';

  // Attendance
  static const String attendanceSummary = '/attendance/my-summary';
  static const String attendanceVerify = '/attendance/verify';

  // Counseling
  static const String counselingSlots = '/counseling/slots';
  static const String counselingMyBookings = '/counseling/my-bookings';
  static String counselingRequestBooking(String slotId) => '/counseling/slots/$slotId/request';
  static String counselingCancelBooking(String requestId) => '/counseling/requests/$requestId/cancel';

  // Feedback
  static const String feedback = '/feedback';
  static const String feedbackMySubmissions = '/feedback/my-submissions';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsMarkAllRead = '/notifications/mark-all-read';
  static String notificationMarkRead(String id) => '/notifications/$id/read';
}
