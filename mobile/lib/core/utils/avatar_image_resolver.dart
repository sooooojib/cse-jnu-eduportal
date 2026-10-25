import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Helper to safely resolve avatar images across Mobile, Desktop, and Web.
/// Prevents runtime ImageCodecException / Uri host exceptions when local file
/// paths (e.g. /data/user/0/... or file:///data/user/0/...) are stored in user documents
/// and erroneously passed to NetworkImage.
class AvatarImageResolver {
  const AvatarImageResolver._();

  static ImageProvider? resolve(String? url, [String? localPath]) {
    // 1. Check local file path if provided and not on web
    if (localPath != null && localPath.trim().isNotEmpty && !kIsWeb) {
      final trimmedLocal = localPath.trim();
      try {
        String cleanPath = trimmedLocal;
        if (trimmedLocal.startsWith('file:')) {
          final uri = Uri.tryParse(trimmedLocal);
          if (uri != null && uri.isScheme('file')) {
            cleanPath = uri.toFilePath();
          } else {
            cleanPath = trimmedLocal.replaceFirst(RegExp(r'^file:\/{1,3}'), '/');
          }
        }
        final file = File(cleanPath);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (_) {}
    }

    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();

    // 2. Base64 data URI format (e.g. data:image/jpeg;base64,...)
    if (trimmed.startsWith('data:image')) {
      final commaIdx = trimmed.indexOf(',');
      if (commaIdx != -1) {
        try {
          final base64Str = trimmed.substring(commaIdx + 1);
          final bytes = base64Decode(base64Str);
          return MemoryImage(bytes);
        } catch (_) {
          return null;
        }
      }
    }

    // 3. Remote HTTP/HTTPS URLs (strictly validated with non-empty host)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.hasAuthority && uri.host.isNotEmpty) {
        return NetworkImage(trimmed);
      }
      return null;
    }

    // 4. Local file paths on non-web platforms (e.g. /data/user/... or file:///data/...)
    if (!kIsWeb && (trimmed.startsWith('/') || trimmed.startsWith('file:'))) {
      try {
        String cleanPath = trimmed;
        if (trimmed.startsWith('file:')) {
          final uri = Uri.tryParse(trimmed);
          if (uri != null && uri.isScheme('file')) {
            cleanPath = uri.toFilePath();
          } else {
            cleanPath = trimmed.replaceFirst(RegExp(r'^file:\/{1,3}'), '/');
          }
        }
        final file = File(cleanPath);
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (_) {}
      return null;
    }

    // On Web or missing local files or unrecognized schemas, return null safely
    return null;
  }
}
