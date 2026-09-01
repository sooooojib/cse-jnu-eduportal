import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../models/curriculum_models.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/repositories/curriculum_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class CurriculumRemoteDataSource {
  Future<List<CourseModel>> getMyCourses();
  Future<List<ScheduleSlotModel>> getSchedule({String? day});
  Future<List<ExamModel>> getExams();
}

class CurriculumRemoteDataSourceImpl implements CurriculumRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  CurriculumRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  Future<Map<String, dynamic>> _getUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: "Not authenticated.");
    final doc = await _firestore.collection("users").doc(uid).get();
    return doc.data() ?? {};
  }

  @override
  Future<List<CourseModel>> getMyCourses() async {
    final profile = await _getUserProfile();
    final year = profile["year"] as int?;
    final semester = profile["semester"] as int?;

    Query query = _firestore.collection("courses");
    if (year != null) query = query.where("year", isEqualTo: year);
    if (semester != null) query = query.where("semester", isEqualTo: semester);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return CourseModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
    }).toList();
  }

  @override
  Future<List<ScheduleSlotModel>> getSchedule({String? day}) async {
    final profile = await _getUserProfile();
    final year = profile["year"] as int?;
    final semester = profile["semester"] as int?;

    Query query = _firestore.collection("schedules");
    if (year != null) query = query.where("targetYear", isEqualTo: year);
    if (semester != null) query = query.where("targetSemester", isEqualTo: semester);
    if (day != null) query = query.where("dayOfWeek", isEqualTo: day.toUpperCase());

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return ScheduleSlotModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
    }).toList();
  }

  @override
  Future<List<ExamModel>> getExams() async {
    final profile = await _getUserProfile();
    final year = profile["year"] as int?;
    final semester = profile["semester"] as int?;

    Query query = _firestore.collection("exams");
    if (year != null) query = query.where("year", isEqualTo: year);
    if (semester != null) query = query.where("semester", isEqualTo: semester);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return ExamModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
    }).toList();
  }
}

// ─── Repository ──────────────────────────────────────────────────────────────

class CurriculumRepositoryImpl implements CurriculumRepository {
  final CurriculumRemoteDataSource remoteDataSource;

  CurriculumRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Course>> getMyCourses() async {
    try {
      final list = await remoteDataSource.getMyCourses();
      return List<Course>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<ScheduleSlot>> getSchedule({String? day}) async {
    try {
      final list = await remoteDataSource.getSchedule(day: day);
      return List<ScheduleSlot>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<Exam>> getExams() async {
    try {
      final list = await remoteDataSource.getExams();
      return List<Exam>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
