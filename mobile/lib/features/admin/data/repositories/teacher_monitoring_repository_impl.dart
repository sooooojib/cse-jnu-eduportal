import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/error_handler.dart';
import '../../../attendance/data/models/attendance_models.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../curriculum/data/models/curriculum_models.dart';
import '../../../curriculum/data/repositories/class_change_repository.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../domain/entities/teacher_monitoring.dart';
import '../../domain/repositories/teacher_monitoring_repository.dart';
import '../../domain/services/teacher_monitoring_calculator.dart';

class TeacherMonitoringRepositoryImpl implements TeacherMonitoringRepository {
  final FirebaseFirestore _firestore;

  TeacherMonitoringRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<TeacherMonitoringReport> loadReport({DateTime? periodStart}) async {
    try {
      final results = await Future.wait([
        _firestore.collection('users').get(),
        _firestore.collection('courses').get(),
        _firestore.collection('courseAssignments').get(),
        // S2-11: only the chosen period's sessions when one is set.
        (periodStart == null
                ? _firestore.collection('attendanceSessions')
                : _firestore.collection('attendanceSessions').where('sessionDate', isGreaterThanOrEqualTo: _key(periodStart)))
            .get(),
        _firestore.collection('schedules').get(),
      ]);
      final changeDocs = await _classChangeDocs();
      final retakes = await _retakeStudents();
      final holidayDates = await _holidayDates();

      final users = results[0].docs.map((d) => UserModel.fromFirestore(d)).toList();
      final courses = results[1].docs.map((d) => CourseModel.fromFirestore(d)).toList();
      final assignments = results[2].docs.map((d) => CourseAssignmentModel.fromFirestore(d)).toList();
      final sessions = results[3].docs.map((d) => AttendanceSessionModel.fromFirestore(d)).toList();

      // Routine lives exclusively in `schedules` (authoritative).
      final slots = results[4].docs
          .map<ScheduleSlot>((d) => ScheduleSlotModel.fromJson({'id': d.id, ...d.data()}))
          .toList();

      return TeacherMonitoringCalculator.build(
        users: users,
        courses: courses,
        assignments: assignments,
        sessions: sessions,
        routineSlots: slots,
        classChanges: changeDocs.map(ClassChangeRepositoryImpl.fromDoc).toList(),
        holidayDates: holidayDates,
        retakeStudents: retakes,
        periodStart: periodStart,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// courseId -> students retaking it (optional input; ignore failures).
  Future<Map<String, Set<String>>> _retakeStudents() async {
    try {
      final snap = await _firestore.collection('enrollments').where('type', isEqualTo: 'RETAKE').get();
      final out = <String, Set<String>>{};
      for (final d in snap.docs) {
        final c = d.data()['courseId'] as String? ?? '';
        final s = d.data()['studentId'] as String? ?? '';
        if (c.isNotEmpty && s.isNotEmpty) out.putIfAbsent(c, () => <String>{}).add(s);
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// One-day class changes are optional input; ignore failures.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _classChangeDocs() async {
    try {
      return (await _firestore.collection('classChanges').get()).docs;
    } catch (_) {
      return const [];
    }
  }

  /// Official holiday dates (`yyyy-MM-dd`); optional input, ignore failures.
  Future<Set<String>> _holidayDates() async {
    try {
      final snap = await _firestore.collection('holidays').get();
      return snap.docs.map((d) => (d.data()['date'] as String?) ?? d.id).toSet();
    } catch (_) {
      return const {};
    }
  }
}
