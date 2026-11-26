import { describe, it } from "node:test";
import * as assert from "node:assert";
import { verifyAppCheck } from "./appcheck";
import { HttpsError } from "firebase-functions/v2/https";

describe("STAGE 32: Firebase App Check Backend Attestation & Enforcement Tests", () => {
  it("1. Authentic App Check token succeeds and returns verified metadata", () => {
    const mockRequest: any = {
      app: {
        appId: "1:123456789:android:abcdef0123456789",
        token: { sub: "test-token" },
      },
      data: {},
    };

    const result = verifyAppCheck(mockRequest, "testEndpoint");
    assert.strictEqual(result.verified, true);
    assert.strictEqual(result.appId, "1:123456789:android:abcdef0123456789");
    assert.strictEqual(result.enforced, false);
  });

  it("2. Unattested request in Monitor/Audit mode returns unverified without throwing", () => {
    const mockRequest: any = {
      app: undefined,
      data: {},
    };

    const result = verifyAppCheck(mockRequest, "approveSignupRequest");
    assert.strictEqual(result.verified, false);
    assert.strictEqual(result.appId, undefined);
    assert.strictEqual(result.enforced, false);
  });

  it("3. Unattested request under strict enforcement throws HttpsError unauthenticated", () => {
    const mockRequest: any = {
      app: undefined,
      data: {},
    };

    assert.throws(
      () => {
        verifyAppCheck(mockRequest, "startAttendanceSession", {
          forceEnforceInTest: true,
        });
      },
      (err: any) => {
        assert.ok(err instanceof HttpsError);
        assert.strictEqual(err.code, "unauthenticated");
        assert.match(err.message, /Firebase App Check verification failed/);
        return true;
      }
    );
  });

  it("4. Attested request under strict enforcement succeeds without error", () => {
    const mockRequest: any = {
      app: {
        appId: "1:987654321:android:fedcba9876543210",
        token: { sub: "verified-play-integrity-token" },
      },
      data: {},
    };

    const result = verifyAppCheck(mockRequest, "startAttendanceSession", {
      forceEnforceInTest: true,
    });
    assert.strictEqual(result.verified, true);
    assert.strictEqual(result.appId, "1:987654321:android:fedcba9876543210");
    assert.strictEqual(result.enforced, true);
  });

  it("5. Replayed token with requireReplayProtection under strict enforcement throws permission-denied", () => {
    const mockRequest: any = {
      app: {
        appId: "1:987654321:android:fedcba9876543210",
        token: { sub: "consumed-token" },
        alreadyConsumed: true,
      },
      data: {},
    };

    assert.throws(
      () => {
        verifyAppCheck(mockRequest, "approveSemesterUpgrade", {
          forceEnforceInTest: true,
          requireReplayProtection: true,
        });
      },
      (err: any) => {
        assert.ok(err instanceof HttpsError);
        assert.strictEqual(err.code, "permission-denied");
        assert.match(err.message, /already been consumed/);
        return true;
      }
    );
  });

  it("6. Local Firebase emulator bypass allows unverified requests during development", () => {
    const originalEmulator = process.env.FUNCTIONS_EMULATOR;
    try {
      process.env.FUNCTIONS_EMULATOR = "true";
      const mockRequest: any = {
        app: undefined,
        data: {},
      };

      // Even with enforcement active, emulator avoids blocking
      const result = verifyAppCheck(mockRequest, "localDevFunction");
      assert.strictEqual(result.verified, false);
    } finally {
      process.env.FUNCTIONS_EMULATOR = originalEmulator;
    }
  });
});
