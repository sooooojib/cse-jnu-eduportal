import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/role_constants.dart';
import '../../domain/entities/signup_request.dart';

String _tsToString(dynamic value) {
  if (value == null) return DateTime.now().toIso8601String();
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value.toString();
}

class SignupRequestModel extends SignupRequest {
  const SignupRequestModel({
    required super.id,
    required super.email,
    required super.fullName,
    required super.role,
    super.studentId,
    super.phone,
    required super.status,
    super.rejectionReason,
    super.reviewedBy,
    required super.createdAt,
  });

  factory SignupRequestModel.fromJson(Map<String, dynamic> json) {
    return SignupRequestModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? json['name'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'STUDENT'),
      studentId: json['studentId'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      rejectionReason: json['rejectionReason'] as String?,
      reviewedBy: json['reviewedBy'] as String?,
      createdAt: _tsToString(json['createdAt']),
    );
  }

  factory SignupRequestModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SignupRequestModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'role': role.value,
      if (studentId != null) 'studentId': studentId,
      if (phone != null) 'phone': phone,
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'role': role.value,
      if (studentId != null) 'studentId': studentId,
      if (phone != null) 'phone': phone,
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
