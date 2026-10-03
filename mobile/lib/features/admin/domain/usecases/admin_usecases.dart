import '../entities/admin_stats.dart';
import '../repositories/admin_repository.dart';
import '../../../auth/domain/entities/signup_request.dart';
import '../../../profile/domain/entities/semester_status.dart';

class AdminDashboardData {
  final AdminOverviewStats stats;
  final List<SignupRequest> pendingSignups;
  final List<SemesterUpgradeRequest> pendingSemesterRequests;

  const AdminDashboardData({
    required this.stats,
    required this.pendingSignups,
    required this.pendingSemesterRequests,
  });
}

class GetAdminDashboardDataUseCase {
  final AdminRepository repository;

  GetAdminDashboardDataUseCase(this.repository);

  Future<AdminDashboardData> execute() async {
    final results = await Future.wait([
      repository.getOverviewStats(),
      repository.getPendingSignupRequests(),
      repository.getPendingSemesterRequests(),
    ]);

    return AdminDashboardData(
      stats: results[0] as AdminOverviewStats,
      pendingSignups: results[1] as List<SignupRequest>,
      pendingSemesterRequests: results[2] as List<SemesterUpgradeRequest>,
    );
  }
}

class ApproveSignupRequestUseCase {
  final AdminRepository repository;

  ApproveSignupRequestUseCase(this.repository);

  Future<void> execute({
    required String requestId,
    int? assignedYear,
    int? assignedSemester,
  }) {
    return repository.approveSignup(
      requestId: requestId,
      assignedYear: assignedYear,
      assignedSemester: assignedSemester,
    );
  }
}

class RejectSignupRequestUseCase {
  final AdminRepository repository;

  RejectSignupRequestUseCase(this.repository);

  Future<void> execute({
    required String requestId,
    required String reason,
  }) {
    return repository.rejectSignup(
      requestId: requestId,
      reason: reason,
    );
  }
}

class ApproveSemesterUpgradeUseCase {
  final AdminRepository repository;

  ApproveSemesterUpgradeUseCase(this.repository);

  Future<void> execute({required String requestId}) {
    return repository.approveSemesterUpgrade(requestId: requestId);
  }
}

class RejectSemesterUpgradeUseCase {
  final AdminRepository repository;

  RejectSemesterUpgradeUseCase(this.repository);

  Future<void> execute({
    required String requestId,
    String? reason,
  }) {
    return repository.rejectSemesterUpgrade(
      requestId: requestId,
      reason: reason,
    );
  }
}
