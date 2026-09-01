import 'package:flutter/foundation.dart';
import '../../domain/entities/counseling_entities.dart';
import '../../domain/repositories/counseling_repository.dart';
import '../../../../core/error/failures.dart';

abstract class CounselingState {}
class CounselingInitial extends CounselingState {}
class CounselingLoading extends CounselingState {}
class CounselingLoaded extends CounselingState {
  final List<CounselingSlot> availableSlots;
  final List<CounselingBooking> myBookings;
  CounselingLoaded({required this.availableSlots, required this.myBookings});
}
class CounselingError extends CounselingState {
  final String message;
  CounselingError(this.message);
}

class CounselingController extends ChangeNotifier {
  final GetAvailableSlotsUseCase getAvailableSlotsUseCase;
  final RequestBookingUseCase requestBookingUseCase;
  final GetMyBookingsUseCase getMyBookingsUseCase;
  final CancelBookingUseCase cancelBookingUseCase;

  CounselingState _state = CounselingInitial();
  bool _isActionLoading = false;

  CounselingController({
    required this.getAvailableSlotsUseCase,
    required this.requestBookingUseCase,
    required this.getMyBookingsUseCase,
    required this.cancelBookingUseCase,
  });

  CounselingState get state => _state;
  bool get isActionLoading => _isActionLoading;

  Future<void> fetchAll() async {
    _state = CounselingLoading();
    notifyListeners();

    try {
      final slots = await getAvailableSlotsUseCase.execute();
      final bookings = await getMyBookingsUseCase.execute();
      _state = CounselingLoaded(availableSlots: slots, myBookings: bookings);
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = CounselingError(message);
      notifyListeners();
    }
  }

  Future<bool> bookSlot(String slotId, {required String category, required String notes}) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      await requestBookingUseCase.execute(slotId, category: category, notes: notes);
      await fetchAll();
      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> cancelBooking(String requestId) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      await cancelBookingUseCase.execute(requestId);
      await fetchAll();
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
