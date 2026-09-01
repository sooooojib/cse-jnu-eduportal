import 'package:equatable/equatable.dart';

class SemesterStatus extends Equatable {
  final int? currentYear;
  final int? currentSemester;
  final int? requestedYear;
  final int? requestedSemester;
  final String status;
  final String? rejectionReason;
  final String? updatedAt;

  const SemesterStatus({
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
  bool get isApproved => status == 'APPROVED';

  @override
  List<Object?> get props => [
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
      ];
}
