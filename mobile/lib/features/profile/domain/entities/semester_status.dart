import 'package:equatable/equatable.dart';

class SemesterStatus extends Equatable {
  final String? requestId;
  final int? currentYear;
  final int? currentSemester;
  final int? requestedYear;
  final int? requestedSemester;
  final String status;
  final String? rejectionReason;
  final String? updatedAt;

  const SemesterStatus({
    this.requestId,
    this.currentYear,
    this.currentSemester,
    this.requestedYear,
    this.requestedSemester,
    required this.status,
    this.rejectionReason,
    this.updatedAt,
  });

  bool get hasPendingRequest => status == 'PENDING';
  bool get isPending => status == 'PENDING';
  bool get isRejected => status == 'REJECTED';
  bool get isApproved => status == 'APPROVED' || status == 'ACTIVE';
  bool get isNoEnrollment => status == 'NONE' || status == 'NO_ENROLLMENT' || (currentYear == null && !isPending);

  @override
  List<Object?> get props => [
        requestId,
        currentYear,
        currentSemester,
        requestedYear,
        requestedSemester,
        status,
        rejectionReason,
        updatedAt,
      ];
}

class SemesterUpgradeRequest extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String studentRoll;
  final int currentYear;
  final int currentSemester;
  final int requestedYear;
  final int requestedSemester;
  final String status;
  final String? rejectionReason;
  final String createdAt;

  final String? updatedAt;

  /// The student's note ("Completed all 3-1 finals…").
  final String? notes;

  /// False when the request has no requested semester (old / broken data):
  /// it can only be rejected.
  bool get hasRequestedLevel => requestedYear > 0 && requestedSemester > 0;

  String get currentLabel => 'Year $currentYear · Sem $currentSemester';
  String get requestedLabel => hasRequestedLevel ? 'Year $requestedYear · Sem $requestedSemester' : 'Requested semester missing';

  const SemesterUpgradeRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentRoll,
    required this.currentYear,
    required this.currentSemester,
    required this.requestedYear,
    required this.requestedSemester,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    this.updatedAt,
    this.notes,
  });

  @override
  List<Object?> get props => [
        id,
        studentId,
        studentName,
        studentRoll,
        currentYear,
        currentSemester,
        requestedYear,
        requestedSemester,
        status,
        rejectionReason,
        createdAt,
        updatedAt,
      ];
}
