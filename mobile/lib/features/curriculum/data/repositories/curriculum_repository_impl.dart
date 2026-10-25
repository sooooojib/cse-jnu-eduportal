import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/config/env_config.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/curriculum_models.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/repositories/curriculum_repository.dart';

// ─── DataSource ───────────────────────────────────────────────────────────────

abstract class CurriculumRemoteDataSource {
  Future<List<CourseModel>> getMyCourses();
  Future<List<ScheduleSlotModel>> getSchedule({String? day, int? year, int? semester, String? teacherId});
  Future<ScheduleSlotModel> createScheduleSlot(ScheduleSlotModel slot);
  Future<ScheduleSlotModel> updateScheduleSlot(ScheduleSlotModel slot);
  Future<void> deleteScheduleSlot(String slotId);
  Future<TeacherAvailabilityModel> getTeacherAvailability({required String teacherId, required String dayOfWeek, String? date});
  Future<WhatsAppBroadcastDataModel> getWhatsAppBroadcast({int? year, int? semester});
  Future<List<CourseModel>> getAllCourses({int? year, int? semester});
  Future<List<Map<String, String>>> getAllTeachers();
  Future<List<ExamModel>> getExams({int? year, int? semester, String? courseId});
  Future<ExamModel> createExam(ExamModel exam);
  Future<ExamModel> updateExam(ExamModel exam);
  Future<void> deleteExam(String examId);
  Future<List<CourseAssignmentModel>> getCourseAssignments({String? courseId, String? teacherId});
  Future<List<EnrollmentModel>> getEnrollments({int? year, int? semester, String? studentId});
}

