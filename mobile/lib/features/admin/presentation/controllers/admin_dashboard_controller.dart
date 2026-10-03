import 'package:flutter/foundation.dart';
import '../../domain/usecases/admin_usecases.dart';
import 'admin_dashboard_state.dart';

class AdminDashboardController extends ChangeNotifier {
  final GetAdminDashboardDataUseCase _getDataUseCase;
  final ApproveSignupRequestUseCase _approveSignupUseCase;
  final RejectSignupRequestUseCase _rejectSignupUseCase;
  final ApproveSemesterUpgradeUseCase _approveSemesterUseCase;
  final RejectSemesterUpgradeUseCase _rejectSemesterUseCase;

  AdminDashboardState _state = const AdminDashboardInitial();
  AdminDashboardState get state => _state;

  AdminDashboardController({
    required GetAdminDashboardDataUseCase getDataUseCase,
    required ApproveSignupRequestUseCase approveSignupUseCase,
    required RejectSignupRequestUseCase rejectSignupUseCase,
    required ApproveSemesterUpgradeUseCase approveSemesterUseCase,
    required RejectSemesterUpgradeUseCase rejectSemesterUseCase,
  })  : _getDataUseCase = getDataUseCase,
        _approveSignupUseCase = approveSignupUseCase,
        _rejectSignupUseCase = rejectSignupUseCase,
        _approveSemesterUseCase = approveSemesterUseCase,
        _rejectSemesterUseCase = rejectSemesterUseCase;

  Future<void> loadDashboard({bool refresh = false}) async {
    if (!refresh && _state is! AdminDashboardLoaded) {
      _state = const AdminDashboardLoading();
      notifyListeners();
    }

    try {
      final data = await _getDataUseCase.execute();
      _state = AdminDashboardLoaded(
        stats: data.stats,
        pendingSignups: data.pendingSignups,
        pendingSemesterRequests: data.pendingSemesterRequests,
      );
      notifyListeners();
    } catch (e) {
      _state = AdminDashboardError(message: e.toString());
      notifyListeners();
    }
  }

  Future<bool> approveSignup({
    required String requestId,
    int? assignedYear,
    int? assignedSemester,
  }) async {
    final current = _state;
    if (current is! AdminDashboardLoaded) return false;

    _state = current.copyWith(isProcessingAction: true);
    notifyListeners();

    try {
      await _approveSignupUseCase.execute(
        requestId: requestId,
        assignedYear: assignedYear,
        assignedSemester: assignedSemester,
      );

      // Remove from list and update pending counter
      final updatedSignups = current.pendingSignups.where((r) => r.id != requestId).toList();
      final updatedStats = current.stats.copyWith(
        pendingSignups: (current.stats.pendingSignups - 1).clamp(0, 999999),
        totalStudents: assignedYear != null ? current.stats.totalStudents + 1 : current.stats.totalStudents,
      );

      _state = current.copyWith(
        isProcessingAction: false,
        pendingSignups: updatedSignups,
        stats: updatedStats,
        actionSuccessMessage: 'Signup petition approved & credentials provisioned.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = current.copyWith(
        isProcessingAction: false,
        actionErrorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectSignup({
    required String requestId,
    required String reason,
  }) async {
    final current = _state;
    if (current is! AdminDashboardLoaded) return false;

    _state = current.copyWith(isProcessingAction: true);
    notifyListeners();

    try {
      await _rejectSignupUseCase.execute(
        requestId: requestId,
        reason: reason,
      );

      final updatedSignups = current.pendingSignups.where((r) => r.id != requestId).toList();
      final updatedStats = current.stats.copyWith(
        pendingSignups: (current.stats.pendingSignups - 1).clamp(0, 999999),
      );

      _state = current.copyWith(
        isProcessingAction: false,
        pendingSignups: updatedSignups,
        stats: updatedStats,
        actionSuccessMessage: 'Signup petition rejected.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = current.copyWith(
        isProcessingAction: false,
        actionErrorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveSemesterUpgrade({required String requestId}) async {
    final current = _state;
    if (current is! AdminDashboardLoaded) return false;

    _state = current.copyWith(isProcessingAction: true);
    notifyListeners();

    try {
      await _approveSemesterUseCase.execute(requestId: requestId);

      final updatedSemesterRequests = current.pendingSemesterRequests.where((r) => r.id != requestId).toList();
      final updatedStats = current.stats.copyWith(
        pendingSemesterRequests: (current.stats.pendingSemesterRequests - 1).clamp(0, 999999),
      );

      _state = current.copyWith(
        isProcessingAction: false,
        pendingSemesterRequests: updatedSemesterRequests,
        stats: updatedStats,
        actionSuccessMessage: 'Semester promotion approved and synced to student profile.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = current.copyWith(
        isProcessingAction: false,
        actionErrorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectSemesterUpgrade({
    required String requestId,
    String? reason,
  }) async {
    final current = _state;
    if (current is! AdminDashboardLoaded) return false;

    _state = current.copyWith(isProcessingAction: true);
    notifyListeners();

    try {
      await _rejectSemesterUseCase.execute(requestId: requestId, reason: reason);

      final updatedSemesterRequests = current.pendingSemesterRequests.where((r) => r.id != requestId).toList();
      final updatedStats = current.stats.copyWith(
        pendingSemesterRequests: (current.stats.pendingSemesterRequests - 1).clamp(0, 999999),
      );

      _state = current.copyWith(
        isProcessingAction: false,
        pendingSemesterRequests: updatedSemesterRequests,
        stats: updatedStats,
        actionSuccessMessage: 'Semester upgrade request rejected.',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _state = current.copyWith(
        isProcessingAction: false,
        actionErrorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }
}
