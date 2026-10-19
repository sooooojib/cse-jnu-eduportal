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
  final List<CounselingSlot> teacherSlots;
  final List<CounselingBooking> teacherRequests;

  CounselingLoaded({
    required this.availableSlots,
    required this.myBookings,
    this.teacherSlots = const [],
    this.teacherRequests = const [],
  });

  CounselingLoaded copyWith({
    List<CounselingSlot>? availableSlots,
    List<CounselingBooking>? myBookings,
    List<CounselingSlot>? teacherSlots,
    List<CounselingBooking>? teacherRequests,
  }) {
    return CounselingLoaded(
      availableSlots: availableSlots ?? this.availableSlots,
      myBookings: myBookings ?? this.myBookings,
      teacherSlots: teacherSlots ?? this.teacherSlots,
      teacherRequests: teacherRequests ?? this.teacherRequests,
    );
  }
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

  final CreateCounselingSlotUseCase? createCounselingSlotUseCase;
  final GetTeacherSlotsUseCase? getTeacherSlotsUseCase;
  final GetTeacherRequestsUseCase? getTeacherRequestsUseCase;
  final ApproveBookingUseCase? approveBookingUseCase;
  final RejectBookingUseCase? rejectBookingUseCase;
  final DeleteCounselingSlotUseCase? deleteCounselingSlotUseCase;

  CounselingState _state = CounselingInitial();
  bool _isActionLoading = false;

  CounselingController({
    required this.getAvailableSlotsUseCase,
    required this.requestBookingUseCase,
    required this.getMyBookingsUseCase,
    required this.cancelBookingUseCase,
    this.createCounselingSlotUseCase,
    this.getTeacherSlotsUseCase,
    this.getTeacherRequestsUseCase,
    this.approveBookingUseCase,
    this.rejectBookingUseCase,
    this.deleteCounselingSlotUseCase,
  });

  CounselingState get state => _state;
  bool get isActionLoading => _isActionLoading;

  // ─── STUDENT / CR OPERATIONS ───────────────────────────────────────────────

  Future<void> fetchAll({String? teacherId}) async {
    _state = CounselingLoading();
    notifyListeners();

    try {
      final slots = await getAvailableSlotsUseCase.execute(teacherId: teacherId);
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

  // ─── TEACHER OPERATIONS ────────────────────────────────────────────────────

  Future<void> fetchTeacherData(String teacherId) async {
    _state = CounselingLoading();
    notifyListeners();

    try {
      List<CounselingSlot> slots = [];
      List<CounselingBooking> requests = [];

      if (getTeacherSlotsUseCase != null) {
        slots = await getTeacherSlotsUseCase!.execute(teacherId);
      }
      if (getTeacherRequestsUseCase != null) {
        requests = await getTeacherRequestsUseCase!.execute(teacherId);
      }

      _state = CounselingLoaded(
        availableSlots: const [],
        myBookings: const [],
        teacherSlots: slots,
        teacherRequests: requests,
      );
      notifyListeners();
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      _state = CounselingError(message);
      notifyListeners();
    }
  }

  Future<bool> createSlot({
    required String slotDate,
    required String startTime,
    required String endTime,
    String? notes,
    required String teacherId,
  }) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      if (createCounselingSlotUseCase == null) {
        throw Exception("Create counseling slot use case not configured.");
      }
      await createCounselingSlotUseCase!.execute(
        slotDate: slotDate,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );
      await fetchTeacherData(teacherId);
      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> approveRequest(String bookingId, {required String teacherId}) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      if (approveBookingUseCase == null) {
        throw Exception("Approve booking use case not configured.");
      }
      await approveBookingUseCase!.execute(bookingId);
      await fetchTeacherData(teacherId);
      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> rejectRequest(String bookingId, {String? reason, required String teacherId}) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      if (rejectBookingUseCase == null) {
        throw Exception("Reject booking use case not configured.");
      }
      await rejectBookingUseCase!.execute(bookingId, reason: reason);
      await fetchTeacherData(teacherId);
      _isActionLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isActionLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> deleteSlot(String slotId, {required String teacherId}) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      if (deleteCounselingSlotUseCase == null) {
        throw Exception("Delete slot use case not configured.");
      }
      await deleteCounselingSlotUseCase!.execute(slotId);
      await fetchTeacherData(teacherId);
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
