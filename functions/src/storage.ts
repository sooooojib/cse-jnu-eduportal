import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

export const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB
export const MAX_DOCUMENT_SIZE_BYTES = 10 * 1024 * 1024; // 10 MB

export const ALLOWED_IMAGE_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

export const ALLOWED_DOCUMENT_MIME_TYPES = new Set([
  ...ALLOWED_IMAGE_MIME_TYPES,
  "application/pdf",
  "text/plain",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
]);

export const DISALLOWED_EXTENSIONS = new Set([
  "exe",
  "bat",
  "cmd",
  "sh",
  "bash",
  "bin",
  "apk",
  "jar",
  "vbs",
  "js",
  "php",
  "py",
  "pl",
]);

export interface StoragePolicyRequest {
  scope: "notice" | "avatar" | "feedback" | "feedback_reply" | "counseling";
  fileName: string;
  fileSizeBytes: number;
  contentType: string;
  entityId?: string; // noticeId, feedbackId, bookingId
  targetUserId?: string; // For avatar
}

export interface StoragePolicyResult {
  storagePath: string;
  contentType: string;
  maxSizeBytes: number;
  metadata: {
    uploadedBy: string;
    originalName: string;
    scope: string;
    fileSize: string;
    createdAt: string;
  };
}

export function sanitizePathSegment(segment: string): string {
  return segment
    .replace(/[\/\\:\*\?"<>\|\s]+/g, "_")
    .replace(/\.\./g, "")
    .trim();
}

export function isApprovedStoragePath(path: string): boolean {
  if (!path || path.startsWith("/") || path.includes("..")) {
    return false;
  }
  const approvedPrefixes = ["notices/", "avatars/", "feedback/", "counseling/"];
  return approvedPrefixes.some((prefix) => path.startsWith(prefix));
}

export function validateFileTypeAndSize(
  fileName: string,
  contentType: string,
  fileSizeBytes: number,
  isImageOnly: boolean = false
): void {
  const dotIndex = fileName.lastIndexOf(".");
  if (dotIndex === -1 || dotIndex === fileName.length - 1) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "File name must include a valid extension."
    );
  }

  const ext = fileName.substring(dotIndex + 1).toLowerCase();
  if (DISALLOWED_EXTENSIONS.has(ext)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Executable and script files (.${ext}) are strictly prohibited.`
    );
  }

  if (isImageOnly) {
    if (!ALLOWED_IMAGE_MIME_TYPES.has(contentType.toLowerCase())) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Invalid image content-type: ${contentType}. Allowed: JPEG, PNG, WEBP.`
      );
    }
    if (fileSizeBytes > MAX_IMAGE_SIZE_BYTES) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Image exceeds maximum allowed size of 5MB (${fileSizeBytes} bytes).`
      );
    }
    return;
  }

  if (!ALLOWED_DOCUMENT_MIME_TYPES.has(contentType.toLowerCase())) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Invalid document content-type: ${contentType}. Allowed: Images, PDF, TXT, DOC, DOCX.`
    );
  }

  if (fileSizeBytes > MAX_DOCUMENT_SIZE_BYTES) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `File exceeds maximum allowed size of 10MB (${fileSizeBytes} bytes).`
    );
  }
}

