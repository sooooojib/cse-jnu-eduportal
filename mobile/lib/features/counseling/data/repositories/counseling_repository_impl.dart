import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/config/env_config.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/counseling_models.dart';
import '../../domain/entities/counseling_entities.dart';
import '../../domain/repositories/counseling_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class CounselingRemoteDataSource {
  Future<List<CounselingSlotModel>> getAvailableSlots({String? teacherId});
  Future<CounselingBookingModel> requestBooking(String slotId, {required String category, required String notes});
  Future<List<CounselingBookingModel>> getMyBookings();
  Future<void> cancelBooking(String requestId);

  // Teacher methods
  Future<CounselingSlotModel> createSlot({
    required String slotDate,
    required String startTime,
    required String endTime,
    String? notes,
  });
  Future<List<CounselingSlotModel>> getTeacherSlots(String teacherId);
  Future<List<CounselingBookingModel>> getTeacherRequests(String teacherId);
  Future<void> approveBooking(String bookingId);
  Future<void> rejectBooking(String bookingId, {String? reason});
  Future<void> deleteSlot(String slotId);
}

class CounselingRemoteDataSourceImpl implements CounselingRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CounselingRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<List<CounselingSlotModel>> getAvailableSlots({String? teacherId}) async {
    Query query = _firestore
        .collection("counselingSlots")
        .where("isBooked", isEqualTo: false);

