import '../entities/curriculum_entities.dart';

abstract class CurriculumRepository {
  Future<List<Course>> getMyCourses();
  Future<List<ScheduleSlot>> getSchedule({String? day, int? year, int? semester, String? teacherId});
  Future<ScheduleSlot> createScheduleSlot(ScheduleSlot slot);
  Future<ScheduleSlot> updateScheduleSlot(ScheduleSlot slot);
  Future<void> deleteScheduleSlot(String slotId);
  Future<TeacherAvailability> getTeacherAvailability({required String teacherId, required String dayOfWeek, String? date});
  Future<WhatsAppBroadcastData> getWhatsAppBroadcast({int? year, int? semester});
  Future<List<Course>> getAllCourses({int? year, int? semester});
  Future<List<Map<String, String>>> getAllTeachers();
  Future<List<Exam>> getExams({int? year, int? semester, String? courseId});
  Future<Exam> createExam(Exam exam);
  Future<Exam> updateExam(Exam exam);
  Future<void> deleteExam(String examId);
  Future<List<CourseAssignment>> getCourseAssignments({String? courseId, String? teacherId});
  Future<List<Enrollment>> getEnrollments({int? year, int? semester, String? studentId});
}

class GetMyCoursesUseCase {
  final CurriculumRepository repository;
  GetMyCoursesUseCase(this.repository);

  Future<List<Course>> execute() => repository.getMyCourses();
}

class GetScheduleUseCase {
  final CurriculumRepository repository;
  GetScheduleUseCase(this.repository);

  Future<List<ScheduleSlot>> execute({String? day, int? year, int? semester, String? teacherId}) =>
      repository.getSchedule(day: day, year: year, semester: semester, teacherId: teacherId);
}

class CreateScheduleSlotUseCase {
  final CurriculumRepository repository;
  CreateScheduleSlotUseCase(this.repository);

  Future<ScheduleSlot> execute(ScheduleSlot slot) => repository.createScheduleSlot(slot);
}

class UpdateScheduleSlotUseCase {
  final CurriculumRepository repository;
  UpdateScheduleSlotUseCase(this.repository);

  Future<ScheduleSlot> execute(ScheduleSlot slot) => repository.updateScheduleSlot(slot);
}

class DeleteScheduleSlotUseCase {
  final CurriculumRepository repository;
  DeleteScheduleSlotUseCase(this.repository);

  Future<void> execute(String slotId) => repository.deleteScheduleSlot(slotId);
}

class GetTeacherAvailabilityUseCase {
  final CurriculumRepository repository;
  GetTeacherAvailabilityUseCase(this.repository);

  Future<TeacherAvailability> execute({required String teacherId, required String dayOfWeek, String? date}) =>
      repository.getTeacherAvailability(teacherId: teacherId, dayOfWeek: dayOfWeek, date: date);
}

class GetWhatsAppBroadcastUseCase {
  final CurriculumRepository repository;
  GetWhatsAppBroadcastUseCase(this.repository);

  Future<WhatsAppBroadcastData> execute({int? year, int? semester}) =>
      repository.getWhatsAppBroadcast(year: year, semester: semester);
}

class GetAllCoursesUseCase {
  final CurriculumRepository repository;
  GetAllCoursesUseCase(this.repository);

  Future<List<Course>> execute({int? year, int? semester}) =>
      repository.getAllCourses(year: year, semester: semester);
}

class GetAllTeachersUseCase {
  final CurriculumRepository repository;
  GetAllTeachersUseCase(this.repository);

  Future<List<Map<String, String>>> execute() => repository.getAllTeachers();
}

class GetExamsUseCase {
  final CurriculumRepository repository;
  GetExamsUseCase(this.repository);

  Future<List<Exam>> execute({int? year, int? semester, String? courseId}) =>
      repository.getExams(year: year, semester: semester, courseId: courseId);
}

class CreateExamUseCase {
  final CurriculumRepository repository;
  CreateExamUseCase(this.repository);

  Future<Exam> execute(Exam exam) => repository.createExam(exam);
}

class UpdateExamUseCase {
  final CurriculumRepository repository;
  UpdateExamUseCase(this.repository);

  Future<Exam> execute(Exam exam) => repository.updateExam(exam);
}

class DeleteExamUseCase {
  final CurriculumRepository repository;
  DeleteExamUseCase(this.repository);

  Future<void> execute(String examId) => repository.deleteExam(examId);
}

