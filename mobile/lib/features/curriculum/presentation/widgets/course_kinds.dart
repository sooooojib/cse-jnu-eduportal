import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/models/curriculum_models.dart';

/// Theory / Lab lookup for class rows.
///
/// Routine slots do not store whether a course is a lab; the course does.
/// The course list is small, so it is read once per app session and cached.
/// Widgets listen to [version] and rebuild when the list arrives.
class CourseKinds {
  CourseKinds._();

  static final Map<String, bool> _isLab = {};
  static Future<void>? _loading;

  /// Bumped whenever new course kinds are known.
  static final ValueNotifier<int> version = ValueNotifier(0);

  /// True for a lab course, false for theory, null when not known yet.
  static bool? isLab(String courseId) => _isLab[courseId];

  /// Starts the one-time load (no-op if already loading / loaded or when
  /// Firestore is not available, e.g. in widget tests).
  static void ensureLoaded() {
    if (_loading != null || !sl.isRegistered<FirebaseFirestore>()) return;
    _loading = _load();
  }

  static Future<void> _load() async {
    try {
      final snap = await sl<FirebaseFirestore>().collection('courses').get();
      for (final d in snap.docs) {
        _isLab[d.id] = CourseModel.fromFirestore(d).isLab;
      }
      version.value++;
    } catch (_) {
      // Fall back to the title-based guess; try again next session.
    }
  }

  /// For tests and screens that already have the course list.
  static void seed(Map<String, bool> kinds) {
    _isLab.addAll(kinds);
    version.value++;
  }

  @visibleForTesting
  static void reset() {
    _isLab.clear();
    _loading = null;
  }
}
