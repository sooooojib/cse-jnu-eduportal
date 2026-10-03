import 'package:flutter/material.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../../auth/domain/entities/signup_request.dart';

class AdminPendingSignupsCard extends StatelessWidget {
  final List<SignupRequest> requests;
  final Function(SignupRequest, int?, int?) onApprove;
  final Function(SignupRequest, String) onReject;
  final VoidCallback? onViewAll;

  const AdminPendingSignupsCard({
    super.key,
    required this.requests,
    required this.onApprove,
    required this.onReject,
    this.onViewAll,
  });

  void _showDetailModal(BuildContext context, SignupRequest req) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Signup Petition Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  RoleBadgeChip(role: req.role),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Applicant Name', req.fullName),
              _buildDetailRow('Email Address', req.email),
              if (req.studentId != null && req.studentId!.isNotEmpty)
                _buildDetailRow('Student ID / Roll', req.studentId!),
              if (req.phone != null && req.phone!.isNotEmpty)
                _buildDetailRow('Contact Phone', req.phone!),
              _buildDetailRow('Status', req.status),
              _buildDetailRow('Submitted At', req.createdAt),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _promptRejection(context, req);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _promptApproval(context, req);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _promptApproval(BuildContext context, SignupRequest req) {
    int selectedYear = 1;
    int selectedSemester = 1;

    if (req.role == UserRole.teacher) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Approve Faculty Signup?'),
          content: Text('Approve and provision portal credentials for ${req.fullName} (${req.email})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onApprove(req, null, null);
              },
              child: const Text('Confirm Approval'),
            ),
          ],
        ),
      );
      return;
    }

    // For Student / CR: Prompt Year & Semester selection
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Approve & Assign Level'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Approve ${req.fullName} (${req.studentId ?? req.email}).'),
                  const SizedBox(height: 16),
                  const Text('Select Academic Year:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [1, 2, 3, 4]
                        .map((y) => DropdownMenuItem(value: y, child: Text('Year $y')))
                        .toList(),
                    onChanged: (val) => setState(() => selectedYear = val ?? 1),
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Academic Semester:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedSemester,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [1, 2]
                        .map((s) => DropdownMenuItem(value: s, child: Text('Semester $s')))
                        .toList(),
                    onChanged: (val) => setState(() => selectedSemester = val ?? 1),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onApprove(req, selectedYear, selectedSemester);
                  },
                  child: const Text('Approve & Provision'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _promptRejection(BuildContext context, SignupRequest req) {
    final controller = TextEditingController(text: 'Applicant does not meet departmental verification criteria.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Signup Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify the reason for rejecting ${req.fullName}:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onReject(req, controller.text.trim());
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E22CE).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Color(0xFF7E22CE), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'New Signup Requests',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: requests.isNotEmpty ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${requests.length} Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: requests.isNotEmpty ? const Color(0xFFDC2626) : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content List or Empty State
          if (requests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 40,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No Pending Signups',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All student and teacher registration petitions have been reviewed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.take(5).length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final req = requests[index];
                final initials = req.fullName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

                return InkWell(
                  onTap: () => _showDetailModal(context, req),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: req.role == UserRole.teacher
                              ? const Color(0xFFEFF6FF)
                              : (req.role == UserRole.cr ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5)),
                          child: Text(
                            initials.isNotEmpty ? initials : 'ST',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: req.role == UserRole.teacher
                                  ? const Color(0xFF1D4ED8)
                                  : (req.role == UserRole.cr ? const Color(0xFFC2410C) : const Color(0xFF047857)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.fullName,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 2,
                                children: [
                                  if (req.studentId != null && req.studentId!.isNotEmpty) ...[
                                    Text(
                                      req.studentId!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const Text('•', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                  RoleBadgeChip(role: req.role, isCompact: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 28),
                              tooltip: 'Approve',
                              onPressed: () => _promptApproval(context, req),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 28),
                              tooltip: 'Reject',
                              onPressed: () => _promptRejection(context, req),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

          if (requests.length > 5 && onViewAll != null) ...[
            const Divider(height: 1),
            InkWell(
              onTap: onViewAll,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Text(
                  'View All Requests',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7E22CE),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
