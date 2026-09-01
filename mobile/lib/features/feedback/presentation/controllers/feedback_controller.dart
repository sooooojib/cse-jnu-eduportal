import 'package:flutter/foundation.dart';
import '../../domain/entities/feedback_entities.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../../../core/error/failures.dart';

abstract class FeedbackState {}
class FeedbackInitial extends FeedbackState {}
class FeedbackLoading extends FeedbackState {}
class FeedbackLoaded extends FeedbackState {
  final List<FeedbackItem> submissions;
  FeedbackLoaded(this.submissions);
}
class FeedbackError extends FeedbackState {
  final String message;
  FeedbackError(this.message);
}

class FeedbackController extends ChangeNotifier {
  final SubmitFeedbackUseCase submitFeedbackUseCase;
  final GetMyFeedbackUseCase getMyFeedbackUseCase;

  FeedbackState _state = FeedbackInitial();
  bool _isSubmitting = false;

  FeedbackController({
    required this.submitFeedbackUseCase,
    required this.getMyFeedbackUseCase,
  });

  FeedbackState get state => _state;
  bool get isSubmitting => _isSubmitting;

  Future<void> fetchSubmissions() async {
    _state = FeedbackLoading();
    notifyListeners();

    try {
      final submissions = await getMyFeedbackUseCase.execute();
      _state = FeedbackLoaded(submissions);
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = FeedbackError(message);
      notifyListeners();
    }
  }

  Future<bool> submitFeedback({
    required String teacherId,
    String? courseId,
    required int rating,
    required String comments,
    required bool isAnonymous,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await submitFeedbackUseCase.execute(
        teacherId: teacherId,
        courseId: courseId,
        rating: rating,
        comments: comments,
        isAnonymous: isAnonymous,
      );
      await fetchSubmissions();
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      rethrow;
    }
  }
}
