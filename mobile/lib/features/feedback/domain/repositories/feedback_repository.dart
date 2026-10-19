import '../entities/feedback_entities.dart';

abstract class FeedbackRepository {
  Future<FeedbackItem> submitFeedback({
    required String teacherId,
    String? courseId,
    String? courseCode,
    String? courseTitle,
    required int rating,
    required String comments,
    required bool isAnonymous,
    List<Attachment> attachments = const [],
  });

  Future<FeedbackItem> editFeedback({
    required String feedbackId,
    int? rating,
    String? comments,
    bool? isAnonymous,
    List<Attachment>? attachments,
  });

  Future<List<FeedbackItem>> getMySubmissions();

  Future<List<FeedbackItem>> getTeacherFeedback({
    required String teacherId,
    String filter = 'ALL',
  });

  Future<FeedbackItem> replyToFeedback({
    required String feedbackId,
    required String replyText,
    List<Attachment> attachments = const [],
  });

  Future<FeedbackItem> editFeedbackReply({
    required String feedbackId,
    required String replyId,
    required String replyText,
    List<Attachment>? attachments,
  });

  Future<List<FeedbackItem>> getAdminFeedback();
}

class SubmitFeedbackUseCase {
  final FeedbackRepository repository;
  SubmitFeedbackUseCase(this.repository);

  Future<FeedbackItem> execute({
    required String teacherId,
    String? courseId,
    String? courseCode,
    String? courseTitle,
    required int rating,
    required String comments,
    required bool isAnonymous,
    List<Attachment> attachments = const [],
  }) =>
      repository.submitFeedback(
        teacherId: teacherId,
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
        rating: rating,
        comments: comments,
        isAnonymous: isAnonymous,
        attachments: attachments,
      );
}

class EditFeedbackUseCase {
  final FeedbackRepository repository;
  EditFeedbackUseCase(this.repository);

  Future<FeedbackItem> execute({
    required String feedbackId,
    int? rating,
    String? comments,
    bool? isAnonymous,
    List<Attachment>? attachments,
  }) =>
      repository.editFeedback(
        feedbackId: feedbackId,
        rating: rating,
        comments: comments,
        isAnonymous: isAnonymous,
        attachments: attachments,
      );
}

class GetMyFeedbackUseCase {
  final FeedbackRepository repository;
  GetMyFeedbackUseCase(this.repository);

  Future<List<FeedbackItem>> execute() => repository.getMySubmissions();
}

class GetTeacherFeedbackUseCase {
  final FeedbackRepository repository;
  GetTeacherFeedbackUseCase(this.repository);

  Future<List<FeedbackItem>> execute({
    required String teacherId,
    String filter = 'ALL',
  }) =>
      repository.getTeacherFeedback(teacherId: teacherId, filter: filter);
}

class ReplyToFeedbackUseCase {
  final FeedbackRepository repository;
  ReplyToFeedbackUseCase(this.repository);

  Future<FeedbackItem> execute({
    required String feedbackId,
    required String replyText,
    List<Attachment> attachments = const [],
  }) =>
      repository.replyToFeedback(
        feedbackId: feedbackId,
        replyText: replyText,
        attachments: attachments,
      );
}

class EditFeedbackReplyUseCase {
  final FeedbackRepository repository;
  EditFeedbackReplyUseCase(this.repository);

  Future<FeedbackItem> execute({
    required String feedbackId,
    required String replyId,
    required String replyText,
    List<Attachment>? attachments,
  }) =>
      repository.editFeedbackReply(
        feedbackId: feedbackId,
        replyId: replyId,
        replyText: replyText,
        attachments: attachments,
      );
}

class GetAdminFeedbackUseCase {
  final FeedbackRepository repository;
  GetAdminFeedbackUseCase(this.repository);

  Future<List<FeedbackItem>> execute() => repository.getAdminFeedback();
}
