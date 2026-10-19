import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Exceptions for Firebase Cloud Storage operations
class StorageException implements Exception {
  final String message;
  const StorageException(this.message);

  @override
  String toString() => message;
}

class StorageFileTooLargeException extends StorageException {
  final int maxBytes;
  final int actualBytes;
  StorageFileTooLargeException({required this.maxBytes, required this.actualBytes})
      : super('File exceeds maximum allowed size of ${(maxBytes / (1024 * 1024)).toStringAsFixed(1)}MB (actual: ${(actualBytes / (1024 * 1024)).toStringAsFixed(2)}MB).');
}

class StorageUnsupportedFileTypeException extends StorageException {
  final String extension;
  final String? mimeType;
  const StorageUnsupportedFileTypeException({required this.extension, this.mimeType})
      : super('Unsupported file type "$extension"${mimeType != null ? ' ($mimeType)' : ''}. Allowed: JPEG, PNG, WEBP, PDF, TXT, DOC, DOCX.');
}

class StorageUnauthorizedException extends StorageException {
  const StorageUnauthorizedException([String message = 'Unauthorized storage operation.'])
      : super(message);
}

class StoragePathValidationException extends StorageException {
  const StoragePathValidationException(String message)
      : super('Invalid storage path: $message');
}

/// Result of a successful storage file upload
class StorageUploadResult {
  final String downloadUrl;
  final String storagePath;
  final String fileName;
  final String contentType;
  final int fileSize;
  final Map<String, String> metadata;

  const StorageUploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
    required this.metadata,
  });
}

/// Scope-based canonical path builder to prevent arbitrary paths from client code
class StoragePathBuilder {
  static const Set<String> _approvedPrefixes = {
    'feedback/',
    'notices/',
    'avatars/',
    'counseling/',
  };

  static String _sanitize(String segment) {
    return segment
        .replaceAll(RegExp(r'[\/\\:\*\?"<>\|\s]+'), '_')
        .replaceAll('..', '')
        .trim();
  }

  static String feedbackAttachment({
    required String feedbackId,
    required String attachmentId,
    required String fileName,
  }) {
    final cleanFeedId = _sanitize(feedbackId);
    final cleanAttId = _sanitize(attachmentId);
    final cleanFile = _sanitize(fileName);
    return 'feedback/$cleanFeedId/attachments/${cleanAttId}_$cleanFile';
  }

  static String feedbackReplyAttachment({
    required String feedbackId,
    required String attachmentId,
    required String fileName,
  }) {
    final cleanFeedId = _sanitize(feedbackId);
    final cleanAttId = _sanitize(attachmentId);
    final cleanFile = _sanitize(fileName);
    return 'feedback/$cleanFeedId/replies/${cleanAttId}_$cleanFile';
  }

  static String noticeAttachment({
    required String noticeId,
    required String fileName,
  }) {
    final cleanNoticeId = _sanitize(noticeId);
    final cleanFile = _sanitize(fileName);
    return 'notices/$cleanNoticeId/$cleanFile';
  }

  static String avatar({
    required String userId,
    required String fileName,
  }) {
    final cleanUserId = _sanitize(userId);
    final cleanFile = _sanitize(fileName);
    return 'avatars/$cleanUserId/$cleanFile';
  }

  static String counselingAttachment({
    required String bookingId,
    required String attachmentId,
    required String fileName,
  }) {
    final cleanBookingId = _sanitize(bookingId);
    final cleanAttId = _sanitize(attachmentId);
    final cleanFile = _sanitize(fileName);
    return 'counseling/$cleanBookingId/${cleanAttId}_$cleanFile';
  }

  static bool isApprovedPath(String path) {
    if (path.isEmpty || path.contains('..') || path.startsWith('/')) {
      return false;
    }
    return _approvedPrefixes.any((prefix) => path.startsWith(prefix));
  }
}

/// Abstract contract for Cloud Storage Service
abstract class CloudStorageService {
  Future<StorageUploadResult> uploadFile({
    required File file,
    required String storagePath,
    required String uploadedBy,
    Map<String, String>? customMetadata,
    bool isImageOnly = false,
  });

  Future<void> deleteFile({
    required String storagePathOrUrl,
    required String requestedBy,
    bool isAdmin = false,
  });

  Future<Uint8List> downloadFileBytes({
    required String storagePathOrUrl,
    int maxDownloadBytes = 10 * 1024 * 1024,
  });
}

