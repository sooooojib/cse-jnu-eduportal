import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/semester_status.dart';

String _tsToString(dynamic value) {
  if (value == null) return DateTime.now().toIso8601String();
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value.toString();
}

class SemesterUpgradeRequestModel extends SemesterUpgradeRequest {
  const SemesterUpgradeRequestModel({
    super.id = '',
    super.studentId = '',
    super.studentName = '',
    super.studentRoll = '',
    super.currentYear = 1,
    super.currentSemester = 1,
    super.requestedYear = 1,
    super.requestedSemester = 1,
    super.status = 'PENDING',
    super.rejectionReason,
    super.createdAt = '',
    super.updatedAt,
  });

  factory SemesterUpgradeRequestModel.fromJson(Map<String, dynamic> json) {
    return SemesterUpgradeRequestModel(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      studentRoll: json['studentRoll'] as String? ?? '',
      currentYear: json['currentYear'] as int? ?? 1,
      currentSemester: json['currentSemester'] as int? ?? 1,
      requestedYear: json['requestedYear'] as int? ?? 1,
      requestedSemester: json['requestedSemester'] as int? ?? 1,
      status: json['status'] as String? ?? 'PENDING',
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: _tsToString(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? _tsToString(json['updatedAt']) : null,
    );
  }

  factory SemesterUpgradeRequestModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SemesterUpgradeRequestModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentRoll': studentRoll,
      'currentYear': currentYear,
      'currentSemester': currentSemester,
      'requestedYear': requestedYear,
      'requestedSemester': requestedSemester,
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentRoll': studentRoll,
      'currentYear': currentYear,
      'currentSemester': currentSemester,
      'requestedYear': requestedYear,
      'requestedSemester': requestedSemester,
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class SemesterStatusModel extends SemesterStatus {
  const SemesterStatusModel({
    super.currentYear,
    super.currentSemester,
    super.requestedYear,
    super.requestedSemester,
    required super.status,
    super.rejectionReason,
    super.updatedAt,
  });

  factory SemesterStatusModel.fromJson(Map<String, dynamic> json) {
    return SemesterStatusModel(
      currentYear: json['currentYear'] as int?,
      currentSemester: json['currentSemester'] as int?,
      requestedYear: json['requestedYear'] as int?,
      requestedSemester: json['requestedSemester'] as int?,
      status: json['semesterStatus'] as String? ?? json['status'] as String? ?? 'NONE',
      rejectionReason: json['rejectionReason'] as String?,
      updatedAt: json['updatedAt'] != null ? _tsToString(json['updatedAt']) : null,
    );
  }

  factory SemesterStatusModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SemesterStatusModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      if (currentYear != null) 'currentYear': currentYear,
      if (currentSemester != null) 'currentSemester': currentSemester,
      if (requestedYear != null) 'requestedYear': requestedYear,
      if (requestedSemester != null) 'requestedSemester': requestedSemester,
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (currentYear != null) 'currentYear': currentYear,
      if (currentSemester != null) 'currentSemester': currentSemester,
      if (requestedYear != null) 'requestedYear': requestedYear,
      if (requestedSemester != null) 'requestedSemester': requestedSemester,
      'status': status,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
