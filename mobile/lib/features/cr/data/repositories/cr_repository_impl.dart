import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../domain/entities/cr_dashboard_data.dart';
import '../../domain/repositories/cr_repository.dart';
import '../datasources/cr_remote_datasource.dart';

class CrRepositoryImpl implements CrRepository {
  final CrRemoteDataSource remoteDataSource;

  CrRepositoryImpl({required this.remoteDataSource});

  @override
  Future<CrDashboardData> getCrDashboardData({
    required User crUser,
    DateTime? currentTime,
  }) async {
    try {
      return await remoteDataSource.getCrDashboardData(
        crUser: crUser,
        currentTime: currentTime,
      );
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    } catch (e) {
      throw ServerFailure(message: 'Failed to load CR dashboard data: $e');
    }
  }

  @override
  Future<void> addTomorrowClassSlot({
    required User crUser,
    required ScheduleSlot slot,
  }) async {
    try {
      await remoteDataSource.addTomorrowClassSlot(
        crUser: crUser,
        slot: slot,
      );
    } on ServerException catch (e) {
      throw ServerFailure(message: e.message);
    } catch (e) {
      throw ServerFailure(message: 'Failed to schedule class slot: $e');
    }
  }
}