export function evaluateUploadPermission(
  auth: { uid: string; token: { role?: string } } | undefined,
  request: StoragePolicyRequest
): void {
  if (!auth || !auth.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authenticated user required for storage uploads."
    );
  }

  const role = (auth.token.role || "").toUpperCase();

  switch (request.scope) {
    case "notice":
      if (role !== "ADMIN") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only administrators can upload notice attachments."
        );
      }
      break;

    case "avatar":
      if (!request.targetUserId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "targetUserId is required for avatar uploads."
        );
      }
      if (auth.uid !== request.targetUserId && role !== "ADMIN") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Users can only upload their own avatar."
        );
      }
      break;

    case "feedback":
      // Any authenticated student/CR/user can upload feedback attachments
      break;

    case "feedback_reply":
      if (role !== "TEACHER" && role !== "ADMIN") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only teachers or administrators can attach files to feedback replies."
        );
      }
      break;

    case "counseling":
      // Any authenticated participant can upload counseling attachments
      break;

    default:
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Unknown storage scope: ${(request as any).scope}`
      );
  }
}

export function evaluateDeletePermission(
  auth: { uid: string; token: { role?: string } } | undefined,
  storagePath: string,
  uploaderUid?: string
): void {
  if (!auth || !auth.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authenticated user required for file deletion."
    );
  }

  if (!isApprovedStoragePath(storagePath)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Path is not within approved storage scopes."
    );
  }

  const role = (auth.token.role || "").toUpperCase();
  if (role === "ADMIN") {
    return; // Admin can delete any file
  }

  if (storagePath.startsWith("notices/")) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only administrators can delete notice attachments."
    );
  }

  if (storagePath.startsWith("avatars/")) {
    const parts = storagePath.split("/");
    const targetUserId = parts[1];
    if (auth.uid !== targetUserId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Users can only delete their own avatar."
      );
    }
    return;
  }

  if (uploaderUid && auth.uid !== uploaderUid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "You do not have permission to delete this file."
    );
  }
}

export function generateCanonicalStoragePath(
  request: StoragePolicyRequest,
  uploaderUid: string
): string {
  const cleanFileName = sanitizePathSegment(request.fileName);
  const timestamp = Date.now();

  switch (request.scope) {
    case "notice": {
      const noticeId = sanitizePathSegment(request.entityId || `notice_${timestamp}`);
      return `notices/${noticeId}/${cleanFileName}`;
    }
    case "avatar": {
      const targetUserId = sanitizePathSegment(request.targetUserId || uploaderUid);
      return `avatars/${targetUserId}/avatar_${timestamp}_${cleanFileName}`;
    }
    case "feedback": {
      const feedbackId = sanitizePathSegment(request.entityId || `feed_${timestamp}`);
      return `feedback/${feedbackId}/attachments/att_${timestamp}_${cleanFileName}`;
    }
    case "feedback_reply": {
      const feedbackId = sanitizePathSegment(request.entityId || `feed_${timestamp}`);
      return `feedback/${feedbackId}/replies/att_${timestamp}_${cleanFileName}`;
    }
    case "counseling": {
      const bookingId = sanitizePathSegment(request.entityId || `coun_${timestamp}`);
      return `counseling/${bookingId}/att_${timestamp}_${cleanFileName}`;
    }
  }
}

export function executeGetStorageUploadPolicy(
  auth: { uid: string; token: { role?: string } } | undefined,
  request: StoragePolicyRequest
): StoragePolicyResult {
  evaluateUploadPermission(auth, request);

  const isImage = request.scope === "avatar";
  validateFileTypeAndSize(request.fileName, request.contentType, request.fileSizeBytes, isImage);

  const storagePath = generateCanonicalStoragePath(request, auth!.uid);

  return {
    storagePath,
    contentType: request.contentType,
    maxSizeBytes: isImage ? MAX_IMAGE_SIZE_BYTES : MAX_DOCUMENT_SIZE_BYTES,
    metadata: {
      uploadedBy: auth!.uid,
      originalName: request.fileName,
      scope: request.scope,
      fileSize: request.fileSizeBytes.toString(),
      createdAt: new Date().toISOString(),
    },
  };
}

// ─── CALLABLE FUNCTIONS ────────────────────────────────────────────────────────

export const getStorageUploadPolicy = functions.https.onCall(
  async (data: StoragePolicyRequest, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in to request storage policy."
      );
    }
    return executeGetStorageUploadPolicy(context.auth as any, data);
  }
);

export const deleteStorageFile = functions.https.onCall(
  async (data: { storagePath: string; uploaderUid?: string }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in to delete storage files."
      );
    }

    const { storagePath, uploaderUid } = data;
    if (!storagePath) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "storagePath is required."
      );
    }

    evaluateDeletePermission(context.auth as any, storagePath, uploaderUid);

    try {
      const bucket = admin.storage().bucket();
      const file = bucket.file(storagePath);
      await file.delete({ ignoreNotFound: true });
      return { success: true, message: `File at "${storagePath}" deleted.` };
    } catch (err: any) {
      throw new functions.https.HttpsError(
        "internal",
        `Failed to delete file: ${err.message}`
      );
    }
  }
);
