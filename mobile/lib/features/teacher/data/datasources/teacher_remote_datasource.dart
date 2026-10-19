import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../curriculum/data/models/curriculum_models.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../domain/entities/teacher_dashboard_data.dart';

abstract class TeacherRemoteDataSource {
  Future<TeacherDashboardData> getTeacherDashboardData({
    required User teacher,
    DateTime? currentTime,
  });
}

class TeacherRemoteDataSourceImpl implements TeacherRemoteDataSource {
  final FirebaseFirestore _firestore;

  TeacherRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<TeacherDashboardData> getTeacherDashboardData({
    required User teacher,
    DateTime? currentTime,
  }) async {
    try {
      final now = currentTime ?? DateTime.now();

      // 1. Time-aware window calculation
      // 05:00 to 16:59 -> Today's Classes
      // 17:00 to 04:59 -> Tomorrow's Classes (Next-day preparation)
      final bool isTomorrow = now.hour >= 17 || now.hour < 5;
      final DateTime targetDate =
          isTomorrow ? now.add(const Duration(days: 1)) : now;
      final String targetDayOfWeek = _dayOfWeekFromWeekday(targetDate.weekday);
      final String formattedDate = DateFormat('MMM d, yyyy').format(targetDate);
      final String targetDateLabel = isTomorrow
          ? 'Tomorrow · $formattedDate'
          : 'Today · $formattedDate';

      AppLogger.i(
        'Loading Teacher Dashboard for ${teacher.fullName} (Target: $targetDayOfWeek, isTomorrow: $isTomorrow)',
      );

      // 2. Fetch Assigned Courses
      final List<Course> assignedCourses = await _fetchAssignedCourses(teacher);
      final Set<String> assignedCodes = assignedCourses.map((c) => c.code.toUpperCase()).toSet();
      final Set<String> assignedIds = assignedCourses.map((c) => c.id).toSet();

      // 3. Fetch Time-Aware Routine Classes
      final List<ScheduleSlot> timeAwareClasses =
          await _fetchTimeAwareClasses(teacher, targetDayOfWeek, assignedCodes, assignedIds);

      // Fetch Time-Aware Exams
      final List<Exam> timeAwareExams =
          await _fetchTimeAwareExams(teacher, targetDate, assignedCodes, assignedIds);

      // 4. Fetch Key Metrics
      final int pendingCounseling = await _fetchPendingCounselingCount(teacher);
      final int feedbackCount = await _fetchFeedbackCount(teacher, assignedCodes);
      final int classesTaught = await _fetchClassesTaughtCount(teacher, assignedCodes);

      return TeacherDashboardData(
        teacherId: teacher.id,
        teacherName: teacher.fullName,
        email: teacher.email,
        phone: teacher.phone,
        avatarUrl: teacher.avatarUrl,
        role: teacher.role,
        pendingCounselingCount: pendingCounseling,
        feedbackCount: feedbackCount,
        classesTaughtCount: classesTaught > 0 ? classesTaught : assignedCourses.length,
        assignedCourses: assignedCourses,
        timeAwareClasses: timeAwareClasses,
        timeAwareExams: timeAwareExams,
        isTomorrow: isTomorrow,
        targetDateLabel: targetDateLabel,
        dayOfWeek: targetDayOfWeek,
      );
    } catch (e, stack) {
      AppLogger.e('Error fetching teacher dashboard data', e, stack);
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to load teacher dashboard data: $e');
    }
  }

  Future<List<Course>> _fetchAssignedCourses(User teacher) async {
    final Map<String, Course> courseMap = {};

    // A. Query courses where teacherId matches
    final snapByTeacherId = await _firestore
        .collection('courses')
        .where('teacherId', isEqualTo: teacher.id)
        .get();

    for (final doc in snapByTeacherId.docs) {
      final model = CourseModel.fromFirestore(doc);
      courseMap[model.code] = model;
    }

    // B. Query courseAssignments for this teacher
    final snapAssignments = await _firestore
        .collection('courseAssignments')
        .where('teacherId', isEqualTo: teacher.id)
        .get();

    final Set<String> assignmentCourseCodes = {};
    for (final doc in snapAssignments.docs) {
      final data = doc.data();
      final code = data['courseCode'] as String? ?? data['courseId'] as String?;
      if (code != null && code.isNotEmpty) {
        assignmentCourseCodes.add(code);
      }
    }

    // C. Include courses from user's assignedCourseIds
    final Set<String> allCodesToFind = {
      ...assignmentCourseCodes,
      ...teacher.assignedCourseIds,
    };

    if (allCodesToFind.isNotEmpty) {
      // Fetch missing courses by code / ID in batches of 10
      final missingCodes = allCodesToFind.where((c) => !courseMap.containsKey(c)).toList();
      for (int i = 0; i < missingCodes.length; i += 10) {
        final chunk = missingCodes.sublist(
          i,
          i + 10 > missingCodes.length ? missingCodes.length : i + 10,
        );
        final snapChunk = await _firestore
            .collection('courses')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapChunk.docs) {
          final model = CourseModel.fromFirestore(doc);
          courseMap[model.code] = model;
        }

        // Also check by 'code' field if doc IDs were UUIDs
        final snapByCodeField = await _firestore
            .collection('courses')
            .where('code', whereIn: chunk)
            .get();
        for (final doc in snapByCodeField.docs) {
          final model = CourseModel.fromFirestore(doc);
          courseMap[model.code] = model;
        }
      }
    }

    // D. If still empty, check by teacherName in courses collection
    if (courseMap.isEmpty && teacher.fullName.isNotEmpty) {
      final snapByName = await _firestore
          .collection('courses')
          .where('teacherName', isEqualTo: teacher.fullName)
          .get();
      for (final doc in snapByName.docs) {
        final model = CourseModel.fromFirestore(doc);
        courseMap[model.code] = model;
      }
    }

