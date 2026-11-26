import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cse_jnu_eduportal/core/error/exceptions.dart';
import 'package:cse_jnu_eduportal/core/error/failures.dart';
import 'package:cse_jnu_eduportal/core/error/friendly_error.dart';

/// S2-12: every error reads as a plain sentence.
void main() {
  test('Firestore codes', () {
    expect(friendlyError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied', message: 'x')), "You don't have permission to do this.");
    expect(friendlyError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), contains('No internet'));
    expect(friendlyError(FirebaseException(plugin: 'cloud_firestore', code: 'resource-exhausted')), contains('free usage limit'));
  });

  test('raw text from old code paths', () {
    expect(friendlyError('[cloud_firestore/permission-denied] The caller does not have permission'), "You don't have permission to do this.");
    expect(friendlyError(Exception('SocketException: Failed host lookup')), contains('No internet'));
    expect(friendlyError('The query requires an index. You can create it here: https://...'), contains('being prepared'));
    expect(friendlyError(const ServerFailure(message: 'Error: [cloud_firestore/not-found] Some doc')), contains('no longer exists'));
  });

  test('human messages pass through, technical prefixes are removed', () {
    expect(friendlyError(const ValidationException(message: 'Wrong password.', validationErrors: [])), 'Wrong password.');
    expect(friendlyError(Exception('Your semester is not set yet.')), 'Your semester is not set yet.');
    expect(friendlyError(const ServerException(message: 'That class is no longer taking attendance.')), 'That class is no longer taking attendance.');
  });

  test('programming errors become a generic sentence', () {
    expect(friendlyError(TypeError()), 'Something went wrong. Please try again.');
    expect(friendlyError(StateError('Bad state: No element')), 'Something went wrong. Please try again.');
    expect(friendlyError(null), 'Something went wrong. Please try again.');
  });
}
