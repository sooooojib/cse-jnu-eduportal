import '../entities/counseling_entities.dart';

abstract class CounselingRepository {
  // Student & CR operations
  Future<List<CounselingSlot>> getAvailableSlots({String? teacherId});
  Future<CounselingBooking> requestBooking(String slotId, {required String category, required String notes});
  Future<List<CounselingBooking>> getMyBookings();
  Future<void> cancelBooking(String requestId);

  // Teacher operations
  Future<CounselingSlot> createSlot({
    required String slotDate,
    required String startTime,
    required String endTime,
    String? notes,
  });
  Future<List<CounselingSlot>> getTeacherSlots(String teacherId);
  Future<List<CounselingBooking>> getTeacherRequests(String teacherId);
  Future<void> approveBooking(String bookingId);
  Future<void> rejectBooking(String bookingId, {String? reason});
  Future<void> deleteSlot(String slotId);
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

class CreateCounselingSlotUseCase {
  final CounselingRepository repository;
  CreateCounselingSlotUseCase(this.repository);

  Future<CounselingSlot> execute({
    required String slotDate,
    required String startTime,
    required String endTime,
    String? notes,
  }) =>
      repository.createSlot(
        slotDate: slotDate,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );
}

class GetTeacherSlotsUseCase {
  final CounselingRepository repository;
  GetTeacherSlotsUseCase(this.repository);

  Future<List<CounselingSlot>> execute(String teacherId) => repository.getTeacherSlots(teacherId);
}

class GetTeacherRequestsUseCase {
  final CounselingRepository repository;
  GetTeacherRequestsUseCase(this.repository);

  Future<List<CounselingBooking>> execute(String teacherId) => repository.getTeacherRequests(teacherId);
}

class ApproveBookingUseCase {
  final CounselingRepository repository;
  ApproveBookingUseCase(this.repository);

  Future<void> execute(String bookingId) => repository.approveBooking(bookingId);
}

class RejectBookingUseCase {
  final CounselingRepository repository;
  RejectBookingUseCase(this.repository);

  Future<void> execute(String bookingId, {String? reason}) =>
      repository.rejectBooking(bookingId, reason: reason);
}

class DeleteCounselingSlotUseCase {
  final CounselingRepository repository;
  DeleteCounselingSlotUseCase(this.repository);

  Future<void> execute(String slotId) => repository.deleteSlot(slotId);
}
