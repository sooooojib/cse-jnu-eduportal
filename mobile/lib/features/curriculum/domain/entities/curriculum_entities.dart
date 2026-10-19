import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final String id;
  final String code;
  final String title;
  final double credit;
  final int year;
  final int semester;
  final String courseType;
  final String? description;
  final String? teacherId;
  final String? teacherName;
  final String? coordinatorId;
  final String? createdAt;

  const Course({
    required this.id,
    required this.code,
    required this.title,
    required this.credit,
    required this.year,
    required this.semester,
    required this.courseType,
    this.description,
    this.teacherId,
    this.teacherName,
    this.coordinatorId,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        code,
        title,
        credit,
        year,
        semester,
        courseType,
        description,
        teacherId,
        teacherName,
        coordinatorId,
        createdAt,
      ];
}

class CourseAssignment extends Equatable {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String teacherId;
  final String teacherName;
  final bool isCoordinator;

  const CourseAssignment({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.teacherId,
    required this.teacherName,
    this.isCoordinator = false,
  });

  @override
  List<Object?> get props => [id, courseId, courseCode, courseTitle, teacherId, teacherName, isCoordinator];
}

class Enrollment extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String studentRoll;
  final int year;
  final int semester;
  final List<String> enrolledCourseIds;

  const Enrollment({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentRoll,
    required this.year,
    required this.semester,
    required this.enrolledCourseIds,
  });

  @override
  List<Object?> get props => [id, studentId, studentName, studentRoll, year, semester, enrolledCourseIds];
}

class ScheduleSlot extends Equatable {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String teacherId;
  final String teacherName;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String room;
  final int targetYear;
  final int targetSemester;
  final bool isExtraClass;
  final String? date;
  final String? status;
  final String? createdBy;

  const ScheduleSlot({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.teacherId,
    required this.teacherName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.targetYear,
    required this.targetSemester,
    this.isExtraClass = false,
    this.date,
    this.status = 'SCHEDULED',
    this.createdBy,
  });

  ScheduleSlot copyWith({
    String? id,
    String? courseId,
    String? courseCode,
    String? courseTitle,
    String? teacherId,
    String? teacherName,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? room,
    int? targetYear,
    int? targetSemester,
    bool? isExtraClass,
    String? date,
    String? status,
    String? createdBy,
  }) {
    return ScheduleSlot(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseCode: courseCode ?? this.courseCode,
      courseTitle: courseTitle ?? this.courseTitle,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      targetYear: targetYear ?? this.targetYear,
      targetSemester: targetSemester ?? this.targetSemester,
      isExtraClass: isExtraClass ?? this.isExtraClass,
      date: date ?? this.date,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        courseCode,
        courseTitle,
        teacherId,
        teacherName,
        dayOfWeek,
        startTime,
        endTime,
        room,
        targetYear,
        targetSemester,
        isExtraClass,
        date,
        status,
        createdBy,
      ];
}

class TeacherAvailabilitySlot extends Equatable {
  final String startTime;
  final String endTime;
  final String courseCode;
  final String room;

  const TeacherAvailabilitySlot({
    required this.startTime,
    required this.endTime,
    required this.courseCode,
    required this.room,
  });

  @override
  List<Object?> get props => [startTime, endTime, courseCode, room];
}

class TeacherAvailabilityWindow extends Equatable {
  final String startTime;
  final String endTime;
  final int durationMinutes;

  const TeacherAvailabilityWindow({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  @override
  List<Object?> get props => [startTime, endTime, durationMinutes];
}

class TeacherAvailability extends Equatable {
  final String teacherId;
  final String teacherName;
  final String dayOfWeek;
  final List<TeacherAvailabilitySlot> busySlots;
  final List<TeacherAvailabilityWindow> freeWindows;

  const TeacherAvailability({
    required this.teacherId,
    required this.teacherName,
    required this.dayOfWeek,
    required this.busySlots,
    required this.freeWindows,
  });

  @override
  List<Object?> get props => [teacherId, teacherName, dayOfWeek, busySlots, freeWindows];
}

class WhatsAppBroadcastData extends Equatable {
  final String date;
  final String dayOfWeek;
  final int slotCount;
  final String broadcastText;
  final String whatsappUrl;

  const WhatsAppBroadcastData({
    required this.date,
    required this.dayOfWeek,
    required this.slotCount,
    required this.broadcastText,
    required this.whatsappUrl,
  });

  @override
  List<Object?> get props => [date, dayOfWeek, slotCount, broadcastText, whatsappUrl];
}

class Exam extends Equatable {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseTitle;
  final String title;
  final String examDate;
  final String startTime;
  final String endTime;
  final String room;
  final int year;
  final int semester;
  final String type;
  final String? instructions;
  final String? invigilatorName;
  final String? invigilatorId;
  final String? createdBy;
  final String? creatorRole;
  final String? createdAt;
  final String? updatedAt;

  const Exam({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseTitle,
    required this.title,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.year,
    required this.semester,
    this.type = 'MID_TERM',
    this.instructions,
    this.invigilatorName,
    this.invigilatorId,
    this.createdBy,
    this.creatorRole,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPast {
    try {
      final parts = examDate.split('-');
      if (parts.length == 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        // Consider exam past after midnight of that day
        final examDateObj = DateTime(y, m, d, 23, 59, 59);
        return DateTime.now().isAfter(examDateObj);
      }
    } catch (_) {}
    return false;
  }

  Exam copyWith({
    String? id,
    String? courseId,
    String? courseCode,
    String? courseTitle,
    String? title,
    String? examDate,
    String? startTime,
    String? endTime,
    String? room,
    int? year,
    int? semester,
    String? type,
    String? instructions,
    String? invigilatorName,
    String? invigilatorId,
    String? createdBy,
    String? creatorRole,
    String? createdAt,
    String? updatedAt,
  }) {
    return Exam(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseCode: courseCode ?? this.courseCode,
      courseTitle: courseTitle ?? this.courseTitle,
      title: title ?? this.title,
      examDate: examDate ?? this.examDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      year: year ?? this.year,
      semester: semester ?? this.semester,
      type: type ?? this.type,
      instructions: instructions ?? this.instructions,
      invigilatorName: invigilatorName ?? this.invigilatorName,
      invigilatorId: invigilatorId ?? this.invigilatorId,
      createdBy: createdBy ?? this.createdBy,
      creatorRole: creatorRole ?? this.creatorRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        courseCode,
        courseTitle,
        title,
        examDate,
        startTime,
        endTime,
        room,
        year,
        semester,
        type,
        instructions,
        invigilatorName,
        invigilatorId,
        createdBy,
        creatorRole,
        createdAt,
        updatedAt,
      ];
}
