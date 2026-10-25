import 'package:equatable/equatable.dart';
import 'package:cse_jnu_eduportal/features/curriculum/domain/entities/curriculum_entities.dart';
import 'package:cse_jnu_eduportal/core/constants/role_constants.dart';

/// Aggregated presentation data model for the Teacher Dashboard.
class TeacherDashboardData extends Equatable {
  final String teacherId;
  final String teacherName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;

  // Key Metrics
  final int pendingCounselingCount;
  final int feedbackCount;
  final int classesTaughtCount;

  // Curriculum Data
  final List<Course> assignedCourses;
  final List<ScheduleSlot> timeAwareClasses;
  final List<Exam> timeAwareExams;

  // Today & Tomorrow Data (Time-Aware)
  final List<ScheduleSlot> todayClasses;
  final List<ScheduleSlot> tomorrowClasses;
  final List<Exam> todayExams;
  final List<Exam> tomorrowExams;

  // Time-Aware Schedule Metadata
  final bool isTomorrow;
  final String targetDateLabel;
  final String todayDateLabel;
  final String tomorrowDateLabel;
  final String dayOfWeek;

  List<ScheduleSlot> get effectiveTodayClasses =>
      todayClasses.isNotEmpty ? todayClasses : (!isTomorrow ? timeAwareClasses : const []);

  List<ScheduleSlot> get effectiveTomorrowClasses =>
      tomorrowClasses.isNotEmpty ? tomorrowClasses : (isTomorrow ? timeAwareClasses : const []);

  List<Exam> get effectiveTodayExams =>
      todayExams.isNotEmpty ? todayExams : (!isTomorrow ? timeAwareExams : const []);

  List<Exam> get effectiveTomorrowExams =>
      tomorrowExams.isNotEmpty ? tomorrowExams : (isTomorrow ? timeAwareExams : const []);

  const TeacherDashboardData({
    required this.teacherId,
    required this.teacherName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role = UserRole.teacher,
    required this.pendingCounselingCount,
    required this.feedbackCount,
    required this.classesTaughtCount,
    required this.assignedCourses,
    required this.timeAwareClasses,
    this.timeAwareExams = const [],
    this.todayClasses = const [],
    this.tomorrowClasses = const [],
    this.todayExams = const [],
    this.tomorrowExams = const [],
    required this.isTomorrow,
    required this.targetDateLabel,
    this.todayDateLabel = '',
    this.tomorrowDateLabel = '',
    required this.dayOfWeek,
  });

  @override
  List<Object?> get props => [
        teacherId,
        teacherName,
        email,
        phone,
        avatarUrl,
        role,
        pendingCounselingCount,
        feedbackCount,
        classesTaughtCount,
        assignedCourses,
        timeAwareClasses,
        timeAwareExams,
        todayClasses,
        tomorrowClasses,
        todayExams,
        tomorrowExams,
        isTomorrow,
        targetDateLabel,
        todayDateLabel,
        tomorrowDateLabel,
        dayOfWeek,
      ];
}
