import '../entities/counseling_entities.dart';

abstract class CounselingRepository {
  Future<List<CounselingSlot>> getAvailableSlots({String? teacherId});
  Future<CounselingBooking> requestBooking(String slotId, {required String category, required String notes});
  Future<List<CounselingBooking>> getMyBookings();
  Future<void> cancelBooking(String requestId);
}

class GetAvailableSlotsUseCase {
  final CounselingRepository repository;
  GetAvailableSlotsUseCase(this.repository);

  Future<List<CounselingSlot>> execute({String? teacherId}) => repository.getAvailableSlots(teacherId: teacherId);
}

class RequestBookingUseCase {
  final CounselingRepository repository;
  RequestBookingUseCase(this.repository);

  Future<CounselingBooking> execute(String slotId, {required String category, required String notes}) =>
      repository.requestBooking(slotId, category: category, notes: notes);
}

class GetMyBookingsUseCase {
  final CounselingRepository repository;
  GetMyBookingsUseCase(this.repository);

  Future<List<CounselingBooking>> execute() => repository.getMyBookings();
}

class CancelBookingUseCase {
  final CounselingRepository repository;
  CancelBookingUseCase(this.repository);

  Future<void> execute(String requestId) => repository.cancelBooking(requestId);
}
