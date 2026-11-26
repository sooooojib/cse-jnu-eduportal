import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/authoritative_guard.dart';
import '../../domain/entities/admin_stats.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/models/signup_request_model.dart';
import '../../../curriculum/data/models/curriculum_models.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../attendance/data/models/attendance_models.dart';
import '../../../feedback/data/models/feedback_models.dart';
import '../../../profile/data/models/semester_upgrade_request_model.dart';
import '../models/department_notice_model.dart';
import '../../../../core/utils/class_time.dart';

abstract class AdminRemoteDataSource {
  Future<AdminOverviewStats> getOverviewStats();

  // Users
  Future<List<UserModel>> getAllUsers({UserRole? roleFilter});
  Future<UserModel> createUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? studentId,
    String? phone,
    int? year,
    int? semester,
  });
  Future<void> deleteUser({required String userId});
  Future<void> toggleUserActiveStatus({required String userId, required bool isActive});
  Future<void> setAdminDelegate({required String userId, required bool enabled});
  Future<void> updateUserRole({required String userId, required UserRole role});
  Future<void> updateUserSession({required String userId, required String? session});

  // Courses
  Future<List<CourseModel>> getAllCourses();
  Future<void> createCourse(Course course);
  Future<void> updateCourse(Course course);
  Future<void> deleteCourse(String courseId);

  // Assignments
  Future<List<CourseAssignmentModel>> getAllCourseAssignments();
  Future<void> assignCourseToTeacher({
    required String courseId,
    required String teacherId,
    bool isCoordinator = false,
  });
  Future<void> removeCourseAssignment({
    required String assignmentId,
    required String courseId,
    required String teacherId,
  });

  // Requests
  Future<List<SignupRequestModel>> getPendingSignupRequests();
  Future<List<SignupRequestModel>> getAllSignupRequests({String? statusFilter});
  Future<void> approveSignup({
    required String requestId,
    int? assignedYear,
    int? assignedSemester,
  });
  Future<void> rejectSignup({
    required String requestId,
    required String reason,
  });

  // Semester Petitions
  Future<List<SemesterUpgradeRequestModel>> getPendingSemesterRequests();
  Future<List<SemesterUpgradeRequestModel>> getAllSemesterRequests({String? statusFilter});
  Future<void> approveSemesterUpgrade({required String requestId});
  Future<void> rejectSemesterUpgrade({
    required String requestId,
    String? reason,
  });

  // Attendance & Feedback
  Future<List<AttendanceSessionModel>> getAllAttendanceSessions();
  Future<List<FeedbackItemModel>> getAllFeedbackItems();

  // Notices & Notifications Hub
  Future<List<DepartmentNoticeModel>> getAllNotices();
  Future<void> sendBroadcastNotice({
    required String title,
    required String message,
    required String noticeType,
    required String targetAudience,
    String? attachmentUrl,
    String? attachmentType,
    String priority = 'NORMAL',
    bool syncToPublicRoutines = false,
  });
  Future<void> deleteNotice(String noticeId);
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final AuthoritativeGuard? _authoritativeGuard;

  AdminRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AuthoritativeGuard? authoritativeGuard,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _authoritativeGuard = authoritativeGuard ?? (sl.isRegistered<AuthoritativeGuard>() ? sl<AuthoritativeGuard>() : null);

  @override
  Future<AdminOverviewStats> getOverviewStats() async {
    try {
      final results = await Future.wait([
        _safeCount(_firestore.collection('users').where('role', isEqualTo: 'STUDENT')),
        _safeCount(_firestore.collection('users').where('role', whereIn: ['TEACHER', 'CHAIRMAN'])),
        _safeCount(_firestore.collection('users').where('role', isEqualTo: 'CR')),
        _safeCount(_firestore.collection('courses')),
        _safeCount(_firestore.collection('signupRequests').where('status', isEqualTo: 'PENDING')),
        _safeCount(_firestore.collection('semesterUpgradeRequests').where('status', isEqualTo: 'PENDING')),
        _safeCount(_firestore.collection('attendanceSessions').where('status', isEqualTo: 'ACTIVE')),
      ]);

      return AdminOverviewStats(
        totalStudents: results[0],
        totalTeachers: results[1],
        totalCrs: results[2],
        totalCourses: results[3],
        pendingSignups: results[4],
        pendingSemesterRequests: results[5],
        activeSessions: results[6],
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<int> _safeCount(Query query) async {
    try {
      final aggregate = await query.count().get();
      return aggregate.count ?? 0;
    } catch (_) {
      try {
        final snap = await query.get();
        return snap.docs.length;
      } catch (_) {
        return 0;
      }
    }
  }

  // ─── USER DIRECTORY & MANAGEMENT ───────────────────────────────────────────

  @override
  Future<List<UserModel>> getAllUsers({UserRole? roleFilter}) async {
    try {
      Query query = _firestore.collection('users');
      if (roleFilter == UserRole.teacher) {
        // "Faculty" includes the Chairman, who also teaches and can be assigned courses.
        query = query.where('role', whereIn: [UserRole.teacher.value, UserRole.chairman.value]);
      } else if (roleFilter != null) {
        query = query.where('role', isEqualTo: roleFilter.value);
      }
      final snap = await query.get();
      final users = snap.docs
          .map((doc) => UserModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      users.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      return users;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<UserModel> createUser({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? studentId,
    String? phone,
    int? year,
    int? semester,
  }) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Creating user profile',
        );
      }

      if (EnvConfig.isCloudFunctionsEnabled) {
        try {
          final callable = _functions.httpsCallable('createAdminUser');
          final response = await callable.call({
            'fullName': fullName.trim(),
            'email': email.trim().toLowerCase(),
            'password': password,
            'role': role.value,
            if (studentId != null) 'studentId': studentId.trim(),
            if (phone != null) 'phone': phone.trim(),
            if (year != null) 'year': year,
            if (semester != null) 'semester': semester,
          });

          final data = response.data;
          if (data is Map && data['success'] == true) {
            final userId = data['userId'] as String;
            return UserModel(
              id: userId,
              email: email.trim().toLowerCase(),
              fullName: fullName.trim(),
              role: role,
              studentId: studentId?.trim(),
              phone: phone?.trim(),
              year: year,
              semester: semester,
              assignedCourseIds: const [],
              isActive: true,
            );
          }
        } catch (fnErr) {
          // Fallback below
        }
      }

      // Direct Firestore user creation fallback
        final normalizedEmail = email.trim().toLowerCase();
        final existingSnap = await _firestore
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (existingSnap.docs.isNotEmpty) {
          throw const ServerException(message: 'A user with this email already exists.');
        }

        final now = FieldValue.serverTimestamp();
        final userRef = _firestore.collection('users').doc();
        final userModel = UserModel(
          id: userRef.id,
          email: normalizedEmail,
          fullName: fullName.trim(),
          role: role,
          studentId: studentId?.trim(),
          phone: phone?.trim(),
          year: year,
          semester: semester,
          assignedCourseIds: const [],
          isActive: true,
        );

        await userRef.set({
          'id': userModel.id,
          'email': userModel.email,
          'fullName': userModel.fullName,
          'role': userModel.role.value,
          'studentId': userModel.studentId,
          'phone': userModel.phone,
          'department': 'Computer Science & Engineering',
          'university': 'Jagannath University',
          'year': userModel.year,
          'semester': userModel.semester,
          'isActive': true,
          'assignedCourseIds': userModel.assignedCourseIds,
          'fcmTokens': [],
          'createdAt': now,
          'updatedAt': now,
        });

        return userModel;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteUser({required String userId}) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Deleting user profile',
        );
      }

      if (EnvConfig.isCloudFunctionsEnabled) {
        try {
          final callable = _functions.httpsCallable('deleteUserByAdmin');
          final response = await callable.call({'userId': userId});
          final data = response.data;
          if (data is Map && data['success'] == false) {
            throw ServerException(message: data['message'] ?? 'Failed to delete user.');
          }
          return;
        } catch (fnErr) {
          // Fallback below
        }
      }
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> toggleUserActiveStatus({required String userId, required bool isActive}) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Updating user active status',
        );
      }

      final userRef = _firestore.collection('users').doc(userId);
      if (isActive) {
        // Reactivate: the account works again (courses / CR role are not
        // restored automatically; reassign them if needed).
        await userRef.update({'isActive': true, 'updatedAt': FieldValue.serverTimestamp()});
        return;
      }

      // S2-07: deactivate instead of delete, in ONE batch. The login is
      // refused ("Your account has been deactivated") and the rules ignore
      // the account. Nothing is left pointing at someone who can't act:
      final data = (await userRef.get()).data() ?? const <String, dynamic>{};
      final role = (data['role'] as String? ?? '').toUpperCase();
      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();
      batch.update(userRef, {
        'isActive': false,
        // A teacher's courses become unassigned.
        if (role == 'TEACHER' || role == 'CHAIRMAN') 'assignedCourseIds': <String>[],
        // A CR stops being CR, so the batch can get a new one.
        if (role == 'CR') 'role': 'STUDENT',
        if (data['isCR'] == true) 'isCR': FieldValue.delete(),
        'updatedAt': now,
      });

      if (role == 'TEACHER' || role == 'CHAIRMAN') {
        for (final course in await teacherCourseIds(userId)) {
          final courseRef = _firestore.collection('courses').doc(course);
          final cData = (await courseRef.get()).data();
          if (cData != null && cData['teacherId'] == userId) {
            batch.update(courseRef, {
              'teacherId': null,
              'teacherName': null,
              if (cData['coordinatorId'] == userId) 'coordinatorId': FieldValue.delete(),
              'updatedAt': now,
            });
          }
          for (final slot in await _currentSlotsOf(course)) {
            if (slot.data()['teacherId'] == userId) {
              batch.update(slot.reference, {'teacherId': '', 'teacherName': '', 'updatedAt': now});
            }
          }
        }
        final assignments = await _firestore.collection('courseAssignments').where('teacherId', isEqualTo: userId).get();
        for (final a in assignments.docs) {
          batch.delete(a.reference);
        }
      }
      if (role == 'CR' || data['isCR'] == true || role == 'STUDENT') {
        for (final offer in await _openCrOffersInvolving(userId)) {
          batch.update(offer, {'status': 'CANCELLED', 'updatedAt': now});
        }
      }
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Courses a teacher holds: as the course's teacher, by assignment, or in
  /// their assignedCourseIds.
  Future<List<String>> teacherCourseIds(String teacherId) async {
    final ids = <String>{};
    final owned = await _firestore.collection('courses').where('teacherId', isEqualTo: teacherId).get();
    ids.addAll(owned.docs.map((d) => d.id));
    final assigned = await _firestore.collection('courseAssignments').where('teacherId', isEqualTo: teacherId).get();
    ids.addAll(assigned.docs.map((d) => d.data()['courseId'] as String? ?? '').where((c) => c.isNotEmpty));
    final u = (await _firestore.collection('users').doc(teacherId).get()).data();
    ids.addAll(List<String>.from(u?['assignedCourseIds'] ?? const []));
    return ids.toList()..sort();
  }

  @override
  Future<void> setAdminDelegate({required String userId, required bool enabled}) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Updating signup committee access',
        );
      }
      if (EnvConfig.isCloudFunctionsEnabled) {
        await _functions.httpsCallable('setAdminDelegate').call({
          'userId': userId,
          'enabled': enabled,
        });
        return;
      }
      await _firestore.collection('users').doc(userId).update({
        'isAdminDelegate': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> updateUserRole({required String userId, required UserRole role}) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Changing user role',
        );
      }
      // Free plan: no Cloud Function. Roles are read from the users record
      // (S1-03), so the change is a direct write that the rules check:
      // Admin any role, Chairman any role except Admin, never your own, and
      // only within a group (staff <-> staff, student <-> CR).
      final ref = _firestore.collection('users').doc(userId);
      final doc = await ref.get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        throw const ValidationException(message: 'User not found.', validationErrors: []);
      }
      final from = UserRole.fromString(data['role'] as String? ?? '');
      if (!roleChangeAllowed(from, role)) {
        throw ValidationException(
          message: 'A ${from.label} can only be changed to ${roleChoicesFor(from).where((r) => r != from).map((r) => r.label).join(' or ')}.',
          validationErrors: const [],
        );
      }

      final batch = _firestore.batch();
      if (role == UserRole.cr) {
        // One CR per batch (year + semester): the previous CR becomes a student.
        for (final prev in await _currentCrs(data['year'], data['semester'])) {
          if (prev.id == userId) continue;
          batch.update(prev.reference, {
            'role': UserRole.student.value,
            'isCR': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          final pending = _firestore.collection('crTransfers').doc(prev.id);
          if ((await pending.get()).exists) batch.delete(pending);
        }
      }
      batch.update(ref, {
        'role': role.value,
        if (from.isCr || role.isCr || role.isStudent) 'isCR': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (from.isCr && role.isStudent) {
        final pending = _firestore.collection('crTransfers').doc(userId);
        if ((await pending.get()).exists) batch.delete(pending);
      }
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// CRs of a year / semester (by role, or the older `isCR` flag).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _currentCrs(dynamic year, dynamic semester) async {
    if (year == null || semester == null) return const [];
    final snap = await _firestore
        .collection('users')
        .where('year', isEqualTo: year)
        .where('semester', isEqualTo: semester)
        .get();
    return snap.docs.where((d) {
      final r = (d.data()['role'] as String? ?? '').toUpperCase();
      return r == 'CR' || d.data()['isCR'] == true;
    }).toList();
  }

  /// Roles a user can be moved to: staff stay staff, students stay students.
  static List<UserRole> roleChoicesFor(UserRole from) => (from.isStudent || from.isCr)
      ? const [UserRole.student, UserRole.cr]
      : const [UserRole.teacher, UserRole.chairman, UserRole.admin];

  static bool roleChangeAllowed(UserRole from, UserRole to) =>
      from != to && roleChoicesFor(from).contains(to);

  @override
  Future<void> updateUserSession({required String userId, required String? session}) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'session': (session == null || session.isEmpty) ? FieldValue.delete() : session,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── COURSE MANAGEMENT ─────────────────────────────────────────────────────

  @override
  Future<List<CourseModel>> getAllCourses() async {
    try {
      final snap = await _firestore.collection('courses').get();
      final courses = snap.docs
          .map((doc) => CourseModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      courses.sort((a, b) {
        final yearCompare = a.year.compareTo(b.year);
        if (yearCompare != 0) return yearCompare;
        final semCompare = a.semester.compareTo(b.semester);
        if (semCompare != 0) return semCompare;
        return a.code.compareTo(b.code);
      });
      return courses;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> createCourse(Course course) async {
    try {
      final trimmedCode = course.code.trim().toUpperCase();

      // Check unique code
      final existing = await _firestore.collection('courses').where('code', isEqualTo: trimmedCode).get();
      if (existing.docs.isNotEmpty) {
        throw const ValidationException(message: 'A course with this course code already exists.', validationErrors: []);
      }

      if (course.year < 1 || course.year > 4) {
        throw const ValidationException(message: 'Academic Year must be between 1 and 4.', validationErrors: []);
      }
      if (course.semester < 1 || course.semester > 2) {
        throw const ValidationException(message: 'Semester must be 1 or 2.', validationErrors: []);
      }
      if (course.credit <= 0 || course.credit > 6.0) {
        throw const ValidationException(message: 'Course credits must be between 0.5 and 6.0.', validationErrors: []);
      }

      final docRef = _firestore.collection('courses').doc(trimmedCode);
      await docRef.set({
        'code': trimmedCode,
        'title': course.title.trim(),
        'description': course.description?.trim(),
        'credit': course.credit,
        'year': course.year,
        'semester': course.semester,
        'courseType': course.courseType,
        'teacherId': course.teacherId,
        'teacherName': course.teacherName,
        if (course.targetClassCount != null && course.targetClassCount! > 0)
          'targetClassCount': course.targetClassCount,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> updateCourse(Course course) async {
    try {
      final courseRef = _firestore.collection('courses').doc(course.id);
      final old = (await courseRef.get()).data() ?? const <String, dynamic>{};
      final moving = old.isNotEmpty && (old['year'] != course.year || old['semester'] != course.semester);
      final batch = _firestore.batch();
      if (moving) {
        await _moveCourseDependents(batch, course, old);
      }
      batch.update(courseRef, {
        'title': course.title.trim(),
        'description': course.description?.trim(),
        'credit': course.credit,
        'year': course.year,
        'semester': course.semester,
        'courseType': course.courseType,
        'targetClassCount': (course.targetClassCount != null && course.targetClassCount! > 0)
            ? course.targetClassCount
            : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// S2-08: a course moved to another year / semester takes its routine and
  /// upcoming exams along (same batch). Past attendance and past exams stay
  /// with the semester they happened in. Blocked, with a reason, if a routine
  /// class would clash in the new semester or upcoming class changes exist.
  Future<void> _moveCourseDependents(WriteBatch batch, Course course, Map<String, dynamic> old) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final code = (old['code'] as String?) ?? course.code;
    final toY = course.year, toS = course.semester;

    final changes = await _firestore.collection('classChanges').where('courseId', isEqualTo: course.id).get();
    final upcomingChanges = changes.docs.where((d) => ((d.data()['date'] as String?) ?? '').compareTo(today) >= 0).length;
    if (upcomingChanges > 0) {
      throw ValidationException(
        message: '$code has $upcomingChanges upcoming class change${upcomingChanges == 1 ? '' : 's'} '
            '(moved / cancelled / extra classes) for Year ${old['year']}, Semester ${old['semester']}. '
            'Remove them in the routine first, then change the semester.',
        validationErrors: const [],
      );
    }

    final slots = await _currentSlotsOf(course.id);
    final target = await _firestore
        .collection('schedules')
        .where('targetYear', isEqualTo: toY)
        .where('targetSemester', isEqualTo: toS)
        .get();
    for (final s in slots) {
      final d = s.data();
      final day = (d['dayOfWeek'] as String? ?? '').toUpperCase();
      final st = ClassTime.toMinutes(d['startTime'] as String? ?? '');
      final en = ClassTime.toMinutes(d['endTime'] as String? ?? '');
      final date = d['date'] as String?;
      if (st == null || en == null) continue;
      for (final t in target.docs) {
        final o = t.data();
        if (o['courseId'] == course.id) continue;
        if ((o['status'] as String? ?? '').toUpperCase() == 'CANCELLED') continue;
        final oDate = o['date'] as String?;
        final sameDay = (date != null && date.isNotEmpty)
            ? (oDate == date || ((oDate == null || oDate.isEmpty) && (o['dayOfWeek'] as String? ?? '').toUpperCase() == day))
            : ((oDate == null || oDate.isEmpty) && (o['dayOfWeek'] as String? ?? '').toUpperCase() == day);
        final os = ClassTime.toMinutes(o['startTime'] as String? ?? '');
        final oe = ClassTime.toMinutes(o['endTime'] as String? ?? '');
        if (sameDay && os != null && oe != null && ClassTime.overlaps(st, en, os, oe)) {
          throw ValidationException(
            message: "Can't move $code: its ${_title(day)} ${d['startTime']} class clashes with "
                "${o['courseCode'] ?? 'another course'} (${o['startTime']}-${o['endTime']}) in Year $toY, Semester $toS. "
                'Change one of the two routine classes first.',
            validationErrors: const [],
          );
        }
      }
      batch.update(s.reference, {'targetYear': toY, 'targetSemester': toS, 'updatedAt': FieldValue.serverTimestamp()});
    }

    final exams = await _firestore.collection('exams').where('courseId', isEqualTo: course.id).get();
    for (final e in exams.docs) {
      if (((e.data()['examDate'] as String?) ?? '').compareTo(today) >= 0) {
        batch.update(e.reference, {'year': toY, 'semester': toS, 'updatedAt': FieldValue.serverTimestamp()});
      }
    }
  }

  static String _title(String day) => day.isEmpty ? day : day[0] + day.substring(1).toLowerCase();

  @override
  Future<void> deleteCourse(String courseId) async {
    try {
      await _firestore.collection('courses').doc(courseId).delete();

      // Clean up matching courseAssignments
      final assignments = await _firestore.collection('courseAssignments').where('courseId', isEqualTo: courseId).get();
      final batch = _firestore.batch();
      for (final doc in assignments.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── TEACHER COURSE ASSIGNMENTS ────────────────────────────────────────────

  @override
  Future<List<CourseAssignmentModel>> getAllCourseAssignments() async {
    try {
      final snap = await _firestore.collection('courseAssignments').get();
      return snap.docs
          .map((doc) => CourseAssignmentModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> assignCourseToTeacher({
    required String courseId,
    required String teacherId,
    bool isCoordinator = false,
  }) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Assigning course to teacher',
        );
      }

      // 1. Validate Teacher
      final teacherDoc = await _firestore.collection('users').doc(teacherId).get();
      if (!teacherDoc.exists || teacherDoc.data() == null) {
        throw const ValidationException(message: 'Teacher profile not found.', validationErrors: []);
      }
      final teacherData = teacherDoc.data()!;
      final teacherRole = (teacherData['role'] as String? ?? '').toUpperCase();
      if (teacherRole != 'TEACHER' && teacherRole != 'CHAIRMAN') {
        throw const ValidationException(message: 'Selected user is not a departmental faculty member.', validationErrors: []);
      }
      final teacherName = teacherData['fullName'] as String? ?? 'Professor';

      // 2. Validate Course
      final courseDoc = await _firestore.collection('courses').doc(courseId).get();
      if (!courseDoc.exists || courseDoc.data() == null) {
        throw const ValidationException(message: 'Course not found.', validationErrors: []);
      }
      final courseData = courseDoc.data()!;
      final courseCode = courseData['code'] as String? ?? courseId;
      final courseTitle = courseData['title'] as String? ?? '';

      // 3. A course has ONE teacher. Assigning replaces the current one, in a
      //    single batch, so the old teacher loses control at the same moment
      //    the new one gets it (no half-finished change).
      final existing = await _firestore
          .collection('courseAssignments')
          .where('courseId', isEqualTo: courseId)
          .get();
      final currentTeacherId = courseData['teacherId'] as String?;
      if (currentTeacherId == teacherId &&
          existing.docs.any((d) => d.data()['teacherId'] == teacherId)) {
        throw const ValidationException(message: 'This teacher is already assigned to this course.', validationErrors: []);
      }

      final oldTeacherIds = <String>{
        for (final d in existing.docs)
          if ((d.data()['teacherId'] as String? ?? '').isNotEmpty) d.data()['teacherId'] as String,
        if (currentTeacherId != null && currentTeacherId.isNotEmpty) currentTeacherId,
      }..remove(teacherId);

      final batch = _firestore.batch();
      for (final d in existing.docs) {
        batch.delete(d.reference);
      }
      for (final oldId in oldTeacherIds) {
        final oldDoc = await _firestore.collection('users').doc(oldId).get();
        if (oldDoc.exists) {
          batch.update(oldDoc.reference, {
            'assignedCourseIds': FieldValue.arrayRemove([courseId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      batch.set(_firestore.collection('courseAssignments').doc(), {
        'courseId': courseId,
        'courseCode': courseCode,
        'courseTitle': courseTitle,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'isCoordinator': isCoordinator,
        'assignedAt': FieldValue.serverTimestamp(),
      });
      batch.update(courseDoc.reference, {
        'teacherId': teacherId,
        'teacherName': teacherName,
        'coordinatorId': isCoordinator ? teacherId : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(teacherDoc.reference, {
        'assignedCourseIds': FieldValue.arrayUnion([courseId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // The course's routine follows: weekly slots and upcoming dated classes
      // held by the old teacher (or nobody) move to the new teacher. Slots
      // deliberately given to another teacher, and past classes, stay.
      for (final slot in await _currentSlotsOf(courseId)) {
        final holder = slot.data()['teacherId'] as String? ?? '';
        if (holder.isEmpty || oldTeacherIds.contains(holder)) {
          batch.update(slot.reference, {
            'teacherId': teacherId,
            'teacherName': teacherName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// A course's weekly routine slots plus dated classes from today on.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _currentSlotsOf(String courseId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snap = await _firestore.collection('schedules').where('courseId', isEqualTo: courseId).get();
    return snap.docs.where((d) {
      final date = d.data()['date'];
      return date == null || (date is String && (date.isEmpty || date.compareTo(today) >= 0));
    }).toList();
  }

  @override
  Future<void> removeCourseAssignment({
    required String assignmentId,
    required String courseId,
    required String teacherId,
  }) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Removing course assignment',
        );
      }

      // One batch: drop the assignment, take the course off the teacher's
      // list, and clear the course's teacher only if it is this teacher.
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('courseAssignments').doc(assignmentId));

      final courseRef = _firestore.collection('courses').doc(courseId);
      final courseDoc = await courseRef.get();
      if (courseDoc.exists && courseDoc.data()?['teacherId'] == teacherId) {
        batch.update(courseRef, {
          'teacherId': null,
          'teacherName': null,
          if (courseDoc.data()?['coordinatorId'] == teacherId) 'coordinatorId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // That teacher's weekly / upcoming classes of this course no longer
      // name them (the routine shows "Teacher not set" until reassigned).
      if (courseDoc.exists && courseDoc.data()?['teacherId'] == teacherId) {
        for (final slot in await _currentSlotsOf(courseId)) {
          if (slot.data()['teacherId'] == teacherId) {
            batch.update(slot.reference, {
              'teacherId': '',
              'teacherName': '',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      final userRef = _firestore.collection('users').doc(teacherId);
      if ((await userRef.get()).exists) {
        batch.update(userRef, {
          'assignedCourseIds': FieldValue.arrayRemove([courseId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── SIGNUP REQUESTS ───────────────────────────────────────────────────────

  @override
  Future<List<SignupRequestModel>> getPendingSignupRequests() {
    return getAllSignupRequests(statusFilter: 'PENDING');
  }

  @override
  Future<List<SignupRequestModel>> getAllSignupRequests({String? statusFilter}) async {
    try {
      Query query = _firestore.collection('signupRequests');
      if (statusFilter != null && statusFilter != 'ALL') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      final snap = await query.get();
      final list = snap.docs
          .map((doc) => SignupRequestModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// The signed-in reviewer (recorded on every decision).
  String get _reviewerId {
    try {
      return fb.FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<void> approveSignup({
    required String requestId,
    int? assignedYear,
    int? assignedSemester,
  }) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Approving signup request',
        );
      }

      if (EnvConfig.isCloudFunctionsEnabled) {
        try {
          final callable = _functions.httpsCallable('approveSignupRequest');
          final response = await callable.call({
            'requestId': requestId,
            if (assignedYear != null) 'assignedYear': assignedYear,
            if (assignedSemester != null) 'assignedSemester': assignedSemester,
          });

          final data = response.data;
          if (data is Map && data['success'] == false) {
            throw ServerException(message: data['message'] ?? 'Failed to approve signup petition.');
          }
          return;
        } catch (fnErr) {
          // Business-rule rejections from the server must reach the user; only
          // fall back to direct Firestore when the function itself is unreachable.
          if (_isAuthoritativeRejection(fnErr)) rethrow;
          // Fallback below
        }
      }

      // Direct path (no Cloud Functions): the applicant already has a login
      // (created at signup); approving switches on their account and marks the
      // request approved in ONE batch, which the security rules check together.
      final reqDoc = await _firestore.collection('signupRequests').doc(requestId).get();
      if (!reqDoc.exists) {
        throw const ServerException(message: 'Signup request not found.');
      }
      final reqData = reqDoc.data()!;
      if ((reqData['status'] as String? ?? 'PENDING') != 'PENDING') {
        throw const ServerException(message: 'This request has already been decided.');
      }
      final userId = (reqData['userId'] as String? ?? '').trim();
      if (userId.isEmpty) {
        throw const ServerException(
          message: 'This is an old request without a login. Ask the person to sign up again in the app.',
        );
      }
      final role = UserRole.fromString(reqData['role'] as String? ?? 'STUDENT');
      final year = assignedYear ?? (reqData['year'] as num?)?.toInt() ?? 1;
      final semester = assignedSemester ?? (reqData['semester'] as num?)?.toInt() ?? 1;
      final now = FieldValue.serverTimestamp();
      final reviewer = _reviewerId;

      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(userId), {
        'id': userId,
        'email': reqData['email'],
        'fullName': reqData['fullName'],
        'role': role.value,
        if (reqData['studentId'] != null) 'studentId': reqData['studentId'],
        if (reqData['phone'] != null) 'phone': reqData['phone'],
        'department': 'Computer Science & Engineering',
        'university': 'Jagannath University',
        if (role.isStudentSide) 'year': year,
        if (role.isStudentSide) 'semester': semester,
        if (reqData['session'] != null) 'session': reqData['session'],
        'isActive': true,
        'assignedCourseIds': [],
        'fcmTokens': [],
        'createdAt': now,
        'updatedAt': now,
      });
      batch.update(_firestore.collection('signupRequests').doc(requestId), {
        'status': 'APPROVED',
        'approvedAt': now,
        'assignedYear': year,
        'assignedSemester': semester,
        'createdUserId': userId,
        'reviewedBy': reviewer,
        'updatedAt': now,
      });
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> rejectSignup({
    required String requestId,
    required String reason,
  }) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Rejecting signup request',
        );
      }

      if (EnvConfig.isCloudFunctionsEnabled) {
        try {
          final callable = _functions.httpsCallable('rejectSignupRequest');
          final response = await callable.call({
            'requestId': requestId,
            'reason': reason,
          });

          final data = response.data;
          if (data is Map && data['success'] == false) {
            throw ServerException(message: data['message'] ?? 'Failed to reject signup petition.');
          }
          return;
        } catch (fnErr) {
          // Business-rule rejections from the server must reach the user; only
          // fall back to direct Firestore when the function itself is unreachable.
          if (_isAuthoritativeRejection(fnErr)) rethrow;
          // Fallback below
        }
      }

      await _firestore.collection('signupRequests').doc(requestId).update({
        'status': 'REJECTED',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'reviewedBy': _reviewerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── SEMESTER UPGRADE REQUESTS ─────────────────────────────────────────────

  @override
  Future<List<SemesterUpgradeRequestModel>> getPendingSemesterRequests() {
    return getAllSemesterRequests(statusFilter: 'PENDING');
  }

  @override
  Future<List<SemesterUpgradeRequestModel>> getAllSemesterRequests({String? statusFilter}) async {
    try {
      Query query = _firestore.collection('semesterUpgradeRequests');
      if (statusFilter != null && statusFilter != 'ALL') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      final snap = await query.get();
      final list = snap.docs
          .map((doc) => SemesterUpgradeRequestModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> approveSemesterUpgrade({required String requestId}) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Approving semester request',
        );
      }

      if (EnvConfig.isCloudFunctionsEnabled) {
        try {
          final callable = _functions.httpsCallable('approveSemesterUpgrade');
          final response = await callable.call({'requestId': requestId});

          final data = response.data;
          if (data is Map && data['success'] == false) {
            throw ServerException(message: data['message'] ?? 'Failed to approve semester promotion.');
          }
          return;
        } catch (fnErr) {
          // Fallback below
        }
      }

      final upgradeDoc = await _firestore.collection('semesterUpgradeRequests').doc(requestId).get();
        if (!upgradeDoc.exists) {
          throw const ServerException(message: 'Semester upgrade request not found.');
        }
        final uData = upgradeDoc.data()!;
        if ((uData['status'] as String? ?? 'PENDING') != 'PENDING') {
          throw const ServerException(message: 'This request has already been decided.');
        }
        final studentId = uData['studentId'] as String;
        final newYear = ((uData['requestedYear'] ?? uData['targetYear']) as num?)?.toInt();
        final newSemester = ((uData['requestedSemester'] ?? uData['targetSemester']) as num?)?.toInt();
        if (newYear == null || newSemester == null) {
          throw const ServerException(message: 'This request has no requested semester. Reject it and ask the student to request again.');
        }
        final now = FieldValue.serverTimestamp();

        // Move the student and approve the request in ONE batch (the rules
        // check that the new semester is exactly the one requested).
        final reviewer = _reviewerId;
        final batch = _firestore.batch();
        // S2-05: a CR who moves on stops being CR (the old batch keeps or
        // appoints its own CR), and open CR offers from / to them are cancelled.
        final studentData = (await _firestore.collection('users').doc(studentId).get()).data() ?? const {};
        final wasCr = (studentData['role'] as String? ?? '').toUpperCase() == 'CR' || studentData['isCR'] == true;
        batch.update(_firestore.collection('users').doc(studentId), {
          'year': newYear,
          'semester': newSemester,
          'lastSemesterRequestId': requestId,
          if (wasCr) 'role': 'STUDENT',
          if (wasCr) 'isCR': FieldValue.delete(),
          'updatedAt': now,
        });
        for (final offer in await _openCrOffersInvolving(studentId)) {
          batch.update(offer, {'status': 'CANCELLED', 'updatedAt': now});
        }
        batch.update(_firestore.collection('semesterUpgradeRequests').doc(requestId), {
          'status': 'APPROVED',
          'approvedAt': now,
          'reviewedBy': reviewer,
          'updatedAt': now,
        });
        await batch.commit();

        // Tell the student (best effort; the change is already saved).
        try {
          await _firestore.collection('notifications').add({
            'userId': studentId,
            'senderId': _reviewerId,
            'title': 'Semester Upgrade Approved',
            'body': 'Your academic level has been updated to Year $newYear, Semester $newSemester.',
            'notificationType': 'SEMESTER',
            'referenceType': 'SEMESTER_REQUEST',
            'referenceId': requestId,
            'isRead': false,
            'createdAt': now,
          });
        } catch (_) {}
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Pending CR hand-over offers sent by or to this student.
  Future<List<DocumentReference>> _openCrOffersInvolving(String uid) async {
    final refs = <DocumentReference>[];
    try {
      final own = await _firestore.collection('crTransfers').doc(uid).get();
      if (own.exists && own.data()?['status'] == 'PENDING') refs.add(own.reference);
      final toMe = await _firestore
          .collection('crTransfers')
          .where('toUid', isEqualTo: uid)
          .where('status', isEqualTo: 'PENDING')
          .get();
      refs.addAll(toMe.docs.map((d) => d.reference));
    } catch (_) {}
    return refs;
  }

  @override
  Future<void> rejectSemesterUpgrade({
    required String requestId,
    String? reason,
  }) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Rejecting semester request',
        );
      }

      final why = (reason ?? '').trim().isEmpty ? 'Not approved.' : reason!.trim();
      final ref = _firestore.collection('semesterUpgradeRequests').doc(requestId);
      final studentId = (await ref.get()).data()?['studentId'] as String?;
      await ref.update({
        'status': 'REJECTED',
        'rejectionReason': why,
        'reviewedBy': _reviewerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // S2-13: tell the student (best effort; the decision is already saved).
      if (studentId != null && studentId.isNotEmpty) {
        try {
          await _firestore.collection('notifications').add({
            'userId': studentId,
            'senderId': _reviewerId,
            'title': 'Semester request not approved',
            'body': why,
            'notificationType': 'SEMESTER',
            'referenceType': 'SEMESTER_REQUEST',
            'referenceId': requestId,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── ATTENDANCE OVERVIEW ───────────────────────────────────────────────────

  @override
  Future<List<AttendanceSessionModel>> getAllAttendanceSessions() async {
    try {
      // S2-11 (free plan): the last 60 days, not every session ever.
      final from = DateFormat('yyyy-MM-dd').format(ClassTime.now().subtract(const Duration(days: 60)));
      final snap = await _firestore.collection('attendanceSessions').where('sessionDate', isGreaterThanOrEqualTo: from).get();
      final sessions = snap.docs
          .map((doc) => AttendanceSessionModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      sessions.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
      return sessions;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── FEEDBACK MODERATION ───────────────────────────────────────────────────

  @override
  Future<List<FeedbackItemModel>> getAllFeedbackItems() async {
    try {
      // S2-11 (free plan): the newest 300.
      final snap = await _firestore.collection('feedback').orderBy('createdAt', descending: true).limit(300).get();
      final list = <FeedbackItemModel>[];
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        if (data['isAnonymous'] == true) {
          try {
            final identityDoc = await _firestore.collection('feedbackIdentities').doc(doc.id).get();
            if (identityDoc.exists && identityDoc.data() != null) {
              final idData = identityDoc.data()!;
              data['studentName'] = 'Anonymous (${idData['studentName'] ?? 'Student'})';
              data['studentEmail'] = idData['studentEmail'];
            }
          } catch (_) {}
        }
        list.add(FeedbackItemModel.fromJson({'id': doc.id, ...data}));
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── NOTICE & NOTIFICATION HUB ─────────────────────────────────────────────

  @override
  Future<List<DepartmentNoticeModel>> getAllNotices() async {
    try {
      final snap = await _firestore.collection('notices').get();
      final list = snap.docs
          .map((doc) => DepartmentNoticeModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> sendBroadcastNotice({
    required String title,
    required String message,
    required String noticeType,
    required String targetAudience,
    String? attachmentUrl,
    String? attachmentType,
    String priority = 'NORMAL',
    bool syncToPublicRoutines = false,
  }) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Publishing department notice',
        );
      }

      // 1. Create central notice record
      final noticeRef = _firestore.collection('notices').doc();
      final nowStr = DateTime.now().toIso8601String();
      await noticeRef.set({
        'title': title,
        'message': message,
        'noticeType': noticeType,
        'targetAudience': targetAudience,
        'attachmentUrl': attachmentUrl,
        'attachmentType': attachmentType,
        'priority': priority,
        'syncedToPublicRoutines': syncToPublicRoutines,
        'sentBy': 'Department Administration',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Fetch targeted users to dispatch notification inboxes
      Query userQuery = _firestore.collection('users');
      if (targetAudience == 'STUDENTS') {
        userQuery = userQuery.where('role', isEqualTo: 'STUDENT');
      } else if (targetAudience == 'TEACHERS') {
        userQuery = userQuery.where('role', whereIn: ['TEACHER', 'CHAIRMAN']);
      } else if (targetAudience == 'CRS') {
        userQuery = userQuery.where('role', isEqualTo: 'CR');
      }

      final usersSnap = await userQuery.get();
      if (usersSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final userDoc in usersSnap.docs) {
          final notifRef = _firestore.collection('notifications').doc();
          batch.set(notifRef, {
            'userId': userDoc.id,
            'title': title,
            'body': message,
            'notificationType': noticeType,
            'referenceType': 'NOTICE',
            'referenceId': noticeRef.id,
            'attachmentUrl': attachmentUrl,
            'attachmentType': attachmentType,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // 3. Sync to public routines archive if applicable
      if (syncToPublicRoutines || noticeType == 'CENTRAL_ROUTINE' || noticeType == 'SEMESTER_EXAM') {
        final routineRef = _firestore.collection('public_routines').doc(noticeRef.id);
        await routineRef.set({
          'noticeId': noticeRef.id,
          'title': title,
          'category': noticeType == 'SEMESTER_EXAM' ? 'Central Exam' : 'Central Routine',
          'type': noticeType == 'SEMESTER_EXAM' ? 'central' : 'central',
          'format': attachmentType ?? 'PDF',
          'fileSize': 'Official Notice Document',
          'fileUrl': attachmentUrl ?? '',
          'publishedDate': nowStr.substring(0, 10),
          'description': message,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteNotice(String noticeId) async {
    try {
      if (_authoritativeGuard != null) {
        await _authoritativeGuard.ensureAuthoritativeServer(
          operationName: 'Deleting department notice',
        );
      }

      await _firestore.collection('notices').doc(noticeId).delete();
      try {
        await _firestore.collection('public_routines').doc(noticeId).delete();
      } catch (_) {}
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}

/// True when a Cloud Function rejected the call for a business / security
/// reason (as opposed to being unreachable), so callers must not retry the
/// operation through a direct-Firestore fallback.
bool _isAuthoritativeRejection(Object error) {
  if (error is! FirebaseFunctionsException) return false;
  const rejectionCodes = {
    'permission-denied',
    'unauthenticated',
    'invalid-argument',
    'failed-precondition',
    'already-exists',
  };
  return rejectionCodes.contains(error.code);
}
