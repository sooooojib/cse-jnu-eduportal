import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../../core/error/exceptions.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({required String email, required String password});
  Future<UserModel> getMe();
  Future<void> logout();
  Stream<fb.User?> authStateChanges();
  Future<void> sendPasswordResetEmail(String email);
  Future<String> submitSignupRequest({
    required String fullName,
    required String email,
    required String role,
    String? studentId,
    String? phone,
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
        // Sign out immediately if profile does not exist yet (unapproved account)
        await _auth.signOut();
        throw const ServerException(
          message: 'Account not yet approved by department administrator.',
        );
      }

      final userData = doc.data()!;
      final isActive = userData['isActive'] as bool? ?? true;
      if (!isActive) {
        await _auth.signOut();
        throw const ServerException(
          message: 'Your account has been deactivated. Please contact CSE administration.',
        );
      }

      final userModel = UserModel.fromFirestore(doc);
      final idToken = await fbUser.getIdToken() ?? '';

      return AuthResponseModel(
        accessToken: idToken,
        refreshToken: fbUser.refreshToken ?? '',
        user: userModel,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(message: _mapFirebaseError(e.code));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
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

      return UserModel.fromFirestore(doc);
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(message: _mapFirebaseError(e.code));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on fb.FirebaseAuthException catch (e) {
      throw ServerException(message: _mapFirebaseError(e.code));
    } catch (e) {
      throw ServerException(message: e.toString());
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
    required String role,
    String? studentId,
    String? phone,
  }) async {
    try {
      final docRef = await _firestore.collection('signupRequests').add({
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'role': role,
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId.trim(),
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Failed to submit registration request: ${e.toString()}');
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
      default:
        return 'Authentication error: ';
    }
  }
}