    if (teacherId != null && teacherId.isNotEmpty) {
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

    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('requestCounselingBooking');
        final res = await callable.call({
          'slotId': slotId,
          'category': category,
          'notes': notes,
        });
        final data = res.data;
        if (data is Map && data['booking'] != null) {
          return CounselingBookingModel.fromJson(Map<String, dynamic>.from(data['booking'] as Map));
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'already-exists' || e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? 'Failed to request counseling slot.');
        }
        AppLogger.w('requestCounselingBooking callable note: $e. Falling back to direct Firestore operation.');
      } catch (e) {
        AppLogger.w('requestCounselingBooking error: $e. Falling back to direct Firestore operation.');
      }
    }

    // Fetch slot to verify availability
    final slotDoc = await _firestore.collection("counselingSlots").doc(slotId).get();
    if (!slotDoc.exists) throw const ServerException(message: "Counseling slot not found.");
    final slotData = slotDoc.data()!;

    if (slotData['isBooked'] == true || slotData['status'] == 'BOOKED') {
      throw const ServerException(message: "This counseling slot is already booked.");
    }

    // Check duplicate pending request
    final dupSnap = await _firestore
        .collection("counselingBookings")
        .where("slotId", isEqualTo: slotId)
        .where("studentId", isEqualTo: uid)
        .get();

    for (final doc in dupSnap.docs) {
      final st = doc.data()['status'];
      if (st == 'PENDING' || st == 'APPROVED') {
        throw const ServerException(message: "You have already submitted a request for this slot.");
      }
    }

    final userDoc = await _firestore.collection("users").doc(uid).get();
    final studentName = userDoc.data()?["fullName"] as String? ?? "Student";
    final studentEmail = userDoc.data()?["email"] as String? ?? "";

    final docRef = await _firestore.collection("counselingBookings").add({
      "slotId": slotId,
      "studentId": uid,
      "studentName": studentName,
      "studentEmail": studentEmail,
      "teacherId": slotData["teacherId"] ?? "",
      "teacherName": slotData["teacherName"] ?? "",
      "slotDate": slotData["slotDate"] ?? slotData["date"] ?? "",
      "startTime": slotData["startTime"] ?? "",
      "endTime": slotData["endTime"] ?? "",
      "category": category,
      "notes": notes,
      "status": "PENDING",
      "createdAt": FieldValue.serverTimestamp(),
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
        .get();

    final list = snapshot.docs.map((doc) {
      return CounselingBookingModel.fromJson({"id": doc.id, ...doc.data()});
    }).toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> cancelBooking(String requestId) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('cancelCounselingBooking');
        await callable.call({'bookingId': requestId});
        return;
      } catch (e) {
        AppLogger.w('cancelCounselingBooking callable note: $e. Falling back to direct Firestore cancellation.');
      }
    }
      // Fallback: direct Firestore cancellation
      final bookingRef = _firestore.collection("counselingBookings").doc(requestId);
      final booking = await bookingRef.get();
      if (!booking.exists) throw const ServerException(message: "Booking not found.");

      final slotId = booking.data()!["slotId"] as String?;
      if (slotId != null && booking.data()!["status"] == "APPROVED") {
        await _firestore.collection("counselingSlots").doc(slotId).update({
          "isBooked": false,
          "status": "AVAILABLE",
          "bookedStudentId": null,
          "bookedBookingId": null,
        });
      }
      await bookingRef.update({"status": "CANCELLED"});
  }

  @override
  Future<CounselingSlotModel> createSlot({
    required String slotDate,
    required String startTime,
    required String endTime,
    String? notes,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");

    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('createCounselingSlot');
        final res = await callable.call({
          'slotDate': slotDate,
          'startTime': startTime,
          'endTime': endTime,
          if (notes != null) 'notes': notes,
        });
        final data = res.data;
        if (data is Map && data['slot'] != null) {
          return CounselingSlotModel.fromJson(Map<String, dynamic>.from(data['slot'] as Map));
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'already-exists' || e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? 'Failed to create counseling slot.');
        }
        AppLogger.w('createCounselingSlot callable note: $e. Falling back to direct Firestore creation.');
      } catch (e) {
        AppLogger.w('createCounselingSlot error: $e. Falling back to direct Firestore creation.');
      }
    }

    final userDoc = await _firestore.collection("users").doc(uid).get();
    final teacherName = userDoc.data()?["fullName"] as String? ?? "Faculty Member";
    final teacherEmail = userDoc.data()?["email"] as String? ?? "";

    final docRef = await _firestore.collection("counselingSlots").add({
      "teacherId": uid,
      "teacherName": teacherName,
      "teacherEmail": teacherEmail,
      "slotDate": slotDate,
      "startTime": startTime,
      "endTime": endTime,
      "isBooked": false,
      "status": "AVAILABLE",
      "notes": notes,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    final newDoc = await docRef.get();
    return CounselingSlotModel.fromJson({"id": newDoc.id, ...newDoc.data()!});
  }

  @override
  Future<List<CounselingSlotModel>> getTeacherSlots(String teacherId) async {
    final snapshot = await _firestore
        .collection("counselingSlots")
        .where("teacherId", isEqualTo: teacherId)
        .get();

    final list = snapshot.docs.map((doc) {
      return CounselingSlotModel.fromJson({"id": doc.id, ...doc.data()});
    }).toList();

    list.sort((a, b) {
      final dateCmp = b.slotDate.compareTo(a.slotDate);
      if (dateCmp != 0) return dateCmp;
      return a.startTime.compareTo(b.startTime);
    });
    return list;
  }

  @override
  Future<List<CounselingBookingModel>> getTeacherRequests(String teacherId) async {
    final snapshot = await _firestore
        .collection("counselingBookings")
        .where("teacherId", isEqualTo: teacherId)
        .get();

    final list = snapshot.docs.map((doc) {
      return CounselingBookingModel.fromJson({"id": doc.id, ...doc.data()});
    }).toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> approveBooking(String bookingId) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('approveCounselingBooking');
        await callable.call({'bookingId': bookingId});
        return;
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'already-exists' || e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? 'Failed to approve booking.');
        }
        AppLogger.w('approveCounselingBooking callable note: $e. Falling back to direct Firestore transaction.');
      } catch (e) {
        AppLogger.w('approveCounselingBooking error: $e. Falling back to direct Firestore transaction.');
      }
    }
      // Fallback: Atomic Firestore transaction
      final bookingRef = _firestore.collection('counselingBookings').doc(bookingId);
      await _firestore.runTransaction((transaction) async {
        final bookingDoc = await transaction.get(bookingRef);
        if (!bookingDoc.exists) {
          throw const ServerException(message: 'Booking request not found.');
        }
        final bData = bookingDoc.data()!;
        if (bData['status'] != 'PENDING') {
          throw ServerException(message: 'Booking request is already ${bData['status']}.');
        }

        final slotId = bData['slotId'] as String?;
        if (slotId == null) throw const ServerException(message: 'Slot ID missing.');

        final slotRef = _firestore.collection('counselingSlots').doc(slotId);
        final slotDoc = await transaction.get(slotRef);
        if (!slotDoc.exists) {
          throw const ServerException(message: 'Associated slot not found.');
        }

        final slotData = slotDoc.data()!;
        if (slotData['isBooked'] == true || slotData['status'] == 'BOOKED') {
          throw const ServerException(message: 'This slot has already been booked and confirmed.');
        }

        // Lock slot
        transaction.update(slotRef, {
          'isBooked': true,
          'status': 'BOOKED',
          'bookedStudentId': bData['studentId'],
          'bookedStudentName': bData['studentName'],
          'bookedBookingId': bookingId,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Approve winning booking
        transaction.update(bookingRef, {
          'status': 'APPROVED',
          'reviewedAt': FieldValue.serverTimestamp(),
        });

        // Mark competing requests as REJECTED
        final competingQuery = await _firestore
            .collection('counselingBookings')
            .where('slotId', isEqualTo: slotId)
            .where('status', isEqualTo: 'PENDING')
            .get();

        for (final doc in competingQuery.docs) {
          if (doc.id != bookingId) {
            transaction.update(doc.reference, {
              'status': 'REJECTED',
              'rejectionReason': 'Slot already booked by another student.',
              'reviewedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      });
  }

  @override
  Future<void> rejectBooking(String bookingId, {String? reason}) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('rejectCounselingBooking');
        await callable.call({
          'bookingId': bookingId,
          if (reason != null) 'reason': reason,
        });
        return;
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? 'Failed to reject booking.');
        }
        AppLogger.w('rejectCounselingBooking callable note: $e. Falling back to direct Firestore update.');
      } catch (e) {
        AppLogger.w('rejectCounselingBooking error: $e. Falling back to direct Firestore update.');
      }
    }
      // Fallback
      await _firestore.collection('counselingBookings').doc(bookingId).update({
        'status': 'REJECTED',
        'rejectionReason': reason ?? 'Declined by faculty.',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
  }

  @override
  Future<void> deleteSlot(String slotId) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('deleteCounselingSlot');
        await callable.call({'slotId': slotId});
        return;
      } catch (e) {
        AppLogger.w('deleteCounselingSlot callable note: $e. Falling back to direct Firestore delete.');
      }
    }
      // Fallback
      final slotDoc = await _firestore.collection('counselingSlots').doc(slotId).get();
      if (!slotDoc.exists) throw const ServerException(message: 'Slot not found.');
      if (slotDoc.data()?['isBooked'] == true) {
        throw const ServerException(message: 'Cannot delete a booked counseling slot.');
      }
      await _firestore.collection('counselingSlots').doc(slotId).delete();
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

  @override
  Future<CounselingSlot> createSlot({
    required String slotDate,
    required String startTime,
    required String endTime,
    String? notes,
  }) async {
    try {
      return await remoteDataSource.createSlot(
        slotDate: slotDate,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<CounselingSlot>> getTeacherSlots(String teacherId) async {
    try {
      final list = await remoteDataSource.getTeacherSlots(teacherId);
      return List<CounselingSlot>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<CounselingBooking>> getTeacherRequests(String teacherId) async {
    try {
      final list = await remoteDataSource.getTeacherRequests(teacherId);
      return List<CounselingBooking>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> approveBooking(String bookingId) async {
    try {
      await remoteDataSource.approveBooking(bookingId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> rejectBooking(String bookingId, {String? reason}) async {
    try {
      await remoteDataSource.rejectBooking(bookingId, reason: reason);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> deleteSlot(String slotId) async {
    try {
      await remoteDataSource.deleteSlot(slotId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
