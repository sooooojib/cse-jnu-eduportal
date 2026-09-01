import 'package:flutter/foundation.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../../../core/error/failures.dart';

abstract class AttendanceState {}
class AttendanceInitial extends AttendanceState {}
class AttendanceLoading extends AttendanceState {}
class AttendanceLoaded extends AttendanceState {
  final AttendanceSummary summary;
  AttendanceLoaded(this.summary);
}
class AttendanceError extends AttendanceState {
  final String message;
  AttendanceError(this.message);
}

class AttendanceController extends ChangeNotifier {
  final GetAttendanceSummaryUseCase getAttendanceSummaryUseCase;
  final VerifyAttendanceCodeUseCase verifyAttendanceCodeUseCase;

  AttendanceState _state = AttendanceInitial();
  bool _isSubmittingCode = false;

  AttendanceController({
    required this.getAttendanceSummaryUseCase,
    required this.verifyAttendanceCodeUseCase,
  });

  AttendanceState get state => _state;
  bool get isSubmittingCode => _isSubmittingCode;

  Future<void> fetchSummary() async {
    _state = AttendanceLoading();
    notifyListeners();

    try {
      final summary = await getAttendanceSummaryUseCase.execute();
      _state = AttendanceLoaded(summary);
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = AttendanceError(message);
      notifyListeners();
    }
  }

  Future<bool> submitVerificationCode(String code, {String? courseId}) async {
    _isSubmittingCode = true;
    notifyListeners();

    try {
      await verifyAttendanceCodeUseCase.execute(code, courseId: courseId);
      // Refresh summary automatically after marking present
      await fetchSummary();
      _isSubmittingCode = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSubmittingCode = false;
      notifyListeners();
      rethrow;
    }
  }
}
