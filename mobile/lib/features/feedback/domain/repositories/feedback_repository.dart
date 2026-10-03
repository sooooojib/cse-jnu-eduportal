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
  Future<List<FeedbackItem>> getMySubmissions();
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

class GetMyFeedbackUseCase {
  final FeedbackRepository repository;
  GetMyFeedbackUseCase(this.repository);

  Future<List<FeedbackItem>> execute() => repository.getMySubmissions();
}
