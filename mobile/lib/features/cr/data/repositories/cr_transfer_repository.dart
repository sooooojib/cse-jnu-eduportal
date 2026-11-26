import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../core/error/error_handler.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/cr_transfer.dart';

/// Classmates list + CR role hand-over.
///
/// Works without Cloud Functions: the hand-over is a single Firestore batch
/// (transfer -> ACCEPTED, new CR -> CR, old CR -> STUDENT) and the security
/// rules only allow those role changes inside that batch for a pending
/// transfer between classmates of the same semester and session.
abstract class CrTransferRepository {
  /// Active students & CRs with the same year, semester and session as [me]
  /// (excluding [me]), sorted by name. Empty if [me] has no session.
  Future<List<User>> getClassmates(User me);

  /// The CR's own transfer (`crTransfers/{fromUid}`), live.
  Stream<CrTransfer?> watchOutgoing(String fromUid);

  /// Pending transfers offered to [toUid], live.
  Stream<List<CrTransfer>> watchIncoming(String toUid);

  Future<void> requestTransfer({required User from, required User to});
  Future<void> cancel(String fromUid);
  Future<void> decline(CrTransfer transfer);
  Future<void> accept(CrTransfer transfer, {required String myUid});
}

class CrTransferRepositoryImpl implements CrTransferRepository {
  final FirebaseFirestore _firestore;

  CrTransferRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transfers => _firestore.collection('crTransfers');

  static CrTransfer _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final created = d['createdAt'];
    return CrTransfer(
      fromUid: d['fromUid'] as String? ?? doc.id,
      fromName: d['fromName'] as String? ?? '',
      toUid: d['toUid'] as String? ?? '',
      toName: d['toName'] as String? ?? '',
      year: (d['year'] as num?)?.toInt() ?? 0,
      semester: (d['semester'] as num?)?.toInt() ?? 0,
      session: d['session'] as String? ?? '',
      status: CrTransferStatus.fromString(d['status'] as String?),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  @override
  Future<List<User>> getClassmates(User me) async {
    final session = me.session?.trim();
    if (session == null || session.isEmpty || me.year == null || me.semester == null) return const [];
    try {
      final snap = await _firestore
          .collection('users')
          .where('year', isEqualTo: me.year)
          .where('semester', isEqualTo: me.semester)
          .where('session', isEqualTo: session)
          .get();
      final list = snap.docs
          .map((d) => UserModel.fromFirestore(d))
          .where((u) => u.id != me.id && u.isActive && u.role.isStudentSide)
          .toList()
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      return list;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Stream<CrTransfer?> watchOutgoing(String fromUid) {
    return _transfers.doc(fromUid).snapshots().map((doc) => doc.exists ? _fromDoc(doc) : null);
  }

  @override
  Stream<List<CrTransfer>> watchIncoming(String toUid) {
    return _transfers
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: CrTransferStatus.pending.value)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  Map<String, dynamic> _notification(String userId, String title, String body, String fromUid) {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'notificationType': 'CR_TRANSFER',
      'referenceId': fromUid,
      'referenceType': 'CR_TRANSFER',
      'route': '/dashboard/student',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  Future<void> requestTransfer({required User from, required User to}) async {
    if (from.role != UserRole.cr) {
      throw StateError('Only the current CR can transfer the CR role.');
    }
    try {
      final batch = _firestore.batch();
      batch.set(_transfers.doc(from.id), {
        'fromUid': from.id,
        'fromName': from.fullName,
        'toUid': to.id,
        'toName': to.fullName,
        'year': from.year,
        'semester': from.semester,
        'session': from.session,
        'status': CrTransferStatus.pending.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'id': notifRef.id,
        ..._notification(
          to.id,
          'CR Role Offered',
          '${from.fullName} wants to transfer the Class Representative role to you. Open your dashboard to accept or decline.',
          from.id,
        ),
      });
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> cancel(String fromUid) async {
    try {
      await _transfers.doc(fromUid).update({
        'status': CrTransferStatus.cancelled.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> decline(CrTransfer transfer) async {
    try {
      final batch = _firestore.batch();
      batch.update(_transfers.doc(transfer.fromUid), {
        'status': CrTransferStatus.declined.value,
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'id': notifRef.id,
        ..._notification(
          transfer.fromUid,
          'CR Transfer Declined',
          '${transfer.toName} declined the CR role. You are still the Class Representative.',
          transfer.fromUid,
        ),
      });
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> accept(CrTransfer transfer, {required String myUid}) async {
    if (myUid != transfer.toUid) {
      throw StateError('Only the invited classmate can accept this transfer.');
    }
    try {
      final now = FieldValue.serverTimestamp();
      final batch = _firestore.batch();
      batch.update(_transfers.doc(transfer.fromUid), {
        'status': CrTransferStatus.accepted.value,
        'respondedAt': now,
        'updatedAt': now,
      });
      // New CR (me).
      batch.update(_firestore.collection('users').doc(myUid), {
        'role': UserRole.cr.value,
        'isCR': true,
        'crTransferRef': transfer.fromUid,
        'updatedAt': now,
      });
      // Old CR becomes a regular student.
      batch.update(_firestore.collection('users').doc(transfer.fromUid), {
        'role': UserRole.student.value,
        'isCR': false,
        'crTransferRef': transfer.fromUid,
        'updatedAt': now,
      });
      final notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'id': notifRef.id,
        ..._notification(
          transfer.fromUid,
          'CR Role Transferred',
          '${transfer.toName} accepted. They are now the Class Representative.',
          transfer.fromUid,
        ),
      });
      await batch.commit();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
