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
  });

  @override
  List<Object?> get props => [id, code, title, credit, year, semester, courseType, description, teacherId, teacherName];
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
  });

  @override
  List<Object?> get props => [id, courseId, courseCode, courseTitle, teacherId, teacherName, dayOfWeek, startTime, endTime, room, targetYear, targetSemester, isExtraClass];
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
  });

  @override
  List<Object?> get props => [id, courseId, courseCode, courseTitle, title, examDate, startTime, endTime, room, year, semester];
}
