/**
 * CSE JnU EduPortal - Ground-Zero Domain Enumerations
 */

export enum RequestStatus {
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
}

export enum SemesterStatus {
  NONE = 'NONE',
  PENDING = 'PENDING',
  APPROVED = 'APPROVED',
  REJECTED = 'REJECTED',
}

export enum CourseType {
  THEORY = 'THEORY',
  LAB = 'LAB',
  PROJECT = 'PROJECT',
  THESIS = 'THESIS',
}

export enum DayOfWeek {
  SUNDAY = 'SUNDAY',
  MONDAY = 'MONDAY',
  TUESDAY = 'TUESDAY',
  WEDNESDAY = 'WEDNESDAY',
  THURSDAY = 'THURSDAY',
  FRIDAY = 'FRIDAY',
  SATURDAY = 'SATURDAY',
}

export const CLASS_DAYS: DayOfWeek[] = [
  DayOfWeek.SUNDAY,
  DayOfWeek.MONDAY,
  DayOfWeek.TUESDAY,
  DayOfWeek.WEDNESDAY,
  DayOfWeek.THURSDAY,
];

export enum AttendanceStatus {
  PRESENT = 'PRESENT',
  ABSENT = 'ABSENT',
  EXCUSED = 'EXCUSED',
}

export enum SessionStatus {
  ACTIVE = 'ACTIVE',
  EXPIRED = 'EXPIRED',
  CLOSED = 'CLOSED',
}

export enum SlotStatus {
  AVAILABLE = 'AVAILABLE',
  BOOKED = 'BOOKED',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
}

export enum CounselingCategory {
  ACADEMIC_ADVISING = 'ACADEMIC_ADVISING',
  RESEARCH_DISCUSSION = 'RESEARCH_DISCUSSION',
  MENTAL_PRESSURE = 'MENTAL_PRESSURE',
  CLASS_ISSUE = 'CLASS_ISSUE',
  CAREER_GUIDANCE = 'CAREER_GUIDANCE',
  OTHER = 'OTHER',
}

export enum AttachmentParentType {
  FEEDBACK = 'FEEDBACK',
  FEEDBACK_REPLY = 'FEEDBACK_REPLY',
  COUNSELING = 'COUNSELING',
}
