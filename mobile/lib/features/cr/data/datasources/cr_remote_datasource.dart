import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../attendance/data/models/attendance_models.dart';
import '../../../attendance/domain/entities/attendance_entities.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../counseling/data/models/counseling_models.dart';
import '../../../counseling/domain/entities/counseling_entities.dart';
import '../../../curriculum/data/models/curriculum_models.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../domain/entities/cr_dashboard_data.dart';

abstract class CrRemoteDataSource {
  Future<CrDashboardData> getCrDashboardData({
    required User crUser,
    DateTime? currentTime,
  });

  Future<void> addTomorrowClassSlot({
    required User crUser,
    required ScheduleSlot slot,
  });
}

class CrRemoteDataSourceImpl implements CrRemoteDataSource {
  final FirebaseFirestore _firestore;

  CrRemoteDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<CrDashboardData> getCrDashboardData({
    required User crUser,
    DateTime? currentTime,
  }) async {
    try {
      final now = currentTime ?? DateTime.now();
      final bool isTomorrow = now.hour >= 17 || now.hour < 5;
      final String dayOfWeek = _dayOfWeekFromWeekday(now.weekday);
      final DateTime tomorrow = now.add(const Duration(days: 1));
      final String tomorrowDayOfWeek = _dayOfWeekFromWeekday(tomorrow.weekday);

      final String targetDateLabel = DateFormat('EEEE · MMM d, yyyy').format(now);
      final String tomorrowDateLabel = DateFormat('EEEE · MMM d, yyyy').format(tomorrow);

      AppLogger.i(
        'Loading CR Dashboard for ${crUser.fullName} (Year ${crUser.year}, Sem ${crUser.semester}, Day: $dayOfWeek)',
      );

      // 1. Fetch Enrolled Semester Courses
      final List<Course> enrolledCourses = await _fetchEnrolledCourses(crUser);

      // 2. Fetch Personal Attendance for CR
      final attendanceSummary = await _fetchPersonalAttendance(crUser, enrolledCourses);

      // 3. Fetch Classes Today & Tomorrow
      final List<ScheduleSlot> todayClasses =
          await _fetchClassesForDay(crUser, dayOfWeek);
      final List<ScheduleSlot> tomorrowClasses =
          await _fetchClassesForDay(crUser, tomorrowDayOfWeek);

      // 4. Fetch Counseling Info (Available Faculty Slots & My Bookings)
      final counselingInfo = await _fetchCounselingInfo(crUser);

      // 5. Fetch Upcoming Exams for this Year & Semester
      final List<Exam> upcomingExams = await _fetchUpcomingExams(crUser, now);

      // 6. Fetch latest semester status from user document if present
      String semesterStatus = crUser.semesterStatus ?? 'APPROVED';
      try {
        final userDoc = await _firestore.collection('users').doc(crUser.id).get();
        if (userDoc.exists && userDoc.data() != null) {
          semesterStatus = userDoc.data()?['semesterStatus'] as String? ?? semesterStatus;
        }
      } catch (_) {}

      return CrDashboardData(
        crId: crUser.id,
        crName: crUser.fullName,
        email: crUser.email,
        phone: crUser.phone,
        avatarUrl: crUser.avatarUrl,
        role: crUser.role,
        year: crUser.year ?? 1,
        semester: crUser.semester ?? 1,
        studentId: crUser.studentId,
        semesterStatus: semesterStatus,
        attendancePercentage: attendanceSummary.overallPercentage,
        attendedClasses: attendanceSummary.totalAttended,
        totalClasses: attendanceSummary.totalSessions,
        isAttendanceEligible: attendanceSummary.overallPercentage >= 75.0,
        courseAttendances: attendanceSummary.courseSummaries,
        classesTodayCount: todayClasses.length,
        todayClasses: todayClasses,
        tomorrowClasses: tomorrowClasses,
        availableCounselingSlotsCount: counselingInfo.availableSlotsCount,
        myActiveCounselingCount: counselingInfo.myBookings.length,
        myBookings: counselingInfo.myBookings,
        upcomingExamsCount: upcomingExams.length,
        upcomingExams: upcomingExams,
        enrolledCourses: enrolledCourses,
        targetDateLabel: targetDateLabel,
        dayOfWeek: dayOfWeek,
        tomorrowDateLabel: tomorrowDateLabel,
        isTomorrow: isTomorrow,
      );
    } catch (e, stack) {
      AppLogger.e('Error fetching CR dashboard data', e, stack);
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to load CR dashboard data: $e');
    }
  }

