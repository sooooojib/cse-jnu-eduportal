import 'package:equatable/equatable.dart';

/// Kind of one-day change to the weekly routine.
enum ClassChangeType {
  extra('EXTRA', 'Extra class'),
  cancel('CANCEL', 'Cancelled'),
  move('MOVE', 'Moved'),

  /// The class was due but did not happen (e.g. the teacher did not come).
  /// Recorded after the fact by the CR (or an admin); counts against the
  /// teacher in the Chairman's monitoring, unlike a planned cancellation.
  notTaken('NOT_TAKEN', 'Not taken');

  final String value;
  final String label;
  const ClassChangeType(this.value, this.label);

  static ClassChangeType fromString(String? v) =>
      ClassChangeType.values.firstWhere((t) => t.value == (v ?? '').toUpperCase(), orElse: () => ClassChangeType.extra);
}

/// A one-day change (extra class, cancellation, move, or not taken) for one batch on one
/// date. Stored in `classChanges`; the weekly routine in `schedules` is never
/// modified by these.
class ClassChange extends Equatable {
  final String id;
  final ClassChangeType type;

  /// "yyyy-MM-dd".
  final String date;
  final String dayOfWeek;

  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String teacherId;
  final String teacherName;
  final int targetYear;
  final int targetSemester;

  /// New (or extra) time & room. For a cancellation these mirror the original.
  final String startTime;
  final String endTime;
  final String room;

  /// Routine slot being cancelled or moved (null for extra classes).
  final String? originalSlotId;
  final String? originalStartTime;
  final String? originalRoom;

  final String? reason;
  final String createdBy;
  final String createdByName;
  final String createdByRole;

  const ClassChange({
    required this.id,
    required this.type,
    required this.date,
    required this.dayOfWeek,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.teacherId,
    required this.teacherName,
    required this.targetYear,
    required this.targetSemester,
    required this.startTime,
    required this.endTime,
    required this.room,
    this.originalSlotId,
    this.originalStartTime,
    this.originalRoom,
    this.reason,
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
  });

  @override
  List<Object?> get props => [
        id, type, date, dayOfWeek, courseId, courseCode, courseTitle, teacherId, teacherName,
        targetYear, targetSemester, startTime, endTime, room, originalSlotId, originalStartTime,
        originalRoom, reason, createdBy, createdByName, createdByRole,
      ];
}
