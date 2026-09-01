import 'package:equatable/equatable.dart';
import '../../../../core/constants/role_constants.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? studentId;
  final String? phone;
  final String? avatarUrl;
  final int? year;
  final int? semester;
  final String? semesterStatus;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.studentId,
    this.phone,
    this.avatarUrl,
    this.year,
    this.semester,
    this.semesterStatus,
  });

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        role,
        studentId,
        phone,
        avatarUrl,
        year,
        semester,
        semesterStatus,
      ];
}
