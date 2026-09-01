import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user.dart';
import '../../../../core/constants/role_constants.dart';

class UserModel extends User {
  final List<String> assignedCourseIds;
  final bool isActive;

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
    this.assignedCourseIds = const [],
    this.isActive = true,
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
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role.value,
      'studentId': studentId,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'year': year,
      'semester': semester,
      'semesterStatus': semesterStatus,
      'assignedCourseIds': assignedCourseIds,
      'isActive': isActive,
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
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
