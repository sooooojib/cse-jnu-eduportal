import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Thrown with a message that can be shown to the user as-is.
class AccountDeletionException implements Exception {
  final String message;
  const AccountDeletionException(this.message);
  @override
  String toString() => message;
}

/// "Delete my account" for students (Google Play requirement), done on the
/// phone so it works on the free plan (no Cloud Functions).
///
/// Order matters: the password is checked first, then the student's own data
/// is removed while their profile still exists (most rules need it), then the
/// profile, and finally the login itself.
///
/// Kept by the department: attendance records (official academic records).
class AccountDeletionService {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AccountDeletionService({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  Future<void> deleteMyAccount({required String password}) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AccountDeletionException('You are not signed in.');
    }
    final uid = user.uid;

    // 1. Who may delete themselves.
    final profile = await _db.collection('users').doc(uid).get();
    final data = profile.data() ?? const <String, dynamic>{};
    final role = (data['role'] as String? ?? 'STUDENT').toUpperCase();
    if (role == 'CR' || data['isCR'] == true) {
      throw const AccountDeletionException(
          'You are the CR. Hand over the CR role to a classmate first, then delete your account.');
    }
    if (profile.exists && role != 'STUDENT') {
      throw const AccountDeletionException(
          'Staff accounts are managed by the department. Please ask the admin to remove your account.');
    }

    // 2. Confirm it's really them (also required by Firebase to delete a login).
    try {
      await user.reauthenticateWithCredential(
        fb.EmailAuthProvider.credential(email: email, password: password),
      );
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential' || e.code == 'invalid-login-credentials') {
        throw const AccountDeletionException('Wrong password.');
      }
      if (e.code == 'too-many-requests') {
        throw const AccountDeletionException('Too many attempts. Please try again later.');
      }
      if (e.code == 'network-request-failed') {
        throw const AccountDeletionException('No internet connection.');
      }
      throw AccountDeletionException(e.message ?? 'Could not confirm your password.');
    }

    try {
      // 3. Their own data, while the profile still exists.
      if (profile.exists) {
        await _deleteWhere('notifications', 'userId', uid);
        await _deleteWhere('semesterUpgradeRequests', 'studentId', uid);
        await _deleteWhere('counselingBookings', 'studentId', uid);
        await _deleteRetakes(uid);
        await _deleteFeedback(uid);
        final stats = _db.collection('studentStats').doc(uid);
        if ((await stats.get()).exists) await stats.delete();
      }

      // 4. Signup record and profile.
      final signup = _db.collection('signupRequests').doc(uid);
      if ((await signup.get()).exists) await signup.delete();
      if (profile.exists) await _db.collection('users').doc(uid).delete();
    } on FirebaseException catch (e) {
      throw AccountDeletionException('Could not remove your data (${e.code}). Nothing was lost; please try again.');
    }

    // 5. The login itself.
    try {
      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      throw AccountDeletionException(e.message ?? 'Your data was removed, but the login could not be deleted. Please try again.');
    }
  }

  Future<void> _deleteWhere(String collection, String field, String uid) async {
    final snap = await _db.collection(collection).where(field, isEqualTo: uid).get();
    await _deleteRefs(snap.docs.map((d) => d.reference).toList());
  }

  Future<void> _deleteRetakes(String uid) async {
    final snap = await _db.collection('enrollments').where('studentId', isEqualTo: uid).get();
    await _deleteRefs(snap.docs.where((d) => d.data()['type'] == 'RETAKE').map((d) => d.reference).toList());
  }

  /// Named and anonymous feedback they wrote, then the hidden identity records
  /// (the feedback delete rule checks the identity, so it goes first).
  Future<void> _deleteFeedback(String uid) async {
    final identities = await _db.collection('feedbackIdentities').where('studentId', isEqualTo: uid).get();
    final named = await _db.collection('feedback').where('studentId', isEqualTo: uid).get();
    final ids = <String>{...identities.docs.map((d) => d.id), ...named.docs.map((d) => d.id)};
    for (final id in ids) {
      final ref = _db.collection('feedback').doc(id);
      try {
        await ref.delete();
      } on FirebaseException catch (_) {
        // Already gone, or not theirs to delete: skip.
      }
    }
    await _deleteRefs(identities.docs.map((d) => d.reference).toList());
  }

  Future<void> _deleteRefs(List<DocumentReference> refs) async {
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(400)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }
}
