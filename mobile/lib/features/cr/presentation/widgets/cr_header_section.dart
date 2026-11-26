import 'package:flutter/material.dart';
import '../../../../app/theme/role_colors.dart';
import '../../../../core/constants/role_constants.dart';
import '../../../../shared/widgets/cards/role_badge_chip.dart';
import '../../domain/entities/cr_dashboard_data.dart';

class CrHeaderSection extends StatelessWidget {
  final CrDashboardData data;
  final VoidCallback onRequestSemesterChange;

  const CrHeaderSection({
    super.key,
    required this.data,
    required this.onRequestSemesterChange,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleColors = RoleColors.forRole(data.role, isDark: isDark);
    final fallbackRole = data.role == UserRole.student ? 'Student' : 'Class Representative';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Row with Role Badge (Footer indicates active tab)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Welcome back, ${data.crName.isNotEmpty ? data.crName : fallbackRole}.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(width: 8),
            RoleBadgeChip(role: data.role, isCompact: true),
          ],
        ),
        const SizedBox(height: 14),

        // Active Semester & Change Request Row
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          // A normal card like the rest of the dashboard (no tinted box).
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13263E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? roleColors.primary.withValues(alpha: 0.2)
                            : roleColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        size: 16,
                        color: roleColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Semester',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            'Year ${data.year} · Semester ${data.semester}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('request_semester_change'),
                onPressed: onRequestSemesterChange,
                child: const Text('Request change'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
