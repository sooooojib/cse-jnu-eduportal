import '../entities/semester_status.dart';

abstract class SemesterRepository {
  Future<SemesterStatus> getStatus();
  Future<SemesterStatus> requestUpgrade({required int requestedYear, required int requestedSemester});
  Future<SemesterStatus> changeUpgradeRequest({
    required String requestId,
    required int requestedYear,
    required int requestedSemester,
  });
  Future<void> dismissRejection({required String requestId});
  Future<List<SemesterUpgradeRequest>> getMyUpgradeRequests();
}

class GetSemesterStatusUseCase {
  final SemesterRepository repository;
  GetSemesterStatusUseCase(this.repository);

  Future<SemesterStatus> execute() => repository.getStatus();
}

class RequestSemesterUpgradeUseCase {
  final SemesterRepository repository;
  RequestSemesterUpgradeUseCase(this.repository);

  Future<SemesterStatus> execute({required int requestedYear, required int requestedSemester}) =>
      repository.requestUpgrade(requestedYear: requestedYear, requestedSemester: requestedSemester);
}

class ChangeSemesterUpgradeRequestUseCase {
  final SemesterRepository repository;
  ChangeSemesterUpgradeRequestUseCase(this.repository);

  Future<SemesterStatus> execute({
    required String requestId,
    required int requestedYear,
    required int requestedSemester,
  }) =>
      repository.changeUpgradeRequest(
        requestId: requestId,
        requestedYear: requestedYear,
        requestedSemester: requestedSemester,
      );
}

class DismissSemesterRejectionUseCase {
  final SemesterRepository repository;
  DismissSemesterRejectionUseCase(this.repository);

  Future<void> execute({required String requestId}) =>
      repository.dismissRejection(requestId: requestId);
}
