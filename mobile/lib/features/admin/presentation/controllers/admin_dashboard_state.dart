import '../../domain/entities/admin_stats.dart';
import '../../../auth/domain/entities/signup_request.dart';
import '../../../profile/domain/entities/semester_status.dart';

abstract class AdminDashboardState {
  const AdminDashboardState();
}

class AdminDashboardInitial extends AdminDashboardState {
  const AdminDashboardInitial();
}

class AdminDashboardLoading extends AdminDashboardState {
  const AdminDashboardLoading();
}

class AdminDashboardLoaded extends AdminDashboardState {
  final AdminOverviewStats stats;
  final List<SignupRequest> pendingSignups;
  final List<SemesterUpgradeRequest> pendingSemesterRequests;
  final bool isProcessingAction;
  final String? actionSuccessMessage;
  final String? actionErrorMessage;

  const AdminDashboardLoaded({
    required this.stats,
    required this.pendingSignups,
    required this.pendingSemesterRequests,
    this.isProcessingAction = false,
    this.actionSuccessMessage,
    this.actionErrorMessage,
  });

  AdminDashboardLoaded copyWith({
    AdminOverviewStats? stats,
    List<SignupRequest>? pendingSignups,
    List<SemesterUpgradeRequest>? pendingSemesterRequests,
    bool? isProcessingAction,
    String? actionSuccessMessage,
    String? actionErrorMessage,
  }) {
    return AdminDashboardLoaded(
      stats: stats ?? this.stats,
      pendingSignups: pendingSignups ?? this.pendingSignups,
      pendingSemesterRequests: pendingSemesterRequests ?? this.pendingSemesterRequests,
      isProcessingAction: isProcessingAction ?? this.isProcessingAction,
      actionSuccessMessage: actionSuccessMessage,
      actionErrorMessage: actionErrorMessage,
    );
  }
}

class AdminDashboardError extends AdminDashboardState {
  final String message;

  const AdminDashboardError({required this.message});
}
