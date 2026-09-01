import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/constants/app_constants.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final LocalStorageService localStorage;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localStorage,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<User?> authStateChanges() {
    return remoteDataSource.authStateChanges().asyncMap((fbUser) async {
      if (fbUser == null) return null;
      try {
        final doc = await _firestore.collection('users').doc(fbUser.uid).get();
        if (!doc.exists || doc.data() == null) return null;
        if (doc.data()?['isActive'] == false) return null;
        return UserModel.fromFirestore(doc);
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Future<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final authResponse = await remoteDataSource.login(
        email: email,
        password: password,
      );

      // Cache user profile locally for offline access
      await localStorage.setString(
        AppConstants.keyUserData,
        jsonEncode(authResponse.user.toJson()),
      );

      return authResponse.user;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<User> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getMe();

      await localStorage.setString(
        AppConstants.keyUserData,
        jsonEncode(user.toJson()),
      );

      return user;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await remoteDataSource.sendPasswordResetEmail(email);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await remoteDataSource.logout();
    } catch (_) {
      // Continue clearing local cache even if signOut has a network hiccup
    } finally {
      await localStorage.remove(AppConstants.keyUserData);
    }
  }

  @override
  Future<bool> hasValidSession() async {
    return fb.FirebaseAuth.instance.currentUser != null;
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
      return await remoteDataSource.submitSignupRequest(
        fullName: fullName,
        email: email,
        role: role,
        studentId: studentId,
        phone: phone,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
