import 'package:flutter/foundation.dart';
import '../../domain/entities/semester_status.dart';
import '../../domain/repositories/semester_repository.dart';
import '../../../../core/error/failures.dart';

abstract class ProfileState {}
class ProfileInitial extends ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileLoaded extends ProfileState {
  final SemesterStatus semesterStatus;
  ProfileLoaded(this.semesterStatus);
}
class ProfileError extends ProfileState {
  final String message;
  ProfileError(this.message);
}

class ProfileController extends ChangeNotifier {
  final GetSemesterStatusUseCase getSemesterStatusUseCase;
  final RequestSemesterUpgradeUseCase requestSemesterUpgradeUseCase;

  ProfileState _state = ProfileInitial();
  bool _isActionLoading = false;

  ProfileController({
    required this.getSemesterStatusUseCase,
    required this.requestSemesterUpgradeUseCase,
  });

  ProfileState get state => _state;
  bool get isActionLoading => _isActionLoading;

  Future<void> fetchSemesterStatus() async {
    _state = ProfileLoading();
    notifyListeners();

    try {
      final status = await getSemesterStatusUseCase.execute();
      _state = ProfileLoaded(status);
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = ProfileError(message);
      notifyListeners();
    }
  }

  Future<bool> requestUpgrade({required int requestedYear, required int requestedSemester}) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      final updatedStatus = await requestSemesterUpgradeUseCase.execute(
        requestedYear: requestedYear,
        requestedSemester: requestedSemester,
      );
      _state = ProfileLoaded(updatedStatus);
      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
