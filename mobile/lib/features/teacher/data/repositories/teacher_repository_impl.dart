import 'package:cse_jnu_eduportal/features/auth/domain/entities/user.dart';
import '../../domain/entities/teacher_dashboard_data.dart';
import '../../domain/repositories/teacher_repository.dart';
import '../datasources/teacher_remote_datasource.dart';

class TeacherRepositoryImpl implements TeacherRepository {
  final TeacherRemoteDataSource remoteDataSource;

  TeacherRepositoryImpl({required this.remoteDataSource});

  @override
  Future<TeacherDashboardData> getTeacherDashboardData({
    required User teacher,
    DateTime? currentTime,
  }) {
    return remoteDataSource.getTeacherDashboardData(
      teacher: teacher,
      currentTime: currentTime,
    );
  }
}
