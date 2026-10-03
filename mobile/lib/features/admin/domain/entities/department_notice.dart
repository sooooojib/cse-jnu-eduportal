import 'package:equatable/equatable.dart';

class DepartmentNotice extends Equatable {
  final String id;
  final String title;
  final String message;
  final String noticeType; // SEMESTER_EXAM, CENTRAL_ROUTINE, GENERAL_NOTICE, EMERGENCY_ALERT, ACADEMIC_UPDATE
  final String targetAudience; // ALL, STUDENTS, TEACHERS, CRS, BATCH_13, BATCH_14, BATCH_15, BATCH_16, POSTGRADUATE
  final String? attachmentUrl;
  final String? attachmentType; // IMAGE, PDF, LINK
  final String priority; // NORMAL, HIGH, URGENT
  final bool syncedToPublicRoutines;
  final String sentBy;
  final String createdAt;

  const DepartmentNotice({
    required this.id,
    required this.title,
    required this.message,
    required this.noticeType,
    required this.targetAudience,
    this.attachmentUrl,
    this.attachmentType,
    this.priority = 'NORMAL',
    this.syncedToPublicRoutines = false,
    required this.sentBy,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        message,
        noticeType,
        targetAudience,
        attachmentUrl,
        attachmentType,
        priority,
        syncedToPublicRoutines,
        sentBy,
        createdAt,
      ];
}
