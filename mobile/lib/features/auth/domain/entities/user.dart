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
  final List<String> assignedCourseIds;
  final List<String> fcmTokens;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

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
    this.assignedCourseIds = const [],
    this.fcmTokens = const [],
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? studentId,
    String? phone,
    String? avatarUrl,
    int? year,
    int? semester,
    String? semesterStatus,
    List<String>? assignedCourseIds,
    List<String>? fcmTokens,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      studentId: studentId ?? this.studentId,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      semesterStatus: semesterStatus ?? this.semesterStatus,
      assignedCourseIds: assignedCourseIds ?? this.assignedCourseIds,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
        assignedCourseIds,
        fcmTokens,
        isActive,
        createdAt,
        updatedAt,
      ];
}
