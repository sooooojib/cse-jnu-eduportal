import '../entities/attendance_entities.dart';

abstract class AttendanceRepository {
  Future<AttendanceSummary> getMySummary();
  Future<AttendanceVerificationResult> verifyCode(String code, {String? courseId});
}

class GetAttendanceSummaryUseCase {
  final AttendanceRepository repository;
  GetAttendanceSummaryUseCase(this.repository);

  Future<AttendanceSummary> execute() => repository.getMySummary();
}

class VerifyAttendanceCodeUseCase {
  final AttendanceRepository repository;
  VerifyAttendanceCodeUseCase(this.repository);

  Future<AttendanceVerificationResult> execute(String code, {String? courseId}) =>
      repository.verifyCode(code, courseId: courseId);
}
