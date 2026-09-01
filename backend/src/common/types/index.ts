import { Request } from 'express';
import { UserRole } from '../constants/roles';
import { SemesterStatus } from '../constants/enums';

export interface AuthUserPayload {
  id: string;
  email: string;
  fullName: string;
  role: UserRole;
  studentId: string | null;
  phone: string | null;
  year: number | null;
  semester: number | null;
  semesterStatus: SemesterStatus;
}

export interface JwtTokenPayload {
  userId: string;
  email: string;
  role: UserRole;
  year: number | null;
  semester: number | null;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthUserPayload;
}

export interface ApiResponseMeta {
  timestamp: string;
  page?: number;
  limit?: number;
  total?: number;
  totalPages?: number;
  hasNextPage?: boolean;
  hasPrevPage?: boolean;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  message?: string;
  error?: {
    code: string;
    message: string;
    details: Array<{ field: string; message: string }> | null;
  };
  meta: ApiResponseMeta;
}
