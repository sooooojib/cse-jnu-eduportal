import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/bangladeshi_phone_utils.dart';

enum WhatsAppShareMethod {
  nativeApp,
  browserWeb,
  copiedToClipboard,
  failed,
}

class WhatsAppShareResult {
  final bool success;
  final WhatsAppShareMethod method;
  final String message;
  final String? deepLinkUsed;

  const WhatsAppShareResult({
    required this.success,
    required this.method,
    required this.message,
    this.deepLinkUsed,
  });

  @override
  String toString() =>
      'WhatsAppShareResult(success: $success, method: $method, message: "$message")';
}

typedef UrlLaunchHandler = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Service for generating safe WhatsApp deep links and safely sharing
/// class schedules, routines, and departmental announcements.
class WhatsAppShareService {
  final UrlLaunchHandler _launchHandler;

  WhatsAppShareService({UrlLaunchHandler? launchHandler})
      : _launchHandler = launchHandler ??
            ((uri, {mode = LaunchMode.platformDefault}) =>
                launchUrl(uri, mode: mode));

  /// Builds a safe, URI-encoded native `whatsapp://send` URI.
  static Uri buildNativeAppUri({required String text, String? recipientPhone}) {
    final queryParams = <String, String>{};

    if (recipientPhone != null && recipientPhone.trim().isNotEmpty) {
      final waNum = BangladeshiPhoneUtils.toWhatsAppNumber(recipientPhone);
      if (waNum != null) {
        queryParams['phone'] = waNum;
      }
    }
    queryParams['text'] = text;

    return Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: queryParams,
    );
  }

  /// Builds a safe, universal `https://wa.me/` URI for universal linking or web.
  static Uri buildWebUri({required String text, String? recipientPhone}) {
    if (recipientPhone != null && recipientPhone.trim().isNotEmpty) {
      final waNum = BangladeshiPhoneUtils.toWhatsAppNumber(recipientPhone);
      if (waNum != null) {
        return Uri.parse(
          'https://wa.me/$waNum?text=${Uri.encodeComponent(text)}',
        );
      }
    }

    return Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );
  }

  /// Authoritatively shares text via WhatsApp with multi-tier fallback:
  /// 1. Native WhatsApp App (`whatsapp://send`)
  /// 2. Universal Web Link (`https://wa.me/`)
  /// 3. Safe Clipboard Copy Fallback
  ///
  /// Guarantees that external app failures NEVER corrupt internal application state.
  Future<WhatsAppShareResult> shareRoutine({
    required String text,
    String? recipientPhone,
    bool copyToClipboardOnFallback = true,
  }) async {
    if (text.trim().isEmpty) {
      return const WhatsAppShareResult(
        success: false,
        method: WhatsAppShareMethod.failed,
        message: 'Cannot share empty routine message.',
      );
    }

    // Validate phone number if provided
    if (recipientPhone != null && recipientPhone.trim().isNotEmpty) {
      final phoneRes = BangladeshiPhoneUtils.normalize(recipientPhone);
      if (!phoneRes.isValid) {
        return WhatsAppShareResult(
          success: false,
          method: WhatsAppShareMethod.failed,
          message: phoneRes.error ?? 'Invalid Bangladeshi phone number.',
        );
      }
    }

    final nativeUri = buildNativeAppUri(
      text: text,
      recipientPhone: recipientPhone,
    );

    // Tier 1: Try Native WhatsApp App
    try {
      final launchedNative = await _launchHandler(
        nativeUri,
        mode: LaunchMode.externalApplication,
      );

      if (launchedNative) {
        return WhatsAppShareResult(
          success: true,
          method: WhatsAppShareMethod.nativeApp,
          message: 'Launched WhatsApp app successfully.',
          deepLinkUsed: nativeUri.toString(),
        );
      }
    } catch (_) {
      // Gracefully cascade to Web/Universal link
    }

    // Tier 2: Try Web / Universal wa.me URL
    final webUri = buildWebUri(
      text: text,
      recipientPhone: recipientPhone,
    );

    try {
      final launchedWeb = await _launchHandler(
        webUri,
        mode: LaunchMode.externalApplication,
      );

      if (launchedWeb) {
        return WhatsAppShareResult(
          success: true,
          method: WhatsAppShareMethod.browserWeb,
          message: 'Opened WhatsApp in browser.',
          deepLinkUsed: webUri.toString(),
        );
      }
    } catch (_) {
      // Gracefully cascade to Clipboard
    }

    // Tier 3: Safe Clipboard Fallback
    if (copyToClipboardOnFallback) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
        return const WhatsAppShareResult(
          success: true,
          method: WhatsAppShareMethod.copiedToClipboard,
          message:
              'WhatsApp could not be opened automatically. Routine text was copied to clipboard!',
        );
      } catch (clipErr) {
        return WhatsAppShareResult(
          success: false,
          method: WhatsAppShareMethod.failed,
          message: 'Failed to open WhatsApp or copy text: $clipErr',
        );
      }
    }

    return const WhatsAppShareResult(
      success: false,
      method: WhatsAppShareMethod.failed,
      message: 'Unable to open WhatsApp on this device.',
    );
  }
}
