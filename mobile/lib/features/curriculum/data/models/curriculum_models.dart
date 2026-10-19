import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/curriculum_entities.dart';

String _tsToString(dynamic value) {
  if (value == null) return DateTime.now().toIso8601String();
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value.toString();
}

class CourseModel extends Course {
  const CourseModel({
    required super.id,
    required super.code,
    required super.title,
    required super.credit,
    required super.year,
    required super.semester,
    required super.courseType,
    super.description,
    super.teacherId,
    super.teacherName,
    super.coordinatorId,
    super.createdAt,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String? ?? json['code'] as String? ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      year: json['year'] as int? ?? 1,
      semester: json['semester'] as int? ?? 1,
      courseType: json['courseType'] as String? ?? 'THEORY',
      description: json['description'] as String?,
      teacherId: json['teacherId'] as String?,
      teacherName: json['teacherName'] as String?,
      coordinatorId: json['coordinatorId'] as String?,
      createdAt: json['createdAt'] != null ? _tsToString(json['createdAt']) : null,
    );
  }

  factory CourseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CourseModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'credit': credit,
      'year': year,
      'semester': semester,
      'courseType': courseType,
      if (description != null) 'description': description,
      if (teacherId != null) 'teacherId': teacherId,
      if (teacherName != null) 'teacherName': teacherName,
      if (coordinatorId != null) 'coordinatorId': coordinatorId,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'title': title,
      'credit': credit,
      'year': year,
      'semester': semester,
      'courseType': courseType,
      if (description != null) 'description': description,
      if (teacherId != null) 'teacherId': teacherId,
      if (teacherName != null) 'teacherName': teacherName,
      if (coordinatorId != null) 'coordinatorId': coordinatorId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class CourseAssignmentModel extends CourseAssignment {
  const CourseAssignmentModel({
    required super.id,
    required super.courseId,
    required super.courseCode,
    required super.courseTitle,
    required super.teacherId,
    required super.teacherName,
    super.isCoordinator = false,
  });

  factory CourseAssignmentModel.fromJson(Map<String, dynamic> json) {
    return CourseAssignmentModel(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      courseCode: json['courseCode'] as String? ?? '',
      courseTitle: json['courseTitle'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      isCoordinator: json['isCoordinator'] as bool? ?? false,
    );
  }

  factory CourseAssignmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CourseAssignmentModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'isCoordinator': isCoordinator,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'courseId': courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'isCoordinator': isCoordinator,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class EnrollmentModel extends Enrollment {
  const EnrollmentModel({
    required super.id,
    required super.studentId,
    required super.studentName,
    required super.studentRoll,
    required super.year,
    required super.semester,
    required super.enrolledCourseIds,
  });

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) {
    return EnrollmentModel(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      studentRoll: json['studentRoll'] as String? ?? '',
      year: json['year'] as int? ?? 1,
      semester: json['semester'] as int? ?? 1,
      enrolledCourseIds: (json['enrolledCourseIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  factory EnrollmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return EnrollmentModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentRoll': studentRoll,
      'year': year,
      'semester': semester,
      'enrolledCourseIds': enrolledCourseIds,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentRoll': studentRoll,
      'year': year,
      'semester': semester,
      'enrolledCourseIds': enrolledCourseIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ScheduleSlotModel extends ScheduleSlot {
  const ScheduleSlotModel({
    required super.id,
    required super.courseId,
    required super.courseCode,
    required super.courseTitle,
    required super.teacherId,
    required super.teacherName,
    required super.dayOfWeek,
    required super.startTime,
    required super.endTime,
    required super.room,
    required super.targetYear,
    required super.targetSemester,
    super.isExtraClass = false,
    super.date,
    super.status = 'SCHEDULED',
    super.createdBy,
  });

  factory ScheduleSlotModel.fromJson(Map<String, dynamic> json) {
    return ScheduleSlotModel(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      courseCode: json['courseCode'] as String? ?? '',
      courseTitle: json['courseTitle'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as String? ?? 'SUNDAY',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      room: json['room'] as String? ?? '',
      targetYear: json['targetYear'] as int? ?? 1,
      targetSemester: json['targetSemester'] as int? ?? 1,
      isExtraClass: json['isExtraClass'] as bool? ?? false,
      date: json['date'] as String?,
      status: json['status'] as String? ?? 'SCHEDULED',
      createdBy: json['createdBy'] as String?,
    );
  }

  factory ScheduleSlotModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ScheduleSlotModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'targetYear': targetYear,
      'targetSemester': targetSemester,
      'isExtraClass': isExtraClass,
      'date': date,
      'status': status,
      'createdBy': createdBy,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'courseId': courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'targetYear': targetYear,
      'targetSemester': targetSemester,
      'isExtraClass': isExtraClass,
      'date': date,
      'status': status,
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ExamModel extends Exam {
  const ExamModel({
    required super.id,
    required super.courseId,
    required super.courseCode,
    required super.courseTitle,
    required super.title,
    required super.examDate,
    required super.startTime,
    required super.endTime,
    required super.room,
    required super.year,
    required super.semester,
    super.type = 'MID_TERM',
    super.instructions,
    super.invigilatorName,
    super.invigilatorId,
    super.createdBy,
    super.creatorRole,
    super.createdAt,
    super.updatedAt,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: json['id'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      courseCode: json['courseCode'] as String? ?? '',
      courseTitle: json['courseTitle'] as String? ?? '',
      title: json['title'] as String? ?? '',
      examDate: json['examDate'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      room: json['room'] as String? ?? '',
      year: json['year'] as int? ?? 1,
      semester: json['semester'] as int? ?? 1,
      type: json['type'] as String? ?? 'MID_TERM',
      instructions: json['instructions'] as String?,
      invigilatorName: json['invigilatorName'] as String?,
      invigilatorId: json['invigilatorId'] as String?,
      createdBy: json['createdBy'] as String?,
      creatorRole: json['creatorRole'] as String?,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate().toIso8601String()
          : json['createdAt'] as String?,
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate().toIso8601String()
          : json['updatedAt'] as String?,
    );
  }

  factory ExamModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ExamModel.fromJson({'id': doc.id, ...data});
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'title': title,
      'examDate': examDate,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'year': year,
      'semester': semester,
      'type': type,
      'instructions': instructions,
      'invigilatorName': invigilatorName,
      'invigilatorId': invigilatorId,
      'createdBy': createdBy,
      'creatorRole': creatorRole,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'courseId': courseId,
      'courseCode': courseCode,
      'courseTitle': courseTitle,
      'title': title,
      'examDate': examDate,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'year': year,
      'semester': semester,
      'type': type,
      'instructions': instructions,
      'invigilatorName': invigilatorName,
      'invigilatorId': invigilatorId,
      'createdBy': createdBy,
      'creatorRole': creatorRole,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class TeacherAvailabilityModel extends TeacherAvailability {
  const TeacherAvailabilityModel({
    required super.teacherId,
    required super.teacherName,
    required super.dayOfWeek,
    required super.busySlots,
    required super.freeWindows,
  });

  factory TeacherAvailabilityModel.fromJson(Map<String, dynamic> json) {
    final rawBusy = json['busySlots'] as List<dynamic>? ?? [];
    final busy = rawBusy.map((b) {
      final map = b is Map<String, dynamic> ? b : Map<String, dynamic>.from(b as Map);
      return TeacherAvailabilitySlot(
        startTime: map['startTime'] as String? ?? '',
        endTime: map['endTime'] as String? ?? '',
        courseCode: map['courseCode'] as String? ?? '',
        room: map['room'] as String? ?? '',
      );
    }).toList();

    final rawFree = json['freeWindows'] as List<dynamic>? ?? [];
    final free = rawFree.map((f) {
      final map = f is Map<String, dynamic> ? f : Map<String, dynamic>.from(f as Map);
      return TeacherAvailabilityWindow(
        startTime: map['startTime'] as String? ?? '',
        endTime: map['endTime'] as String? ?? '',
        durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    return TeacherAvailabilityModel(
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as String? ?? '',
      busySlots: busy,
      freeWindows: free,
    );
  }
}

class WhatsAppBroadcastDataModel extends WhatsAppBroadcastData {
  const WhatsAppBroadcastDataModel({
    required super.date,
    required super.dayOfWeek,
    required super.slotCount,
    required super.broadcastText,
    required super.whatsappUrl,
  });

  factory WhatsAppBroadcastDataModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppBroadcastDataModel(
      date: json['date'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as String? ?? '',
      slotCount: (json['slotCount'] as num?)?.toInt() ?? 0,
      broadcastText: json['broadcastText'] as String? ?? '',
      whatsappUrl: json['whatsappUrl'] as String? ?? '',
    );
  }
}
