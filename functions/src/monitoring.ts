import * as functions from "firebase-functions";
import { CallableRequest, HttpsError } from "firebase-functions/v2/https";

/**
 * High-level failure categorization for server-side monitoring and alerting.
 */
export type FailureCategory =
  | "AUTH"
  | "AUTHORIZATION"
  | "VALIDATION"
  | "CONCURRENCY"
  | "NOT_FOUND"
  | "COMMUNICATION"
  | "STORAGE"
  | "SYSTEM_ERROR";

/**
 * Execution context attached to structured log entries.
 */
export interface MonitoringContext {
  operation: string;
  uid?: string;
  role?: string;
  appId?: string;
  requestId?: string;
  targetId?: string;
  courseId?: string;
  sessionId?: string;
}

/**
 * Sanitizes input data structures to ensure secrets, passwords, tokens,
 * and unnecessary student PII are never emitted to Google Cloud Logging.
 */
export class DiagnosticSanitizer {
  private static readonly DISALLOWED_KEY_REGEX =
    /(password|secret|token|credential|apikey|privatekey|authorization|rawcomment|studentcomment)/i;

  public static sanitize(value: any, depth = 0): any {
    if (depth > 4) return "[TRUNCATED_DEPTH]";
    if (value === null || value === undefined) return value;

    if (typeof value === "string") {
      // Redact JWTs
      if (/ey[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/.test(value)) {
        return "[REDACTED_JWT]";
      }
      // Mask email addresses for privacy: s***@jnu.ac.bd
      if (/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/.test(value)) {
        const parts = value.split("@");
        return `${parts[0].charAt(0)}***@${parts[1]}`;
      }
      return value;
    }

    if (Array.isArray(value)) {
      return value.map((item) => this.sanitize(item, depth + 1));
    }

    if (typeof value === "object") {
      const sanitizedObj: Record<string, any> = {};
      for (const [k, v] of Object.entries(value)) {
        if (this.DISALLOWED_KEY_REGEX.test(k)) {
          sanitizedObj[k] = "[REDACTED]";
        } else {
          sanitizedObj[k] = this.sanitize(v, depth + 1);
        }
      }
      return sanitizedObj;
    }

    return value;
  }
}

/**
 * Structured diagnostic logger for Cloud Functions execution.
 */
export class StructuredLogger {
  /**
   * Extracts non-sensitive telemetry context from a CallableRequest.
   */
  public static extractContext(
    operation: string,
    request?: CallableRequest<any>
  ): MonitoringContext {
    return {
      operation,
      uid: request?.auth?.uid,
      role: request?.auth?.token?.role,
      appId: request?.app?.appId,
      requestId: request?.data?.requestId,
      courseId: request?.data?.courseId,
      sessionId: request?.data?.sessionId,
    };
  }

  /**
   * Logs standard informational events.
   */
  public static info(
    operation: string,
    message: string,
    context?: Partial<MonitoringContext>,
    extraData?: Record<string, any>
  ): void {
    const payload = {
      severity: "INFO",
      timestamp: new Date().toISOString(),
      operation,
      message,
      context: DiagnosticSanitizer.sanitize(context),
      details: DiagnosticSanitizer.sanitize(extraData),
    };
    functions.logger.info(`[${operation}] ${message}`, payload);
  }

  /**
   * Logs warnings (e.g. unverified app check during audit, non-fatal soft retries).
   */
  public static warn(
    operation: string,
    message: string,
    context?: Partial<MonitoringContext>,
    extraData?: Record<string, any>
  ): void {
    const payload = {
      severity: "WARNING",
      timestamp: new Date().toISOString(),
      operation,
      message,
      context: DiagnosticSanitizer.sanitize(context),
      details: DiagnosticSanitizer.sanitize(extraData),
    };
    functions.logger.warn(`[${operation}] ${message}`, payload);
  }

  /**
   * Logs errors and maps them to standard failure categories for monitoring.
   */
  public static error(
    operation: string,
    err: any,
    category: FailureCategory,
    context?: Partial<MonitoringContext>,
    extraData?: Record<string, any>
  ): void {
    const isHttpsError = err instanceof HttpsError;
    const errorCode = isHttpsError ? err.code : "internal";
    const errorMessage = err?.message || String(err);

    const payload = {
      severity: "ERROR",
      timestamp: new Date().toISOString(),
      operation,
      category,
      errorCode,
      errorMessage,
      context: DiagnosticSanitizer.sanitize(context),
      details: DiagnosticSanitizer.sanitize(extraData),
      stack: isHttpsError ? undefined : err?.stack, // Omit stack for standard client validation errors
    };

    functions.logger.error(`[${operation}:${category}] ${errorMessage}`, payload);
  }

  /**
   * Logs security and audit decisions for critical operations.
   */
  public static audit(
    operation: string,
    actorUid: string,
    decision: "ALLOWED" | "DENIED" | "APPROVED" | "REJECTED" | "MODIFIED",
    targetEntity: string,
    targetId: string,
    details?: Record<string, any>
  ): void {
    const payload = {
      severity: "NOTICE",
      timestamp: new Date().toISOString(),
      type: "SECURITY_AUDIT",
      operation,
      actorUid,
      decision,
      targetEntity,
      targetId,
      details: DiagnosticSanitizer.sanitize(details),
    };
    functions.logger.info(`[AUDIT:${decision}] ${operation} on ${targetEntity}:${targetId} by ${actorUid}`, payload);
  }
}
