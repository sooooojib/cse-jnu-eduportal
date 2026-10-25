import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/app_colors.dart';
import '../utils/bangladeshi_phone_utils.dart';
import 'whatsapp_share_service.dart';

class WhatsAppShareDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String messageText;
  final WhatsAppShareService? shareService;

  const WhatsAppShareDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.messageText,
    this.shareService,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String messageText,
    WhatsAppShareService? shareService,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => WhatsAppShareDialog(
        title: title,
        subtitle: subtitle,
        messageText: messageText,
        shareService: shareService,
      ),
    );
  }

  @override
  State<WhatsAppShareDialog> createState() => _WhatsAppShareDialogState();
}

class _WhatsAppShareDialogState extends State<WhatsAppShareDialog> {
  final _phoneController = TextEditingController();
  late final WhatsAppShareService _shareService;
  BangladeshiPhoneResult? _phoneResult;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _shareService = widget.shareService ?? WhatsAppShareService();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final text = _phoneController.text.trim();
    if (text.isEmpty) {
      if (_phoneResult != null) {
        setState(() {
          _phoneResult = null;
        });
      }
      return;
    }

    final res = BangladeshiPhoneUtils.normalize(text);
    setState(() {
      _phoneResult = res;
    });
  }

  Future<void> _handleShare() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final phoneText = _phoneController.text.trim();

    if (phoneText.isNotEmpty && (_phoneResult == null || !_phoneResult!.isValid)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_phoneResult?.error ?? 'Invalid Bangladeshi phone number.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSharing = true;
    });

    final res = await _shareService.shareRoutine(
      text: widget.messageText,
      recipientPhone: phoneText.isNotEmpty ? phoneText : null,
    );

    if (!mounted) return;

    setState(() {
      _isSharing = false;
    });

    navigator.pop();

    Color snackColor;
    switch (res.method) {
      case WhatsAppShareMethod.nativeApp:
      case WhatsAppShareMethod.browserWeb:
        snackColor = const Color(0xFF25D366);
        break;
      case WhatsAppShareMethod.copiedToClipboard:
        snackColor = const Color(0xFF059669);
        break;
      case WhatsAppShareMethod.failed:
        snackColor = Colors.redAccent;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: snackColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleCopy() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await Clipboard.setData(ClipboardData(text: widget.messageText));
    } catch (_) {}

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Routine copied to clipboard! Ready to paste into WhatsApp.'),
        backgroundColor: Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF25D366),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  widget.subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message Preview Box
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceContainerDark : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.messageText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Optional Recipient Phone Number
            const Text(
              'Direct Recipient (Optional)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'e.g. 017XXXXXXXX or +88017XXXXXXXX',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _phoneResult != null && _phoneResult!.isValid
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF25D366), size: 20)
                    : null,
              ),
            ),
            if (_phoneResult != null) ...[
              const SizedBox(height: 6),
              if (_phoneResult!.isValid)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Operator: ${_phoneResult!.operator}',
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      'Target: ${_phoneResult!.whatsAppNumber}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                )
              else
                Text(
                  _phoneResult!.error ?? 'Invalid phone number',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
            ],
            const SizedBox(height: 6),
            const Text(
              'Leave blank to select contact or group in WhatsApp.',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: _handleCopy,
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy Message'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isSharing ? null : _handleShare,
          icon: _isSharing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(_phoneController.text.trim().isNotEmpty ? 'Send to Contact' : 'Share WhatsApp'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
