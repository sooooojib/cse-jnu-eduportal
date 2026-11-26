import 'package:equatable/equatable.dart';
import '../../../../core/constants/role_constants.dart';

class SignupRequest extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? studentId;
  final String? phone;

  /// Academic session / batch, e.g. "2021-2022" (students & CRs only).
  final String? session;
  final String status;
  final String? rejectionReason;
  final String? reviewedBy;
  final String createdAt;

  const SignupRequest({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.studentId,
    this.phone,
    this.session,
    required this.status,
    this.rejectionReason,
    this.reviewedBy,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        role,
        studentId,
        phone,
        session,
        status,
        rejectionReason,
        reviewedBy,
        createdAt,
      ];
}
