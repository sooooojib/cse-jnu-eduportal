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
  });

  @override
  List<Object?> get props => [id, teacherId, teacherName, teacherEmail, slotDate, startTime, endTime, status, notes];
}

class CounselingBooking extends Equatable {
  final String id;
  final String slotId;
  final String teacherId;
  final String teacherName;
  final String slotDate;
  final String startTime;
  final String endTime;
  final String category;
  final String notes;
  final String status;
  final String? reviewedAt;
  final String createdAt;

  const CounselingBooking({
    required this.id,
    required this.slotId,
    required this.teacherId,
    required this.teacherName,
    required this.slotDate,
    required this.startTime,
    required this.endTime,
    required this.category,
    required this.notes,
    required this.status,
    this.reviewedAt,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, slotId, teacherId, teacherName, slotDate, startTime, endTime, category, notes, status, reviewedAt, createdAt];
}
