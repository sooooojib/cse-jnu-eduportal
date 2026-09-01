import {
  UserRole,
  RequestStatus,
  SemesterStatus,
  CourseType,
  DayOfWeek,
  AttendanceStatus,
  SessionStatus,
  SlotStatus,
  CounselingCategory,
  AttachmentParentType,
} from '../../../common/constants';

// 1. users
export interface UserEntity {
  id: string;
  email: string;
  password_hash: string;
  full_name: string;
  role: UserRole;
  student_id: string | null;
  phone: string | null;
  avatar_url: string | null;
  year: number | null;
  semester: number | null;
  requested_year: number | null;
  requested_semester: number | null;
  semester_status: SemesterStatus;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

// 2. signup_requests
export interface SignupRequestEntity {
  id: string;
  email: string;
  full_name: string;
  role: UserRole;
  student_id: string | null;
  phone: string | null;
  status: RequestStatus;
  rejection_reason: string | null;
  reviewed_by_id: string | null;
  created_at: Date;
  updated_at: Date;
}

// 3. semester_requests
export interface SemesterRequestEntity {
  id: string;
  student_id: string;
  current_year: number;
  current_semester: number;
  requested_year: number;
  requested_semester: number;
  status: RequestStatus;
  rejection_reason: string | null;
  reviewed_by_id: string | null;
  created_at: Date;
  updated_at: Date;
}

// 4. courses
export interface CourseEntity {
  id: string;
  code: string;
  title: string;
  credit: number;
  year: number;
  semester: number;
  course_type: CourseType;
  description: string | null;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

// 5. course_teachers
export interface CourseTeacherEntity {
  id: string;
  course_id: string;
  teacher_id: string;
  is_coordinator: boolean;
  created_at: Date;
}

// 6. schedule_slots
export interface ScheduleSlotEntity {
  id: string;
  course_id: string;
  teacher_id: string;
  day_of_week: DayOfWeek;
  start_time: string;
  end_time: string;
  room: string;
  target_year: number;
  target_semester: number;
  created_by_id: string;
  created_at: Date;
  updated_at: Date;
}

// 7. exams
export interface ExamEntity {
  id: string;
  course_id: string;
  title: string;
  exam_date: string;
  start_time: string;
  end_time: string;
  room: string;
  year: number;
  semester: number;
  created_by_id: string;
  created_at: Date;
  updated_at: Date;
}

// 8. attendance_sessions
export interface AttendanceSessionEntity {
  id: string;
  course_id: string;
  teacher_id: string;
  schedule_slot_id: string | null;
  code: string;
  status: SessionStatus;
  expires_at: Date | null;
  created_at: Date;
  updated_at: Date;
}

// 9. attendance_records
export interface AttendanceRecordEntity {
  id: string;
  session_id: string;
  student_id: string;
  status: AttendanceStatus;
  verified_at: Date;
  is_manual_override: boolean;
  override_by_id: string | null;
  notes: string | null;
  created_at: Date;
  updated_at: Date;
}

// 10. counseling_slots
export interface CounselingSlotEntity {
  id: string;
  teacher_id: string;
  slot_date: string;
  start_time: string;
  end_time: string;
  status: SlotStatus;
  booked_student_id: string | null;
  notes: string | null;
  created_at: Date;
  updated_at: Date;
}

// 11. counseling_requests
export interface CounselingRequestEntity {
  id: string;
  slot_id: string;
  student_id: string;
  category: CounselingCategory;
  notes: string;
  status: RequestStatus;
  reviewed_at: Date | null;
  created_at: Date;
  updated_at: Date;
}

// 12. feedbacks
export interface FeedbackEntity {
  id: string;
  teacher_id: string;
  student_id: string | null;
  course_id: string | null;
  rating: number;
  comments: string;
  is_anonymous: boolean;
  created_at: Date;
  updated_at: Date;
}

// 13. feedback_replies
export interface FeedbackReplyEntity {
  id: string;
  feedback_id: string;
  teacher_id: string;
  reply_text: string;
  created_at: Date;
  updated_at: Date;
}

// 14. attachments
export interface AttachmentEntity {
  id: string;
  parent_type: AttachmentParentType;
  parent_id: string;
  file_url: string;
  file_name: string;
  file_size_bytes: number;
  mime_type: string;
  uploaded_by_id: string;
  created_at: Date;
}

// 15. notifications
export interface NotificationEntity {
  id: string;
  user_id: string;
  title: string;
  body: string;
  notification_type: string;
  reference_type: string | null;
  reference_id: string | null;
  is_read: boolean;
  created_at: Date;
}

// 16. refresh_tokens (Session & Revocation)
export interface RefreshTokenEntity {
  id: string;
  user_id: string;
  token: string;
  is_revoked: boolean;
  expires_at: Date;
  created_at: Date;
  updated_at: Date;
}

