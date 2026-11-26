import '../entities/teacher_monitoring.dart';

abstract class TeacherMonitoringRepository {
  /// Builds the department-wide teacher course delivery report.
  ///
  /// When [periodStart] is set (e.g. semester start), only classes on/after it
  /// count and expected routine classes are estimated from that date.
  Future<TeacherMonitoringReport> loadReport({DateTime? periodStart});
}
