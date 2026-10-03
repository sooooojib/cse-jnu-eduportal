import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/department_notice.dart';

String _tsToString(dynamic val) {
  if (val == null) return DateTime.now().toIso8601String();
  if (val is Timestamp) return val.toDate().toIso8601String();
  return val.toString();
}

class DepartmentNoticeModel extends DepartmentNotice {
  const DepartmentNoticeModel({
    required super.id,
    required super.title,
    required super.message,
    required super.noticeType,
    required super.targetAudience,
    super.attachmentUrl,
    super.attachmentType,
    super.priority = 'NORMAL',
    super.syncedToPublicRoutines = false,
    required super.sentBy,
    required super.createdAt,
  });

  factory DepartmentNoticeModel.fromJson(Map<String, dynamic> json) {
    return DepartmentNoticeModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      noticeType: json['noticeType'] as String? ?? 'GENERAL_NOTICE',
      targetAudience: json['targetAudience'] as String? ?? 'ALL',
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentType: json['attachmentType'] as String?,
      priority: json['priority'] as String? ?? 'NORMAL',
      syncedToPublicRoutines: json['syncedToPublicRoutines'] as bool? ?? false,
      sentBy: json['sentBy'] as String? ?? 'Department Administration',
      createdAt: _tsToString(json['createdAt']),
    );
  }

  factory DepartmentNoticeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DepartmentNoticeModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'noticeType': noticeType,
      'targetAudience': targetAudience,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'priority': priority,
      'syncedToPublicRoutines': syncedToPublicRoutines,
      'sentBy': sentBy,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'noticeType': noticeType,
      'targetAudience': targetAudience,
      'attachmentUrl': attachmentUrl,
      'attachmentType': attachmentType,
      'priority': priority,
      'syncedToPublicRoutines': syncedToPublicRoutines,
      'sentBy': sentBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
