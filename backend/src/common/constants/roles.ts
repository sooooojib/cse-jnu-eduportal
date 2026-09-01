/**
 * CSE JnU EduPortal - User Roles & Authorization Constants
 * Ground-zero defined for Department of Computer Science & Engineering, Jagannath University
 */

export enum UserRole {
  STUDENT = 'STUDENT',
  CR = 'CR',
  TEACHER = 'TEACHER',
  ADMIN = 'ADMIN',
}

export const ALL_ROLES: UserRole[] = [
  UserRole.STUDENT,
  UserRole.CR,
  UserRole.TEACHER,
  UserRole.ADMIN,
];

export const STUDENT_ROLES: UserRole[] = [
  UserRole.STUDENT,
  UserRole.CR,
];

export const FACULTY_ROLES: UserRole[] = [
  UserRole.TEACHER,
];

export const ADMIN_ROLES: UserRole[] = [
  UserRole.ADMIN,
];
