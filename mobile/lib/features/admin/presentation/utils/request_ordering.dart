import '../../../auth/domain/entities/signup_request.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../profile/domain/entities/semester_status.dart';

/// Shared ordering / filtering rules for the approver screens (Admin,
/// Chairman, signup-committee faculty).
class RequestOrdering {
  RequestOrdering._();

  /// Short label for a level, e.g. Year 3 Semester 1 -> "3.1".
  static String levelLabel(int year, int semester) => '$year.$semester';

  /// "3.1" style filters offered in the User Directory, in order.
  static const List<String> levelFilters = ['1.1', '1.2', '2.1', '2.2', '3.1', '3.2', '4.1', '4.2'];

  /// Whether a student / CR is in the level given as "Y.S" (null = all).
  static bool userMatchesLevel(User user, String? level) {
    if (level == null) return true;
    if (user.year == null || user.semester == null) return false;
    return levelLabel(user.year!, user.semester!) == level;
  }

  /// Normalised session key, or null when the request has no session.
  static String? sessionOf(SignupRequest r) {
    final s = r.session?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// Filter / group value for faculty signup requests.
  static const String teacherGroup = '__teachers__';

  /// Filter / group value for Student / CR requests without a session.
  static const String noSessionGroup = '__no_session__';

  /// Group of a signup request: its session ("2021-2022"), [noSessionGroup]
  /// for students without one, or [teacherGroup] for faculty.
  static String signupGroupOf(SignupRequest r) {
    if (!r.role.isStudentSide) return teacherGroup;
    return sessionOf(r) ?? noSessionGroup;
  }

  /// Human label for a signup group, e.g. "Session 2021-22".
  static String signupGroupLabel(String group) {
    if (group == teacherGroup) return 'Teachers';
    if (group == noSessionGroup) return 'Students – session not set';
    return 'Session ${shortSession(group)}';
  }

  /// "2021-2022" -> "2021-22".
  static String shortSession(String session) {
    final parts = session.split('-');
    if (parts.length == 2 && parts[1].length == 4) return '${parts[0]}-${parts[1].substring(2)}';
    return session;
  }

  static int _groupRank(String group) =>
      group == teacherGroup ? 2 : (group == noSessionGroup ? 1 : 0);

  /// Signup requests ordered by session, oldest session first
  /// (2019-2020 before 2020-2021), then students without a session, then
  /// teachers. Within a group, newest request first.
  static List<SignupRequest> sortSignupsBySession(Iterable<SignupRequest> requests) {
    final list = requests.toList();
    list.sort((a, b) {
      final ga = signupGroupOf(a);
      final gb = signupGroupOf(b);
      if (ga != gb) {
        final byRank = _groupRank(ga).compareTo(_groupRank(gb));
        return byRank != 0 ? byRank : ga.compareTo(gb);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Groups present in [requests], in display order (sessions oldest first,
  /// then "session not set", then teachers).
  static List<String> signupGroupsIn(Iterable<SignupRequest> requests) {
    final groups = requests.map(signupGroupOf).toSet().toList()
      ..sort((a, b) {
        final byRank = _groupRank(a).compareTo(_groupRank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });
    return groups;
  }

  /// Whether [r] is in [group] (null = all).
  static bool signupInGroup(SignupRequest r, String? group) =>
      group == null || signupGroupOf(r) == group;

  /// Semester upgrade requests ordered by the semester being requested
  /// (1.1, 1.2, 2.1 ... 4.2). Within a level, oldest request first so the
  /// longest-waiting student is handled first.
  static List<SemesterUpgradeRequest> sortSemesterRequestsByTarget(
    Iterable<SemesterUpgradeRequest> requests,
  ) {
    final list = requests.toList();
    list.sort((a, b) {
      final byYear = a.requestedYear.compareTo(b.requestedYear);
      if (byYear != 0) return byYear;
      final bySem = a.requestedSemester.compareTo(b.requestedSemester);
      if (bySem != 0) return bySem;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }
}
