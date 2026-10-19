import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import '../entities/teacher_dashboard_data.dart';

abstract class TeacherRepository {
  /// Fetches complete aggregated dashboard data for the given [teacher].
  /// [currentTime] can be provided to test or override the time-aware window.
  Future<TeacherDashboardData> getTeacherDashboardData({
    required User teacher,
    DateTime? currentTime,
  });
}
