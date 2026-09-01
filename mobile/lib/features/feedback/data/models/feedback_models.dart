import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/feedback_entities.dart';

String _tsToString(dynamic value) {
  if (value == null) return DateTime.now().toIso8601String();
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value.toString();
}

class AttachmentModel extends Attachment {
  const AttachmentModel({
    required super.id,
    required super.fileName,
    required super.fileUrl,
    required super.mimeType,
    required super.fileSize,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileUrl: json['fileUrl'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      fileSize: json['fileSize'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'mimeType': mimeType,
      'fileSize': fileSize,
    };
  }
}

class FeedbackReplyModel extends FeedbackReply {
  const FeedbackReplyModel({
    required super.id,
    required super.teacherName,
    required super.replyText,
    required super.createdAt,
  });

  factory FeedbackReplyModel.fromJson(Map<String, dynamic> json) {
    return FeedbackReplyModel(
      id: json['id'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      replyText: json['replyText'] as String? ?? '',
      createdAt: _tsToString(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacherName': teacherName,
      'replyText': replyText,
      'createdAt': createdAt,
    };
  }
}

class FeedbackItemModel extends FeedbackItem {
  const FeedbackItemModel({
    required super.id,
    required super.teacherId,
    required super.teacherName,
    super.courseId,
    super.courseCode,
    super.courseTitle,
    required super.rating,
    required super.comments,
    required super.isAnonymous,
    super.attachments = const [],
    required super.replies,
    required super.createdAt,
  });

  factory FeedbackItemModel.fromJson(Map<String, dynamic> json) {
    final repliesList = (json['replies'] as List? ?? [])
        .map((r) => FeedbackReplyModel.fromJson(r as Map<String, dynamic>))
        .toList();
    final attachmentsList = (json['attachments'] as List? ?? [])
        .map((a) => AttachmentModel.fromJson(a as Map<String, dynamic>))
        .toList();

    return FeedbackItemModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      courseId: json['courseId'] as String?,
      courseCode: json['courseCode'] as String?,
      courseTitle: json['courseTitle'] as String?,
      rating: json['rating'] as int? ?? 0,
      comments: json['comments'] as String? ?? '',
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      attachments: attachmentsList,
      replies: List<FeedbackReply>.from(repliesList),
      createdAt: _tsToString(json['createdAt']),
    );
  }

  factory FeedbackItemModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FeedbackItemModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacherId': teacherId,
      'teacherName': teacherName,
      if (courseId != null) 'courseId': courseId,
      if (courseCode != null) 'courseCode': courseCode,
      if (courseTitle != null) 'courseTitle': courseTitle,
      'rating': rating,
      'comments': comments,
      'isAnonymous': isAnonymous,
      'attachments': attachments.map((a) => (a as AttachmentModel).toJson()).toList(),
      'replies': replies.map((r) => (r as FeedbackReplyModel).toJson()).toList(),
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'teacherId': teacherId,
      'teacherName': teacherName,
      if (courseId != null) 'courseId': courseId,
      if (courseCode != null) 'courseCode': courseCode,
      if (courseTitle != null) 'courseTitle': courseTitle,
      'rating': rating,
      'comments': comments,
      'isAnonymous': isAnonymous,
      'studentId': isAnonymous ? 'ANONYMOUS' : null,
      'attachments': attachments.map((a) => (a as AttachmentModel).toJson()).toList(),
      'replies': replies.map((r) => (r as FeedbackReplyModel).toJson()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
