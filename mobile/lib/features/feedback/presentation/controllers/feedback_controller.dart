import 'package:flutter/foundation.dart';
import '../../domain/entities/feedback_entities.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../../../../core/error/failures.dart';

abstract class FeedbackState {}

class FeedbackInitial extends FeedbackState {}

class FeedbackLoading extends FeedbackState {}

class FeedbackLoaded extends FeedbackState {
  final List<FeedbackItem> submissions;
  final List<FeedbackItem> teacherFeedback;
  final String teacherFilter; // 'ALL', 'REPLIED', 'NOT_REPLIED'

  FeedbackLoaded({
    this.submissions = const [],
    this.teacherFeedback = const [],
    this.teacherFilter = 'ALL',
  });

  FeedbackLoaded copyWith({
    List<FeedbackItem>? submissions,
    List<FeedbackItem>? teacherFeedback,
    String? teacherFilter,
  }) {
    return FeedbackLoaded(
      submissions: submissions ?? this.submissions,
      teacherFeedback: teacherFeedback ?? this.teacherFeedback,
      teacherFilter: teacherFilter ?? this.teacherFilter,
    );
  }
}

class FeedbackError extends FeedbackState {
  final String message;
  FeedbackError(this.message);
}

class FeedbackController extends ChangeNotifier {
  final SubmitFeedbackUseCase submitFeedbackUseCase;
  final EditFeedbackUseCase editFeedbackUseCase;
  final GetMyFeedbackUseCase getMyFeedbackUseCase;
  final GetTeacherFeedbackUseCase getTeacherFeedbackUseCase;
  final ReplyToFeedbackUseCase replyToFeedbackUseCase;
  final EditFeedbackReplyUseCase editFeedbackReplyUseCase;
  final GetAdminFeedbackUseCase getAdminFeedbackUseCase;

  FeedbackState _state = FeedbackInitial();
  bool _isSubmitting = false;

  FeedbackController({
    required this.submitFeedbackUseCase,
    required this.getMyFeedbackUseCase,
    EditFeedbackUseCase? editFeedbackUseCase,
    GetTeacherFeedbackUseCase? getTeacherFeedbackUseCase,
    ReplyToFeedbackUseCase? replyToFeedbackUseCase,
    EditFeedbackReplyUseCase? editFeedbackReplyUseCase,
    GetAdminFeedbackUseCase? getAdminFeedbackUseCase,
  })  : editFeedbackUseCase = editFeedbackUseCase ?? EditFeedbackUseCase(submitFeedbackUseCase.repository),
        getTeacherFeedbackUseCase = getTeacherFeedbackUseCase ?? GetTeacherFeedbackUseCase(getMyFeedbackUseCase.repository),
        replyToFeedbackUseCase = replyToFeedbackUseCase ?? ReplyToFeedbackUseCase(getMyFeedbackUseCase.repository),
        editFeedbackReplyUseCase = editFeedbackReplyUseCase ?? EditFeedbackReplyUseCase(getMyFeedbackUseCase.repository),
        getAdminFeedbackUseCase = getAdminFeedbackUseCase ?? GetAdminFeedbackUseCase(getMyFeedbackUseCase.repository);

  FeedbackState get state => _state;
  bool get isSubmitting => _isSubmitting;

  // ─── Student Operations ───────────────────────────────────────────────────

  Future<void> fetchSubmissions() async {
    final currentTeacherList = _state is FeedbackLoaded ? (_state as FeedbackLoaded).teacherFeedback : <FeedbackItem>[];
    final currentFilter = _state is FeedbackLoaded ? (_state as FeedbackLoaded).teacherFilter : 'ALL';

    _state = FeedbackLoading();
    notifyListeners();

    try {
      final submissions = await getMyFeedbackUseCase.execute();
      _state = FeedbackLoaded(
        submissions: submissions,
        teacherFeedback: currentTeacherList,
        teacherFilter: currentFilter,
      );
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
    String? courseCode,
    String? courseTitle,
    required int rating,
    required String comments,
    required bool isAnonymous,
    List<Attachment> attachments = const [],
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await submitFeedbackUseCase.execute(
        teacherId: teacherId,
        courseId: courseId,
        courseCode: courseCode,
        courseTitle: courseTitle,
        rating: rating,
        comments: comments,
        isAnonymous: isAnonymous,
        attachments: attachments,
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

  Future<bool> editFeedback({
    required String feedbackId,
    int? rating,
    String? comments,
    bool? isAnonymous,
    List<Attachment>? attachments,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await editFeedbackUseCase.execute(
        feedbackId: feedbackId,
        rating: rating,
        comments: comments,
        isAnonymous: isAnonymous,
        attachments: attachments,
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

  // ─── Teacher Operations ───────────────────────────────────────────────────

  Future<void> fetchTeacherFeedback(String teacherId, {String filter = 'ALL'}) async {
    final currentSubs = _state is FeedbackLoaded ? (_state as FeedbackLoaded).submissions : <FeedbackItem>[];

    _state = FeedbackLoading();
    notifyListeners();

    try {
      final items = await getTeacherFeedbackUseCase.execute(
        teacherId: teacherId,
        filter: filter,
      );
      _state = FeedbackLoaded(
        submissions: currentSubs,
        teacherFeedback: items,
        teacherFilter: filter,
      );
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = FeedbackError(message);
      notifyListeners();
    }
  }

  Future<void> setTeacherFilter(String teacherId, String filter) async {
    await fetchTeacherFeedback(teacherId, filter: filter);
  }

  Future<bool> replyToFeedback({
    required String feedbackId,
    required String replyText,
    List<Attachment> attachments = const [],
    String? teacherId,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await replyToFeedbackUseCase.execute(
        feedbackId: feedbackId,
        replyText: replyText,
        attachments: attachments,
      );
      if (teacherId != null) {
        final currentFilter = _state is FeedbackLoaded ? (_state as FeedbackLoaded).teacherFilter : 'ALL';
        await fetchTeacherFeedback(teacherId, filter: currentFilter);
      }
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> editFeedbackReply({
    required String feedbackId,
    required String replyId,
    required String replyText,
    List<Attachment>? attachments,
    String? teacherId,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await editFeedbackReplyUseCase.execute(
        feedbackId: feedbackId,
        replyId: replyId,
        replyText: replyText,
        attachments: attachments,
      );
      if (teacherId != null) {
        final currentFilter = _state is FeedbackLoaded ? (_state as FeedbackLoaded).teacherFilter : 'ALL';
        await fetchTeacherFeedback(teacherId, filter: currentFilter);
      }
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmitting = false;
      notifyListeners();
      rethrow;
    }
  }

  // ─── Admin Operations ─────────────────────────────────────────────────────

  Future<void> fetchAdminFeedback() async {
    _state = FeedbackLoading();
    notifyListeners();

    try {
      final items = await getAdminFeedbackUseCase.execute();
      _state = FeedbackLoaded(
        submissions: const [],
        teacherFeedback: items,
        teacherFilter: 'ALL',
      );
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = FeedbackError(message);
      notifyListeners();
    }
  }
}
