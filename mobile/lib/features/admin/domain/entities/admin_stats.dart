class AdminOverviewStats {
  final int totalStudents;
  final int totalTeachers;
  final int totalCrs;
  final int totalCourses;
  final int pendingSignups;
  final int pendingSemesterRequests;
  final int activeSessions;

  const AdminOverviewStats({
    this.totalStudents = 0,
    this.totalTeachers = 0,
    this.totalCrs = 0,
    this.totalCourses = 0,
    this.pendingSignups = 0,
    this.pendingSemesterRequests = 0,
    this.activeSessions = 0,
  });

  int get totalUsers => totalStudents + totalTeachers + totalCrs;

  AdminOverviewStats copyWith({
    int? totalStudents,
    int? totalTeachers,
    int? totalCrs,
    int? totalCourses,
    int? pendingSignups,
    int? pendingSemesterRequests,
    int? activeSessions,
  }) {
    return AdminOverviewStats(
      totalStudents: totalStudents ?? this.totalStudents,
      totalTeachers: totalTeachers ?? this.totalTeachers,
      totalCrs: totalCrs ?? this.totalCrs,
      totalCourses: totalCourses ?? this.totalCourses,
      pendingSignups: pendingSignups ?? this.pendingSignups,
      pendingSemesterRequests: pendingSemesterRequests ?? this.pendingSemesterRequests,
      activeSessions: activeSessions ?? this.activeSessions,
    );
  }
}
