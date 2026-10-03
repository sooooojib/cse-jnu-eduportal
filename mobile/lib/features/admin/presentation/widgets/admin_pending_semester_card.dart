import 'package:flutter/material.dart';
import '../../../profile/domain/entities/semester_status.dart';

class AdminPendingSemesterCard extends StatelessWidget {
  final List<SemesterUpgradeRequest> requests;
  final Function(SemesterUpgradeRequest) onApprove;
  final Function(SemesterUpgradeRequest, String?) onReject;
  final VoidCallback? onViewAll;

  const AdminPendingSemesterCard({
    super.key,
    required this.requests,
    required this.onApprove,
    required this.onReject,
    this.onViewAll,
  });

  void _showDetailModal(BuildContext context, SemesterUpgradeRequest req) {
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Semester Promotion Petition',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Icon(Icons.school_rounded, color: Color(0xFF7E22CE)),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Student Name', req.studentName.isNotEmpty ? req.studentName : 'Student'),
              _buildDetailRow('Student Roll', req.studentRoll.isNotEmpty ? req.studentRoll : '—'),
              _buildDetailRow('Current Standing', 'Year ${req.currentYear}, Semester ${req.currentSemester}'),
              _buildDetailRow('Requested Standing', 'Year ${req.requestedYear}, Semester ${req.requestedSemester}'),
              _buildDetailRow('Status', req.status),
              _buildDetailRow('Submission Date', req.createdAt),
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
            width: 130,
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

  void _promptApproval(BuildContext context, SemesterUpgradeRequest req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approve Semester Promotion?'),
        content: Text(
          'Promote ${req.studentName} (${req.studentRoll}) from Year ${req.currentYear}, Semester ${req.currentSemester} to Year ${req.requestedYear}, Semester ${req.requestedSemester}?',
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
              onApprove(req);
            },
            child: const Text('Confirm Promotion'),
          ),
        ],
      ),
    );
  }

  void _promptRejection(BuildContext context, SemesterUpgradeRequest req) {
    final controller = TextEditingController(text: 'Academic eligibility requirements not yet fulfilled.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reject Semester Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify the reason for rejecting ${req.studentName}\'s petition:'),
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
                        child: const Icon(Icons.school_rounded, color: Color(0xFF7E22CE), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Semester Promotion Requests',
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
                    color: requests.isNotEmpty ? const Color(0xFFFAF5FF) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${requests.length} Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: requests.isNotEmpty ? const Color(0xFF7E22CE) : const Color(0xFF047857),
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
                      Icons.done_all_rounded,
                      size: 40,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No Pending Promotions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All student semester upgrade petitions have been reviewed.',
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
                final initials = req.studentName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

                return InkWell(
                  onTap: () => _showDetailModal(context, req),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark
                              ? const Color(0xFF047857).withValues(alpha: 0.25)
                              : const Color(0xFFECFDF5),
                          child: Text(
                            initials.isNotEmpty ? initials : 'ST',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req.studentName.isNotEmpty ? req.studentName : 'Student',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                req.studentRoll.isNotEmpty ? req.studentRoll : 'Enrolled Student',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Transition Pill: Y1S1 -> Y1S2
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Y${req.currentYear}S${req.currentSemester}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF7E22CE)),
                              const SizedBox(width: 4),
                              Text(
                                'Y${req.requestedYear}S${req.requestedSemester}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF7E22CE),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
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
