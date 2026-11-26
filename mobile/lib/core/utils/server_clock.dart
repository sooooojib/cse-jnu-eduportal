import 'package:cloud_firestore/cloud_firestore.dart';
import 'class_time.dart';

/// Learns how far the phone's clock is from the server's (S2-10): touches the
/// user's own `updatedAt` with the server time and reads it back. One small
/// write + read per sign-in; failures leave the offset unchanged.
class ServerClock {
  ServerClock._();

  static Future<void> sync({required FirebaseFirestore firestore, required String uid}) async {
    try {
      final ref = firestore.collection('users').doc(uid);
      final before = DateTime.now();
      await ref.update({'updatedAt': FieldValue.serverTimestamp()});
      final snap = await ref.get(const GetOptions(source: Source.server));
      final after = DateTime.now();
      final ts = snap.data()?['updatedAt'];
      if (ts is! Timestamp) return;
      final mid = before.add(after.difference(before) ~/ 2);
      ClassTime.serverOffset = ts.toDate().difference(mid);
    } catch (_) {}
  }
}
