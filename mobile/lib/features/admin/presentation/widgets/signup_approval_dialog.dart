import 'package:flutter/material.dart';
import '../../../auth/domain/entities/signup_request.dart';

/// Result of the approval dialog. [year] and [semester] are null for faculty.
class SignupApprovalDecision {
  final int? year;
  final int? semester;

  const SignupApprovalDecision({this.year, this.semester});
}

/// One selectable academic level, e.g. Year 3 · Semester 1.
class AcademicLevel {
  final int year;
  final int semester;

  const AcademicLevel(this.year, this.semester);

  String get label => 'Year $year · Semester $semester';

  /// All eight levels of the 4-year programme, in order.
  static const List<AcademicLevel> all = [
    AcademicLevel(1, 1),
    AcademicLevel(1, 2),
    AcademicLevel(2, 1),
    AcademicLevel(2, 2),
    AcademicLevel(3, 1),
    AcademicLevel(3, 2),
    AcademicLevel(4, 1),
    AcademicLevel(4, 2),
  ];
}

/// Shared approval dialog used by the Requests screen, the pending-signups
/// card, and the Chairman / committee Admin View.
///
/// For Students / CRs it shows the session the applicant chose at signup as
/// read-only (it is saved exactly as submitted and can be corrected later from
/// the User Directory), and the approver must pick the semester. Nothing is
/// guessed from the session: students may take longer than normal and session
/// jams shift whole batches.
class SignupApprovalDialog extends StatefulWidget {
  final SignupRequest request;

  const SignupApprovalDialog({super.key, required this.request});

  /// Returns the decision, or null if the approver cancelled.
  static Future<SignupApprovalDecision?> show(BuildContext context, SignupRequest request) {
    return showDialog<SignupApprovalDecision>(
      context: context,
      builder: (_) => SignupApprovalDialog(request: request),
    );
  }

  @override
  State<SignupApprovalDialog> createState() => _SignupApprovalDialogState();
}

class _SignupApprovalDialogState extends State<SignupApprovalDialog> {
  AcademicLevel? _level;

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (!req.role.isStudentSide) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Faculty Signup?'),
        content: Text('Approve and provision portal credentials for ${req.fullName} (${req.email})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, const SignupApprovalDecision()),
            child: const Text('Confirm Approval'),
          ),
        ],
      );
    }

    final hasSession = req.session != null && req.session!.trim().isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Approve ${req.fullName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${req.studentId ?? '-'}  •  ${req.email}',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 16),
            Container(
              key: const ValueKey('approval_session_info'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.school_outlined, size: 18, color: muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasSession ? 'Session: ${req.session!.trim()}' : 'Session: not provided',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Session is saved as the applicant entered it. It can be corrected later from the User Directory.',
              style: TextStyle(fontSize: 11.5, color: muted),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AcademicLevel>(
              key: const ValueKey('approval_semester_dropdown'),
              initialValue: _level,
              isExpanded: true,
              hint: const Text('Select current semester'),
              decoration: InputDecoration(
                labelText: 'Semester',
              ),
              items: AcademicLevel.all
                  .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                  .toList(),
              onChanged: (v) => setState(() => _level = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            foregroundColor: Colors.white,
          ),
          onPressed: _level == null
              ? null
              : () => Navigator.pop(
                    context,
                    SignupApprovalDecision(year: _level!.year, semester: _level!.semester),
                  ),
          child: const Text('Approve & Provision'),
        ),
      ],
    );
  }
}
