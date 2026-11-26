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
import '../../../../core/utils/class_time.dart';
import '../../../curriculum/data/repositories/class_change_repository.dart';
import '../../../curriculum/domain/entities/class_change.dart';
import '../../../curriculum/domain/services/effective_schedule.dart';
import '../../../attendance/data/services/attendance_totals.dart';
import '../../../../core/network/cache_first.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

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
      final now = currentTime ?? ClassTime.now();
      final bool isTomorrow = now.hour >= 17 || now.hour < 5;
      final String dayOfWeek = _dayOfWeekFromWeekday(now.weekday);
      final DateTime tomorrow = now.add(const Duration(days: 1));
      final String tomorrowDayOfWeek = _dayOfWeekFromWeekday(tomorrow.weekday);

      final String targetDateLabel = DateFormat('EEEE · MMM d, yyyy').format(now);
      final String tomorrowDateLabel = DateFormat('EEEE · MMM d, yyyy').format(tomorrow);

      AppLogger.i(
        'Loading CR Dashboard for ${crUser.fullName} (Year ${crUser.year}, Sem ${crUser.semester}, Day: $dayOfWeek)',
      );

      // 0. Fetch explicit enrollments once (course -> date counted from).
      final Map<String, String?> enrolledSince = await _fetchEnrollments(crUser.id);
      final Set<String> retakeCourseIds = enrolledSince.keys.toSet();

      // 1. Fetch Enrolled Semester + Retake Courses
      final List<Course> enrolledCourses =
          await _fetchEnrolledCourses(crUser, retakeCourseIds: retakeCourseIds);

      // 2. Fetch Personal Attendance & Live Open Sessions (unified with ClassAttendanceService)
      final attendanceSummary = await _fetchPersonalAttendance(
        crUser,
        enrolledCourses,
        retakeCourseIds: retakeCourseIds,
        enrolledSince: enrolledSince,
        now: now,
      );
      final openAttendanceSessions = await _fetchOpenSessions(
        crUser,
        retakeCourseIds: retakeCourseIds,
        now: now,
      );

      // 3. Fetch Classes Today & Tomorrow + holiday info
      final todayHolidayTitle = await _fetchHolidayTitle(now);
      final tomorrowHolidayTitle = await _fetchHolidayTitle(tomorrow);
      final List<ScheduleSlot> todayClasses = await _fetchClassesForDate(
        crUser,
        now,
        dayOfWeek,
        retakeCourseIds: retakeCourseIds,
        holidayTitle: todayHolidayTitle,
      );
      final List<ScheduleSlot> tomorrowClasses = await _fetchClassesForDate(
        crUser,
        tomorrow,
        tomorrowDayOfWeek,
        retakeCourseIds: retakeCourseIds,
        holidayTitle: tomorrowHolidayTitle,
      );

      // 4. Fetch Counseling Info (Available Faculty Slots & My Bookings)
      final counselingInfo = await _fetchCounselingInfo(crUser);

      // 5. Fetch Upcoming Exams for this Year & Semester + Retake Courses
      final List<Exam> upcomingExams = await _fetchUpcomingExams(
        crUser,
        now,
        retakeCourseIds: retakeCourseIds,
      );

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
        classesTodayCount: todayClasses.where((c) => !c.isCancelled).length,
        todayClasses: todayClasses,
        tomorrowClasses: tomorrowClasses,
        availableCounselingSlotsCount: counselingInfo.availableSlotsCount,
        myActiveCounselingCount: counselingInfo.myBookings.length,
        myBookings: counselingInfo.myBookings,
        // Cancelled exams stay listed (struck through) but are not counted.
        upcomingExamsCount: upcomingExams.where((e) => !e.isCancelled).length,
        upcomingExams: upcomingExams,
        enrolledCourses: enrolledCourses,
        targetDateLabel: targetDateLabel,
        dayOfWeek: dayOfWeek,
        tomorrowDateLabel: tomorrowDateLabel,
        isTomorrow: isTomorrow,
        openAttendanceSessions: openAttendanceSessions,
        todayHolidayTitle: todayHolidayTitle,
        tomorrowHolidayTitle: tomorrowHolidayTitle,
      );
    } catch (e, stack) {
      AppLogger.e('Error fetching CR dashboard data', e, stack);
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Could not load the dashboard. ${friendlyError(e)}');
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

      await docRef.set(slotMap);

      AppLogger.i('CR added schedule slot: ${docRef.id} for ${slot.dayOfWeek}');
    } catch (e, stack) {
      AppLogger.e('Failed to add schedule slot', e, stack);
      throw ServerException(message: 'Could not add the class. ${friendlyError(e)}');
    }
  }

  /// The student's explicit enrollments (retakes etc.): courseId → the date
  /// from which classes count ("yyyy-MM-dd": `enrolledOn`, else `createdAt`),
  /// or null when unknown (count every class).
  Future<Map<String, String?>> _fetchEnrollments(String uid) async {
    try {
      final snap = await _firestore
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .get();
      final out = <String, String?>{};
      for (final d in snap.docs) {
        final data = d.data();
        final cid = (data['courseId'] as String? ?? '').trim();
        if (cid.isEmpty) continue;
        out[cid] = enrolledSinceKey(data);
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// "yyyy-MM-dd" from `enrolledOn`, else from `createdAt`, else null.
  static String? enrolledSinceKey(Map<String, dynamic> data) {
    final on = (data['enrolledOn'] as String?)?.trim() ?? '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(on)) return on;
    final created = data['createdAt'];
    if (created is Timestamp) return ClassTime.dateKey(ClassTime.dhaka(created.toDate()));
    if (created is String) {
      final d = DateTime.tryParse(created);
      if (d != null) return ClassTime.dateKey(d);
    }
    return null;
  }

  Future<String?> _fetchHolidayTitle(DateTime date) async {
    try {
      final dateKey = ClassTime.dateKey(date);
      final hDoc = await _firestore.collection('holidays').doc(dateKey).get();
      if (!hDoc.exists) return null;
      return (hDoc.data()?['title'] as String? ?? 'University Holiday').trim();
    } catch (_) {
      return null;
    }
  }

  Future<List<AttendanceSession>> _fetchOpenSessions(
    User crUser, {
    Set<String> retakeCourseIds = const {},
    required DateTime now,
  }) async {
    try {
      final byId = <String, AttendanceSession>{};
      if (crUser.year != null && crUser.semester != null) {
        final semSnap = await _firestore
            .collection('attendanceSessions')
            .where('targetYear', isEqualTo: crUser.year)
            .where('targetSemester', isEqualTo: crUser.semester)
            .where('isActive', isEqualTo: true)
            .get();
        for (final d in semSnap.docs) {
          final s = AttendanceSessionModel.fromFirestore(d);
          if (!s.isManualMode && (s.expiresAt?.isAfter(ClassTime.instant()) ?? false)) {
            byId[s.id] = s;
          }
        }
      }
      if (retakeCourseIds.isNotEmpty) {
        final list = retakeCourseIds.toList();
        for (var i = 0; i < list.length; i += 10) {
          final chunk = list.skip(i).take(10).toList();
          final rSnap = await _firestore
              .collection('attendanceSessions')
              .where('courseId', whereIn: chunk)
              .where('isActive', isEqualTo: true)
              .get();
          for (final d in rSnap.docs) {
            final s = AttendanceSessionModel.fromFirestore(d);
            if (!s.isManualMode && (s.expiresAt?.isAfter(ClassTime.instant()) ?? false)) {
              byId[s.id] = s;
            }
          }
        }
      }
      final list = byId.values.toList()
        ..sort((a, b) => (a.expiresAt ?? ClassTime.instant()).compareTo(b.expiresAt ?? ClassTime.instant()));
      return list;
    } catch (e) {
      AppLogger.w('Failed to load open attendance sessions for home banner: $e');
      return const [];
    }
  }

  Future<List<Course>> _fetchEnrolledCourses(
    User crUser, {
    Set<String> retakeCourseIds = const {},
  }) async {
    try {
      final byId = <String, Course>{};
      // No semester yet → no semester courses (only explicit enrollments).
      if (crUser.year != null && crUser.semester != null) {
        // Rarely changes: offline copy, server at most every 6 h (S2-11).
        final snap = await CacheFirst.get(
          _firestore
              .collection('courses')
              .where('year', isEqualTo: crUser.year)
              .where('semester', isEqualTo: crUser.semester),
          'courses_${crUser.year}_${crUser.semester}',
        );

        for (final d in snap.docs) {
          final c = CourseModel.fromFirestore(d);
          byId[c.id] = c;
        }

        if (byId.isEmpty) {
          final allSnap = await _firestore.collection('courses').get();
          for (final d in allSnap.docs) {
            final c = CourseModel.fromFirestore(d);
            if (c.year == crUser.year && c.semester == crUser.semester) {
              byId[c.id] = c;
            }
          }
        }
      }

      for (final cid in retakeCourseIds) {
        if (byId.containsKey(cid)) continue;
        try {
          final cDoc = await _firestore.collection('courses').doc(cid).get();
          if (cDoc.exists) {
            final c = CourseModel.fromFirestore(cDoc);
            byId[c.id] = c;
          }
        } catch (_) {}
      }

      return byId.values.toList()..sort((a, b) => a.code.compareTo(b.code));
    } catch (e) {
      AppLogger.w('Failed to query courses for Year ${crUser.year} Sem ${crUser.semester}: $e');
      return [];
    }
  }

  Future<AttendanceSummary> _fetchPersonalAttendance(
    User crUser,
    List<Course> enrolledCourses, {
    Set<String> retakeCourseIds = const {},
    Map<String, String?> enrolledSince = const {},
    required DateTime now,
  }) async {
    try {
      // S2-11 (free plan): a few small records instead of every session and
      // mark of the semester; same numbers as the Attendance screen.
      final summary = await AttendanceTotals(_firestore).summary(
        uid: crUser.id,
        courses: {for (final c in enrolledCourses) c.id: (c.code, c.title)},
        since: enrolledSince,
        today: ClassTime.dateKey(now),
        withRecent: false, // the dashboard doesn't list recent marks
      );
      return AttendanceSummary(
        overallPercentage: double.parse(summary.overallPercentage.toStringAsFixed(1)),
        totalAttended: summary.totalAttended,
        totalSessions: summary.totalSessions,
        courseSummaries: summary.courseSummaries,
        recentRecords: summary.recentRecords,
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

  /// Effective classes for [date]: the routine for that weekday plus the
  /// batch's one-day changes for that exact date, respecting holidays.
  Future<List<ScheduleSlot>> _fetchClassesForDate(
    User crUser,
    DateTime date,
    String targetDay, {
    Set<String> retakeCourseIds = const {},
    String? holidayTitle,
  }) async {
    final dateKey = ClassTime.dateKey(date);

    // On a holiday the routine doesn't run, but an extra class someone
    // deliberately scheduled that day still does.
    final routine = holidayTitle != null
        ? const <ScheduleSlot>[]
        : await _fetchClassesForDay(crUser, targetDay, retakeCourseIds: retakeCourseIds);

    final byId = <String, ClassChange>{};
    if (crUser.year != null && crUser.semester != null) {
      try {
        final snap = await _firestore
            .collection('classChanges')
            .where('targetYear', isEqualTo: crUser.year)
            .where('targetSemester', isEqualTo: crUser.semester)
            .where('date', isEqualTo: dateKey)
            .get();
        for (final d in snap.docs) {
          final c = ClassChangeRepositoryImpl.fromDoc(d);
          byId[c.id] = c;
        }
      } catch (e) {
        AppLogger.w('Failed to load class changes for $dateKey: $e');
      }
    }
    // Retake courses belong to another semester: load their changes too.
    if (retakeCourseIds.isNotEmpty) {
      final list = retakeCourseIds.toList();
      for (var i = 0; i < list.length; i += 10) {
        final chunk = list.skip(i).take(10).toList();
        try {
          final snap = await _firestore
              .collection('classChanges')
              .where('courseId', whereIn: chunk)
              .where('date', isEqualTo: dateKey)
              .get();
          for (final d in snap.docs) {
            final c = ClassChangeRepositoryImpl.fromDoc(d);
            byId.putIfAbsent(c.id, () => c);
          }
        } catch (e) {
          AppLogger.w('Failed to load retake class changes for $dateKey: $e');
        }
      }
    }
    var changes = byId.values.toList();
    if (holidayTitle != null) {
      changes = changes.where((c) => c.type == ClassChangeType.extra).toList();
    }
    return EffectiveSchedule.forDate(routine: routine, changes: changes, date: date);
  }

  Future<List<ScheduleSlot>> _fetchClassesForDay(
    User crUser,
    String targetDay, {
    Set<String> retakeCourseIds = const {},
  }) async {
    try {
      final Map<String, ScheduleSlot> slotMap = {};
      final normDay = targetDay.trim().toUpperCase();

      // 1. Query 'schedules' collection for semester cohort
      try {
        if (crUser.year == null || crUser.semester == null) throw StateError('no semester');
        // The weekly routine rarely changes: offline copy first (S2-11).
        // One-day changes are always read live (below).
        final schedulesSnap = await CacheFirst.get(
          _firestore
              .collection('schedules')
              .where('targetYear', isEqualTo: crUser.year)
              .where('targetSemester', isEqualTo: crUser.semester)
              .where('dayOfWeek', isEqualTo: normDay),
          'routine_${crUser.year}_${crUser.semester}_$normDay',
        );

        for (final doc in schedulesSnap.docs) {
          final model = ScheduleSlotModel.fromFirestore(doc);
          final key = model.id.isNotEmpty ? model.id : doc.id;
          slotMap[key] = model;
        }
      } catch (e) {
        AppLogger.w('Failed to query schedules collection for $normDay: $e');
      }

      // 2. Merge schedules for explicitly enrolled retake courses
      if (retakeCourseIds.isNotEmpty) {
        final list = retakeCourseIds.toList();
        for (var i = 0; i < list.length; i += 10) {
          final chunk = list.skip(i).take(10).toList();
          try {
            final retakeSnap = await _firestore
                .collection('schedules')
                .where('courseId', whereIn: chunk)
                .where('dayOfWeek', isEqualTo: normDay)
                .get();
            for (final doc in retakeSnap.docs) {
              final model = ScheduleSlotModel.fromFirestore(doc);
              final key = model.id.isNotEmpty ? model.id : doc.id;
              slotMap.putIfAbsent(key, () => model);
            }
          } catch (e) {
            AppLogger.w('Failed to query retake schedules for $normDay: $e');
          }
        }
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
      // S2-11: a count query (1 read per 1,000 slots), not every slot.
      final agg = await _firestore
          .collection('counselingSlots')
          .where('status', isEqualTo: 'AVAILABLE')
          .count()
          .get();
      availableSlotsCount = agg.count ?? 0;
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

  Future<List<Exam>> _fetchUpcomingExams(
    User crUser,
    DateTime now, {
    Set<String> retakeCourseIds = const {},
  }) async {
    try {
      final todayKey = ClassTime.dateKey(now);
      final byId = <String, Exam>{};

      if (crUser.year != null && crUser.semester != null) {
        // Only upcoming exams (S2-11; index year + semester + examDate).
        final snap = await _firestore
            .collection('exams')
            .where('year', isEqualTo: crUser.year)
            .where('semester', isEqualTo: crUser.semester)
            .where('examDate', isGreaterThanOrEqualTo: todayKey)
            .get();

        for (final d in snap.docs) {
          final ex = ExamModel.fromFirestore(d);
          if (ex.examDate.compareTo(todayKey) >= 0) {
            byId[ex.id] = ex;
          }
        }
      }

      if (retakeCourseIds.isNotEmpty) {
        final list = retakeCourseIds.toList();
        for (var i = 0; i < list.length; i += 10) {
          final chunk = list.skip(i).take(10).toList();
          final rSnap = await _firestore
              .collection('exams')
              .where('courseId', whereIn: chunk)
              .get();
          for (final d in rSnap.docs) {
            final ex = ExamModel.fromFirestore(d);
            if (ex.examDate.compareTo(todayKey) >= 0) {
              byId.putIfAbsent(ex.id, () => ex);
            }
          }
        }
      }

      final exams = byId.values.toList()..sort((a, b) => a.examDate.compareTo(b.examDate));
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
