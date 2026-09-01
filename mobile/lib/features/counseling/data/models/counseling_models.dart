import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/counseling_entities.dart';

String _tsToString(dynamic value) {
  if (value == null) return DateTime.now().toIso8601String();
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value.toString();
}

class CounselingSlotModel extends CounselingSlot {
  const CounselingSlotModel({
    required super.id,
    required super.teacherId,
    required super.teacherName,
    required super.teacherEmail,
    required super.slotDate,
    required super.startTime,
    required super.endTime,
    super.notes,
    required super.status,
  });

  factory CounselingSlotModel.fromJson(Map<String, dynamic> json) {
    return CounselingSlotModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      teacherEmail: json['teacherEmail'] as String? ?? '',
      slotDate: _tsToString(json['date'] ?? json['slotDate']),
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      notes: json['notes'] as String?,
      status: (json['isBooked'] as bool? ?? false) ? 'BOOKED' : (json['status'] as String? ?? 'AVAILABLE'),
    );
  }

  factory CounselingSlotModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CounselingSlotModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherEmail': teacherEmail,
      'slotDate': slotDate,
      'startTime': startTime,
      'endTime': endTime,
      'notes': notes,
      'status': status,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherEmail': teacherEmail,
      'slotDate': slotDate,
      'startTime': startTime,
      'endTime': endTime,
      'isBooked': status == 'BOOKED',
      'status': status,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class CounselingBookingModel extends CounselingBooking {
  const CounselingBookingModel({
    required super.id,
    required super.slotId,
    required super.teacherId,
    required super.teacherName,
    required super.slotDate,
    required super.startTime,
    required super.endTime,
    required super.category,
    required super.notes,
    required super.status,
    super.reviewedAt,
    required super.createdAt,
  });

  factory CounselingBookingModel.fromJson(Map<String, dynamic> json) {
    return CounselingBookingModel(
      id: json['id'] as String? ?? '',
      slotId: json['slotId'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      slotDate: _tsToString(json['slotDate']),
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      category: json['category'] as String? ?? 'ACADEMIC_ADVISING',
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      reviewedAt: json['reviewedAt'] != null ? _tsToString(json['reviewedAt']) : null,
      createdAt: _tsToString(json['createdAt']),
    );
  }

  factory CounselingBookingModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CounselingBookingModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slotId': slotId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'slotDate': slotDate,
      'startTime': startTime,
      'endTime': endTime,
      'category': category,
      'notes': notes,
      'status': status,
      'reviewedAt': reviewedAt,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'slotId': slotId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'slotDate': slotDate,
      'startTime': startTime,
      'endTime': endTime,
      'category': category,
      'notes': notes,
      'status': status,
      'reviewedAt': reviewedAt != null ? FieldValue.serverTimestamp() : null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
