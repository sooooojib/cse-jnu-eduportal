import '../../domain/entities/admin_stats.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/entities/signup_request.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../attendance/domain/entities/attendance_entities.dart';
import '../../../feedback/domain/entities/feedback_entities.dart';
import '../../../profile/domain/entities/semester_status.dart';
import '../../../../core/constants/role_constants.dart';
import '../../domain/entities/department_notice.dart';

class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDataSource _remoteDataSource;

  AdminRepositoryImpl({
    required AdminRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<AdminOverviewStats> getOverviewStats() {
    return _remoteDataSource.getOverviewStats();
  }

  // ─── USER DIRECTORY ────────────────────────────────────────────────────────
  @override
  Future<List<User>> getAllUsers({UserRole? roleFilter}) {
    return _remoteDataSource.getAllUsers(roleFilter: roleFilter);
  }

  @override
  Future<User> createUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? studentId,
    String? phone,
    int? year,
    int? semester,
  }) {
    return _remoteDataSource.createUser(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      studentId: studentId,
      phone: phone,
      year: year,
      semester: semester,
    );
  }

  @override
  Future<void> deleteUser({required String userId}) {
    return _remoteDataSource.deleteUser(userId: userId);
  }

  @override
  Future<void> toggleUserActiveStatus({required String userId, required bool isActive}) {
    return _remoteDataSource.toggleUserActiveStatus(userId: userId, isActive: isActive);
  }

  // ─── COURSE MANAGEMENT ─────────────────────────────────────────────────────
  @override
  Future<List<Course>> getAllCourses() {
    return _remoteDataSource.getAllCourses();
  }

  @override
  Future<void> createCourse(Course course) {
    return _remoteDataSource.createCourse(course);
  }

  @override
  Future<void> updateCourse(Course course) {
    return _remoteDataSource.updateCourse(course);
  }

  @override
  Future<void> deleteCourse(String courseId) {
    return _remoteDataSource.deleteCourse(courseId);
  }

  // ─── TEACHER ASSIGNMENTS ───────────────────────────────────────────────────
  @override
  Future<List<CourseAssignment>> getAllCourseAssignments() {
    return _remoteDataSource.getAllCourseAssignments();
  }

  @override
  Future<void> assignCourseToTeacher({
    required String courseId,
    required String teacherId,
    bool isCoordinator = false,
  }) {
    return _remoteDataSource.assignCourseToTeacher(
      courseId: courseId,
      teacherId: teacherId,
      isCoordinator: isCoordinator,
    );
  }

  @override
  Future<void> removeCourseAssignment({
    required String assignmentId,
    required String courseId,
    required String teacherId,
  }) {
    return _remoteDataSource.removeCourseAssignment(
      assignmentId: assignmentId,
      courseId: courseId,
      teacherId: teacherId,
    );
  }

  // ─── SIGNUP PETITIONS ──────────────────────────────────────────────────────
  @override
  Future<List<SignupRequest>> getPendingSignupRequests() {
    return _remoteDataSource.getPendingSignupRequests();
  }

  @override
  Future<List<SignupRequest>> getAllSignupRequests({String? statusFilter}) {
    return _remoteDataSource.getAllSignupRequests(statusFilter: statusFilter);
  }

  @override
  Future<void> approveSignup({
    required String requestId,
    int? assignedYear,
    int? assignedSemester,
  }) {
    return _remoteDataSource.approveSignup(
      requestId: requestId,
      assignedYear: assignedYear,
      assignedSemester: assignedSemester,
    );
  }

  @override
  Future<void> rejectSignup({
    required String requestId,
    required String reason,
  }) {
    return _remoteDataSource.rejectSignup(
      requestId: requestId,
      reason: reason,
    );
  }

  // ─── SEMESTER UPGRADES ─────────────────────────────────────────────────────
  @override
  Future<List<SemesterUpgradeRequest>> getPendingSemesterRequests() {
    return _remoteDataSource.getPendingSemesterRequests();
  }

  @override
  Future<List<SemesterUpgradeRequest>> getAllSemesterRequests({String? statusFilter}) {
    return _remoteDataSource.getAllSemesterRequests(statusFilter: statusFilter);
  }

  @override
  Future<void> approveSemesterUpgrade({required String requestId}) {
    return _remoteDataSource.approveSemesterUpgrade(requestId: requestId);
  }

  @override
  Future<void> rejectSemesterUpgrade({
    required String requestId,
    String? reason,
  }) {
    return _remoteDataSource.rejectSemesterUpgrade(
      requestId: requestId,
      reason: reason,
    );
  }

  // ─── ATTENDANCE OVERVIEW ───────────────────────────────────────────────────
  @override
  Future<List<AttendanceSession>> getAllAttendanceSessions() {
    return _remoteDataSource.getAllAttendanceSessions();
  }

  // ─── FEEDBACK MODERATION ───────────────────────────────────────────────────
  @override
  Future<List<FeedbackItem>> getAllFeedbackItems() {
    return _remoteDataSource.getAllFeedbackItems();
  }

  // ─── NOTICE & NOTIFICATION HUB ─────────────────────────────────────────────
  @override
  Future<List<DepartmentNotice>> getAllNotices() {
    return _remoteDataSource.getAllNotices();
  }

  @override
  Future<void> sendBroadcastNotice({
    required String title,
    required String message,
    required String noticeType,
    required String targetAudience,
    String? attachmentUrl,
    String? attachmentType,
    String priority = 'NORMAL',
    bool syncToPublicRoutines = false,
  }) {
    return _remoteDataSource.sendBroadcastNotice(
      title: title,
      message: message,
      noticeType: noticeType,
      targetAudience: targetAudience,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      priority: priority,
      syncToPublicRoutines: syncToPublicRoutines,
    );
  }

  @override
  Future<void> deleteNotice(String noticeId) {
    return _remoteDataSource.deleteNotice(noticeId);
  }
}
