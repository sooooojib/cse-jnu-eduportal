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
    final effectiveRole = (authoritativeRole != null && authoritativeRole.isNotEmpty)
        ? authoritativeRole
        : (data['role'] as String? ?? 'STUDENT');
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
      'assignedCourseIds': assignedCourseIds,
      'fcmTokens': fcmTokens,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
