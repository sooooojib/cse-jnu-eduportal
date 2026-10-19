import '../../../auth/domain/entities/user.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../entities/cr_dashboard_data.dart';

abstract class CrRepository {
  Future<CrDashboardData> getCrDashboardData({
    required User crUser,
    DateTime? currentTime,
  });

  Future<void> addTomorrowClassSlot({
    required User crUser,
    required ScheduleSlot slot,
  });
}