class CurriculumRemoteDataSourceImpl implements CurriculumRemoteDataSource {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CurriculumRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>> _getUserProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};
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
  Future<List<ScheduleSlotModel>> getSchedule({
    String? day,
    int? year,
    int? semester,
    String? teacherId,
  }) async {
    Query query = _firestore.collection("schedules");

    if (year != null && semester != null) {
      query = query.where("targetYear", isEqualTo: year).where("targetSemester", isEqualTo: semester);
    } else if (teacherId != null && teacherId.isNotEmpty) {
      query = query.where("teacherId", isEqualTo: teacherId);
    } else {
      final profile = await _getUserProfile();
      final pYear = profile["year"] as int?;
      final pSemester = profile["semester"] as int?;
      final role = (profile["role"] as String?)?.toUpperCase();
      final uid = _auth.currentUser?.uid;

      if (role == "TEACHER" && uid != null) {
        query = query.where("teacherId", isEqualTo: uid);
      } else if (pYear != null && pSemester != null) {
        query = query.where("targetYear", isEqualTo: pYear).where("targetSemester", isEqualTo: pSemester);
      }
    }

    if (day != null && day.toUpperCase() != "ALL") {
      query = query.where("dayOfWeek", isEqualTo: day.toUpperCase());
    }

    final snapshot = await query.get();
    final Map<String, ScheduleSlotModel> map = {};
    for (final doc in snapshot.docs) {
      final m = ScheduleSlotModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
      map[m.id] = m;
    }

    // Also check scheduleSlots collection to merge any slots added directly there
    try {
      Query slotsQuery = _firestore.collection("scheduleSlots");
      if (year != null && semester != null) {
        slotsQuery = slotsQuery.where("targetYear", isEqualTo: year).where("targetSemester", isEqualTo: semester);
      } else if (teacherId != null && teacherId.isNotEmpty) {
        slotsQuery = slotsQuery.where("teacherId", isEqualTo: teacherId);
      }
      if (day != null && day.toUpperCase() != "ALL") {
        slotsQuery = slotsQuery.where("dayOfWeek", isEqualTo: day.toUpperCase());
      }
      final slotsSnap = await slotsQuery.get();
      for (final doc in slotsSnap.docs) {
        final m = ScheduleSlotModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
        if (!map.containsKey(m.id)) {
          map[m.id] = m;
        }
      }
    } catch (_) {}

    final list = map.values.toList();
    // Sort chronologically by startTime
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  @override
  Future<ScheduleSlotModel> createScheduleSlot(ScheduleSlotModel slot) async {
    // Call server-side Cloud Function first for authoritative validation
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('createScheduleSlot');
        final result = await callable.call({
          'courseId': slot.courseId,
          'teacherId': slot.teacherId,
          'dayOfWeek': slot.dayOfWeek,
          'startTime': slot.startTime,
          'endTime': slot.endTime,
          'room': slot.room,
          'targetYear': slot.targetYear,
          'targetSemester': slot.targetSemester,
          'isExtraClass': slot.isExtraClass,
          if (slot.date != null) 'date': slot.date,
        });

        final data = result.data;
        if (data is Map && data['slot'] != null) {
          final slotMap = Map<String, dynamic>.from(data['slot'] as Map);
          return ScheduleSlotModel.fromJson(slotMap);
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'already-exists' || e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? e.code);
        }
        AppLogger.w('createScheduleSlot callable note: $e. Falling back to direct Firestore creation.');
      } catch (e) {
        AppLogger.w('createScheduleSlot error: $e. Falling back to direct Firestore creation.');
      }
    }

    // Direct atomic write to both 'schedules' and 'scheduleSlots'
    final docRef = _firestore.collection('schedules').doc();
    final currentUserId = _auth.currentUser?.uid;
    final data = {
      ...slot.toFirestore(),
      'id': docRef.id,
      if (slot.createdBy != null)
        'createdBy': slot.createdBy
      else if (currentUserId != null)
        'createdBy': currentUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _firestore.batch();
    batch.set(docRef, data);
    batch.set(_firestore.collection('scheduleSlots').doc(docRef.id), data);
    await batch.commit();
    return ScheduleSlotModel.fromJson({...slot.toJson(), 'id': docRef.id});
  }

  @override
  Future<ScheduleSlotModel> updateScheduleSlot(ScheduleSlotModel slot) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('updateScheduleSlot');
        final result = await callable.call({
          'slotId': slot.id,
          'courseId': slot.courseId,
          'teacherId': slot.teacherId,
          'dayOfWeek': slot.dayOfWeek,
          'startTime': slot.startTime,
          'endTime': slot.endTime,
          'room': slot.room,
          'targetYear': slot.targetYear,
          'targetSemester': slot.targetSemester,
          'isExtraClass': slot.isExtraClass,
          if (slot.date != null) 'date': slot.date,
        });

        final data = result.data;
        if (data is Map && data['slot'] != null) {
          final slotMap = Map<String, dynamic>.from(data['slot'] as Map);
          return ScheduleSlotModel.fromJson(slotMap);
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'already-exists' || e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? e.code);
        }
        AppLogger.w('updateScheduleSlot callable note: $e. Falling back to direct Firestore update.');
      } catch (e) {
        AppLogger.w('updateScheduleSlot error: $e. Falling back to direct Firestore update.');
      }
    }

    final currentUserId = _auth.currentUser?.uid;
    final data = {
      ...slot.toFirestore(),
      'id': slot.id,
      if (currentUserId != null) 'updatedBy': currentUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _firestore.batch();
    batch.set(_firestore.collection('schedules').doc(slot.id), data, SetOptions(merge: true));
    batch.set(_firestore.collection('scheduleSlots').doc(slot.id), data, SetOptions(merge: true));
    await batch.commit();
    return slot;
  }

  @override
  Future<void> deleteScheduleSlot(String slotId) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('deleteScheduleSlot');
        await callable.call({'slotId': slotId});
        return;
      } catch (e) {
        AppLogger.w('deleteScheduleSlot callable note: $e. Falling back to direct Firestore delete.');
      }
    }

    final batch = _firestore.batch();
    batch.delete(_firestore.collection('schedules').doc(slotId));
    batch.delete(_firestore.collection('scheduleSlots').doc(slotId));
    await batch.commit();
  }

  @override
  Future<TeacherAvailabilityModel> getTeacherAvailability({
    required String teacherId,
    required String dayOfWeek,
    String? date,
  }) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('getTeacherAvailability');
        final result = await callable.call({
          'teacherId': teacherId,
          'dayOfWeek': dayOfWeek,
          if (date != null) 'date': date,
        });

        final data = Map<String, dynamic>.from(result.data as Map);
        return TeacherAvailabilityModel.fromJson(data);
      } catch (e) {
        AppLogger.w('getTeacherAvailability callable note: $e. Using local availability windows.');
      }
    }

    try {
      final snap = await _firestore.collection('schedules')
          .where('teacherId', isEqualTo: teacherId)
          .where('dayOfWeek', isEqualTo: dayOfWeek)
          .get();

      final busy = snap.docs.map((d) {
        final data = d.data();
        return TeacherAvailabilitySlot(
          startTime: data['startTime'] as String? ?? '',
          endTime: data['endTime'] as String? ?? '',
          courseCode: data['courseCode'] as String? ?? '',
          room: data['room'] as String? ?? '',
        );
      }).toList();

      final teacherDoc = await _firestore.collection('users').doc(teacherId).get();
      final teacherName = teacherDoc.data()?['fullName'] as String? ?? '';

      return TeacherAvailabilityModel(
        teacherId: teacherId,
        teacherName: teacherName,
        dayOfWeek: dayOfWeek,
        busySlots: busy,
        freeWindows: const [
          TeacherAvailabilityWindow(
            startTime: '08:00 AM',
            endTime: '05:00 PM',
            durationMinutes: 540,
          ),
        ],
      );
    } catch (_) {
      return TeacherAvailabilityModel(
        teacherId: teacherId,
        teacherName: '',
        dayOfWeek: dayOfWeek,
        busySlots: const [],
        freeWindows: const [
          TeacherAvailabilityWindow(
            startTime: '08:00 AM',
            endTime: '05:00 PM',
            durationMinutes: 540,
          ),
        ],
      );
    }
  }

  @override
  Future<WhatsAppBroadcastDataModel> getWhatsAppBroadcast({int? year, int? semester}) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('getWhatsAppBroadcast');
        final result = await callable.call({
          if (year != null) 'year': year,
          if (semester != null) 'semester': semester,
        });

        final data = Map<String, dynamic>.from(result.data as Map);
        return WhatsAppBroadcastDataModel.fromJson(data);
      } catch (e) {
        AppLogger.w('getWhatsAppBroadcast callable note: $e. Using default broadcast message.');
      }
    }

    try {
      final now = DateTime.now();
      final days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
      final todayDay = days[now.weekday - 1];

      Query query = _firestore.collection('schedules').where('dayOfWeek', isEqualTo: todayDay);
      if (year != null) query = query.where('targetYear', isEqualTo: year);
      if (semester != null) query = query.where('targetSemester', isEqualTo: semester);

      final snap = await query.get();
      final slots = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

      final buffer = StringBuffer('*Department of Computer Science & Engineering, JnU*\n');
      buffer.writeln('*Class Routine Notice*\n');
      buffer.writeln('*Date:* $todayDay');
      buffer.writeln('────────────────────────────────────────');
      if (slots.isEmpty) {
        buffer.writeln('Notice: There are no classes scheduled for today ($todayDay).');
      } else {
        buffer.writeln('*Scheduled Classes:*\n');
        for (int i = 0; i < slots.length; i++) {
          final s = slots[i];
          buffer.writeln('${i + 1}. *${s['courseCode'] ?? s['courseTitle'] ?? 'Class'}*');
          buffer.writeln('   Time: ${s['startTime']} - ${s['endTime']}');
          buffer.writeln('   Room: ${s['room'] ?? 'N/A'}');
          if (s['teacherName'] != null && (s['teacherName'] as String).isNotEmpty) {
            buffer.writeln('   Faculty: ${s['teacherName']}');
          }
          if (i < slots.length - 1) buffer.writeln('');
        }
      }
      final text = buffer.toString();
      final encoded = Uri.encodeComponent(text);

      return WhatsAppBroadcastDataModel(
        date: now.toIso8601String().substring(0, 10),
        dayOfWeek: todayDay,
        slotCount: slots.length,
        broadcastText: text,
        whatsappUrl: 'https://wa.me/?text=$encoded',
      );
    } catch (_) {
      return const WhatsAppBroadcastDataModel(
        date: '',
        dayOfWeek: '',
        slotCount: 0,
        broadcastText: 'No schedule available for broadcast.',
        whatsappUrl: '',
      );
    }
  }

  @override
  Future<List<CourseModel>> getAllCourses({int? year, int? semester}) async {
    Query query = _firestore.collection("courses");
    if (year != null) query = query.where("year", isEqualTo: year);
    if (semester != null) query = query.where("semester", isEqualTo: semester);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return CourseModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
    }).toList();
  }

  @override
  Future<List<Map<String, String>>> getAllTeachers() async {
    try {
      final snap = await _firestore.collection("users").get();
      final teachers = <Map<String, String>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final role = (data['role'] as String?)?.toUpperCase();
        if (role == 'TEACHER') {
          final name = data['name'] as String? ?? data['fullName'] as String? ?? doc.id;
          teachers.add({'id': doc.id, 'name': name});
        }
      }
      return teachers;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<ExamModel>> getExams({int? year, int? semester, String? courseId}) async {
    final profile = await _getUserProfile();
    final effectiveYear = year ?? profile["year"] as int?;
    final effectiveSemester = semester ?? profile["semester"] as int?;

    Query query = _firestore.collection("exams");
    if (effectiveYear != null) query = query.where("year", isEqualTo: effectiveYear);
    if (effectiveSemester != null) query = query.where("semester", isEqualTo: effectiveSemester);
    if (courseId != null) query = query.where("courseId", isEqualTo: courseId);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return ExamModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
    }).toList();
  }

  @override
  Future<ExamModel> createExam(ExamModel exam) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('createExam');
        final result = await callable.call({
          'courseId': exam.courseId,
          'courseCode': exam.courseCode,
          'courseTitle': exam.courseTitle,
          'title': exam.title,
          'examDate': exam.examDate,
          'startTime': exam.startTime,
          'endTime': exam.endTime,
          'room': exam.room,
          'year': exam.year,
          'semester': exam.semester,
          'type': exam.type,
          if (exam.instructions != null) 'instructions': exam.instructions,
          if (exam.invigilatorName != null) 'invigilatorName': exam.invigilatorName,
          if (exam.invigilatorId != null) 'invigilatorId': exam.invigilatorId,
        });

        final data = result.data;
        if (data is Map && data['exam'] != null) {
          final examMap = Map<String, dynamic>.from(data['exam'] as Map);
          return ExamModel.fromJson(examMap);
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'already-exists' || e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? e.code);
        }
        AppLogger.w('createExam callable note: $e. Falling back to direct Firestore creation.');
      } catch (e) {
        AppLogger.w('createExam error: $e. Falling back to direct Firestore creation.');
      }
    }

    final payload = exam.toFirestore();
    if (payload['createdBy'] == null && _auth.currentUser != null) {
      payload['createdBy'] = _auth.currentUser!.uid;
    }
    final docRef = await _firestore.collection('exams').add(payload);
    return exam.copyWith(id: docRef.id);
  }

  @override
  Future<ExamModel> updateExam(ExamModel exam) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('updateExam');
        final result = await callable.call({
          'examId': exam.id,
          'courseId': exam.courseId,
          'courseCode': exam.courseCode,
          'courseTitle': exam.courseTitle,
          'title': exam.title,
          'examDate': exam.examDate,
          'startTime': exam.startTime,
          'endTime': exam.endTime,
          'room': exam.room,
          'year': exam.year,
          'semester': exam.semester,
          'type': exam.type,
          if (exam.instructions != null) 'instructions': exam.instructions,
          if (exam.invigilatorName != null) 'invigilatorName': exam.invigilatorName,
          if (exam.invigilatorId != null) 'invigilatorId': exam.invigilatorId,
        });

        final data = result.data;
        if (data is Map && data['exam'] != null) {
          final examMap = Map<String, dynamic>.from(data['exam'] as Map);
          return ExamModel.fromJson(examMap);
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'already-exists' || e.code == 'failed-precondition') {
          throw ServerException(message: e.message ?? e.code);
        }
        AppLogger.w('updateExam callable note: $e. Falling back to direct Firestore update.');
      } catch (e) {
        AppLogger.w('updateExam error: $e. Falling back to direct Firestore update.');
      }
    }

    await _firestore.collection('exams').doc(exam.id).update(exam.toFirestore());
    return exam;
  }

  @override
  Future<void> deleteExam(String examId) async {
    if (EnvConfig.isCloudFunctionsEnabled) {
      try {
        final callable = _functions.httpsCallable('deleteExam');
        await callable.call({'examId': examId});
        return;
      } catch (e) {
        AppLogger.w('deleteExam callable note: $e. Falling back to direct Firestore delete.');
      }
    }

    await _firestore.collection('exams').doc(examId).delete();
  }

  @override
  Future<List<CourseAssignmentModel>> getCourseAssignments({String? courseId, String? teacherId}) async {
    Query query = _firestore.collection("courseAssignments");
    if (courseId != null) query = query.where("courseId", isEqualTo: courseId);
    if (teacherId != null) query = query.where("teacherId", isEqualTo: teacherId);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return CourseAssignmentModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
    }).toList();
  }

  @override
  Future<List<EnrollmentModel>> getEnrollments({int? year, int? semester, String? studentId}) async {
    Query query = _firestore.collection("enrollments");
    if (year != null) query = query.where("year", isEqualTo: year);
    if (semester != null) query = query.where("semester", isEqualTo: semester);
    if (studentId != null) query = query.where("studentId", isEqualTo: studentId);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      return EnrollmentModel.fromJson({"id": doc.id, ...doc.data() as Map<String, dynamic>});
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
  Future<List<ScheduleSlot>> getSchedule({
    String? day,
    int? year,
    int? semester,
    String? teacherId,
  }) async {
    try {
      final list = await remoteDataSource.getSchedule(
        day: day,
        year: year,
        semester: semester,
        teacherId: teacherId,
      );
      return List<ScheduleSlot>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<ScheduleSlot> createScheduleSlot(ScheduleSlot slot) async {
    try {
      final model = ScheduleSlotModel(
        id: slot.id,
        courseId: slot.courseId,
        courseCode: slot.courseCode,
        courseTitle: slot.courseTitle,
        teacherId: slot.teacherId,
        teacherName: slot.teacherName,
        dayOfWeek: slot.dayOfWeek,
        startTime: slot.startTime,
        endTime: slot.endTime,
        room: slot.room,
        targetYear: slot.targetYear,
        targetSemester: slot.targetSemester,
        isExtraClass: slot.isExtraClass,
        date: slot.date,
        status: slot.status,
        createdBy: slot.createdBy,
      );
      return await remoteDataSource.createScheduleSlot(model);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<ScheduleSlot> updateScheduleSlot(ScheduleSlot slot) async {
    try {
      final model = ScheduleSlotModel(
        id: slot.id,
        courseId: slot.courseId,
        courseCode: slot.courseCode,
        courseTitle: slot.courseTitle,
        teacherId: slot.teacherId,
        teacherName: slot.teacherName,
        dayOfWeek: slot.dayOfWeek,
        startTime: slot.startTime,
        endTime: slot.endTime,
        room: slot.room,
        targetYear: slot.targetYear,
        targetSemester: slot.targetSemester,
        isExtraClass: slot.isExtraClass,
        date: slot.date,
        status: slot.status,
        createdBy: slot.createdBy,
      );
      return await remoteDataSource.updateScheduleSlot(model);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> deleteScheduleSlot(String slotId) async {
    try {
      await remoteDataSource.deleteScheduleSlot(slotId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<TeacherAvailability> getTeacherAvailability({
    required String teacherId,
    required String dayOfWeek,
    String? date,
  }) async {
    try {
      return await remoteDataSource.getTeacherAvailability(
        teacherId: teacherId,
        dayOfWeek: dayOfWeek,
        date: date,
      );
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<WhatsAppBroadcastData> getWhatsAppBroadcast({int? year, int? semester}) async {
    try {
      return await remoteDataSource.getWhatsAppBroadcast(year: year, semester: semester);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<Course>> getAllCourses({int? year, int? semester}) async {
    try {
      final list = await remoteDataSource.getAllCourses(year: year, semester: semester);
      return List<Course>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<Map<String, String>>> getAllTeachers() async {
    try {
      return await remoteDataSource.getAllTeachers();
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<Exam>> getExams({int? year, int? semester, String? courseId}) async {
    try {
      final list = await remoteDataSource.getExams(year: year, semester: semester, courseId: courseId);
      return List<Exam>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<Exam> createExam(Exam exam) async {
    try {
      final model = ExamModel(
        id: exam.id,
        courseId: exam.courseId,
        courseCode: exam.courseCode,
        courseTitle: exam.courseTitle,
        title: exam.title,
        examDate: exam.examDate,
        startTime: exam.startTime,
        endTime: exam.endTime,
        room: exam.room,
        year: exam.year,
        semester: exam.semester,
        type: exam.type,
        instructions: exam.instructions,
        invigilatorName: exam.invigilatorName,
        invigilatorId: exam.invigilatorId,
        createdBy: exam.createdBy,
        creatorRole: exam.creatorRole,
      );
      return await remoteDataSource.createExam(model);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<Exam> updateExam(Exam exam) async {
    try {
      final model = ExamModel(
        id: exam.id,
        courseId: exam.courseId,
        courseCode: exam.courseCode,
        courseTitle: exam.courseTitle,
        title: exam.title,
        examDate: exam.examDate,
        startTime: exam.startTime,
        endTime: exam.endTime,
        room: exam.room,
        year: exam.year,
        semester: exam.semester,
        type: exam.type,
        instructions: exam.instructions,
        invigilatorName: exam.invigilatorName,
        invigilatorId: exam.invigilatorId,
        createdBy: exam.createdBy,
        creatorRole: exam.creatorRole,
      );
      return await remoteDataSource.updateExam(model);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<void> deleteExam(String examId) async {
    try {
      await remoteDataSource.deleteExam(examId);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<CourseAssignment>> getCourseAssignments({String? courseId, String? teacherId}) async {
    try {
      final list = await remoteDataSource.getCourseAssignments(courseId: courseId, teacherId: teacherId);
      return List<CourseAssignment>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }

  @override
  Future<List<Enrollment>> getEnrollments({int? year, int? semester, String? studentId}) async {
    try {
      final list = await remoteDataSource.getEnrollments(year: year, semester: semester, studentId: studentId);
      return List<Enrollment>.from(list);
    } catch (e) {
      throw ErrorHandler.handleException(e);
    }
  }
}
