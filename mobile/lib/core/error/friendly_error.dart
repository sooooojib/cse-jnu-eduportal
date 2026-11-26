import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'exceptions.dart';
import 'failures.dart';

/// S2-12: turns any error into one plain sentence for message bars and
/// error panels. Messages written for people (our own validation texts) pass
/// through; technical ones ("[cloud_firestore/permission-denied] ...",
/// "Exception: ...", type errors) become a simple explanation.
String friendlyError(Object? error) {
  if (error == null) return FriendlyErrors.generic;
  if (error is fb.FirebaseAuthException) return FriendlyErrors.forAuthCode(error.code) ?? FriendlyErrors.clean(error.message ?? '');
  if (error is FirebaseException) return FriendlyErrors.forCode(error.code) ?? FriendlyErrors.clean(error.message ?? '');
  if (error is Failure) return FriendlyErrors.forCode(error.code ?? '') ?? FriendlyErrors.clean(error.message);
  if (error is AppException) return FriendlyErrors.forCode(error.code ?? '') ?? FriendlyErrors.clean(error.message);
  return FriendlyErrors.clean(error.toString());
}

class FriendlyErrors {
  FriendlyErrors._();

  static const generic = 'Something went wrong. Please try again.';
  static const permission = "You don't have permission to do this.";
  static const offline = 'No internet connection. Check your connection and try again.';
  static const slow = 'This is taking too long. Check your connection and try again.';
  static const missing = 'That item no longer exists. Pull down to refresh.';
  static const signIn = 'Please sign in again.';
  static const quota = "The app has reached today's free usage limit. Please try again tomorrow.";
  static const preparing = 'This list is still being prepared. Please try again in a few minutes.';
  static const exists = 'That already exists.';
  static const busy = 'Too many attempts. Please wait a moment and try again.';

  /// Firestore / Functions error codes.
  static String? forCode(String code) {
    switch (code.toLowerCase().replaceAll('_', '-')) {
      case 'permission-denied':
        return permission;
      case 'unavailable':
      case 'network-request-failed':
        return offline;
      case 'deadline-exceeded':
        return slow;
      case 'not-found':
        return missing;
      case 'unauthenticated':
        return signIn;
      case 'resource-exhausted':
        return quota;
      case 'already-exists':
        return exists;
      case 'failed-precondition':
        return preparing;
      default:
        return null;
    }
  }

  static String? forAuthCode(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Wrong email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return busy;
      case 'network-request-failed':
        return offline;
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Choose a longer password (at least 6 characters).';
      case 'invalid-email':
        return "That email address doesn't look right.";
      case 'requires-recent-login':
        return signIn;
      default:
        return null;
    }
  }

  /// Recognises raw technical text; keeps sentences written for people.
  static String clean(String raw) {
    var msg = raw.trim();
    final lower = msg.toLowerCase();
    if (lower.contains('permission-denied') || lower.contains('permission_denied') || lower.contains('insufficient permissions')) {
      return permission;
    }
    if (lower.contains('resource-exhausted') || lower.contains('quota')) return quota;
    if (lower.contains('requires an index') || (lower.contains('failed-precondition') && lower.contains('index'))) return preparing;
    if (lower.contains('socketexception') || lower.contains('failed host lookup') || lower.contains('[cloud_firestore/unavailable]') ||
        lower.contains('network-request-failed') || lower.contains('network is unreachable')) {
      return offline;
    }
    if (lower.contains('deadline-exceeded') || lower.contains('timeoutexception') || lower.contains('timed out')) return slow;
    if (lower.contains('[cloud_firestore/not-found]') || lower.contains('no document to update')) return missing;
    if (lower.contains('unauthenticated')) return signIn;

    // Strip "[plugin/code] ", "Exception: ", "ServerException(message: ...)".
    msg = msg.replaceFirst(RegExp(r'^\[[\w_/-]+\]\s*'), '');
    final wrapped = RegExp(r'^\w*(Exception|Failure)\(message: (.*?)(, code: .*)?\)$').firstMatch(msg);
    if (wrapped != null) msg = wrapped.group(2)!;
    msg = msg.replaceFirst(RegExp(r'^(\w*(Exception|Failure|Error)):\s*'), '');

    if (msg.isEmpty ||
        RegExp(r"Instance of|_TypeError|type '.*' is not a subtype|Null check operator|NoSuchMethodError|RangeError|Bad state|LateInitializationError|UnimplementedError|PlatformException|MissingPluginException")
            .hasMatch(msg)) {
      return generic;
    }
    return msg;
  }
}
