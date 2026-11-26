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
        _firestore.collection('attendanceSessions').get(),
        _firestore.collection('schedules').get(),
      ]);
      final legacySlotDocs = await _legacySlotDocs();
      final changeDocs = await _classChangeDocs();

      final users = results[0].docs.map((d) => UserModel.fromFirestore(d)).toList();
      final courses = results[1].docs.map((d) => CourseModel.fromFirestore(d)).toList();
      final assignments = results[2].docs.map((d) => CourseAssignmentModel.fromFirestore(d)).toList();
      final sessions = results[3].docs.map((d) => AttendanceSessionModel.fromFirestore(d)).toList();

      // Routine lives in `schedules` (authoritative); `scheduleSlots` may hold
      // legacy duplicates with the same id.
      final slotsById = <String, ScheduleSlot>{};
      for (final d in results[4].docs) {
        slotsById[d.id] = ScheduleSlotModel.fromJson({'id': d.id, ...d.data()});
      }
      for (final d in legacySlotDocs) {
        slotsById.putIfAbsent(d.id, () => ScheduleSlotModel.fromJson({'id': d.id, ...d.data()}));
      }

      return TeacherMonitoringCalculator.build(
        users: users,
        courses: courses,
        assignments: assignments,
        sessions: sessions,
        routineSlots: slotsById.values.toList(),
        classChanges: changeDocs.map(ClassChangeRepositoryImpl.fromDoc).toList(),
        periodStart: periodStart,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
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

  /// Legacy `scheduleSlots` collection is optional; ignore failures.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _legacySlotDocs() async {
    try {
      return (await _firestore.collection('scheduleSlots').get()).docs;
    } catch (_) {
      return const [];
    }
  }
}
