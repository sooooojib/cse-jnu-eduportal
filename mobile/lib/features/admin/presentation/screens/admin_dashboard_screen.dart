import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/states/app_error_state_view.dart';
import '../../../../shared/widgets/states/app_loading_view.dart';
import '../../../auth/domain/entities/signup_request.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../profile/domain/entities/semester_status.dart';
import '../../domain/entities/admin_stats.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../attendance/domain/entities/attendance_entities.dart';
import '../../../feedback/domain/entities/feedback_entities.dart';
import '../../domain/entities/department_notice.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/admin_usecases.dart';
import '../controllers/admin_dashboard_controller.dart';
import '../controllers/admin_dashboard_state.dart';
import '../widgets/admin_header.dart';
import '../widgets/admin_overview_grid.dart';
import '../widgets/admin_quick_actions_grid.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AdminDashboardController? controller;
  final AuthController? authController;

  const AdminDashboardScreen({
    super.key,
    this.controller,
    this.authController,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminDashboardController _controller;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else if (sl.isRegistered<AdminDashboardController>()) {
      _controller = sl<AdminDashboardController>();
    } else {
      final repo = _NoOpAdminRepository();
      _controller = AdminDashboardController(
        getDataUseCase: GetAdminDashboardDataUseCase(repo),
        approveSignupUseCase: ApproveSignupRequestUseCase(repo),
        rejectSignupUseCase: RejectSignupRequestUseCase(repo),
        approveSemesterUseCase: ApproveSemesterUpgradeUseCase(repo),
        rejectSemesterUseCase: RejectSemesterUpgradeUseCase(repo),
      );
    }

    _authController = widget.authController ?? sl<AuthController>();
    _controller.loadDashboard();
    _controller.addListener(_handleStateChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleStateChange);
    super.dispose();
  }

  void _handleStateChange() {
    if (!mounted) return;
    final state = _controller.state;
    if (state is AdminDashboardLoaded) {
      if (state.actionSuccessMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.actionSuccessMessage!),
            backgroundColor: const Color(0xFF047857),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (state.actionErrorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.actionErrorMessage!),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final user = _authController.currentUser;

        if (state is AdminDashboardLoading || state is AdminDashboardInitial) {
          return const Scaffold(
            body: Center(
              child: AppLoadingView(message: 'Loading Department Administration...'),
            ),
          );
        }

        if (state is AdminDashboardError) {
          return Scaffold(
            body: Center(
              child: AppErrorStateView(
                title: 'Unable to Load Admin Console',
                message: state.message,
                onRetry: () => _controller.loadDashboard(refresh: true),
              ),
            ),
          );
        }

        if (state is AdminDashboardLoaded) {
          final isDark = context.isDarkMode;

          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0B1C30) : const Color(0xFFF8F9FF),
            body: SafeArea(
              top: true,
              bottom: false,
              child: RefreshIndicator(
                color: const Color(0xFF7E22CE),
                onRefresh: () => _controller.loadDashboard(refresh: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Admin Header
                      AdminHeader(
                        user: user,
                        authController: _authController,
                      ),
                      const SizedBox(height: 24),

                      // 2. Administrative Overview Grid
                      AdminOverviewGrid(
                        stats: state.stats,
                        onStudentsTap: () => context.push('${RouteNames.adminUsers}?role=students'),
                        onFacultyTap: () => context.push('${RouteNames.adminUsers}?role=faculty'),
                        onCrsTap: () => context.push('${RouteNames.adminUsers}?role=cr'),
                        onCoursesTap: () => context.push(RouteNames.adminCourses),
                        onPendingSignupsTap: () => context.push(RouteNames.adminSignupRequests),
                        onPendingSemesterTap: () => context.push(RouteNames.adminSemesterRequests),
                        onUsersTap: () => context.push(RouteNames.adminUsers),
                      ),
                      const SizedBox(height: 24),

                      // 3. Administrative Quick Actions
                      const AdminQuickActionsGrid(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _NoOpAdminRepository implements AdminRepository {
  @override
  Future<AdminOverviewStats> getOverviewStats() async => const AdminOverviewStats();

  @override
  Future<List<SignupRequest>> getPendingSignupRequests() async => [];

  @override
  Future<List<SemesterUpgradeRequest>> getPendingSemesterRequests() async => [];

  @override
  Future<void> approveSignup({
    required String requestId,
    int? assignedYear,
    int? assignedSemester,
  }) async {}

  @override
  Future<void> rejectSignup({
    required String requestId,
    required String reason,
  }) async {}

  @override
  Future<void> approveSemesterUpgrade({required String requestId}) async {}

  @override
  Future<void> rejectSemesterUpgrade({
    required String requestId,
    String? reason,
  }) async {}

  @override
  Future<List<User>> getAllUsers({UserRole? roleFilter}) async => [];

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
  }) async => User(id: 'noop', email: email, fullName: fullName, role: role);

  @override
  Future<void> deleteUser({required String userId}) async {}

  @override
  Future<void> toggleUserActiveStatus({required String userId, required bool isActive}) async {}

  @override
  Future<List<Course>> getAllCourses() async => [];

  @override
  Future<void> createCourse(Course course) async {}

  @override
  Future<void> updateCourse(Course course) async {}

  @override
  Future<void> deleteCourse(String courseId) async {}

  @override
  Future<List<CourseAssignment>> getAllCourseAssignments() async => [];

  @override
  Future<void> assignCourseToTeacher({
    required String courseId,
    required String teacherId,
    bool isCoordinator = false,
  }) async {}

  @override
  Future<void> removeCourseAssignment({
    required String assignmentId,
    required String courseId,
    required String teacherId,
  }) async {}

  @override
  Future<List<SignupRequest>> getAllSignupRequests({String? statusFilter}) async => [];

  @override
  Future<List<SemesterUpgradeRequest>> getAllSemesterRequests({String? statusFilter}) async => [];

  @override
  Future<List<AttendanceSession>> getAllAttendanceSessions() async => [];

  @override
  Future<List<FeedbackItem>> getAllFeedbackItems() async => [];

  @override
  Future<List<DepartmentNotice>> getAllNotices() async => [];

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
  }) async {}

  @override
  Future<void> deleteNotice(String noticeId) async {}
}
