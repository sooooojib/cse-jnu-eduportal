import '../entities/semester_status.dart';

abstract class SemesterRepository {
  Future<SemesterStatus> getStatus();
  Future<SemesterStatus> requestUpgrade({required int requestedYear, required int requestedSemester});
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
