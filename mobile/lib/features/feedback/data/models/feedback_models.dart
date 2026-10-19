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
    super.teacherId,
    required super.teacherName,
    required super.replyText,
    super.attachments = const [],
    required super.createdAt,
    super.updatedAt,
  });

  factory FeedbackReplyModel.fromJson(Map<String, dynamic> json) {
    final attachmentsList = (json['attachments'] as List? ?? [])
        .map((a) => AttachmentModel.fromJson(a as Map<String, dynamic>))
        .toList();

    return FeedbackReplyModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacherId'] as String?,
      teacherName: json['teacherName'] as String? ?? '',
      replyText: json['replyText'] as String? ?? '',
      attachments: attachmentsList,
      createdAt: _tsToString(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? _tsToString(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (teacherId != null) 'teacherId': teacherId,
      'teacherName': teacherName,
      'replyText': replyText,
      'attachments': attachments
          .map((a) => (a is AttachmentModel ? a : AttachmentModel(
                id: a.id,
                fileName: a.fileName,
                fileUrl: a.fileUrl,
                mimeType: a.mimeType,
                fileSize: a.fileSize,
              )).toJson())
          .toList(),
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
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
    super.studentId,
    super.studentName,
    super.studentEmail,
    super.attachments = const [],
    required super.replies,
    required super.createdAt,
    super.updatedAt,
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
      studentId: json['studentId'] as String?,
      studentName: json['studentName'] as String?,
      studentEmail: json['studentEmail'] as String?,
      attachments: attachmentsList,
      replies: List<FeedbackReply>.from(repliesList),
      createdAt: _tsToString(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? _tsToString(json['updatedAt']) : null,
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
      if (studentId != null) 'studentId': studentId,
      if (studentName != null) 'studentName': studentName,
      if (studentEmail != null) 'studentEmail': studentEmail,
      'attachments': attachments
          .map((a) => (a is AttachmentModel ? a : AttachmentModel(
                id: a.id,
                fileName: a.fileName,
                fileUrl: a.fileUrl,
                mimeType: a.mimeType,
                fileSize: a.fileSize,
              )).toJson())
          .toList(),
      'replies': replies
          .map((r) => (r is FeedbackReplyModel ? r : FeedbackReplyModel(
                id: r.id,
                teacherId: r.teacherId,
                teacherName: r.teacherName,
                replyText: r.replyText,
                attachments: r.attachments,
                createdAt: r.createdAt,
                updatedAt: r.updatedAt,
              )).toJson())
          .toList(),
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
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
      'studentId': isAnonymous ? 'ANONYMOUS' : studentId,
      'studentName': isAnonymous ? 'Anonymous Student' : studentName,
      'attachments': attachments
          .map((a) => {
                'id': a.id,
                'fileName': a.fileName,
                'fileUrl': a.fileUrl,
                'mimeType': a.mimeType,
                'fileSize': a.fileSize,
              })
          .toList(),
      'replies': replies
          .map((r) => {
                'id': r.id,
                if (r.teacherId != null) 'teacherId': r.teacherId,
                'teacherName': r.teacherName,
                'replyText': r.replyText,
                'attachments': r.attachments
                    .map((att) => {
                          'id': att.id,
                          'fileName': att.fileName,
                          'fileUrl': att.fileUrl,
                          'mimeType': att.mimeType,
                          'fileSize': att.fileSize,
                        })
                    .toList(),
                'createdAt': r.createdAt,
                if (r.updatedAt != null) 'updatedAt': r.updatedAt,
              })
          .toList(),
      'hasReplied': replies.isNotEmpty,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
