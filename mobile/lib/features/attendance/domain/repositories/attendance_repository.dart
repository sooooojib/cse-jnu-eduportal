import '../entities/attendance_entities.dart';

abstract class AttendanceRepository {
  Future<AttendanceSummary> getMySummary();
  Future<AttendanceVerificationResult> verifyCode(String code, {String? courseId});
  Future<AttendanceSession> startSession({required String courseId, int? durationMinutes});
  Future<void> deactivateSession({required String sessionId});
  Future<AttendanceSession?> getActiveSession({required String courseId});
  Future<SessionRoster> getSessionRoster({required String sessionId});
  Future<void> updateRoster({required String sessionId, required List<AttendanceRosterItem> updates});
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

class StartAttendanceSessionUseCase {
  final AttendanceRepository repository;
  StartAttendanceSessionUseCase(this.repository);

  Future<AttendanceSession> execute({required String courseId, int? durationMinutes}) =>
      repository.startSession(courseId: courseId, durationMinutes: durationMinutes);
}

class DeactivateAttendanceSessionUseCase {
  final AttendanceRepository repository;
  DeactivateAttendanceSessionUseCase(this.repository);

  Future<void> execute({required String sessionId}) =>
      repository.deactivateSession(sessionId: sessionId);
}

class GetActiveAttendanceSessionUseCase {
  final AttendanceRepository repository;
  GetActiveAttendanceSessionUseCase(this.repository);

  Future<AttendanceSession?> execute({required String courseId}) =>
      repository.getActiveSession(courseId: courseId);
}

class GetSessionRosterUseCase {
  final AttendanceRepository repository;
  GetSessionRosterUseCase(this.repository);

  Future<SessionRoster> execute({required String sessionId}) =>
      repository.getSessionRoster(sessionId: sessionId);
}

class UpdateAttendanceRosterUseCase {
  final AttendanceRepository repository;
  UpdateAttendanceRosterUseCase(this.repository);

  Future<void> execute({required String sessionId, required List<AttendanceRosterItem> updates}) =>
      repository.updateRoster(sessionId: sessionId, updates: updates);
}
