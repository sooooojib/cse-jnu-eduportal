import 'package:equatable/equatable.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../attendance/domain/entities/attendance_entities.dart';
import '../../../counseling/domain/entities/counseling_entities.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';

/// Aggregated presentation data model for the Class Representative (CR) Dashboard.
class CrDashboardData extends Equatable {
  final String crId;
  final String crName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final int year;
  final int semester;
  final String? studentId;
  final String semesterStatus;

  // 1. Personal Attendance
  final double attendancePercentage;
  final int attendedClasses;
  final int totalClasses;
  final bool isAttendanceEligible;
  final List<CourseAttendance> courseAttendances;

  // 2. Classes Today & Routine
  final int classesTodayCount;
  final List<ScheduleSlot> todayClasses;
  final List<ScheduleSlot> tomorrowClasses;

  // 3. Counseling
  final int availableCounselingSlotsCount;
  final int myActiveCounselingCount;
  final List<CounselingBooking> myBookings;

  // 4. Upcoming Exams
  final int upcomingExamsCount;
  final List<Exam> upcomingExams;

  // 5. Enrolled Semester Courses
  final List<Course> enrolledCourses;

  // 6. Time & Calendar Metadata
  final String targetDateLabel;
  final String dayOfWeek;
  final String tomorrowDateLabel;

  const CrDashboardData({
    required this.crId,
    required this.crName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role = UserRole.cr,
    required this.year,
    required this.semester,
    this.studentId,
    this.semesterStatus = 'APPROVED',
    required this.attendancePercentage,
    required this.attendedClasses,
    required this.totalClasses,
    required this.isAttendanceEligible,
    this.courseAttendances = const [],
    required this.classesTodayCount,
    this.todayClasses = const [],
    this.tomorrowClasses = const [],
    required this.availableCounselingSlotsCount,
    required this.myActiveCounselingCount,
    this.myBookings = const [],
    required this.upcomingExamsCount,
    this.upcomingExams = const [],
    this.enrolledCourses = const [],
    required this.targetDateLabel,
    required this.dayOfWeek,
    required this.tomorrowDateLabel,
  });

  @override
  List<Object?> get props => [
        crId,
        crName,
        email,
        phone,
        avatarUrl,
        role,
        year,
        semester,
        studentId,
        semesterStatus,
        attendancePercentage,
        attendedClasses,
        totalClasses,
        isAttendanceEligible,
        courseAttendances,
        classesTodayCount,
        todayClasses,
        tomorrowClasses,
        availableCounselingSlotsCount,
        myActiveCounselingCount,
        myBookings,
        upcomingExamsCount,
        upcomingExams,
        enrolledCourses,
        targetDateLabel,
        dayOfWeek,
        tomorrowDateLabel,
      ];
}
