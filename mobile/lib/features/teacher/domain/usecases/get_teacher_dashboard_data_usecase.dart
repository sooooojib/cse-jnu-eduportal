import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import '../entities/teacher_dashboard_data.dart';
import '../repositories/teacher_repository.dart';

class GetTeacherDashboardDataUseCase {
  final TeacherRepository repository;

  GetTeacherDashboardDataUseCase(this.repository);

  Future<TeacherDashboardData> execute({
    required User teacher,
    DateTime? currentTime,
  }) {
    return repository.getTeacherDashboardData(
      teacher: teacher,
      currentTime: currentTime,
    );
  }
}