  @override
  Future<void> addTomorrowClassSlot({
    required User crUser,
    required ScheduleSlot slot,
  }) async {
    try {
      final docRef = _firestore.collection('schedules').doc();
      final slotMap = {
        'id': docRef.id,
        'courseId': slot.courseId,
        'courseCode': slot.courseCode,
        'courseTitle': slot.courseTitle,
        'teacherId': slot.teacherId,
        'teacherName': slot.teacherName,
        'dayOfWeek': slot.dayOfWeek,
        'startTime': slot.startTime,
        'endTime': slot.endTime,
        'room': slot.room,
        'targetYear': crUser.year ?? 1,
        'targetSemester': crUser.semester ?? 1,
        'isExtraClass': slot.isExtraClass,
        'createdBy': crUser.id,
        'createdByCrId': crUser.id,
        'creatorRole': 'CR',
        if (slot.date != null) 'date': slot.date,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Atomic batch write to both 'schedules' and 'scheduleSlots' so:
      // 1. Teachers see it on their dashboard and schedule screens (they query 'schedules')
      // 2. Students see it on their timetable/schedule screens (they query 'schedules')
      // 3. CR dashboard sees it in real time
      final batch = _firestore.batch();
      batch.set(docRef, slotMap);
      batch.set(_firestore.collection('scheduleSlots').doc(docRef.id), slotMap);
      await batch.commit();

      AppLogger.i('CR added schedule slot: ${docRef.id} for ${slot.dayOfWeek}');
    } catch (e, stack) {
      AppLogger.e('Failed to add schedule slot', e, stack);
      throw ServerException(message: 'Unable to schedule class slot: $e');
    }
  }

  Future<List<Course>> _fetchEnrolledCourses(User crUser) async {
    try {
      final snap = await _firestore
          .collection('courses')
          .where('year', isEqualTo: crUser.year ?? 1)
          .where('semester', isEqualTo: crUser.semester ?? 1)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => CourseModel.fromFirestore(d)).toList();
      }

      // Fallback: search all courses
      final allSnap = await _firestore.collection('courses').get();
      final filtered = allSnap.docs
          .map((d) => CourseModel.fromFirestore(d))
          .where((c) => c.year == (crUser.year ?? 1) && c.semester == (crUser.semester ?? 1))
          .toList();

      return filtered;
    } catch (e) {
      AppLogger.w('Failed to query courses for Year ${crUser.year} Sem ${crUser.semester}: $e');
      return [];
    }
  }

  Future<AttendanceSummary> _fetchPersonalAttendance(
    User crUser,
    List<Course> enrolledCourses,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('attendance')
          .where('studentId', isEqualTo: crUser.id)
          .get();

      final records = snapshot.docs.map((doc) {
        final data = {'id': doc.id, ...doc.data()};
        return AttendanceRecordModel.fromJson(data);
      }).toList();

      final Map<String, List<AttendanceRecordModel>> byCourse = {};
      for (final r in records) {
        byCourse.putIfAbsent(r.courseCode.toUpperCase(), () => []).add(r);
      }

      final List<CourseAttendance> courseSummaries = [];

      for (final course in enrolledCourses) {
        final cCode = course.code.toUpperCase();
        final cRecords = byCourse[cCode] ?? [];
        final total = cRecords.length;
        final attended = cRecords.where((r) => r.status.toUpperCase() == 'PRESENT').length;
        final pct = total > 0 ? (attended / total) * 100 : 0.0;

        courseSummaries.add(
          CourseAttendanceModel(
            courseId: course.id,
            courseCode: course.code,
            courseTitle: course.title,
            attendedClasses: attended,
            totalClasses: total,
            percentage: pct,
            isEligible: pct >= 75.0,
          ),
        );
      }

      // Include courses in records not in enrolledCourses
      for (final entry in byCourse.entries) {
        if (!courseSummaries.any((c) => c.courseCode.toUpperCase() == entry.key)) {
          final total = entry.value.length;
          final attended = entry.value.where((r) => r.status.toUpperCase() == 'PRESENT').length;
          final pct = total > 0 ? (attended / total) * 100 : 0.0;
          courseSummaries.add(
            CourseAttendanceModel(
              courseId: entry.key,
              courseCode: entry.key,
              courseTitle: entry.value.first.courseTitle,
              attendedClasses: attended,
              totalClasses: total,
              percentage: pct,
              isEligible: pct >= 75.0,
            ),
          );
        }
      }

      final totalAttended = records.where((r) => r.status.toUpperCase() == 'PRESENT').length;
      final totalSessions = records.length;
      final overallPct = totalSessions > 0 ? (totalAttended / totalSessions) * 100 : 0.0;

      return AttendanceSummary(
        overallPercentage: double.parse(overallPct.toStringAsFixed(1)),
        totalAttended: totalAttended,
        totalSessions: totalSessions,
        courseSummaries: courseSummaries,
        recentRecords: records,
      );
    } catch (e) {
      AppLogger.w('Attendance query failed for CR: $e');
      return AttendanceSummary(
        overallPercentage: 0.0,
        totalAttended: 0,
        totalSessions: 0,
        courseSummaries: enrolledCourses
            .map(
              (c) => CourseAttendanceModel(
                courseId: c.id,
                courseCode: c.code,
                courseTitle: c.title,
                attendedClasses: 0,
                totalClasses: 0,
                percentage: 0.0,
                isEligible: true,
              ),
            )
            .toList(),
        recentRecords: const [],
      );
    }
  }

  Future<List<ScheduleSlot>> _fetchClassesForDay(User crUser, String targetDay) async {
    try {
      final Map<String, ScheduleSlot> slotMap = {};
      final normDay = targetDay.trim().toUpperCase();

      // 1. Query 'schedules' collection
      try {
        final schedulesSnap = await _firestore
            .collection('schedules')
            .where('targetYear', isEqualTo: crUser.year ?? 1)
            .where('targetSemester', isEqualTo: crUser.semester ?? 1)
            .where('dayOfWeek', isEqualTo: normDay)
            .get();

        for (final doc in schedulesSnap.docs) {
          final model = ScheduleSlotModel.fromFirestore(doc);
          final key = model.id.isNotEmpty ? model.id : doc.id;
          slotMap[key] = model;
        }
      } catch (e) {
        AppLogger.w('Failed to query schedules collection for $normDay: $e');
      }

      // 2. Query 'scheduleSlots' collection
      try {
        final slotsSnap = await _firestore
            .collection('scheduleSlots')
            .where('targetYear', isEqualTo: crUser.year ?? 1)
            .where('targetSemester', isEqualTo: crUser.semester ?? 1)
            .where('dayOfWeek', isEqualTo: normDay)
            .get();

        for (final doc in slotsSnap.docs) {
          final model = ScheduleSlotModel.fromFirestore(doc);
          final key = model.id.isNotEmpty ? model.id : doc.id;
          if (!slotMap.containsKey(key)) {
            slotMap[key] = model;
          }
        }
      } catch (e) {
        AppLogger.w('Failed to query scheduleSlots collection for $normDay: $e');
      }

      final results = slotMap.values.toList();
      results.sort((a, b) => a.startTime.compareTo(b.startTime));
      return results;
    } catch (e) {
      AppLogger.w('Failed to query schedule slots for $targetDay: $e');
      return [];
    }
  }

  Future<_CounselingFetchResult> _fetchCounselingInfo(User crUser) async {
    int availableSlotsCount = 0;
    final List<CounselingBooking> myBookings = [];

    try {
      final slotsSnap = await _firestore
          .collection('counselingSlots')
          .where('status', isEqualTo: 'AVAILABLE')
          .get();
      availableSlotsCount = slotsSnap.docs.length;
    } catch (e) {
      AppLogger.w('Counseling slots fetch failed: $e');
    }

    try {
      final bookingsSnap = await _firestore
          .collection('counselingBookings')
          .where('studentId', isEqualTo: crUser.id)
          .get();

      for (final doc in bookingsSnap.docs) {
        myBookings.add(CounselingBookingModel.fromFirestore(doc));
      }
    } catch (e) {
      AppLogger.w('Counseling bookings fetch failed: $e');
    }

    return _CounselingFetchResult(
      availableSlotsCount: availableSlotsCount,
      myBookings: myBookings,
    );
  }

  Future<List<Exam>> _fetchUpcomingExams(User crUser, DateTime now) async {
    try {
      final snap = await _firestore
          .collection('exams')
          .where('year', isEqualTo: crUser.year ?? 1)
          .where('semester', isEqualTo: crUser.semester ?? 1)
          .get();

      final List<Exam> exams = snap.docs.map((d) => ExamModel.fromFirestore(d)).toList();

      exams.sort((a, b) => a.examDate.compareTo(b.examDate));
      return exams;
    } catch (e) {
      AppLogger.w('Failed to query exams for Year ${crUser.year} Sem ${crUser.semester}: $e');
      return [];
    }
  }

  String _dayOfWeekFromWeekday(int weekday) {
    switch (weekday) {
      case DateTime.sunday:
        return 'SUNDAY';
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
      default:
        return 'SUNDAY';
    }
  }
}

class _CounselingFetchResult {
  final int availableSlotsCount;
  final List<CounselingBooking> myBookings;

  const _CounselingFetchResult({
    required this.availableSlotsCount,
    required this.myBookings,
  });
}