    final courses = courseMap.values.toList();
    courses.sort((a, b) => a.code.compareTo(b.code));
    return courses;
  }

  Future<List<ScheduleSlot>> _fetchTimeAwareClasses(
    User teacher,
    String targetDayOfWeek,
    Set<String> assignedCodes,
    Set<String> assignedIds,
  ) async {
    final snapshot = await _firestore
        .collection('schedules')
        .where('dayOfWeek', isEqualTo: targetDayOfWeek.toUpperCase())
        .get();

    final List<ScheduleSlot> slots = [];

    for (final doc in snapshot.docs) {
      final model = ScheduleSlotModel.fromFirestore(doc);

      // Business Rule: Do NOT display internal attendance markers as ordinary classes
      if (_isInternalAttendanceMarker(model)) {
        continue;
      }

      // Check teacher attribution: by ID, by Name, or by assigned course codes
      final bool matchesTeacherId =
          model.teacherId.isNotEmpty && model.teacherId == teacher.id;
      final bool matchesTeacherName = model.teacherName.isNotEmpty &&
          model.teacherName.trim().toLowerCase() ==
              teacher.fullName.trim().toLowerCase();
      final bool matchesCourse = assignedCodes.contains(model.courseCode.toUpperCase()) ||
          assignedIds.contains(model.courseId);

      if (matchesTeacherId || matchesTeacherName || matchesCourse) {
        slots.add(model);
      }
    }

    // Sort chronologically by start time
    slots.sort((a, b) => a.startTime.compareTo(b.startTime));
    return slots;
  }

  Future<List<Exam>> _fetchTimeAwareExams(
    User teacher,
    DateTime targetDate,
    Set<String> assignedCodes,
    Set<String> assignedIds,
  ) async {
    try {
      final snapshot = await _firestore.collection('exams').get();
      final List<Exam> exams = [];
      final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final targetFormatted1 = DateFormat('MMM d, yyyy').format(targetDate);
      final targetFormatted2 = DateFormat('MMM d').format(targetDate);

      for (final doc in snapshot.docs) {
        final exam = ExamModel.fromFirestore(doc);
        final matchesCourse = assignedCodes.contains(exam.courseCode.toUpperCase()) ||
            assignedIds.contains(exam.courseId);

        final examDateClean = exam.examDate.trim();
        final matchesDate = examDateClean.contains(targetDateStr) ||
            examDateClean.contains(targetFormatted1) ||
            examDateClean.contains(targetFormatted2);

        if (matchesCourse || matchesDate) {
          exams.add(exam);
        }
      }
      exams.sort((a, b) => a.startTime.compareTo(b.startTime));
      return exams;
    } catch (_) {
      return [];
    }
  }

  bool _isInternalAttendanceMarker(ScheduleSlot slot) {
    final code = slot.courseCode.toUpperCase();
    final title = slot.courseTitle.toLowerCase();
    return code.startsWith('ATT_') ||
        code.startsWith('INTERNAL_') ||
        code.contains('MARKER') ||
        title.contains('attendance marker') ||
        title.contains('internal marker') ||
        title.contains('test marker');
  }

  Future<int> _fetchPendingCounselingCount(User teacher) async {
    try {
      final snapById = await _firestore
          .collection('counselingBookings')
          .where('teacherId', isEqualTo: teacher.id)
          .where('status', isEqualTo: 'PENDING')
          .get();

      if (snapById.docs.isNotEmpty) {
        return snapById.docs.length;
      }

      // Fallback by name if seeded with name
      if (teacher.fullName.isNotEmpty) {
        final snapByName = await _firestore
            .collection('counselingBookings')
            .where('teacherName', isEqualTo: teacher.fullName)
            .where('status', isEqualTo: 'PENDING')
            .get();
        return snapByName.docs.length;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchFeedbackCount(User teacher, Set<String> assignedCodes) async {
    try {
      final snapById = await _firestore
          .collection('feedback')
          .where('teacherId', isEqualTo: teacher.id)
          .get();

      if (snapById.docs.isNotEmpty) {
        return snapById.docs.length;
      }

      if (teacher.fullName.isNotEmpty) {
        final snapByName = await _firestore
            .collection('feedback')
            .where('teacherName', isEqualTo: teacher.fullName)
            .get();
        if (snapByName.docs.isNotEmpty) {
          return snapByName.docs.length;
        }
      }

      if (assignedCodes.isNotEmpty) {
        final snapByCourse = await _firestore
            .collection('feedback')
            .where('courseCode', whereIn: assignedCodes.take(10).toList())
            .get();
        return snapByCourse.docs.length;
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _fetchClassesTaughtCount(User teacher, Set<String> assignedCodes) async {
    try {
      final snapById = await _firestore
          .collection('attendanceSessions')
          .where('teacherId', isEqualTo: teacher.id)
          .get();

      if (snapById.docs.isNotEmpty) {
        return snapById.docs.length;
      }

      if (assignedCodes.isNotEmpty) {
        final snapByCourse = await _firestore
            .collection('attendanceSessions')
            .where('courseCode', whereIn: assignedCodes.take(10).toList())
            .get();
        return snapByCourse.docs.length;
      }

      return 0;
    } catch (_) {
      return 0;
    }
  }

  String _dayOfWeekFromWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'MONDAY';
      case DateTime.tuesday:
        return 'TUESDAY';
      case DateTime.wednesday:
        return 'WEDNESDAY';
      case DateTime.thursday:
        return 'THURSDAY';
      case DateTime.friday:
        return 'FRIDAY';
      case DateTime.saturday:
        return 'SATURDAY';
      case DateTime.sunday:
      default:
        return 'SUNDAY';
    }
  }
}
