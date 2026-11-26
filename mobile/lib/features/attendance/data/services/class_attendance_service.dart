import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/attendance_entities.dart';
import '../models/attendance_models.dart';

/// Attendance without Cloud Functions, protected by security rules.
///
/// * **Rotating code:** the session document holds no code. The current code
///   (and the previous one) live in `attendanceSessions/{id}/private/code`,
///   readable only by the session's teacher. The teacher's screen issues a
///   new code every [rotateEvery]; the rules accept the current or previous
///   code only while the teacher's screen keeps rotating (issued < 45 s ago).
/// * **Right students only:** a student can only mark a session of their own
///   semester, once, while it is open.
/// * **On time / late:** after `lateAfter` a self-mark is LATE.
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
  Future<AttendanceSummary> mySummary();
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
    final now = DateTime.now();
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
      'sessionDate': dateKey(now),
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
    final cur = ((await ref.get()).data()?['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final base = cur.isAfter(DateTime.now()) ? cur : DateTime.now();
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
  }

  @override
  Future<void> finishSession({required String sessionId, required List<AttendanceRosterItem> roster}) async {
    final missing = roster.where((r) => !r.hasRecord).map((r) => r.copyWith(status: 'ABSENT')).toList();
    await saveMarks(sessionId: sessionId, items: missing);
    final present = roster.where((r) => r.hasRecord && r.isPresent).length;
    await _sessions.doc(sessionId).update({
      'isActive': false,
      'status': 'COMPLETED',
      'closedAt': FieldValue.serverTimestamp(),
      'totalPresentCount': present,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<AttendanceSession>> recentSessions({int days = 7}) async {
    final uid = _uid;
    final from = dateKey(DateTime.now().subtract(Duration(days: days)));
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
    final today = dateKey(DateTime.now());
    final sessions = await _sessions.where('courseId', isEqualTo: courseId).get();
    final dates = sessions.docs
        .map((d) => d.data()['sessionDate'] as String? ?? '')
        .where((d) => d.isNotEmpty && d.compareTo(today) <= 0)
        .toSet()
        .toList()
      ..sort();
    final records = await _records.where('courseId', isEqualTo: courseId).get();
    final attended = <String, Set<String>>{};
    final late = <String, Set<String>>{};
    final names = <String, (String, String)>{};
    for (final d in records.docs) {
      final r = d.data();
      final sid = r['studentId'] as String? ?? '';
      final date = r['date'] as String? ?? '';
      final status = (r['status'] as String? ?? '').toUpperCase();
      names[sid] = ((r['studentRoll'] as String?) ?? '', (r['studentName'] as String?) ?? '');
      if (status == 'PRESENT' || status == 'LATE') attended.putIfAbsent(sid, () => {}).add(date);
      if (status == 'LATE') late.putIfAbsent(sid, () => {}).add(date);
    }
    final year = (course['year'] as num?)?.toInt();
    final sem = (course['semester'] as num?)?.toInt();
    if (year != null && sem != null) {
      final students = await _db.collection('users').where('year', isEqualTo: year).where('semester', isEqualTo: sem).get();
      for (final d in students.docs) {
        final role = (d.data()['role'] as String? ?? '').toUpperCase();
        if (role != 'STUDENT' && role != 'CR') continue;
        names.putIfAbsent(d.id, () => ((d.data()['studentId'] as String?) ?? '', (d.data()['fullName'] as String?) ?? ''));
      }
    }
    final dateSet = dates.toSet();
    final rows = names.entries
        .map((e) => StudentAttendanceRow(
              studentId: e.key,
              studentRoll: e.value.$1,
              studentName: e.value.$2,
              attended: (attended[e.key] ?? const {}).intersection(dateSet).length,
              late: (late[e.key] ?? const {}).intersection(dateSet).length,
              held: dates.length,
            ))
        .toList()
      ..sort((a, b) => a.studentRoll.compareTo(b.studentRoll));
    return CourseAttendanceReport(
      courseId: courseId,
      courseCode: (course['code'] as String?) ?? courseId,
      courseTitle: (course['title'] as String?) ?? '',
      classDates: dates,
      rows: rows,
    );
  }

  // ─── Student ─────────────────────────────────────────────────────────────

  Future<(Map<String, dynamic>, List<AttendanceSession>)> _openForMe() async {
    final me = (await _db.collection('users').doc(_uid).get()).data() ?? const {};
    final year = (me['year'] as num?)?.toInt();
    final sem = (me['semester'] as num?)?.toInt();
    if (year == null || sem == null) throw const ServerException(message: 'Your semester is not set yet.');
    final now = DateTime.now();
    final open = (await _sessions
            .where('targetYear', isEqualTo: year)
            .where('targetSemester', isEqualTo: sem)
            .where('isActive', isEqualTo: true)
            .get())
        .docs
        .map(AttendanceSessionModel.fromFirestore)
        .where((s) => !s.isManualMode && (s.expiresAt?.isAfter(now) ?? false))
        .toList()
      ..sort((a, b) => (a.expiresAt ?? now).compareTo(b.expiresAt ?? now));
    return (me, open.cast<AttendanceSession>());
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
    final now = DateTime.now();
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
      final late = s.lateAfter != null && now.isAfter(s.lateAfter!);
      for (final status in late ? ['LATE', 'PRESENT'] : ['PRESENT', 'LATE']) {
        try {
          await ref.set({
            'id': ref.id,
            'sessionId': s.id,
            'studentId': uid,
            'studentName': (me['fullName'] ?? '') as String,
            'studentRoll': (me['studentId'] ?? '') as String,
            'courseId': s.courseId,
            'courseCode': s.courseCode,
            'courseTitle': s.courseTitle,
            'status': status,
            'markedBy': 'SELF',
            'codeUsed': clean,
            'isManualOverride': false,
            'date': s.sessionDate,
            'verifiedAt': FieldValue.serverTimestamp(),
          });
          final name = s.courseTitle.isNotEmpty ? s.courseTitle : s.courseCode;
          return AttendanceVerificationResult(
            success: true,
            message: status == 'LATE' ? 'Marked late for $name.' : 'You are marked present for $name.',
            courseCode: s.courseCode,
            courseTitle: s.courseTitle,
            recordId: ref.id,
          );
        } catch (e) {
          if (!_denied(e)) rethrow;
          // Wrong code for this session, or on-time / late boundary: try next.
        }
      }
    }
    throw const ServerException(message: 'Wrong or expired code. Use the code on the teacher\'s screen right now.');
  }

  @override
  Future<AttendanceSummary> mySummary() async {
    final uid = _uid;
    final me = (await _db.collection('users').doc(uid).get()).data() ?? const {};
    final year = (me['year'] as num?)?.toInt();
    final sem = (me['semester'] as num?)?.toInt();
    final today = dateKey(DateTime.now());

    final recordsSnap = await _records.where('studentId', isEqualTo: uid).get();
    final records = recordsSnap.docs.map(AttendanceRecordModel.fromFirestore).toList()
      ..sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));

    // Classes held per course = distinct days with a session for my semester.
    final held = <String, Set<String>>{};
    final titles = <String, (String, String)>{};
    if (year != null && sem != null) {
      final sessions = await _sessions.where('targetYear', isEqualTo: year).where('targetSemester', isEqualTo: sem).get();
      for (final d in sessions.docs) {
        final s = d.data();
        final cid = s['courseId'] as String? ?? '';
        final date = s['sessionDate'] as String? ?? '';
        if (cid.isEmpty || date.isEmpty || date.compareTo(today) > 0) continue;
        held.putIfAbsent(cid, () => {}).add(date);
        titles[cid] = ((s['courseCode'] as String?) ?? cid, (s['courseTitle'] as String?) ?? '');
      }
    }
    final attended = <String, Set<String>>{};
    final late = <String, Set<String>>{};
    for (final r in records) {
      final cid = r.courseId ?? '';
      if (!held.containsKey(cid)) continue;
      final st = r.status.toUpperCase();
      if (st == 'PRESENT' || st == 'LATE') attended.putIfAbsent(cid, () => {}).add(r.date ?? '');
      if (st == 'LATE') late.putIfAbsent(cid, () => {}).add(r.date ?? '');
    }

    final courses = held.entries.map((e) {
      final days = e.value;
      final went = (attended[e.key] ?? const <String>{}).intersection(days);
      final pct = days.isEmpty ? 0.0 : went.length / days.length * 100;
      final missed = days.difference(went).toList()..sort((a, b) => b.compareTo(a));
      return CourseAttendanceModel(
        courseId: e.key,
        courseCode: titles[e.key]?.$1 ?? e.key,
        courseTitle: titles[e.key]?.$2 ?? '',
        attendedClasses: went.length,
        totalClasses: days.length,
        percentage: pct,
        isEligible: pct >= 75,
        absentDates: missed,
        lateCount: (late[e.key] ?? const <String>{}).intersection(days).length,
      );
    }).toList()
      ..sort((a, b) => a.courseCode.compareTo(b.courseCode));

    final totalHeld = courses.fold<int>(0, (s, c) => s + c.totalClasses);
    final totalWent = courses.fold<int>(0, (s, c) => s + c.attendedClasses);
    return AttendanceSummaryModel(
      overallPercentage: totalHeld == 0 ? 0 : totalWent / totalHeld * 100,
      totalAttended: totalWent,
      totalSessions: totalHeld,
      courseSummaries: courses,
      recentRecords: records.take(15).toList(),
      isFromCache: recordsSnap.metadata.isFromCache,
    );
  }
}
