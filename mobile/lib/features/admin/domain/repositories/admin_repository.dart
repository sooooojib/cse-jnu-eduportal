import '../entities/admin_stats.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/entities/signup_request.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../attendance/domain/entities/attendance_entities.dart';
import '../../../feedback/domain/entities/feedback_entities.dart';
import '../../../profile/domain/entities/semester_status.dart';
import '../../../../core/constants/role_constants.dart';
import '../entities/department_notice.dart';

abstract class AdminRepository {
  // ─── OVERVIEW METRICS ───────────────────────────────────────────────────────
  Future<AdminOverviewStats> getOverviewStats();

  // ─── USER DIRECTORY & MANAGEMENT ───────────────────────────────────────────
  Future<List<User>> getAllUsers({UserRole? roleFilter});
  Future<User> createUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? studentId,
    String? phone,
    int? year,
    int? semester,
  });
  Future<void> deleteUser({required String userId});
  Future<void> toggleUserActiveStatus({required String userId, required bool isActive});

  // ─── COURSE MANAGEMENT ─────────────────────────────────────────────────────
  Future<List<Course>> getAllCourses();
  Future<void> createCourse(Course course);
  Future<void> updateCourse(Course course);
  Future<void> deleteCourse(String courseId);

  // ─── TEACHER COURSE ASSIGNMENTS ────────────────────────────────────────────
  Future<List<CourseAssignment>> getAllCourseAssignments();
  Future<void> assignCourseToTeacher({
    required String courseId,
    required String teacherId,
    bool isCoordinator = false,
  });
  Future<void> removeCourseAssignment({
    required String assignmentId,
    required String courseId,
    required String teacherId,
  });

  // ─── SIGNUP REQUESTS ───────────────────────────────────────────────────────
  Future<List<SignupRequest>> getPendingSignupRequests();
  Future<List<SignupRequest>> getAllSignupRequests({String? statusFilter});
  Future<void> approveSignup({
    required String requestId,
    int? assignedYear,
    int? assignedSemester,
  });
  Future<void> rejectSignup({
    required String requestId,
    required String reason,
  });

  // ─── SEMESTER UPGRADE REQUESTS ─────────────────────────────────────────────
  Future<List<SemesterUpgradeRequest>> getPendingSemesterRequests();
  Future<List<SemesterUpgradeRequest>> getAllSemesterRequests({String? statusFilter});
  Future<void> approveSemesterUpgrade({required String requestId});
  Future<void> rejectSemesterUpgrade({
    required String requestId,
    String? reason,
  });

  // ─── ATTENDANCE OVERVIEW ───────────────────────────────────────────────────
  Future<List<AttendanceSession>> getAllAttendanceSessions();

  // ─── FEEDBACK MODERATION ───────────────────────────────────────────────────
  Future<List<FeedbackItem>> getAllFeedbackItems();

  // ─── NOTICE & NOTIFICATION HUB ─────────────────────────────────────────────
  Future<List<DepartmentNotice>> getAllNotices();
  Future<void> sendBroadcastNotice({
    required String title,
    required String message,
    required String noticeType,
    required String targetAudience,
    String? attachmentUrl,
    String? attachmentType,
    String priority = 'NORMAL',
    bool syncToPublicRoutines = false,
  });
  Future<void> deleteNotice(String noticeId);
}
