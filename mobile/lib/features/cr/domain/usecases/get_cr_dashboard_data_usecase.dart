import '../../../auth/domain/entities/user.dart';
import '../entities/cr_dashboard_data.dart';
import '../repositories/cr_repository.dart';

class GetCrDashboardDataUseCase {
  final CrRepository repository;

  GetCrDashboardDataUseCase(this.repository);

  Future<CrDashboardData> execute({
    required User crUser,
    DateTime? currentTime,
  }) {
    return repository.getCrDashboardData(
      crUser: crUser,
      currentTime: currentTime,
    );
  }
}
