import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance_totals.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/attendance_entities.dart';
import '../models/attendance_models.dart';
import '../../../../core/utils/class_time.dart';
import '../../domain/services/class_keys.dart';

/// Attendance without Cloud Functions, protected by security rules.
///
/// * **Rotating code:** the session document holds no code. The current code
///   (and the previous one) live in `attendanceSessions/{id}/private/code`,
///   readable only by the session's teacher. The teacher's screen issues a
///   new code every [rotateEvery]; the rules accept the current or previous
///   code only while the teacher's screen keeps rotating (issued < 45 s ago).
/// * **Right students only:** a student can only mark a session of their own
///   semester, once, while it is open.
/// * **Present only:** self-marks are always PRESENT (late marking was
///   removed); older LATE records still count as attended.
/// * **Manual mode:** no code; the teacher marks the roster by hand.
/// * **Auto absent:** finishing a session records everyone left as ABSENT,
///   so percentages are attended ÷ held.
/// * **Who marked:** every record keeps `markedBy` (SELF / TEACHER) and teacher
///   edits are logged in `editLog`.
abstract class ClassAttendanceService {
  static const rotateEvery = Duration(seconds: 20);

  Future<AttendanceSession> startClassSession({
    required String courseId,
    String mode = 'CODE',
    int durationMinutes = 15,
    int lateAfterMinutes = 10,
    String? slotId,
  });

  /// Issues a new code (teacher only). Returns it.
  Future<String> rotateCode(String sessionId);

  Future<DateTime> extendSession(String sessionId, {int minutes = 5});

  /// Live marks for a session, as roster items (only students with a record).
  Stream<List<AttendanceRosterItem>> watchMarks(String sessionId);

  /// Teacher sets the status of these students (writes only these).
  Future<void> saveMarks({required String sessionId, required List<AttendanceRosterItem> items});

  /// Keeps `attendanceSessions/{sessionId}.totalPresentCount` synced live.
  Future<void> updateSessionPresentCount(String sessionId, int presentCount);

  /// Records everyone without a mark as ABSENT, saves the count and closes.
  Future<void> finishSession({required String sessionId, required List<AttendanceRosterItem> roster});

  /// The current teacher's sessions from the last [days] days, newest first.
  Future<List<AttendanceSession>> recentSessions({int days = 7});

  Future<CourseAttendanceReport> courseReport(String courseId);

  /// Student: classes of their semester taking attendance by code right now.
  Future<List<AttendanceSession>> openSessionsForMe();

  /// Student: mark attendance with the code on the teacher's screen. With
  /// [sessionId] the code is checked against that one class only.
  Future<AttendanceVerificationResult> markWithCode(String code, {String? courseId, String? sessionId});

  /// Student: attended ÷ held per course for their semester.
  /// [year] / [semester]: a past semester to look back at (default: current).
  Future<AttendanceSummary> mySummary({int? year, int? semester});
}

class ClassAttendanceServiceImpl implements ClassAttendanceService {
  final FirebaseFirestore _db;
  final fb.FirebaseAuth _auth;

