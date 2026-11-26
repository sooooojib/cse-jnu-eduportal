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

  /// Academic session / batch, e.g. "2021-2022" (students & CRs only).
  final String? session;

  /// Faculty member granted access to the limited Admin View
  /// (signup review committee). Chairman & Admin don't need this flag.
  final bool isAdminDelegate;
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
    this.session,
    this.isAdminDelegate = false,
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
    String? session,
    bool? isAdminDelegate,
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
      session: session ?? this.session,
      isAdminDelegate: isAdminDelegate ?? this.isAdminDelegate,
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
        session,
        isAdminDelegate,
        assignedCourseIds,
        fcmTokens,
        isActive,
        createdAt,
        updatedAt,
      ];

  /// Whether the dashboard should offer the Faculty / Admin view switcher.
  bool get canSwitchToAdminView =>
      role == UserRole.chairman || role == UserRole.teacher;
}
