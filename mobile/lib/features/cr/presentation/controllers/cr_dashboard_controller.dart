import 'package:flutter/foundation.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/controllers/auth_state.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../domain/usecases/add_tomorrow_slot_usecase.dart';
import '../../domain/usecases/get_cr_dashboard_data_usecase.dart';
import 'cr_dashboard_state.dart';
import '../../../../core/network/cache_first.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

class CrDashboardController extends ValueNotifier<CrDashboardState> {
  final GetCrDashboardDataUseCase getCrDashboardDataUseCase;
  final AddTomorrowSlotUseCase? addTomorrowSlotUseCase;
  final AuthController authController;

  CrDashboardController({
    required this.getCrDashboardDataUseCase,
    this.addTomorrowSlotUseCase,
    required this.authController,
  }) : super(const CrDashboardInitial());

  bool _disposed = false;

  /// A load can finish after the screen closed; ignore updates then.
  @override
  set value(CrDashboardState newValue) {
    if (_disposed) return;
    super.value = newValue;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  User? get currentCrUser {
    final state = authController.state;
    if (state is Authenticated) return state.user;
    return authController.currentUser;
  }

  Future<void> loadDashboardData({bool isRefresh = false}) async {
    final user = currentCrUser;
    if (user == null) {
      value = const CrDashboardError('Not authenticated.');
      return;
    }

    if (!isRefresh) {
      value = const CrDashboardLoading();
    }

    try {
      final data = await getCrDashboardDataUseCase.execute(crUser: user);
      value = CrDashboardLoaded(data);
    } catch (e, stack) {
      AppLogger.e('Error in CrDashboardController.loadDashboardData', e, stack);
      value = CrDashboardError('Unable to load dashboard data: ${friendlyError(e)}');
    }
  }

  Future<void> refreshData() async {
    // Pull-to-refresh: read the routine / courses from the server again.
    await CacheFirst.clear();
    await loadDashboardData(isRefresh: true);
  }

  Future<bool> addTomorrowSlot(ScheduleSlot slot) async {
    final user = currentCrUser;
    if (user == null || addTomorrowSlotUseCase == null) return false;

    try {
      await addTomorrowSlotUseCase!.execute(crUser: user, slot: slot);
      await refreshData();
      return true;
    } catch (e, stack) {
      AppLogger.e('Error adding schedule slot by CR', e, stack);
      return false;
    }
  }
}
