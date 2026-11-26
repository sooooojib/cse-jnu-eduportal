import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../cr/domain/entities/cr_dashboard_data.dart';
import '../../../cr/domain/repositories/cr_repository.dart';
import '../../../cr/domain/usecases/get_cr_dashboard_data_usecase.dart';
import '../../../cr/presentation/controllers/cr_dashboard_controller.dart';
import '../../../cr/presentation/widgets/batch_dashboard_view.dart';
import 'package:cse_jnu_eduportal/core/utils/refresh_on_reopen.dart';

/// Student Dashboard Screen — delegates rendering to [BatchDashboardView] with
/// regular student permissions (`isCrMode: false`).
class StudentDashboardShell extends StatefulWidget {
  final AuthController authController;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final bool wrapWithScaffold;
  final void Function(int tabIndex)? onNavigateTab;
  final CrDashboardController? controller;

  const StudentDashboardShell({
    super.key,
    required this.authController,
    required this.themeModeNotifier,
    this.wrapWithScaffold = true,
    this.onNavigateTab,
    this.controller,
  });

  @override
  State<StudentDashboardShell> createState() => _StudentDashboardShellState();
}

class _StudentDashboardShellState extends State<StudentDashboardShell> with RefreshOnReopen {
  late final CrDashboardController _controller;
  bool _ownsController = false;

  // S2-13: reload quietly when the app / tab is reopened.
  @override
  void onReopened() => _controller.loadDashboardData(isRefresh: true);

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else if (sl.isRegistered<CrDashboardController>()) {
      // registerFactory → a fresh instance for this screen, so we own it.
      _controller = sl<CrDashboardController>();
      _ownsController = true;
    } else if (sl.isRegistered<GetCrDashboardDataUseCase>()) {
      _controller = CrDashboardController(
        getCrDashboardDataUseCase: sl<GetCrDashboardDataUseCase>(),
        authController: widget.authController,
      );
      _ownsController = true;
    } else {
      final user = widget.authController.currentUser;
      _controller = CrDashboardController(
        getCrDashboardDataUseCase: _StubGetCrDashboardDataUseCase(user),
        authController: widget.authController,
      );
      _ownsController = true;
    }
    _controller.loadDashboardData();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BatchDashboardView(
      controller: _controller,
      authController: widget.authController,
      isCrMode: false,
      wrapWithScaffold: widget.wrapWithScaffold,
      onNavigateTab: widget.onNavigateTab,
    );
  }
}

class _StubGetCrDashboardDataUseCase implements GetCrDashboardDataUseCase {
  final User? user;
  _StubGetCrDashboardDataUseCase(this.user);

  @override
  CrRepository get repository => throw UnimplementedError();

  @override
  Future<CrDashboardData> execute({required User crUser, DateTime? currentTime}) async {
    final effectiveUser = user ?? crUser;
    return CrDashboardData(
      crId: effectiveUser.id,
      crName: effectiveUser.fullName,
      email: effectiveUser.email,
      phone: effectiveUser.phone,
      avatarUrl: effectiveUser.avatarUrl,
      role: effectiveUser.role,
      year: effectiveUser.year ?? 1,
      semester: effectiveUser.semester ?? 1,
      studentId: effectiveUser.studentId,
      attendancePercentage: 85.0,
      attendedClasses: 17,
      totalClasses: 20,
      isAttendanceEligible: true,
      classesTodayCount: 0,
      availableCounselingSlotsCount: 0,
      myActiveCounselingCount: 0,
      upcomingExamsCount: 0,
      targetDateLabel: 'Today · Oct 19, 2026',
      dayOfWeek: 'MONDAY',
      tomorrowDateLabel: 'Tomorrow · Oct 20, 2026',
    );
  }
}