  ClassAttendanceServiceImpl({FirebaseFirestore? firestore, fb.FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _sessions => _db.collection('attendanceSessions');
  CollectionReference<Map<String, dynamic>> get _records => _db.collection('attendance');
  DocumentReference<Map<String, dynamic>> _codeDoc(String sessionId) =>
      _sessions.doc(sessionId).collection('private').doc('code');

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const ServerException(message: 'Not signed in.');
    return uid;
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String newCode() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // no 0/O/1/I
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static bool _denied(Object e) =>
      e is FirebaseException && e.code == 'permission-denied' ||
      e.toString().toLowerCase().contains('permission');

  // ─── Teacher ─────────────────────────────────────────────────────────────

  @override
  Future<AttendanceSession> startClassSession({
    required String courseId,
    String mode = 'CODE',
    int durationMinutes = 15,
    int lateAfterMinutes = 10,
    String? slotId,
  }) async {
    final uid = _uid;
    final courseDoc = await _db.collection('courses').doc(courseId).get();
    if (!courseDoc.exists) throw const ServerException(message: 'Course not found.');
    final course = courseDoc.data()!;
    final me = (await _db.collection('users').doc(uid).get()).data() ?? const {};

    // Close this teacher's other open sessions for the course.
    final open = await _sessions
        .where('courseId', isEqualTo: courseId)
        .where('teacherId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .get();
    for (final d in open.docs) {
      await d.reference.update({'isActive': false, 'status': 'COMPLETED', 'closedAt': FieldValue.serverTimestamp()});
    }

    final manual = mode.toUpperCase() == 'MANUAL';
    // S2-10: real moment from the server-corrected clock; the day in Dhaka.
    final now = ClassTime.instant();
    final expiresAt = now.add(Duration(minutes: manual ? 180 : durationMinutes));
    final lateAfter = now.add(Duration(minutes: lateAfterMinutes));
    final ref = _sessions.doc();
    final code = manual ? '' : newCode();
    final data = <String, dynamic>{
      'id': ref.id,
      'courseId': courseId,
      'courseCode': course['code'] ?? courseId,
      'courseTitle': course['title'] ?? '',
      'teacherId': uid,
      'teacherName': (me['fullName'] ?? me['name'] ?? course['teacherName'] ?? '') as String,
      'mode': manual ? 'MANUAL' : 'CODE',
      'isActive': true,
      'status': 'ACTIVE',
      'sessionDate': ClassTime.todayKey(),
      'startTime': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'lateAfter': Timestamp.fromDate(lateAfter),
      'targetYear': (course['year'] as num?)?.toInt() ?? 1,
      'targetSemester': (course['semester'] as num?)?.toInt() ?? 1,
      if (slotId != null) 'slotId': slotId,
      'totalPresentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch()..set(ref, data);
    if (!manual) {
      batch.set(_codeDoc(ref.id), {'code': code, 'prevCode': '', 'issuedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();

    return AttendanceSessionModel.fromJson({
      ...data,
      'code': code,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'lateAfter': Timestamp.fromDate(lateAfter),
      'createdAt': now.toIso8601String(),
    });
  }

  @override
  Future<String> rotateCode(String sessionId) async {
    final ref = _codeDoc(sessionId);
    final old = (await ref.get()).data()?['code'] as String? ?? '';
    final code = newCode();
    await ref.set({'code': code, 'prevCode': old, 'issuedAt': FieldValue.serverTimestamp()});
    return code;
  }

  @override
  Future<DateTime> extendSession(String sessionId, {int minutes = 5}) async {
    final ref = _sessions.doc(sessionId);
    final cur = ((await ref.get()).data()?['expiresAt'] as Timestamp?)?.toDate() ?? ClassTime.instant();
    final base = cur.isAfter(ClassTime.instant()) ? cur : ClassTime.instant();
    final next = base.add(Duration(minutes: minutes));
    await ref.update({'expiresAt': Timestamp.fromDate(next), 'updatedAt': FieldValue.serverTimestamp()});
    return next;
  }

  static AttendanceRosterItem _markFrom(Map<String, dynamic> d) => AttendanceRosterItemModel.fromJson({
        ...d,
        'markedBy': d['markedBy'] ?? ((d['isManualOverride'] as bool? ?? false) ? 'TEACHER' : 'SELF'),
      });

  @override
  Stream<List<AttendanceRosterItem>> watchMarks(String sessionId) => _records
      .where('sessionId', isEqualTo: sessionId)
      .snapshots()
      .map((s) => s.docs.map((d) => _markFrom(d.data())).toList());

  @override
  Future<void> saveMarks({required String sessionId, required List<AttendanceRosterItem> items}) async {
    if (items.isEmpty) return;
    final uid = _uid;
    final s = (await _sessions.doc(sessionId).get()).data();
    if (s == null) throw const ServerException(message: 'Session not found.');
    final at = DateTime.now().toIso8601String();
    for (var i = 0; i < items.length; i += 400) {
      final batch = _db.batch();
      for (final item in items.skip(i).take(400)) {
        final id = '${sessionId}_${item.studentId}';
        batch.set(
          _records.doc(id),
          {
            'id': id,
            'sessionId': sessionId,
            'studentId': item.studentId,
            'studentName': item.studentName,
            'studentRoll': item.studentRoll,
            'courseId': s['courseId'],
            'courseCode': s['courseCode'],
            'courseTitle': s['courseTitle'],
            'status': item.status,
            'markedBy': 'TEACHER',
            'markedById': uid,
            'isManualOverride': true,
            'date': s['sessionDate'],
            if ((s['slotId'] as String? ?? '').isNotEmpty) 'slotId': s['slotId'],
            'verifiedAt': item.isPresent ? FieldValue.serverTimestamp() : null,
            'updatedAt': FieldValue.serverTimestamp(),
            'editLog': FieldValue.arrayUnion([
              {'by': uid, 'to': item.status, 'at': at}
            ]),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
    try {
      await updateSessionPresentCount(sessionId, await _countPresent(sessionId));
    } catch (_) {}
    await _updateStats(
      s['courseId'] as String? ?? '',
      ClassKeys.of(s['sessionDate'] as String? ?? '', s['slotId'] as String?),
      items,
    );
  }

  /// S2-11: keeps the small summary records in step with teacher marks.
  /// Best effort (the marks themselves are already saved).
  Future<void> _updateStats(String courseId, String date, List<AttendanceRosterItem> items) async {
    if (courseId.isEmpty || date.isEmpty) return;
    // Only students who are now present, or who had a mark that may have been
    // present: a new ABSENT for someone with no mark changes nothing.
    items = items.where((i) => i.isPresent || i.hasRecord).toList();
    try {
      for (var i = 0; i < items.length; i += 400) {
        final batch = _db.batch();
        for (final item in items.skip(i).take(400)) {
          batch.set(
            _db.collection('studentStats').doc(item.studentId),
            {
              'present': {
                courseId: item.isPresent ? FieldValue.arrayUnion([date]) : FieldValue.arrayRemove([date]),
              },
              'lastCourseId': courseId,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }
    } catch (_) {}
    try {
      await AttendanceTotals.refreshCourse(_db, courseId);
    } catch (_) {}
  }

  /// Present count from the saved records (not the on-screen roster).
  Future<int> _countPresent(String sessionId) async {
    final snap = await _records.where('sessionId', isEqualTo: sessionId).get();
    return snap.docs.where((d) {
      final st = (d.data()['status'] as String? ?? '').toUpperCase();
      return st == 'PRESENT' || st == 'LATE';
    }).length;
  }

  @override
  Future<void> updateSessionPresentCount(String sessionId, int presentCount) async {
    try {
      await _sessions.doc(sessionId).update({
        'totalPresentCount': presentCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  Future<void> finishSession({required String sessionId, required List<AttendanceRosterItem> roster}) async {
    final missing = roster.where((r) => !r.hasRecord).map((r) => r.copyWith(status: 'ABSENT')).toList();
    await saveMarks(sessionId: sessionId, items: missing);
    // Recount from the saved records: the roster on screen may be a moment
    // behind a student's own mark.
    int present;
    try {
      present = await _countPresent(sessionId);
    } catch (_) {
      present = roster.where((r) => r.hasRecord && r.isPresent).length;
    }
    await _sessions.doc(sessionId).update({
      'isActive': false,
      'status': 'COMPLETED',
      'closedAt': FieldValue.serverTimestamp(),
      'totalPresentCount': present,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // S2-11: "classes held" for this course, now that the count is final.
    try {
      final cid = (await _sessions.doc(sessionId).get()).data()?['courseId'] as String? ?? '';
      if (cid.isNotEmpty) await AttendanceTotals.refreshCourse(_db, cid);
    } catch (_) {}
  }

  @override
  Future<List<AttendanceSession>> recentSessions({int days = 7}) async {
    final uid = _uid;
    final from = dateKey(ClassTime.now().subtract(Duration(days: days)));
    final snap = await _sessions.where('teacherId', isEqualTo: uid).get();
    final list = snap.docs
        .map(AttendanceSessionModel.fromFirestore)
        .where((s) => s.sessionDate.compareTo(from) >= 0)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<CourseAttendanceReport> courseReport(String courseId) async {
    final course = (await _db.collection('courses').doc(courseId).get()).data() ?? const {};
    final today = ClassTime.todayKey();
    final sessions = await _sessions.where('courseId', isEqualTo: courseId).get();
    final records = await _records.where('courseId', isEqualTo: courseId).get();
    // One class per (day, routine slot) (S2-13); held only if someone was
    // present (an empty session is not a class — same rule everywhere).
    final keyOfSession = <String, String>{
      for (final d in sessions.docs)
        d.id: ClassKeys.of(d.data()['sessionDate'] as String? ?? '', d.data()['slotId'] as String?),
    };
    String keyOfRecord(Map<String, dynamic> r) =>
        keyOfSession[r['sessionId'] as String? ?? ''] ?? ClassKeys.of(r['date'] as String? ?? '', r['slotId'] as String?);
    final presentKeys = <String>{
      for (final d in records.docs)
        if (['PRESENT', 'LATE'].contains((d.data()['status'] as String? ?? '').toUpperCase())) keyOfRecord(d.data()),
    };
    final dates = ClassKeys.normalize({
      for (final d in sessions.docs)
        if (((d.data()['totalPresentCount'] as num?)?.toInt() ?? 0) > 0 || presentKeys.contains(keyOfSession[d.id]))
          keyOfSession[d.id]!,
    }.where((k) => ClassKeys.dateOf(k).isNotEmpty && ClassKeys.dateOf(k).compareTo(today) <= 0)).toList()
      ..sort();
    final attended = <String, Set<String>>{};
    final late = <String, Set<String>>{};
    final names = <String, (String, String)>{};
    for (final d in records.docs) {
      final r = d.data();
      final sid = r['studentId'] as String? ?? '';
      final date = keyOfRecord(r);
      final status = (r['status'] as String? ?? '').toUpperCase();
      names[sid] = ((r['studentRoll'] as String?) ?? '', (r['studentName'] as String?) ?? '');
      if (status == 'PRESENT' || status == 'LATE') attended.putIfAbsent(sid, () => {}).add(date);
      if (status == 'LATE') late.putIfAbsent(sid, () => {}).add(date);
    }
    final year = (course['year'] as num?)?.toInt();
    final sem = (course['semester'] as num?)?.toInt();
    final cohortIds = <String>{};
    final sessionVotes = <String, int>{};
    if (year != null && sem != null) {
      final students = await _db.collection('users').where('year', isEqualTo: year).where('semester', isEqualTo: sem).get();
      for (final d in students.docs) {
        final role = (d.data()['role'] as String? ?? '').toUpperCase();
        if (role != 'STUDENT' && role != 'CR') continue;
        cohortIds.add(d.id);
        final ses = (d.data()['session'] as String? ?? '').trim();
        if (ses.isNotEmpty) sessionVotes[ses] = (sessionVotes[ses] ?? 0) + 1;
        names.putIfAbsent(d.id, () => ((d.data()['studentId'] as String?) ?? '', (d.data()['fullName'] as String?) ?? ''));
      }
    }
    // Retake / explicit enrollments: listed, and counted from their enrollment date.
    final since = <String, String>{};
    try {
      final enrollSnap = await _db.collection('enrollments').where('courseId', isEqualTo: courseId).get();
      for (final enr in enrollSnap.docs) {
        final sid = (enr.data()['studentId'] as String? ?? '').trim();
        final from = enrolledSinceKey(enr.data());
        if (sid.isNotEmpty && from != null && !cohortIds.contains(sid)) {
          since[sid] = from;
        }
        if (sid.isEmpty || names.containsKey(sid)) continue;
        final uDoc = await _db.collection('users').doc(sid).get();
        if (uDoc.exists && uDoc.data() != null) {
          final u = uDoc.data()!;
          names.putIfAbsent(sid, () => ((u['studentId'] as String?) ?? '', (u['fullName'] as String?) ?? ''));
        }
      }
    } catch (_) {}
    var teacherName = (course['teacherName'] as String? ?? '').trim();
    if (teacherName.isEmpty) {
      final tid = (course['teacherId'] as String? ?? '').trim();
      if (tid.isNotEmpty) {
        try {
          final tDoc = await _db.collection('users').doc(tid).get();
          final tData = tDoc.data();
          if (tData != null) {
            teacherName =
                ((tData['fullName'] as String?) ??
                        (tData['name'] as String?) ??
                        '')
                    .trim();
          }
        } catch (_) {}
      }
    }
    if (teacherName.isEmpty) {
      for (final s in sessions.docs) {
        final tn = (s.data()['teacherName'] as String? ?? '').trim();
        if (tn.isNotEmpty) {
          teacherName = tn;
          break;
        }
      }
    }

    final dateSet = dates.toSet();
    final rows = names.entries
        .map((e) {
          final from = since[e.key];
          final myDates = from == null ? dateSet : dateSet.where((d) => ClassKeys.dateOf(d).compareTo(from) >= 0).toSet();
          final presentDates = ClassKeys.match(myDates, attended[e.key] ?? const <String>{}).$1;
          return StudentAttendanceRow(
            studentId: e.key,
            studentRoll: e.value.$1,
            studentName: e.value.$2,
            attended: presentDates.length,
            late: (late[e.key] ?? const <String>{}).intersection(myDates).length,
            held: myDates.length,
            presentDates: presentDates,
          );
        })
        .toList()
      ..sort((a, b) => a.studentRoll.compareTo(b.studentRoll));
    return CourseAttendanceReport(
      courseId: courseId,
      courseCode: (course['code'] as String?) ?? courseId,
      courseTitle: (course['title'] as String?) ?? '',
      teacherName: teacherName,
      classDates: dates,
      rows: rows,
      year: year,
      semester: sem,
      // The batch's session: the one most of its students have.
      session: sessionVotes.isEmpty
          ? null
          : (sessionVotes.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key,
      generatedOn: ClassTime.todayKey(),
    );
  }

  // ─── Student ─────────────────────────────────────────────────────────────

  /// "yyyy-MM-dd" from which an enrollment's classes count: `enrolledOn`,
  /// else `createdAt`, else null (count every class).
  static String? enrolledSinceKey(Map<String, dynamic> data) {
    final on = (data['enrolledOn'] as String?)?.trim() ?? '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(on)) return on;
    final created = data['createdAt'];
    if (created is Timestamp) return dateKey(created.toDate());
    if (created is String) {
      final d = DateTime.tryParse(created);
      if (d != null) return dateKey(d);
    }
    return null;
  }

  /// courseId → since-date for the student's explicit enrollments.
  Future<Map<String, String?>> _enrollmentsSince(String uid) async {
    try {
      final snap = await _db.collection('enrollments').where('studentId', isEqualTo: uid).get();
      final out = <String, String?>{};
      for (final d in snap.docs) {
        final cid = (d.data()['courseId'] as String? ?? '').trim();
        if (cid.isNotEmpty) out[cid] = enrolledSinceKey(d.data());
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  Future<Set<String>> _enrolledCourseIds(String uid) async {
    try {
      final snap = await _db.collection('enrollments').where('studentId', isEqualTo: uid).get();
      return snap.docs
          .map((d) => (d.data()['courseId'] as String? ?? '').trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<(Map<String, dynamic>, List<AttendanceSession>)> _openForMe() async {
    final uid = _uid;
    final me = (await _db.collection('users').doc(uid).get()).data() ?? const {};
    final year = (me['year'] as num?)?.toInt();
    final sem = (me['semester'] as num?)?.toInt();
    final enrolled = await _enrolledCourseIds(uid);
    if ((year == null || sem == null) && enrolled.isEmpty) {
      throw const ServerException(message: 'Your semester is not set yet.');
    }

    final now = ClassTime.instant();
    final byId = <String, AttendanceSession>{};

    if (year != null && sem != null) {
      final semSnap = await _sessions
          .where('targetYear', isEqualTo: year)
          .where('targetSemester', isEqualTo: sem)
          .where('isActive', isEqualTo: true)
          .get();
      for (final d in semSnap.docs) {
        final s = AttendanceSessionModel.fromFirestore(d);
        if (!s.isManualMode && (s.expiresAt?.isAfter(now) ?? false)) {
          byId[s.id] = s;
        }
      }
    }

    if (enrolled.isNotEmpty) {
      final list = enrolled.toList();
      for (var i = 0; i < list.length; i += 10) {
        final chunk = list.skip(i).take(10).toList();
        try {
          final snap = await _sessions
              .where('courseId', whereIn: chunk)
              .where('isActive', isEqualTo: true)
              .get();
          for (final d in snap.docs) {
            final s = AttendanceSessionModel.fromFirestore(d);
            if (!s.isManualMode && (s.expiresAt?.isAfter(now) ?? false)) {
              byId[s.id] = s;
            }
          }
        } catch (_) {}
      }
    }

    final open = byId.values.toList()
      ..sort((a, b) => (a.expiresAt ?? now).compareTo(b.expiresAt ?? now));
    return (me, open);
  }

  @override
  Future<List<AttendanceSession>> openSessionsForMe() async => (await _openForMe()).$2;

  @override
  Future<AttendanceVerificationResult> markWithCode(String code, {String? courseId, String? sessionId}) async {
    final uid = _uid;
    final clean = code.trim().toUpperCase();
    if (clean.length != 6) throw const ServerException(message: 'The code has 6 characters.');
    final found = await _openForMe();
    final me = found.$1;
    final open = found.$2
        .where((s) => sessionId == null || s.id == sessionId)
        .where((s) => courseId == null || s.courseId == courseId)
        .toList();
    if (open.isEmpty) {
      throw ServerException(
        message: sessionId != null
            ? 'That class is no longer taking attendance.'
            : 'No class is taking attendance for your semester right now.',
      );
    }
    // Several classes open at once (e.g. lab groups): the student must choose.
    if (sessionId == null && open.length > 1) {
      throw const ServerException(message: 'More than one class is open. Tap your class first, then enter the code.');
    }

    for (final s in open) {
      final ref = _records.doc('${s.id}_$uid');
      final existing = await ref.get();
      if (existing.exists) {
        final st = (existing.data()?['status'] as String? ?? '').toUpperCase();
        if (st == 'PRESENT' || st == 'LATE') {
          throw ServerException(message: 'You are already marked for ${s.courseTitle.isNotEmpty ? s.courseTitle : s.courseCode}.');
        }
        throw const ServerException(message: 'Your teacher has already marked you. Ask them to change it.');
      }
      try {
        // The record and +1 on the session's present count are one write, so
        // the class counts as held even if the teacher's phone is closed
        // (S2-03). The rules only allow the +1 together with a valid mark.
        final batch = _db.batch()
          ..set(ref, {
          'id': ref.id,
          'sessionId': s.id,
          'studentId': uid,
          'studentName': (me['fullName'] ?? '') as String,
          'studentRoll': (me['studentId'] ?? '') as String,
          'courseId': s.courseId,
          'courseCode': s.courseCode,
          'courseTitle': s.courseTitle,
          'status': 'PRESENT',
          'markedBy': 'SELF',
          'codeUsed': clean,
          'isManualOverride': false,
          'date': s.sessionDate,
          if ((s.slotId ?? '').isNotEmpty) 'slotId': s.slotId,
          'verifiedAt': FieldValue.serverTimestamp(),
        })
          ..update(_sessions.doc(s.id), {'totalPresentCount': FieldValue.increment(1)})
          // S2-11: the student's own present days (their display copy).
          ..set(
            _db.collection('studentStats').doc(uid),
            {
              'present': {s.courseId: FieldValue.arrayUnion([ClassKeys.of(s.sessionDate, s.slotId)])},
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        await batch.commit();
        final name = s.courseTitle.isNotEmpty ? s.courseTitle : s.courseCode;
        return AttendanceVerificationResult(
          success: true,
          message: 'You are marked present for $name.',
          courseCode: s.courseCode,
          courseTitle: s.courseTitle,
          recordId: ref.id,
        );
      } catch (e) {
        if (!_denied(e)) rethrow;
        // Wrong code for this session: try next.
      }
    }
    throw const ServerException(message: 'Wrong or expired code. Use the code on the teacher\'s screen right now.');
  }

  @override
  Future<AttendanceSummary> mySummary({int? year, int? semester}) async {
    final pickYear = year;
    final pickSem = semester;
    return _summaryFor(pickYear, pickSem);
  }

  Future<AttendanceSummary> _summaryFor(int? pickYear, int? pickSem) async {
    final uid = _uid;
    final me = (await _db.collection('users').doc(uid).get()).data() ?? const {};
    final myYear = (me['year'] as num?)?.toInt();
    final mySem = (me['semester'] as num?)?.toInt();
    // S2-05: past semesters stay visible after promotion. Retakes belong to
    // the current semester's view only.
    final year = pickYear ?? myYear;
    final sem = pickSem ?? mySem;
    final isCurrent = year == myYear && sem == mySem;
    final since = isCurrent ? await _enrollmentsSince(uid) : const <String, String?>{};

    // S2-11: a few small records instead of every session and mark.
    final totals = AttendanceTotals(_db);
    final courses = await totals.coursesOf(year, sem, extraIds: since.keys);
    return totals.summary(uid: uid, courses: courses, since: since, today: ClassTime.todayKey());
  }

}
