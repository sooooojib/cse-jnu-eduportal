// Private fields can't be named initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/utils/class_time.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/class_change.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/services/effective_schedule.dart';
import '../../domain/services/exam_rules.dart';
import '../models/curriculum_models.dart';
import 'class_change_repository.dart';

/// Extra exam operations that work without Cloud Functions: data for the
/// clash check, known rooms, cancelling, and telling the semester.
abstract class ExamSupportRepository {
  /// All exams on [dateKey] ("yyyy-MM-dd"), every semester.
  Future<List<Exam>> examsOn(String dateKey);

  /// The effective class schedule on [date], every semester.
  Future<List<ScheduleSlot>> classesOn(DateTime date);

  /// Rooms used in the routine and in exams, sorted.
  Future<List<String>> knownRooms();

  /// Cancels (keeps the exam listed, struck through) with a reason.
  Future<void> cancel(Exam exam, {String? reason});

  /// In-app notification to every student of the exam's semester.
  Future<void> notifySemester(Exam exam, {required String title, required String body, required User sender});
}

class ExamSupportRepositoryImpl implements ExamSupportRepository {
  final FirebaseFirestore _firestore;
  final ClassChangeRepository _classes;

  ExamSupportRepositoryImpl({required FirebaseFirestore firestore, required ClassChangeRepository classes})
      : _firestore = firestore,
        _classes = classes;

  @override
  Future<List<Exam>> examsOn(String dateKey) async {
    try {
      final snap = await _firestore.collection('exams').where('examDate', isEqualTo: dateKey).get();
      return snap.docs.map(ExamModel.fromFirestore).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<ScheduleSlot>> classesOn(DateTime date) async {
    final routine = await _classes.routineForDay(ClassTime.dayOfWeek(date));
    List<ClassChange> changes = const [];
    try {
      changes = await _classes.changesOn(date);
    } catch (_) {}
    return EffectiveSchedule.forDate(routine: routine, changes: changes, date: date);
  }

  @override
  Future<List<String>> knownRooms() async {
    final rooms = <String>{};
    Future<void> add(String collection) async {
      try {
        final snap = await _firestore.collection(collection).get();
        for (final d in snap.docs) {
          final r = (d.data()['room'] as String?)?.trim() ?? '';
          if (r.isNotEmpty) rooms.add(r);
        }
      } catch (_) {}
    }

    await Future.wait([add('schedules'), add('exams')]);
    return rooms.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  Future<void> cancel(Exam exam, {String? reason}) async {
    try {
      await _firestore.collection('exams').doc(exam.id).update({
        'status': 'CANCELLED',
        'statusNote': (reason ?? '').trim().isEmpty ? null : reason!.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> notifySemester(Exam exam, {required String title, required String body, required User sender}) async {
    // One notification per student; failures are ignored (the exam is
    // already saved and visible in the Exam Schedule).
    try {
      final snap = await _firestore
          .collection('users')
          .where('year', isEqualTo: exam.year)
          .where('semester', isEqualTo: exam.semester)
          .get();
      final recipients = snap.docs.where((d) {
        final role = (d.data()['role'] as String? ?? '').toUpperCase();
        return d.id != sender.id && (role == 'STUDENT' || role == 'CR');
      });
      await Future.wait(recipients.map((d) => _firestore.collection('notifications').add({
            'userId': d.id,
            'senderId': sender.id,
            'title': title,
            'body': body,
            'notificationType': 'EXAM_UPDATE',
            'referenceType': 'EXAM',
            'referenceId': exam.id,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          }).then((_) {}, onError: (_) {})));
    } catch (_) {}
  }

  /// Message for a new / changed / cancelled exam.
  static (String, String) message(Exam exam, {required String kind}) {
    final name = exam.courseTitle.isNotEmpty ? exam.courseTitle : exam.courseCode;
    final type = ExamTypes.label(exam.type);
    final when = '${exam.examDate}, ${ClassTime.normalize(exam.startTime)}–${ClassTime.normalize(exam.endTime)}, ${exam.room}';
    return switch (kind) {
      'cancel' => ('$type cancelled: $name',
          'The $type on ${exam.examDate} is cancelled.${(exam.statusNote ?? '').isNotEmpty ? ' ${exam.statusNote}' : ''}'),
      'change' => ('$type changed: $name', 'Now on $when.'),
      _ => ('New $type: $name', '$when.'),
    };
  }
}
