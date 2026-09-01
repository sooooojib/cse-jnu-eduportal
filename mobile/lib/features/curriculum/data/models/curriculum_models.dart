import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/curriculum_entities.dart';

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
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      credit: (json['credit'] as num?)?.toDouble() ?? 0.0,
      year: json['year'] as int? ?? 1,
      semester: json['semester'] as int? ?? 1,
      courseType: json['courseType'] as String? ?? 'THEORY',
      description: json['description'] as String?,
      teacherId: json['teacherId'] as String?,
      teacherName: json['teacherName'] as String?,
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
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
