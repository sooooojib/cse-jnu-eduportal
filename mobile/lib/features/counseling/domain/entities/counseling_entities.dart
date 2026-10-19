import 'package:equatable/equatable.dart';

class CounselingSlot extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final String slotDate;
  final String startTime;
  final String endTime;
  final String status;
  final String? notes;
  final String? bookedStudentId;
  final String? bookedStudentName;

  const CounselingSlot({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.slotDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes,
    this.bookedStudentId,
    this.bookedStudentName,
  });

  bool get isBooked => status == 'BOOKED';

  @override
  List<Object?> get props => [
        id,
        teacherId,
        teacherName,
        teacherEmail,
        slotDate,
        startTime,
        endTime,
        status,
        notes,
        bookedStudentId,
        bookedStudentName,
      ];
}

class CounselingBooking extends Equatable {
  final String id;
  final String slotId;
  final String? studentId;
  final String? studentName;
  final String teacherId;
  final String teacherName;
  final String slotDate;
  final String startTime;
  final String endTime;
  final String category;
  final String notes;
  final String status;
  final String? rejectionReason;
  final String? reviewedAt;
  final String createdAt;

  const CounselingBooking({
    required this.id,
    required this.slotId,
    this.studentId,
    this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.slotDate,
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.notes,
    required this.status,
    this.rejectionReason,
    this.reviewedAt,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        slotId,
        studentId,
        studentName,
        teacherId,
        teacherName,
        slotDate,
        startTime,
        endTime,
        category,
        notes,
        status,
        rejectionReason,
        reviewedAt,
        createdAt,
      ];
}
