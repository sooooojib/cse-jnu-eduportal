enum UserRole {
  student('STUDENT', 'Student'),
  cr('CR', 'Class Representative'),
  teacher('TEACHER', 'Professor / Faculty'),
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
        return UserRole.teacher;
      case 'ADMIN':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }

  bool get isStudent => this == UserRole.student;
  bool get isCr => this == UserRole.cr;
  bool get isTeacher => this == UserRole.teacher;
  bool get isAdmin => this == UserRole.admin;
}
