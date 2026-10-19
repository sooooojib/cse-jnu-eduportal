import 'package:flutter/foundation.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/usecases/get_teacher_dashboard_data_usecase.dart';
import 'teacher_dashboard_state.dart';

class TeacherDashboardController extends ChangeNotifier {
  final GetTeacherDashboardDataUseCase getTeacherDashboardDataUseCase;
  final AuthController authController;

  TeacherDashboardState _state = const TeacherDashboardInitial();
  DateTime? _simulatedTime;

  TeacherDashboardController({
    required this.getTeacherDashboardDataUseCase,
    required this.authController,
  });

  TeacherDashboardState get state => _state;
  DateTime? get simulatedTime => _simulatedTime;

  /// Loads or reloads dashboard data for the authenticated teacher.
  Future<void> loadDashboardData({DateTime? currentTime}) async {
    _simulatedTime = currentTime;
    _state = const TeacherDashboardLoading();
    notifyListeners();

    try {
      final User? currentUser = authController.currentUser;
      if (currentUser == null) {
        _state = const TeacherDashboardError('User is not authenticated.');
        notifyListeners();
        return;
      }

      final data = await getTeacherDashboardDataUseCase.execute(
        teacher: currentUser,
        currentTime: currentTime,
      );

      _state = TeacherDashboardLoaded(data);
      notifyListeners();
    } catch (e, stack) {
      AppLogger.e('Error loading teacher dashboard', e, stack);
      _state = TeacherDashboardError(e.toString().replaceAll('Exception: ', ''));
      notifyListeners();
    }
  }

  /// Triggers a pull-to-refresh without clearing state abruptly.
  Future<void> refreshData() async {
    try {
      final User? currentUser = authController.currentUser;
      if (currentUser == null) return;

      final data = await getTeacherDashboardDataUseCase.execute(
        teacher: currentUser,
        currentTime: _simulatedTime,
      );

      _state = TeacherDashboardLoaded(data);
      notifyListeners();
    } catch (e) {
      AppLogger.w('Silent refresh failed: $e');
    }
  }
}
