import '../entities/attendance_entities.dart';

abstract class AttendanceRepository {
  Future<AttendanceSummary> getMySummary();
  Future<Map<String, dynamic>> verifyCode(String code, {String? courseId});
}

class GetAttendanceSummaryUseCase {
  final AttendanceRepository repository;
  GetAttendanceSummaryUseCase(this.repository);

  Future<AttendanceSummary> execute() => repository.getMySummary();
}

class VerifyAttendanceCodeUseCase {
  final AttendanceRepository repository;
  VerifyAttendanceCodeUseCase(this.repository);

  Future<Map<String, dynamic>> execute(String code, {String? courseId}) =>
      repository.verifyCode(code, courseId: courseId);
}
