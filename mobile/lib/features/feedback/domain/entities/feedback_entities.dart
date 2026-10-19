import 'package:equatable/equatable.dart';

class Attachment extends Equatable {
  final String id;
  final String fileName;
  final String fileUrl;
  final String mimeType;
  final int fileSize;

  const Attachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    this.mimeType = 'application/octet-stream',
    this.fileSize = 0,
  });

  @override
  List<Object?> get props => [id, fileName, fileUrl, mimeType, fileSize];
}

class FeedbackReply extends Equatable {
  final String id;
  final String? teacherId;
  final String teacherName;
  final String replyText;
  final List<Attachment> attachments;
  final String createdAt;
  final String? updatedAt;

  const FeedbackReply({
    required this.id,
    this.teacherId,
    required this.teacherName,
    required this.replyText,
    this.attachments = const [],
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [id, teacherId, teacherName, replyText, attachments, createdAt, updatedAt];
}

class FeedbackItem extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final String? courseId;
  final String? courseCode;
  final String? courseTitle;
  final int rating;
  final String comments;
  final bool isAnonymous;
  final String? studentId;
  final String? studentName;
  final String? studentEmail;
  final List<Attachment> attachments;
  final List<FeedbackReply> replies;
  final String createdAt;
  final String? updatedAt;

  const FeedbackItem({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    this.courseId,
    this.courseCode,
    this.courseTitle,
    required this.rating,
    required this.comments,
    required this.isAnonymous,
    this.studentId,
    this.studentName,
    this.studentEmail,
    this.attachments = const [],
    required this.replies,
    required this.createdAt,
    this.updatedAt,
  });

  bool get hasReplied => replies.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        teacherId,
        teacherName,
        courseId,
        courseCode,
        courseTitle,
        rating,
        comments,
        isAnonymous,
        studentId,
        studentName,
        studentEmail,
        attachments,
        replies,
        createdAt,
        updatedAt,
      ];
}
