import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/utils/class_time.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/class_change.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../models/curriculum_models.dart';

/// One-day class changes (`classChanges`) plus the routine reads needed to
/// build the effective schedule and run clash checks.
abstract class ClassChangeRepository {
  /// Weekly routine slots for [dayOfWeek] across all batches.
  Future<List<ScheduleSlot>> routineForDay(String dayOfWeek);

  /// Changes on [date] across all batches.
  Future<List<ClassChange>> changesOn(DateTime date);

  /// Changes from [from] to [to] (inclusive) for one batch.
  Future<List<ClassChange>> changesForBatch({required int year, required int semester, required DateTime from, required DateTime to});

  /// Changes from [from] to [to] (inclusive) for the given courses.
  Future<List<ClassChange>> changesForCourses({required Set<String> courseIds, required DateTime from, required DateTime to});

  /// Courses a user may plan for: the CR's own semester, or a teacher's own courses.
  Future<List<Course>> plannableCourses(User user);

  Future<void> create(ClassChange change);
  Future<void> undo(String changeId);
}

class ClassChangeRepositoryImpl implements ClassChangeRepository {
  final FirebaseFirestore _firestore;

  ClassChangeRepositoryImpl({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _changes => _firestore.collection('classChanges');

  static ClassChange fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    String s(String k) => (d[k] as String?) ?? '';
    return ClassChange(
      id: doc.id,
      type: ClassChangeType.fromString(d['type'] as String?),
      date: s('date'),
      dayOfWeek: s('dayOfWeek'),
      courseId: s('courseId'),
      courseCode: s('courseCode'),
      courseTitle: s('courseTitle'),
      teacherId: s('teacherId'),
      teacherName: s('teacherName'),
      targetYear: (d['targetYear'] as num?)?.toInt() ?? 0,
      targetSemester: (d['targetSemester'] as num?)?.toInt() ?? 0,
      startTime: s('startTime'),
      endTime: s('endTime'),
      room: s('room'),
      originalSlotId: d['originalSlotId'] as String?,
      originalStartTime: d['originalStartTime'] as String?,
      originalRoom: d['originalRoom'] as String?,
      reason: d['reason'] as String?,
      createdBy: s('createdBy'),
      createdByName: s('createdByName'),
      createdByRole: s('createdByRole'),
    );
  }

  @override
  Future<List<ScheduleSlot>> routineForDay(String dayOfWeek) async {
    try {
      final day = dayOfWeek.toUpperCase();
      final byId = <String, ScheduleSlot>{};
      final main = await _firestore.collection('schedules').where('dayOfWeek', isEqualTo: day).get();
      for (final d in main.docs) {
        byId[d.id] = ScheduleSlotModel.fromJson({'id': d.id, ...d.data()});
      }
      try {
        final legacy = await _firestore.collection('scheduleSlots').where('dayOfWeek', isEqualTo: day).get();
        for (final d in legacy.docs) {
          byId.putIfAbsent(d.id, () => ScheduleSlotModel.fromJson({'id': d.id, ...d.data()}));
        }
      } catch (_) {}
      return byId.values.toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ClassChange>> changesOn(DateTime date) async {
    try {
      final snap = await _changes.where('date', isEqualTo: ClassTime.dateKey(date)).get();
      return snap.docs.map(fromDoc).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  bool _inRange(ClassChange c, DateTime from, DateTime to) =>
      c.date.compareTo(ClassTime.dateKey(from)) >= 0 && c.date.compareTo(ClassTime.dateKey(to)) <= 0;

  @override
  Future<List<ClassChange>> changesForBatch({
    required int year,
    required int semester,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      // Equality filters only (no composite index needed); date range in memory.
      final snap = await _changes
          .where('targetYear', isEqualTo: year)
          .where('targetSemester', isEqualTo: semester)
          .get();
      final list = snap.docs.map(fromDoc).where((c) => _inRange(c, from, to)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ClassChange>> changesForCourses({
    required Set<String> courseIds,
    required DateTime from,
    required DateTime to,
  }) async {
    if (courseIds.isEmpty) return const [];
    try {
      final out = <ClassChange>[];
      final ids = courseIds.toList();
      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final snap = await _changes.where('courseId', whereIn: chunk).get();
        out.addAll(snap.docs.map(fromDoc).where((c) => _inRange(c, from, to)));
      }
      out.sort((a, b) => a.date.compareTo(b.date));
      return out;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<Course>> plannableCourses(User user) async {
    try {
      if (user.role.hasTeacherAccess) {
        final byId = <String, Course>{};
        final owned = await _firestore.collection('courses').where('teacherId', isEqualTo: user.id).get();
        for (final d in owned.docs) {
          byId[d.id] = CourseModel.fromFirestore(d);
        }
        final assigned = user.assignedCourseIds.where((id) => !byId.containsKey(id)).toList();
        for (var i = 0; i < assigned.length; i += 10) {
          final chunk = assigned.sublist(i, i + 10 > assigned.length ? assigned.length : i + 10);
          final snap = await _firestore.collection('courses').where(FieldPath.documentId, whereIn: chunk).get();
          for (final d in snap.docs) {
            byId[d.id] = CourseModel.fromFirestore(d);
          }
        }
        return byId.values.toList()..sort((a, b) => a.code.compareTo(b.code));
      }
      final snap = await _firestore
          .collection('courses')
          .where('year', isEqualTo: user.year)
          .where('semester', isEqualTo: user.semester)
          .get();
      return snap.docs.map(CourseModel.fromFirestore).toList()..sort((a, b) => a.code.compareTo(b.code));
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> create(ClassChange c) async {
    try {
      final date = DateTime.parse(c.date);
      await _changes.add({
        'type': c.type.value,
        'date': c.date,
        // Midday of the class date, used by security rules for the 7-day window.
        'dateTs': Timestamp.fromDate(DateTime(date.year, date.month, date.day, 12)),
        'dayOfWeek': c.dayOfWeek,
        'courseId': c.courseId,
        'courseCode': c.courseCode,
        'courseTitle': c.courseTitle,
        'teacherId': c.teacherId,
        'teacherName': c.teacherName,
        'targetYear': c.targetYear,
        'targetSemester': c.targetSemester,
        'startTime': c.startTime,
        'endTime': c.endTime,
        'room': c.room,
        if (c.originalSlotId != null) 'originalSlotId': c.originalSlotId,
        if (c.originalStartTime != null) 'originalStartTime': c.originalStartTime,
        if (c.originalRoom != null) 'originalRoom': c.originalRoom,
        if (c.reason != null && c.reason!.trim().isNotEmpty) 'reason': c.reason!.trim(),
        'createdBy': c.createdBy,
        'createdByName': c.createdByName,
        'createdByRole': c.createdByRole,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> undo(String changeId) async {
    try {
      await _changes.doc(changeId).delete();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
