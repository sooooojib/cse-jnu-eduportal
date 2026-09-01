import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../models/counseling_models.dart';
import '../../domain/entities/counseling_entities.dart';
import '../../domain/repositories/counseling_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class CounselingRemoteDataSource {
  Future<List<CounselingSlotModel>> getAvailableSlots({String? teacherId});
  Future<CounselingBookingModel> requestBooking(String slotId, {required String category, required String notes});
  Future<List<CounselingBookingModel>> getMyBookings();
  Future<void> cancelBooking(String requestId);
}

class CounselingRemoteDataSourceImpl implements CounselingRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  CounselingRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  @override
  Future<List<CounselingSlotModel>> getAvailableSlots({String? teacherId}) async {
    Query query = _firestore
        .collection("counselingSlots")
        .where("isBooked", isEqualTo: false);

    if (teacherId != null) {
      query = query.where("teacherId", isEqualTo: teacherId);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return CounselingSlotModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
    }).toList();
  }

  @override
  Future<CounselingBookingModel> requestBooking(
    String slotId, {
    required String category,
    required String notes,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    // Fetch slot to get teacher info
    final slotDoc = await _firestore.collection("counselingSlots").doc(slotId).get();
    if (!slotDoc.exists) throw const ServerException(message: "Slot not found.");
    final slotData = slotDoc.data()!;

    // Mark slot as booked
    await slotDoc.reference.update({"isBooked": true});

    // Create booking record
    final now = DateTime.now().toIso8601String();
    final docRef = await _firestore.collection("counselingBookings").add({
      "slotId": slotId,
      "studentId": uid,
      "teacherId": slotData["teacherId"] ?? "",
      "teacherName": slotData["teacherName"] ?? "",
      "slotDate": slotData["date"] ?? "",
      "startTime": slotData["startTime"] ?? "",
      "endTime": slotData["endTime"] ?? "",
      "category": category,
      "notes": notes,
      "status": "PENDING",
      "createdAt": now,
    });

    final newDoc = await docRef.get();
    return CounselingBookingModel.fromJson({"id": newDoc.id, ...newDoc.data()!});
  }

  @override
  Future<List<CounselingBookingModel>> getMyBookings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    final snapshot = await _firestore
        .collection("counselingBookings")
        .where("studentId", isEqualTo: uid)
        .orderBy("createdAt", descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return CounselingBookingModel.fromJson({"id": doc.id, ...doc.data()});
    }).toList();
  }

  @override
  Future<void> cancelBooking(String requestId) async {
    final bookingRef = _firestore.collection("counselingBookings").doc(requestId);
    final booking = await bookingRef.get();
    if (!booking.exists) throw const ServerException(message: "Booking not found.");

    // Free up the slot and mark booking cancelled
    final slotId = booking.data()!["slotId"] as String?;
    if (slotId != null) {
      await _firestore.collection("counselingSlots").doc(slotId).update({"isBooked": false});
    }
    await bookingRef.update({"status": "CANCELLED"});
  }
}

// ─── Repository ──────────────────────────────────────────────────────────────

class CounselingRepositoryImpl implements CounselingRepository {
  final CounselingRemoteDataSource remoteDataSource;

  CounselingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<CounselingSlot>> getAvailableSlots({String? teacherId}) async {
    try {
      final list = await remoteDataSource.getAvailableSlots(teacherId: teacherId);
      return List<CounselingSlot>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<CounselingBooking> requestBooking(String slotId, {required String category, required String notes}) async {
    try {
      return await remoteDataSource.requestBooking(slotId, category: category, notes: notes);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<CounselingBooking>> getMyBookings() async {
    try {
      final list = await remoteDataSource.getMyBookings();
      return List<CounselingBooking>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> cancelBooking(String requestId) async {
    try {
      await remoteDataSource.cancelBooking(requestId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
