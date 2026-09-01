import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'exceptions.dart';
import 'failures.dart';

class ErrorHandler {
  static Failure handle(Object error) => handleException(error);

  static Failure handleException(Object error) {
    if (error is Failure) {
      return error;
    }

    if (error is AuthException) {
      return AuthFailure(message: error.message, code: error.code, statusCode: error.statusCode);
    }

    if (error is ForbiddenException) {
      return ForbiddenFailure(message: error.message, code: error.code, statusCode: error.statusCode);
    }

    if (error is ValidationException) {
      return ValidationFailure(
        message: error.message,
        validationErrors: error.validationErrors,
      );
    }

    if (error is ServerException) {
      return ServerFailure(message: error.message, code: error.code, statusCode: error.statusCode);
    }

    if (error is NetworkException) {
      return NetworkFailure(message: error.message);
    }

    if (error is CacheException) {
      return CacheFailure(message: error.message);
    }

    // Firebase Auth errors
    if (error is fb.FirebaseAuthException) {
      return _handleFirebaseAuthError(error);
    }

    // Firestore errors
    if (error is FirebaseException) {
      return _handleFirestoreError(error);
    }

    return ServerFailure(message: error.toString());
  }

  static Failure _handleFirebaseAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case "user-not-found":
      case "wrong-password":
      case "invalid-credential":
        return const AuthFailure(message: "Invalid email or password.");
      case "user-disabled":
        return const AuthFailure(message: "This account has been disabled.");
      case "too-many-requests":
        return const NetworkFailure(message: "Too many attempts. Please try again later.");
      case "network-request-failed":
        return const NetworkFailure(message: "Network error. Please check your connection.");
      default:
        return AuthFailure(message: e.message ?? "Authentication failed.");
    }
  }

  static Failure _handleFirestoreError(FirebaseException e) {
    switch (e.code) {
      case "permission-denied":
        return const ForbiddenFailure(message: "Access denied. Check Firestore security rules.");
      case "not-found":
        return const ServerFailure(message: "The requested resource was not found.");
      case "unavailable":
        return const NetworkFailure(message: "Service unavailable. Please try again.");
      case "deadline-exceeded":
        return const NetworkFailure(message: "Request timed out. Please check your network.");
      default:
        return ServerFailure(message: e.message ?? "An unexpected error occurred.");
    }
  }
}