/// Production implementation of CloudStorageService using FirebaseStorage
class CloudStorageServiceImpl implements CloudStorageService {
  final FirebaseStorage storage;

  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const int maxDocumentSizeBytes = 10 * 1024 * 1024; // 10 MB

  static const Map<String, String> _imageMimeMap = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const Map<String, String> _docMimeMap = {
    ..._imageMimeMap,
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  CloudStorageServiceImpl({required this.storage});

  static String resolveMimeType(String fileName, {bool isImageOnly = false}) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      throw const StorageUnsupportedFileTypeException(extension: 'unknown');
    }
    final ext = fileName.substring(dotIndex + 1).toLowerCase();

    if (isImageOnly) {
      final mime = _imageMimeMap[ext];
      if (mime == null) {
        throw StorageUnsupportedFileTypeException(extension: ext);
      }
      return mime;
    }

    final mime = _docMimeMap[ext];
    if (mime == null) {
      throw StorageUnsupportedFileTypeException(extension: ext);
    }
    return mime;
  }

  @override
  Future<StorageUploadResult> uploadFile({
    required File file,
    required String storagePath,
    required String uploadedBy,
    Map<String, String>? customMetadata,
    bool isImageOnly = false,
  }) async {
    // 1. Verify caller identity
    if (uploadedBy.trim().isEmpty) {
      throw const StorageUnauthorizedException('UploadedBy UID must be provided for authenticated uploads.');
    }

    // 2. Validate canonical storage path
    if (!StoragePathBuilder.isApprovedPath(storagePath)) {
      throw StoragePathValidationException('Path "$storagePath" is not within approved scopes.');
    }

    // 3. Verify file existence
    if (!await file.exists()) {
      throw StorageException('Local file does not exist at path: ${file.path}');
    }

    // 4. File type validation
    final fileName = file.path.split(Platform.pathSeparator).last;
    final mimeType = resolveMimeType(fileName, isImageOnly: isImageOnly);

    // 5. File size limits
    final fileSize = await file.length();
    final maxSize = isImageOnly ? maxImageSizeBytes : maxDocumentSizeBytes;
    if (fileSize > maxSize) {
      throw StorageFileTooLargeException(maxBytes: maxSize, actualBytes: fileSize);
    }

    // 6. Build secure metadata
    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: {
        'uploadedBy': uploadedBy,
        'originalName': fileName,
        'fileSize': fileSize.toString(),
        'uploadedAt': DateTime.now().toUtc().toIso8601String(),
        if (customMetadata != null) ...customMetadata,
      },
    );

    // 7. Execute upload
    final ref = storage.ref(storagePath);
    final taskSnapshot = await ref.putFile(file, metadata);
    final downloadUrl = await taskSnapshot.ref.getDownloadURL();

    return StorageUploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      fileName: fileName,
      contentType: mimeType,
      fileSize: fileSize,
      metadata: metadata.customMetadata ?? {},
    );
  }

  @override
  Future<void> deleteFile({
    required String storagePathOrUrl,
    required String requestedBy,
    bool isAdmin = false,
  }) async {
    if (requestedBy.trim().isEmpty) {
      throw const StorageUnauthorizedException('RequestedBy UID must be provided for deletion.');
    }

    Reference ref;
    if (storagePathOrUrl.startsWith('http://') || storagePathOrUrl.startsWith('https://') || storagePathOrUrl.startsWith('gs://')) {
      ref = storage.refFromURL(storagePathOrUrl);
    } else {
      if (!StoragePathBuilder.isApprovedPath(storagePathOrUrl)) {
        throw StoragePathValidationException('Path "$storagePathOrUrl" is not within approved scopes.');
      }
      ref = storage.ref(storagePathOrUrl);
    }

    await ref.delete();
  }

  @override
  Future<Uint8List> downloadFileBytes({
    required String storagePathOrUrl,
    int maxDownloadBytes = 10 * 1024 * 1024,
  }) async {
    Reference ref;
    if (storagePathOrUrl.startsWith('http://') || storagePathOrUrl.startsWith('https://') || storagePathOrUrl.startsWith('gs://')) {
      ref = storage.refFromURL(storagePathOrUrl);
    } else {
      ref = storage.ref(storagePathOrUrl);
    }

    final data = await ref.getData(maxDownloadBytes);
    if (data == null) {
      throw StorageException('Downloaded file was empty or could not be retrieved.');
    }
    return data;
  }
}
