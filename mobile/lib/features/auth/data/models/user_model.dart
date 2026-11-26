import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user.dart';
import '../../../../core/constants/role_constants.dart';

String _tsToString(dynamic value) {
  if (value == null) return DateTime.now().toIso8601String();
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value.toString();
}

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    required super.role,
    super.studentId,
    super.phone,
    super.avatarUrl,
    super.year,
    super.semester,
    super.semesterStatus,
    super.session,
    super.isAdminDelegate = false,
    super.assignedCourseIds = const [],
    super.fcmTokens = const [],
    super.isActive = true,
    super.createdAt,
    super.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'STUDENT'),
      studentId: json['studentId'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      year: json['year'] as int?,
      semester: json['semester'] as int?,
      semesterStatus: json['semesterStatus'] as String?,
      session: json['session'] as String?,
      isAdminDelegate: json['isAdminDelegate'] as bool? ?? false,
      assignedCourseIds: (json['assignedCourseIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      fcmTokens: (json['fcmTokens'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null ? _tsToString(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? _tsToString(json['updatedAt']) : null,
    );
  }

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? authoritativeRole,
  }) {
    final data = doc.data() ?? {};
    // The users record is the source of truth (the security rules use it too).
    // A login-token role claim is only a fallback for a record without a role,
    // so a stale claim can never override a demotion or a CR hand-over.
    final recordRole = (data['role'] as String?)?.trim() ?? '';
    final effectiveRole = recordRole.isNotEmpty
        ? recordRole
        : ((authoritativeRole != null && authoritativeRole.isNotEmpty) ? authoritativeRole : 'STUDENT');
    return UserModel.fromJson({
      'id': doc.id,
      ...data,
      'role': effectiveRole,
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role.value,
      if (studentId != null) 'studentId': studentId,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (year != null) 'year': year,
      if (semester != null) 'semester': semester,
      if (semesterStatus != null) 'semesterStatus': semesterStatus,
      if (session != null) 'session': session,
      'isAdminDelegate': isAdminDelegate,
      'assignedCourseIds': assignedCourseIds,
      'fcmTokens': fcmTokens,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'role': role.value,
      if (studentId != null) 'studentId': studentId,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (year != null) 'year': year,
      if (semester != null) 'semester': semester,
      if (semesterStatus != null) 'semesterStatus': semesterStatus,
      if (session != null) 'session': session,
      'isAdminDelegate': isAdminDelegate,
      'assignedCourseIds': assignedCourseIds,
      'fcmTokens': fcmTokens,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
