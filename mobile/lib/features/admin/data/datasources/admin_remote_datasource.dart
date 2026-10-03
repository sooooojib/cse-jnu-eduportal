import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/admin_stats.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/models/signup_request_model.dart';
import '../../../curriculum/data/models/curriculum_models.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../attendance/data/models/attendance_models.dart';
import '../../../feedback/data/models/feedback_models.dart';
import '../../../profile/data/models/semester_upgrade_request_model.dart';
import '../models/department_notice_model.dart';

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

  AdminRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<AdminOverviewStats> getOverviewStats() async {
    try {
      final results = await Future.wait([
        _safeCount(_firestore.collection('users').where('role', isEqualTo: 'STUDENT')),
        _safeCount(_firestore.collection('users').where('role', isEqualTo: 'TEACHER')),
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
      if (roleFilter != null) {
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
        // Fallback to direct Firestore user creation if Cloud Functions is not deployed
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
      }

      throw const ServerException(message: 'Failed to provision account.');
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteUser({required String userId}) async {
    try {
      try {
        final callable = _functions.httpsCallable('deleteUserByAdmin');
        final response = await callable.call({'userId': userId});
        final data = response.data;
        if (data is Map && data['success'] == false) {
          throw ServerException(message: data['message'] ?? 'Failed to delete user.');
        }
        return;
      } catch (fnErr) {
        await _firestore.collection('users').doc(userId).delete();
      }
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> toggleUserActiveStatus({required String userId, required bool isActive}) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
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
      await _firestore.collection('courses').doc(course.id).update({
        'title': course.title.trim(),
        'description': course.description?.trim(),
        'credit': course.credit,
        'year': course.year,
        'semester': course.semester,
        'courseType': course.courseType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

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
      // 1. Validate Teacher
      final teacherDoc = await _firestore.collection('users').doc(teacherId).get();
      if (!teacherDoc.exists || teacherDoc.data() == null) {
        throw const ValidationException(message: 'Teacher profile not found.', validationErrors: []);
      }
      final teacherData = teacherDoc.data()!;
      if (teacherData['role'] != 'TEACHER') {
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

      // 3. Prevent Duplicate Assignment
      final existingAssignment = await _firestore
          .collection('courseAssignments')
          .where('courseId', isEqualTo: courseId)
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (existingAssignment.docs.isNotEmpty) {
        throw const ValidationException(message: 'This teacher is already assigned to this course.', validationErrors: []);
      }

      // 4. Create assignment document
      final assignmentRef = _firestore.collection('courseAssignments').doc();
      await assignmentRef.set({
        'courseId': courseId,
        'courseCode': courseCode,
        'courseTitle': courseTitle,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'isCoordinator': isCoordinator,
        'assignedAt': FieldValue.serverTimestamp(),
      });

      // 5. Update course record with current teacher (if exists)
      try {
        final courseDoc = await _firestore.collection('courses').doc(courseId).get();
        if (courseDoc.exists) {
          await _firestore.collection('courses').doc(courseId).update({
            'teacherId': teacherId,
            'teacherName': teacherName,
            if (isCoordinator) 'coordinatorId': teacherId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}

      // 6. Append to teacher's assignedCourseIds (if exists)
      try {
        final userDoc = await _firestore.collection('users').doc(teacherId).get();
        if (userDoc.exists) {
          await _firestore.collection('users').doc(teacherId).update({
            'assignedCourseIds': FieldValue.arrayUnion([courseId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> removeCourseAssignment({
    required String assignmentId,
    required String courseId,
    required String teacherId,
  }) async {
    try {
      await _firestore.collection('courseAssignments').doc(assignmentId).delete();

      try {
        final courseDoc = await _firestore.collection('courses').doc(courseId).get();
        if (courseDoc.exists) {
          await _firestore.collection('courses').doc(courseId).update({
            'teacherId': null,
            'teacherName': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}

      try {
        final userDoc = await _firestore.collection('users').doc(teacherId).get();
        if (userDoc.exists) {
          await _firestore.collection('users').doc(teacherId).update({
            'assignedCourseIds': FieldValue.arrayRemove([courseId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {}
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

  @override
  Future<void> approveSignup({
    required String requestId,
    int? assignedYear,
    int? assignedSemester,
  }) async {
    try {
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
        // Fallback to direct Firestore operations if Cloud Functions is not deployed
        final reqDoc = await _firestore.collection('signupRequests').doc(requestId).get();
        if (!reqDoc.exists) {
          throw const ServerException(message: 'Signup petition not found.');
        }
        final reqData = reqDoc.data()!;
        final roleStr = reqData['role'] as String? ?? 'STUDENT';
        final role = UserRole.fromString(roleStr);
        final now = FieldValue.serverTimestamp();
        final userId = reqData['userId'] as String? ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

        await _firestore.collection('users').doc(userId).set({
          'id': userId,
          'email': reqData['email'],
          'fullName': reqData['fullName'],
          'role': role.value,
          'studentId': reqData['studentId'],
          'phone': reqData['phone'],
          'department': 'Computer Science & Engineering',
          'university': 'Jagannath University',
          'year': assignedYear ?? reqData['year'] ?? 1,
          'semester': assignedSemester ?? reqData['semester'] ?? 1,
          'isActive': true,
          'assignedCourseIds': [],
          'fcmTokens': [],
          'createdAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));

        await _firestore.collection('signupRequests').doc(requestId).update({
          'status': 'APPROVED',
          'approvedAt': now,
          'assignedYear': assignedYear ?? 1,
          'assignedSemester': assignedSemester ?? 1,
          'createdUserId': userId,
          'updatedAt': now,
        });
      }
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
        await _firestore.collection('signupRequests').doc(requestId).update({
          'status': 'REJECTED',
          'rejectionReason': reason,
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
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
      try {
        final callable = _functions.httpsCallable('approveSemesterUpgrade');
        final response = await callable.call({'requestId': requestId});

        final data = response.data;
        if (data is Map && data['success'] == false) {
          throw ServerException(message: data['message'] ?? 'Failed to approve semester promotion.');
        }
        return;
      } catch (fnErr) {
        final upgradeDoc = await _firestore.collection('semesterUpgradeRequests').doc(requestId).get();
        if (!upgradeDoc.exists) {
          throw const ServerException(message: 'Semester upgrade request not found.');
        }
        final uData = upgradeDoc.data()!;
        final studentId = uData['studentId'] as String;
        final newYear = uData['requestedYear'] as int;
        final newSemester = uData['requestedSemester'] as int;
        final now = FieldValue.serverTimestamp();

        // Update student in Firestore
        await _firestore.collection('users').doc(studentId).set({
          'year': newYear,
          'semester': newSemester,
          'updatedAt': now,
        }, SetOptions(merge: true));

        // Mark request as APPROVED
        await _firestore.collection('semesterUpgradeRequests').doc(requestId).update({
          'status': 'APPROVED',
          'approvedAt': now,
          'updatedAt': now,
        });

        // Add notification
        await _firestore.collection('notifications').add({
          'userId': studentId,
          'title': 'Semester Upgrade Approved',
          'body': 'Your academic level has been updated to Year $newYear, Semester $newSemester.',
          'notificationType': 'SEMESTER',
          'isRead': false,
          'createdAt': now,
        });
      }
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> rejectSemesterUpgrade({
    required String requestId,
    String? reason,
  }) async {
    try {
      await _firestore.collection('semesterUpgradeRequests').doc(requestId).update({
        'status': 'REJECTED',
        'rejectionReason': reason ?? 'Administrative discretion.',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── ATTENDANCE OVERVIEW ───────────────────────────────────────────────────

  @override
  Future<List<AttendanceSessionModel>> getAllAttendanceSessions() async {
    try {
      final snap = await _firestore.collection('attendanceSessions').get();
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
      final snap = await _firestore.collection('feedback').get();
      final list = snap.docs
          .map((doc) => FeedbackItemModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

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
        userQuery = userQuery.where('role', isEqualTo: 'TEACHER');
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
      await _firestore.collection('notices').doc(noticeId).delete();
      try {
        await _firestore.collection('public_routines').doc(noticeId).delete();
      } catch (_) {}
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
