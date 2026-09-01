import '../entities/curriculum_entities.dart';

abstract class CurriculumRepository {
  Future<List<Course>> getMyCourses();
  Future<List<ScheduleSlot>> getSchedule({String? day});
  Future<List<Exam>> getExams();
}

class GetMyCoursesUseCase {
  final CurriculumRepository repository;
  GetMyCoursesUseCase(this.repository);

  Future<List<Course>> execute() => repository.getMyCourses();
}

class GetScheduleUseCase {
  final CurriculumRepository repository;
  GetScheduleUseCase(this.repository);

  Future<List<ScheduleSlot>> execute({String? day}) => repository.getSchedule(day: day);
}

class GetExamsUseCase {
  final CurriculumRepository repository;
  GetExamsUseCase(this.repository);

  Future<List<Exam>> execute() => repository.getExams();
}
