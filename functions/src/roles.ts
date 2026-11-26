/**
 * Centralised role helpers for Cloud Functions RBAC.
 *
 * Role hierarchy:
 *   - ADMIN     : System administrator. Full control, incl. security roles and
 *                 de-anonymised feedback audit.
 *   - CHAIRMAN  : Chairman of the Department. Holds every faculty capability AND
 *                 departmental admin capability (approvals, courses, notices,
 *                 teacher monitoring). Cannot create/delete/promote ADMIN
 *                 accounts or see anonymous feedback identities.
 *   - TEACHER   : Faculty member. Optional `isAdminDelegate` flag on the user
 *                 document allows reviewing STUDENT/CR signup requests.
 *   - CR / STUDENT
 */

export const ROLE_ADMIN = "ADMIN";
export const ROLE_CHAIRMAN = "CHAIRMAN";
export const ROLE_TEACHER = "TEACHER";
export const ROLE_CR = "CR";
export const ROLE_STUDENT = "STUDENT";

export const VALID_ROLES = [ROLE_STUDENT, ROLE_CR, ROLE_TEACHER, ROLE_CHAIRMAN, ROLE_ADMIN];

export function normalizeRole(role: unknown): string {
  return typeof role === "string" ? role.trim().toUpperCase() : "";
}

/** ADMIN or CHAIRMAN — departmental administration rights. */
export function isAdminRole(role: unknown): boolean {
  const r = normalizeRole(role);
  return r === ROLE_ADMIN || r === ROLE_CHAIRMAN;
}

/** Strictly the system ADMIN (security roles, identity audit). */
export function isSystemAdminRole(role: unknown): boolean {
  return normalizeRole(role) === ROLE_ADMIN;
}

/** TEACHER (or legacy FACULTY) or CHAIRMAN — people who teach courses. */
export function isTeacherRole(role: unknown): boolean {
  const r = normalizeRole(role);
  return r === ROLE_TEACHER || r === "FACULTY" || r === ROLE_CHAIRMAN;
}

export function isChairmanRole(role: unknown): boolean {
  return normalizeRole(role) === ROLE_CHAIRMAN;
}

export function isStudentSideRole(role: unknown): boolean {
  const r = normalizeRole(role);
  return r === ROLE_STUDENT || r === ROLE_CR;
}

/**
 * Whether a caller may review (approve/reject) a signup request for the given
 * requested role. Admin & Chairman may review everything; delegated faculty may
 * only review STUDENT / CR requests.
 */
export function canReviewSignupRequest(
  callerRole: unknown,
  callerIsAdminDelegate: boolean,
  requestedRole: unknown
): boolean {
  if (isAdminRole(callerRole)) return true;
  if (normalizeRole(callerRole) === ROLE_TEACHER && callerIsAdminDelegate) {
    return isStudentSideRole(requestedRole || ROLE_STUDENT);
  }
  return false;
}

/** Roles that the caller is allowed to provision / assign to other accounts. */
export function canAssignRole(callerRole: unknown, targetRole: unknown): boolean {
  const target = normalizeRole(targetRole);
  if (!VALID_ROLES.includes(target)) return false;
  if (isSystemAdminRole(callerRole)) return true;
  if (isChairmanRole(callerRole)) return target !== ROLE_ADMIN;
  return false;
}

/** Signup requests from the public form may only request these roles. */
export const SELF_SIGNUP_ROLES = [ROLE_STUDENT, ROLE_CR, ROLE_TEACHER];

/** Accepts "2021-2022" style academic sessions where year2 == year1 + 1. */
export function isValidAcademicSession(session: unknown): boolean {
  if (typeof session !== "string") return false;
  const m = /^(\d{4})-(\d{4})$/.exec(session.trim());
  if (!m) return false;
  const a = Number(m[1]);
  const b = Number(m[2]);
  return b === a + 1 && a >= 2000 && a <= 2100;
}
