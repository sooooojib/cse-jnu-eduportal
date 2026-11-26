import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// S2-11 (free plan): for data that rarely changes (the weekly routine, the
/// course list) read the phone's offline copy, and ask the server at most
/// every [maxAge] per query. Reads from the offline copy cost nothing.
/// Pull-to-refresh calls [clear] so the next load goes to the server.
class CacheFirst {
  CacheFirst._();

  static Duration maxAge = const Duration(hours: 6);
  static const _prefix = 'cache_first_';

  static Future<QuerySnapshot<Map<String, dynamic>>> get(Query<Map<String, dynamic>> query, String key) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt('$_prefix$key');
      final now = DateTime.now().millisecondsSinceEpoch;
      if (last != null && now - last >= 0 && now - last < maxAge.inMilliseconds) {
        final cached = await query.get(const GetOptions(source: Source.cache));
        if (cached.docs.isNotEmpty) return cached;
      }
    } catch (_) {}
    final fresh = await query.get();
    if (!fresh.metadata.isFromCache) {
      try {
        await prefs?.setInt('$_prefix$key', DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}
    }
    return fresh;
  }

  /// Forget all "fresh" marks (next reads go to the server).
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
