import 'package:cloud_firestore/cloud_firestore.dart';

/// One student in a batch preview.
class BatchStudent {
  final String id;
  final String name;
  final String roll;
  final String? session;
  final bool isCr;
  const BatchStudent({required this.id, required this.name, required this.roll, this.session, required this.isCr});
}

/// "Promote batch" (S2-05): move a whole semester (optionally one session) to
/// the next semester in one go. Admin / Chairman only (checked by the rules).
///
/// CRs stay CR, because the whole batch moves together. Pending semester
/// requests of these students are closed: approved if they asked for exactly
/// the new semester, otherwise rejected with a note.
class BatchPromotionService {
  final FirebaseFirestore _db;
  BatchPromotionService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  /// The semester after (year, semester), or null after 4-2 (final).
  static (int, int)? nextOf(int year, int semester) {
    if (semester == 1) return (year, 2);
    if (year >= 4) return null;
    return (year + 1, 1);
  }

  /// Active students and CRs of a year / semester (optionally one session).
  Future<List<BatchStudent>> preview({required int year, required int semester, String? session}) async {
    final snap = await _db
        .collection('users')
        .where('year', isEqualTo: year)
        .where('semester', isEqualTo: semester)
        .get();
    final list = <BatchStudent>[];
    for (final d in snap.docs) {
      final u = d.data();
      final role = (u['role'] as String? ?? '').toUpperCase();
      if (role != 'STUDENT' && role != 'CR') continue;
      if (u['isActive'] == false) continue;
      final s = u['session'] as String?;
      if (session != null && session.isNotEmpty && s != session) continue;
      list.add(BatchStudent(
        id: d.id,
        name: (u['fullName'] as String?) ?? '',
        roll: (u['studentId'] as String?) ?? '',
        session: s,
        isCr: role == 'CR' || u['isCR'] == true,
      ));
    }
    list.sort((a, b) => a.roll.compareTo(b.roll));
    return list;
  }

  /// Moves [studentIds] from (year, semester) to the next semester. Returns
  /// how many were moved.
  Future<int> promote({
    required int year,
    required int semester,
    required List<String> studentIds,
    required String actorId,
  }) async {
    final next = nextOf(year, semester);
    if (next == null) {
      throw StateError('Year 4, Semester 2 is the final semester; there is nothing to promote to.');
    }
    if (studentIds.isEmpty) return 0;
    final (ny, ns) = next;
    final ids = studentIds.toSet();

    // Their pending semester requests (one query, filtered here).
    final pending = await _db.collection('semesterUpgradeRequests').where('status', isEqualTo: 'PENDING').get();
    final requestsByStudent = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final r in pending.docs) {
      final sid = r.data()['studentId'] as String? ?? '';
      if (ids.contains(sid)) requestsByStudent.putIfAbsent(sid, () => []).add(r);
    }

    var moved = 0;
    final idList = ids.toList();
    // Up to 5 writes per student (user, requests, notice): 80 students per batch.
    for (var i = 0; i < idList.length; i += 80) {
      final batch = _db.batch();
      for (final sid in idList.skip(i).take(80)) {
        final ref = _db.collection('users').doc(sid);
        final cur = (await ref.get()).data();
        // Only students still in that semester (someone may have moved already).
        if (cur == null || cur['year'] != year || cur['semester'] != semester) continue;
        batch.update(ref, {'year': ny, 'semester': ns, 'updatedAt': FieldValue.serverTimestamp()});
        for (final r in requestsByStudent[sid] ?? const []) {
          final d = r.data();
          final wantY = ((d['requestedYear'] ?? d['targetYear']) as num?)?.toInt();
          final wantS = ((d['requestedSemester'] ?? d['targetSemester']) as num?)?.toInt();
          final match = wantY == ny && wantS == ns;
          batch.update(r.reference, {
            'status': match ? 'APPROVED' : 'REJECTED',
            if (match) 'approvedAt': FieldValue.serverTimestamp(),
            if (!match) 'rejectionReason': 'Your whole batch was promoted to Year $ny, Semester $ns.',
            'reviewedBy': actorId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        batch.set(_db.collection('notifications').doc(), {
          'userId': sid,
          'senderId': actorId,
          'title': 'Semester updated',
          'body': 'Your batch moved to Year $ny, Semester $ns.',
          'notificationType': 'SEMESTER',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        moved++;
      }
      await batch.commit();
    }
    return moved;
  }
}
