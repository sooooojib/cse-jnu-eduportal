import '../entities/feedback_entities.dart';

abstract class FeedbackRepository {
  Future<FeedbackItem> submitFeedback({
    required String teacherId,
    String? courseId,
    required int rating,
    required String comments,
    required bool isAnonymous,
  });
  Future<List<FeedbackItem>> getMySubmissions();
}

class SubmitFeedbackUseCase {
  final FeedbackRepository repository;
  SubmitFeedbackUseCase(this.repository);

  Future<FeedbackItem> execute({
    required String teacherId,
    String? courseId,
    required int rating,
    required String comments,
    required bool isAnonymous,
  }) =>
      repository.submitFeedback(
        teacherId: teacherId,
        courseId: courseId,
        rating: rating,
        comments: comments,
        isAnonymous: isAnonymous,
      );
}

class GetMyFeedbackUseCase {
  final FeedbackRepository repository;
  GetMyFeedbackUseCase(this.repository);

  Future<List<FeedbackItem>> execute() => repository.getMySubmissions();
}
