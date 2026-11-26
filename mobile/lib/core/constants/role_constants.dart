enum UserRole {
  student('STUDENT', 'Student'),
  cr('CR', 'Class Representative'),
  teacher('TEACHER', 'Professor / Faculty'),
  chairman('CHAIRMAN', 'Chairman'),
  admin('ADMIN', 'Administrator');

  final String value;
  final String label;

  const UserRole(this.value, this.label);

  static UserRole fromString(String role) {
    switch (role.toUpperCase()) {
      case 'STUDENT':
        return UserRole.student;
      case 'CR':
        return UserRole.cr;
      case 'TEACHER':
      case 'FACULTY':
        return UserRole.teacher;
      case 'CHAIRMAN':
        return UserRole.chairman;
      case 'ADMIN':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }

  bool get isStudent => this == UserRole.student;
  bool get isCr => this == UserRole.cr;

  /// Exact role match. Prefer [hasTeacherAccess] for capability checks.
  bool get isTeacher => this == UserRole.teacher;
  bool get isChairman => this == UserRole.chairman;

  /// Exact role match. Prefer [hasAdminAccess] for capability checks.
  bool get isAdmin => this == UserRole.admin;

  /// Roles that teach: run attendance, counseling, receive feedback,
  /// can be assigned courses. The Chairman is also faculty.
  bool get hasTeacherAccess => this == UserRole.teacher || this == UserRole.chairman;

  /// Roles with full departmental administration rights.
  bool get hasAdminAccess => this == UserRole.admin || this == UserRole.chairman;

  /// Student-side roles (attend classes, book counseling, submit feedback).
  bool get isStudentSide => this == UserRole.student || this == UserRole.cr;
}
