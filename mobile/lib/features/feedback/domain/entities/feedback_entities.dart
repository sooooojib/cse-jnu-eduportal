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
    required this.mimeType,
    required this.fileSize,
  });

  @override
  List<Object?> get props => [id, fileName, fileUrl, mimeType, fileSize];
}

class FeedbackReply extends Equatable {
  final String id;
  final String teacherName;
  final String replyText;
  final String createdAt;

  const FeedbackReply({
    required this.id,
    required this.teacherName,
    required this.replyText,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, teacherName, replyText, createdAt];
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
  final List<Attachment> attachments;
  final List<FeedbackReply> replies;
  final String createdAt;

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
    this.attachments = const [],
    required this.replies,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, teacherId, teacherName, courseId, courseCode, courseTitle, rating, comments, isAnonymous, attachments, replies, createdAt];
}
