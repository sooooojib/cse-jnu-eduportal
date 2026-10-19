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

  // Time-Aware Schedule Metadata
  final bool isTomorrow;
  final String targetDateLabel;
  final String dayOfWeek;

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
    required this.isTomorrow,
    required this.targetDateLabel,
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
        isTomorrow,
        targetDateLabel,
        dayOfWeek,
      ];
}
