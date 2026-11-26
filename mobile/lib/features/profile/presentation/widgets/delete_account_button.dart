import 'package:flutter/material.dart';
import '../../../auth/data/services/account_deletion_service.dart';

/// "Delete my account" for students. Shows what will be removed, asks for the
/// password, deletes, then calls [onDeleted] (sign out + go to login).
class DeleteAccountButton extends StatelessWidget {
  final Future<void> Function() onDeleted;
  final AccountDeletionService? service;

  const DeleteAccountButton({super.key, required this.onDeleted, this.service});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _open(context),
      style: TextButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
      child: const Text('Delete my account', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Future<void> _open(BuildContext context) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteAccountDialog(service: service ?? AccountDeletionService()),
    );
    if (deleted == true) {
      await onDeleted();
    }
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  final AccountDeletionService service;
  const _DeleteAccountDialog({required this.service});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.deleteMyAccount(password: _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AccountDeletionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This removes your login and permanently deletes:'),
            const SizedBox(height: 8),
            Text(
              '• your profile\n'
              '• your semester requests\n'
              '• your counseling requests\n'
              '• feedback you wrote\n'
              '• your retake courses\n'
              '• your notifications',
              style: TextStyle(fontSize: 13, color: muted, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Attendance records are official department records and are kept.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 4),
            Text('This cannot be undone.', style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: _hide,
              enabled: !_busy,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Your password',
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: _error,
                errorMaxLines: 3,
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
              onSubmitted: (_) => _busy ? null : _delete(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
          onPressed: _busy ? null : _delete,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Delete'),
        ),
      ],
    );
  }
}
