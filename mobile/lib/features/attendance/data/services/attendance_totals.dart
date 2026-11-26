import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_models.dart';
import '../../domain/services/class_keys.dart';

/// S2-11 (free plan): the student's attendance summary from a few small
/// records instead of every session and every mark of the semester.
///
/// * `courseStats/{courseId}.heldDates` — the days the class was held
///   (someone present). Written by the course teacher (rebuilt from that
///   course's sessions on every save / close). If missing, that one course
///   falls back to reading its sessions.
/// * `studentStats/{uid}.present.{courseId}` — the days this student was
///   present. Kept up to date by their own code marks and by teacher marks;
///   rebuilt once from their records if missing or incomplete. It is the
///   student's own display copy; official reports read the real records.
///
/// Same rule as everywhere (S2-03): a day is held if someone was present,
/// which includes this student's own present days.
class AttendanceTotals {
  final FirebaseFirestore db;
  AttendanceTotals(this.db);

  static const recentCount = 15;

  /// Rebuilds the held days of one course from its sessions and saves them.
  /// Teacher / admin only (rules); failures are ignored by callers.
  static Future<List<String>> refreshCourse(FirebaseFirestore db, String courseId) async {
    final held = await _heldFromSessions(db, courseId);
    await db.collection('courseStats').doc(courseId).set({
      'heldDates': held,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return held;
  }

  static Future<List<String>> _heldFromSessions(FirebaseFirestore db, String courseId) async {
    final snap = await db.collection('attendanceSessions').where('courseId', isEqualTo: courseId).get();
    // One class per (day, routine slot) — S2-13 double periods.
    final keys = ClassKeys.normalize({
      for (final d in snap.docs)
        if (((d.data()['totalPresentCount'] as num?)?.toInt() ?? 0) > 0 && (d.data()['sessionDate'] as String? ?? '').isNotEmpty)
          ClassKeys.of(d.data()['sessionDate'] as String, d.data()['slotId'] as String?),
    });
    return keys.toList()..sort();
  }

  /// The student's present days per course (rebuilt once if needed), and
  /// their most recent marks for the "recent" list.
  Future<(Map<String, Set<String>>, List<AttendanceRecordModel>, bool)> _myPresent(String uid, {bool withRecent = true}) async {
    final ref = db.collection('studentStats').doc(uid);
    final snap = await ref.get();
    final data = snap.data();
    if (data != null && data['complete'] == true) {
      final present = <String, Set<String>>{
        for (final e in ((data['present'] as Map?) ?? const {}).entries)
          e.key as String: {for (final d in (e.value as List? ?? const [])) d as String},
      };
      List<AttendanceRecordModel> recent = const [];
      if (withRecent) try {
        final r = await db
            .collection('attendance')
            .where('studentId', isEqualTo: uid)
            .orderBy('date', descending: true)
            .limit(recentCount)
            .get();
        recent = r.docs.map(AttendanceRecordModel.fromFirestore).toList();
      } catch (_) {}
      return (present, recent, snap.metadata.isFromCache);
    }

    // One-time rebuild from all of this student's records.
    final all = await db.collection('attendance').where('studentId', isEqualTo: uid).get();
    final records = all.docs.map(AttendanceRecordModel.fromFirestore).toList()
      ..sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
    final present = <String, Set<String>>{};
    for (final d in all.docs) {
      final r = d.data();
      final st = (r['status'] as String? ?? '').toUpperCase();
      final cid = r['courseId'] as String? ?? '';
      final date = r['date'] as String? ?? '';
      if (cid.isEmpty || date.isEmpty) continue;
      if (st == 'PRESENT' || st == 'LATE') present.putIfAbsent(cid, () => {}).add(ClassKeys.of(date, r['slotId'] as String?));
    }
    try {
      await ref.set({
        'present': {for (final e in present.entries) e.key: (e.value.toList()..sort())},
        'complete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    return (present, records.take(recentCount).toList(), all.metadata.isFromCache);
  }

  /// Held days per course, from courseStats (8-ish reads), falling back to
  /// that course's sessions when its record doesn't exist yet.
  Future<Map<String, Set<String>>> _held(Iterable<String> courseIds) async {
    final out = <String, Set<String>>{};
    for (final cid in courseIds) {
      try {
        final s = await db.collection('courseStats').doc(cid).get();
        final list = s.data()?['heldDates'];
        out[cid] = list is List
            ? {for (final d in list) d as String}
            : (await _heldFromSessions(db, cid)).toSet();
      } catch (_) {
        out[cid] = {};
      }
    }
    return out;
  }

  /// Summary for [courses] (id -> (code, title)). [since]: retake course ->
  /// first date that counts.
  Future<AttendanceSummaryModel> summary({
    required String uid,
    required Map<String, (String, String)> courses,
    Map<String, String?> since = const {},
    required String today,
    bool withRecent = true,
  }) async {
    final (present, recent, fromCache) = await _myPresent(uid, withRecent: withRecent);
    final heldByCourse = await _held(courses.keys);

    bool inRange(String cid, String key) {
      final date = ClassKeys.dateOf(key);
      if (date.isEmpty || date.compareTo(today) > 0) return false;
      final from = since[cid];
      return from == null || date.compareTo(from) >= 0;
    }

    final list = <CourseAttendanceModel>[];
    for (final e in courses.entries) {
      final cid = e.key;
      final mine = {...?present[cid]}..removeWhere((d) => !inRange(cid, d));
      final heldKeys = ClassKeys.normalize({...?heldByCourse[cid]}..removeWhere((d) => !inRange(cid, d)));
      // Own present days are held too (S2-03); old marks may lack the slot.
      final (matched, extra) = ClassKeys.match(heldKeys, mine);
      final went = {...matched, ...extra};
      final days = {...heldKeys, ...extra};
      if (days.isEmpty) continue;
      final pct = went.length / days.length * 100;
      list.add(CourseAttendanceModel(
        courseId: cid,
        courseCode: e.value.$1,
        courseTitle: e.value.$2,
        attendedClasses: went.length,
        totalClasses: days.length,
        percentage: pct,
        isEligible: pct >= 75,
        absentDates: (days.difference(went).map(ClassKeys.dateOf).toList()..sort((a, b) => b.compareTo(a))),
        lateCount: 0,
      ));
    }
    list.sort((a, b) => a.courseCode.compareTo(b.courseCode));

    final totalHeld = list.fold<int>(0, (s, c) => s + c.totalClasses);
    final totalWent = list.fold<int>(0, (s, c) => s + c.attendedClasses);
    return AttendanceSummaryModel(
      overallPercentage: totalHeld == 0 ? 0 : totalWent / totalHeld * 100,
      totalAttended: totalWent,
      totalSessions: totalHeld,
      courseSummaries: list,
      recentRecords: recent,
      isFromCache: fromCache,
    );
  }

  /// Courses of a semester (id -> (code, title)) plus [extraIds] (retakes).
  Future<Map<String, (String, String)>> coursesOf(int? year, int? semester, {Iterable<String> extraIds = const []}) async {
    final out = <String, (String, String)>{};
    if (year != null && semester != null) {
      final snap = await db.collection('courses').where('year', isEqualTo: year).where('semester', isEqualTo: semester).get();
      for (final d in snap.docs) {
        out[d.id] = ((d.data()['code'] as String?) ?? d.id, (d.data()['title'] as String?) ?? '');
      }
    }
    for (final id in extraIds) {
      if (out.containsKey(id)) continue;
      try {
        final d = await db.collection('courses').doc(id).get();
        if (d.exists) out[id] = ((d.data()?['code'] as String?) ?? id, (d.data()?['title'] as String?) ?? '');
      } catch (_) {}
    }
    return out;
  }
}
