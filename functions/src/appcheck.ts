import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import * as functions from "firebase-functions";

/**
 * Result of Firebase App Check attestation verification.
 */
export interface AppCheckVerificationResult {
  verified: boolean;
  appId?: string;
  enforced: boolean;
  replayed?: boolean;
}

/**
 * Options for verifying Firebase App Check attestation on incoming requests.
 */
export interface VerifyAppCheckOptions {
  /** If true, enforce even when NODE_ENV is 'test' (useful for test assertions) */
  forceEnforceInTest?: boolean;
  /** If true, verify that the token has not been replayed (requires limited-use token) */
  requireReplayProtection?: boolean;
}

/**
 * Validates or audits Firebase App Check token for incoming Cloud Function calls.
 *
 * Operational Strategy:
 * 1. Audit / Monitor Mode (Default):
 *    - Validates presence of `request.app`.
 *    - If present, logs authentic `appId`.
 *    - If missing or unverified, logs a structured warning and allows request through to prevent user lockout.
 *
 * 2. Strict Enforcement Mode (`ENFORCE_APP_CHECK="true"`):
 *    - If `request.app` is missing, throws `HttpsError("unauthenticated", ...)`.
 *    - If `requireReplayProtection` is true and token was already consumed, throws `HttpsError("permission-denied", ...)`.
 *
 * 3. Emulator & Unit Test Safety:
 *    - Bypasses blocking when running in Firebase Local Emulator or unit test suite unless explicitly overridden.
 */
export function verifyAppCheck(
  request: CallableRequest<any>,
  functionName: string,
  options: VerifyAppCheckOptions = {}
): AppCheckVerificationResult {
  const isEnforced = process.env.ENFORCE_APP_CHECK === "true" || options.forceEnforceInTest === true;
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
  const isTest = process.env.NODE_ENV === "test" && !options.forceEnforceInTest;

  const app = request.app;
  const verified = Boolean(app && app.appId);
  const replayed = Boolean(app && (app as any).alreadyConsumed);

  if (verified) {
    if (options.requireReplayProtection && replayed) {
      functions.logger.error(
        `[AppCheck:REPLAY_ATTACK] ${functionName} received replayed token from appId: ${app!.appId}`
      );
      if (isEnforced && !isEmulator && !isTest) {
        throw new HttpsError(
          "permission-denied",
          "Firebase App Check replay protection failed: this security token has already been consumed."
        );
      }
    }

    functions.logger.info(
      `[AppCheck:VERIFIED] ${functionName} called by authentic app binary (appId: ${app!.appId})`
    );
    return {
      verified: true,
      appId: app!.appId,
      enforced: isEnforced,
      replayed,
    };
  }

  // Missing or unverified token
  if (isEnforced && !isEmulator && !isTest) {
    functions.logger.error(
      `[AppCheck:BLOCKED] ${functionName} rejected request without authentic App Check attestation token.`
    );
    throw new HttpsError(
      "unauthenticated",
      "Firebase App Check verification failed. This request was rejected because it did not originate from an authentic CSE JnU EduPortal build."
    );
  }

  // Audit / Monitoring warning
  functions.logger.warn(
    `[AppCheck:AUDIT] ${functionName} accepted unverified request (no App Check token). Monitoring mode active; strict enforcement pending metrics confirmation.`
  );

  return {
    verified: false,
    enforced: isEnforced,
  };
}
