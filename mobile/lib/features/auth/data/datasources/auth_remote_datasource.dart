import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/exceptions.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({required String email, required String password});
  Future<UserModel> getMe();
  Future<void> logout();
  Stream<fb.User?> authStateChanges();
  Future<void> sendPasswordResetEmail(String email);
  Future<String> submitSignupRequest({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? studentId,
    String? phone,
    String? session,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<fb.User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final fbUser = credential.user;
      if (fbUser == null) {
        throw const ServerException(message: 'Login failed: no user returned.');
      }

      // Fetch user profile from Firestore
      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (!doc.exists || doc.data() == null) {
        // No profile yet: tell them where their signup stands, then sign out.
        var message = 'Your account is waiting for approval by a teacher or the admin.';
        try {
          final req = (await _firestore.collection('signupRequests').doc(fbUser.uid).get()).data();
          if ((req?['status'] as String?) == 'REJECTED') {
            final reason = (req?['rejectionReason'] as String? ?? '').trim();
            message = reason.isEmpty
                ? 'Your signup was not approved. Please contact the department.'
                : 'Your signup was not approved: $reason';
          }
        } catch (_) {}
        await _auth.signOut();
        throw ServerException(message: message);
      }

      final userData = doc.data()!;
      final isActive = userData['isActive'] as bool? ?? true;
      if (!isActive) {
        await _auth.signOut();
        throw const ServerException(
          message: 'Your account has been deactivated. Please contact CSE administration.',
        );
      }

      String? authoritativeRole;
      String idToken = '';
      try {
        // Force refresh=true to get a fresh token so Firestore security
        // rules can correctly evaluate role-based access on first login.
        final tokenResult = await fbUser.getIdTokenResult(true);
        authoritativeRole = tokenResult.claims?['role'] as String?;
        idToken = tokenResult.token ?? '';
        // Small delay to allow Firestore to recognise the refreshed token
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) {
        idToken = await fbUser.getIdToken(true) ?? '';
      }

      final userModel = UserModel.fromFirestore(doc, authoritativeRole: authoritativeRole);

      return AuthResponseModel(
        accessToken: idToken,
        refreshToken: fbUser.refreshToken ?? '',
        user: userModel,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(message: _mapFirebaseError(e.code));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: friendlyError(e));
    }
  }

  @override
  Future<UserModel> getMe() async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null) {
        throw const ServerException(message: 'Not authenticated.');
      }

      final doc = await _firestore.collection('users').doc(fbUser.uid).get();
      if (!doc.exists || doc.data() == null) {
        await _auth.signOut();
        throw const ServerException(message: 'User profile not found. Please log in again.');
      }

      final userData = doc.data()!;
      if (userData['isActive'] == false) {
        await _auth.signOut();
        throw const ServerException(message: 'Account has been deactivated.');
      }

      String? authoritativeRole;
      try {
        // Always force-refresh to ensure Firestore rules see the latest token.
        final tokenResult = await fbUser.getIdTokenResult(true);
        authoritativeRole = tokenResult.claims?['role'] as String?;
      } catch (_) {}

      return UserModel.fromFirestore(doc, authoritativeRole: authoritativeRole);
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(message: _mapFirebaseError(e.code));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: friendlyError(e));
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(message: _mapFirebaseError(e.code));
    } catch (e) {
      throw ServerException(message: friendlyError(e));
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<String> submitSignupRequest({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? studentId,
    String? phone,
    String? session,
  }) async {
    try {
      // 1. The person's own login, created now (free plan: no server needed).
      final normalizedEmail = email.trim().toLowerCase();
      final cred = await _auth.createUserWithEmailAndPassword(email: normalizedEmail, password: password);
      final uid = cred.user?.uid;
      if (uid == null) throw const ServerException(message: 'Could not create your account. Please try again.');

      // 2. The request, keyed by their uid, waiting for a teacher / admin.
      try {
        await _firestore.collection('signupRequests').doc(uid).set({
          'userId': uid,
          'fullName': fullName.trim(),
          'email': normalizedEmail,
          'role': role,
          if (studentId != null && studentId.isNotEmpty) 'studentId': studentId.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          if (session != null && session.isNotEmpty) 'session': session.trim(),
          'status': 'PENDING',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Don't leave a login without a request behind.
        try {
          await cred.user?.delete();
        } catch (_) {}
        rethrow;
      }

      // 3. They can't use the app until approved.
      await _auth.signOut();
      return uid;
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(message: _mapFirebaseError(e.code));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Could not send the request. ${friendlyError(e)}');
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled by the administrator.';
      case 'too-many-requests':
        return 'Too many login attempts. Please wait a moment and try again.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try signing in instead.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      default:
        return 'Authentication error: ';
    }
  }
}
